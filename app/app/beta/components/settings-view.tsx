"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { FiBookOpen, FiCheck, FiDatabase, FiDownload, FiExternalLink, FiHeadphones, FiInfo, FiSearch, FiSettings, FiTrash2, FiX } from "react-icons/fi";
import { loadState } from "../../storage";
import { clearOfflineLexiconCache, offlineLexiconCacheBytes } from "../../offline-lexicon";
import type { GeneratedBook, SearchRecord } from "../../types";
import { modeLabels, type ReviewMode, type StudyMode } from "../domain/types";
import { useBetaStore } from "../store";
import { clearLearningPacks, fetchLearningPackManifest, installLearningPack, learningPackCacheUsage, removeLearningPack, type LearningPack } from "../services/learning-packs";
import { enrichmentCacheUsage } from "../services/enrichment-cache";
import styles from "../beta.module.css";

const modes = Object.entries(modeLabels) as [ReviewMode, string][];

type CacheSizes = { enrichment: number; packs: number; lexicon: number; pwa: number };

function formatBytes(bytes: number | null) {
  if (bytes === null) return "正在计算…";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
}

async function pwaCacheBytes() {
  if (!("caches" in window)) return 0;
  let total = 0;
  for (const name of await caches.keys()) {
    const cache = await caches.open(name);
    for (const request of await cache.keys()) {
      const response = await cache.match(request);
      if (!response) continue;
      try {
        total += (await response.clone().arrayBuffer()).byteLength;
      } catch {
        total += Number(response.headers.get("content-length")) || 0;
      }
    }
  }
  return total;
}

