"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import { useConsent } from "@/lib/cookies";

type Fbq = ((...args: unknown[]) => void) & { callMethod?: (...a: unknown[]) => void; queue?: unknown[]; loaded?: boolean; version?: string; push?: unknown };
declare global {
  interface Window {
    fbq?: Fbq;
    _fbq?: Fbq;
  }
}

const PIXEL_ID = process.env.NEXT_PUBLIC_META_PIXEL_ID;

/** Snippet oficial do Pixel da Meta, só executado depois do aceite. */
function loadPixel(id: string) {
  if (window.fbq) return;
  const fbq: Fbq = function (...args: unknown[]) {
    if (fbq.callMethod) fbq.callMethod(...args);
    else fbq.queue?.push(args);
  } as Fbq;
  window.fbq = fbq;
  if (!window._fbq) window._fbq = fbq;
  fbq.push = fbq;
  fbq.loaded = true;
  fbq.version = "2.0";
  fbq.queue = [];
  const s = document.createElement("script");
  s.async = true;
  s.src = "https://connect.facebook.net/en_US/fbevents.js";
  document.head.appendChild(s);
  fbq("init", id);
}

/** Pixel da Meta: só carrega se a pessoa aceitou os cookies. PageView em toda página, inclusive ao trocar de rota. */
export default function MetaPixel() {
  const consent = useConsent();
  const pathname = usePathname();
  const started = useRef(false);

  useEffect(() => {
    if (consent !== "accepted" || !PIXEL_ID) return;
    if (!started.current) {
      loadPixel(PIXEL_ID);
      started.current = true;
    }
    window.fbq?.("track", "PageView");
  }, [consent, pathname]);

  return null;
}
