import type { Metadata } from "next";
import { GuideShell } from "../guide-shell";

export const metadata: Metadata = {
  title: "英语单词表转PDF｜免费双语词汇书生成器 Lexora",
  description: "把英语单词和短语自动补全为包含英美音标、双语释义、词频与例句的PDF词汇书，支持A4、A5和B5。",
  alternates: { canonical: "/guides/word-to-pdf" },
};

export default function WordToPdfGuide() {
  return <GuideShell eyebrow="单词转 PDF" title="如何把英语单词表制作成 PDF 词汇书" intro="Lexora不是简单地把单词复制进文档，而是先补全词典信息，再根据纸张、字号和内容长度进行排版。">
    <section><h2>输入或导入词条</h2><p>可以逐个输入单词和短语，也可以从文档批量导入。生成前能够拖动排序，或按照字母、长度和难度重新排列。</p></section>
    <section><h2>自动补全词典内容</h2><p>软件会查询英文和中文释义、词性、英美音标、难度、词频、例句、搭配及近反义词。没有可靠结果的内容会被跳过，避免用无关的模糊匹配污染词汇书。</p></section>
    <section><h2>选择纸张和字体</h2><p>A4适合普通打印，A5便于装订成小册子，B5介于两者之间。小号字体能够使用两栏或三栏节省纸张，大号字体则更适合手机阅读。还可以用滑块分别调整标题、释义和例句字号。</p></section>
    <section><h2>不只有PDF</h2><p>同一份词汇内容还可以导出为EPUB、可编辑的DOCX、分页图片或长图。PDF适合固定版式和打印；EPUB适合电子阅读器；DOCX适合继续编辑。</p></section>
  </GuideShell>;
}
