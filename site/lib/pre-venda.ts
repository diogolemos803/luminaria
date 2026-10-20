/**
 * Pré-venda do Day Finisher SOVEE.
 *
 * TERMS_READY só vira true quando os termos completos (enviados pelo dono da marca) estiverem
 * em TERMS abaixo. Enquanto for false, a página mostra "abre em breve" e o pagamento não abre.
 * Ao trocar o texto dos termos, mude TERMS_VERSION: ela é gravada junto com o aceite de cada pessoa.
 */
export const TERMS_READY = false;
export const TERMS_VERSION = "pendente";

export const SINAL = 100; // R$, abatido do preço final
export const VAGAS = 50;
export const INSTAGRAM = { handle: "the.sovee", url: "https://instagram.com/the.sovee" };

export type TermsSection = { title: string; body: string[] };

export const TERMS: TermsSection[] = [
  { title: "termos em elaboração", body: ["Os termos completos da pré-venda serão publicados aqui antes da abertura."] },
];

/** A pré-venda só abre com termos prontos, link de pagamento e destino dos e-mails configurados. */
export function preVendaConfigured() {
  return TERMS_READY && !!process.env.PREVENDA_PAYMENT_URL && !!process.env.PREVENDA_WEBHOOK_URL;
}
