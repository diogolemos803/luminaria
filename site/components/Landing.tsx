"use client";

import { useEffect, useRef, useState } from "react";
import Experience from "./Experience";
import FooterNav from "./FooterNav";
import HowItWorks from "./HowItWorks";
import ListaSection from "./ListaSection";
import { useLang } from "./LangProvider";

/**
 * Landing em uma rolagem só: o quarto, "como funciona" (animação que avança com a rolagem) e a lista de espera.
 * A própria <main> é o rolador (o body do site não rola); a animação mede a rolagem dela.
 */
export default function Landing() {
  const { t } = useLang();
  const scroller = useRef<HTMLElement>(null);
  const [inHero, setInHero] = useState(true);

  useEffect(() => {
    const sc = scroller.current;
    if (!sc) return;
    let raf = 0;
    const on = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => setInHero(sc.scrollTop < sc.clientHeight * 0.55));
    };
    sc.addEventListener("scroll", on, { passive: true });
    on();
    return () => {
      cancelAnimationFrame(raf);
      sc.removeEventListener("scroll", on);
    };
  }, []);

  return (
    <main className="buy hw landing" ref={scroller}>
      <Experience inHero={inHero} />
      <HowItWorks scroller={scroller} />
      <div className="landing-end">
        <ListaSection />
        <footer className="pg-foot landing-foot">
          <FooterNav nav={t.nav} label={t.pagesNav} />
          <p>{t.tagline}</p>
        </footer>
      </div>
    </main>
  );
}
