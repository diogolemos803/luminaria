export type Mode = "night" | "day";

// Cards translúcidos (cor sólida com opacidade, sem blur).
export const rooms = {
  night: { text: "#FDF8C7", card: "rgba(40,44,54,0.86)" },
  day: { text: "#444444", card: "rgba(253,248,199,0.92)" },
} as const;

// Cores reais do produto físico: âmbar → laranja → vermelho.
export const lampColors = ["#F2B05E", "#E8742A", "#C8402F"] as const;
