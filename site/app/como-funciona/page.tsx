import type { Metadata } from "next";
import HowItWorks from "@/components/HowItWorks";
import { ui } from "@/lib/i18n";
import { getLang } from "@/lib/lang";
import { pageMeta } from "@/lib/meta";

export function generateMetadata(): Metadata {
  const m = ui[getLang()].meta.how;
  return pageMeta("/como-funciona", m.title, m.description);
}

export default function ComoFunciona() {
  return <HowItWorks />;
}
