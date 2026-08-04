"use client";

import {
  ChangeEvent,
  FormEvent,
  ReactNode,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import Image from "next/image";
import Link from "next/link";
import {
  FiBookOpen,
  FiCheck,
  FiChevronDown,
  FiClock,
  FiDownload,
  FiExternalLink,
  FiFileText,
  FiGithub,
  FiHeart,
  FiHelpCircle,
  FiPlus,
  FiRefreshCw,
  FiSearch,
  FiSettings,
  FiShare2,
  FiStar,
  FiTrash2,
  FiUpload,
  FiX,
} from "react-icons/fi";
import { LexoraWordmark } from "../lexora-wordmark";
import { offlineLookup } from "./offline-lexicon";
import {
  deleteGeneratedFile,
  loadState,
  readGeneratedFile,
  saveGeneratedFile,
  saveState,
} from "./storage";
import type {
  AppSettings,
  AppTab,
  BookFormat,
  DictionaryEntry,
  FontPreset,
  GeneratedBook,
  GeneratedWordRecord,
  SearchRecord,
  Typography,
  WordItem,
} from "./types";
import { defaultSettings } from "./types";
import styles from "./lexora-web.module.css";

type InstallPrompt = Event & {
  prompt(): Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};
type Suggestion = { word: string; normalized_word?: string; history?: boolean };
type HistoryMode = "generated" | "searched";

const nav: { id: AppTab; label: string; icon: ReactNode }[] = [
  { id: "search", label: "单词", icon: <FiSearch /> },
  { id: "book", label: "词汇书", icon: <FiBookOpen /> },
  { id: "records", label: "生成记录", icon: <FiFileText /> },
  { id: "history", label: "历史", icon: <FiClock /> },
  { id: "settings", label: "设置", icon: <FiSettings /> },
];

const fontPresetTypography: Record<FontPreset, Typography> = {
  small: {
    word: 9.4,
    phonetic: 7.4,
    definition: 7.4,
    related: 6.4,
    example: 6.4,
    phrase: 6.4,
  },
  medium: {
    word: 11,
    phonetic: 9,
    definition: 8.7,
    related: 7.2,
    example: 7.2,
    phrase: 7.2,
  },
  large: {
    word: 14.78,
    phonetic: 12.78,
    definition: 12.354,
    related: 10.224,
    example: 10.224,
    phrase: 10.224,
  },
};

function isMobileDevice() {
  return (
    typeof navigator !== "undefined" &&
    (/Android|iPhone|iPad|iPod/i.test(navigator.userAgent) ||
      (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1))
  );
}
function isIOS() {
  return (
    typeof navigator !== "undefined" &&
    (/iPhone|iPad|iPod/i.test(navigator.userAgent) ||
      (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1))
  );
}
function isStandalone() {
  return (
    typeof window !== "undefined" &&
    (window.matchMedia("(display-mode: standalone)").matches ||
      Boolean((navigator as Navigator & { standalone?: boolean }).standalone))
  );
}
function normalizeTerms(value: string) {
  return value
    .split(/[\n,，;；]+/)
    .map((term) => term.trim().toLowerCase().replace(/\s+/g, " "))
    .filter((term) => /^[a-z][a-z' .-]{0,119}$/.test(term));
}
function list(value: unknown): string[] {
  if (Array.isArray(value))
    return value
      .map((item) => {
        if (typeof item === "string") return item;
        const object = item as {
          word?: string;
          phrase?: string;
          text?: string;
          translation_zh?: string;
          definition_zh?: string;
          meaning_zh?: string;
        };
        const term = String(object.word || object.phrase || object.text || "");
        const translation = String(
          object.translation_zh ||
            object.definition_zh ||
            object.meaning_zh ||
            "",
        );
        return translation ? `${term} — ${translation}` : term;
      })
      .filter(Boolean);
  return [];
}
function deviceId() {
  const key = "lexora-web-device-id";
  const cookie = document.cookie
    .split("; ")
    .find((item) => item.startsWith(`${key}=`))
    ?.split("=")[1];
  let value = cookie || localStorage.getItem(key);
  if (!value) value = crypto.randomUUID();
  localStorage.setItem(key, value);
  document.cookie = `${key}=${encodeURIComponent(value)}; Max-Age=31536000; Path=/; SameSite=Lax; Secure`;
  return value;
}
function formatDate(timestamp: number) {
  return new Intl.DateTimeFormat("zh-CN", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(timestamp);
}

async function fetchJsonWithRetry<T>(
  url: string,
  init: RequestInit = {},
  attempts = 2,
): Promise<T> {
  let lastError: unknown;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 12_000);
    try {
      const response = await fetch(url, {
        ...init,
        cache: "no-store",
        headers: { accept: "application/json", ...init.headers },
        signal: controller.signal,
      });
      const result = (await response.json().catch(() => ({}))) as T & {
        detail?: string;
      };
      if (!response.ok)
        throw new Error(result.detail || `请求失败（${response.status}）`);
      return result;
    } catch (error) {
      lastError = error;
      if (attempt + 1 < attempts)
        await new Promise((resolve) => window.setTimeout(resolve, 280));
    } finally {
      window.clearTimeout(timeout);
    }
  }
  if (
    lastError instanceof Error &&
    !/load failed|failed to fetch|networkerror|abort/i.test(lastError.message)
  )
    throw lastError;
  throw new Error("网络连接暂时不稳定，请稍后重试");
}
function haptic(pattern: number | number[] = 9) {
  navigator.vibrate?.(pattern);
}
function logEvent(event: string, detail: Record<string, unknown> = {}) {
  if (
    typeof window === "undefined" ||
    localStorage.getItem("lexora-dev-enabled") !== "1"
  )
    return;
  const key = "lexora-web-developer-log";
  let rows: unknown[] = [];
  try {
    rows = JSON.parse(localStorage.getItem(key) || "[]") as unknown[];
  } catch {
    rows = [];
  }
  rows.push({
    timestamp: new Date().toISOString(),
    event,
    detail,
    userAgent: navigator.userAgent,
  });
  localStorage.setItem(key, JSON.stringify(rows.slice(-3000)));
}
export function LexoraWebApp() {
  const [tab, setTab] = useState<AppTab>("search");
  const [installed, setInstalled] = useState(false);
  const [mobile, setMobile] = useState(false);
  const [ios, setIos] = useState(false);
  const [installPrompt, setInstallPrompt] = useState<InstallPrompt | null>(
    null,
  );
  const [words, setWords] = useState<WordItem[]>([]);
  const [settings, setSettings] = useState<AppSettings>(defaultSettings);
  const [records, setRecords] = useState<GeneratedBook[]>([]);
  const [searches, setSearches] = useState<SearchRecord[]>([]);
  const [generatedWords, setGeneratedWords] = useState<GeneratedWordRecord[]>(
    [],
  );
  const [historySearchTarget, setHistorySearchTarget] =
    useState<SearchRecord | null>(null);
  const [searchActive, setSearchActive] = useState(false);
  const [onboardingDone, setOnboardingDone] = useState(true);
  const [loaded, setLoaded] = useState(false);
  const [toast, setToast] = useState("");
  const [quota, setQuota] = useState<{
    lookupsRemaining: number;
    pdfsRemaining: number;
  } | null>(null);
  const toastTimer = useRef<number | null>(null);
  const swipeStart = useRef<{
    x: number;
    y: number;
    interactive: boolean;
  } | null>(null);

  const notify = useCallback((message: string) => {
    setToast(message);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(""), 2800);
  }, []);
  const clearHistorySearchTarget = useCallback(
    () => setHistorySearchTarget(null),
    [],
  );

  useEffect(() => {
    const prompt = (event: Event) => {
      event.preventDefault();
      setInstallPrompt(event as InstallPrompt);
    };
    const refresh = () => setInstalled(isStandalone());
    window.addEventListener("beforeinstallprompt", prompt);
    window.addEventListener("pageshow", refresh);
    document.addEventListener("visibilitychange", refresh);
    navigator.serviceWorker
      ?.register("/sw.js", { updateViaCache: "none" })
      .then((registration) => registration.update())
      .catch(() => undefined);
    const initialFrame = window.requestAnimationFrame(() => {
      setMobile(isMobileDevice());
      setIos(isIOS());
      setInstalled(isStandalone());
      const saved = loadState();
      if (saved?.words)
        setWords(
          saved.words.map((word) => ({
            ...word,
            status: word.status === "loading" ? "idle" : word.status,
          })),
        );
      if (saved?.settings)
        setSettings({
          ...defaultSettings,
          ...saved.settings,
          typography: {
            ...defaultSettings.typography,
            ...saved.settings.typography,
          },
        });
      if (saved?.records) setRecords(saved.records);
      if (saved?.searches) setSearches(saved.searches);
      if (saved?.generatedWords) setGeneratedWords(saved.generatedWords);
      setOnboardingDone(Boolean(saved?.onboardingDone));
      setLoaded(true);
    });
    return () => {
      window.cancelAnimationFrame(initialFrame);
      window.removeEventListener("beforeinstallprompt", prompt);
      window.removeEventListener("pageshow", refresh);
      document.removeEventListener("visibilitychange", refresh);
      if (toastTimer.current) clearTimeout(toastTimer.current);
    };
  }, []);

  useEffect(() => {
    if (loaded)
      saveState({
        words,
        settings,
        records,
        searches,
        generatedWords,
        onboardingDone,
      });
  }, [
    words,
    settings,
    records,
    searches,
    generatedWords,
    onboardingDone,
    loaded,
  ]);
  useEffect(() => {
    if (!loaded || (mobile && !installed)) return;
    fetch("/api/web/quota", { headers: { "x-lexora-device": deviceId() } })
      .then((r) =>
        r.ok
          ? (r.json() as Promise<{
              lookupsRemaining: number;
              pdfsRemaining: number;
            }>)
          : null,
      )
      .then((v) => v && setQuota(v))
      .catch(() => undefined);
  }, [installed, loaded, mobile]);

  function addToBook(term: string, entry?: DictionaryEntry) {
    const normalized = term.trim().toLowerCase();
    setWords((current) =>
      current.some((item) => item.term === normalized)
        ? current.filter((item) => item.term !== normalized)
        : [
            ...current,
            {
              id: crypto.randomUUID(),
              term: normalized,
              status: entry ? "ready" : "idle",
              matched:
                entry?.word.toLowerCase() !== normalized
                  ? entry?.word
                  : undefined,
              difficulty: entry?.difficulty,
              frequency: entry?.frequency,
            },
          ],
    );
    notify(
      words.some((item) => item.term === normalized)
        ? "已从词汇书移除"
        : "已加入词汇书",
    );
  }

  async function install() {
    if (!installPrompt) return;
    await installPrompt.prompt();
    if ((await installPrompt.userChoice).outcome === "accepted")
      setInstallPrompt(null);
  }
  const installGate = mobile && !installed;
  if (installGate)
    return (
      <InstallGate
        ios={ios}
        prompt={installPrompt}
        install={install}
        refresh={() => setInstalled(isStandalone())}
      />
    );

  const views: Record<AppTab, ReactNode> = {
    search: (
      <SearchView
        searches={searches}
        setSearches={setSearches}
        words={words}
        addToBook={addToBook}
        scale={settings.searchScale}
        notify={notify}
        initialRecord={historySearchTarget}
        clearInitialRecord={clearHistorySearchTarget}
        onActiveChange={setSearchActive}
      />
    ),
    book: (
      <BookView
        words={words}
        setWords={setWords}
        settings={settings}
        setSettings={setSettings}
        records={records}
        setRecords={setRecords}
        generatedWords={generatedWords}
        setGeneratedWords={setGeneratedWords}
        setTab={setTab}
        notify={notify}
      />
    ),
    records: (
      <RecordsView records={records} setRecords={setRecords} notify={notify} />
    ),
    history: (
      <HistoryView
        searches={searches}
        setSearches={setSearches}
        generatedWords={generatedWords}
        setGeneratedWords={setGeneratedWords}
        setWords={setWords}
        setTab={setTab}
        settings={settings}
        setSettings={setSettings}
        openSearch={(record) => {
          setHistorySearchTarget(record);
          setTab("search");
        }}
        notify={notify}
      />
    ),
    settings: (
      <SettingsView
        settings={settings}
        setSettings={setSettings}
        notify={notify}
      />
    ),
  };

  return (
    <main className={styles.appShell}>
      <aside className={styles.sidebar}>
        <Link href="/" className={styles.sideBrand}>
          <Image src="/favicon.png" alt="" width={38} height={38} unoptimized />
          <LexoraWordmark />
        </Link>
        <nav>
          {nav.map((item) => (
            <button
              key={item.id}
              className={tab === item.id ? styles.activeNav : ""}
              onClick={() => {
                setTab(item.id);
                logEvent("navigation", { tab: item.id });
                haptic(6);
              }}
            >
              {item.icon}
              <span>{item.label}</span>
            </button>
          ))}
        </nav>
        <div className={styles.sideStatus}>
          <span className={styles.onlineDot} />
          {quota
            ? `查询 ${quota.lookupsRemaining} · 生成 ${quota.pdfsRemaining}`
            : "云端已连接"}
        </div>
      </aside>
      <section
        className={styles.mainArea}
        onTouchStart={(event) => {
          const target = event.target as HTMLElement;
          swipeStart.current = {
            x: event.touches[0].clientX,
            y: event.touches[0].clientY,
            interactive: Boolean(
              target.closest(
                "button,input,textarea,select,a,.wordList,.reader",
              ),
            ),
          };
        }}
        onTouchEnd={(event) => {
          const start = swipeStart.current;
          swipeStart.current = null;
          if (!start || start.interactive) return;
          const x = event.changedTouches[0].clientX;
          const y = event.changedTouches[0].clientY;
          const dx = x - start.x;
          if (Math.abs(dx) < 72 || Math.abs(y - start.y) > 55) return;
          const index = nav.findIndex((item) => item.id === tab);
          const next = Math.max(
            0,
            Math.min(nav.length - 1, index + (dx < 0 ? 1 : -1)),
          );
          if (next !== index) {
            setTab(nav[next].id);
            haptic(7);
          }
        }}
      >
        <header className={styles.mobileHeader}>
          <Link href="/" className={styles.mobileBrand}>
            <Image
              src="/favicon.png"
              alt=""
              width={32}
              height={32}
              unoptimized
            />
            <LexoraWordmark />
          </Link>
          {(tab === "settings" || (tab === "search" && !searchActive)) && (
            <a
              className={styles.mobileGithub}
              href="https://github.com/xiaozhangwangxue/lexora"
              target="_blank"
              rel="noreferrer"
            >
              <FiGithub /> GitHub
            </a>
          )}
        </header>
        {views[tab]}
      </section>
      <nav className={styles.bottomNav}>
        {nav.map((item) => (
          <button
            key={item.id}
            className={tab === item.id ? styles.activeNav : ""}
            onClick={() => {
              setTab(item.id);
              logEvent("navigation", { tab: item.id });
              haptic(6);
            }}
          >
            {item.icon}
            <span>{item.label}</span>
          </button>
        ))}
      </nav>
      {!onboardingDone && <Onboarding close={() => setOnboardingDone(true)} />}
      {toast && (
        <div className={styles.toast} role="status">
          {toast}
        </div>
      )}
    </main>
  );
}

function InstallGate({
  ios,
  prompt,
  install,
  refresh,
}: {
  ios: boolean;
  prompt: InstallPrompt | null;
  install(): void;
  refresh(): void;
}) {
  return (
    <main className={styles.installPage}>
      <section className={styles.installCard}>
        <Image
          src="/lexora-icon-512.png"
          alt="Lexora"
          width={76}
          height={76}
          priority
          unoptimized
        />
        <LexoraWordmark className={styles.installWordmark} />
        <p className={styles.eyebrow}>完整网页应用</p>
        <h1>请先将 Lexora 添加到主屏幕</h1>
        <p>安装后可使用词典、词汇书、多格式导出、生成记录与历史等全部功能。</p>
        <p className={styles.installWaitNote}>
          首次打开请等待 3–5 秒，确认上方 Lexora 图标已完整显示后再添加，避免系统保存空白图标。
        </p>
        <ol className={styles.steps}>
          {ios ? (
            <>
              <li>
                <b>1</b>
                <span>在 Safari 点按“分享”</span>
              </li>
              <li>
                <b>2</b>
                <span>选择“添加到主屏幕”</span>
              </li>
              <li>
                <b>3</b>
                <span>从主屏幕打开 Lexora</span>
              </li>
            </>
          ) : (
            <>
              <li>
                <b>1</b>
                <span>点击下方安装按钮</span>
              </li>
              <li>
                <b>2</b>
                <span>从主屏幕打开 Lexora</span>
              </li>
            </>
          )}
        </ol>
        {!ios && (
          <button
            className={styles.primaryButton}
            onClick={install}
            disabled={!prompt}
          >
            {prompt ? "添加到主屏幕" : "请在浏览器菜单中选择安装"}
          </button>
        )}
        <button className={styles.textButton} onClick={refresh}>
          我已添加，重新检测
        </button>
      </section>
    </main>
  );
}

function PageHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  return (
    <div className={styles.pageHeader}>
      <div>
        <h1>{title}</h1>
        {subtitle && <p>{subtitle}</p>}
      </div>
      {action}
    </div>
  );
}

