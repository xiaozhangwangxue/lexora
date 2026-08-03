"use client";

import Link from "next/link";
import { ChangeEvent, FormEvent, useEffect, useMemo, useRef, useState } from "react";
import { LexoraWordmark } from "../lexora-wordmark";
import { useSiteLanguage } from "../use-site-language";

const apiBase = "https://dict.12323456.xyz";
const listStorageKey = "lexora.web.words";
const identityStorageKey = "lexora.web.client-hash";

type Suggestion = { word: string; normalized_word?: string; frequency?: number; frequency_rank?: number };
type Entry = {
  word: string;
  normalized_word?: string;
  matched_word?: string;
  match_type?: string;
  definition?: string;
  definition_zh?: string;
  pos?: string;
  us_phonetic?: string;
  uk_phonetic?: string;
  difficulty?: string;
  frequency?: number | string;
  examples?: unknown[];
  synonyms?: unknown[];
  antonyms?: unknown[];
  phrases?: unknown[];
  related_words?: unknown[];
};

function createIdentity() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join("");
}

function getIdentity() {
  let identity = window.localStorage.getItem(identityStorageKey);
  if (!identity || !/^[a-f0-9]{64}$/.test(identity)) {
    identity = createIdentity();
    window.localStorage.setItem(identityStorageKey, identity);
  }
  return identity;
}

function displayValue(value: unknown): string {
  if (typeof value === "string") return value;
  if (value && typeof value === "object") {
    const item = value as Record<string, unknown>;
    const english = item.word ?? item.phrase ?? item.text ?? item.example ?? item.definition;
    const chinese = item.translation ?? item.translation_zh ?? item.definition_zh;
    return [english, chinese].filter((part): part is string => typeof part === "string" && part.length > 0).join(" — ");
  }
  return "";
}

async function errorMessage(response: Response) {
  try {
    const payload = await response.json() as { detail?: string };
    return payload.detail || `${response.status}`;
  } catch {
    return `${response.status}`;
  }
}

