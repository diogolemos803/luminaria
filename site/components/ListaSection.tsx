import ListaForm from "./ListaForm";

/** Lista de espera: última dobra da landing (conteúdo só em português). */
export default function ListaSection() {
  return (
    <section id="lista" className="lista-section" lang="pt-BR" aria-labelledby="lista-titulo">
      <div className="ls">
        <p className="buy-eyebrow">lista de espera</p>
        <h2 id="lista-titulo" className="pg-h1">quer descansar de verdade?</h2>
        <p className="buy-lead">entre na lista e avisamos você primeiro, assim que o Day Finisher SOVEE estiver disponível.</p>
        <ListaForm />
      </div>
    </section>
  );
}
