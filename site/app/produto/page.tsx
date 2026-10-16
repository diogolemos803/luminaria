import Link from "next/link";
import type { Metadata } from "next";
import LampDrawing from "@/components/LampDrawing";
import PageShell from "@/components/PageShell";
import content from "@/lib/content.json";

export const metadata: Metadata = {
  title: "O Day Finisher SOVEE",
  description: "Uma luz que acompanha o seu sono, do âmbar ao vermelho.",
};

export default function Produto() {
  const c = content.produto;
  return (
    <PageShell>
      <section className="buy-grid pg-hero">
        <LampDrawing />
        <div className="buy-col">
          <p className="buy-eyebrow">{c.eyebrow}</p>
          <h1 className="buy-title">{c.title}</h1>
          <p className="buy-lead">{c.lead}</p>
          <p className="buy-note">{c.note}</p>
          <Link href="/comprar" className="buy-btn pg-cta">
            {c.cta}
          </Link>
        </div>
      </section>

      <section className="pg-section" aria-labelledby="steps-h">
        <h2 id="steps-h" className="pg-h2">{c.stepsTitle}</h2>
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