function SearchView({
  searches,
  setSearches,
  words,
  addToBook,
  scale,
  notify,
  initialRecord,
  clearInitialRecord,
  onActiveChange,
}: {
  searches: SearchRecord[];
  setSearches(
    v: SearchRecord[] | ((c: SearchRecord[]) => SearchRecord[]),
  ): void;
  words: WordItem[];
  addToBook(term: string, entry?: DictionaryEntry): void;
  scale: number;
  notify(message: string): void;
  initialRecord: SearchRecord | null;
  clearInitialRecord(): void;
  onActiveChange(active: boolean): void;
}) {
  const [query, setQuery] = useState(initialRecord?.resolvedWord || "");
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [entry, setEntry] = useState<DictionaryEntry | null>(
    initialRecord?.entry || null,
  );
  const [loading, setLoading] = useState(false);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const timer = useRef<number | null>(null);
  const activeSearch = useRef(0);
  const searched = useMemo(
    () =>
      searches
        .filter((record) => record.query.startsWith(query.toLowerCase()))
        .slice(0, 4)
        .map((record) => ({ word: record.resolvedWord, history: true })),
    [query, searches],
  );
  useEffect(() => {
    if (!initialRecord) return;
    clearInitialRecord();
  }, [clearInitialRecord, initialRecord]);
  useEffect(() => {
    onActiveChange(
      Boolean(query.trim() || entry || loading || showSuggestions),
    );
    return () => onActiveChange(false);
  }, [entry, loading, onActiveChange, query, showSuggestions]);
  useEffect(() => {
    if (timer.current) clearTimeout(timer.current);
    const normalized = query.trim().toLowerCase();
    if (!normalized) return;
    let cancelled = false;
    timer.current = window.setTimeout(() => {
      const path = `/api/web/suggest?prefix=${encodeURIComponent(normalized)}&limit=12`;
      fetchJsonWithRetry<Suggestion[]>(path, {
        headers: { "x-lexora-device": deviceId() },
      })
        .catch(() =>
          fetchJsonWithRetry<Suggestion[]>(
            `https://dict.12323456.xyz/v1/suggest?prefix=${encodeURIComponent(normalized)}&limit=12`,
            {},
            1,
          ),
        )
        .then((values) => {
          if (cancelled) return;
          setSuggestions(
            values
              .filter(
                (item) =>
                  item.word &&
                  !searched.some((old) => old.word === item.word),
              )
              .slice(0, 8),
          );
        })
        .catch(() => {
          if (!cancelled) setSuggestions([]);
        });
    }, 160);
    return () => {
      cancelled = true;
      if (timer.current) clearTimeout(timer.current);
    };
  }, [query, searched]);
  async function search(term = query) {
    const normalized = term.trim().toLowerCase();
    if (!normalized || loading) return;
    const requestId = ++activeSearch.current;
    setQuery(normalized);
    setLoading(true);
    setShowSuggestions(false);
    try {
      const localEntry = await offlineLookup(normalized).catch(() => null);
      if (localEntry) {
        const displayedEntry = withDisplaySenses(localEntry);
        setEntry(displayedEntry);
        const localRecord: SearchRecord = {
          id: crypto.randomUUID(),
          query: normalized,
          resolvedWord: localEntry.word,
          searchedAt: Date.now(),
          difficulty: localEntry.difficulty,
          frequency: localEntry.frequency,
          entry: displayedEntry,
        };
        setSearches((current) =>
          [
            localRecord,
            ...current.filter((item) => item.query !== normalized),
          ].slice(0, 500),
        );
        void withChineseDisplaySenses(displayedEntry)
          .then((translatedEntry) => {
            if (activeSearch.current !== requestId) return;
            setEntry(translatedEntry);
            setSearches((current) =>
              current.map((item) =>
                item.id === localRecord.id
                  ? { ...item, entry: translatedEntry }
                  : item,
              ),
            );
          })
          .catch(() => undefined);
        logEvent("offline-lookup", { term: normalized });
        return;
      }
      const result = await fetchJsonWithRetry<DictionaryEntry & {
        detail?: string;
      }>(
        `/api/web/lookup?term=${encodeURIComponent(normalized)}`,
        { headers: { "x-lexora-device": deviceId() } },
      );
      const displayedEntry = withDisplaySenses(result);
      setEntry(displayedEntry);
      logEvent("cloud-lookup", { term: normalized, match: result.match_type });
      const record: SearchRecord = {
        id: crypto.randomUUID(),
        query: normalized,
        resolvedWord: result.word,
        searchedAt: Date.now(),
        difficulty: result.difficulty,
        frequency: result.frequency,
        entry: displayedEntry,
      };
      setSearches((current) =>
        [record, ...current.filter((item) => item.query !== normalized)].slice(
          0,
          500,
        ),
      );
      void withChineseDisplaySenses(displayedEntry)
        .then((translatedEntry) => {
          if (activeSearch.current !== requestId) return;
          setEntry(translatedEntry);
          setSearches((current) =>
            current.map((item) =>
              item.id === record.id
                ? { ...item, entry: translatedEntry }
                : item,
            ),
          );
        })
        .catch(() => undefined);
    } catch (error) {
      setEntry(null);
      notify(error instanceof Error ? error.message : "查询失败");
    } finally {
      setLoading(false);
    }
  }
  if (entry)
    return (
      <div className={`${styles.page} ${styles.resultPage}`}>
        <PageHeader
          title="单词"
          action={
            <button
              className={styles.ghostButton}
              onClick={() => {
                activeSearch.current += 1;
                setEntry(null);
                setQuery("");
              }}
            >
              <FiSearch /> 新搜索
            </button>
          }
        />
        <article
          className={styles.resultCard}
          style={{ fontSize: `${scale}em` }}
        >
          <div className={styles.resultTop}>
            <div>
              <h2>{entry.word}</h2>
              <p>
                {entry.us_phonetic &&
                  `US /${entry.us_phonetic.replaceAll("/", "")}/`}{" "}
                {entry.uk_phonetic &&
                  `· UK /${entry.uk_phonetic.replaceAll("/", "")}/`}
              </p>
            </div>
            <button
              className={styles.resultNewSearch}
              onClick={() => {
                setEntry(null);
                setQuery("");
              }}
            >
              <FiSearch /> <span>新搜索</span>
            </button>
            <div className={styles.resultActions}>
              <span>{entry.difficulty || "—"}</span>
              <span>
                freq {entry.frequency?.toFixed?.(1) ?? entry.frequency ?? "—"}
              </span>
              <button title="难度采用 CEFR；词频数值越高越常见">
                <FiHelpCircle />
              </button>
              <button
                className={styles.addCircle}
                onClick={() => addToBook(entry.word, entry)}
              >
                {words.some(
                  (item) => item.term === entry.word.toLowerCase(),
                ) ? (
                  <FiCheck />
                ) : (
                  <FiPlus />
                )}
              </button>
            </div>
          </div>
          <ResultSections entry={entry} search={search} />
        </article>
      </div>
    );
  return (
    <div className={`${styles.page} ${styles.searchHome}`}>
      <div className={styles.searchHero}>
        <LexoraWordmark />
        <p>/lekˈsɔːrə/</p>
        <h1>查一个单词，也找到与它相关的世界。</h1>
        <div className={styles.searchControl}>
          <form
            onSubmit={(event) => {
              event.preventDefault();
              void search();
            }}
            className={styles.searchBox}
          >
            <FiSearch />
            <input
              autoFocus={!isMobileDevice()}
              value={query}
              onChange={(event) => {
                setQuery(event.target.value);
                setShowSuggestions(Boolean(event.target.value.trim()));
              }}
              placeholder="搜索单词或短语"
            />
            <button disabled={!query || loading} aria-label="搜索">
              {loading ? <i /> : "→"}
            </button>
          </form>
          {showSuggestions &&
            (searched.length > 0 || suggestions.length > 0) && (
              <div className={styles.suggestionPanel}>
                {searched.length > 0 && <p>搜索过</p>}
                {searched.map((item) => (
                  <SuggestionRow
                    key={`h-${item.word}`}
                    item={item}
                    choose={search}
                    fill={(value) => {
                      setQuery(value);
                      setShowSuggestions(true);
                    }}
                  />
                ))}
                {suggestions.length > 0 && <p>其他联想</p>}
                {suggestions.map((item) => (
                  <SuggestionRow
                    key={item.word}
                    item={item}
                    choose={search}
                    fill={(value) => {
                      setQuery(value);
                      setShowSuggestions(true);
                    }}
                  />
                ))}
              </div>
            )}
        </div>
      </div>
      <div className={styles.featureStrip}>
        <span>英美音标</span>
        <span>双语释义</span>
        <span>近反义词</span>
        <span>例句与搭配</span>
      </div>
    </div>
  );
}

