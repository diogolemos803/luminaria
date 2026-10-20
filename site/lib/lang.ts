import { cookies, headers } from "next/headers";
import { isLang, type Lang } from "./i18n";

/** Idioma da requisição: cookie da escolha do visitante; senão o idioma do navegador. */
export function getLang(): Lang {
  const saved = cookies().get("lang")?.value;
  if (isLang(saved)) return saved;
  const al = (headers().get("accept-language") ?? "").toLowerCase();
  if (!al) return "pt";
  const first = al.split(",")[0].trim();
  if (first.startsWith("pt")) return "pt";
  if (first.startsWith("es")) return "es";
  return "en";
}
