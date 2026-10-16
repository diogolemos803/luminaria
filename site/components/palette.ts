export type Mode = "night" | "day";

// Só o que sobrou de paleta: cards translúcidos (cor sólida com opacidade, sem blur).
export const rooms = {
  night: { text: "#FDF8C7", card: "rgba(68,68,68,0.88)" },
  day: { text: "#444444", card: "rgba(253,248,199,0.9)" },
} as const;

// Cores reais do produto físico: âmbar → laranja → vermelho.
export const lampColors = ["#F2B05E", "#E8742A", "#C8402F"] as const;

// Posição da luminária e da janela, em % da foto (a mesma geometria nas duas fotos).
export const hotspots = {
  lamp: { x: 21, y: 46, w: 8.5, h: 22 },
  window: { x: 70, y: 0, w: 28, h: 36 },
};
