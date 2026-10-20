"use client";

import { FormEvent, useState } from "react";
import { readAttribution } from "@/lib/attribution";
import { getConsent } from "@/lib/cookies";

type View = "form" | "done";

/** Formulário da lista de espera. Não cobra nada: guarda nome, e-mail e o consentimento. */
export default function ListaForm() {
  const [nome, setNome] = useState("");
  const [email, setEmail] = useState("");
  const [website, setWebsite] = useState(""); // isca anti-robô
  const [consent, setConsent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [view, setView] = useState<View>("form");

  const ready = email.includes("@") && consent && !busy;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!ready) return;
    setBusy(true);
    setError("");
    const eventId = typeof crypto !== "undefined" && "randomUUID" in crypto ? crypto.randomUUID() : String(Date.now()) + Math.random().toString(16).slice(2);
    try {
      const res = await fetch("/api/lista", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nome, email, website, consentimento: true, event_id: eventId, ...readAttribution() }),
      });
      if (res.ok) {
        // Lead do Pixel: só se a pessoa aceitou os cookies. Sem nome nem e-mail; o event_id é o mesmo gravado na lista.
        if (getConsent() === "accepted") window.fbq?.("track", "Lead", {}, { eventID: eventId });
        setView("done");
        return;
      }
      const data = await res.json().catch(() => ({}));
      setError(data.error === "email" ? "confira o e-mail e tente de novo." : "algo deu errado. tente de novo em instantes.");
    } catch {
      setError("algo deu errado. tente de novo em instantes.");
    }
    setBusy(false);
  }

  if (view === "done") {
    return (
      <section className="ls-card ls-done" role="status">
        <h2>pronto. você está na lista. avisamos por e-mail.</h2>
      </section>
    );
  }

  return (
    <form className="ls-card buy-form" onSubmit={onSubmit} noValidate>
      <div className="ls-field">
        <label htmlFor="ls-nome">nome</label>
        <input id="ls-nome" name="nome" autoComplete="name" value={nome} onChange={(e) => setNome(e.target.value)} />
      </div>
      <div className="ls-field">
        <label htmlFor="ls-email">e-mail</label>
        <input id="ls-email" name="email" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
      </div>
      <div className="ls-trap" aria-hidden="true">
        <label htmlFor="ls-site">não preencha</label>
        <input id="ls-site" name="website" tabIndex={-1} autoComplete="off" value={website} onChange={(e) => setWebsite(e.target.value)} />
      </div>
      <label className="ls-check">
        <input type="checkbox" checked={consent} onChange={(e) => setConsent(e.target.checked)} />
        <span>
          Concordo em receber e-mails da SOVEE sobre o lançamento. Posso sair da lista quando quiser.
        </span>
      </label>
      <button type="submit" className="buy-btn" disabled={!ready}>
        {busy ? "..." : "avise-me"}
      </button>
      {error && (
        <p className="ls-error" role="alert">
          {error}
        </p>
      )}
      <p className="buy-note">usamos seu e-mail só para falar do lançamento da SOVEE.</p>
    </form>
  );
}
