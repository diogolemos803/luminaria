"use client";

import { useSyncExternalStore } from "react";

/** Escolha de cookies do visitante, guardada em localStorage. Sem escolha = nada de rastreamento. */
export type Consent = "accepted" | "declined" | null;
const KEY = "sovee-cookies";
const EVENT = "sovee-cookies-change";

export function getConsent(): Consent {
  try {
    const v = localStorage.getItem(KEY);
    return v === "accepted" || v === "declined" ? v : null;
  } catch {
    return null;
  }
}

export function setConsent(v: Consent) {
  try {
    if (v) localStorage.setItem(KEY, v);
    else localStorage.removeItem(KEY);
  } catch {}
  window.dispatchEvent(new Event(EVENT));
}

function subscribe(cb: () => void) {
  window.addEventListener(EVENT, cb);
  window.addEventListener("storage", cb);
  return () => {
    window.removeEventListener(EVENT, cb);
    window.removeEventListener("storage", cb);
  };
}

/** No servidor e na primeira pintura devolve "pending": nada de banner nem pixel até saber a escolha. */
export function useConsent(): Consent | "pending" {
  return useSyncExternalStore<Consent | "pending">(subscribe, getConsent, () => "pending");
}
