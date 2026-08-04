"use client";

import Link from "next/link";
import { FiBookOpen, FiDatabase, FiExternalLink, FiHeadphones, FiInfo, FiSettings } from "react-icons/fi";
import { modeLabels, type ReviewMode, type StudyMode } from "../domain/types";
import { useBetaStore } from "../store";
import styles from "../beta.module.css";

const modes = Object.entries(modeLabels) as [ReviewMode, string][];

export function SettingsView() {
  const { state, loaded, updateSettings } = useBetaStore();
  if (!loaded) return <div className={styles.loadingState}>正在读取设置…</div>;
  const settings = state.settings;
  return <div className={styles.page}>
    <div className={styles.pageTitle}><div><span className={styles.betaPill}>本地设置</span><h1>设置</h1><p>学习偏好只保存在当前设备，不需要账号。</p></div></div>
    <section className={styles.settingsSection}><div className={styles.settingsTitle}><FiBookOpen /><div><h2>学习设置</h2><p>控制新词数量和题型组合</p></div></div><SettingRow label="每日新词数量" detail="只限制新词，不会隐藏到期任务"><input type="number" min="0" max="100" value={settings.dailyNewWordLimit} onChange={(event) => updateSettings({ dailyNewWordLimit: Math.max(0, Math.min(100, Number(event.target.value))) })} /></SettingRow><SettingRow label="默认学习模式" detail="综合模式会根据词条资料安全轮换"><select value={settings.defaultStudyMode} onChange={(event) => updateSettings({ defaultStudyMode: event.target.value as StudyMode })}><option value="mixed">综合模式</option>{modes.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></SettingRow><div className={styles.modeSettings}><b>启用的复习模式</b>{modes.map(([value, label]) => <label key={value}><input type="checkbox" checked={settings.enabledReviewModes.includes(value)} onChange={(event) => { const next = event.target.checked ? [...settings.enabledReviewModes, value] : settings.enabledReviewModes.filter((mode) => mode !== value); updateSettings({ enabledReviewModes: next.length ? next : ["word-to-meaning"] }); }} />{label}</label>)}</div></section>
    <section className={styles.settingsSection}><div className={styles.settingsTitle}><FiHeadphones /><div><h2>发音设置</h2><p>音频不可用时自动降级为系统朗读</p></div></div><SettingRow label="默认口音" detail="优先使用对应音频"><select value={settings.preferredAccent} onChange={(event) => updateSettings({ preferredAccent: event.target.value as "uk" | "us" })}><option value="us">美式</option><option value="uk">英式</option></select></SettingRow><SettingRow label="朗读速度" detail="适用于音频和系统语音"><select value={settings.speechRate} onChange={(event) => updateSettings({ speechRate: Number(event.target.value) as 0.75 | 1 | 1.25 })}><option value="0.75">0.75x</option><option value="1">1.0x</option><option value="1.25">1.25x</option></select></SettingRow><Toggle label="自动播放单词" detail="进入拼写卡片时播放" checked={settings.autoPlayWordAudio} onChange={(value) => updateSettings({ autoPlayWordAudio: value })} /><Toggle label="显示答案后朗读例句" detail="浏览器禁止自动播放时不会阻塞学习" checked={settings.autoPlayExampleAudio} onChange={(value) => updateSettings({ autoPlayExampleAudio: value })} /></section>
    <section className={styles.settingsSection}><div className={styles.settingsTitle}><FiSettings /><div><h2>显示设置</h2><p>保持信息明确但不过度打扰</p></div></div><Toggle label="显示下次复习时间" detail="评分按钮下展示预计间隔" checked={settings.showNextReviewTime} onChange={(value) => updateSettings({ showNextReviewTime: value })} /></section>
    <section className={styles.settingsSection}><div className={styles.settingsTitle}><FiDatabase /><div><h2>数据信息</h2><p>迁移与学习数据概况</p></div></div><dl className={styles.dataList}><dt>当前数据版本</dt><dd>schemaVersion {state.schemaVersion}</dd><dt>单词数量</dt><dd>{state.words.length}</dd><dt>复习记录数量</dt><dd>{state.reviewLogs.length}</dd><dt>最近迁移时间</dt><dd>{new Date(state.lastMigrationAt).toLocaleString("zh-CN")}</dd></dl><p className={styles.dataSafety}><FiInfo />稳定版 v2 原数据不会被覆盖；Beta 迁移失败时会保留恢复副本。</p></section>
    <section className={styles.settingsSection}><div className={styles.settingsTitle}><FiExternalLink /><div><h2>版本入口</h2><p>稳定版和学习 Beta 相互独立</p></div></div><div className={styles.quickLinks}><Link href="/app">打开稳定版 /app <FiExternalLink /></Link><Link href="/">Lexora 官网 <FiExternalLink /></Link><a href="https://github.com/xiaozhangwangxue/lexora" target="_blank" rel="noreferrer">GitHub 源码 <FiExternalLink /></a></div></section>
  </div>;
}

function SettingRow({ label, detail, children }: { label: string; detail: string; children: React.ReactNode }) { return <div className={styles.settingRow}><div><b>{label}</b><span>{detail}</span></div>{children}</div>; }
function Toggle({ label, detail, checked, onChange }: { label: string; detail: string; checked: boolean; onChange(value: boolean): void }) { return <SettingRow label={label} detail={detail}><label className={styles.switch}><input type="checkbox" checked={checked} onChange={(event) => onChange(event.target.checked)} /><span /></label></SettingRow>; }
