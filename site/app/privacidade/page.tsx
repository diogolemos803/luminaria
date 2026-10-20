import type { Metadata } from "next";
import CookiePrefs from "@/components/CookiePrefs";
import PageShell from "@/components/PageShell";
import { pageMeta } from "@/lib/meta";

export const metadata: Metadata = pageMeta("/privacidade", "Política de Privacidade — SOVEE", "Como a SOVEE cuida dos seus dados na lista de espera.");

// E-mail de contato da política: defina NEXT_PUBLIC_CONTACT_EMAIL na Vercel. Enquanto não houver, aparece o aviso para preencher.
const CONTACT = process.env.NEXT_PUBLIC_CONTACT_EMAIL;
const PENDING = "[E-MAIL DE CONTATO — preencher]";

/** Política de Privacidade (LGPD), em português. Modelo: vale uma revisão jurídica. */
export default function Privacidade() {
  const contact = CONTACT ? <a href={`mailto:${CONTACT}`}>{CONTACT}</a> : <strong>{PENDING}</strong>;
  return (
    <PageShell>
      <article className="pg-article" lang="pt-BR">
        <p className="buy-eyebrow">privacidade</p>
        <h1 className="pg-h1">política de privacidade</h1>
        <p className="buy-lead">como a SOVEE cuida dos seus dados, em linguagem simples.</p>

        <section className="pg-sec">
          <h2 className="pg-h2">quem somos</h2>
          <p className="pg-p">A SOVEE é um projeto de Porto Alegre/RS. O responsável pelos seus dados é Diogo Lemos. Para falar sobre privacidade: {contact}.</p>
        </section>

        <section className="pg-sec">
          <h2 className="pg-h2">quais dados coletamos</h2>
          <ul className="pg-list">
            <li>nome e e-mail, que você informa na lista de espera;</li>
            <li>o texto do consentimento que você viu e a data e a hora em que concordou;</li>
            <li>de onde você veio: os parâmetros utm da página (utm_source, utm_medium, utm_campaign e utm_content) e a primeira página que abriu no site;</li>
            <li>dados de navegação e cookies, somente se você aceitar o aviso de cookies.</li>
          </ul>
        </section>

        <section className="pg-sec">
          <h2 className="pg-h2">para que usamos</h2>
          <p className="pg-p">Para avisar você sobre o lançamento do Day Finisher SOVEE e para medir o alcance dos anúncios da SOVEE.</p>
        </section>

        <section className="pg-sec">
          <h2 className="pg-h2">base legal</h2>
          <p className="pg-p">Seu consentimento (Lei Geral de Proteção de Dados, art. 7º, inciso I). Você pode retirá-lo quando quiser.</p>
        </section>

        <section className="pg-sec">
          <h2 className="pg-h2">com quem compartilhamos</h2>
          <p className="pg-p">
            Com os provedores que fazem o site e a lista funcionarem: hospedagem e armazenamento dos dados (Vercel e Upstash) e, quando houver envio de e-mails, o serviço de envio. Se você aceitar os cookies de anúncio, a Meta (Facebook e Instagram) recebe dados de navegação e de conversão para medir os anúncios; não enviamos seu nome nem seu e-mail. Não vendemos dados.
          </p>
        </section>

        <section className="pg-sec">
          <h2 className="pg-h2">cookies</h2>
          <p className="pg-p">Só carregamos o pixel da Meta depois que você aceita. Se recusar, nada de rastreamento é carregado. Você pode mudar de ideia a qualquer momento.</p>
          <CookiePrefs />
        </section>

        <section className="pg-sec">
          <h2 className="pg-h2">por quanto tempo guardamos</h2>
          <p className="pg-p">Até você sair da lista. Quando você pedir para sair, apagamos seu nome e seu e-mail.</p>
        </section>

        <section className="pg-sec">
          <h2 className="pg-h2">seus direitos</h2>
          <p className="pg-p">
            A lei (LGPD, art. 18) garante que você peça: a confirmação de que tratamos seus dados, o acesso a eles, a correção, a eliminação, a portabilidade, a informação sobre com quem compartilhamos e a revogação do consentimento. Para pedir, escreva para {contact}. Todo e-mail que enviarmos terá um link para sair da lista.
          </p>
        </section>

        <p className="pg-disclaimer">última atualização: 20 de outubro de 2026</p>
      </article>
    </PageShell>
  );
}
