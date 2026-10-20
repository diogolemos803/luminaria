import type { Metadata, Viewport } from "next";
import { DM_Sans } from "next/font/google";
import "./globals.css";
import { LangProvider } from "@/components/LangProvider";
import { getLang } from "@/lib/lang";
import { htmlLang, ui } from "@/lib/i18n";

// Neue Machina fica de fora até a licença comercial ser confirmada: DM Sans em tudo.
const dmSans = DM_Sans({ subsets: ["latin"], variable: "--font-dm-sans", display: "swap" });

export function generateMetadata(): Metadata {
  return ui[getLang()].meta.home;
}

export const viewport: Viewport = { themeColor: "#444444" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const lang = getLang();
  return (
    <html lang={htmlLang[lang]} className={dmSans.variable}>
      <body>
        <LangProvider initial={lang}>{children}</LangProvider>
      </body>
    </html>
  );
}
