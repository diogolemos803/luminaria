import type { Metadata } from "next";
import PageShell from "@/components/PageShell";
import PreVendaForm from "@/components/PreVendaForm";
import { DOCS, INSTAGRAM, SINAL, SINAL_PIX, TERMS_VERSION, VAGAS, preVendaConfigured, waitlistConfigured } from "@/lib/pre-venda";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Pré-venda SOVEE",
  description: `Quer descansar de verdade? Garanta sua vaga entre as ${VAGAS} primeiras unidades do Day Finisher SOVEE.`,
};

/** Pré-venda: conteúdo só em português (sinal em reais). */
export default function PreVenda() {
  return (
    <PageShell>
      <article className="pg-article pv" lang="pt-BR">
        <p className="buy-eyebrow">pré-venda · primeiras {VAGAS} unidades</p>
        <h1 className="pg-h1">Quer descansar de verdade?</h1>
        <p className="buy-lead">
          Garanta seu lugar na fila das {VAGAS} primeiras unidades do Day Finisher SOVEE com um sinal de R$ {SINAL} (R$ {SINAL_PIX} no Pix). O restante só é cobrado no envio.
        </p>
        <PreVendaForm open={preVendaConfigured()} waitlist={waitlistConfigured()} docs={DOCS} termsVersion={TERMS_VERSION} sinal={SINAL} sinalPix={SINAL_PIX} vagas={VAGAS} instagram={INSTAGRAM} />
      </article>
    </PageShell>
  );
}
