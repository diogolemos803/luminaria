import Link from "next/link";
import LangSwitch from "./LangSwitch";
import Wordmark from "./Wordmark";
import { getLang } from "@/lib/lang";
import { ui } from "@/lib/i18n";

/** Moldura comum das páginas internas: topo com voltar e logo, conteúdo e rodapé de navegação. */
export default function PageShell({ children }: { children: React.ReactNode }) {
  const t = ui[getLang()];
  const nav = [
    { label: t.nav.product, href: "/produto" },
    { label: t.nav.how, href: "/como-funciona" },
    { label: t.nav.about, href: "/sobre" },
    { label: t.nav.science, href: "/ciencia-do-sono" },
    { label: t.nav.buy, href: "/comprar" },
  ];
  return (
    <main className="buy pg">
      <header className="buy-top">
        <Link href="/" className="buy-back" aria-label={t.back}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M15 5l-7 7 7 7" />
          </svg>
          <span>{t.back}</span>
        </Link>
        <div className="buy-right">
          <LangSwitch />
          <div className="buy-brand" aria-label="sovee">
            <i className="brand-mark" aria-hidden="true" />
            <Wordmark />
          </div>
        </div>
      </header>
      <div className="pg-body">{children}</div>
      <footer className="pg-foot">
        <nav aria-label={t.pagesNav}>
          {nav.map((n) => (
            <Link key={n.href} href={n.href}>
              {n.label}
            </Link>
          ))}
        </nav>
        <p>{t.tagline}</p>
      </footer>
    </main>
  );
}