function SuggestionRow({
  item,
  choose,
  fill,
}: {
  item: Suggestion;
  choose(term: string): void;
  fill(term: string): void;
}) {
  return (
    <button className={styles.suggestionRow} onClick={() => choose(item.word)}>
      <span>
        {item.history ? <FiClock /> : <FiSearch />}
        {item.word}
      </span>
      <i
        onClick={(event) => {
          event.stopPropagation();
          fill(item.word);
        }}
      >
        ↵
      </i>
    </button>
  );
}

const partOfSpeechZh: Record<string, string> = {
  adjective: "形容词",
  adverb: "副词",
  conjunction: "连词",
  determiner: "限定词",
  interjection: "感叹词",
  noun: "名词",
  numeral: "数词",
  particle: "助词",
  phrase: "短语",
  preposition: "介词",
  pronoun: "代词",
  "proper noun": "专有名词",
  verb: "动词",
};

function readableText(value: unknown) {
  return String(value || "")
    .replaceAll("\\n", "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function senseValues(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(readableText).filter(Boolean);
  const text = readableText(value);
  return text ? [text] : [];
}

const partOfSpeechAlias: Record<string, string> = {
  a: "adjective",
  adj: "adjective",
  ad: "adverb",
  adv: "adverb",
  conj: "conjunction",
  imp: "verb",
  int: "interjection",
  intj: "interjection",
  name: "proper noun",
  n: "noun",
  num: "numeral",
  prep: "preposition",
  pron: "pronoun",
  v: "verb",
  vi: "verb",
  vt: "verb",
};

function normalizedPartOfSpeech(value: unknown, fallback = "definition") {
  const pos = readableText(value).toLowerCase().replace(/[.。]/g, "");
  return partOfSpeechAlias[pos] || pos || fallback;
}

function chineseOverview(value: unknown, fallbackPos: unknown) {
  const groups = new Map<string, string[]>();
  const fallback = normalizedPartOfSpeech(fallbackPos);
  for (const rawLine of readableText(value).split(/\n+|\s*\|\s*/)) {
    const match = rawLine.trim().match(/^([a-z]{1,8})\s*[.。]?\s*(.*)$/i);
    if (match?.[1].toLowerCase() === "imp") continue;
    const pos = match
      ? normalizedPartOfSpeech(match[1], fallback)
      : fallback;
    const sourceText = (match?.[2] || rawLine).trim();
    if (sourceText.length > 90) continue;
    let text = sourceText;
    text = text.split(/[。！？]/, 1)[0].trim();
    const han = (text.match(/[\u3400-\u9fff]/g) || []).length;
    const latin = (text.match(/[a-z]/gi) || []).length;
    if (han < 2 || latin > Math.max(8, Math.floor(han * 0.25))) continue;
    const values = groups.get(pos) || [];
    if (!values.includes(text) && values.length < 4) values.push(text);
    groups.set(pos, values);
  }
  return groups;
}

function groupedSenses(
  value: unknown,
  fallbackPos: unknown,
) {
  const source = Array.isArray(value)
    ? (value as Record<string, unknown>[])
    : [];
  const groups = new Map<
    string,
    {
      pos: string;
      posZh: string;
      items: { definition: string; translation?: string }[];
    }
  >();
  for (const sense of source) {
    const pos = normalizedPartOfSpeech(
      sense.part_of_speech || sense.pos || fallbackPos,
    );
    const definitions = senseValues(
      sense.definitions || sense.definition || sense.definition_en,
    );
    const translations = senseValues(
      sense.definitions_zh || sense.definition_zh,
    );
    if (!definitions.length && !translations.length) continue;
    const group = groups.get(pos) || {
      pos,
      posZh:
        readableText(sense.part_of_speech_zh || sense.pos_zh) ||
        partOfSpeechZh[pos] ||
        "释义",
      items: [],
    };
    const aligned = translations.length === definitions.length;
    for (const [index, definition] of definitions.entries()) {
      const existing = group.items.find(
        (item) => item.definition === definition,
      );
      const translation = aligned ? translations[index] : undefined;
      if (existing) {
        if (!existing.translation && translation)
          existing.translation = translation;
      } else group.items.push({ definition, translation });
    }
    groups.set(pos, group);
  }
  return [...groups.values()];
}

type DisplaySense = {
  pos: string;
  pos_zh: string;
  definitions: string[];
  definitions_zh: string[];
};

function displaySenses(entry: DictionaryEntry): DisplaySense[] {
  const source = Array.isArray(entry.senses)
    ? (entry.senses as Record<string, unknown>[])
    : [];
  const groups = new Map<string, DisplaySense>();
  for (const sense of source) {
    const pos = normalizedPartOfSpeech(
      sense.part_of_speech || sense.pos || entry.pos,
    );
    const definitions = senseValues(
      sense.definitions || sense.definition || sense.definition_en,
    );
    if (!definitions.length) continue;
    const group = groups.get(pos) || {
      pos,
      pos_zh:
        readableText(sense.part_of_speech_zh || sense.pos_zh) ||
        partOfSpeechZh[pos] ||
        "释义",
      definitions: [],
      definitions_zh: [],
    };
    const definition = definitions[0].replace(/\s+\.$/, ".");
    if (!group.definitions.includes(definition) && group.definitions.length < 3) {
      const translations = senseValues(
        sense.definitions_zh || sense.definition_zh,
      );
      group.definitions.push(definition);
      group.definitions_zh.push(
        translations.length === definitions.length ? translations[0] || "" : "",
      );
    }
    groups.set(pos, group);
  }
  return [...groups.values()].filter((sense) => sense.definitions.length);
}

function withDisplaySenses(entry: DictionaryEntry): DictionaryEntry {
  return { ...entry, display_senses: displaySenses(entry) };
}

async function directChineseTranslations(texts: string[]) {
  const translations = Array(texts.length).fill("") as string[];
  if (!texts.length) return translations;
  const marker = (index: number) => `[[[${index}]]]`;
  try {
    const payload = texts
      .map((text, index) => `${marker(index)} ${text}`)
      .join("\n");
    const endpoint = new URL(
      "https://translate.googleapis.com/translate_a/single",
    );
    endpoint.search = new URLSearchParams({
      client: "gtx",
      sl: "en",
      tl: "zh-CN",
      dt: "t",
      q: payload,
    }).toString();
    const body = await fetchJsonWithRetry<unknown[]>(endpoint.toString(), {}, 1);
    const chunks = Array.isArray(body[0]) ? (body[0] as unknown[][]) : [];
    const joined = chunks.map((chunk) => readableText(chunk[0])).join("");
    texts.forEach((_, index) => {
      const startMarker = marker(index);
      const start = joined.indexOf(startMarker);
      if (start < 0) return;
      const nextMarker = marker(index + 1);
      const contentStart = start + startMarker.length;
      const end = joined.indexOf(nextMarker, contentStart);
      translations[index] = joined
        .slice(contentStart, end < 0 ? joined.length : end)
        .trim();
    });
  } catch {
    // Mainland networks can block Google; MyMemory below remains available.
  }
  let missing = translations
    .map((translation, index) =>
      (translation.match(/[\u3400-\u9fff]/g) || []).length >= 2 ? -1 : index,
    )
    .filter((index) => index >= 0);
  await Promise.all(
    missing.map(async (index) => {
      try {
        const endpoint = new URL(
          "https://translate.googleapis.com/translate_a/single",
        );
        endpoint.search = new URLSearchParams({
          client: "gtx",
          sl: "en",
          tl: "zh-CN",
          dt: "t",
          q: texts[index],
        }).toString();
        const body = await fetchJsonWithRetry<unknown[]>(
          endpoint.toString(),
          {},
          1,
        );
        const chunks = Array.isArray(body[0]) ? (body[0] as unknown[][]) : [];
        const translation = chunks
          .map((chunk) => readableText(chunk[0]))
          .join("")
          .trim();
        if (hasChinese(translation)) translations[index] = translation;
      } catch {
        // MyMemory below remains available.
      }
    }),
  );
  missing = translations
    .map((translation, index) => (hasChinese(translation) ? -1 : index))
    .filter((index) => index >= 0);
  await Promise.all(
    missing.map(async (index) => {
      try {
        const endpoint = new URL("https://api.mymemory.translated.net/get");
        endpoint.search = new URLSearchParams({
          q: texts[index],
          langpair: "en|zh-CN",
        }).toString();
        const body = await fetchJsonWithRetry<{
          responseData?: { translatedText?: unknown };
        }>(endpoint.toString(), {}, 1);
        const translation = readableText(body.responseData?.translatedText);
        if ((translation.match(/[\u3400-\u9fff]/g) || []).length >= 2)
          translations[index] = translation;
      } catch {
        // English remains readable even when both translation providers fail.
      }
    }),
  );
  return translations;
}

function hasChinese(value: string) {
  return (value.match(/[\u3400-\u9fff]/g) || []).length >= 2;
}

async function resolvedChineseTranslations(texts: string[]) {
  if (!texts.length) return [];
  let translations: string[] = [];
  try {
    const payload = await fetchJsonWithRetry<{ translations?: unknown[] }>(
      "/api/translate/batch",
      {
        method: "POST",
        headers: { "content-type": "application/json; charset=utf-8" },
        body: JSON.stringify({ texts }),
      },
      1,
    );
    translations = Array.isArray(payload.translations)
      ? payload.translations.map(readableText)
      : [];
  } catch {
    // Direct browser providers below keep translation non-blocking.
  }
  if (texts.some((_, index) => !hasChinese(translations[index] || ""))) {
    const direct = await directChineseTranslations(texts);
    translations = texts.map((_, index) =>
      hasChinese(translations[index] || "")
        ? translations[index]
        : direct[index] || "",
    );
  }
  return translations;
}

type TranslatedLink = { word: string; translation: string };

function relationItems(value: unknown, limit = 8): TranslatedLink[] {
  const result: TranslatedLink[] = [];
  for (const item of list(value)) {
    const [word, ...translationParts] = item.split(" — ");
    const normalizedWord = readableText(word);
    if (!normalizedWord || result.some((row) => row.word === normalizedWord))
      continue;
    result.push({
      word: normalizedWord,
      translation: readableText(translationParts.join(" — ")),
    });
    if (result.length >= limit) break;
  }
  return result;
}

async function withChineseDisplaySenses(entry: DictionaryEntry) {
  const senses = (Array.isArray(entry.display_senses)
    ? entry.display_senses
    : displaySenses(entry)) as DisplaySense[];
  const requests: { sense: number; definition: number; text: string }[] = [];
  senses.forEach((sense, senseIndex) =>
    sense.definitions.forEach((text, definitionIndex) => {
      if (!readableText(sense.definitions_zh[definitionIndex]))
        requests.push({ sense: senseIndex, definition: definitionIndex, text });
    }),
  );
  const related = relationItems(
    list(entry.related_words).length ? entry.related_words : entry.related_entries,
  );
  const synonyms = relationItems(entry.synonyms);
  const antonyms = relationItems(entry.antonyms);
  const relationRows = [...related, ...synonyms, ...antonyms];
  const missingRelations = relationRows.filter(
    (item) => !hasChinese(item.translation),
  );
  const [translations, relationTranslations] = await Promise.all([
    resolvedChineseTranslations(requests.map((item) => item.text)),
    resolvedChineseTranslations(missingRelations.map((item) => item.word)),
  ]);
  const enriched = senses.map((sense) => ({
    ...sense,
    definitions: [...sense.definitions],
    definitions_zh: [...sense.definitions_zh],
  }));
  requests.forEach((request, index) => {
    const translation = (translations[index] || "").replace(
      /[。．]{2,}/g,
      "。",
    );
    if (hasChinese(translation))
      enriched[request.sense].definitions_zh[request.definition] =
        translation;
  });
  missingRelations.forEach((item, index) => {
    const translation = readableText(relationTranslations[index]);
    if (hasChinese(translation)) item.translation = translation;
  });
  return {
    ...entry,
    display_senses: enriched,
    display_related: related,
    display_synonyms: synonyms,
    display_antonyms: antonyms,
  };
}

function ResultSections({
  entry,
  search,
}: {
  entry: DictionaryEntry;
  search(term: string): void;
}) {
  const senses = groupedSenses(
    entry.display_senses || entry.senses,
    entry.pos,
  );
  return (
    <div className={styles.resultBody}>
      {senses.length > 0 && (
        <section>
          <h3>释义</h3>
          {senses.map((sense) => (
            <div className={styles.sense} key={sense.pos}>
              <b>
                {sense.pos} <small>{sense.posZh}</small>
              </b>
              <ol className={styles.definitionList}>
                {sense.items.map((item) => (
                  <li key={item.definition}>
                    <span>{item.definition}</span>
                    {item.translation && (
                      <p className={styles.zh}>{item.translation}</p>
                    )}
                  </li>
                ))}
              </ol>
            </div>
          ))}
        </section>
      )}
      {senses.length === 0 && (entry.definition || entry.definition_zh) && (
        <section>
          <h3>释义</h3>
          {entry.definition && <p>{readableText(entry.definition)}</p>}
          {entry.definition_zh && (
            <div className={styles.chineseOverview}>
              <small>中文释义</small>
              {[...chineseOverview(entry.definition_zh, entry.pos).values()]
                .flat()
                .map((translation) => (
                  <p className={styles.zh} key={translation}>
                    {translation}
                  </p>
                ))}
            </div>
          )}
        </section>
      )}
      <LinkList
        title="联想词"
        values={(entry.display_related as TranslatedLink[]) || relationItems(
          list(entry.related_words).length
            ? entry.related_words
            : entry.related_entries,
        )}
        search={search}
      />
      <LinkList
        title="近义词"
        values={(entry.display_synonyms as TranslatedLink[]) || relationItems(entry.synonyms)}
        search={search}
      />
      <LinkList
        title="反义词"
        values={(entry.display_antonyms as TranslatedLink[]) || relationItems(entry.antonyms)}
        search={search}
      />
      <TextList
        title="例句"
        values={list(entry.examples)}
        highlight={entry.word}
      />
      <TextList
        title="短语与常用搭配"
        values={
          list(entry.phrases).length
            ? list(entry.phrases)
            : list(entry.phrase_entries)
        }
        highlight={entry.word}
      />
    </div>
  );
}
function LinkList({
  title,
  values,
  search,
}: {
  title: string;
  values: TranslatedLink[];
  search(term: string): void;
}) {
  if (!values.length) return null;
  return (
    <section>
      <h3>{title}</h3>
      <div className={styles.linkCloud}>
        {values.slice(0, 12).map((value) => (
          <button key={value.word} onClick={() => search(value.word)}>
            <span>{value.word}</span>
            {value.translation && <small>{value.translation}</small>}
          </button>
        ))}
      </div>
    </section>
  );
}
function TextList({
  title,
  values,
  highlight,
}: {
  title: string;
  values: string[];
  highlight: string;
}) {
  if (!values.length) return null;
  const parts = (value: string) =>
    value.split(
      new RegExp(`(${highlight.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")})`, "ig"),
    );
  return (
    <section>
      <h3>{title}</h3>
      <div className={styles.textList}>
        {values.slice(0, 8).map((value) => (
          <p key={value}>
            {parts(value).map((part, index) =>
              part.toLowerCase() === highlight.toLowerCase() ? (
                <strong key={index}>{part}</strong>
              ) : (
                part
              ),
            )}
          </p>
        ))}
      </div>
    </section>
  );
}

function BookView({
  words,
  setWords,
  settings,
  setSettings,
  records,
  setRecords,
  generatedWords,
  setGeneratedWords,
  setTab,
  notify,
}: {
  words: WordItem[];
  setWords(v: WordItem[] | ((c: WordItem[]) => WordItem[])): void;
  settings: AppSettings;
  setSettings(v: AppSettings | ((c: AppSettings) => AppSettings)): void;
  records: GeneratedBook[];
  setRecords(
    v: GeneratedBook[] | ((c: GeneratedBook[]) => GeneratedBook[]),
  ): void;
  generatedWords: GeneratedWordRecord[];
  setGeneratedWords(
    v:
      | GeneratedWordRecord[]
      | ((c: GeneratedWordRecord[]) => GeneratedWordRecord[]),
  ): void;
  setTab(v: AppTab): void;
  notify(message: string): void;
}) {
  const [input, setInput] = useState("");
  const [dragged, setDragged] = useState<string | null>(null);
  const [sortMode, setSortMode] = useState("custom");
  const [customizing, setCustomizing] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [completed, setCompleted] = useState<GeneratedBook | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  function add(event: FormEvent) {
    event.preventDefault();
    const existing = new Set(words.map((word) => word.term));
    const additions = normalizeTerms(input)
      .filter((term) => !existing.has(term))
      .map((term) => ({
        id: crypto.randomUUID(),
        term,
        status: "idle" as const,
      }));
    if (!additions.length) return notify("请输入有效且未重复的单词或短语");
    setWords((current) => [...current, ...additions]);
    setInput("");
  }
  async function importFile(event: ChangeEvent<HTMLInputElement>) {
    const files = Array.from(event.target.files || []);
    for (const file of files) {
      const body = new FormData();
      body.append("file", file);
      try {
        const response = await fetch("/api/web/import", {
          method: "POST",
          headers: { "x-lexora-device": deviceId() },
          body,
        });
        const result = (await response.json()) as {
          terms?: string[];
          detail?: string;
        };
        if (!response.ok) throw new Error(result.detail || "导入失败");
        setWords((current) => {
          const existing = new Set(current.map((item) => item.term));
          return [
            ...current,
            ...(result.terms || [])
              .filter((term) => !existing.has(term))
              .map((term) => ({
                id: crypto.randomUUID(),
                term,
                status: "idle" as const,
              })),
          ];
        });
        notify(`已从 ${file.name} 导入 ${result.terms?.length || 0} 条`);
      } catch (error) {
        notify(error instanceof Error ? error.message : "导入失败");
      }
    }
    event.target.value = "";
  }
  async function generate() {
    if (!words.length || generating) return;
    if (
      !window.confirm(
        `确定开始生成 ${words.length} 个词条吗？确认后会清空当前列表，便于继续整理下一本词汇书。`,
      )
    )
      return;
    const batch = [...words];
    setWords([]);
    setGenerating(true);
    try {
      const response = await fetch("/api/web/generate", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-lexora-device": deviceId(),
        },
        body: JSON.stringify({
          title: settings.title,
          terms: batch.map((word) => word.term),
          fontPreset: settings.fontPreset,
          examples: settings.examples,
          format: settings.format,
          pageSize: settings.pageSize,
          smartReorder: settings.smartReorder,
          typography: settings.typography,
        }),
      });
      const result = response.ok
        ? null
        : ((await response.json().catch(() => ({}))) as { detail?: string });
      if (!response.ok) throw new Error(result?.detail || "生成失败");
      const blob = await response.blob();
      const id = crypto.randomUUID();
      const filename =
        response.headers.get("x-lexora-filename") ||
        `lexora-${Date.now()}.${settings.format}`;
      const record: GeneratedBook = {
        id,
        title: settings.title,
        filename,
        createdAt: Date.now(),
        wordCount: batch.length,
        previewWords: batch
          .slice(0, 6)
          .map((word) => word.matched || word.term),
        format: settings.format,
        mime: blob.type,
        size: blob.size,
      };
      await saveGeneratedFile(id, blob);
      setRecords([record, ...records]);
      setGeneratedWords((current) => {
        const map = new Map(current.map((item) => [item.word, item]));
        for (const item of batch) {
          const old = map.get(item.term);
          map.set(
            item.term,
            old
              ? {
                  ...old,
                  generationCount: old.generationCount + 1,
                  lastGeneratedAt: Date.now(),
                }
              : {
                  word: item.term,
                  generationCount: 1,
                  firstGeneratedAt: Date.now(),
                  lastGeneratedAt: Date.now(),
                  difficulty: item.difficulty,
                  starred: false,
                },
          );
        }
        return [...map.values()];
      });
      notify("生成完成，已保存到生成记录");
      haptic([12, 35, 22]);
      if (
        document.visibilityState !== "visible" &&
        typeof Notification !== "undefined" &&
        Notification.permission === "granted"
      ) {
        new Notification("Lexora 已生成完毕", {
          body: `${settings.title} 已保存到生成记录。`,
          icon: "/lexora-icon-192.png",
        });
      }
      setCompleted(record);
    } catch (error) {
      setWords((current) => (current.length ? current : batch));
      notify(error instanceof Error ? error.message : "生成失败");
    } finally {
      setGenerating(false);
    }
  }
  function reorder(over: string) {
    if (!dragged || dragged === over) return;
    setWords((current) => {
      const next = [...current];
      const from = next.findIndex((item) => item.id === dragged);
      const to = next.findIndex((item) => item.id === over);
      const [item] = next.splice(from, 1);
      next.splice(to, 0, item);
      return next;
    });
  }
  function sortWords(mode: string) {
    setSortMode(mode);
    if (mode === "custom") return;
    setWords((current) =>
      [...current].sort((a, b) =>
        mode === "alpha"
          ? a.term.localeCompare(b.term)
          : mode === "length"
            ? a.term.length - b.term.length
            : String(a.difficulty || "ZZ").localeCompare(
                String(b.difficulty || "ZZ"),
              ),
      ),
    );
  }
  function moveWord(index: number, delta: number) {
    const target = index + delta;
    if (target < 0 || target >= words.length) return;
    setSortMode("custom");
    setWords((current) => {
      const next = [...current];
      const [item] = next.splice(index, 1);
      next.splice(target, 0, item);
      return next;
    });
  }
  return (
    <div className={styles.page}>
      <PageHeader
        title="词汇书"
        subtitle="整理属于你的词条，再一次生成精致的个人词汇书。"
        action={
          <>
            <input
              ref={fileRef}
              type="file"
              multiple
              hidden
              accept=".txt,.text,.md,.csv,.tsv,.rtf,.doc,.docx,.odt,.pdf"
              onChange={importFile}
            />
            <button
              className={styles.ghostButton}
              onClick={() => fileRef.current?.click()}
            >
              <FiUpload /> 导入文件
            </button>
          </>
        }
      />
      <div className={styles.bookGrid}>
        <section className={styles.card}>
          <form className={styles.bookInput} onSubmit={add}>
            <textarea
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder="输入单词或短语；换行可批量添加"
            />
            <button>
              <FiPlus /> 添加
            </button>
          </form>
          <div className={styles.bookControls}>
            <button onClick={() => setCustomizing(true)}>
              <FiSettings /> 文档自定义
            </button>
            <button
              className={styles.primaryButton}
              disabled={!words.length || generating}
              onClick={generate}
            >
              {generating ? (
                <>
                  <i />
                  云端生成中…
                </>
              ) : (
                <>
                  <FiUpload />
                  生成{" "}
                  {settings.format === "longImage"
                    ? "长图"
                    : settings.format.toUpperCase()}
                </>
              )}
            </button>
          </div>
        </section>
        <section className={styles.card}>
          <div className={styles.listHeader}>
            <div>
              <b>待生成内容</b>
              <small>{words.length} 条 · 可拖动排序</small>
            </div>
            {words.length > 0 && (
              <div className={styles.listTools}>
                <select
                  value={sortMode}
                  onChange={(event) => sortWords(event.target.value)}
                  aria-label="词条排序"
                >
                  <option value="custom">自定义</option>
                  <option value="alpha">字母</option>
                  <option value="length">长度</option>
                  <option value="difficulty">难度</option>
                </select>
                <button onClick={() => setWords([])}>清空</button>
              </div>
            )}
          </div>
          {!words.length ? (
            <Empty
              icon="Aa"
              title="还没有词条"
              text="从左侧输入，或从 TXT、DOCX、PDF 等文件批量导入。"
            />
          ) : (
            <ol className={styles.wordList}>
              {words.map((word, index) => (
                <li
                  key={word.id}
                  draggable
                  onDragStart={() => setDragged(word.id)}
                  onDragEnter={() => reorder(word.id)}
                  onDragOver={(event) => event.preventDefault()}
                  onDragEnd={() => setDragged(null)}
                  className={dragged === word.id ? styles.dragging : ""}
                >
                  <span className={styles.dragHandle}>⋮⋮</span>
                  <small>{index + 1}</small>
                  <div>
                    <b>{word.matched || word.term}</b>
                    {word.matched && <em>原输入：{word.term}</em>}
                    <span>
                      {word.difficulty || "等待生成"}
                      {word.frequency !== undefined
                        ? ` · freq ${word.frequency}`
                        : ""}
                    </span>
                  </div>
                  <div className={styles.listActions}>
                    <button
                      aria-label={`上移 ${word.term}`}
                      disabled={index === 0}
                      onClick={() => moveWord(index, -1)}
                    >
                      <FiChevronDown />
                    </button>
                    <button
                      aria-label={`下移 ${word.term}`}
                      disabled={index === words.length - 1}
                      onClick={() => moveWord(index, 1)}
                    >
                      <FiChevronDown />
                    </button>
                    <button
                      aria-label={`删除 ${word.term}`}
                      onClick={() =>
                        setWords((current) =>
                          current.filter((item) => item.id !== word.id),
                        )
                      }
                    >
                      <FiX />
                    </button>
                  </div>
                </li>
              ))}
            </ol>
          )}
        </section>
      </div>
      {customizing && (
        <CustomizationModal
          settings={settings}
          setSettings={setSettings}
          close={() => setCustomizing(false)}
        />
      )}
      {completed && (
        <div className={styles.modalBackdrop}>
          <section
            className={`${styles.customModal} ${styles.completionModal}`}
            role="dialog"
            aria-modal="true"
            aria-labelledby="generation-complete-title"
          >
            <div className={styles.completionIcon}>
              <FiCheck />
            </div>
            <h2 id="generation-complete-title">词汇书生成完成</h2>
            <p>
              {completed.filename} 已安全保存到生成记录，可以现在分享或打开查看。
            </p>
            <div className={styles.completionActions}>
              <button onClick={() => setCompleted(null)}>忽略</button>
              <button
                className={styles.primaryButton}
                onClick={() =>
                  void readGeneratedFile(completed.id).then((blob) => {
                    if (!blob) return;
                    if (navigator.share) {
                      return navigator.share({
                        files: [
                          new File([blob], completed.filename, {
                            type: blob.type,
                          }),
                        ],
                        title: completed.title,
                      });
                    }
                    const url = URL.createObjectURL(blob);
                    const anchor = document.createElement("a");
                    anchor.href = url;
                    anchor.download = completed.filename;
                    anchor.click();
                    setTimeout(() => URL.revokeObjectURL(url), 30000);
                  })
                }
              >
                <FiShare2 /> 分享
              </button>
              <button
                className={styles.primaryButton}
                onClick={() =>
                  void readGeneratedFile(completed.id).then((blob) => {
                    if (!blob) return;
                    const url = URL.createObjectURL(blob);
                    window.open(url, "_blank", "noopener,noreferrer");
                    setTimeout(() => URL.revokeObjectURL(url), 60000);
                    setCompleted(null);
                  })
                }
              >
                打开
              </button>
            </div>
          </section>
        </div>
      )}
    </div>
  );
}

