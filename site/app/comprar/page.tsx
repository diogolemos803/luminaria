"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";

// Valor provisório: troque aqui quando o preço for definido.
const PRICE = 890;
const brl = (n: number) => n.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

const inbox = [
  "Luminária SOVEE",
  "Base de madeira com nicho para o celular",
  "Etiqueta NFC que vincula a luminária ao app",
];

const payments = [
  { id: "pix", label: "Pix" },
  { id: "cartao", label: "Cartão de crédito" },
  { id: "boleto", label: "Boleto" },
];

export default function Comprar() {
  const [qty, setQty] = useState(1);
  const [pay, setPay] = useState("pix");
  const [sent, setSent] = useState(false);
  const [lit, setLit] = useState(false);

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    setSent(true);
  };

  return (
    <main className="buy">
      <header className="buy-top">
        <Link href="/" className="buy-back" aria-label="voltar ao quarto">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M15 5l-7 7 7 7" />
          </svg>
          <span>voltar ao quarto</span>
        </Link>
        <div className="buy-brand" aria-label="sovee">
          <i className="brand-mark" aria-hidden="true" />
          <span>sovee</span>
        </div>
      </header>

      <div className="buy-grid">
        <div
          className={`buy-photo ${lit ? "is-lit" : ""}`}
          role="img"
          tabIndex={0}
          aria-label={lit ? "Desenho da luminária SOVEE acesa, com a base e o nicho do celular" : "Desenho da luminária SOVEE apagada, com a base e o nicho do celular"}
          onPointerEnter={(e) => e.pointerType === "mouse" && setLit(true)}
          onPointerLeave={(e) => e.pointerType === "mouse" && setLit(false)}
          onPointerDown={(e) => e.pointerType !== "mouse" && setLit((v) => !v)}
          onFocus={() => setLit(true)}
          onBlur={() => setLit(false)}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/produto/lampada_apagada.webp" alt="" draggable={false} />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="buy-photo-on" src="/produto/lampada_acesa.webp" alt="" draggable={false} />
        </div>

        <div className="buy-col">
          <p className="buy-eyebrow">luminária circadiana</p>
          <h1 className="buy-title">sovee</h1>
          <p className="buy-lead">hora de desligar. Uma luz que acompanha o seu sono, do âmbar ao vermelho.</p>
          <p className="buy-price">
            {brl(PRICE)} <small>por unidade</small>
          </p>

          <section aria-labelledby="inbox-h" className="buy-block">
            <h2 id="inbox-h">na caixa</h2>
            <ul className="buy-list">
              {inbox.map((t) => (
                <li key={t}>{t}</li>
              ))}
            </ul>
          </section>

          {sent ? (
            <section className="buy-done" role="status">
              <h2>pedido recebido</h2>
              <p>
                {qty} {qty === 1 ? "luminária" : "luminárias"} por {brl(PRICE * qty)}. Enviaremos a confirmação para o e-mail informado.
              </p>
              <p className="buy-note">Esta é uma página de demonstração: nenhuma cobrança foi feita.</p>
              <Link href="/" className="buy-btn">
                voltar ao quarto
              </Link>
            </section>
          ) : (
            <form onSubmit={onSubmit} className="buy-form">
              <section className="buy-block" aria-labelledby="qty-h">
                <h2 id="qty-h">quantidade</h2>
                <div className="buy-qty">
                  <button type="button" aria-label="diminuir" onClick={() => setQty((q) => Math.max(1, q - 1))}>−</button>
                  <output aria-live="polite">{qty}</output>
                  <button type="button" aria-label="aumentar" onClick={() => setQty((q) => Math.min(9, q + 1))}>+</button>
                </div>
              </section>

              <fieldset className="buy-block">
                <legend>contato</legend>
                <label htmlFor="nome">nome completo</label>
                <input id="nome" name="nome" autoComplete="name" required />
                <label htmlFor="email">e-mail</label>
                <input id="email" name="email" type="email" autoComplete="email" required />
              </fieldset>

              <fieldset className="buy-block">
                <legend>entrega</legend>
                <label htmlFor="cep">CEP</label>
                <input id="cep" name="cep" inputMode="numeric" autoComplete="postal-code" placeholder="00000-000" required />
                <label htmlFor="rua">endereço</label>
                <input id="rua" name="rua" autoComplete="address-line1" required />
                <div className="buy-row">
                  <div>
                    <label htmlFor="num">número</label>
                    <input id="num" name="num" required />
                  </div>
                  <div>
                    <label htmlFor="comp">complemento</label>
                    <input id="comp" name="comp" autoComplete="address-line2" />
                  </div>
                </div>
                <div className="buy-row buy-row-uf">
                  <div>
                    <label htmlFor="cidade">cidade</label>
                    <input id="cidade" name="cidade" autoComplete="address-level2" required />
                  </div>
                  <div>
                    <label htmlFor="uf">UF</label>
                    <input id="uf" name="uf" maxLength={2} autoComplete="address-level1" required />
                  </div>
                </div>
              </fieldset>

              <fieldset className="buy-block">
                <legend>pagamento</legend>
                <div className="buy-pay" role="radiogroup" aria-label="forma de pagamento">
                  {payments.map((p) => (
                    <label key={p.id} className={pay === p.id ? "is-on" : ""}>
                      <input type="radio" name="pagamento" value={p.id} checked={pay === p.id} onChange={() => setPay(p.id)} />
                      {p.label}
                    </label>
                  ))}
                </div>
              </fieldset>

              <div className="buy-sum" aria-live="polite">
                <div><span>{qty} × {brl(PRICE)}</span><span>{brl(PRICE * qty)}</span></div>
                <div><span>frete</span><span>calculado pelo CEP</span></div>
                <div className="buy-total"><span>total</span><span>{brl(PRICE * qty)}</span></div>
              </div>

              <button type="submit" className="buy-btn">finalizar compra</button>
              <p className="buy-note">Página de demonstração: nenhum pagamento é processado.</p>
            </form>
          )}
        </div>
      </div>
    </main>
  );
}
