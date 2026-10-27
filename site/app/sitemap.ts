import type { MetadataRoute } from "next";
import { SITE_URL } from "@/lib/meta";

const pages = ["/", "/produto", "/sobre", "/ciencia-do-sono"];

export default function sitemap(): MetadataRoute.Sitemap {
  return pages.map((p) => ({ url: `${SITE_URL}${p === "/" ? "" : p}` }));
}
