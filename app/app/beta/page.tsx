import type { Metadata } from "next";
import { BetaApp } from "./beta-app";

export const metadata: Metadata = {
  title: "Lexora Beta｜大学英语四级词汇学习系统",
  description: "把单词来源、主动回忆、间隔重复、五种练习模式和学习统计连接成完整闭环。",
  alternates: { canonical: "/app/beta" },
  manifest: "/beta-manifest.webmanifest",
  appleWebApp: { capable: true, statusBarStyle: "default", title: "Lexora Beta" },
};

export default function BetaPage() {
  return <BetaApp />;
}
