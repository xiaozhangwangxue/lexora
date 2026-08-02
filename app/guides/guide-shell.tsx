import Link from "next/link";
import { LexoraWordmark } from "../lexora-wordmark";

export function GuideShell({
  eyebrow,
  title,
  intro,
  language = "zh",
  children,
}: {
  eyebrow: string;
  title: string;
  intro: string;
  language?: "zh" | "en";
  children: React.ReactNode;
}) {
  const english = language === "en";
  return (
    <main className="seoPage">
      <nav className="nav wrap" aria-label={english ? "Guide navigation" : "指南导航"}>
        <Link className="brand" href="/"><LexoraWordmark /></Link>
        <div className="seoNavLinks">
          <Link href={english ? "/en/vocabulary-book-generator" : "/guides"}>{english ? "Vocabulary book" : "全部指南"}</Link>
          <Link className="seoDownloadLink" href="/#download">{english ? "Free download" : "免费下载"}</Link>
        </div>
      </nav>
      <header className="seoHero wrap">
        <p className="sectionLabel">{eyebrow}</p>
        <h1>{title}</h1>
        <p>{intro}</p>
      </header>
      <article className="seoArticle wrap">{children}</article>
      <section className="seoCta wrap">
        <div>
          <p className="sectionLabel">{english ? "Free to use" : "免费使用"}</p>
          <h2>{english ? "Turn your next word list into a vocabulary book worth reading." : "把下一份单词表变成真正想读的词汇书。"}</h2>
        </div>
        <Link href="/#download">{english ? "Download Lexora" : "下载 Lexora"} <span>↓</span></Link>
      </section>
      <footer className="wrap">
        <Link className="brand" href="/"><LexoraWordmark /></Link>
        <p>{english ? "Free bilingual dictionary and personal vocabulary book generator" : "免费的个人英语词汇书生成器与英汉词典"}</p>
        <span>© 2026 Lexora</span>
      </footer>
    </main>
  );
}
