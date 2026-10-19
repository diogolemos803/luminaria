"use client";

import Link from "next/link";
import { useEffect, useRef } from "react";
import * as launch from "./scenes/launchScene";
import * as landing from "./scenes/landingScene";

/* ---------- matemática de rolagem ---------- */
const clamp01 = (v: number) => Math.min(1, Math.max(0, v));
const seg = (p: number, a: number, b: number) => clamp01((p - a) / (b - a));
const ease = (t: number) => t * t * (3 - 2 * t);
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const hex = (h: string) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const mix = (a: string, b: string, t: number) => {
  const x = hex(a);
  const y = hex(b);
  return `rgb(${x.map((v, i) => Math.round(lerp(v, y[i], t))).join(",")})`;
};

const AMBER = "#F2B05E";
const ORANGE = "#E8742A";
const RED = "#C8402F";

/* Capítulos: janela de rolagem (0 a 1) em que cada card aparece e some. */
const chapters = [
  { id: "arme", from: 0.0, to: 0.13, title: "arme o modo noite", text: "No app SOVEE, um toque no botão redondo prepara a noite." },
  { id: "encoste", from: 0.13, to: 0.27, title: "encoste o celular", text: "A etiqueta NFC do Day Finisher reconhece o seu iPhone, e o rostinho do botão fica verde." },
  { id: "encaixe", from: 0.27, to: 0.4, title: "encaixe no nicho", text: "O celular descansa no nicho de madeira da base, à vista e longe da cama. A luz acende e os apps que você escolheu ficam bloqueados." },
  { id: "noite", from: 0.4, to: 0.55, title: "três cores de luz", text: "Âmbar, laranja e vermelho, sempre em tons quentes, sem o azul que mantém o cérebro em alerta. Fixe a cor que preferir ou deixe o Day Finisher alternar sozinho." },
  { id: "foguete", from: 0.55, to: 0.67, title: "o foguete decola", text: "No app, o foguete parte assim que o celular é reconhecido e segue viagem enquanto você dorme." },
  { id: "meteoro", from: 0.67, to: 0.78, title: "se você pegar o celular", text: "Um meteoro atinge o foguete e ele fica em obras até de manhã. Aquela noite não conta na sua sequência." },
  { id: "manha", from: 0.78, to: 0.91, title: "o despertador toca", text: "No horário da rotina, o despertador toca com um som calmo, os apps voltam e o foguete pousa na Lua. Quanto mais noites seguidas, mais longe ele chega." },
] as const;
const FINAL = { from: 0.91, to: 1.01 };

/* ---------- geometria do desenho do Day Finisher (viewBox 1080 x 1350) ---------- */
const T = [526.5, 697.5];
const U = [333, 96.6];
const V = [-117.5, 101.5];
const NICHE = [634, 797];
const LAMP_PATH = "M219.5 467 A117 58 0 0 1 453.5 467 L453.5 669 A117 58 0 0 1 219.5 669 Z";
/* escala do celular em relação ao desenho: o celular deitado cobre ~84% do comprimento do nicho */
const PHONE_SCALE = 0.57;
const MATRIX = `matrix(${U[0]} ${U[1]} ${V[0]} ${V[1]} ${T[0]} ${T[1]})`;

type Anim = Animation[];

