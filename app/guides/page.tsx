import type { Metadata } from "next";
import Link from "next/link";
import { GuideShell } from "./guide-shell";

export const metadata: Metadata = {
  title: "英语单词整理与个人词汇书制作指南｜Lexora",
  description: "学习如何批量导入英语单词、制作个人词汇书，并将单词表导出为适合手机阅读和打印的PDF。",
  alternates: { canonical: "/guides" },
};

const guides = [
  { href: "/guides/personal-vocabulary-book", label: "个人词汇书", title: "如何制作真正适合自己的英语词汇书", copy: "从阅读中积累生词，补全语境，再按自己的阅读和打印习惯生成词汇书。" },
  { href: "/guides/import-word-list", label: "批量整理", title: "如何批量导入 TXT、PDF、DOC 和 DOCX 单词表", copy: "用换行分隔词条，一次导入大量单词和短语，并在生成前检查与调整顺序。" },
  { href: "/guides/word-to-pdf", label: "单词转 PDF", title: "如何把英语单词表制作成 PDF", copy: "自动补全音标、释义和例句，选择纸张与字号，生成适合手机和打印的文件。" },
];

export default function GuidesPage() {
  return <GuideShell eyebrow="Lexora 使用指南" title="把英语单词整理成真正能复习的材料。" intro="这里不是关键词堆砌，而是从导入、查词、整理到导出的完整实用方法。所有步骤都可以使用免费的 Lexora 完成。">
    <div className="seoGuideGrid">
      {guides.map((guide) => <Link href={guide.href} key={guide.href}>
        <span>{guide.label}</span><h2>{guide.title}</h2><p>{guide.copy}</p><b>阅读指南 →</b>
      </Link>)}
    </div>
    <section><h2>Lexora适合哪些人？</h2><p>适合需要整理阅读生词、备考四六级、考研、雅思或托福词汇，以及希望自己控制词汇书内容和排版的人。它同时提供词典搜索、批量导入、排序、双语补全和多格式导出，不需要把词条分散在多个工具里。</p></section>
  </GuideShell>;
}
