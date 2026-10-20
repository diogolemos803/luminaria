import type { Metadata } from "next";
import ListaForm from "@/components/ListaForm";
import PageShell from "@/components/PageShell";
import { pageMeta } from "@/lib/meta";

export const metadata: Metadata = pageMeta("/lista", "Lista de espera SOVEE", "Entre na lista e avisamos você primeiro, assim que o Day Finisher SOVEE estiver disponível.");

/** Lista de espera (conteúdo só em português). */
export default function Lista() {
  return (
    <PageShell>
      <article className="pg-article ls" lang="pt-BR">
        <p className="buy-eyebrow">lista de espera</p>
        <h1 className="pg-h1">quer descansar de verdade?</h1>
        <p className="buy-lead">entre na lista e avisamos você primeiro, assim que o Day Finisher SOVEE estiver disponível.</p>
        <ListaForm />
      </article>
    </PageShell>
  );
}
