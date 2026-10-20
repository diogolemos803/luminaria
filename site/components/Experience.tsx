"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import Loading from "./Loading";
import Menu from "./Menu";
import { useLang } from "./LangProvider";
import { lampColors, rooms, type Mode } from "./palette";

const MIN_LOADING_MS = 1200;
const PHOTOS = {
  dia: "/cena/dia.webp",
  noite: "/cena/noite.webp",
  laranja: "/cena/noite_laranja.webp",
  vermelho: "/cena/noite_vermelho.webp",
} as const;

// zonas em % da foto (16:9): o Day Finisher e a pessoa
const LAMP = { left: "44%", top: "33%", width: "18%", height: "33%" };

/** Pilha de fotos: a noite âmbar fica sempre por baixo, laranja e vermelho entram por cima. */
function Layers({ mode, colorIndex, reduced }: { mode: Mode; colorIndex: number; reduced: boolean }) {
  const night = mode === "night";
  const fade = { duration: reduced ? 0 : 1.1, ease: "easeInOut" as const };
  const img = "absolute inset-0 h-full w-full select-none object-cover";
  return (
    <>
      {/* eslint-disable @next/next/no-img-element */}
      <img src={PHOTOS.noite} alt="" className={img} draggable={false} />
      <motion.img src={PHOTOS.laranja} alt="" className={img} draggable={false} initial={false} animate={{ opacity: night && colorIndex >= 1 ? 1 : 0 }} transition={fade} />
      <motion.img src={PHOTOS.vermelho} alt="" className={img} draggable={false} initial={false} animate={{ opacity: night && colorIndex >= 2 ? 1 : 0 }} transition={fade} />
      <motion.img src={PHOTOS.dia} alt="" className={img} draggable={false} initial={false} animate={{ opacity: night ? 0 : 1 }} transition={{ ...fade, duration: reduced ? 0 : 0.9 }} />
      {/* eslint-enable @next/next/no-img-element */}
    </>
  );
}

