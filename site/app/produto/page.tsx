import Link from "next/link";

// Placeholder: a rota real da página de produto ainda está em aberto.
export default function Produto() {
  return (
    <main className="flex h-full flex-col items-center justify-center gap-6 bg-carvao px-6 text-center text-creme">
      <h1 className="text-4xl font-medium">sovee</h1>
      <p className="max-w-sm opacity-80">a página do produto chega em breve.</p>
      <Link href="/" className="rounded-full border border-creme px-6 py-2 text-sm">
        voltar ao quarto
      </Link>
    </main>
  );
}
