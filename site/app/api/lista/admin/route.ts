import { timingSafeEqual } from "crypto";
import { NextResponse } from "next/server";
import { listSubscribers, listaConfigured, removeSubscriber } from "@/lib/lista";

export const dynamic = "force-dynamic";

/**
 * Administração da lista, protegida pela variável LISTA_ADMIN_KEY (?key=... ou Authorization: Bearer ...).
 *  GET                      -> baixa a lista em CSV
 *  DELETE ?email=a@b.com    -> remove a pessoa da lista a pedido
 */
const COLS = ["nome", "email", "consentimento", "consentimento_em", "consentimento_texto", "utm_source", "utm_medium", "utm_campaign", "utm_content", "pagina_origem", "event_id"] as const;
const noStore = { "Cache-Control": "no-store", "X-Robots-Tag": "noindex" };

function authorized(req: Request) {
  const admin = process.env.LISTA_ADMIN_KEY;
  const given = new URL(req.url).searchParams.get("key") ?? req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!admin || !given) return false;
  const a = Buffer.from(given);
  const b = Buffer.from(admin);
  return a.length === b.length && timingSafeEqual(a, b);
}

const cell = (v: unknown) => {
  let s = v === undefined || v === null ? "" : String(v);
  if (/^[=+\-@\t\r]/.test(s)) s = "'" + s; // evita que o Excel/Planilhas executem fórmulas
  return `"${s.replace(/"/g, '""')}"`;
};

export async function GET(req: Request) {
  if (!authorized(req)) return new NextResponse("não autorizado", { status: 401, headers: noStore });
  if (!listaConfigured()) return new NextResponse("nenhum banco conectado", { status: 501, headers: noStore });
  try {
    const rows = (await listSubscribers()).sort((x, y) => x.consentimento_em.localeCompare(y.consentimento_em));
    const csv = [COLS.join(","), ...rows.map((r) => COLS.map((c) => cell(r[c])).join(","))].join("\n");
    return new NextResponse("﻿" + csv, {
      headers: { ...noStore, "Content-Type": "text/csv; charset=utf-8", "Content-Disposition": 'attachment; filename="sovee-lista-de-espera.csv"' },
    });
  } catch {
    return new NextResponse("erro ao ler o banco", { status: 502, headers: noStore });
  }
}

export async function DELETE(req: Request) {
  if (!authorized(req)) return new NextResponse("não autorizado", { status: 401, headers: noStore });
  const email = new URL(req.url).searchParams.get("email") ?? "";
  if (!email.includes("@")) return NextResponse.json({ error: "informe ?email=" }, { status: 400, headers: noStore });
  try {
    const removed = await removeSubscriber(email);
    return NextResponse.json({ removed }, { headers: noStore });
  } catch {
    return NextResponse.json({ error: "erro" }, { status: 502, headers: noStore });
  }
}
