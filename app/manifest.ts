import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Lexora - 个人英语词汇书",
    short_name: "Lexora",
    description: "免费的英汉词典与个人词汇书生成器。",
    start_url: "/",
    display: "standalone",
    background_color: "#f7f8fb",
    theme_color: "#2444c8",
    icons: [
      { src: "/lexora-icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/lexora-icon-512.png", sizes: "512x512", type: "image/png" },
    ],
  };
}
