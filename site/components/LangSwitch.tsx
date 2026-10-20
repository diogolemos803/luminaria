"use client";

import { LANGS } from "@/lib/i18n";
import { useLang } from "./LangProvider";

/** Troca de idioma: PT / EN / ES. */
export default function LangSwitch({ className = "" }: { className?: string }) {
  const { lang, t, setLang } = useLang();
  return (
    <div className={`lang-sw ${className}`} role="group" aria-label={t.langLabel}>
      {LANGS.map((l) => (
        <button key={l} type="button" lang={l} aria-pressed={lang === l} onClick={() => setLang(l)}>
          {l.toUpperCase()}
        </button>
      ))}
    </div>
  );
}
