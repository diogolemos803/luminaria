/** Escrita "sovee" da marca (arte oficial), recolorida pela cor do texto. A altura vem do CSS do contexto. */
export default function Wordmark({ className = "" }: { className?: string }) {
  return <i className={`wordmark ${className}`} role="img" aria-label="sovee" />;
}
