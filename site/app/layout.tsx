import type { Metadata, Viewport } from "next";
import { DM_Sans } from "next/font/google";
import "./globals.css";
import AttributionCapture from "@/components/AttributionCapture";
import CookieBanner from "@/components/CookieBanner";
import { LangProvider } from "@/components/LangProvider";
import MetaPixel from "@/components/MetaPixel";
import { getLang } from "@/lib/lang";
import { htmlLang, ui } from "@/lib/i18n";
import { SITE_URL, pageMeta } from "@/lib/meta";

// Neue Machina fica de fora até a licença comercial ser confirmada: DM Sans em tudo.
const dmSans = DM_Sans({ subsets: ["latin"], variable: "--font-dm-sans", display: "swap" });

export function generateMetadata(): Metadata {
  const m = ui[getLang()].meta.home;
  return { metadataBase: new URL(SITE_URL), ...pageMeta("/", m.title, m.description) };
}

export const viewport: Viewport = { themeColor: "#444444" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const lang = getLang();
  return (
    <html lang={htmlLang[lang]} className={dmSans.variable}>
      <body>
        <LangProvider initial={lang}>
          {children}
          <AttributionCapture />
          <CookieBanner />
          <MetaPixel />
        </LangProvider>
      </body>
    </html>
  );
}