export function SettingsView() {
  const {
    state, loaded, updateSettings, selectGeneratedBook, confirmAddedTerms,
    enriching, enrichmentCompleted, enrichmentTotal, enrichmentCacheEntries,
    clearLocalEnrichmentCache,
  } = useBetaStore();
  const [packs, setPacks] = useState<LearningPack[]>([]);
  const [generatedBooks, setGeneratedBooks] = useState<GeneratedBook[]>([]);
  const [searches, setSearches] = useState<SearchRecord[]>([]);
  const [packError, setPackError] = useState("");
  const [busyPack, setBusyPack] = useState("");
  const [progress, setProgress] = useState(0);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [pickerQuery, setPickerQuery] = useState("");
  const [draftWordIds, setDraftWordIds] = useState<string[]>([]);
  const [cacheDialogOpen, setCacheDialogOpen] = useState(false);
  const [cacheBusy, setCacheBusy] = useState(false);
  const [cacheMessage, setCacheMessage] = useState("");
  const [cacheSizes, setCacheSizes] = useState<CacheSizes | null>(null);
  const [cacheSelection, setCacheSelection] = useState({
    enrichment: true,
    packs: false,
    lexicon: false,
    pwa: false,
  });

  useEffect(() => {
    void fetchLearningPackManifest().then(setPacks).catch((error) => setPackError(error instanceof Error ? error.message : "词库列表加载失败"));
    let cancelled = false;
    void Promise.resolve().then(() => {
      const stableState = loadState();
      if (cancelled) return;
      setGeneratedBooks(stableState?.records ?? []);
      setSearches(stableState?.searches ?? []);
    });
    return () => { cancelled = true; };
  }, []);

  const searchByTerm = useMemo(() => {
    const map = new Map<string, SearchRecord>();
    for (const search of searches) {
      [search.query, search.resolvedWord, search.entry?.word].filter(Boolean).forEach((term) => map.set(String(term).trim().toLowerCase(), search));
    }
    return map;
  }, [searches]);

  const addedWords = useMemo(() => state.words.filter((word) => !word.sources.some((source) => source.title.startsWith("预设词库:") || source.title.startsWith("词汇书生成记录:"))), [state.words]);
  const filteredAddedWords = useMemo(() => {
    const query = pickerQuery.trim().toLowerCase();
    if (!query) return addedWords;
    return addedWords.filter((word) => [word.text, ...word.meanings.flatMap((meaning) => [meaning.definitionZh, meaning.definitionEn])].filter(Boolean).join(" ").toLowerCase().includes(query));
  }, [addedWords, pickerQuery]);

  if (!loaded) return <div className={styles.loadingState}>正在读取设置…</div>;
  const settings = state.settings;
  const sources = new Set(settings.enabledLearningSources);
  const selectedAddedCount = sources.has("manual") ? addedWords.length : settings.selectedHistoryWordIds.length;

  function toggleSource(id: string, enabled: boolean) {
    const next = new Set(settings.enabledLearningSources);
    if (enabled) next.add(id); else next.delete(id);
    updateSettings({ enabledLearningSources: [...next] });
  }

  async function install(pack: LearningPack) {
    setBusyPack(pack.id); setProgress(0); setPackError("");
    try {
      await installLearningPack(pack, setProgress);
      updateSettings({ installedLearningPacks: [...new Set([...settings.installedLearningPacks, pack.id])], enabledLearningSources: [...new Set([...settings.enabledLearningSources, `preset:${pack.id}`])] });
    } catch (error) { setPackError(error instanceof Error ? error.message : "词库安装失败"); }
    finally { setBusyPack(""); }
  }

  async function remove(pack: LearningPack) {
    setBusyPack(pack.id); setPackError("");
    try {
      await removeLearningPack(pack.id);
      updateSettings({ installedLearningPacks: settings.installedLearningPacks.filter((id) => id !== pack.id), enabledLearningSources: settings.enabledLearningSources.filter((id) => id !== `preset:${pack.id}`) });
    } catch (error) { setPackError(error instanceof Error ? error.message : "词库删除失败"); }
    finally { setBusyPack(""); }
  }

  function openAddedWordPicker() {
    setDraftWordIds(sources.has("manual") ? addedWords.map((word) => word.id) : settings.selectedHistoryWordIds);
    setPickerQuery("");
    setPickerOpen(true);
  }

  async function confirmAddedWordSelection() {
    await confirmAddedTerms(draftWordIds);
    setPickerOpen(false);
  }

  async function clearSelectedCaches() {
    if (!Object.values(cacheSelection).some(Boolean)) return;
    setCacheBusy(true);
    setCacheMessage("");
    try {
      const tasks: Promise<unknown>[] = [];
      if (cacheSelection.enrichment) tasks.push(clearLocalEnrichmentCache());
      if (cacheSelection.packs) tasks.push(clearLearningPacks());
      if (cacheSelection.lexicon) tasks.push(clearOfflineLexiconCache());
      if (cacheSelection.pwa && "caches" in window) {
        tasks.push(caches.keys().then((names) => Promise.all(names.map((name) => caches.delete(name)))));
      }
      await Promise.all(tasks);
      if (cacheSelection.packs) {
        updateSettings({
          installedLearningPacks: [],
          enabledLearningSources: settings.enabledLearningSources.filter((value) => !value.startsWith("preset:")),
        });
      }
      await refreshCacheSizes();
      setCacheMessage("所选缓存已清除，个人词条、生成记录和学习进度均已保留。");
    } catch (error) {
      setCacheMessage(error instanceof Error ? `清除失败：${error.message}` : "清除缓存失败，请重试。");
    } finally {
      setCacheBusy(false);
    }
  }

  async function refreshCacheSizes() {
    const [enrichment, packUsage, lexicon, pwa] = await Promise.all([
      enrichmentCacheUsage().catch(() => ({ entries: enrichmentCacheEntries, bytes: 0 })),
      learningPackCacheUsage().catch(() => ({ packs: settings.installedLearningPacks.length, bytes: 0 })),
      offlineLexiconCacheBytes().catch(() => 0),
      pwaCacheBytes().catch(() => 0),
    ]);
    setCacheSizes({ enrichment: enrichment.bytes, packs: packUsage.bytes, lexicon, pwa });
  }

  function openCacheDialog() {
    setCacheMessage("");
    setCacheSizes(null);
    setCacheDialogOpen(true);
    void refreshCacheSizes();
  }

  return <div className={styles.page}>
    <div className={styles.pageTitle}><div><span className={styles.betaPill}>本地设置</span><h1>学习设置</h1><p>先选择学习内容，确认后再联网补全；已补全资料保存在当前设备。</p></div></div>

    <section className={styles.settingsSection}>
      <div className={styles.settingsTitle}><FiBookOpen /><div><h2>学习内容</h2><p>单词库会完整展示这里已经选中的词汇书、预设词库和单独词条。</p></div></div>

      <div className={styles.sourceBox}>
        <div className={styles.packHeading}><b>生成过的词汇书</b><span>分别选择需要学习的生成记录</span></div>
        {generatedBooks.length ? <div className={styles.sourceList}>{generatedBooks.map((book) => {
          const selected = settings.selectedGeneratedBookIds.includes(book.id);
          const terms = book.words?.length ? book.words : book.previewWords;
          return <label key={book.id} className={styles.sourceChoice}>
            <input type="checkbox" checked={selected} onChange={(event) => selectGeneratedBook({
              id: book.id,
              title: book.title || book.filename,
              words: terms.map((term) => ({ term, entry: searchByTerm.get(term.trim().toLowerCase())?.entry })),
            }, event.target.checked)} />
            <span><b>{book.title || book.filename}</b><small>{new Date(book.createdAt).toLocaleString("zh-CN")} · {book.wordCount} 词{!book.words?.length ? " · 旧记录仅可恢复预览词条" : ""}</small></span>
          </label>;
        })}</div> : <p className={styles.muted}>还没有生成记录。先在稳定版生成词汇书，记录会自动出现在这里。</p>}
      </div>

      <div className={styles.sourceBox}>
        <div className={styles.packHeading}><b>预设词汇书</b><span>下载后可离线学习，也可随时停用或删除</span></div>
        <div className={styles.packList}>{packs.map((pack) => {
          const installed = settings.installedLearningPacks.includes(pack.id);
          const enabled = sources.has(`preset:${pack.id}`);
          return <article key={pack.id}><div><b>{pack.titleZh}</b><span>{pack.descriptionZh}</span><small>{pack.entryCount.toLocaleString("zh-CN")} 词 · {pack.attribution}</small></div>{installed ? <div className={styles.packActions}><label><input type="checkbox" checked={enabled} onChange={(event) => toggleSource(`preset:${pack.id}`, event.target.checked)} />启用</label><button onClick={() => void remove(pack)} disabled={busyPack === pack.id} aria-label={`删除${pack.titleZh}`}><FiTrash2 /></button></div> : <button className={styles.packDownload} onClick={() => void install(pack)} disabled={Boolean(busyPack)}><FiDownload />{busyPack === pack.id ? `${Math.round(progress * 100)}%` : "下载"}</button>}</article>;
        })}</div>
        {packError && <p className={styles.inlineError} role="alert">{packError}</p>}
      </div>

      <div className={styles.sourceBox}>
        <div className={styles.packHeading}><b>单独添加的词条</b><span>打开列表多选，点“确定并补全”后才联网查询</span></div>
        <button className={styles.pickerButton} onClick={openAddedWordPicker}><FiSearch /><span>选择添加过的词条</span><b>{selectedAddedCount} / {addedWords.length}</b></button>
      </div>
    </section>

    <section className={styles.settingsSection}><div className={styles.settingsTitle}><FiBookOpen /><div><h2>学习方式</h2><p>控制新词数量和题型组合</p></div></div><SettingRow label="每日新词数量" detail="只限制新词，不会隐藏到期任务"><input type="number" min="0" max="100" value={settings.dailyNewWordLimit} onChange={(event) => updateSettings({ dailyNewWordLimit: Math.max(0, Math.min(100, Number(event.target.value))) })} /></SettingRow><SettingRow label="默认学习模式" detail="综合模式会根据词条资料安全轮换"><select value={settings.defaultStudyMode} onChange={(event) => updateSettings({ defaultStudyMode: event.target.value as StudyMode })}><option value="mixed">综合模式</option>{modes.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></SettingRow><div className={styles.modeSettings}><b>启用的复习模式</b>{modes.map(([value, label]) => <label key={value}><input type="checkbox" checked={settings.enabledReviewModes.includes(value)} onChange={(event) => { const next = event.target.checked ? [...settings.enabledReviewModes, value] : settings.enabledReviewModes.filter((mode) => mode !== value); updateSettings({ enabledReviewModes: next.length ? next : ["word-to-meaning"] }); }} />{label}</label>)}</div></section>
    <section className={styles.settingsSection}><div className={styles.settingsTitle}><FiHeadphones /><div><h2>发音设置</h2><p>音频不可用时自动降级为系统朗读</p></div></div><SettingRow label="默认口音" detail="优先使用对应音频"><select value={settings.preferredAccent} onChange={(event) => updateSettings({ preferredAccent: event.target.value as "uk" | "us" })}><option value="us">美式</option><option value="uk">英式</option></select></SettingRow><SettingRow label="朗读速度" detail="适用于音频和系统语音"><select value={settings.speechRate} onChange={(event) => updateSettings({ speechRate: Number(event.target.value) as 0.75 | 1 | 1.25 })}><option value="0.75">0.75x</option><option value="1">1.0x</option><option value="1.25">1.25x</option></select></SettingRow><Toggle label="自动播放单词" detail="进入拼写卡片时播放" checked={settings.autoPlayWordAudio} onChange={(value) => updateSettings({ autoPlayWordAudio: value })} /><Toggle label="显示答案后朗读例句" detail="浏览器禁止自动播放时不会阻塞学习" checked={settings.autoPlayExampleAudio} onChange={(value) => updateSettings({ autoPlayExampleAudio: value })} /></section>
    <section className={styles.settingsSection}><div className={styles.settingsTitle}><FiSettings /><div><h2>显示设置</h2><p>保持信息明确但不过度打扰</p></div></div><Toggle label="显示下次复习时间" detail="评分按钮下展示预计间隔" checked={settings.showNextReviewTime} onChange={(value) => updateSettings({ showNextReviewTime: value })} /></section>
    <section className={styles.settingsSection}><div className={styles.settingsTitle}><FiDatabase /><div><h2>本地数据</h2><p>补全资料与学习数据都保存在当前设备</p></div></div><dl className={styles.dataList}><dt>当前数据版本</dt><dd>schemaVersion {state.schemaVersion}</dd><dt>已保存词条</dt><dd>{state.words.length}</dd><dt>联网补全缓存</dt><dd>{enrichmentCacheEntries} 个词条</dd><dt>复习记录数量</dt><dd>{state.reviewLogs.length}</dd></dl><div className={styles.cacheActions}><button className={styles.dangerText} onClick={openCacheDialog}><FiTrash2 />自定义清除缓存</button><span>逐项选择要清除的内容；个人词条、生成记录和学习进度不在清理范围内。</span></div><p className={styles.dataSafety}><FiInfo />稳定版原数据不会被覆盖；Beta 迁移失败时会保留恢复副本。</p></section>
    <section className={styles.settingsSection}><div className={styles.settingsTitle}><FiExternalLink /><div><h2>版本入口</h2><p>稳定版和学习 Beta 相互独立</p></div></div><div className={styles.quickLinks}><Link href="/app">打开稳定版 /app <FiExternalLink /></Link><Link href="/">Lexora 官网 <FiExternalLink /></Link><a href="https://github.com/xiaozhangwangxue/lexora" target="_blank" rel="noreferrer">GitHub 源码 <FiExternalLink /></a></div></section>

    {pickerOpen && <div className={styles.modalBackdrop} onMouseDown={(event) => { if (event.target === event.currentTarget && !enriching) setPickerOpen(false); }}>
      <section className={styles.wordPickerDialog} role="dialog" aria-modal="true" aria-labelledby="word-picker-title">
        <header><div><span className={styles.betaPill}>多选词条</span><h2 id="word-picker-title">选择想背的单词</h2><p>只有点击下方“确定并补全”后才会联网，补全结果会留在本地。</p></div><button onClick={() => setPickerOpen(false)} disabled={enriching} aria-label="关闭"><FiX /></button></header>
        <label className={styles.pickerSearch}><FiSearch /><input value={pickerQuery} onChange={(event) => setPickerQuery(event.target.value)} placeholder="搜索单词或释义" /></label>
        <div className={styles.pickerBulk}><button onClick={() => setDraftWordIds([...new Set([...draftWordIds, ...filteredAddedWords.map((word) => word.id)])])}>全选当前结果</button><button onClick={() => setDraftWordIds(draftWordIds.filter((id) => !filteredAddedWords.some((word) => word.id === id)))}>取消当前结果</button><span>已选 {draftWordIds.length} 个</span></div>
        <div className={styles.wordPickerList}>{filteredAddedWords.length ? filteredAddedWords.map((word) => <label key={word.id}><input type="checkbox" checked={draftWordIds.includes(word.id)} disabled={enriching} onChange={(event) => setDraftWordIds((current) => event.target.checked ? [...new Set([...current, word.id])] : current.filter((id) => id !== word.id))} /><span><b>{word.text}</b><small>{word.meanings.find((meaning) => meaning.definitionZh)?.definitionZh || "确认后联网补全中英文释义"}</small></span>{draftWordIds.includes(word.id) && <FiCheck />}</label>) : <div className={styles.emptyPicker}>没有符合条件的已添加词条</div>}</div>
        {enriching && <div className={styles.enrichmentProgress}><span style={{ width: `${enrichmentTotal ? enrichmentCompleted / enrichmentTotal * 100 : 100}%` }} /><p>正在补全 {enrichmentCompleted} / {enrichmentTotal}</p></div>}
        <footer><button className={styles.secondaryButton} onClick={() => setPickerOpen(false)} disabled={enriching}>取消</button><button className={styles.primaryButton} onClick={() => void confirmAddedWordSelection()} disabled={enriching}>{enriching ? "正在联网补全…" : "确定并补全"}</button></footer>
      </section>
    </div>}
    {cacheDialogOpen && <div className={styles.modalBackdrop} onMouseDown={(event) => { if (event.target === event.currentTarget && !cacheBusy) setCacheDialogOpen(false); }}>
      <section className={styles.cacheDialog} role="dialog" aria-modal="true" aria-labelledby="cache-dialog-title">
        <header><div><span className={styles.betaPill}>存储管理</span><h2 id="cache-dialog-title">自定义清除缓存</h2><p>只勾选需要重新下载或重新查询的内容。你的词条、生成记录和学习进度不会被删除。</p></div><button onClick={() => setCacheDialogOpen(false)} disabled={cacheBusy} aria-label="关闭"><FiX /></button></header>
        <div className={styles.cacheChoiceList}>
          <CacheChoice checked={cacheSelection.enrichment} onChange={(value) => setCacheSelection((current) => ({ ...current, enrichment: value }))} title="联网补全与查词缓存" detail={`占用 ${formatBytes(cacheSizes?.enrichment ?? null)} · ${enrichmentCacheEntries} 个词条；下次使用时会重新联网补全。`} />
          <CacheChoice checked={cacheSelection.packs} onChange={(value) => setCacheSelection((current) => ({ ...current, packs: value }))} title="已下载的预设词汇书" detail={`占用 ${formatBytes(cacheSizes?.packs ?? null)} · ${settings.installedLearningPacks.length} 个；清除后可重新下载。`} />
          <CacheChoice checked={cacheSelection.lexicon} onChange={(value) => setCacheSelection((current) => ({ ...current, lexicon: value }))} title="离线词典包" detail={`占用 ${formatBytes(cacheSizes?.lexicon ?? null)} · 删除极速版/完整版，不影响联网查词。`} />
          <CacheChoice checked={cacheSelection.pwa} onChange={(value) => setCacheSelection((current) => ({ ...current, pwa: value }))} title="网页离线资源" detail={`占用 ${formatBytes(cacheSizes?.pwa ?? null)} · 当前页面刷新后会重新下载。`} />
        </div>
        {cacheMessage && <p className={cacheMessage.startsWith("清除失败") ? styles.inlineError : styles.cacheSuccess} role="status">{cacheMessage}</p>}
        <footer><button className={styles.secondaryButton} onClick={() => setCacheDialogOpen(false)} disabled={cacheBusy}>关闭</button><button className={styles.primaryButton} onClick={() => void clearSelectedCaches()} disabled={cacheBusy || !Object.values(cacheSelection).some(Boolean)}>{cacheBusy ? "正在清除…" : "清除所选缓存"}</button></footer>
      </section>
    </div>}
  </div>;
}

function SettingRow({ label, detail, children }: { label: string; detail: string; children: React.ReactNode }) { return <div className={styles.settingRow}><div><b>{label}</b><span>{detail}</span></div>{children}</div>; }
function Toggle({ label, detail, checked, onChange }: { label: string; detail: string; checked: boolean; onChange(value: boolean): void }) { return <SettingRow label={label} detail={detail}><label className={styles.switch}><input type="checkbox" checked={checked} onChange={(event) => onChange(event.target.checked)} /><span /></label></SettingRow>; }
function CacheChoice({ checked, onChange, title, detail }: { checked: boolean; onChange(value: boolean): void; title: string; detail: string }) { return <label className={styles.cacheChoice}><input type="checkbox" checked={checked} onChange={(event) => onChange(event.target.checked)} /><span><b>{title}</b><small>{detail}</small></span>{checked && <FiCheck />}</label>; }
