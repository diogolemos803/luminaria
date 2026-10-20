# Página de compra congelada

Esta pasta começa com `_`, então o Next.js **não** cria rota para ela: a página de compra
(demonstração, sem pagamento real) está escondida e guardada. `/comprar` redireciona para
`/pre-venda` (ver `next.config.mjs`).

Para reativar: renomeie a pasta para `app/comprar` e remova o redirecionamento.
