"use client";

import { FormEvent, useState } from "react";
import type { TermsSection } from "@/lib/pre-venda";

type Props = {
  open: boolean;
  terms: TermsSection[];
  termsVersion: string;
  sinal: number;
  vagas: number;
  instagram: { handle: string; url: string };
};

/** Pré-venda em 4 passos: e-mail, Instagram, termos e sinal. O link de pagamento só vem depois de gravar o aceite. */
export default function PreVendaForm({ open, terms, termsVersion, sinal, vagas, instagram }: Props) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [website, setWebsite] = useState(""); // isca anti-robô
  const [igOpened, setIgOpened] = useState(false);
  const [follows, setFollows] = useState(false);
  const [accepted, setAccepted] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const ready = email.includes("@") && follows && accepted && !busy;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!ready) return;
    setBusy(true);
    setError("");
    try {
      const res = await fetch("/api/pre-venda", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, email, website, acceptedTerms: accepted, termsVersion, followsInstagram: follows }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok && data.paymentUrl) {
        window.location.assign(data.paymentUrl);
        return;
      }
      setError(
        data.error === "email"
          ? "Confira o e-mail digitado."
          : res.status === 503
            ? "A pré-venda ainda não abriu. Siga a gente no Instagram para saber quando abrir."
            : "Não foi possível registrar agora. Tente de novo em instantes. Nenhuma cobrança foi feita.",
      );
    } catch {
      setError("Sem conexão. Tente de novo. Nenhuma cobrança foi feita.");
    }
    setBusy(false);
  }

  const IgLink = ({ className }: { className: string }) => (
    <a className={className} href={instagram.url} target="_blank" rel="noopener noreferrer" onClick={() => setIgOpened(true)}>
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <rect x="4" y="4" width="16" height="16" rx="5" />
        <circle cx="12" cy="12" r="3.6" />
        <path d="M16.8 7.2h.01" />
      </svg>
      seguir @{instagram.handle}
    </a>
  );

  if (!open) {
    return (
      <section className="pv-card pv-closed" role="status">
        <h2>A pré-venda abre em breve</h2>
        <p>Estamos finalizando os termos e o pagamento. Siga a SOVEE no Instagram para ser avisado quando abrir.</p>
        <IgLink className="buy-btn" />
      </section>
    );
  }

  return (
    <form className="pv-card buy-form" onSubmit={onSubmit} noValidate>
      <section className="pv-step" aria-labelledby="pv1">
        <h2 id="pv1"><span>1</span> seu e-mail</h2>
        <label htmlFor="pv-name">nome</label>
        <input id="pv-name" name="name" autoComplete="name" value={name} onChange={(e) => setName(e.target.value)} />
        <label htmlFor="pv-email">e-mail</label>
        <input id="pv-email" name="email" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        <div className="pv-trap" aria-hidden="true">
          <label htmlFor="pv-site">não preencha</label>
          <input id="pv-site" name="website" tabIndex={-1} autoComplete="off" value={website} onChange={(e) => setWebsite(e.target.value)} />
        </div>
      </section>

      <section className="pv-step" aria-labelledby="pv2">
        <h2 id="pv2"><span>2</span> siga a sovee no instagram</h2>
        <p className="pv-p">Avisos da fila e da abertura de cada lote saem primeiro por lá.</p>
        <IgLink className="buy-btn pv-ig" />
        <label className="pv-check">
          <input type="checkbox" checked={follows} disabled={!igOpened} onChange={(e) => setFollows(e.target.checked)} />
          <span>Já sigo @{instagram.handle}</span>
        </label>
        {!igOpened && <p className="buy-note">Abra o perfil e siga para liberar esta opção.</p>}
      </section>

      <section className="pv-step" aria-labelledby="pv3">
        <h2 id="pv3"><span>3</span> termos da pré-venda</h2>
        <div className="pv-terms" tabIndex={0} role="region" aria-label="termos da pré-venda">
          {terms.map((s) => (
            <section key={s.title}>
              <h3>{s.title}</h3>
              {s.body.map((p) => (
                <p key={p}>{p}</p>
              ))}
            </section>
          ))}
        </div>
        <label className="pv-check">
          <input type="checkbox" checked={accepted} onChange={(e) => setAccepted(e.target.checked)} />
          <span>Li e aceito os termos da pré-venda.</span>
        </label>
      </section>

      <section className="pv-step" aria-labelledby="pv4">
        <h2 id="pv4"><span>4</span> sinal de R$ {sinal}</h2>
        <p className="pv-p">
          Garante seu lugar entre as {vagas} primeiras unidades. O valor é abatido do preço final do Day Finisher.
        </p>
        <button type="submit" className="buy-btn" disabled={!ready}>
          {busy ? "registrando..." : `garantir minha vaga por R$ ${sinal}`}
        </button>
        {error && <p className="pv-error" role="alert">{error}</p>}
        <p className="buy-note">Você será levado ao pagamento seguro. Seus dados só são gravados depois que você aceitar os termos.</p>
      </section>
    </form>
  );
}
