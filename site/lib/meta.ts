import type { Metadata } from "next";

export const SITE_URL = "https://sovee.com.br";
const OG_IMAGE = { url: `${SITE_URL}/og.jpg`, width: 1200, height: 630, alt: "o Day Finisher SOVEE aceso sobre o criado-mudo, à noite" };

/** Metadados de uma página: título, descrição, canonical, Open Graph e cartão do Twitter. */
export function pageMeta(path: string, title: string, description: string): Metadata {
  return {
    title,
    description,
    alternates: { canonical: `${SITE_URL}${path}` },
    openGraph: { title, description, url: `${SITE_URL}${path}`, siteName: "SOVEE", locale: "pt_BR", type: "website", images: [OG_IMAGE] },
    twitter: { card: "summary_large_image", title, description, images: [OG_IMAGE.url] },
  };
}
