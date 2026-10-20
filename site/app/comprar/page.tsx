"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import LampDrawing from "@/components/LampDrawing";
import LangSwitch from "@/components/LangSwitch";
import { useLang } from "@/components/LangProvider";
import { money, price } from "@/lib/i18n";

export default function Comprar() {
  const { lang, t: all } = useLang();
  const t = all.buy;
  const PRICE = price[lang].amount; // preço no idioma/moeda escolhidos
  const brl = (n: number) => money(lang, n);
  const inbox = t.inbox;
  const payments = t.payments;
  const [qty, setQty] = useState(1);
  const [payChoice, setPay] = useState("");
  const pay = payments.some((p) => p.id === payChoice) ? payChoice : payments[0].id;
  const [sent, setSent] = useState(false);

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    setSent(true);
  };

  return (
    <main className="buy">
      <header className="buy-top">
        <Link href="/" className="buy-back" aria-label={all.back}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M15 5l-7 7 7 7" />
          </svg>
          <span>{all.back}</span>
        </Link>
        <div className="buy-right">
          <LangSwitch />
          <div className="buy-brand" aria-label="sovee">
            <i className="brand-mark" aria-hidden="true" />
            <span>sovee</span>
          </div>
        </div>
      </header>

      <div className="buy-grid">
        <LampDrawing />

        <div className="buy-col">
          <p className="buy-eyebrow">Day Finisher</p>
          <h1 className="buy-title">sovee</h1>
          <p className="buy-lead">{t.lead}</p>
          <p className="buy-price">
            {brl(PRICE)} <small>{t.perUnit}</small>
          </p>

          <section aria-labelledby="inbox-h" className="buy-block">
            <h2 id="inbox-h">{t.inboxTitle}</h2>
            <ul className="buy-list">
              {inbox.map((t) => (
                <li key={t}>{t}</li>
              ))}
            </ul>
          </section>

          {sent ? (
            <section className="buy-done" role="status">
              <h2>{t.doneTitle}</h2>
              <p>{t.done(qty, brl(PRICE * qty))}</p>
              <p className="buy-note">{t.demoDone}</p>
              <Link href="/" className="buy-btn">
                {all.back}
              </Link>
            </section>
          ) : (
            <form onSubmit={onSubmit} className="buy-form">
              <section className="buy-block" aria-labelledby="qty-h">
                <h2 id="qty-h">{t.qty}</h2>
                <div className="buy-qty">
                  <button type="button" aria-label={t.less} onClick={() => setQty((q) => Math.max(1, q - 1))}>−</button>
                  <output aria-live="polite">{qty}</output>
                  <button type="button" aria-label={t.more} onClick={() => setQty((q) => Math.min(9, q + 1))}>+</button>
                </div>
              </section>

              <fieldset className="buy-block">
                <legend>{t.contact}</legend>
                <label htmlFor="nome">{t.name}</label>
                <input id="nome" name="nome" autoComplete="name" required />
                <label htmlFor="email">{t.email}</label>
                <input id="email" name="email" type="email" autoComplete="email" required />
              </fieldset>

              <fieldset className="buy-block">
                <legend>{t.delivery}</legend>
                <label htmlFor="cep">{t.zip}</label>
                <input id="cep" name="cep" inputMode="numeric" autoComplete="postal-code" placeholder={t.zipPlaceholder} required />
                <label htmlFor="rua">{t.street}</label>
                <input id="rua" name="rua" autoComplete="address-line1" required />
                <div className="buy-row">
                  <div>
                    <label htmlFor="num">{t.number}</label>
                    <input id="num" name="num" required />
                  </div>
                  <div>
                    <label htmlFor="comp">{t.complement}</label>
                    <input id="comp" name="comp" autoComplete="address-line2" />
                  </div>
                </div>
                <div className="buy-row buy-row-uf">
                  <div>
                    <label htmlFor="cidade">{t.city}</label>
                    <input id="cidade" name="cidade" autoComplete="address-level2" required />
                  </div>
                  <div>
                    <label htmlFor="uf">{t.state}</label>
                    <input id="uf" name="uf" maxLength={t.stateMax} autoComplete="address-level1" required />
                  </div>
                </div>
              </fieldset>

              <fieldset className="buy-block">
                <legend>{t.payment}</legend>
                <div className="buy-pay" role="radiogroup" aria-label={t.paymentGroup}>
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
                <div><span>{t.shipping}</span><span>{t.shippingNote}</span></div>
                <div className="buy-total"><span>{t.total}</span><span>{brl(PRICE * qty)}</span></div>
              </div>

              <button type="submit" className="buy-btn">{t.submit}</button>
              <p className="buy-note">{t.demo}</p>
            </form>
          )}
        </div>
      </div>
    </main>
  );
}
