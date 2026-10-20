"use client";

import { createContext, useCallback, useContext, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { htmlLang, ui, type Lang, type UI } from "@/lib/i18n";

type Ctx = { lang: Lang; t: UI; setLang: (l: Lang) => void };
const LangCtx = createContext<Ctx | null>(null);

export function LangProvider({ initial, children }: { initial: Lang; children: React.ReactNode }) {
  const [lang, setLangState] = useState<Lang>(initial);
  const router = useRouter();

  useEffect(() => setLangState(initial), [initial]);

  const setLang = useCallback(
    (l: Lang) => {
      try {
        document.cookie = `lang=${l}; path=/; max-age=31536000; samesite=lax`;
      } catch {}
      document.documentElement.lang = htmlLang[l];
      setLangState(l);
      router.refresh(); // as páginas de servidor releem o cookie
    },
    [router],
  );

  return <LangCtx.Provider value={{ lang, t: ui[lang], setLang }}>{children}</LangCtx.Provider>;
}

export function useLang(): Ctx {
  const c = useContext(LangCtx);
  if (!c) throw new Error("useLang fora do LangProvider");
  return c;
}
