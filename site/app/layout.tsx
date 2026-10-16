import type { Metadata, Viewport } from "next";
import { DM_Sans } from "next/font/google";
import "./globals.css";

// Neue Machina fica de fora até a licença comercial ser confirmada: DM Sans em tudo.
const dmSans = DM_Sans({ subsets: ["latin"], variable: "--font-dm-sans", display: "swap" });

export const metadata: Metadata = {
  title: "SOVEE — durma sem pegar no celular.",
  description: "A luminária circadiana que transforma a hora de dormir em ritual.",
};

export const viewport: Viewport = { themeColor: "#444444" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className={dmSans.variable}>
      <body>{children}</body>
    </html>
  );
}
