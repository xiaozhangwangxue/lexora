import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "raw.githubusercontent.com",
        pathname: "/xiaozhangwangxue/autoword/**",
      },
    ],
  },
};

export default nextConfig;
