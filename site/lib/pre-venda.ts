/**
 * Pré-venda do Day Finisher SOVEE.
 *
 * Os termos e a política de privacidade abaixo vêm do texto enviado pelo dono da marca.
 * A pré-venda só abre quando NENHUM trecho tiver mais "[...]" (campos a preencher),
 * e quando os links de pagamento e o destino dos cadastros estiverem configurados.
 * Ao mudar o texto, mude TERMS_VERSION: ela é gravada junto com o aceite de cada pessoa.
 */
import { leadsBackend } from "./leads";

export const TERMS_VERSION = "2026-10-20";

export const SINAL = 100; // R$, à vista (não parcelável)
export const SINAL_PIX = 95; // R$ 5 de desconto no Pix
export const VAGAS = 50;
export const INSTAGRAM = { handle: "the.sovee", url: "https://instagram.com/the.sovee" };

export type Clause = { n: number; title: string; text: string };
export type LegalDoc = { heading: string; clauses: Clause[] };

export const DOCS: LegalDoc[] = [
  {
    heading: "Termos de pré-venda",
    clauses: [
      { n: 1, title: "Objeto", text: "Estes Termos regem a pré-venda da luminária SOVEE, realizada pelo site sovee.com.br, limitada a 50 (cinquenta) unidades do primeiro lote de produção. Cada unidade desta pré-venda recebe numeração individual gravada na base, correspondente ao número do pedido (ex.: pedido nº 7 recebe a numeração “007”), e dá direito aos benefícios descritos no item 3." },
      { n: 2, title: "Preço e pagamento", text: "A reserva do lugar na fila é feita mediante sinal de R$100,00 (cem reais) por unidade, pago à vista no ato do pedido — o sinal não é parcelável. Pagamento do sinal via Pix tem desconto de R$5,00, reduzindo o valor para R$95,00. O valor restante — R$499,00 (preço de lançamento) ou R$549,00 (preço cheio), conforme a tabela vigente no momento do pedido — é cobrado somente no momento do envio do produto, antes do despacho. Esgotadas as 50 unidades, novos pedidos não têm mais acesso a este preço nem a estes benefícios." },
      { n: 3, title: "Benefícios da pré-venda", text: "Além do produto, o pagamento do sinal garante aos primeiros 50 compradores: (a) numeração individual gravada na base da luminária, correspondente ao número do pedido; e (b) desconto de 30% (trinta por cento) na compra de uma segunda unidade do mesmo modelo, ou de futuros lançamentos da SOVEE, sem prazo de validade. O direito ao desconto fica registrado no cadastro do comprador (vinculado ao CPF e ao número do pedido) no sistema de vendas da SOVEE, e é aplicado automaticamente em compras futuras feitas com o mesmo cadastro — a numeração física da peça serve como comprovação adicional, caso necessário." },
      { n: 4, title: "Prazo de produção e entrega", text: "O prazo estimado para produção e entrega é de até 3 (três) meses, contados da data de confirmação do pagamento. Trata-se de estimativa de boa-fé baseada em protótipo já funcional; eventuais atrasos serão comunicados por e-mail e nas atualizações públicas de produção, com nova data estimada." },
      { n: 5, title: "Direito de arrependimento e reembolso", text: "Nos termos do art. 49 do Código de Defesa do Consumidor (Lei 8.078/1990), o comprador pode desistir da compra em até 7 (sete) dias corridos a contar da confirmação do pedido, com reembolso integral do sinal e sem necessidade de justificativa. Adicionalmente, a SOVEE garante ao comprador o direito de solicitar reembolso integral do sinal a qualquer momento antes do envio do produto, mediante e-mail para [e-mail de contato]. Caso o comprador desista após o pagamento do saldo restante (cobrado no envio), o reembolso segue as mesmas condições do item 6." },
      { n: 6, title: "Atraso além do prazo estimado", text: "Caso o prazo do item 3 seja ultrapassado em mais de 30 (trinta) dias sem comunicação prévia de nova data, o comprador poderá solicitar o cancelamento do pedido com reembolso integral, sem ônus." },
      { n: 7, title: "Limite do lote", text: "Esta pré-venda cobre exclusivamente as 50 unidades do primeiro lote, com o sinal e os benefícios do item 3. Lotes futuros serão vendidos a preço cheio, sem o mecanismo de sinal e sem os benefícios de fundador deste item. Pedidos após o esgotamento deste lote entram em lista de espera para lotes futuros, sem garantia de prazo, preço ou condições iguais a estas." },
      { n: 8, title: "Identificação do vendedor", text: "[Razão social da SLU], CNPJ [preencher], com sede em [endereço], e-mail de contato [preencher], telefone/WhatsApp [preencher]." },
      { n: 9, title: "Foro", text: "Fica eleito o foro da comarca de Porto Alegre/RS para dirimir questões decorrentes destes Termos, sem prejuízo do direito do consumidor de acionar o foro de seu próprio domicílio, conforme o CDC." },
    ],
  },
  {
    heading: "Política de privacidade (LGPD)",
    clauses: [
      { n: 1, title: "Dados coletados", text: "Nome, e-mail, telefone/WhatsApp, endereço de entrega, e dados de pagamento — estes últimos processados diretamente pelo meio de pagamento escolhido (plataforma de pagamento a definir), sem armazenamento direto pela SOVEE." },
      { n: 2, title: "Finalidade", text: "Processar a reserva e o pagamento, emitir nota fiscal, comunicar atualizações de produção e entrega, e enviar comunicações de marketing apenas mediante consentimento específico (opt-in separado da compra)." },
      { n: 3, title: "Compartilhamento", text: "Dados podem ser compartilhados com processadores de pagamento, transportadoras/correios para entrega, e ferramentas de agendamento de conteúdo (ex.: Metricool) apenas quando aplicável à comunicação com o cliente. Nenhum dado é vendido a terceiros." },
      { n: 4, title: "Direitos do titular", text: "Conforme a Lei Geral de Proteção de Dados (Lei 13.709/2018), o titular pode solicitar a qualquer momento: acesso aos dados, correção, exclusão, portabilidade e revogação do consentimento para comunicações de marketing — mediante e-mail para [e-mail de contato]." },
      { n: 5, title: "Retenção", text: "Os dados são mantidos enquanto durar a relação comercial (pré-venda, produção e entrega) e pelo prazo adicional exigido por obrigações fiscais e legais." },
      { n: 6, title: "Contato do controlador", text: "[Razão social da SLU], e-mail [preencher], responsável por questões de privacidade: [preencher]." },
    ],
  },
];

/** Campos "[...]" que ainda faltam preencher nos termos. */
export const PLACEHOLDERS = Array.from(new Set(DOCS.flatMap((d) => d.clauses).flatMap((c) => c.text.match(/\[[^\]]+\]/g) ?? [])));

/** A pré-venda só abre com termos completos, os dois links de pagamento e o destino dos cadastros. */
export function preVendaConfigured() {
  return (
    PLACEHOLDERS.length === 0 &&
    !!process.env.PREVENDA_PAYMENT_URL_PIX &&
    !!process.env.PREVENDA_PAYMENT_URL_CARTAO &&
    leadsBackend() !== null
  );
}

/** A lista de espera (e-mail antes da abertura) só precisa de um lugar para guardar os cadastros. */
export function waitlistConfigured() {
  return leadsBackend() !== null;
}