function CustomizationModal({
  settings,
  setSettings,
  close,
  complete,
}: {
  settings: AppSettings;
  setSettings(v: AppSettings | ((c: AppSettings) => AppSettings)): void;
  close(): void;
  complete?: () => void;
}) {
  const modalRef = useRef<HTMLElement>(null);
  useEffect(() => {
    const previousBodyOverflow = document.body.style.overflow;
    const previousOverscroll = document.documentElement.style.overscrollBehavior;
    document.body.style.overflow = "hidden";
    document.documentElement.style.overscrollBehavior = "none";
    const frame = requestAnimationFrame(() =>
      modalRef.current?.focus({ preventScroll: true }),
    );
    return () => {
      cancelAnimationFrame(frame);
      document.body.style.overflow = previousBodyOverflow;
      document.documentElement.style.overscrollBehavior = previousOverscroll;
    };
  }, []);
  const formats: { id: BookFormat; label: string }[] = [
    { id: "pdf", label: "PDF" },
    { id: "epub", label: "EPUB" },
    { id: "docx", label: "DOCX" },
    { id: "images", label: "分页图片" },
    { id: "longImage", label: "长图" },
  ];
  const update = <K extends keyof AppSettings>(key: K, value: AppSettings[K]) =>
    setSettings((current) => ({ ...current, [key]: value }));
  const applyFontPreset = (preset: FontPreset) =>
    setSettings((current) => ({
      ...current,
      fontPreset: preset,
      typography: { ...fontPresetTypography[preset] },
    }));
  const previewSize = (value: number) => Math.min(24, Math.max(9, value));
  return (
    <div
      className={styles.modalBackdrop}
      onMouseDown={(event) => event.target === event.currentTarget && close()}
    >
      <section
        ref={modalRef}
        className={styles.customModal}
        role="dialog"
        aria-modal="true"
        aria-labelledby="document-customization-title"
        tabIndex={-1}
      >
        <div className={styles.modalHandle} />
        <div className={styles.modalHeader}>
          <div>
            <p>文档自定义</p>
            <h2 id="document-customization-title">让手机阅读与纸张打印都舒服</h2>
          </div>
          <button onClick={close}>
            <FiX />
          </button>
        </div>
        <div className={styles.modalScroll}>
          <SettingGroup title="导出格式">
            <div className={styles.pillGrid}>
              {formats.map((format) => (
                <button
                  key={format.id}
                  aria-pressed={settings.format === format.id}
                  onClick={() => update("format", format.id)}
                >
                  {format.label}
                </button>
              ))}
            </div>
          </SettingGroup>
          <SettingGroup title="纸张尺寸">
            <Segment
              values={["a4", "a5", "b5"]}
              value={settings.pageSize}
              choose={(value) =>
                update("pageSize", value as AppSettings["pageSize"])
              }
            />
          </SettingGroup>
          <SettingGroup title="字号预设">
            <Segment
              values={["small", "medium", "large"]}
              labels={["小", "中", "大"]}
              value={settings.fontPreset}
              choose={(value) => applyFontPreset(value as FontPreset)}
            />
          </SettingGroup>
          <SettingGroup title="例句">
            <Segment
              values={["0", "1", "3"]}
              labels={["不添加", "1 句", "2–3 句"]}
              value={String(settings.examples)}
              choose={(value) =>
                update("examples", Number(value) as AppSettings["examples"])
              }
            />
          </SettingGroup>
          <SettingGroup title="精细调整字体">
            <div className={styles.typographyPreview} aria-live="polite">
              <small>字体预览</small>
              <strong
                style={{ fontSize: `${previewSize(settings.typography.word)}px` }}
              >
                serendipity
              </strong>
              <span
                style={{
                  fontSize: `${previewSize(settings.typography.phonetic)}px`,
                }}
              >
                US /ˌserənˈdɪpəti/ · UK /ˌserənˈdɪpɪti/
              </span>
              <p
                style={{
                  fontSize: `${previewSize(settings.typography.definition)}px`,
                }}
              >
                The pleasant discovery of something unexpected.
              </p>
              <p
                className={styles.typographyPreviewZh}
                style={{
                  fontSize: `${previewSize(settings.typography.definition)}px`,
                }}
              >
                意外发现美好事物的幸运。
              </p>
              <div
                className={styles.typographyPreviewRelated}
                style={{
                  fontSize: `${previewSize(settings.typography.related)}px`,
                }}
              >
                Synonyms / 近义词 · discovery · chance
              </div>
              <blockquote
                style={{
                  fontSize: `${previewSize(settings.typography.example)}px`,
                }}
              >
                We found it by pure serendipity. · 我们偶然发现了它。
              </blockquote>
              <div
                className={styles.typographyPreviewPhrase}
                style={{
                  fontSize: `${previewSize(settings.typography.phrase)}px`,
                }}
              >
                a moment of serendipity · 一次美好的偶遇
              </div>
            </div>
            {Object.entries(settings.typography).map(([key, value]) => (
              <label className={styles.sliderRow} key={key}>
                <span>
                  {
                    {
                      word: "单词标题",
                      phonetic: "音标",
                      definition: "释义",
                      related: "近反义词",
                      example: "例句",
                      phrase: "短语",
                    }[key]
                  }
                  <b>{value} pt</b>
                </span>
                <input
                  type="range"
                  min="6"
                  max={key === "word" ? "32" : "22"}
                  step="0.2"
                  value={value}
                  onChange={(event) =>
                    setSettings((current) => ({
                      ...current,
                      typography: {
                        ...current.typography,
                        [key]: Number(event.target.value),
                      },
                    }))
                  }
                />
              </label>
            ))}
          </SettingGroup>
          <label className={styles.switchRow}>
            <span>
              <b>智能调整顺序</b>
              <small>根据词条长度稳定重排，减少页面留白。</small>
            </span>
            <input
              type="checkbox"
              checked={settings.smartReorder}
              onChange={(event) => update("smartReorder", event.target.checked)}
            />
          </label>
        </div>
        <button className={styles.primaryButton} onClick={complete || close}>
          完成
        </button>
      </section>
    </div>
  );
}
function SettingGroup({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <div className={styles.settingGroup}>
      <h3>{title}</h3>
      {children}
    </div>
  );
}
function Segment({
  values,
  labels,
  value,
  choose,
}: {
  values: string[];
  labels?: string[];
  value: string;
  choose(value: string): void;
}) {
  return (
    <div className={styles.segment}>
      {values.map((item, index) => (
        <button
          key={item}
          aria-pressed={value === item}
          onClick={() => choose(item)}
        >
          {labels?.[index] || item.toUpperCase()}
        </button>
      ))}
    </div>
  );
}

