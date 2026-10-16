import Link from "next/link";

const nav = [
  { label: "produto", href: "/produto" },
  { label: "sobre", href: "/sobre" },
  { label: "a ciência do sono", href: "/ciencia-do-sono" },
  { label: "adquira", href: "/comprar" },
];

/** Moldura comum das páginas internas: topo com voltar e logo, conteúdo e rodapé de navegação. */
export default function PageShell({ children }: { children: React.ReactNode }) {
  return (
    <main className="buy pg">
      <header className="buy-top">
        <Link href="/" className="buy-back" aria-label="voltar ao quarto">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M15 5l-7 7 7 7" />
          </svg>
          <span>voltar ao quarto</span>
        </Link>
        <div className="buy-brand" aria-label="sovee">
          <i className="brand-mark" aria-hidden="true" />
          <span>sovee</span>
        </div>
      </header>
      <div className="pg-body">{children}</div>
      <footer className="pg-foot">
        <nav aria-label="páginas">
          {nav.map((n) => (
            <Link key={n.href} href={n.href}>
              {n.label}
            </Link>
          ))}
        </nav>
        <p>hora de desligar.</p>
      </footer>
    </main>
  );
}
