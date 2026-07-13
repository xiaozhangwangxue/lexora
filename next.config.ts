import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "raw.githubusercontent.com",
        pathname: "/xiaozhangwangxue/autoword/**",
      },
      {
        protocol: "https",
        hostname: "photo.12323456.xyz",
        pathname: "/api/rfile/**",
      },
    ],
  },
};

export default nextConfig;
