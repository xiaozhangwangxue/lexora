"use client";

import { FormEvent, useEffect, useMemo, useRef, useState } from "react";
import Image from "next/image";
import Link from "next/link";
import type { IconType } from "react-icons";
import { FaAndroid, FaApple, FaDownload, FaLinux, FaWindows } from "react-icons/fa6";
import { LexoraWordmark } from "./lexora-wordmark";
import { useSiteLanguage } from "./use-site-language";

type SortMode = "custom" | "alphabetical" | "length" | "difficulty";
type PlatformKey = "macos" | "windows" | "linux" | "android";
type DetectedPlatform = PlatformKey | "ios" | "unknown";
type DragPreview = { word: string; x: number; y: number; width: number; grabOffsetY: number };

const seedWords = ["serendipity", "lucid", "resilient", "wanderlust"];
const donationCodes = {
  wechat: "https://photo.12323456.xyz/api/rfile/%E5%BE%AE%E4%BF%A1.png",
  alipay: "https://photo.12323456.xyz/api/rfile/%E6%94%AF%E4%BB%98%E5%AE%9D.jpg",
};

const currentVersion = "v1.1.1";
const platforms: Array<{ key: PlatformKey; name: string; noteZh: string; noteEn: string; Icon: IconType; file: string }> = [
  { key: "macos", name: "macOS", noteZh: "macOS 12+ · 拖动安装 DMG", noteEn: "macOS 12+ · Drag-to-install DMG", Icon: FaApple, file: `lexora-macos-${currentVersion}.dmg` },
  { key: "windows", name: "Windows", noteZh: "Windows 10 / 11 · 安装程序", noteEn: "Windows 10 / 11 · Installer", Icon: FaWindows, file: `lexora-windows-${currentVersion}-setup.exe` },
  { key: "linux", name: "Linux", noteZh: "64 位 Linux · tar.gz", noteEn: "64-bit Linux · tar.gz", Icon: FaLinux, file: `lexora-linux-${currentVersion}.tar.gz` },
  { key: "android", name: "Android", noteZh: "Android 8+ · APK", noteEn: "Android 8+ · APK", Icon: FaAndroid, file: `lexora-android-${currentVersion}.apk` },
];

function detectPlatform(): DetectedPlatform {
  const nav = navigator as Navigator & { userAgentData?: { platform?: string } };
  const userAgent = nav.userAgent.toLowerCase();
  const platform = (nav.userAgentData?.platform || nav.platform || "").toLowerCase();
  if (/android/.test(userAgent)) return "android";
  if (/iphone|ipad|ipod/.test(userAgent) || (platform === "macintel" && nav.maxTouchPoints > 1)) return "ios";
  if (/win/.test(platform) || /windows/.test(userAgent)) return "windows";
  if (/mac/.test(platform) || /macintosh/.test(userAgent)) return "macos";
  if (/linux|x11/.test(platform) || /linux/.test(userAgent)) return "linux";
  return "unknown";
}

const installGuides: Record<PlatformKey, { zh: string[]; en: string[] }> = {
  macos: {
    zh: ["打开 DMG，按背景箭头将 Lexora 拖到 Applications 文件夹。", "首次启动时进入“应用程序”，按住 Control 点击 Lexora，选择“打开”。", "若 macOS 提示未验证开发者，在确认文件来自本官网后再选择打开。"],
    en: ["Open the DMG and follow the background arrow to drag Lexora into Applications.", "Control-click Lexora in Applications the first time, then choose Open.", "If macOS warns about an unidentified developer, verify this official site first, then confirm Open."],
  },
  windows: {
    zh: ["双击安装程序并按向导完成安装，最后可选择立即启动 Lexora（默认勾选）。", "若 SmartScreen 出现提示，先确认下载域名为 lexora.12323456.xyz。", "点击“更多信息”，然后选择“仍要运行”。"],
    en: ["Open the installer and follow the setup wizard; the final Launch Lexora option is checked by default.", "If SmartScreen appears, first verify that the file came from lexora.12323456.xyz.", "Choose More info, then Run anyway."],
  },
  linux: {
    zh: ["解压 tar.gz 文件。", "若无法启动，在文件属性中允许作为程序执行，或使用 chmod +x。", "启动 lexora 可执行文件。"],
    en: ["Extract the tar.gz archive.", "If needed, allow the lexora file to run as a program or use chmod +x.", "Launch the lexora executable."],
  },
  android: {
    zh: ["从 v0.3.0 或更高版本可直接覆盖安装 v1.1.1；只有 v0.2.0 需先卸载一次。", "下载 APK，系统询问时允许浏览器安装未知来源应用。", "确认文件来自本官网后，选择“仍要安装”；安装后可关闭该权限。"],
    en: ["v0.3.0 and newer can update directly to v1.1.1. Only v0.2.0 requires one uninstall first.", "Download the APK and allow your browser to install unknown apps when Android asks.", "After verifying this official site, choose Install anyway. You can revoke that permission afterward."],
  },
};