function RecordsView({
  records,
  setRecords,
  notify,
}: {
  records: GeneratedBook[];
  setRecords(
    v: GeneratedBook[] | ((c: GeneratedBook[]) => GeneratedBook[]),
  ): void;
  notify(message: string): void;
}) {
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [multi, setMulti] = useState(false);
  const [reader, setReader] = useState<{
    record: GeneratedBook;
    url: string;
    html?: string;
    images?: string[];
  } | null>(null);
  async function open(record: GeneratedBook, download = false) {
    const blob = await readGeneratedFile(record.id);
    if (!blob) return notify("此文件在浏览器中已被清理");
    const url = URL.createObjectURL(blob);
    if (download) {
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = record.filename;
      anchor.click();
      setTimeout(() => URL.revokeObjectURL(url), 30000);
    } else {
      try {
        if (record.format === "docx") {
          const mammoth = await import("mammoth/mammoth.browser");
          const result = await mammoth.convertToHtml({
            arrayBuffer: await blob.arrayBuffer(),
          });
          setReader({ record, url, html: result.value });
        } else if (record.format === "epub" || record.format === "images") {
          const { default: JSZip } = await import("jszip");
          const archive = await JSZip.loadAsync(blob);
          if (record.format === "epub") {
            const chapter = Object.values(archive.files).find((file) =>
              /chapter.*\.xhtml$/i.test(file.name),
            );
            setReader({
              record,
              url,
              html: chapter
                ? await chapter.async("text")
                : "<p>EPUB 中没有可显示的章节。</p>",
            });
          } else {
            const imageFiles = Object.values(archive.files)
              .filter((file) => /\.png$/i.test(file.name))
              .sort((a, b) => a.name.localeCompare(b.name));
            const images = await Promise.all(
              imageFiles.map(async (file) =>
                URL.createObjectURL(await file.async("blob")),
              ),
            );
            setReader({ record, url, images });
          }
        } else setReader({ record, url });
      } catch {
        URL.revokeObjectURL(url);
        notify("文件阅读器加载失败，仍可以直接下载");
      }
    }
  }
  async function remove(ids: string[]) {
    await Promise.all(ids.map(deleteGeneratedFile));
    setRecords((current) =>
      current.filter((record) => !ids.includes(record.id)),
    );
    setSelected(new Set());
    notify("已删除");
  }
  return (
    <div className={styles.page}>
      <PageHeader
        title="生成记录"
        subtitle="直接阅读、下载、分享或批量管理已生成文件。"
        action={
          <button
            className={styles.ghostButton}
            onClick={() => {
              setMulti(!multi);
              setSelected(new Set());
            }}
          >
            {multi ? "完成" : "多选"}
          </button>
        }
      />
      {multi && records.length > 0 && (
        <div className={styles.selectionBar}>
          <button
            onClick={() =>
              setSelected(new Set(records.map((record) => record.id)))
            }
          >
            全选
          </button>
          <span>已选 {selected.size} 项</span>
          <button
            disabled={!selected.size}
            onClick={() => void remove([...selected])}
          >
            <FiTrash2 /> 删除
          </button>
        </div>
      )}{" "}
      {!records.length ? (
        <Empty
          icon={<FiFileText />}
          title="还没有生成记录"
          text="词汇书生成完成后，可以在这里直接阅读和导出。"
        />
      ) : (
        <div className={styles.recordGrid}>
          {records.map((record) => (
            <article
              className={styles.recordCard}
              key={record.id}
              onClick={() =>
                multi &&
                setSelected((current) => {
                  const next = new Set(current);
                  next.has(record.id)
                    ? next.delete(record.id)
                    : next.add(record.id);
                  return next;
                })
              }
            >
              {multi && (
                <input
                  type="checkbox"
                  readOnly
                  checked={selected.has(record.id)}
                />
              )}
              <div className={styles.fileBadge}>
                {record.format === "longImage"
                  ? "JPG"
                  : record.format.toUpperCase()}
              </div>
              <div className={styles.recordInfo}>
                <h3>{record.title}</h3>
                <p>{record.previewWords.join(" · ")}</p>
                <small>
                  {formatDate(record.createdAt)} · {record.wordCount} 条 ·{" "}
                  {(record.size / 1024 / 1024).toFixed(1)} MB
                </small>
              </div>
              {!multi && (
                <div className={styles.recordActions}>
                  <button onClick={() => void open(record)}>打开</button>
                  <button onClick={() => void open(record, true)}>
                    <FiDownload />
                  </button>
                  <button
                    onClick={() =>
                      navigator.share
                        ? void readGeneratedFile(record.id).then(
                            (blob) =>
                              blob &&
                              navigator.share({
                                files: [
                                  new File([blob], record.filename, {
                                    type: blob.type,
                                  }),
                                ],
                                title: record.title,
                              }),
                          )
                        : void open(record, true)
                    }
                  >
                    <FiShare2 />
                  </button>
                  <button onClick={() => void remove([record.id])}>
                    <FiTrash2 />
                  </button>
                </div>
              )}
            </article>
          ))}
        </div>
      )}
      {reader && (
        <Reader
          record={reader.record}
          url={reader.url}
          html={reader.html}
          images={reader.images}
          close={() => {
            URL.revokeObjectURL(reader.url);
            reader.images?.forEach((image) => URL.revokeObjectURL(image));
            setReader(null);
          }}
        />
      )}
    </div>
  );
}

