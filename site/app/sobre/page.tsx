import Link from "next/link";
import type { Metadata } from "next";
import PageShell from "@/components/PageShell";
import content from "@/lib/content.json";

export const metadata: Metadata = {
  title: "Sobre a SOVEE",
  description: "A luminária circadiana que transforma a hora de dormir em ritual.",
};

export default function Sobre() {
  const c = content.sobre;
  return (
    <PageShell>
      <article className="pg-article">
        <p className="buy-eyebrow">{c.eyebrow}</p>
        <h1 className="pg-h1">{c.title}</h1>
        <p className="buy-lead">{c.lead}</p>
        {c.paragraphs.map((p) => (
          <p key={p} className="pg-p">{p}</p>
        ))}
        <h2 className="pg-h2">{c.valuesTitle}</h2>
        <ul className="pg-cards pg-cards-3">
          {c.values.map((v) => (
            <li key={v.t}>
              <h3>{v.t}</h3>
              <p>{v.d}</p>
            </li>
          ))}
        </ul>
        <p className="pg-closing">{c.closing}</p>
        <Link href="/produto" className="buy-btn pg-cta">conheça a luminária</Link>
      </article>
    </PageShell>
  );
}
