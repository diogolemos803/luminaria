/**
 * Onde os cadastros da pré-venda ficam guardados.
 * 1) Redis (Upstash, pelo Marketplace da Vercel): privado, com listagem/CSV. Variáveis KV_REST_API_URL e KV_REST_API_TOKEN
 *    (ou UPSTASH_REDIS_REST_URL e UPSTASH_REDIS_REST_TOKEN), criadas ao conectar o banco ao projeto.
 * 2) Webhook (PREVENDA_WEBHOOK_URL): repassa cada cadastro para outro serviço (Formspree, planilha, etc.).
 */
export type LeadRecord = Record<string, string | boolean>;

/**
 * Acha o Redis nas variáveis do ambiente, qualquer que seja o prefixo escolhido ao conectar o banco
 * (ex.: KV_REST_API_URL, UPSTASH_REDIS_REST_URL, STORAGE_KV_REST_API_URL).
 */
function redisEnv(): { url: string; token: string } | null {
  const env = process.env;
  for (const key of Object.keys(env)) {
    const m = key.match(/^(.*)(KV_REST_API_URL|UPSTASH_REDIS_REST_URL)$/);
    if (!m || !env[key]) continue;
    const tokenKey = `${m[1]}${m[2].replace("URL", "TOKEN")}`;
    if (env[tokenKey]) return { url: env[key] as string, token: env[tokenKey] as string };
  }
  return null;
}
const redisUrl = () => redisEnv()?.url;
const redisToken = () => redisEnv()?.token;
const HASH = "sovee:leads";

export function leadsBackend(): "redis" | "webhook" | null {
  if (redisUrl() && redisToken()) return "redis";
  if (process.env.PREVENDA_WEBHOOK_URL) return "webhook";
  return null;
}

async function redis(command: (string | number)[]) {
  const res = await fetch(redisUrl() as string, {
    method: "POST",
    headers: { Authorization: `Bearer ${redisToken()}`, "Content-Type": "application/json" },
    body: JSON.stringify(command),
    signal: AbortSignal.timeout(8000),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.error) throw new Error("redis");
  return data.result;
}

/** Grava o cadastro. Lança erro se não conseguir: quem chama não deve liberar o pagamento. */
export async function saveLead(record: LeadRecord & { email: string; source: string }) {
  const backend = leadsBackend();
  if (backend === "redis") {
    // um registro por e-mail e origem: repetir o cadastro atualiza, não duplica
    await redis(["HSET", HASH, `${record.source}:${record.email}`, JSON.stringify(record)]);
    return;
  }
  if (backend === "webhook") {
    const res = await fetch(process.env.PREVENDA_WEBHOOK_URL as string, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(record),
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) throw new Error("webhook");
    return;
  }
  throw new Error("sem destino configurado");
}

/** Lista os cadastros (só com Redis). */
export async function listLeads(): Promise<LeadRecord[]> {
  if (leadsBackend() !== "redis") throw new Error("listagem indisponível");
  const flat: string[] = await redis(["HGETALL", HASH]);
  const out: LeadRecord[] = [];
  for (let i = 1; i < flat.length; i += 2) {
    try {
      out.push(JSON.parse(flat[i]));
    } catch {}
  }
  return out;
}
