import { NextResponse } from "next/server";
import { TERMS_VERSION, preVendaConfigured } from "@/lib/pre-venda";

export const dynamic = "force-dynamic";

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

/**
 * Registra o cadastro da pré-venda e só então devolve o link de pagamento.
 * Se o e-mail não puder ser gravado (webhook fora do ar), o pagamento NÃO é liberado:
 * assim nenhum cliente paga sem ficar registrado com o aceite dos termos.
 */
export async function POST(req: Request) {
  if (!preVendaConfigured()) return NextResponse.json({ error: "closed" }, { status: 503 });

  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid" }, { status: 400 });
  }

  // campo-isca: robôs preenchem, pessoas não veem
  if (typeof b.website === "string" && b.website.trim() !== "") return NextResponse.json({ ok: true });

  const email = typeof b.email === "string" ? b.email.trim().toLowerCase() : "";
  const name = typeof b.name === "string" ? b.name.trim().slice(0, 100) : "";
  if (!EMAIL.test(email) || email.length > 254) return NextResponse.json({ error: "email" }, { status: 400 });
  if (b.acceptedTerms !== true || b.termsVersion !== TERMS_VERSION) return NextResponse.json({ error: "terms" }, { status: 400 });
  if (b.followsInstagram !== true) return NextResponse.json({ error: "instagram" }, { status: 400 });
  const paymentMethod = b.paymentMethod === "pix" || b.paymentMethod === "cartao" ? b.paymentMethod : "";
  if (!paymentMethod) return NextResponse.json({ error: "payment" }, { status: 400 });

  const record = {
    email,
    name,
    acceptedTerms: true,
    termsVersion: TERMS_VERSION,
    acceptedAt: new Date().toISOString(),
    followsInstagram: true, // declarado pela pessoa; o Instagram não permite verificar
    marketingOptIn: b.marketingOptIn === true, // consentimento separado, opcional (LGPD)
    paymentMethod,
    source: "pre-venda",
  };

  try {
    const res = await fetch(process.env.PREVENDA_WEBHOOK_URL as string, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(record),
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) throw new Error(String(res.status));
  } catch {
    return NextResponse.json({ error: "storage" }, { status: 502 });
  }

  return NextResponse.json({
    paymentUrl: paymentMethod === "pix" ? process.env.PREVENDA_PAYMENT_URL_PIX : process.env.PREVENDA_PAYMENT_URL_CARTAO,
  });
}
