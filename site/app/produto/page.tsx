import Link from "next/link";
import type { Metadata } from "next";
import LampDrawing from "@/components/LampDrawing";
import PageShell from "@/components/PageShell";
import Wordmark from "@/components/Wordmark";
import { content, ui } from "@/lib/i18n";
import { getLang } from "@/lib/lang";

export function generateMetadata(): Metadata {
  return ui[getLang()].meta.product;
}

export default function Produto() {
  const lang = getLang();
  const c = content[lang].produto;
  return (
    <PageShell>
      <section className="buy-grid pg-hero">
        <LampDrawing />
        <div className="buy-col">
          <p className="buy-eyebrow">{c.eyebrow}</p>
          <h1 className="buy-title" aria-label={c.title}><Wordmark className="wordmark-title" /></h1>
          <p className="buy-lead">{c.lead}</p>
          <p className="buy-note">{c.note}</p>
          <Link href="/pre-venda" className="buy-btn pg-cta">
            {c.cta}
          </Link>
        </div>
      </section>

      <section className="pg-section" aria-labelledby="steps-h">
        <h2 id="steps-h" className="pg-h2">{c.stepsTitle}</h2>
        <p className="pg-p" style={{ marginBottom: 16 }}>
          <Link href="/como-funciona" className="hw-link">{ui[lang].product.seeAnimation}</Link>
        </p>
        <ol className="pg-steps">
          {c.steps.map((s, i) => (
            <li key={s.t}>
              <span aria-hidden="true">{i + 1}</span>
              <h3>{s.t}</h3>
              <p>{s.d}</p>
            </li>
          ))}
        </ol>
      </section>

      <section className="pg-section" aria-labelledby="feat-h">
        <h2 id="feat-h" className="pg-h2">{c.featuresTitle}</h2>
        <ul className="pg-cards">
          {c.features.map((f) => (
            <li key={f.t}>
              <h3>{f.t}</h3>
              <p>{f.d}</p>
            </li>
          ))}
        </ul>
      </section>
    </PageShell>
  );
}