export default function HowItWorks() {
  const scroller = useRef<HTMLElement>(null);
  const track = useRef<HTMLDivElement>(null);
  const stage = useRef<HTMLDivElement>(null);
  const iso = useRef<HTMLDivElement>(null);
  const lampFill = useRef<SVGGElement>(null);
  const glow = useRef<SVGEllipseElement>(null);
  const ambient = useRef<HTMLDivElement>(null);
  const waves = useRef<(SVGEllipseElement | null)[]>([]);
  const blackLayer = useRef<HTMLDivElement>(null);
  const frameEl = useRef<HTMLDivElement>(null);
  const wireEl = useRef<HTMLDivElement>(null);
  const slabsEl = useRef<HTMLDivElement>(null);
  const isoShadow = useRef<SVGGElement>(null);
  const phone = useRef<HTMLDivElement>(null);
  const dayLayer = useRef<HTMLDivElement>(null);
  const nightLayer = useRef<HTMLDivElement>(null);
  const okLayer = useRef<HTMLDivElement>(null);
  const tap = useRef<HTMLDivElement>(null);
  const launchEl = useRef<HTMLDivElement>(null);
  const meteorEl = useRef<HTMLIFrameElement>(null);
  const landEl = useRef<HTMLDivElement>(null);
  const clock = useRef<HTMLDivElement>(null);
  const chip = useRef<HTMLDivElement>(null);
  const hint = useRef<HTMLDivElement>(null);
  const cards = useRef<(HTMLDivElement | null)[]>([]);
  const finalCard = useRef<HTMLDivElement>(null);
  const swatches = useRef<(HTMLSpanElement | null)[]>([]);
  const colorName = useRef<HTMLDivElement>(null);
  const dots = useRef<(HTMLButtonElement | null)[]>([]);

  useEffect(() => {
    const sc = scroller.current;
    const tr = track.current;
    const st = stage.current;
    if (!sc || !tr || !st) return;

    let launchAnims: Anim = [];
    let landAnims: Anim = [];
    const grab = (el: HTMLElement | null) => {
      const list = el?.getAnimations ? el.getAnimations({ subtree: true }) : [];
      list.forEach((a) => a.pause());
      return list;
    };
    const setup = requestAnimationFrame(() => {
      launchAnims = grab(launchEl.current);
      landAnims = grab(landEl.current);
      update();
    });

    let W = 0;
    let H = 0;
    const L = { objCx: 0, objCy: 0, isoW: 0, isoH: 0, isoX: 0, isoY: 0, nicheX: 0, nicheY: 0, sBig: 1, mobile: false, k0: 1, kBig: 1, kBig2: 1, Sx: 0, Sy: 0, Ex: 0, Ey: 0 };

    function measure() {
      W = st!.clientWidth;
      H = st!.clientHeight;
      L.mobile = W < 800;
      L.objCx = L.mobile ? W / 2 : W * 0.32;
      L.objCy = L.mobile ? H * 0.4 : H * 0.5;
      const isoH0 = L.mobile ? Math.min(H * 0.56, W * 1.2) : H * 0.92;
      const isoW0 = isoH0 * 0.8;
      L.k0 = isoW0 / 1080;
      L.sBig = (L.mobile ? H * 0.5 : H * 0.74) / 626;
      // o celular mantém o tamanho em relação ao Day Finisher: quem muda é a câmera
      L.kBig = L.sBig / PHONE_SCALE;
      L.kBig2 = L.kBig * 0.92;
      L.Sx = L.objCx;
      L.Sy = L.objCy;
      L.Ex = L.objCx - isoW0 / 2 + NICHE[0] * L.k0;
      L.Ey = L.objCy - isoH0 / 2 + NICHE[1] * L.k0;
    }

    function setLayer(el: HTMLElement | null, o: number) {
      if (el) el.style.opacity = String(o);
    }

    function update() {
      measure();
      const max = tr!.offsetHeight - sc!.clientHeight;
      const p = clamp01((sc!.scrollTop - tr!.offsetTop) / Math.max(1, max));

      /* --- câmera e celular: o mesmo celular, com rotação rígida, sem deformar --- */
      const segA = ease(seg(p, 0.135, 0.3));
      const segB = ease(seg(p, 0.545, 0.6));
      const segC = ease(seg(p, 0.9, 0.95));
      const k = p < 0.5 ? lerp(L.kBig, L.k0, segA) : lerp(lerp(L.k0, L.kBig2, segB), L.k0, segC);
      const px = p < 0.5 ? lerp(L.Sx, L.Ex, segA) : lerp(lerp(L.Ex, L.Sx, segB), L.Ex, segC);
      const py = p < 0.5 ? lerp(L.Sy, L.Ey, segA) : lerp(lerp(L.Ey, L.Sy, segB), L.Ey, segC);
      const tilt = p < 0.5 ? ease(seg(p, 0.16, 0.27)) : lerp(1 - segB, 1, segC);
      const lift =
        p < 0.5
          ? 380 * ease(seg(p, 0.15, 0.27)) * (1 - ease(seg(p, 0.285, 0.355)))
          : 190 * (Math.sin(Math.PI * segB) + Math.sin(Math.PI * segC));
      L.isoW = 1080 * k;
      L.isoH = 1350 * k;
      L.isoX = px - NICHE[0] * k;
      L.isoY = py - NICHE[1] * k;
      L.nicheX = px;
      L.nicheY = py;
      if (iso.current) {
        iso.current.style.width = `${L.isoW}px`;
        iso.current.style.height = `${L.isoH}px`;
        iso.current.style.left = `${L.isoX}px`;
        iso.current.style.top = `${L.isoY}px`;
      }
      const cx = px + lift * 0.3 * k;
      const cy = py - (lift + 7) * k; // 7: o corpo do celular assenta dentro do nicho
      if (phone.current) {
        phone.current.style.transform = `translate(${cx - 150}px, ${cy - 313}px) perspective(3000px) rotateX(${60 * tilt}deg) rotateZ(${-59.9 * tilt}deg) scale(${PHONE_SCALE * k})`;
        phone.current.style.opacity = "1";
      }
      // deitado no nicho: corpo escuro e fosco com o traço fino claro do desenho
      if (frameEl.current) frameEl.current.style.opacity = "1";
      if (wireEl.current) wireEl.current.style.opacity = String(tilt);
      if (slabsEl.current) slabsEl.current.style.opacity = String(tilt);
      // tela apagada enquanto o celular fica no nicho
      const off = p < 0.5 ? ease(seg(p, 0.265, 0.3)) : p < 0.88 ? 1 - ease(seg(p, 0.545, 0.575)) : ease(seg(p, 0.9, 0.93));
      if (blackLayer.current) blackLayer.current.style.opacity = String(off);

      /* --- telas do app --- */
      const toNight = seg(p, 0.05, 0.068);
      const recognized = seg(p, 0.235, 0.252);
      setLayer(dayLayer.current, 1 - toNight);
      setLayer(nightLayer.current, toNight * (1 - recognized));
      setLayer(okLayer.current, toNight * recognized);
      if (tap.current) {
        const q = seg(p, 0.036, 0.062);
        tap.current.style.opacity = String(q > 0 && q < 1 ? 1 - q : 0);
        tap.current.style.transform = `translate(-50%,-50%) scale(${lerp(0.55, 1.35, q)})`;
      }
      const appOp = 1 - seg(p, 0.555, 0.575);
      [dayLayer.current, nightLayer.current, okLayer.current].forEach((el) => {
        if (el) el.style.visibility = appOp > 0 ? "visible" : "hidden";
      });
      if (appOp < 1) {
        setLayer(dayLayer.current, (1 - toNight) * appOp);
        setLayer(nightLayer.current, toNight * (1 - recognized) * appOp);
        setLayer(okLayer.current, toNight * recognized * appOp);
      }

      const launchOp = seg(p, 0.555, 0.575) * (1 - seg(p, 0.665, 0.685));
      setLayer(launchEl.current, launchOp);
      const launchMs = lerp(0, 7500, seg(p, 0.56, 0.665));
      if (launchOp > 0) launchAnims.forEach((a) => (a.currentTime = launchMs));

      const meteorOp = seg(p, 0.665, 0.685) * (1 - seg(p, 0.775, 0.795));
      setLayer(meteorEl.current as unknown as HTMLElement, meteorOp);
      if (meteorOp > 0) {
        try {
          const w = meteorEl.current?.contentWindow as (Window & { __scrub?: (t: number) => void; __DURATION?: number }) | null | undefined;
          w?.__scrub?.(lerp(0, w.__DURATION ?? 6.3, seg(p, 0.67, 0.775)));
        } catch {
          /* iframe ainda carregando */
        }
      }

      const landOp = seg(p, 0.775, 0.795);
      setLayer(landEl.current, landOp);
      const landMs = lerp(0, 9200, seg(p, 0.785, 0.905));
      if (landOp > 0) landAnims.forEach((a) => (a.currentTime = landMs));

      /* --- desenho do Day Finisher --- */
      const isoIn = ease(seg(p, 0.13, 0.2));
      const dim = seg(p, 0.545, 0.58) * (1 - seg(p, 0.9, 0.94));
      if (iso.current) iso.current.style.opacity = String(isoIn * lerp(1, 0.28, dim));

      // luz: acende na etapa 3, muda de cor na 4, apaga de manhã
      const I = ease(seg(p, 0.36, 0.42)) * (1 - ease(seg(p, 0.88, 0.93)));
      let color = AMBER;
      if (p >= 0.44 && p < 0.5) color = mix(AMBER, ORANGE, ease(seg(p, 0.44, 0.5)));
      else if (p >= 0.5) color = mix(ORANGE, RED, ease(seg(p, 0.5, 0.56)));
      if (iso.current) iso.current.style.setProperty("--lc", color);
      if (lampFill.current) lampFill.current.style.opacity = String(I);
      if (glow.current) glow.current.style.opacity = String(I * 0.85);
      if (ambient.current) {
        ambient.current.style.setProperty("--lc", color);
        ambient.current.style.opacity = String(I * 0.55 * lerp(1, 0.5, dim));
        ambient.current.style.left = `${L.isoX + 337 * (L.isoW / 1080)}px`;
        ambient.current.style.top = `${L.isoY + 590 * (L.isoH / 1350)}px`;
        ambient.current.style.width = `${L.isoW * 1.9}px`;
        ambient.current.style.height = `${L.isoW * 1.9}px`;
      }

      // ondas do NFC
      const q = seg(p, 0.215, 0.285);
      waves.current.forEach((el, i) => {
        if (!el) return;
        const f = clamp01(q * 1.6 - i * 0.22);
        const r = lerp(0.12, 0.95, f);
        el.setAttribute("rx", String(r / 2.24));
        el.setAttribute("ry", String(r));
        el.style.opacity = String(f > 0 && f < 1 ? (1 - f) * 0.9 : 0);
      });

      // legenda da cor da luz
      const ci = p < 0.47 ? 0 : p < 0.53 ? 1 : 2;
      swatches.current.forEach((el, i) => el?.setAttribute("data-on", String(i === ci)));
      if (colorName.current) {
        colorName.current.textContent = ["luz âmbar", "luz laranja", "luz vermelha"][ci];
        colorName.current.style.color = color;
        colorName.current.style.opacity = String(I * (1 - seg(p, 0.545, 0.575)));
        colorName.current.style.left = `${L.objCx}px`;
        colorName.current.style.top = `${L.mobile ? H * 0.06 + 52 : H * 0.05 + 56}px`;
      }
      if (phone.current) phone.current.style.setProperty("--sh", String(1 - tilt));
      if (phone.current) phone.current.style.setProperty("--tilt", String(tilt));

      // sombra do celular no nicho
      if (isoShadow.current) isoShadow.current.style.opacity = String(tilt * clamp01(1 - lift / 260) * 0.4);

      // relógio da noite
      if (clock.current) {
        const mins = Math.round(lerp(22 * 60 + 40, 24 * 60 + 6 * 60 + 30, seg(p, 0.3, 0.9)));
        const hh = Math.floor((mins % 1440) / 60);
        const mm = mins % 60;
        clock.current.textContent = `${String(hh).padStart(2, "0")}:${String(mm).padStart(2, "0")}`;
        clock.current.style.opacity = String(seg(p, 0.29, 0.32) * (1 - seg(p, 0.9, 0.93)));
        clock.current.style.left = `${L.objCx}px`;
        clock.current.style.top = `${L.mobile ? H * 0.06 : H * 0.05}px`;
      }
      if (chip.current) {
        chip.current.style.opacity = String(seg(p, 0.36, 0.39) * (1 - seg(p, 0.54, 0.565)));
        chip.current.style.left = `${L.nicheX}px`;
        chip.current.style.top = `${L.nicheY + L.isoH * 0.13}px`;
      }
      if (hint.current) hint.current.style.opacity = String(1 - seg(p, 0.015, 0.05));

      /* --- cards --- */
      chapters.forEach((c, i) => {
        const el = cards.current[i];
        if (!el) return;
        const a = seg(p, c.from + 0.012, c.from + 0.035);
        const b = 1 - seg(p, c.to - 0.025, c.to - 0.004);
        const o = Math.min(a, b);
        el.style.opacity = String(o);
        el.style.transform = `translateY(${(1 - a) * 22 - (1 - b) * 22}px)`;
      });
      if (finalCard.current) {
        const a = seg(p, FINAL.from + 0.006, FINAL.from + 0.03);
        finalCard.current.style.opacity = String(a);
        finalCard.current.style.transform = `translateY(${(1 - a) * 22}px)`;
        finalCard.current.style.pointerEvents = a > 0.6 ? "auto" : "none";
      }
      const active = p >= FINAL.from ? chapters.length : chapters.findIndex((c) => p >= c.from && p < c.to);
      dots.current.forEach((d, i) => d?.setAttribute("aria-current", i === active ? "step" : "false"));
    }

    let raf = 0;
    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(update);
    };
    sc.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    const ro = new ResizeObserver(onScroll);
    ro.observe(st);
    update();
    return () => {
      cancelAnimationFrame(setup);
      cancelAnimationFrame(raf);
      sc.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      ro.disconnect();
    };
  }, []);

  const goTo = (from: number) => {
    const sc = scroller.current;
    const tr = track.current;
    if (!sc || !tr) return;
    const max = tr.offsetHeight - sc.clientHeight;
    sc.scrollTo({ top: tr.offsetTop + (from + 0.012) * max, behavior: "smooth" });
  };

  return (
    <main className="buy hw" ref={scroller}>
      <style>{launch.css}</style>
      <style>{landing.css}</style>

      <header className="hw-top">
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

      {/* texto para leitores de tela: a animação abaixo é decorativa */}
      <section className="sr-only" aria-label="como funciona">
        <h1>como funciona o Day Finisher</h1>
        <ol>
          {chapters.map((c) => (
            <li key={c.id}>
              <strong>{c.title}.</strong> {c.text}
            </li>
          ))}
        </ol>
        <p>hora de desligar.</p>
        <Link href="/comprar">adquira</Link>
        <Link href="/produto">conheça o produto</Link>
      </section>

      <div className="hw-track" ref={track}>
        <div className="hw-stage" ref={stage} aria-hidden="true">

          {/* o Day Finisher, em perspectiva */}
          <div className="hw-iso" ref={iso}>
            <svg viewBox="0 0 1080 1350" role="presentation">
              <defs>
                <radialGradient id="hw-glow" cx="50%" cy="50%" r="50%">
                  <stop offset="0%" style={{ stopColor: "var(--lc)", stopOpacity: 0.7 }} />
                  <stop offset="55%" style={{ stopColor: "var(--lc)", stopOpacity: 0.18 }} />
                  <stop offset="100%" style={{ stopColor: "var(--lc)", stopOpacity: 0 }} />
                </radialGradient>
                <linearGradient id="hw-body" x1="0" x2="1" y1="0" y2="0">
                  <stop offset="0%" style={{ stopColor: "var(--lc)", stopOpacity: 0.78 }} />
                  <stop offset="45%" style={{ stopColor: "var(--lc)", stopOpacity: 1 }} />
                  <stop offset="100%" style={{ stopColor: "var(--lc)", stopOpacity: 0.7 }} />
                </linearGradient>
                <linearGradient id="hw-screen" x1="0" x2="1" y1="0" y2="1">
                  <stop offset="0%" stopColor="#1b2230" />
                  <stop offset="100%" stopColor="#0c0f16" />
                </linearGradient>
                <filter id="hw-blur" x="-20%" y="-20%" width="140%" height="140%">
                  <feGaussianBlur stdDeviation="0.03" />
                </filter>
              </defs>

              <image href="/produto/lampada_apagada.webp" x="0" y="0" width="1080" height="1350" />

              {/* luz do Day Finisher */}
              <ellipse ref={glow} cx="337" cy="590" rx="520" ry="430" fill="url(#hw-glow)" style={{ opacity: 0, mixBlendMode: "screen" }} />
              <g ref={lampFill} style={{ opacity: 0, mixBlendMode: "screen" }}>
                <path d={LAMP_PATH} fill="url(#hw-body)" />
                <ellipse cx="336.5" cy="467" rx="117" ry="58" fill="var(--lc)" style={{ opacity: 0.55 }} />
              </g>

              {/* ondas do NFC no nicho */}
              <g transform={MATRIX} fill="none" stroke="#FDF8C7" strokeWidth="3" style={{ opacity: 0.9 }}>
                {[0, 1, 2].map((i) => (
                  <ellipse
                    key={i}
                    ref={(el) => {
                      waves.current[i] = el;
                    }}
                    cx="0.42"
                    cy="0.5"
                    rx="0"
                    ry="0"
                    vectorEffect="non-scaling-stroke"
                    style={{ opacity: 0 }}
                  />
                ))}
              </g>

              {/* sombra e celular */}
              <g ref={isoShadow} style={{ opacity: 0 }}>
                <g transform={MATRIX}>
                  <rect x="0.08" y="0.2" width="0.7" height="0.62" rx="0.04" ry="0.09" fill="#000" opacity="0.5" filter="url(#hw-blur)" />
                </g>
              </g>
            </svg>
          </div>

          <div className="hw-ambient" ref={ambient} />
          <div className="hw-clock" ref={clock} />
          <div className="hw-colorname" ref={colorName} />
          <div className="hw-chip" ref={chip}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <rect x="5" y="11" width="14" height="9" rx="2.5" />
              <path d="M8 11V8a4 4 0 0 1 8 0v3" />
            </svg>
            apps bloqueados até o despertador
          </div>

          {/* o celular, com a tela do app */}
          <div className="hw-phone" ref={phone}>
            <div className="hw-slabs" ref={slabsEl} style={{ opacity: 0 }}>
              {[1.5, 3, 4.5, 6, 7.5].map((z) => (
                <div key={z} className="hw-slab hw-slab-fill" style={{ transform: `translateZ(${-z}px)` }} />
              ))}
              <div className="hw-slab" style={{ transform: "translateZ(-9px)" }} />
            </div>
            <div className="hw-wire" ref={wireEl} />
            <div className="hw-frame" ref={frameEl}>
              <div className="hw-screen">
                <div className="hw-app hw-day" ref={dayLayer}>
                  <div className="hw-btn">
                    <i className="hw-face" style={{ color: "#444444", WebkitMaskImage: "url(/como-funciona/logo_acordado.png)", maskImage: "url(/como-funciona/logo_acordado.png)" }} />
                    <div className="hw-tap" ref={tap} />
                  </div>
                </div>
                <div className="hw-app hw-night" ref={nightLayer} style={{ opacity: 0 }}>
                  <div className="hw-btn">
                    <i className="hw-face" style={{ color: "#849FC8", WebkitMaskImage: "url(/como-funciona/logo_sono.png)", maskImage: "url(/como-funciona/logo_sono.png)" }} />
                  </div>
                  <p>hora de desligar.</p>
                </div>
                <div className="hw-app hw-night" ref={okLayer} style={{ opacity: 0 }}>
                  <div className="hw-btn hw-ok">
                    <i className="hw-face" style={{ color: "#80A68E", WebkitMaskImage: "url(/como-funciona/logo_sono.png)", maskImage: "url(/como-funciona/logo_sono.png)" }} />
                  </div>
                  <p>hora de desligar.</p>
                </div>
                <div className="hw-layer sc-dl" ref={launchEl} style={{ opacity: 0 }} dangerouslySetInnerHTML={{ __html: launch.svg }} />
                <iframe className="hw-layer" ref={meteorEl} src="/como-funciona/meteoro.html" title="" aria-hidden="true" tabIndex={-1} style={{ opacity: 0 }} />
                <div className="hw-layer sc-ld" ref={landEl} style={{ opacity: 0 }} dangerouslySetInnerHTML={{ __html: landing.svg }} />
                <div className="hw-black" ref={blackLayer} style={{ opacity: 0 }} />
                <div className="hw-notch" />
              </div>
            </div>
          </div>

          {/* cards de cada etapa */}
          <div className="hw-cards">
            {chapters.map((c, i) => (
              <div
                key={c.id}
                className="hover-card hw-card"
                style={{ opacity: 0 }}
                ref={(el) => {
                  cards.current[i] = el;
                }}
              >
                <span className="hw-step">etapa {i + 1} de {chapters.length}</span>
                <h2>{c.title}</h2>
                <p>{c.text}</p>
                {c.id === "noite" && (
                  <div className="hw-sw">
                    {[
                      ["âmbar", AMBER],
                      ["laranja", ORANGE],
                      ["vermelho", RED],
                    ].map(([name, col], i) => (
                      <span
                        key={name}
                        data-on="false"
                        ref={(el) => {
                          swatches.current[i] = el;
                        }}
                      >
                        <i style={{ background: col }} />
                        {name}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            ))}
            <div className="hover-card hw-card hw-final" style={{ opacity: 0, pointerEvents: "none" }} ref={finalCard}>
              <span className="hw-step">pronto</span>
              <h2>hora de desligar.</h2>
              <p>Um gesto, uma luz e uma noite sem o celular.</p>
              <div className="hw-actions">
                <Link href="/comprar" className="buy-btn" tabIndex={-1}>
                  adquira
                </Link>
                <Link href="/produto" className="hw-link" tabIndex={-1}>
                  conheça o produto
                </Link>
              </div>
            </div>
          </div>

          <nav className="hw-dots" aria-hidden="true">
            {chapters.map((c, i) => (
              <button
                key={c.id}
                type="button"
                tabIndex={-1}
                ref={(el) => {
                  dots.current[i] = el;
                }}
                onClick={() => goTo(c.from)}
                aria-label={c.title}
                title={c.title}
              />
            ))}
          </nav>

          <div className="hw-hint" ref={hint}>
            <span>role para ver como funciona</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M6 9l6 6 6-6" />
            </svg>
          </div>
        </div>
      </div>

      <footer className="pg-foot hw-foot">
        <nav aria-label="páginas">
          <Link href="/produto">produto</Link>
          <Link href="/sobre">sobre</Link>
          <Link href="/ciencia-do-sono">a ciência do sono</Link>
          <Link href="/comprar">adquira</Link>
        </nav>
        <p>hora de desligar.</p>
      </footer>
    </main>
  );
}
