/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async redirects() {
    // www.sovee.com.br -> sovee.com.br (endereço principal)
    return [
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
