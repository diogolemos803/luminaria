import { NextResponse } from "next/server";
import { CONSENT_TEXT, addSubscriber, allowAttempt, listaConfigured } from "@/lib/lista";

export const dynamic = "force-dynamic";

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const clip = (v: unknown, n: number) => (typeof v === "string" ? v.trim().slice(0, n) : "");

/**
 * Inscrição na lista de espera. Só guarda nome, e-mail e o consentimento; não cobra nem gera link de pagamento.
 * Quem já estava na lista recebe o mesmo "ok" (não revelamos quem está na lista).
 */
export async function POST(req: Request) {
  if (!listaConfigured()) return NextResponse.json({ error: "erro" }, { status: 503 });

  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch {
    return NextResponse.json({ error: "erro" }, { status: 400 });
  }

  // campo-isca: robôs preenchem, pessoas não veem. Responde "ok" sem gravar nada.
  if (clip(b.website, 50) !== "") return NextResponse.json({ ok: true });

  const email = clip(b.email, 254).toLowerCase();
  if (!EMAIL.test(email)) return NextResponse.json({ error: "email" }, { status: 400 });
  if (b.consentimento !== true) return NextResponse.json({ error: "consentimento" }, { status: 400 });

  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || req.headers.get("x-real-ip") || "desconhecido";
  try {
    if (!(await allowAttempt(ip))) return NextResponse.json({ error: "limite" }, { status: 429 });
    await addSubscriber({
      nome: clip(b.nome, 100),
      email,
      consentimento: true,
      consentimento_em: new Date().toISOString(),
      consentimento_texto: CONSENT_TEXT,
      utm_source: clip(b.utm_source, 200),
      utm_medium: clip(b.utm_medium, 200),
      utm_campaign: clip(b.utm_campaign, 200),
      utm_content: clip(b.utm_content, 200),
      pagina_origem: clip(b.pagina_origem, 300),
      event_id: clip(b.event_id, 100),
    });
  } catch {
    return NextResponse.json({ error: "erro" }, { status: 502 });
  }
  return NextResponse.json({ ok: true });
}