function difficultyScore(word: string) {
  return word.length + [...word].filter((letter) => "qxzj".includes(letter)).length * 2;
}

export default function Home() {
  const [words, setWords] = useState(seedWords);
  const [input, setInput] = useState("");
  const [sort, setSort] = useState<SortMode>("custom");
  const { language, setLanguage, zh } = useSiteLanguage();
  const [progress, setProgress] = useState<number | null>(null);
  const [downloadChoice, setDownloadChoice] = useState<PlatformKey | null>(null);
  const [detectedPlatform, setDetectedPlatform] = useState<DetectedPlatform | null>(null);
  const draggedWord = useRef<string | null>(null);
  const listRef = useRef<HTMLOListElement | null>(null);
  const dragPreviewRef = useRef<DragPreview | null>(null);
  const [draggingWord, setDraggingWord] = useState<string | null>(null);
  const [dropTargetWord, setDropTargetWord] = useState<string | null>(null);
  const [dragPreview, setDragPreview] = useState<DragPreview | null>(null);
  const selectedPlatform = platforms.find((platform) => platform.key === downloadChoice);
  const recommendedPlatform = platforms.find((platform) => platform.key === detectedPlatform);
  const RecommendedIcon = recommendedPlatform?.Icon ?? (detectedPlatform === "ios" ? FaApple : FaDownload);
  const orderedPlatforms = useMemo(() => {
    if (!recommendedPlatform) return platforms;
    return [recommendedPlatform, ...platforms.filter((platform) => platform.key !== recommendedPlatform.key)];
  }, [recommendedPlatform]);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      setDetectedPlatform(detectPlatform());
    });
    return () => window.cancelAnimationFrame(frame);
  }, []);

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

  function captureListPositions() {
    const positions = new Map<string, number>();
    listRef.current?.querySelectorAll<HTMLElement>("[data-demo-word]").forEach((item) => {
      if (item.dataset.demoWord) positions.set(item.dataset.demoWord, item.getBoundingClientRect().top);
    });
    return positions;
  }

  function animateListFrom(positions: Map<string, number>) {
    window.requestAnimationFrame(() => {
      listRef.current?.querySelectorAll<HTMLElement>("[data-demo-word]").forEach((item) => {
        const word = item.dataset.demoWord;
        const previousTop = word ? positions.get(word) : undefined;
        if (previousTop === undefined) return;
        const delta = previousTop - item.getBoundingClientRect().top;
        if (Math.abs(delta) < 1) return;
        item.animate(
          [{ transform: `translateY(${delta}px)` }, { transform: "translateY(0)" }],
          { duration: 210, easing: "cubic-bezier(.22,1,.36,1)" },
        );
      });
    });
  }

  function beginReorder(word: string, preview: DragPreview) {
    if (sort !== "custom") {
      setWords(visibleWords);
      setSort("custom");
    }
    draggedWord.current = word;
    dragPreviewRef.current = preview;
    setDraggingWord(word);
    setDropTargetWord(null);
    setDragPreview(preview);
  }

  function reorderOver(targetWord: string) {
    const activeWord = draggedWord.current;
    if (!activeWord || activeWord === targetWord) return;
    const previousPositions = captureListPositions();
    setDropTargetWord(targetWord);
    setWords((current) => {
      const next = [...current];
      const from = next.indexOf(activeWord);
      const to = next.indexOf(targetWord);
      if (from < 0 || to < 0) return current;
      next.splice(from, 1);
      next.splice(to, 0, activeWord);
      return next;
    });
    animateListFrom(previousPositions);
  }

  function finishReorder() {
    draggedWord.current = null;
    dragPreviewRef.current = null;
    setDraggingWord(null);
    setDropTargetWord(null);
    setDragPreview(null);
  }

  function moveWord(word: string, direction: -1 | 1) {
    const next = sort === "custom" ? [...words] : [...visibleWords];
    const from = next.indexOf(word);
    const to = from + direction;
    if (from < 0 || to < 0 || to >= next.length) return;
    const previousPositions = captureListPositions();
    next.splice(from, 1);
    next.splice(to, 0, word);
    setWords(next);
    setSort("custom");
    animateListFrom(previousPositions);
  }

  return (
    <main>
      <nav className="nav wrap" aria-label="Primary navigation">
        <a className="brand" href="#top" aria-label="Lexora home">
          <img src="/lexora-icon-192.png" alt="" width="36" height="36" />
          <LexoraWordmark />
        </a>
        <div className="navLinks">
          <a href="#how">{zh ? "工作方式" : "How it works"}</a>
          <a href="#download">{zh ? "下载" : "Download"}</a>
          <Link href="/donate">{zh ? "捐款" : "Donate"}</Link>
          <a className="githubProfileButton" href="https://github.com/xiaozhangwangxue/lexora" target="_blank" rel="noreferrer">
            <span className="githubProfileIcon"><Image src="/github-mark.png" alt="" width={25} height={25} unoptimized /><Image src="/github-avatar.png" alt="" width={15} height={15} unoptimized /></span>
            GitHub
          </a>
          <button className="language" onClick={() => setLanguage(language === "zh" ? "en" : "zh")}>
            {zh ? "EN" : "中文"}
          </button>
        </div>
      </nav>

      <section className="hero wrap" id="top">
        <LexoraWordmark hero />
        <div className="eyebrow"><span /> {zh ? "你的词汇，终于井然有序" : "Your vocabulary, finally organized"}</div>
        <h1>{zh ? <><span className="heroLine">把零散单词，变成</span><br /><em className="heroLine">真正想读的词汇书。</em></> : <>Turn loose words into a<br /><em>book worth reading.</em></>}</h1>
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
            <div className="miniBrand"><LexoraWordmark /></div>
            <div className="windowMenu">•••</div>
          </div>
          <div className="appBody">
            <aside>
              <button className="active"><span>◫</span> {zh ? "单词" : "Words"}</button>
              <button><span>↺</span> {zh ? "历史" : "History"}</button>
              <div className="asideFoot">{currentVersion} · Open source</div>
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
                <span className="reorderHint">{zh ? "拖动手柄调整顺序" : "Drag the handle to reorder"}</span>
                <select value={sort} onChange={(event) => setSort(event.target.value as SortMode)} aria-label="Sort words">
                  <option value="custom">{zh ? "自定义顺序" : "Custom order"}</option>
                  <option value="alphabetical">A–Z</option>
                  <option value="length">{zh ? "单词长度" : "Word length"}</option>
                  <option value="difficulty">{zh ? "难度" : "Difficulty"}</option>
                </select>
              </div>
              <ol className="wordList" ref={listRef}>
                {visibleWords.map((word, index) => (
                  <li
                    key={word}
                    data-demo-word={word}
                    className={draggingWord === word ? "isDragging" : dropTargetWord === word ? "isDropTarget" : undefined}
                  >
                    <span className="wordIndex">{String(index + 1).padStart(2, "0")}</span>
                    <span className="wordName">{word}<small>{word.length} {zh ? "个字母" : "letters"}</small></span>
                    <button aria-label={`Delete ${word}`} onClick={() => setWords((current) => current.filter((item) => item !== word))}>×</button>
                    <button
                      className="dragHandle"
                      draggable={false}
                      aria-label={zh ? `调整 ${word} 的顺序` : `Reorder ${word}`}
                      title={zh ? "拖动调整顺序，或用上下方向键" : "Drag to reorder, or use the arrow keys"}
                      onDragStart={(event) => event.preventDefault()}
                      onPointerDown={(event) => {
                        event.preventDefault();
                        const item = event.currentTarget.closest("[data-demo-word]") as HTMLElement | null;
                        if (!item) return;
                        const rect = item.getBoundingClientRect();
                        beginReorder(word, {
                          word,
                          x: rect.left,
                          y: rect.top,
                          width: rect.width,
                          grabOffsetY: event.clientY - rect.top,
                        });
                        event.currentTarget.setPointerCapture(event.pointerId);
                      }}
                      onPointerMove={(event) => {
                        if (!draggedWord.current) return;
                        const preview = dragPreviewRef.current;
                        if (preview) {
                          const nextPreview = { ...preview, y: event.clientY - preview.grabOffsetY };
                          dragPreviewRef.current = nextPreview;
                          setDragPreview(nextPreview);
                        }
                        const target = document.elementFromPoint(event.clientX, event.clientY)?.closest("[data-demo-word]") as HTMLElement | null;
                        const targetWord = target?.dataset.demoWord;
                        if (targetWord) reorderOver(targetWord);
                      }}
                      onPointerUp={(event) => {
                        if (event.currentTarget.hasPointerCapture(event.pointerId)) {
                          event.currentTarget.releasePointerCapture(event.pointerId);
                        }
                        finishReorder();
                      }}
                      onPointerCancel={finishReorder}
                      onKeyDown={(event) => {
                        if (event.key === "ArrowUp" || event.key === "ArrowDown") {
                          event.preventDefault();
                          moveWord(word, event.key === "ArrowUp" ? -1 : 1);
                        }
                      }}
                    >⠿</button>
                  </li>
                ))}
              </ol>
              {dragPreview && (
                <div
                  className="dragPreview"
                  aria-hidden="true"
                  style={{ left: dragPreview.x, top: dragPreview.y, width: dragPreview.width }}
                >
                  <span className="wordIndex">{String(visibleWords.indexOf(dragPreview.word) + 1).padStart(2, "0")}</span>
                  <span className="wordName">{dragPreview.word}<small>{dragPreview.word.length} {zh ? "个字母" : "letters"}</small></span>
                  <span className="dragPreviewHandle">⠿</span>
                </div>
              )}
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
          <p>{zh ? "中号使用紧凑双栏，小字号可自动切换三栏；设置、生成记录和完整单词历史都在手边。" : "Medium type uses two compact columns, while sufficiently small type automatically switches to three."}</p>
        </article>
      </section>

      <section className="download wrap" id="download">
        <div>
          <p className="sectionLabel">{zh ? "所有设备" : "Every device"}</p>
          <h2>{zh ? "词汇跟着你走。" : "Your words go with you."}</h2>
          <p>{zh ? "Lexora 会在本地识别你的设备并推荐对应版本；设备信息不会上传。你也可以随时选择其他平台。" : "Lexora detects your device locally and recommends the matching build without uploading device data. You can still choose another platform."}</p>
        </div>
        <div className="downloadChoices">
          <div className={`recommendedDownload${recommendedPlatform ? " isReady" : ""}`} aria-live="polite">
            <div className="recommendedDownloadCopy">
              <span className="recommendedBadge">{zh ? "为你的设备推荐" : "Recommended for your device"}</span>
              <span className="platformIcon recommendedPlatformIcon" aria-hidden="true"><RecommendedIcon /></span>
              <span>
                <strong>{recommendedPlatform
                  ? `Lexora for ${recommendedPlatform.name}`
                  : detectedPlatform === "ios"
                    ? (zh ? "iPhone / iPad 暂无对应版本" : "No iPhone / iPad build yet")
                    : detectedPlatform === "unknown"
                      ? (zh ? "选择适合你的版本" : "Choose the right version")
                      : (zh ? "正在识别设备…" : "Detecting your device…")}</strong>
                <small>{recommendedPlatform
                  ? (zh ? recommendedPlatform.noteZh : recommendedPlatform.noteEn)
                  : detectedPlatform === "ios"
                    ? (zh ? "可在 Android 或电脑上使用 Lexora" : "Use Lexora on Android or a computer")
                    : (zh ? "Android、macOS、Windows 与 Linux" : "Android, macOS, Windows, and Linux")}</small>
              </span>
            </div>
            {recommendedPlatform ? (
              <button onClick={() => setDownloadChoice(recommendedPlatform.key)}>
                {zh ? `下载 ${recommendedPlatform.name} 版` : `Download for ${recommendedPlatform.name}`} <span>↓</span>
              </button>
            ) : (
              <a href="#all-downloads">{zh ? "查看全部版本" : "View all versions"} <span>↓</span></a>
            )}
          </div>
          <div className="platformGrid" id="all-downloads">
            {orderedPlatforms.map((platform) => {
              const PlatformIcon = platform.Icon;
              return (
              <a
                className={platform.key === detectedPlatform ? "isRecommended" : undefined}
                key={platform.name}
                href={`/downloads/${platform.file}`}
                onClick={(event) => { event.preventDefault(); setDownloadChoice(platform.key); }}
              >
                <span className={`platformIcon platformIcon-${platform.key}`} aria-hidden="true"><PlatformIcon /></span>
                <span><strong>{platform.name}</strong><small>{zh ? platform.noteZh : platform.noteEn}</small></span>
                {platform.key === detectedPlatform && <span className="platformRecommendedLabel">{zh ? "推荐" : "Recommended"}</span>}
                <span className="downloadArrow">↓</span>
              </a>
              );
            })}
          </div>
        </div>
      </section>

      {selectedPlatform && downloadChoice && (
        <div className="installOverlay" role="presentation" onMouseDown={() => setDownloadChoice(null)}>
          <section className="installDialog" role="dialog" aria-modal="true" aria-labelledby="install-title" onMouseDown={(event) => event.stopPropagation()}>
            <button className="installClose" aria-label={zh ? "关闭" : "Close"} onClick={() => setDownloadChoice(null)}>×</button>
            <p className="sectionLabel">{zh ? "安装说明" : "Installation guide"}</p>
            <h2 id="install-title">{zh ? `安装 Lexora for ${selectedPlatform.name}` : `Install Lexora for ${selectedPlatform.name}`}</h2>
            <div className="riskNotice">
              <strong>{zh ? "可能出现系统风险提示" : "Your system may show a risk warning"}</strong>
              <p>{zh ? "Lexora 尚未上架应用商店，也未购买所有平台的商业签名。请先确认当前域名和 GitHub 仓库，然后按下面步骤选择“仍要安装/运行”。" : "Lexora is not yet distributed through app stores and does not have commercial signing for every platform. Verify this domain and GitHub repository first, then follow the steps below to continue."}</p>
            </div>
            <ol>
              {installGuides[downloadChoice][zh ? "zh" : "en"].map((step) => <li key={step}>{step}</li>)}
            </ol>
            <div className="installActions">
              <button onClick={() => setDownloadChoice(null)}>{zh ? "取消" : "Cancel"}</button>
              <a href={`/downloads/${selectedPlatform.file}`} download onClick={() => setDownloadChoice(null)}>
                {zh ? "我已了解，继续下载" : "I understand, continue download"} <span>↓</span>
              </a>
            </div>
          </section>
        </div>
      )}

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
            <Image src={donationCodes.wechat} alt="微信支付收款码" width={300} height={300} unoptimized />
            <span><b>微信支付</b><small>WeChat Pay</small></span>
          </Link>
          <Link href="/donate" aria-label={zh ? "打开支付宝捐款二维码" : "Open Alipay donation code"}>
            <Image src={donationCodes.alipay} alt="支付宝收款码" width={300} height={300} unoptimized />
            <span><b>支付宝</b><small>Alipay</small></span>
          </Link>
        </div>
      </section>

      <footer className="wrap">
        <a className="brand" href="#top"><LexoraWordmark /></a>
        <p>{zh ? "把单词变成值得保存的东西。" : "Make your words worth keeping."}</p>
        <span>© 2026 Lexora · <Link href="/donate">{zh ? "支持项目" : "Support"}</Link></span>
      </footer>
    </main>
  );
}