function Reader({
  record,
  url,
  html,
  images,
  close,
}: {
  record: GeneratedBook;
  url: string;
  html?: string;
  images?: string[];
  close(): void;
}) {
  return (
    <div className={styles.reader}>
      <header>
        <button onClick={close}>
          <FiX />
        </button>
        <b>{record.filename}</b>
        <a href={url} download={record.filename}>
          <FiDownload />
        </a>
      </header>
      {record.format === "longImage" ? (
        <div className={styles.imageReader}>
          <img src={url} alt={record.title} />
        </div>
      ) : record.format === "pdf" ? (
        <iframe src={url} title={record.title} />
      ) : images ? (
        <div className={styles.imagePages}>
          {images.map((image, index) => (
            <img key={image} src={image} alt={`第 ${index + 1} 页`} />
          ))}
        </div>
      ) : html ? (
        <div
          className={styles.documentReader}
          dangerouslySetInnerHTML={{ __html: html }}
        />
      ) : (
        <div className={styles.readerMessage}>
          <FiBookOpen />
          <h2>正在准备阅读器…</h2>
        </div>
      )}
    </div>
  );
}

function HistoryView({
  searches,
  setSearches,
  generatedWords,
  setGeneratedWords,
  setWords,
  setTab,
  settings,
  setSettings,
  openSearch,
  notify,
}: {
  searches: SearchRecord[];
  setSearches(v: SearchRecord[]): void;
  generatedWords: GeneratedWordRecord[];
  setGeneratedWords(
    v:
      | GeneratedWordRecord[]
      | ((c: GeneratedWordRecord[]) => GeneratedWordRecord[]),
  ): void;
  setWords(v: WordItem[]): void;
  setTab(v: AppTab): void;
  settings: AppSettings;
  setSettings(v: AppSettings | ((c: AppSettings) => AppSettings)): void;
  openSearch(record: SearchRecord): void;
  notify(message: string): void;
}) {
  const [mode, setMode] = useState<HistoryMode>("generated");
  const [sort, setSort] = useState("time");
  const [ascending, setAscending] = useState(false);
  const [selecting, setSelecting] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [regenerateTerms, setRegenerateTerms] = useState<string[] | null>(null);
  const visible = useMemo(() => {
    const direction = ascending ? 1 : -1;
    if (mode === "searched") {
      return [...searches].sort((a, b) => {
        const comparison =
          sort === "alpha"
          ? a.resolvedWord.localeCompare(b.resolvedWord)
          : sort === "difficulty"
            ? String(a.difficulty).localeCompare(String(b.difficulty))
            : sort === "frequency"
              ? (a.frequency || 0) - (b.frequency || 0)
              : a.searchedAt - b.searchedAt;
        return comparison * direction;
      });
    }
    return [...generatedWords].sort((a, b) => {
      if (a.starred !== b.starred) return a.starred ? -1 : 1;
      const comparison =
        sort === "alpha"
          ? a.word.localeCompare(b.word)
          : sort === "count"
            ? a.generationCount - b.generationCount
            : sort === "difficulty"
              ? String(a.difficulty).localeCompare(String(b.difficulty))
              : a.lastGeneratedAt - b.lastGeneratedAt;
      return comparison * direction;
    });
  }, [ascending, mode, searches, generatedWords, sort]);
  function changeMode(value: HistoryMode) {
    setMode(value);
    setSort("time");
    setSelecting(false);
    setSelected(new Set());
  }
  function toggleSelecting() {
    setSelecting((current) => !current);
    setSelected(new Set());
  }
  function toggle(id: string) {
    const next = new Set(selected);
    next.has(id) ? next.delete(id) : next.add(id);
    setSelected(next);
  }
  function toggleAll() {
    const ids =
      mode === "searched"
        ? (visible as SearchRecord[]).map((item) => item.id)
        : (visible as GeneratedWordRecord[]).map((item) => item.word);
    setSelected(selected.size === ids.length ? new Set() : new Set(ids));
  }
  function commitBook(values: string[], messageMode: HistoryMode) {
    setWords(
      values.map((term) => ({
        id: crypto.randomUUID(),
        term: term.toLowerCase(),
        status: "idle",
      })),
    );
    setTab("book");
    setSelecting(false);
    setSelected(new Set());
    notify(
      messageMode === "generated"
        ? `已加入 ${values.length} 条，可重新生成词汇书`
        : `已将 ${values.length} 条加入词汇书`,
    );
  }
  function createBook() {
    const values =
      mode === "searched"
        ? searches
            .filter((item) => selected.has(item.id))
            .map((item) => item.resolvedWord)
        : generatedWords
            .filter((item) => selected.has(item.word))
            .map((item) => item.word);
    if (!values.length) return;
    if (mode === "generated") {
      setRegenerateTerms(values);
      return;
    }
    commitBook(values, mode);
  }
  function remove() {
    if (mode === "searched")
      setSearches(searches.filter((item) => !selected.has(item.id)));
    else
      setGeneratedWords((current) =>
        current.filter((item) => !selected.has(item.word)),
      );
    setSelected(new Set());
    setSelecting(false);
  }
  return (
    <div className={styles.page}>
      <div className={styles.historyHeader}>
        <h1>历史</h1>
        <div className={styles.historySwitch}>
          <button
            aria-pressed={mode === "generated"}
            onClick={() => changeMode("generated")}
          >
            生成历史
          </button>
          <button
            aria-pressed={mode === "searched"}
            onClick={() => changeMode("searched")}
          >
            搜索历史
          </button>
        </div>
        <button className={styles.historySelect} onClick={toggleSelecting}>
          {selecting ? <FiX /> : <FiCheck />}
          {selecting ? "完成" : "多选"}
        </button>
      </div>
      <div className={styles.toolbar}>
        <label className={styles.sortField}>
          <span>排序方式</span>
          <select
            value={sort}
            onChange={(event) => setSort(event.target.value)}
          >
          <option value="time">
            {mode === "generated" ? "生成时间" : "搜索时间"}
          </option>
          <option value="alpha">首字母</option>
          <option value="difficulty">难度</option>
          {mode === "generated" ? (
            <option value="count">生成次数</option>
          ) : (
            <option value="frequency">词频</option>
          )}
          </select>
        </label>
        <button
          className={styles.orderButton}
          onClick={() => setAscending(!ascending)}
          aria-label={ascending ? "升序" : "降序"}
        >
          {ascending ? "↑" : "↓"}
        </button>
      </div>
      {selecting && visible.length > 0 && (
        <div className={styles.historyBulkBar}>
          <button onClick={toggleAll}>
            {selected.size === visible.length ? "取消全选" : "全选"}
          </button>
          <span>已选 {selected.size} 项</span>
          <div />
          <button onClick={createBook} disabled={!selected.size}>
            <FiBookOpen />
            {mode === "generated" ? "重新生成" : "生成词汇书"}
          </button>
          <button onClick={remove} disabled={!selected.size} aria-label="删除">
            <FiTrash2 />
          </button>
        </div>
      )}
      {!visible.length ? (
        <Empty
          icon={<FiClock />}
          title="还没有历史"
          text={
            mode === "searched"
              ? "查过的单词会自动出现在这里。"
              : "生成过的词条会按次数与时间记录。"
          }
        />
      ) : (
        <div className={styles.historyList}>
          {mode === "searched"
            ? (visible as SearchRecord[]).map((item) => (
                <HistoryRow
                  key={item.id}
                  id={item.id}
                  selecting={selecting}
                  selected={selected.has(item.id)}
                  toggle={toggle}
                  title={item.resolvedWord}
                  meta={`${item.difficulty || "—"} · freq ${item.frequency?.toFixed?.(1) ?? item.frequency ?? "—"} · ${formatDate(item.searchedAt)}${item.query === item.resolvedWord ? "" : ` · ${item.query} → ${item.resolvedWord}`}`}
                  open={() => openSearch(item)}
                  trailing={
                    <button
                      className={styles.rowAction}
                      aria-label="删除记录"
                      onClick={() =>
                        setSearches(searches.filter((row) => row.id !== item.id))
                      }
                    >
                      <FiX />
                    </button>
                  }
                />
              ))
            : (visible as GeneratedWordRecord[]).map((item) => (
                <HistoryRow
                  key={item.word}
                  id={item.word}
                  selecting={selecting}
                  selected={selected.has(item.word)}
                  toggle={toggle}
                  title={item.word}
                  meta={`${item.difficulty || "—"} · 生成 ${item.generationCount} 次 · ${formatDate(item.lastGeneratedAt)}`}
                  trailing={
                    <button
                      className={styles.starButton}
                      aria-label={item.starred ? "取消星标" : "添加星标"}
                      onClick={() => {
                        setGeneratedWords((current) =>
                          current.map((row) =>
                            row.word === item.word
                              ? { ...row, starred: !row.starred }
                              : row,
                          ),
                        );
                      }}
                    >
                      <FiStar fill={item.starred ? "currentColor" : "none"} />
                    </button>
                  }
                />
              ))}
        </div>
      )}
      {regenerateTerms && (
        <CustomizationModal
          settings={settings}
          setSettings={setSettings}
          close={() => setRegenerateTerms(null)}
          complete={() => {
            const values = regenerateTerms;
            setRegenerateTerms(null);
            commitBook(values, "generated");
          }}
        />
      )}
    </div>
  );
}
function HistoryRow({
  id,
  selecting,
  selected,
  toggle,
  title,
  meta,
  open,
  trailing,
}: {
  id: string;
  selecting: boolean;
  selected: boolean;
  toggle(id: string): void;
  title: string;
  meta: string;
  open?: () => void;
  trailing?: ReactNode;
}) {
  return (
    <article
      className={styles.historyRow}
      data-selected={selected || undefined}
      onClick={selecting ? () => toggle(id) : undefined}
    >
      {selecting ? (
        <input type="checkbox" readOnly checked={selected} />
      ) : (
        <span className={styles.historyAvatar}>
          {title.charAt(0).toUpperCase()}
        </span>
      )}
      <button
        className={styles.historyRowBody}
        onClick={selecting ? undefined : open}
      >
        <h3>{title}</h3>
        <p>{meta}</p>
      </button>
      {!selecting && trailing}
    </article>
  );
}

