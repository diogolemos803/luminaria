import { NextResponse } from "next/server";
import { waitlistConfigured } from "@/lib/pre-venda";

export const dynamic = "force-dynamic";

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

/** Lista de espera: guarda o e-mail de quem quer ser avisado quando a pré-venda abrir. */
export async function POST(req: Request) {
  if (!waitlistConfigured()) return NextResponse.json({ error: "closed" }, { status: 503 });

  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid" }, { status: 400 });
  }

  if (typeof b.website === "string" && b.website.trim() !== "") return NextResponse.json({ ok: true }); // isca anti-robô

  const email = typeof b.email === "string" ? b.email.trim().toLowerCase() : "";
  const name = typeof b.name === "string" ? b.name.trim().slice(0, 100) : "";
  if (!EMAIL.test(email) || email.length > 254) return NextResponse.json({ error: "email" }, { status: 400 });

  try {
    const res = await fetch(process.env.PREVENDA_WEBHOOK_URL as string, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ email, name, source: "lista-de-espera", createdAt: new Date().toISOString() }),
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) throw new Error(String(res.status));
  } catch {
    return NextResponse.json({ error: "storage" }, { status: 502 });
  }
  return NextResponse.json({ ok: true });
}
