import type { Metadata } from "next";
import { GuideShell } from "../guide-shell";

export const metadata: Metadata = {
  title: "批量导入英语单词和短语｜TXT PDF DOCX生词表整理",
  description: "将以换行分隔的TXT、PDF、DOC或DOCX英语单词表批量导入Lexora，自动识别单词和短语并生成个人词汇书。",
  alternates: { canonical: "/guides/import-word-list" },
};

export default function ImportWordListGuide() {
  return <GuideShell eyebrow="批量导入" title="如何批量导入英语单词和短语" intro="已有几十个甚至几千个词条时，不必重新手工输入。整理好换行格式，就可以一次加入词汇书列表。">
    <section><h2>支持哪些文件？</h2><p>Lexora可以读取TXT、PDF、DOC和DOCX等常见文档。推荐让每个单词或短语独占一行，例如第一行写“word”，第二行写“people-to-people”，这样识别结果最稳定。</p></section>
    <section><h2>导入前如何整理？</h2><p>删除页码、标题和无关说明，保留英语词条本身。短语中的空格和连字符可以保留；重复词条会在加入列表时去重。扫描版PDF没有可选文字时，应先进行文字识别再导入。</p></section>
    <section><h2>导入后需要检查什么？</h2><p>先浏览列表，删除误识别内容，再通过拖动调整顺序，或按字母、长度和难度排序。生成时，无法可靠匹配的词会被跳过并集中提示；相似词匹配会同时显示原始输入和实际采用的词。</p></section>
    <section><h2>大量词条怎样更快？</h2><p>可以先分成若干主题或章节，每次生成适量词条。这样既便于检查匹配结果，也能得到更容易阅读和复习的词汇书，而不是一份难以翻阅的超长文件。</p></section>
  </GuideShell>;
}
