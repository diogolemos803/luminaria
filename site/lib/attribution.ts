/** Origem da visita: utm_* da URL e primeira página, guardados em sessionStorage durante a sessão. */
const KEY = "sovee-attr";
const FIELDS = ["utm_source", "utm_medium", "utm_campaign", "utm_content"] as const;
export type Attribution = Record<(typeof FIELDS)[number], string> & { pagina_origem: string };

const empty = (): Attribution => ({ utm_source: "", utm_medium: "", utm_campaign: "", utm_content: "", pagina_origem: "" });

function read(): Attribution {
  try {
    return { ...empty(), ...JSON.parse(sessionStorage.getItem(KEY) ?? "{}") };
  } catch {
    return empty();
  }
}

/** Chamado em toda página: guarda os utm da URL (se houver) e a primeira página da sessão. */
export function captureAttribution() {
  try {
    const cur = read();
    const q = new URLSearchParams(location.search);
    let changed = false;
    if (!cur.pagina_origem) {
      cur.pagina_origem = location.pathname;
      changed = true;
    }
    for (const f of FIELDS) {
      const v = q.get(f);
      if (v) {
        cur[f] = v.slice(0, 200);
        changed = true;
      }
    }
    if (changed) sessionStorage.setItem(KEY, JSON.stringify(cur));
  } catch {}
}

export function readAttribution(): Attribution {
  const a = read();
  if (!a.pagina_origem) a.pagina_origem = location.pathname;
  return a;
}
