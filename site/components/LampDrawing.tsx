"use client";

import { useState } from "react";

/** Desenho da luminária: apagado em repouso, aceso no hover (ou toque / foco). */
export default function LampDrawing({ className = "" }: { className?: string }) {
  const [lit, setLit] = useState(false);
  return (
    <div
      className={`buy-photo ${lit ? "is-lit" : ""} ${className}`}
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
  );
}
