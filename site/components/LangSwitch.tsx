"use client";

import { useEffect, useRef, useState } from "react";
import { LANGS, type Lang } from "@/lib/i18n";
import { useLang } from "./LangProvider";

const names: Record<Lang, string> = { pt: "Português", en: "English", es: "Español" };

/** Idioma: mostra só o selecionado; ao tocar, aparecem os outros. */
export default function LangSwitch({ className = "" }: { className?: string }) {
  const { lang, t, setLang } = useLang();
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: PointerEvent) => {
      if (!box.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("pointerdown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("pointerdown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div className={`lang-sw ${className}`} ref={box}>
      <button type="button" className="lang-cur" aria-haspopup="true" aria-expanded={open} aria-label={`${t.langLabel}: ${names[lang]}`} onClick={() => setOpen((o) => !o)}>
        {lang.toUpperCase()}
        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>
      {open && (
        <div className="lang-pop" role="group" aria-label={t.langLabel}>
          {LANGS.filter((l) => l !== lang).map((l) => (
            <button
              key={l}
              type="button"
              lang={l}
              onClick={() => {
                setLang(l);
                setOpen(false);
              }}
            >
              {names[l]}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
