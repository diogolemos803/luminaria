import { NextResponse } from "next/server";
import { waitlistConfigured } from "@/lib/pre-venda";
import { saveLead } from "@/lib/leads";

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
    await saveLead({ email, name, source: "lista-de-espera", createdAt: new Date().toISOString() });
  } catch {
    return NextResponse.json({ error: "storage" }, { status: 502 });
  }
  return NextResponse.json({ ok: true });
}
