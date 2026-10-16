import type { Config } from "tailwindcss";

// Paleta oficial SOVEE.
const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    boxShadow: { none: "none" },
    extend: {
      colors: {
        peach: "#FF9F66",
        sage: "#80A68E",
        terracota: "#DB8149",
        floresta: "#417C5A",
        creme: "#FDF8C7",
        carvao: "#444444",
      },
      fontFamily: { sans: ["var(--font-dm-sans)", "system-ui", "sans-serif"] },
    },
  },
  plugins: [],
};
export default config;
