import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Adquira a SOVEE",
  description: "Compre a luminária circadiana SOVEE.",
};

export default function ComprarLayout({ children }: { children: React.ReactNode }) {
  return children;
}
