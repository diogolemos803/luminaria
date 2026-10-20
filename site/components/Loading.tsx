"use client";

import { motion } from "framer-motion";
import { useLang } from "./LangProvider";
import Wordmark from "./Wordmark";

/** Logo SOVEE: a carinha dormindo, recolorida pela cor do texto. */
export function Logo({ size = 120, color = "#FDF8C7" }: { size?: number; color?: string }) {
  return (
    <i
      aria-hidden="true"
      style={{
        display: "block",
        width: size * 0.9,
        height: size,
        background: color,
        WebkitMask: "url(/logo.png) center/contain no-repeat",
        mask: "url(/logo.png) center/contain no-repeat",
      }}
    />
  );
}

export default function Loading({ reduced }: { reduced: boolean }) {
  const { t } = useLang();
  return (
    <motion.div
      className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-5 bg-carvao"
      exit={{ opacity: 0 }}
      transition={{ duration: 0.8, ease: "easeInOut" }}
      role="status"
      aria-label={t.loading}
    >
      {/* o zZ pulsa em ~2,5s por ciclo; sem spinner */}
      <motion.div
        animate={reduced ? undefined : { opacity: [1, 0.25, 1] }}
        transition={reduced ? undefined : { duration: 2.5, repeat: Infinity, ease: "easeInOut" }}
      >
        <Logo />
      </motion.div>
      <span className="text-creme"><Wordmark className="wordmark-lg" /></span>
    </motion.div>
  );
}
