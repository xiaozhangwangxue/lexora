import type { Metadata } from "next";
import { LexoraWebApp } from "./lexora-web-app";

export const metadata: Metadata = {
  title: "Lexora Web — 我的双语词汇书",
  description: "搜索、整理英语单词和短语，并在云端生成适合阅读与打印的双语 PDF。",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Lexora",
  },
  alternates: { canonical: "/app" },
};

export default function AppPage() {
  return <LexoraWebApp />;
}
