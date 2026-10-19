import type { Metadata } from "next";
import HowItWorks from "@/components/HowItWorks";

export const metadata: Metadata = {
  title: "Como funciona o Day Finisher",
  description: "Do gesto de encaixar o celular ao despertador: veja a noite com o Day Finisher passo a passo.",
};

export default function ComoFunciona() {
  return <HowItWorks />;
}
