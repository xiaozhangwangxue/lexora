"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { FiBarChart2, FiBookOpen, FiHome, FiSettings, FiZap } from "react-icons/fi";
import { LexoraWordmark } from "../../lexora-wordmark";
import { BetaProvider, useBetaStore } from "./store";
import { Dashboard } from "./components/dashboard";
import { StudyView } from "./components/study-view";
import { LibraryView } from "./components/library-view";
import { StatsView } from "./components/stats-view";
import { SettingsView } from "./components/settings-view";
import styles from "./beta.module.css";

type Tab = "dashboard" | "study" | "library" | "stats" | "settings";
type InstallPrompt = Event & { prompt(): Promise<void>; userChoice: Promise<{ outcome: "accepted" | "dismissed" }> };

function isMobile() {
  return /Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
}

function isStandalone() {
  return window.matchMedia("(display-mode: standalone)").matches || Boolean((navigator as Navigator & { standalone?: boolean }).standalone);
}

export function BetaApp() {
  return <BetaProvider><BetaShell /></BetaProvider>;
}

function BetaShell() {
  const { error } = useBetaStore();
  const [tab, setTab] = useState<Tab>("dashboard");
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
      <span className={styles.betaPill}>学习系统 Beta</span>
      <LexoraWordmark className={styles.installLogo} />
      <h1>先把 Lexora Beta 添加到主屏幕</h1>
      <p>独立启动后才能稳定保存学习队列、复习日志与当前卡片。原版 Lexora 不会被替换。</p>
      <ol><li><b>1</b><span>在浏览器菜单选择“添加到主屏幕”或“安装应用”</span></li><li><b>2</b><span>从主屏幕上的 Lexora Beta 图标启动</span></li></ol>
      {prompt ? <button className={styles.primaryButton} onClick={async () => { await prompt.prompt(); if ((await prompt.userChoice).outcome === "accepted") setPrompt(null); }}>添加到主屏幕</button> : <p className={styles.installHint}>iPhone 请使用 Safari 的分享菜单；Android 请打开浏览器菜单。</p>}
      <Link href="/app" className={styles.textLink}>返回稳定版 /app</Link>
    </section></main>;
  }

  const views: Record<Tab, React.ReactNode> = {
    dashboard: <Dashboard openStudy={() => setTab("study")} openLibrary={() => setTab("library")} />,
    study: <StudyView goHome={() => setTab("dashboard")} />,
    library: <LibraryView startStudy={() => setTab("study")} />,
    stats: <StatsView />,
    settings: <SettingsView />,
  };
  const nav = [
    ["dashboard", "首页", FiHome], ["study", "今日学习", FiZap], ["library", "单词库", FiBookOpen], ["stats", "统计", FiBarChart2], ["settings", "设置", FiSettings],
  ] as const;
  return <main className={styles.shell}>
    <aside className={styles.sidebar}>
      <Link href="/app/beta" className={styles.brand}><LexoraWordmark /><span>Beta</span></Link>
      <nav>{nav.map(([key, label, Icon]) => <button key={key} className={tab === key ? styles.activeNav : ""} onClick={() => setTab(key)}><Icon /><span>{label}</span></button>)}</nav>
      <div className={styles.sidebarFooter}><i />本地学习数据已保护<Link href="/app">稳定版</Link></div>
    </aside>
    <section className={styles.mainArea}>
      <header className={styles.mobileHeader}><LexoraWordmark /><span>学习系统 Beta</span></header>
      {error && <div className={styles.globalError} role="alert">{error}</div>}
      <div className={styles.view}>{views[tab]}</div>
    </section>
    <nav className={styles.bottomNav}>{nav.map(([key, label, Icon]) => <button key={key} className={tab === key ? styles.activeNav : ""} onClick={() => setTab(key)}><Icon /><span>{label}</span></button>)}</nav>
  </main>;
}
