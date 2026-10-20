/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async redirects() {
    return [
      // endereços antigos de compra: agora só existe a lista de espera
      { source: "/pre-venda", destination: "/lista", permanent: true },
      { source: "/comprar", destination: "/lista", permanent: true },
      // www.sovee.com.br -> sovee.com.br (endereço principal)
      {
        source: "/:path*",
        has: [{ type: "host", value: "www.sovee.com.br" }],
        destination: "https://sovee.com.br/:path*",
        permanent: true,
      },
    ];
  },
};
export default nextConfig;
