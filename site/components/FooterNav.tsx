import Link from "next/link";
import type { UI } from "@/lib/i18n";

/** Links do rodapé de todas as páginas: as páginas do site, mais instagram, privacidade e lista de espera. */
export default function FooterNav({ nav, label }: { nav: UI["nav"]; label: string }) {
  return (
    <nav aria-label={label}>
      <Link href="/produto">{nav.product}</Link>
      <Link href="/como-funciona">{nav.how}</Link>
      <Link href="/sobre">{nav.about}</Link>
      <Link href="/ciencia-do-sono">{nav.science}</Link>
      <a href="https://instagram.com/the.sovee" target="_blank" rel="noopener noreferrer">{nav.instagram}</a>
      <Link href="/privacidade">{nav.privacy}</Link>
      <Link href="/lista">{nav.waitlist}</Link>
    </nav>
  );
}
