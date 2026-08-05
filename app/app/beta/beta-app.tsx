"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { FiBarChart2, FiBookOpen, FiClock, FiFileText, FiHome, FiMenu, FiRefreshCw, FiSearch, FiSettings, FiZap } from "react-icons/fi";
import { LexoraWordmark } from "../../lexora-wordmark";
import { LexoraWebApp } from "../lexora-web-app";
import type { AppTab } from "../types";
import betaReleaseManifest from "../../../public/beta-version.json";
import { BetaProvider, useBetaStore } from "./store";
import { Dashboard } from "./components/dashboard";
import { StudyView } from "./components/study-view";
import { LibraryView } from "./components/library-view";
import { StatsView } from "./components/stats-view";
import { SettingsView } from "./components/settings-view";
import styles from "./beta.module.css";

type MainTab = AppTab | "learning";
type LearningTab = "dashboard" | "learn" | "review" | "library" | "stats" | "settings";
type InstallPrompt = Event & { prompt(): Promise<void>; userChoice: Promise<{ outcome: "accepted" | "dismissed" }> };

const mainNav = [
  ["search", "单词", FiSearch],
  ["book", "词汇书", FiBookOpen],
  ["records", "生成记录", FiFileText],
  ["history", "历史", FiClock],
  ["learning", "学习", FiZap],
  ["settings", "设置", FiSettings],
] as const;

const learningNav = [
  ["dashboard", "学习首页", FiHome],
  ["learn", "今日学习", FiZap],
  ["review", "今日复习", FiRefreshCw],
  ["library", "单词库", FiBookOpen],
  ["stats", "统计", FiBarChart2],
  ["settings", "学习设置", FiSettings],
] as const;

function isMobile() {
  return /Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
}

function isStandalone() {
  return window.matchMedia("(display-mode: standalone)").matches || Boolean((navigator as Navigator & { standalone?: boolean }).standalone);
}

export function BetaApp() {
  return <BetaProvider><UnifiedLexora /></BetaProvider>;
}

function UnifiedLexora() {
  const { error } = useBetaStore();
  const [mainTab, setMainTab] = useState<MainTab>("search");
  const [learningTab, setLearningTab] = useState<LearningTab>("dashboard");
  const [sidebarExpanded, setSidebarExpanded] = useState(true);
  const [mobile, setMobile] = useState(false);
  const [installed, setInstalled] = useState(false);
  const [prompt, setPrompt] = useState<InstallPrompt | null>(null);

  useEffect(() => {
    const capture = (event: Event) => { event.preventDefault(); setPrompt(event as InstallPrompt); };
    const refresh = () => { setMobile(isMobile()); setInstalled(isStandalone()); };
    refresh();
    window.addEventListener("beforeinstallprompt", capture);
    window.addEventListener("pageshow", refresh);
    document.addEventListener("visibilitychange", refresh);
    void navigator.serviceWorker?.register("/sw.js", { updateViaCache: "none" });
    return () => {
      window.removeEventListener("beforeinstallprompt", capture);
      window.removeEventListener("pageshow", refresh);
      document.removeEventListener("visibilitychange", refresh);
    };
  }, []);

  if (mobile && !installed) {
    return <main className={styles.installPage}><section className={styles.installCard}>
      <span className={styles.betaPill}>完整功能学习 Beta</span>
      <LexoraWordmark className={styles.installLogo} />
      <h1>先把 Lexora Beta 添加到主屏幕</h1>
      <p>安装后可使用词典、词汇书、生成记录、历史、学习系统和全部设置。</p>
      <ol><li><b>1</b><span>在浏览器菜单选择“添加到主屏幕”或“安装应用”</span></li><li><b>2</b><span>从主屏幕上的 Lexora Beta 图标启动</span></li></ol>
      {prompt ? <button className={styles.primaryButton} onClick={async () => { await prompt.prompt(); if ((await prompt.userChoice).outcome === "accepted") setPrompt(null); }}>添加到主屏幕</button> : <p className={styles.installHint}>iPhone 请使用 Safari 的分享菜单；Android 请打开浏览器菜单。</p>}
      <Link href="/app" className={styles.textLink}>返回稳定版 /app</Link>
    </section></main>;
  }

  const stableTab = mainTab === "learning" ? null : mainTab;
  return <main className={styles.unifiedShell}>
    <section className={`${styles.macWindow} ${sidebarExpanded ? styles.sidebarExpanded : styles.sidebarCompact}`}>
      <header className={styles.macTopBar}>
        <div className={styles.trafficLights} aria-label="macOS 窗口控制装饰"><i /><i /><i /></div>
        <Link href="/" className={styles.unifiedBrand}><LexoraWordmark /><span>Beta</span></Link>
        <div className={styles.localStatus}><i />本地数据</div>
      </header>
      <nav className={styles.mainTabs} aria-label="Lexora 主要功能">
        <div className={styles.mainTabItems}>
          {mainNav.map(([key, label, Icon]) => <button key={key} aria-label={label} title={label} className={mainTab === key ? styles.selectedTopTab : ""} onClick={() => setMainTab(key)}><Icon /><span>{label}</span></button>)}
        </div>
        <button className={styles.sidebarToggle} onClick={() => setSidebarExpanded((value) => !value)} aria-label={sidebarExpanded ? "收起边栏" : "展开边栏"}><FiMenu /><span>{sidebarExpanded ? "收起边栏" : "展开边栏"}</span></button>
      </nav>
      {error && <div className={styles.globalError} role="alert">{error}</div>}
      <div className={styles.unifiedContent}>
        {stableTab ? <LexoraWebApp embedded activeTab={stableTab} onActiveTabChange={setMainTab} releaseLabel={`v${betaReleaseManifest.version}`} /> : <LearningWorkspace tab={learningTab} setTab={setLearningTab} />}
      </div>
    </section>
  </main>;
}

