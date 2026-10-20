import type { Metadata } from "next";
import HowItWorks from "@/components/HowItWorks";
import { ui } from "@/lib/i18n";
import { getLang } from "@/lib/lang";

export function generateMetadata(): Metadata {
  return ui[getLang()].meta.how;
}

export default function ComoFunciona() {
  return <HowItWorks />;
}
