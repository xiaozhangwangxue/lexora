import type { Metadata } from "next";
import { BetaApp } from "./beta-app";

export const metadata: Metadata = {
  title: "Lexora Beta｜词典、个人词汇书与学习系统",
  description: "在一个页面使用 Lexora 词典、个人词汇书生成、历史记录和间隔重复学习系统。",
  alternates: { canonical: "/app/beta" },
  manifest: "/beta-manifest.webmanifest",
  appleWebApp: { capable: true, statusBarStyle: "default", title: "Lexora Beta" },
};

export default function BetaPage() {
  return <BetaApp />;
}