function LearningWorkspace({ tab, setTab }: { tab: LearningTab; setTab(tab: LearningTab): void }) {
  const tabsRef = useRef<HTMLElement | null>(null);

  function selectLearningTab(nextTab: LearningTab, index: number) {
    setTab(nextTab);
    const tabs = tabsRef.current;
    if (!tabs || tabs.scrollWidth <= tabs.clientWidth + 1) return;
    const button = tabs.children.item(index) as HTMLElement | null;
    if (!button) return;
    const maxScroll = tabs.scrollWidth - tabs.clientWidth;
    const target = index === 0
      ? 0
      : index === learningNav.length - 1
        ? maxScroll
        : button.offsetLeft + button.offsetWidth / 2 - tabs.clientWidth / 2;
    tabs.scrollTo({
      left: Math.max(0, Math.min(maxScroll, target)),
      behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
    });
  }

  const views: Record<LearningTab, React.ReactNode> = {
    dashboard: <Dashboard openStudy={() => setTab("learn")} openLibrary={() => setTab("library")} />,
    learn: <StudyView focus="new" title="今日学习" goHome={() => setTab("dashboard")} openReview={() => setTab("review")} />,
    review: <StudyView focus="review" title="今日复习" goHome={() => setTab("dashboard")} />,
    library: <LibraryView startStudy={() => setTab("learn")} />,
    stats: <StatsView />,
    settings: <SettingsView />,
  };
  return <section className={styles.learningWorkspace}>
    <header className={styles.learningHeader}>
      <div><div className={styles.learningTitleRow}><h1>学习</h1><span className={styles.betaPill}>间隔重复学习系统</span></div><p>新词、到期复习、个人单词库、统计与学习设置都集中在这里。</p></div>
      <div className={styles.learningPrivacy}><i />学习记录仅保存在当前设备</div>
    </header>
    <nav ref={tabsRef} className={styles.learningTabs} aria-label="学习功能">
      {learningNav.map(([key, label, Icon], index) => <button key={key} className={tab === key ? styles.selectedLearningTab : ""} onClick={() => selectLearningTab(key, index)}><Icon /><span>{label}</span></button>)}
    </nav>
    <div className={styles.learningContent}>{views[tab]}</div>
  </section>;
}
