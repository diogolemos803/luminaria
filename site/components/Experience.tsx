"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import Loading from "./Loading";
import Menu from "./Menu";
import { hotspots, lampColors, rooms, type Mode } from "./palette";

const MIN_LOADING_MS = 1200;
const PHOTOS = { night: "/cena/noite.jpg", day: "/cena/dia.jpg" } as const;

const pct = (n: number) => `${n}%`;
const box = (h: { x: number; y: number; w: number; h: number }) => ({ left: pct(h.x), top: pct(h.y), width: pct(h.w), height: pct(h.h) });

export default function Experience() {
  const reduced = !!useReducedMotion();
  const [minTime, setMinTime] = useState(false);
  const [loaded, setLoaded] = useState(0);
  const [mode, setMode] = useState<Mode>("night");
  const [lampActive, setLampActive] = useState(false);
  const [colorIndex, setColorIndex] = useState(0);
  const leaveTimer = useRef<ReturnType<typeof setTimeout>>();
  const pointerType = useRef("mouse");
  const ready = minTime && loaded >= 2;

  // Loading: no mínimo ~1,2s, mesmo com as fotos já carregadas.
  useEffect(() => {
    const t = setTimeout(() => setMinTime(true), MIN_LOADING_MS);
    return () => clearTimeout(t);
  }, []);

  // Pré-carrega as duas fotos (onLoad do <img> pode disparar antes da hidratação).
  useEffect(() => {
    let n = 0;
    Object.values(PHOTOS).forEach((src) => {
      const img = new window.Image();
      const done = () => setLoaded(++n);
      img.onload = done;
      img.onerror = done;
      img.src = src;
    });
  }, []);

  // Com a luminária ativa, cicla âmbar → laranja → vermelho em loop lento.
  useEffect(() => {
    if (!lampActive) {
      setColorIndex(0);
      return;
    }
    const id = setInterval(() => setColorIndex((i) => (i + 1) % lampColors.length), 2000);
    return () => clearInterval(id);
  }, [lampActive]);

  const enterLamp = useCallback(() => {
    clearTimeout(leaveTimer.current);
    setLampActive(true);
  }, []);
  const leaveLamp = useCallback(() => {
    leaveTimer.current = setTimeout(() => setLampActive(false), 200);
  }, []);
  const hover = {
    onPointerEnter: (e: React.PointerEvent) => e.pointerType === "mouse" && enterLamp(),
    onPointerLeave: (e: React.PointerEvent) => e.pointerType === "mouse" && leaveLamp(),
  };
  const toggleMode = () => setMode((m) => (m === "night" ? "day" : "night"));
  const activate = (fn: () => void) => (e: React.KeyboardEvent) => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      fn();
    }
  };

  const c = rooms[mode];
  const lamp = lampColors[colorIndex];
  const night = mode === "night";
  const fade = { duration: reduced ? 0 : 0.8, ease: "easeInOut" as const };

  // "respiração": cópia da foto, mascarada só no edredom e na pessoa, que sobe e desce de leve
  const breathMask = "radial-gradient(ellipse 34% 40% at 74% 62%, #000 30%, transparent 100%)";

  return (
    <main className="relative h-full w-full overflow-hidden bg-carvao">
      <AnimatePresence>{!ready && <Loading key="loading" reduced={reduced} />}</AnimatePresence>

      <motion.div
        className="absolute inset-0"
        initial={{ opacity: 0, scale: reduced ? 1 : 1.05 }}
        animate={ready ? { opacity: 1, scale: 1 } : {}}
        transition={{ duration: reduced ? 0 : 0.8, ease: "easeInOut" }}
      >
        {/* palco 16:9 que cobre a tela; hotspots usam % da foto */}
        <div
          className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
          style={{ width: "max(100vw, calc(100svh * 16 / 9))", aspectRatio: "16 / 9" }}
        >
          <motion.div
            className="absolute inset-0"
            animate={reduced ? undefined : { scale: [1, 1.025, 1], x: ["0%", "-0.6%", "0%"] }}
            transition={reduced ? undefined : { duration: 40, repeat: Infinity, ease: "easeInOut" }}
          >
            {(["night", "day"] as const).map((m) => (
              <motion.div key={m} className="absolute inset-0" animate={{ opacity: mode === m ? 1 : 0 }} transition={fade}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={PHOTOS[m]} alt="" className="absolute inset-0 h-full w-full select-none" draggable={false} />
                {!reduced && (
                  <motion.div
                    className="absolute inset-0"
                    style={{ transformOrigin: "74% 70%", WebkitMaskImage: breathMask, maskImage: breathMask }}
                    animate={{ scale: [1, 1.012, 1] }}
                    transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={PHOTOS[m]} alt="" className="absolute inset-0 h-full w-full" draggable={false} />
                  </motion.div>
                )}
              </motion.div>
            ))}

            {/* luminária recolorida: só ativa depois do âmbar de repouso */}
            <motion.div
              className="pointer-events-none absolute rounded-[20%]"
              style={{ ...box({ x: 21.8, y: 47.5, w: 6.4, h: 18 }), background: lamp, mixBlendMode: "color" }}
              animate={{ opacity: night && colorIndex > 0 ? 0.9 : 0 }}
              transition={{ duration: 1.2 }}
            />
            <motion.div
              className="pointer-events-none absolute"
              style={{
                ...box({ x: 0, y: 5, w: 55, h: 95 }),
                background: `radial-gradient(ellipse at 40% 50%, ${lamp} 0%, transparent 60%)`,
                mixBlendMode: "screen",
              }}
              animate={night ? { opacity: colorIndex > 0 ? 0.28 : 0.04 } : { opacity: 0 }}
              transition={{ duration: 1.2 }}
            />

            {/* janela */}
            <div
              role="button"
              tabIndex={0}
              aria-label={night ? "abrir a janela e ver o dia" : "fechar a janela e ver a noite"}
              className="absolute cursor-pointer"
              style={box(hotspots.window)}
              onClick={toggleMode}
              onKeyDown={activate(toggleMode)}
            />
            {/* luminária */}
            <div
              role="button"
              tabIndex={0}
              aria-label="luminária sovee"
              aria-expanded={lampActive}
              className="absolute cursor-pointer"
              style={box(hotspots.lamp)}
              onPointerDown={(e) => (pointerType.current = e.pointerType)}
              onClick={() => pointerType.current !== "mouse" && setLampActive((a) => !a)}
              onKeyDown={activate(() => setLampActive((a) => !a))}
              {...hover}
            />

            <AnimatePresence>
              {lampActive && (
                <motion.div
                  key="card"
                  className="absolute z-30 w-60 rounded-2xl p-4"
                  style={{ left: "31%", top: "44%", background: c.card, color: c.text }}
                  initial={{ opacity: 0, y: 6 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: 6 }}
                  transition={{ duration: 0.25 }}
                  {...hover}
                >
                  <p className="text-sm leading-snug">uma luz que acompanha o seu sono, do âmbar ao vermelho.</p>
                  <Link href="/produto" className="mt-3 inline-block rounded-full px-4 py-1.5 text-sm" style={{ background: lamp, color: "#2A2A2A" }}>
                    conheça a sovee
                  </Link>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        </div>
      </motion.div>

      {ready && <Menu mode={mode} />}
    </main>
  );
}
