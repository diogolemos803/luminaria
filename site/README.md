# SOVEE: site

Site do Day Finisher SOVEE (Next.js 14, App Router, Tailwind, Framer Motion).

## Rodar

```
npm install
npm run dev      # http://localhost:3000
npm run build    # build de produção
```

## Páginas

- `/` cena do quarto (noite/dia, luz do âmbar ao vermelho, menu, botão adquira)
- `/produto`, `/sobre`, `/ciencia-do-sono` textos em `lib/content.json`
- `/comprar` página de compra de demonstração (nenhum pagamento é processado; preço em `app/comprar/page.tsx`)

## Deploy na Vercel

- Root Directory: `site`
- Framework: Next.js

## Fonte da marca

O "sovee" usa Neue Machina (uso pessoal). O arquivo fica em `public/fonts/`, fora do git;
sem ele o site cai para DM Sans. Veja `CREDITS.md`.
