import { cookies } from "next/headers";
import { isLang, type Lang } from "./i18n";

/** Idioma da requisição: o cookie da escolha do visitante; sem escolha, português (também para buscadores e prévias de links). */
export function getLang(): Lang {
  const saved = cookies().get("lang")?.value;
  return isLang(saved) ? saved : "pt";
}