function SettingsView({
  settings,
  setSettings,
  notify,
}: {
  settings: AppSettings;
  setSettings(v: AppSettings | ((c: AppSettings) => AppSettings)): void;
  notify(message: string): void;
}) {
  const [customizing, setCustomizing] = useState(false);
  const [donate, setDonate] = useState(false);
  const update = <K extends keyof AppSettings>(key: K, value: AppSettings[K]) =>
    setSettings((current) => ({ ...current, [key]: value }));
  async function refreshPage() {
    notify("正在刷新网页…");
    try {
      const registrations =
        (await navigator.serviceWorker?.getRegistrations()) || [];
      await Promise.all(registrations.map((item) => item.update()));
    } finally {
      window.location.reload();
    }
  }
  return (
    <div className={styles.page}>
      <PageHeader
        title="设置"
        subtitle="v4.0.2 · 网页完整版"
        action={
          <a
            className={`${styles.ghostButton} ${styles.desktopOnly}`}
            href="https://github.com/xiaozhangwangxue/lexora"
            target="_blank"
            rel="noreferrer"
          >
            <FiGithub /> GitHub
          </a>
        }
      />
      <section className={`${styles.card} ${styles.introCard}`}>
        <Image
          src="/favicon.png"
          alt="Lexora"
          width={68}
          height={68}
          unoptimized
        />
        <div>
          <LexoraWordmark />
          <h2>把零散单词，变成真正想读的词汇书。</h2>
          <p>
            Lexora
            会联网补全难度、词频、英美音标、双语释义、近反义词、例句和短语。
          </p>
        </div>
      </section>
      <section className={styles.settingsGrid}>
        <div className={styles.settingsCard}>
          <h2>
            <FiSettings /> 文档自定义
          </h2>
          <SettingRow
            title="导出格式"
            detail={`${settings.format.toUpperCase()} · ${settings.pageSize.toUpperCase()} · ${settings.fontPreset}`}
            action={
              <button onClick={() => setCustomizing(true)}>
                调整 <FiChevronDown />
              </button>
            }
          />
          <SettingRow
            title="搜索结果字号"
            detail={`${Math.round(settings.searchScale * 100)}%`}
            className={styles.rangeSetting}
            action={
              <input
                type="range"
                min="0.8"
                max="1.5"
                step="0.05"
                value={settings.searchScale}
                onChange={(event) =>
                  update("searchScale", Number(event.target.value))
                }
              />
            }
          />
        </div>
        <div className={styles.settingsCard}>
          <h2>
            <FiUpload /> 云端与性能
          </h2>
          <SettingRow
            title="甲骨文云服务器加速"
            detail="查词、词汇书和文档导出"
            action={
              <input
                type="checkbox"
                checked={settings.serverAcceleration}
                onChange={(event) =>
                  update("serverAcceleration", event.target.checked)
                }
              />
            }
          />
          <SettingRow
            title="生成完成通知"
            detail="焦点不在 Lexora 时使用系统通知提醒"
            action={
              <button
                onClick={() => {
                  if (typeof Notification === "undefined") {
                    notify("当前浏览器不支持系统通知");
                    return;
                  }
                  void Notification.requestPermission().then((permission) =>
                    notify(
                      permission === "granted" ? "通知已开启" : "未开启通知",
                    ),
                  );
                }}
              >
                开启
              </button>
            }
          />
        </div>
        <div className={styles.settingsCard}>
          <h2>
            <FiExternalLink /> 快捷链接
          </h2>
          <SettingLink
            href="/"
            title="Lexora 官网"
            detail="下载更新与安装说明"
          />
          <SettingLink
            href="https://github.com/xiaozhangwangxue/lexora"
            title="GitHub"
            detail="源代码与版本发布"
          />
          <SettingLink
            href="https://github.com/xiaozhangwangxue/lexora/blob/main/LICENSE"
            title="开源协议"
            detail="查看 Lexora 的开源许可"
          />
          <SettingRow
            title="刷新网页"
            detail="重新载入页面并获取最新内容"
            action={
              <button onClick={() => void refreshPage()} aria-label="刷新网页">
                <FiRefreshCw />
              </button>
            }
          />
          <SettingRow
            title="支持 Lexora"
            detail="捐款完全自愿"
            action={
              <button onClick={() => setDonate(true)}>
                <FiHeart />
              </button>
            }
          />
        </div>
      </section>
      {customizing && (
        <CustomizationModal
          settings={settings}
          setSettings={setSettings}
          close={() => setCustomizing(false)}
        />
      )}
      {donate && (
        <div className={styles.modalBackdrop} onClick={() => setDonate(false)}>
          <section
            className={styles.donateModal}
            onClick={(event) => event.stopPropagation()}
          >
            <button onClick={() => setDonate(false)}>
              <FiX />
            </button>
            <h2>支持 Lexora</h2>
            <p>捐款完全自愿，不会解锁付费功能。</p>
            <div>
              <img
                src="https://photo.12323456.xyz/api/rfile/微信.png"
                alt="微信捐赠二维码"
              />
              <img
                src="https://photo.12323456.xyz/api/rfile/支付宝.jpg"
                alt="支付宝捐赠二维码"
              />
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
function SettingRow({
  title,
  detail,
  action,
  className,
}: {
  title: string;
  detail: string;
  action: ReactNode;
  className?: string;
}) {
  return (
    <div className={`${styles.settingRow} ${className || ""}`}>
      <div>
        <b>{title}</b>
        <small>{detail}</small>
      </div>
      {action}
    </div>
  );
}
function SettingLink({
  href,
  title,
  detail,
}: {
  href: string;
  title: string;
  detail: string;
}) {
  return (
    <a
      className={styles.settingRow}
      href={href}
      target={href === "/" ? undefined : "_blank"}
      rel="noreferrer"
    >
      <div>
        <b>{title}</b>
        <small>{detail}</small>
      </div>
      <FiExternalLink />
    </a>
  );
}
function Empty({
  icon,
  title,
  text,
}: {
  icon: ReactNode;
  title: string;
  text: string;
}) {
  return (
    <div className={styles.empty}>
      <span>{icon}</span>
      <h2>{title}</h2>
      <p>{text}</p>
    </div>
  );
}
function Onboarding({ close }: { close(): void }) {
  const [step, setStep] = useState(0);
  const content = [
    {
      icon: <FiSearch />,
      title: "完整的双语词典",
      text: "搜索单词或短语，查看释义、音标、难度、词频、例句与搭配。",
    },
    {
      icon: <FiBookOpen />,
      title: "一键生成个人词汇书",
      text: "批量导入词条，精细调整字体和纸张，导出 PDF、EPUB、DOCX 或图片。",
    },
    {
      icon: <FiClock />,
      title: "历史与记录不会丢",
      text: "浏览器意外刷新后，待生成列表、设置、搜索历史和生成记录仍会保留。",
    },
  ];
  const item = content[step];
  return (
    <div className={styles.modalBackdrop}>
      <section className={styles.onboarding}>
        <div className={styles.onboardingIcon}>{item.icon}</div>
        <p>
          {step + 1} / {content.length}
        </p>
        <h2>{item.title}</h2>
        <span>{item.text}</span>
        <div className={styles.dots}>
          {content.map((_, index) => (
            <i key={index} className={index === step ? styles.activeDot : ""} />
          ))}
        </div>
        <button
          className={styles.primaryButton}
          onClick={() =>
            step === content.length - 1 ? close() : setStep(step + 1)
          }
        >
          {step === content.length - 1 ? "开始使用" : "继续"}
        </button>
      </section>
    </div>
  );
}
