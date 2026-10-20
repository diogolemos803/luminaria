import type { Metadata } from "next";
import PageShell from "@/components/PageShell";
import PreVendaForm from "@/components/PreVendaForm";
import { INSTAGRAM, SINAL, TERMS, TERMS_VERSION, VAGAS, preVendaConfigured } from "@/lib/pre-venda";

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
          Garanta seu lugar na fila das {VAGAS} primeiras unidades do Day Finisher SOVEE com um sinal de R$ {SINAL}, que é abatido do preço final.
        </p>
        <PreVendaForm open={preVendaConfigured()} terms={TERMS} termsVersion={TERMS_VERSION} sinal={SINAL} vagas={VAGAS} instagram={INSTAGRAM} />
      </article>
    </PageShell>
  );
}
