"use client";

import { setConsent } from "@/lib/cookies";

/** Na página de privacidade: deixa a pessoa refazer a escolha de cookies. */
export default function CookiePrefs() {
  return (
    <button type="button" className="cookie-reset" onClick={() => setConsent(null)}>
      alterar minha escolha de cookies
    </button>
  );
}
