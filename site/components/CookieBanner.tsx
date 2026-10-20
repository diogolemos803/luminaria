"use client";

import { setConsent, useConsent } from "@/lib/cookies";

/** Aviso de cookies discreto. Nada de rastreamento carrega antes do aceite. */
export default function CookieBanner() {
  const consent = useConsent();
  if (consent !== null) return null; // "pending" (ainda lendo a escolha) ou já escolheu
  return (
    <div className="cookie-banner" role="region" aria-label="cookies">
      <p>
        usamos cookies para entender o que funciona nos anúncios.
      </p>
      <div>
        <button type="button" onClick={() => setConsent("declined")}>recusar</button>
        <button type="button" className="is-primary" onClick={() => setConsent("accepted")}>aceitar</button>
      </div>
    </div>
  );
}
