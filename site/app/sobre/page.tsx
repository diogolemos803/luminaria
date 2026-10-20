import Link from "next/link";
import type { Metadata } from "next";
import PageShell from "@/components/PageShell";
import { content, ui } from "@/lib/i18n";
import { getLang } from "@/lib/lang";
import { pageMeta } from "@/lib/meta";

export function generateMetadata(): Metadata {
  const m = ui[getLang()].meta.about;
  return pageMeta("/sobre", m.title, m.description);
}

export default function Sobre() {
  const lang = getLang();
  const c = content[lang].sobre;
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
        <Link href="/produto" className="buy-btn pg-cta">{ui[lang].about.cta}</Link>
      </article>
    </PageShell>
  );
}