export default function Experience() {
  const { t } = useLang();
  const reduced = !!useReducedMotion();
  const [minTime, setMinTime] = useState(false);
  const [loaded, setLoaded] = useState(0);
  const [mode, setMode] = useState<Mode>("night");
  const [lampActive, setLampActive] = useState(false);
  const [picked, setPicked] = useState(0); // cor fixa escolhida
  const [cycleIndex, setCycleIndex] = useState(0);
  const [paused, setPaused] = useState(false); // parou o ciclo ao escolher uma cor
  const [menuOpen, setMenuOpen] = useState(false);
  const [auto, setAuto] = useState(false); // "alternar sozinha": cicla sem precisar do cartão aberto
  const leaveTimer = useRef<ReturnType<typeof setTimeout>>();
  const pointerType = useRef("mouse");
  const menuOpenRef = useRef(false);
  const ready = minTime && loaded >= Object.keys(PHOTOS).length;

  // Loading: no mínimo ~1,2s, mesmo com as fotos já carregadas.
  useEffect(() => {
    const t = setTimeout(() => setMinTime(true), MIN_LOADING_MS);
    return () => clearTimeout(t);
  }, []);

  // Pré-carrega as fotos antes de mostrar a cena.
  useEffect(() => {
    let n = 0;
    Object.values(PHOTOS).forEach((src) => {
      const im = new window.Image();
      const done = () => setLoaded(++n);
      im.onload = done;
      im.onerror = done;
      im.src = src;
    });
  }, []);

  // Com o Day Finisher ativo (à noite), cicla âmbar → laranja → vermelho em loop lento.
  useEffect(() => {
    if ((!lampActive && !auto) || mode === "day") {
      setPaused(false);
      return;
    }
    if (paused) return;
    setCycleIndex(picked);
    const id = setInterval(() => setCycleIndex((i) => (i + 1) % lampColors.length), 2400);
    return () => clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lampActive, auto, paused, mode]);
  const colorIndex = mode === "night" ? ((lampActive || auto) && !paused ? cycleIndex : picked) : 0;

  const hoverIn = useCallback(() => {
    if (menuOpenRef.current) return;
    clearTimeout(leaveTimer.current);
    setLampActive(true);
  }, []);
  const hoverOut = useCallback(() => {
    leaveTimer.current = setTimeout(() => setLampActive(false), 250);
  }, []);
  const handleMenuOpen = useCallback((o: boolean) => {
    menuOpenRef.current = o;
    setMenuOpen(o);
    if (o) {
      clearTimeout(leaveTimer.current);
      setLampActive(false);
    }
  }, []);
  const toggleMode = useCallback(() => setMode((m) => (m === "night" ? "day" : "night")), []);

  const c = rooms[mode];
  const hovering = lampActive && !menuOpen;
  const night = mode === "night";
  const lampColor = lampColors[colorIndex];

  const focusMask = "radial-gradient(ellipse 15% 21% at 52% 50%, #000 58%, transparent 100%)";

  return (
    <main className="relative h-full w-full overflow-hidden bg-carvao">
      <AnimatePresence>{!ready && <Loading key="loading" reduced={reduced} />}</AnimatePresence>

      <motion.div
        className="absolute inset-0"
        initial={{ opacity: 0, scale: reduced ? 1 : 1.05 }}
        animate={ready ? { opacity: 1, scale: 1 } : {}}
        transition={{ duration: reduced ? 0 : 0.8, ease: "easeInOut" }}
      >
        {/* palco 16:9 que cobre a tela; zonas interativas usam % da foto */}
        <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2" style={{ width: "max(100vw, calc(100svh * 16 / 9))", aspectRatio: "16 / 9" }}>
          <motion.div
            className="absolute inset-0"
            role="img"
            aria-label={t.experience.scene}
          >
            <div className="absolute inset-0" style={{ filter: hovering ? "blur(1.8px)" : "none", transition: "filter .45s ease" }}>
              <Layers mode={mode} colorIndex={colorIndex} reduced={reduced} />
            </div>

            {/* foco nítido no Day Finisher enquanto o resto desfoca */}
            <div
              className="pointer-events-none absolute inset-0"
              style={{ opacity: hovering ? 1 : 0, transition: "opacity .45s ease", WebkitMaskImage: focusMask, maskImage: focusMask }}
            >
              <Layers mode={mode} colorIndex={colorIndex} reduced={reduced} />
            </div>

            {/* brilho do Day Finisher: tremor mínimo, na cor atual */}
            <motion.div
              className="pointer-events-none absolute"
              style={{
                left: "30%",
                top: "12%",
                width: "40%",
                height: "70%",
                background: `radial-gradient(ellipse at 50% 52%, ${lampColor}55 0%, ${lampColor}00 62%)`,
                mixBlendMode: "screen",
              }}
              animate={{ opacity: night ? 0.45 : 0 }}
              transition={{ duration: 0.8 }}
            />

            {/* zona do Day Finisher */}
            <div
              role="button"
              tabIndex={0}
              aria-label={t.experience.lamp}
              aria-expanded={lampActive}
              className="absolute cursor-pointer"
              style={LAMP}
              onPointerDown={(e) => (pointerType.current = e.pointerType)}
              onPointerEnter={(e) => e.pointerType === "mouse" && hoverIn()}
              onPointerLeave={(e) => e.pointerType === "mouse" && hoverOut()}
              onClick={() => pointerType.current !== "mouse" && setLampActive((a) => !a)}
              onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && (e.preventDefault(), setLampActive((a) => !a))}
            />

          </motion.div>
        </div>
      </motion.div>

      <AnimatePresence>
        {hovering && (
          <motion.div
            key="card"
            className={`hover-card ${night ? "" : "is-day"}`}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 6 }}
            transition={{ duration: 0.25 }}
            onPointerEnter={hoverIn}
            onPointerLeave={hoverOut}
          >
          <p className="text-sm leading-snug">{t.experience.hover}</p>
            {night && (
              <div className="mt-3 flex gap-2" role="group" aria-label={t.experience.colorGroup}>
                {lampColors.map((col, i) => (
                  <button
                    key={col}
                    type="button"
                    aria-label={t.experience.colors[i]}
                    aria-pressed={colorIndex === i}
                    onClick={() => {
                      setPicked(i);
                      setAuto(false);
                      setPaused(true);
                    }}
                    className="h-6 w-6 rounded-full"
                    style={{ background: col, outline: colorIndex === i ? `2px solid ${c.text}` : "none", outlineOffset: 2 }}
                  />
                ))}
              </div>
            )}
            <Link href="/produto" className="mt-4 inline-block rounded-full px-4 py-1.5 text-sm" style={{ background: night ? lampColor : "#DB8149", color: "#2A2A2A" }}>
              {t.experience.learnMore}
            </Link>
          </motion.div>
        )}
      </AnimatePresence>

      {ready && (
        <>
          <div className={`brand-logo ${night ? "" : "is-day"}`} aria-label="sovee">
            <i className="brand-mark" aria-hidden="true" />
            <span>sovee</span>
          </div>
          <Link href="/comprar" className={`buy-cta ${night ? "" : "is-day"}`} style={{ ["--lc" as string]: lampColor }}>
            {t.nav.buy}
          </Link>
          <Menu
            mode={mode}
            colorIndex={colorIndex}
            auto={auto}
            onPick={(i) => { setPicked(i); setAuto(false); setPaused(true); }}
            onAuto={() => { setAuto(true); setPaused(false); }}
            onMode={setMode}
            onOpenChange={handleMenuOpen}
          />
          <button
            type="button"
            onClick={toggleMode}
            aria-label={night ? t.experience.seeDay : t.experience.seeNight}
            className="fixed bottom-4 left-4 z-40 flex h-12 w-12 items-center justify-center rounded-full"
            style={{ background: c.card, color: c.text }}
          >
            {night ? (
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
                <circle cx="12" cy="12" r="4" />
                <path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
              </svg>
            ) : (
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                <path d="M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z" />
              </svg>
            )}
          </button>
        </>
      )}
    </main>
  );
}
