import { timingSafeEqual } from "crypto";
import { NextResponse } from "next/server";
import { listLeads, leadsBackend } from "@/lib/leads";

export const dynamic = "force-dynamic";

const COLS = ["source", "email", "name", "createdAt", "acceptedAt", "termsVersion", "paymentMethod", "marketingOptIn", "followsInstagram"];

function same(a: string, b: string) {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

const cell = (v: unknown) => {
  let s = v === undefined ? "" : String(v);
  if (/^[=+\-@]/.test(s)) s = "'" + s; // evita fórmulas ao abrir no Excel/Planilhas
  return `"${s.replace(/"/g, '""')}"`;
};

/** Exporta os cadastros em CSV. Protegido pela chave PREVENDA_ADMIN_KEY (?key=... ou Authorization: Bearer ...). */
export async function GET(req: Request) {
  const admin = process.env.PREVENDA_ADMIN_KEY;
  const url = new URL(req.url);
  const given = url.searchParams.get("key") ?? req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!admin || !same(given, admin)) return new NextResponse("não autorizado", { status: 401, headers: { "Cache-Control": "no-store" } });
  if (leadsBackend() !== "redis") return new NextResponse("listagem indisponível: nenhum banco conectado", { status: 501 });

  let leads;
  try {
    leads = await listLeads();
  } catch {
    return new NextResponse("erro ao ler o banco", { status: 502 });
  }
  leads.sort((a, b) => String(a.createdAt ?? a.acceptedAt ?? "").localeCompare(String(b.createdAt ?? b.acceptedAt ?? "")));
  const csv = [COLS.join(","), ...leads.map((l) => COLS.map((c) => cell(l[c])).join(","))].join("\n");
  return new NextResponse("﻿" + csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": 'attachment; filename="sovee-cadastros.csv"',
      "Cache-Control": "no-store",
      "X-Robots-Tag": "noindex",
    },
  });
}
