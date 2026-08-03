import type { Metadata } from "next";
import WebApp from "./web-app";

export const metadata: Metadata = {
  title: "Lexora 在线版｜免费英汉词典与个人词汇书生成器",
  description: "无需安装或注册，在线查询英语单词和短语、批量导入词表，并生成 PDF、EPUB、DOCX、分页图片或长图词汇书。",
  alternates: { canonical: "/web" },
  openGraph: {
    title: "Lexora 在线版｜查词并生成个人词汇书",
    description: "在浏览器里查询、整理和导出你的个人英语词汇书。",
    url: "/web",
  },
};

export default function WebAppPage() {
  return <WebApp />;
}
