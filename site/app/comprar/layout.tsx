import type { Metadata } from "next";
import { ui } from "@/lib/i18n";
import { getLang } from "@/lib/lang";

export function generateMetadata(): Metadata {
  return ui[getLang()].meta.buy;
}

export default function ComprarLayout({ children }: { children: React.ReactNode }) {
  return children;
}
