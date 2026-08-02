import type { Metadata } from "next";
import Link from "next/link";
import { GuideShell } from "../guides/guide-shell";

export const metadata: Metadata = {
  title: "免费英语词汇书生成器｜单词表转 PDF、EPUB、DOCX｜Lexora",
  description: "Lexora 是免费的个人英语词汇书生成器和英汉词典。批量导入单词或短语，自动补全音标、双语释义、例句与词频，生成 PDF、EPUB、DOCX、图片或长图。",
  alternates: {
    canonical: "/vocabulary-book-generator",
    languages: {
      "zh-CN": "/vocabulary-book-generator",
      en: "/en/vocabulary-book-generator",
    },
  },
  openGraph: {
    title: "Lexora 免费英语词汇书生成器",
    description: "把零散单词和短语整理成适合手机阅读与打印的个人词汇书。",
    url: "/vocabulary-book-generator",
    type: "article",
  },
};

const questions = [
  ["Lexora 是什么？", "Lexora 是一款免费的英汉词典和个人英语词汇书生成器，可在 Android、macOS、Windows 与 Linux 上使用。"],
  ["可以把单词表转换成 PDF 吗？", "可以。导入或输入单词后，Lexora 会补全音标、双语释义、例句、词频和相关词，再生成适合手机阅读与打印的 PDF。"],
  ["支持哪些导出格式？", "支持 PDF、EPUB、可编辑 DOCX、分页图片和长图，并可选择 A4、A5 或 B5 纸张与不同字号。"],
  ["是否免费且开源？", "Lexora 免费使用，源代码和版本记录公开托管在 GitHub，用户无需注册账号。"],
];

export default function VocabularyBookGeneratorPage() {
  const faq = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: questions.map(([name, text]) => ({
      "@type": "Question",
      name,
      acceptedAnswer: { "@type": "Answer", text },
    })),
  };
  return (
    <GuideShell eyebrow="Lexora 词汇书生成器" title="免费的个人英语词汇书生成器" intro="输入或批量导入你真正遇到的英语单词和短语，自动补全词典信息，再生成紧凑、清晰、适合复习与打印的个人词汇书。">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faq) }} />
      <h2>从单词列表到完整词汇书</h2>
      <p>Lexora 不只是把单词复制进文档。它会查询英美音标、词性、英文与中文释义、词频、近义词、反义词、例句和常用搭配，并根据纸张、字号与内容长度自动排版。</p>
      <ol>
        <li><strong>收集：</strong>逐个输入，或从 TXT、PDF、DOC、DOCX 等文件批量导入。</li>
        <li><strong>整理：</strong>拖动调整顺序、删除不需要的词条，或按字母、长度、难度排序。</li>
        <li><strong>生成：</strong>选择字号、例句数量、纸张和文件格式，生成个人词汇书。</li>
        <li><strong>复习：</strong>在应用中阅读生成记录，或导出到手机、电脑和电子书阅读器。</li>
      </ol>
      <h2>适合哪些学习场景</h2>
      <p>阅读英文书籍、论文、新闻或备考时遇到的生词，通常比通用词表更贴近自己的学习路径。Lexora 可以把这些零散记录变成可持续复习的材料，也适合教师整理课程词表。</p>
      <h2>常见问题</h2>
      {questions.map(([question, answer]) => <section key={question}><h3>{question}</h3><p>{answer}</p></section>)}
      <p><Link href="/guides/word-to-pdf">查看英语单词表转 PDF 教程</Link>，或前往 <a href="https://github.com/xiaozhangwangxue/lexora">Lexora GitHub 开源项目</a>查看源代码。</p>
    </GuideShell>
  );
}