export default function WebApp() {
  const { language, setLanguage, zh } = useSiteLanguage();
  const [query, setQuery] = useState("");
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [entry, setEntry] = useState<Entry | null>(null);
  const [words, setWords] = useState<string[]>([]);
  const [searching, setSearching] = useState(false);
  const [importing, setImporting] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [message, setMessage] = useState("");
  const [title, setTitle] = useState("My vocabulary book");
  const [format, setFormat] = useState("pdf");
  const [pageSize, setPageSize] = useState("a4");
  const [fontPreset, setFontPreset] = useState("medium");
  const [examples, setExamples] = useState(1);
  const [smartReorder, setSmartReorder] = useState(true);
  const suggestionRequest = useRef<AbortController | null>(null);
  const suggestionTimer = useRef<number | null>(null);
  const restoredWords = useRef(false);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      try {
        const saved = JSON.parse(window.localStorage.getItem(listStorageKey) || "[]") as unknown;
        restoredWords.current = true;
        if (Array.isArray(saved)) setWords(saved.filter((item): item is string => typeof item === "string").slice(0, 500));
      } catch { restoredWords.current = true; }
    }, 0);
    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    if (restoredWords.current) window.localStorage.setItem(listStorageKey, JSON.stringify(words));
  }, [words]);

  useEffect(() => {
    const prefix = query.trim();
    if (prefix.length < 2 || entry?.normalized_word === prefix.toLowerCase()) {
      return;
    }
    suggestionTimer.current = window.setTimeout(async () => {
      suggestionRequest.current?.abort();
      const controller = new AbortController();
      suggestionRequest.current = controller;
      try {
        const response = await fetch(`${apiBase}/v1/web/suggest?prefix=${encodeURIComponent(prefix)}&limit=8`, {
          headers: { "X-Lexora-Client-Hash": getIdentity() },
          signal: controller.signal,
        });
        if (response.ok) setSuggestions(await response.json() as Suggestion[]);
      } catch (error) {
        if (!(error instanceof DOMException && error.name === "AbortError")) setSuggestions([]);
      }
    }, 300);
    return () => {
      if (suggestionTimer.current !== null) window.clearTimeout(suggestionTimer.current);
    };
  }, [query, entry?.normalized_word]);

  const isSaved = useMemo(() => entry ? words.includes(entry.word) : false, [entry, words]);

  function addWord(word: string) {
    const cleaned = word.trim();
    if (!cleaned) return;
    setWords((current) => current.includes(cleaned) ? current : [...current, cleaned]);
    setMessage(zh ? `已将“${cleaned}”加入词汇书` : `Added “${cleaned}” to your book`);
  }

  async function search(term: string) {
    const cleaned = term.trim();
    if (!cleaned) return;
    if (suggestionTimer.current !== null) window.clearTimeout(suggestionTimer.current);
    suggestionRequest.current?.abort();
    setQuery(cleaned);
    setSuggestions([]);
    setSearching(true);
    setMessage("");
    try {
      const response = await fetch(`${apiBase}/v1/web/lookup?term=${encodeURIComponent(cleaned)}`, {
        headers: { "X-Lexora-Client-Hash": getIdentity() },
      });
      if (!response.ok) throw new Error(await errorMessage(response));
      setEntry(await response.json() as Entry);
    } catch (error) {
      setEntry(null);
      setMessage(`${zh ? "没有找到可靠结果" : "No reliable result"}：${error instanceof Error ? error.message : ""}`);
    } finally {
      setSearching(false);
    }
  }

  function submitSearch(event: FormEvent) {
    event.preventDefault();
    void search(query);
  }

  function updateQuery(next: string) {
    setQuery(next);
    if (next.trim().length < 2) setSuggestions([]);
  }

  async function importFile(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    setImporting(true);
    setMessage("");
    const body = new FormData();
    body.append("file", file);
    try {
      const response = await fetch(`${apiBase}/v1/web/import`, {
        method: "POST",
        headers: { "X-Lexora-Client-Hash": getIdentity() },
        body,
      });
      if (!response.ok) throw new Error(await errorMessage(response));
      const payload = await response.json() as { terms: string[]; count: number };
      setWords((current) => Array.from(new Set([...current, ...payload.terms])).slice(0, 500));
      setMessage(zh ? `已从文件导入 ${payload.count} 个词条` : `Imported ${payload.count} entries`);
    } catch (error) {
      setMessage(`${zh ? "导入失败" : "Import failed"}：${error instanceof Error ? error.message : ""}`);
    } finally {
      setImporting(false);
    }
  }

  function moveWord(index: number, direction: -1 | 1) {
    const destination = index + direction;
    if (destination < 0 || destination >= words.length) return;
    setWords((current) => {
      const next = [...current];
      [next[index], next[destination]] = [next[destination], next[index]];
      return next;
    });
  }

  async function generateBook() {
    if (!words.length) {
      setMessage(zh ? "请先添加至少一个单词或短语" : "Add at least one word or phrase first");
      return;
    }
    setGenerating(true);
    setMessage(zh ? "正在生成，请稍候…" : "Generating, please wait…");
    try {
      const response = await fetch(`${apiBase}/v1/web/generate`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Lexora-Client-Hash": getIdentity() },
        body: JSON.stringify({ title, terms: words, fontPreset, examples, format, pageSize, smartReorder, typography: {} }),
      });
      if (!response.ok) throw new Error(await errorMessage(response));
      const blob = await response.blob();
      const disposition = response.headers.get("content-disposition") || "";
      const encoded = disposition.match(/filename\*=UTF-8''([^;]+)/i)?.[1];
      const plain = disposition.match(/filename="?([^";]+)"?/i)?.[1];
      const extension = format === "longImage" ? "png" : format === "images" ? "zip" : format;
      const filename = response.headers.get("X-Lexora-Filename") || (encoded ? decodeURIComponent(encoded) : plain) || `lexora-vocabulary-book.${extension}`;
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.setTimeout(() => URL.revokeObjectURL(url), 1000);
      const skipped = response.headers.get("X-Lexora-Skipped");
      setMessage(skipped ? (zh ? `生成完成，已跳过：${skipped}` : `Done. Skipped: ${skipped}`) : (zh ? "生成完成，文件已开始下载" : "Done. Your download has started"));
    } catch (error) {
      setMessage(`${zh ? "生成失败" : "Generation failed"}：${error instanceof Error ? error.message : ""}`);
    } finally {
      setGenerating(false);
    }
  }

  function renderItems(titleText: string, values?: unknown[]) {
    const items = (values || []).map(displayValue).filter(Boolean);
    if (!items.length) return null;
    return <section className="webResultSection"><h3>{titleText}</h3><ul>{items.map((item, index) => <li key={`${item}-${index}`}>{item}</li>)}</ul></section>;
  }

  return (
    <main className="webAppPage">
      <header className="webAppTopbar wrap">
        <Link className="brand" href="/" aria-label={zh ? "返回 Lexora 官网" : "Back to Lexora home"}><LexoraWordmark /></Link>
        <nav aria-label={zh ? "网页版导航" : "Web app navigation"}>
          <Link href="/">{zh ? "官网" : "Website"}</Link>
          <a href="https://github.com/xiaozhangwangxue/lexora" target="_blank" rel="noreferrer">GitHub</a>
          <button className="language" onClick={() => setLanguage(language === "zh" ? "en" : "zh")}>{zh ? "EN" : "中文"}</button>
        </nav>
      </header>

      <section className="webAppHero wrap">
        <div><p className="sectionLabel">{zh ? "无需安装 · 无需账号" : "No install · No account"}</p><h1>{zh ? "在线查词，生成你的词汇书。" : "Look up words. Build your own book."}</h1><p>{zh ? "查询单词或短语，把需要的内容加入列表，然后直接导出为适合阅读、打印或编辑的文档。" : "Look up a word or phrase, save what matters, then export a document made for reading, printing, or editing."}</p></div>
        <form className="webSearch" onSubmit={submitSearch} role="search">
          <span aria-hidden="true">⌕</span>
          <input value={query} onChange={(event) => updateQuery(event.target.value)} placeholder={zh ? "输入单词或短语" : "Enter a word or phrase"} aria-label={zh ? "搜索单词或短语" : "Search for a word or phrase"} autoComplete="off" />
          <button type="submit" disabled={searching}>{searching ? "…" : "↵"}<span className="srOnly">{zh ? "搜索" : "Search"}</span></button>
          {suggestions.length > 0 && <div className="webSuggestions" role="listbox">{suggestions.map((item) => <button type="button" role="option" aria-selected="false" key={item.normalized_word || item.word} onClick={() => void search(item.word)}><span>⌕</span><b>{item.word}</b><small>↵</small></button>)}</div>}
        </form>
      </section>

      <div className="webAppGrid wrap">
        <section className="webLookupPanel" aria-live="polite">
          {entry ? <article className="webResult">
            <header><div><h2>{entry.word}</h2>{entry.match_type === "fuzzy" && <p className="webFuzzy">{zh ? `与“${query}”模糊匹配` : `Fuzzy match for “${query}”`}</p>}<p>{entry.us_phonetic && `US /${entry.us_phonetic.replace(/^\/?|\/?$/g, "")}/`} {entry.uk_phonetic && ` · UK /${entry.uk_phonetic.replace(/^\/?|\/?$/g, "")}/`}</p></div><button className={`webSaveButton${isSaved ? " isSaved" : ""}`} onClick={() => isSaved ? setWords((current) => current.filter((word) => word !== entry.word)) : addWord(entry.word)} aria-label={isSaved ? (zh ? "从词汇书移除" : "Remove from book") : (zh ? "加入词汇书" : "Add to book")}>{isSaved ? "✓" : "+"}</button></header>
            <div className="webBadges">{entry.difficulty && <b>{entry.difficulty}</b>}{entry.frequency !== undefined && <b>freq {entry.frequency}</b>}{entry.pos && <b>{entry.pos}</b>}</div>
            {(entry.definition || entry.definition_zh) && <section className="webResultSection"><h3>{zh ? "释义" : "Definition"}</h3>{entry.definition && <p>{entry.definition}</p>}{entry.definition_zh && <p className="webTranslation">{entry.definition_zh}</p>}</section>}
            {renderItems(zh ? "例句" : "Examples", entry.examples)}
            {renderItems(zh ? "近义词" : "Synonyms", entry.synonyms)}
            {renderItems(zh ? "反义词" : "Antonyms", entry.antonyms)}
            {renderItems(zh ? "常用短语" : "Phrases", entry.phrases)}
            {renderItems(zh ? "联想词" : "Related words", entry.related_words)}
          </article> : <div className="webEmpty"><LexoraWordmark /><h2>{zh ? "你的在线英汉词典" : "Your online bilingual dictionary"}</h2><p>{zh ? "搜索结果会显示在这里。找到需要的词后，点加号放进右侧词汇书。" : "Results appear here. Use the plus button to save a word to your book."}</p></div>}
        </section>

        <aside className="webBookPanel">
          <header><div><p className="sectionLabel">{zh ? "个人词汇书" : "Vocabulary book"}</p><h2>{words.length} {zh ? "个词条" : "entries"}</h2></div><label className="webImportButton">{importing ? "…" : (zh ? "导入文件" : "Import file")}<input type="file" accept=".txt,.pdf,.doc,.docx,.rtf,.odt,.csv,.tsv" onChange={importFile} disabled={importing} /></label></header>
          <div className="webWordList">{words.length ? words.map((word, index) => <div key={`${word}-${index}`}><span>{index + 1}</span><b>{word}</b><div><button onClick={() => moveWord(index, -1)} disabled={index === 0} aria-label={zh ? "上移" : "Move up"}>↑</button><button onClick={() => moveWord(index, 1)} disabled={index === words.length - 1} aria-label={zh ? "下移" : "Move down"}>↓</button><button onClick={() => setWords((current) => current.filter((_, itemIndex) => itemIndex !== index))} aria-label={zh ? "删除" : "Delete"}>×</button></div></div>) : <p>{zh ? "搜索并添加单词，或从 TXT、PDF、DOC、DOCX 等文件批量导入。" : "Search and add words, or import them from TXT, PDF, DOC, DOCX, and more."}</p>}</div>
          <div className="webExportSettings">
            <label>{zh ? "标题" : "Title"}<input value={title} maxLength={60} onChange={(event) => setTitle(event.target.value)} /></label>
            <div className="webSettingRow"><label>{zh ? "格式" : "Format"}<select value={format} onChange={(event) => setFormat(event.target.value)}><option value="pdf">PDF</option><option value="epub">EPUB</option><option value="docx">DOCX</option><option value="images">{zh ? "分页图片" : "Page images"}</option><option value="longImage">{zh ? "长图" : "Long image"}</option></select></label><label>{zh ? "纸张" : "Page"}<select value={pageSize} onChange={(event) => setPageSize(event.target.value)}><option value="a4">A4</option><option value="a5">A5</option><option value="b5">B5</option></select></label></div>
            <div className="webSettingRow"><label>{zh ? "字号" : "Text size"}<select value={fontPreset} onChange={(event) => setFontPreset(event.target.value)}><option value="small">{zh ? "小" : "Small"}</option><option value="medium">{zh ? "中" : "Medium"}</option><option value="large">{zh ? "大" : "Large"}</option></select></label><label>{zh ? "例句" : "Examples"}<select value={examples} onChange={(event) => setExamples(Number(event.target.value))}><option value={0}>0</option><option value={1}>1</option><option value={3}>2–3</option></select></label></div>
            <label className="webCheck"><input type="checkbox" checked={smartReorder} onChange={(event) => setSmartReorder(event.target.checked)} />{zh ? "智能调整顺序，减少留白" : "Smart ordering to reduce whitespace"}</label>
          </div>
          <button className="webGenerateButton" onClick={() => void generateBook()} disabled={generating || !words.length}>{generating ? (zh ? "正在生成…" : "Generating…") : (zh ? "生成并下载" : "Generate and download")}<span>↗</span></button>
          {message && <p className="webStatus" role="status">{message}</p>}
          <small className="webPrivacy">{zh ? "列表仅保存在当前浏览器。本服务免费，受每日公平使用额度限制。" : "Your list stays in this browser. This free service has a daily fair-use limit."}</small>
        </aside>
      </div>
    </main>
  );
}
