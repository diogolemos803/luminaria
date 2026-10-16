"use client";

import { useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import type { Mode } from "./palette";
import { rooms } from "./palette";

const links = [
  { label: "produto", href: "/produto" },
  { label: "sobre", href: "#sobre" },
  { label: "a ciência do sono", href: "#ciencia" },
  { label: "instagram", href: "https://instagram.com" },
];

export default function Menu({ mode }: { mode: Mode }) {
  const [open, setOpen] = useState(false);
  const c = rooms[mode];
  const bar = "absolute left-0 h-[2px] w-6 rounded-full";
  const t = { duration: 0.25, ease: "easeInOut" as const };

  return (
    <nav
      className="fixed right-4 top-4 z-40 rounded-2xl p-3"
      style={{ background: c.card, color: c.text }}
    >
      <button
        type="button"
        aria-label={open ? "fechar menu" : "abrir menu"}
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
        className="relative ml-auto block h-6 w-6"
      >
        <motion.span className={bar} style={{ background: c.text, top: 5 }} animate={{ y: open ? 6 : 0, rotate: open ? 45 : 0 }} transition={t} />
        <motion.span className={bar} style={{ background: c.text, top: 11 }} animate={{ opacity: open ? 0 : 1 }} transition={t} />
        <motion.span className={bar} style={{ background: c.text, top: 17 }} animate={{ y: open ? -6 : 0, rotate: open ? -45 : 0 }} transition={t} />
      </button>
      <AnimatePresence initial={false}>
        {open && (
          <motion.ul
            className="overflow-hidden"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={t}
          >
            {links.map((l) => (
              <li key={l.label} className="pt-3 first:pt-4">
                <a href={l.href} className="block whitespace-nowrap pr-2 text-sm">
                  {l.label}
                </a>
              </li>
            ))}
          </motion.ul>
        )}
      </AnimatePresence>
    </nav>
  );
}
