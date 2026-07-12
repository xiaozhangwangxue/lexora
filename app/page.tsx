"use client";

import { FormEvent, useMemo, useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { useSiteLanguage } from "./use-site-language";

type SortMode = "custom" | "alphabetical" | "length" | "difficulty";

const seedWords = ["serendipity", "lucid", "resilient", "wanderlust"];
const donationQrBase = "https://raw.githubusercontent.com/xiaozhangwangxue/autoword/main/assets/donate";

const platforms = [
  { name: "macOS", note: "Apple silicon & Intel", icon: "⌘", file: "lexora-macos.zip" },
  { name: "Windows", note: "Windows 10 / 11", icon: "⊞", file: "lexora-windows.zip" },
  { name: "Linux", note: "64-bit bundle", icon: "◇", file: "lexora-linux.tar.gz" },
  { name: "Android", note: "Android 8+", icon: "◒", file: "lexora-android.apk" },
];

function difficultyScore(word: string) {
  return word.length + [...word].filter((letter) => "qxzj".includes(letter)).length * 2;
}

export default function Home() {
  const [words, setWords] = useState(seedWords);
  const [input, setInput] = useState("");
  const [sort, setSort] = useState<SortMode>("custom");
  const { language, setLanguage, zh } = useSiteLanguage();
  const [progress, setProgress] = useState<number | null>(null);

  const visibleWords = useMemo(() => {
    const next = [...words];
    if (sort === "alphabetical") next.sort();
    if (sort === "length") next.sort((a, b) => a.length - b.length);
    if (sort === "difficulty") next.sort((a, b) => difficultyScore(a) - difficultyScore(b));
    return next;
  }, [words, sort]);

  function addWord(event: FormEvent) {
    event.preventDefault();
    const word = input.trim().toLowerCase();
    if (!/^[a-z][a-z'-]*$/.test(word) || words.includes(word)) return;
    setWords((current) => [...current, word]);
    setInput("");
    setSort("custom");
  }

  function generate() {
    if (!words.length || progress !== null) return;
    setProgress(8);
    let value = 8;
    const timer = window.setInterval(() => {
      value += Math.max(3, (100 - value) * 0.16);
      if (value >= 100) {
        window.clearInterval(timer);
        setProgress(100);
        window.setTimeout(() => setProgress(null), 1200);
      } else setProgress(value);
    }, 180);
  }

  return (
    <main>
      <nav className="nav wrap" aria-label="Primary navigation">
        <a className="brand" href="#top" aria-label="Lexora home">
          <img src="/lexora-icon-192.png" alt="" width="36" height="36" />
          <span>Lexora</span>
        </a>
        <div className="navLinks">
          <a href="#how">{zh ? "工作方式" : "How it works"}</a>
          <a href="#download">{zh ? "下载" : "Download"}</a>
          <Link href="/donate">{zh ? "捐款" : "Donate"}</Link>
          <a href="https://github.com/" target="_blank" rel="noreferrer">GitHub</a>
          <button className="language" onClick={() => setLanguage(language === "zh" ? "en" : "zh")}>
            {zh ? "EN" : "中文"}
          </button>
        </div>
      </nav>

      <section className="hero wrap" id="top">
        <div className="eyebrow"><span /> {zh ? "你的词汇，终于井然有序" : "Your vocabulary, finally organized"}</div>
        <h1>{zh ? <>把零散单词，变成<br /><em>真正想读的词汇书。</em></> : <>Turn loose words into a<br /><em>book worth reading.</em></>}</h1>
        <p className="heroCopy">
          {zh
            ? "输入单词，Lexora 自动补全难度、词频、英美音标、近反义词、例句与完整中文翻译，并生成紧凑精美的 PDF。"
            : "Type your words. Lexora adds difficulty, frequency, US & UK phonetics, related words, examples, and complete Chinese translations—then typesets a beautiful PDF."}
        </p>
        <div className="heroActions">
          <a className="primaryButton" href="#download">{zh ? "免费下载" : "Download free"} <span>↓</span></a>
          <a className="textButton" href="#demo">{zh ? "试试交互演示" : "Try the live demo"} <span>↘</span></a>
        </div>

        <div className="appWindow" id="demo">
          <div className="windowBar">
            <div className="traffic"><i /><i /><i /></div>
            <div className="miniBrand"><img src="/lexora-icon-192.png" alt="" width="21" height="21" /> Lexora</div>
            <div className="windowMenu">•••</div>
          </div>
          <div className="appBody">
            <aside>
              <button className="active"><span>◫</span> {zh ? "单词" : "Words"}</button>
              <button><span>↺</span> {zh ? "历史" : "History"}</button>
              <div className="asideFoot">v0.2 · Open source</div>
            </aside>
            <section className="composer">
              <div className="composerHead">
                <h2>{zh ? "创建词汇书" : "Create a vocabulary book"}</h2>
                <p>{zh ? "输入一个英文单词并按下回车键" : "Type an English word and press Enter"}</p>
              </div>
              <form className="wordInput" onSubmit={addWord}>
                <span>⌕</span>
                <input value={input} onChange={(event) => setInput(event.target.value)} placeholder={zh ? "输入单词…" : "Enter a word…"} aria-label="English word" />
                <kbd>↵</kbd>
              </form>
              <button className="generate" onClick={generate} disabled={!words.length || progress !== null}>
                <span>✦</span> {progress === null ? (zh ? "开始生成" : "Start generating") : (zh ? "正在生成…" : "Generating…")}
              </button>
              {progress !== null && <div className="progress" aria-label="Generation progress"><i style={{ width: `${progress}%` }} /></div>}
              <div className="listHeader">
                <strong>{words.length} {zh ? "个单词" : words.length === 1 ? "word" : "words"}</strong>
                <select value={sort} onChange={(event) => setSort(event.target.value as SortMode)} aria-label="Sort words">
                  <option value="custom">{zh ? "自定义顺序" : "Custom order"}</option>
                  <option value="alphabetical">A–Z</option>
                  <option value="length">{zh ? "单词长度" : "Word length"}</option>
                  <option value="difficulty">{zh ? "难度" : "Difficulty"}</option>
                </select>
              </div>
              <ol className="wordList">
                {visibleWords.map((word, index) => (
                  <li key={word}>
                    <span className="wordIndex">{String(index + 1).padStart(2, "0")}</span>
                    <span className="wordName">{word}<small>{word.length} {zh ? "个字母" : "letters"}</small></span>
                    <button aria-label={`Delete ${word}`} onClick={() => setWords((current) => current.filter((item) => item !== word))}>×</button>
                    <span className="drag">⠿</span>
                  </li>
                ))}
              </ol>
            </section>
          </div>
        </div>
      </section>

      <section className="statement" id="how">
        <div className="wrap statementGrid">
          <p className="sectionLabel">{zh ? "从列表到词汇书" : "From list to lexicon"}</p>
          <h2>{zh ? "查词应该是过程，阅读才是结果。" : "Lookup is the process. Reading is the point."}</h2>
          <p>{zh ? "Lexora 从可靠的在线词典与语料数据中整理每个单词，再用为学习设计的双语版式生成 PDF。信息足够完整，页面仍然轻盈。" : "Lexora gathers each word from trusted dictionary and corpus sources, then creates a bilingual PDF designed for study—rich in context, light on clutter."}</p>
        </div>
      </section>

      <section className="features wrap">
        <article className="feature featureLarge">
          <span className="featureNumber">01</span>
          <div>
            <p className="sectionLabel">{zh ? "快速整理" : "Fast capture"}</p>
            <h3>{zh ? "像搜索一样简单，像播放列表一样灵活。" : "As simple as search. As flexible as a playlist."}</h3>
            <p>{zh ? "按回车添加，长按调整顺序，滑动删除，或按字母、长度与难度自动排序。" : "Press Enter to add, long-press to reorder, swipe to delete, or sort by alphabet, length, and difficulty."}</p>
          </div>
          <div className="stackVisual"><span>serendipity</span><span>resilient</span><span>lucid</span></div>
        </article>
        <article className="feature">
          <span className="featureNumber">02</span>
          <div className="soundVisual"><i /><i /><i /><i /><i /><i /><i /></div>
          <h3>{zh ? "一个单词，完整语境。" : "One word. Full context."}</h3>
          <p>{zh ? "难度、词频、英美音标、近反义词与双语例句一次补全。" : "Difficulty, frequency, phonetics, related words, and bilingual examples in one pass."}</p>
        </article>
        <article className="feature darkFeature">
          <span className="featureNumber">03</span>
          <div className="pdfMini"><b>LEXORA</b><strong>lucid</strong><small>/ˈluːsɪd/ · B2</small><p>expressed clearly; easy to understand</p><em>清晰的；易懂的</em></div>
          <h3>{zh ? "PDF 不只是导出，而是成品。" : "Not an export. A finished book."}</h3>
          <p>{zh ? "紧凑、清晰、适合屏幕阅读和打印。" : "Compact, polished, and made for screens or paper."}</p>
        </article>
      </section>

      <section className="download wrap" id="download">
        <div>
          <p className="sectionLabel">{zh ? "所有设备" : "Every device"}</p>
          <h2>{zh ? "词汇跟着你走。" : "Your words go with you."}</h2>
          <p>{zh ? "Lexora 为每个平台调整导航、交互密度和分享方式，同时保持同样安静、清晰的体验。" : "Lexora adapts navigation, density, and sharing to every platform while keeping the same calm, focused experience."}</p>
        </div>
        <div className="platformGrid">
          {platforms.map((platform) => (
            <a key={platform.name} href={`/downloads/${platform.file}`}>
              <span className="platformIcon">{platform.icon}</span>
              <span><strong>{platform.name}</strong><small>{platform.note}</small></span>
              <span className="downloadArrow">↓</span>
            </a>
          ))}
        </div>
      </section>

      <section className="support">
        <div className="wrap supportInner">
          <div className="supportMark">♥</div>
          <div>
            <p className="sectionLabel">{zh ? "支持独立开发" : "Support independent work"}</p>
            <h2>{zh ? "让 Lexora 继续变得更好。" : "Help Lexora keep getting better."}</h2>
            <p>{zh ? "Lexora 免费使用。你的自愿支持会用于词典数据、跨平台测试、签名与长期维护。" : "Lexora is free to use. Voluntary support helps cover dictionary data, cross-platform testing, signing, and long-term maintenance."}</p>
          </div>
          <Link className="supportButton" href="/donate">{zh ? "打开捐款页面" : "Open donation page"} <span>↗</span></Link>
        </div>
      </section>

      <section className="homeDonateChannels wrap" aria-labelledby="donation-channels-title">
        <div className="homeDonateIntro">
          <p className="sectionLabel">{zh ? "捐款渠道" : "Donation channels"}</p>
          <h2 id="donation-channels-title">{zh ? "谢谢你支持 Lexora。" : "Thank you for supporting Lexora."}</h2>
          <p>{zh ? "捐款完全自愿，不会解锁额外付费功能。可直接扫码，或打开独立捐款页面查看大图。" : "Donations are entirely optional and never unlock paid features. Scan here, or open the donation page for full-size codes."}</p>
          <Link href="/donate">{zh ? "查看完整捐款页面 →" : "Open the full donation page →"}</Link>
        </div>
        <div className="homeQrGrid">
          <Link href="/donate" aria-label={zh ? "打开微信支付捐款二维码" : "Open WeChat Pay donation code"}>
            <Image src={`${donationQrBase}/wechat.png`} alt="微信支付收款码" width={300} height={300} unoptimized />
            <span><b>微信支付</b><small>WeChat Pay</small></span>
          </Link>
          <Link href="/donate" aria-label={zh ? "打开支付宝捐款二维码" : "Open Alipay donation code"}>
            <Image src={`${donationQrBase}/alipay.jpg`} alt="支付宝收款码" width={300} height={300} unoptimized />
            <span><b>支付宝</b><small>Alipay</small></span>
          </Link>
        </div>
      </section>

      <footer className="wrap">
        <a className="brand" href="#top"><img src="/lexora-icon-192.png" alt="" width="30" height="30" /><span>Lexora</span></a>
        <p>{zh ? "把单词变成值得保存的东西。" : "Make your words worth keeping."}</p>
        <span>© 2026 Lexora · <Link href="/donate">{zh ? "支持项目" : "Support"}</Link></span>
      </footer>
    </main>
  );
}
