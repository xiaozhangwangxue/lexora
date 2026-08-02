import type { Metadata } from "next";
import { GuideShell } from "../guide-shell";

export const metadata: Metadata = {
  title: "如何制作个人英语词汇书｜免费词汇书生成器 Lexora",
  description: "从阅读生词到双语释义、音标、例句和PDF排版，学习使用Lexora制作适合自己复习的个人英语词汇书。",
  alternates: { canonical: "/guides/personal-vocabulary-book" },
};

export default function PersonalVocabularyBookGuide() {
  return <GuideShell eyebrow="个人词汇书" title="如何制作真正适合自己的英语词汇书" intro="现成单词书覆盖面很广，但未必包含你在阅读中真正遇到的词。个人词汇书的价值，是把词汇放回你的学习路径中。">
    <section><h2>第一步：只记录值得复习的词</h2><p>阅读文章、论文或书籍时，先记录影响理解、频繁出现或与你目标考试有关的单词和短语。Lexora支持逐个搜索，也支持将已经整理好的列表批量导入。</p></section>
    <section><h2>第二步：保留足够的语境</h2><p>只记中文意思很容易造成误用。一个实用词条至少应包含英文释义、中文释义、词性和可靠音标；常用词还可以加入例句、搭配、近义词和反义词。Lexora会自动补全这些内容，搜不到的字段不会强行留下空白。</p></section>
    <section><h2>第三步：按照使用场景排版</h2><p>手机阅读可选择较大字号或EPUB，打印复习可选择A4、A5或B5纸张。小字号时使用多栏能够减少纸张浪费，内容长短差异较大时可启用智能排序来减少页面留白。</p></section>
    <section><h2>第四步：持续更新而不是一次做完</h2><p>每周整理一次新词，比一次收集几千个词更容易坚持。生成记录方便重新打开和分享词汇书，搜索历史则能帮助你发现反复查询、但尚未真正掌握的词。</p></section>
  </GuideShell>;
}
