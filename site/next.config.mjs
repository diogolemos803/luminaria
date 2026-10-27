/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async redirects() {
    return [
      // as páginas viraram dobras da landing; os endereços antigos levam para elas
      { source: "/como-funciona", destination: "/#como-funciona", permanent: true },
      { source: "/lista", destination: "/#lista", permanent: true },
      { source: "/pre-venda", destination: "/#lista", permanent: true },
      { source: "/comprar", destination: "/#lista", permanent: true },
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
