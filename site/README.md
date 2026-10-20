# SOVEE: site

Site do Day Finisher SOVEE (Next.js 14, App Router, Tailwind, Framer Motion).

## Rodar

```
npm install
npm run dev      # http://localhost:3000
npm run build    # build de produção
```

## Páginas

- `/` cena do quarto (noite/dia, luz do âmbar ao vermelho, menu, botão lista de espera)
- `/produto`, `/sobre`, `/ciencia-do-sono` textos em `lib/content/` (pt, en e es)
- `/como-funciona` animação que avança com a rolagem (celular encaixando no nicho, luz do Day Finisher, foguete, meteoro e pouso); cenas geradas dos protótipos em `components/scenes/` e `public/como-funciona/`
- `/lista` lista de espera (nome, e-mail e consentimento). `/pre-venda` e `/comprar` redirecionam para ela. Nada no site cobra ou vende.
- política de privacidade (LGPD): escondida por enquanto em `app/_privacidade-oculta` (a pasta com `_` não vira rota). Para publicar, renomeie para `app/privacidade` e religue os links.

## Lista de espera

Grava no Redis da Upstash (Marketplace da Vercel; as variáveis `KV_REST_API_URL` e `KV_REST_API_TOKEN` aparecem ao conectar o banco ao projeto).

- `POST /api/lista` recebe a inscrição.
- `GET /api/lista/admin?key=...` baixa a lista em CSV; `DELETE /api/lista/admin?key=...&email=...` remove alguém a pedido. A chave é a variável `LISTA_ADMIN_KEY`.
- `NEXT_PUBLIC_CONTACT_EMAIL`: e-mail de contato mostrado na política de privacidade.
- `NEXT_PUBLIC_META_PIXEL_ID`: ID do Pixel da Meta. O pixel só carrega depois que o visitante aceita os cookies.

## Deploy na Vercel

- Root Directory: `site`
- Framework: Next.js

## Fonte da marca

O "sovee" usa Neue Machina (uso pessoal). O arquivo fica em `public/fonts/`, fora do git;
sem ele o site cai para DM Sans. Veja `CREDITS.md`.
