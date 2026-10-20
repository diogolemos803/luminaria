/**
 * Lista de espera da SOVEE: onde as inscrições ficam guardadas (Redis da Upstash, via Marketplace da Vercel).
 * O banco aparece nas variáveis do ambiente com um prefixo qualquer (KV_REST_API_URL, STORAGE_KV_REST_API_URL,
 * UPSTASH_REDIS_REST_URL...). Aqui nada cobra, gera link de pagamento ou chama gateway: só guarda nome e e-mail.
 */
import { createHash } from "crypto";

/** Texto exato mostrado ao lado da caixa de consentimento; é o que fica gravado com cada inscrição. */
export const CONSENT_TEXT = "Concordo em receber e-mails da SOVEE sobre o lançamento. Posso sair da lista quando quiser.";

export type Subscriber = {
  nome: string;
  email: string;
  consentimento: true;
  consentimento_em: string; // ISO, gravado pelo servidor
  consentimento_texto: string;
  utm_source: string;
  utm_medium: string;
  utm_campaign: string;
  utm_content: string;
  pagina_origem: string;
  event_id: string; // o mesmo id do evento Lead do Pixel, para uma futura Conversions API
};

const HASH = "sovee:lista";

function redisEnv(): { url: string; token: string } | null {
  const env = process.env;
  for (const key of Object.keys(env)) {
    const m = key.match(/^(.*)(KV_REST_API_URL|UPSTASH_REDIS_REST_URL)$/);
    if (!m || !env[key]) continue;
    const token = env[`${m[1]}${m[2].replace("URL", "TOKEN")}`];
    if (token) return { url: env[key] as string, token };
  }
  return null;
}

export const listaConfigured = () => redisEnv() !== null;

async function redis(command: (string | number)[]) {
  const cfg = redisEnv();
  if (!cfg) throw new Error("sem banco");
  const res = await fetch(cfg.url, {
    method: "POST",
    headers: { Authorization: `Bearer ${cfg.token}`, "Content-Type": "application/json" },
    body: JSON.stringify(command),
    signal: AbortSignal.timeout(8000),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.error) throw new Error("redis");
  return data.result;
}

/** Limite de tentativas por IP (o IP vira um hash e some em 10 minutos). Devolve false se passou do limite. */
export async function allowAttempt(ip: string, max = 6, windowSec = 600) {
  const key = `sovee:rl:${createHash("sha256").update(ip).digest("hex").slice(0, 24)}`;
  const n = Number(await redis(["INCR", key]));
  if (n === 1) await redis(["EXPIRE", key, windowSec]);
  return n <= max;
}

/** Grava a inscrição sem repetir: o mesmo e-mail não é gravado de novo (e quem chama não revela isso). */
export async function addSubscriber(s: Subscriber) {
  await redis(["HSETNX", HASH, s.email, JSON.stringify(s)]);
}

export async function listSubscribers(): Promise<Subscriber[]> {
  const flat: string[] = (await redis(["HGETALL", HASH])) ?? [];
  const out: Subscriber[] = [];
  for (let i = 1; i < flat.length; i += 2) {
    try {
      out.push(JSON.parse(flat[i]));
    } catch {}
  }
  return out;
}

/** Remove uma pessoa da lista a pedido (LGPD, art. 18). Devolve true se existia. */
export async function removeSubscriber(email: string) {
  return Number(await redis(["HDEL", HASH, email.trim().toLowerCase()])) > 0;
}
