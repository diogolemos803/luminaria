"use client";

import { useState } from "react";
import type { Mode } from "./palette";
import { lampColors } from "./palette";
import LangSwitch from "./LangSwitch";
import { useLang } from "./LangProvider";
import type { UI } from "@/lib/i18n";

const links: { key: keyof UI["nav"]; href: string; icon: React.ReactNode }[] = [
  { key: "product", href: "/produto", icon: <><rect x="7" y="3" width="10" height="12" rx="3" /><path d="M5 20h14M8 15v5M16 15v5" /></> },
  { key: "how", href: "/como-funciona", icon: <><path d="M8 5.5v13l11-6.5z" /></> },
  { key: "about", href: "/sobre", icon: <><circle cx="12" cy="12" r="9" /><path d="M12 11v5M12 8h.01" /></> },
  { key: "science", href: "/ciencia-do-sono", icon: <path d="M4 5.5C4 4.7 4.7 4 5.5 4H11v16H5.5C4.7 20 4 19.3 4 18.5zM20 5.5c0-.8-.7-1.5-1.5-1.5H13v16h5.5c.8 0 1.5-.7 1.5-1.5z" /> },
  { key: "instagram", href: "https://instagram.com/the.sovee", icon: <><rect x="4" y="4" width="16" height="16" rx="5" /><circle cx="12" cy="12" r="3.6" /><path d="M16.8 7.2h.01" /></> },
];

type Props = {
  mode: Mode;
  colorIndex: number;
  auto: boolean;
  onPick: (i: number) => void;
  onAuto: () => void;
  onMode: (m: Mode) => void;
  onOpenChange?: (open: boolean) => void;
};

const Check = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M5 12.5l4.5 4.5L19 7.5" />
  </svg>
);

export default function Menu({ mode, colorIndex, auto, onPick, onAuto, onMode, onOpenChange }: Props) {
  const { t } = useLang();
  const names = t.menu.colors;
  const [open, setOpen] = useState(false);
  const [hover, setHover] = useState("");
  const night = mode === "night";
  const day = !night;
  const title = day ? t.menu.day : auto ? t.menu.cycling : names[colorIndex];
  const label = hover || (day ? t.menu.room : t.menu.nightLight);

  return (
    <>
      <button type="button" aria-label={open ? t.menu.close : t.menu.open} aria-expanded={open} onClick={() => { const o = !open; setOpen(o); onOpenChange?.(o); }} className={`menu-fab ${day ? "is-day" : ""} ${open ? "is-open" : ""}`}>
        <i /><i /><i />
      </button>
      <nav aria-label={t.menu.aria} className={`glass-menu ${day ? "is-day" : ""} ${open ? "is-open" : ""}`} aria-hidden={!open}>
        <div className="glass-nav">
          {links.map((l) => {
            const name = t.nav[l.key];
            return (
            <a key={l.key} href={l.href} aria-label={name} tabIndex={open ? 0 : -1} {...(l.href.startsWith("http") ? { target: "_blank", rel: "noopener noreferrer" } : {})}
              onPointerEnter={() => setHover(name)} onPointerLeave={() => setHover("")}
              onFocus={() => setHover(name)} onBlur={() => setHover("")}>
              <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">{l.icon}</svg>
            </a>
            );
          })}
        </div>
        <p className="glass-label">{label}</p>
        <h2 className="glass-title">{title}</h2>
        <div className="glass-opts" role="radiogroup" aria-label={t.menu.roomLight}>
          {night ? (
            <>
              {lampColors.map((c, i) => (
                <button key={c} type="button" role="radio" aria-checked={!auto && colorIndex === i} tabIndex={open ? 0 : -1} onClick={() => onPick(i)}>
                  <i style={{ background: c }} />{names[i]}<Check />
                </button>
              ))}
              <button type="button" role="radio" aria-checked={auto} tabIndex={open ? 0 : -1} onClick={onAuto}>{t.menu.cycle}<Check /></button>
            </>
          ) : (
            <>
              <button type="button" role="radio" aria-checked tabIndex={open ? 0 : -1} onClick={() => onMode("day")}>{t.menu.day}<Check /></button>
              <button type="button" role="radio" aria-checked={false} tabIndex={open ? 0 : -1} onClick={() => onMode("night")}>{t.menu.night}<Check /></button>
            </>
          )}
        </div>
        <a className="glass-link" href="/lista" tabIndex={open ? 0 : -1}>{t.nav.waitlist}</a>
        <LangSwitch className="lang-sw-menu" />
      </nav>
    </>
  );
}
