"use client";

import dynamic from "next/dynamic";
import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import Loading from "./Loading";
import Menu from "./Menu";
import { lampColors, rooms, type Mode } from "./palette";

const Scene = dynamic(() => import("./Scene"), { ssr: false });
const MIN_LOADING_MS = 1200;

export default function Experience() {
  const reduced = !!useReducedMotion();
  const [minTime, setMinTime] = useState(false);
  const [sceneReady, setSceneReady] = useState(false);
  const [mode, setMode] = useState<Mode>("night");
  const [lampActive, setLampActive] = useState(false);
  const [picked, setPicked] = useState(0); // cor fixa escolhida
  const [cycleIndex, setCycleIndex] = useState(0);
  const [paused, setPaused] = useState(false); // parou o ciclo ao escolher uma cor
  const leaveTimer = useRef<ReturnType<typeof setTimeout>>();
  const cardRef = useRef<HTMLDivElement>(null);
  const ready = minTime && sceneReady;

  // Loading: no mínimo ~1,2s, mesmo com a cena já carregada.
  useEffect(() => {
    const t = setTimeout(() => setMinTime(true), MIN_LOADING_MS);
    return () => clearTimeout(t);
  }, []);

  // Com a luminária ativa, cicla âmbar → laranja → vermelho em loop lento.
  useEffect(() => {
    if (!lampActive) {
      setPaused(false);
      return;
    }
    if (paused) return;
    setCycleIndex(picked);
    const id = setInterval(() => setCycleIndex((i) => (i + 1) % lampColors.length), 2200);
    return () => clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lampActive, paused]);
  const colorIndex = lampActive && !paused ? cycleIndex : picked;

  const onLampHover = useCallback((hover: boolean) => {
    clearTimeout(leaveTimer.current);
    if (hover) setLampActive(true);
    else leaveTimer.current = setTimeout(() => setLampActive(false), 250);
  }, []);
  const onLampTap = useCallback(() => setLampActive((a) => !a), []);
  const toggleMode = useCallback(() => setMode((m) => (m === "night" ? "day" : "night")), []);
  const onLampScreen = useCallback((x: number, y: number) => {
    const c = cardRef.current;
    if (c) c.style.transform = `translate(${x + 24}px, ${y}px) translateY(-50%)`;
  }, []);

  const c = rooms[mode];
  const night = mode === "night";

  return (
    <main className="relative h-full w-full overflow-hidden bg-carvao">
      <AnimatePresence>{!ready && <Loading key="loading" reduced={reduced} />}</AnimatePresence>

      <motion.div
        className="absolute inset-0"
        initial={{ opacity: 0, scale: reduced ? 1 : 1.05 }}
        animate={ready ? { opacity: 1, scale: 1 } : {}}
        transition={{ duration: reduced ? 0 : 0.8, ease: "easeInOut" }}
      >
        <Scene
          mode={mode}
          lampColor={lampColors[colorIndex]}
          reduced={reduced}
          onReady={() => setSceneReady(true)}
          onLampHover={onLampHover}
          onLampTap={onLampTap}
          onWindowTap={toggleMode}
          onLampScreen={onLampScreen}
        />

        <AnimatePresence>
          {lampActive && (
            <div ref={cardRef} className="pointer-events-none absolute left-0 top-0 z-30" onPointerEnter={() => clearTimeout(leaveTimer.current)}>
              <motion.div
                className="pointer-events-auto w-60 rounded-2xl p-4"
                style={{ background: c.card, color: c.text }}
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 6 }}
                transition={{ duration: 0.25 }}
                onPointerEnter={() => clearTimeout(leaveTimer.current)}
                onPointerLeave={() => onLampHover(false)}
              >
                <p className="text-sm leading-snug">uma luz que acompanha o seu sono, do âmbar ao vermelho.</p>
                <div className="mt-3 flex gap-2" role="group" aria-label="cor da luz">
                  {lampColors.map((col, i) => (
                    <button
                      key={col}
                      type="button"
                      aria-label={["âmbar", "laranja", "vermelho"][i]}
                      aria-pressed={colorIndex === i}
                      onClick={() => {
                        setPicked(i);
                        setPaused(true);
                      }}
                      className="h-6 w-6 rounded-full"
                      style={{ background: col, outline: colorIndex === i ? `2px solid ${c.text}` : "none", outlineOffset: 2 }}
                    />
                  ))}
                </div>
                <Link href="/produto" className="mt-4 inline-block rounded-full px-4 py-1.5 text-sm" style={{ background: lampColors[colorIndex], color: "#2A2A2A" }}>
                  conheça a sovee
                </Link>
              </motion.div>
            </div>
          )}
        </AnimatePresence>

        {/* acesso por teclado e leitores de tela */}
        <div className="sr-only">
          <button type="button" aria-expanded={lampActive} onClick={onLampTap}>
            luminária sovee
          </button>
          <button type="button" onClick={toggleMode}>
            {night ? "abrir a janela e ver o dia" : "fechar a janela e ver a noite"}
          </button>
        </div>
      </motion.div>

      {ready && <Menu mode={mode} />}
    </main>
  );
}
