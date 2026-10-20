import type { Metadata } from "next";
import PageShell from "@/components/PageShell";
import { content, ui } from "@/lib/i18n";
import { getLang } from "@/lib/lang";

export function generateMetadata(): Metadata {
  return ui[getLang()].meta.science;
}

export default function Ciencia() {
  const c = content[getLang()].ciencia;
  return (
    <PageShell>
      <article className="pg-article">
        <p className="buy-eyebrow">{c.eyebrow}</p>
        <h1 className="pg-h1">{c.title}</h1>
        <p className="buy-lead">{c.lead}</p>
        {c.sections.map((s) => (
          <section key={s.t} className="pg-sec">
            <h2 className="pg-h2">{s.t}</h2>
            {s.p.map((p) => (
              <p key={p} className="pg-p">{p}</p>
            ))}
          </section>
        ))}
        <p className="pg-disclaimer">{c.disclaimer}</p>
        <section className="pg-sec">
          <h2 className="pg-h2">{c.refsTitle}</h2>
          <ul className="pg-refs">
            {c.refs.map((r) => (
              <li key={r}>{r}</li>
            ))}
          </ul>
        </section>
      </article>
    </PageShell>
  );
}
