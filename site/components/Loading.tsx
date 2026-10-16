"use client";

import { motion } from "framer-motion";

/** Logo SOVEE em line-art com o motivo zZ. */
export function Logo({ size = 120, color = "#FDF8C7" }: { size?: number; color?: string }) {
  const stroke = { stroke: color, strokeWidth: 5, strokeLinecap: "round" as const, strokeLinejoin: "round" as const, fill: "none" };
  return (
    <svg width={size} height={size} viewBox="0 0 120 120" aria-hidden="true">
      <path d="M22 62 H46 L22 94 H48" {...stroke} />
      <path d="M62 24 H98 L62 80 H100" {...stroke} />
    </svg>
  );
}

export default function Loading({ reduced }: { reduced: boolean }) {
  return (
    <motion.div
      className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-5 bg-carvao"
      exit={{ opacity: 0 }}
      transition={{ duration: 0.8, ease: "easeInOut" }}
      role="status"
      aria-label="carregando"
    >
      {/* o zZ pulsa em ~2,5s por ciclo; sem spinner */}
      <motion.div
        animate={reduced ? undefined : { opacity: [1, 0.25, 1] }}
        transition={reduced ? undefined : { duration: 2.5, repeat: Infinity, ease: "easeInOut" }}
      >
        <Logo />
      </motion.div>
      <span className="text-sm tracking-[0.4em] text-creme">sovee</span>
    </motion.div>
  );
}
