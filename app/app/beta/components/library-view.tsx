"use client";

import { useMemo, useState } from "react";
import { FiBookOpen, FiChevronRight, FiEdit3, FiFilter, FiHeadphones, FiPlus, FiSearch, FiStar, FiTrash2, FiVolume2, FiX } from "react-icons/fi";
import { createClozeSentence } from "../domain/answers";
import { formatDueTime } from "../domain/time";
import { groupReviewLogsByWord } from "../domain/stats";
import { isWeakWord } from "../domain/weak";
import { skillTagLabels, sourceTypeLabels, statusLabels, type Collocation, type SkillTag, type SourceType, type Word, type WordExample, type WordMeaning, type WordSource } from "../domain/types";
import { playWord, speakText } from "../services/speech";
import { useBetaStore } from "../store";
import styles from "../beta.module.css";

type Filter = "all" | "new" | "learning" | "review" | "mastered" | "lapsed" | "weak" | "important" | "due" | "has-example" | "no-example" | "has-source" | "no-source" | "has-collocation" | "no-collocation";
type Sort = "recent" | "oldest" | "due" | "lapses" | "reviews-desc" | "reviews-asc" | "alphabetical";

function uid(prefix: string) {
  return `${prefix}-${crypto.randomUUID()}`;
}

function blankWord(): Word {
  const now = new Date().toISOString();
  return {
    id: uid("word"), text: "", normalizedText: "", meanings: [{ id: uid("meaning"), partOfSpeech: "", definitionZh: "", definitionEn: "", acceptedAnswers: [], examples: [] }], collocations: [], sources: [], tags: [], customTags: [], isImportant: false, createdAt: now, updatedAt: now,
  };
}

export function LibraryView({ startStudy }: { startStudy(): void }) {
  const { state, loaded, saveWord, deleteWord, toggleImportant, importDictionaryWord, startStudy: createSession } = useBetaStore();
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<Filter>("all");
  const [tag, setTag] = useState<SkillTag | "all">("all");
  const [sourceType, setSourceType] = useState<SourceType | "all">("all");
  const [sort, setSort] = useState<Sort>("recent");
  const [selected, setSelected] = useState<Word | null>(null);
  const [editing, setEditing] = useState<Word | null>(null);
  const [lookup, setLookup] = useState("");
  const [lookupBusy, setLookupBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [now] = useState(Date.now);
  const logsByWord = useMemo(() => groupReviewLogsByWord(state.reviewLogs), [state.reviewLogs]);

  const words = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    const matches = state.words.filter((word) => {
      const review = state.reviewStates[word.id];
      const logs = (logsByWord.get(word.id) ?? []).slice(-10);
      const searchable = [word.text, word.note, ...word.meanings.flatMap((meaning) => [meaning.definitionZh, meaning.definitionEn, ...meaning.examples.flatMap((example) => [example.sentence, example.translation])]), ...word.collocations.flatMap((item) => [item.text, item.meaningZh]), ...word.sources.flatMap((source) => [source.title, source.originalSentence]), ...word.customTags].filter(Boolean).join(" ").toLowerCase();
      if (normalizedQuery && !searchable.includes(normalizedQuery)) return false;
      if (tag !== "all" && !word.tags.includes(tag)) return false;
      if (sourceType !== "all" && !word.sources.some((source) => source.sourceType === sourceType)) return false;
      if (!review) return filter === "all";
      const hasExample = word.meanings.some((meaning) => meaning.examples.length);
      if (["new", "learning", "review", "mastered", "lapsed"].includes(filter) && review.status !== filter) return false;
      if (filter === "weak" && !isWeakWord(review, logs)) return false;
      if (filter === "important" && !word.isImportant) return false;
      if (filter === "due" && new Date(review.dueAt).getTime() > now) return false;
      if (filter === "has-example" && !hasExample) return false;
      if (filter === "no-example" && hasExample) return false;
      if (filter === "has-source" && !word.sources.length) return false;
      if (filter === "no-source" && word.sources.length) return false;
      if (filter === "has-collocation" && !word.collocations.length) return false;
      if (filter === "no-collocation" && word.collocations.length) return false;
      return true;
    });
    return matches.sort((a, b) => {
      const aState = state.reviewStates[a.id], bState = state.reviewStates[b.id];
      if (sort === "oldest") return a.createdAt.localeCompare(b.createdAt);
      if (sort === "due") return (aState?.dueAt ?? "").localeCompare(bState?.dueAt ?? "");
      if (sort === "lapses") return (bState?.lapseCount ?? 0) - (aState?.lapseCount ?? 0);
      if (sort === "reviews-desc") return (bState?.totalReviews ?? 0) - (aState?.totalReviews ?? 0);
      if (sort === "reviews-asc") return (aState?.totalReviews ?? 0) - (bState?.totalReviews ?? 0);
      if (sort === "alphabetical") return a.normalizedText.localeCompare(b.normalizedText);
      return b.createdAt.localeCompare(a.createdAt);
    });
  }, [filter, logsByWord, now, query, sort, sourceType, state.reviewStates, state.words, tag]);

  async function lookupWord() {
    const term = lookup.trim();
    if (!term || lookupBusy) return;
    if (state.words.some((word) => word.normalizedText === term.toLowerCase())) { setMessage("该单词已存在，可以打开已有词条继续编辑或添加来源。"); return; }
    setLookupBusy(true); setMessage("");
    try {
      const response = await fetch(`/api/web/lookup?term=${encodeURIComponent(term)}`, { headers: { "x-lexora-device": crypto.randomUUID() } });
      if (!response.ok) throw new Error(response.status === 404 ? "没有找到可靠词典结果，可改为手动录入。" : "词典暂时无法连接");
      const entry = await response.json();
      setEditing(importDictionaryWord(entry, term));
    } catch (cause) { setMessage(cause instanceof Error ? cause.message : "查询失败"); } finally { setLookupBusy(false); }
  }

  if (!loaded) return <div className={styles.loadingState}>正在打开单词库…</div>;
  if (editing) return <WordEditor initial={editing} onCancel={() => setEditing(null)} onSave={(word) => { try { saveWord(word); setEditing(null); setSelected(word); setMessage("词条已保存"); } catch (cause) { setMessage(cause instanceof Error ? cause.message : "保存失败"); } }} />;
  if (selected) return <WordDetail word={state.words.find((word) => word.id === selected.id) ?? selected} close={() => setSelected(null)} edit={() => setEditing(structuredClone(selected))} remove={() => { if (confirm(`确定删除 ${selected.text} 吗？相关学习状态和日志也会一起删除。`)) { deleteWord(selected.id); setSelected(null); } }} start={() => { const session = createSession(undefined, [selected.id]); if (session) startStudy(); else setMessage("这个单词尚未到期，暂时没有可复习卡片。"); }} />;

  return <div className={styles.page}>
    <div className={styles.pageTitle}><div><span className={styles.betaPill}>语境词库</span><h1>单词库</h1><p>多释义、多来源、固定搭配和学习状态都保存在同一个词条中。</p></div><button className={styles.primaryButton} onClick={() => setEditing(blankWord())}><FiPlus />手动添加</button></div>
    <section className={styles.lookupBar}><div><FiSearch /><input value={lookup} onChange={(event) => setLookup(event.target.value)} onKeyDown={(event) => event.key === "Enter" && void lookupWord()} placeholder="输入单词或短语，从词典补全资料" /><button onClick={() => void lookupWord()} disabled={lookupBusy}>{lookupBusy ? "正在查询…" : "查询并添加"}</button></div>{message && <p role="status">{message}</p>}</section>
    <section className={styles.libraryTools}><label><FiSearch /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="搜索单词、释义、例句、来源或标签" /></label><select value={filter} onChange={(event) => setFilter(event.target.value as Filter)} aria-label="筛选单词"><option value="all">全部状态</option><option value="new">新单词</option><option value="learning">学习中</option><option value="review">复习中</option><option value="mastered">已掌握</option><option value="lapsed">遗忘重学</option><option value="weak">薄弱词</option><option value="important">重点词</option><option value="due">今天到期</option><option value="has-example">有例句</option><option value="no-example">无例句</option><option value="has-source">有来源</option><option value="no-source">无来源</option><option value="has-collocation">有固定搭配</option><option value="no-collocation">无固定搭配</option></select><select value={tag} onChange={(event) => setTag(event.target.value as SkillTag | "all")} aria-label="四级标签"><option value="all">全部四级标签</option>{Object.entries(skillTagLabels).map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select><select value={sourceType} onChange={(event) => setSourceType(event.target.value as SourceType | "all")} aria-label="来源类型"><option value="all">全部来源</option>{Object.entries(sourceTypeLabels).map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select><select value={sort} onChange={(event) => setSort(event.target.value as Sort)} aria-label="排序"><option value="recent">最近添加</option><option value="oldest">最早添加</option><option value="due">最早到期</option><option value="lapses">遗忘次数最多</option><option value="reviews-desc">复习次数最多</option><option value="reviews-asc">复习次数最少</option><option value="alphabetical">字母顺序</option></select></section>
    <div className={styles.librarySummary}><FiFilter />当前显示 {words.length} / {state.words.length} 个词条</div>
    {words.length ? <div className={styles.wordGrid}>{words.map((word) => {
      const review = state.reviewStates[word.id]; const logs = (logsByWord.get(word.id) ?? []).slice(-10); const weak = review && isWeakWord(review, logs);
      return <article className={styles.wordCard} key={word.id} onClick={() => setSelected(word)}><div><h2>{word.text}</h2><button aria-label={word.isImportant ? "取消重点" : "标记重点"} className={word.isImportant ? styles.starred : ""} onClick={(event) => { event.stopPropagation(); toggleImportant(word.id); }}><FiStar /></button></div><p>{word.meanings[0]?.definitionZh || word.meanings[0]?.definitionEn || "等待补充释义"}</p><div className={styles.wordMeta}>{review && <span>{statusLabels[review.status]}</span>}{review && <span>{formatDueTime(review.dueAt)}</span>}{weak && <b>薄弱</b>}<span>{word.sources.length} 个来源</span></div><div className={styles.tagRow}>{word.tags.slice(0, 3).map((item) => <span key={item}>{skillTagLabels[item]}</span>)}</div><FiChevronRight className={styles.cardChevron} /></article>;
    })}</div> : <div className={styles.emptyState}><FiBookOpen /><h2>{state.words.length ? "没有符合条件的单词" : "单词库还是空的"}</h2><p>{state.words.length ? "换一个筛选条件试试。" : "输入单词从在线词典补全，或手动记录真实语境。"}</p></div>}
  </div>;
}

function WordDetail({ word, close, edit, remove, start }: { word: Word; close(): void; edit(): void; remove(): void; start(): void }) {
  const { state } = useBetaStore(); const review = state.reviewStates[word.id]; const logs = state.reviewLogs.filter((log) => log.wordId === word.id).slice(-10).reverse();
  const [speechError, setSpeechError] = useState("");
  async function play(text: string, accent: "us" | "uk") {
    setSpeechError("");
    try {
      if (text === word.text) await playWord(word, state.settings, accent);
      else await speakText(text, state.settings);
    } catch (cause) {
      setSpeechError(cause instanceof Error ? cause.message : "系统语音暂时无法播放");
    }
  }
  return <div className={styles.page}><div className={styles.detailHeader}><button className={styles.backButton} onClick={close}><FiX />关闭</button><div><button onClick={() => void play(word.text, "us")}><FiHeadphones />美式</button><button onClick={() => void play(word.text, "uk")}><FiHeadphones />英式</button><button onClick={edit}><FiEdit3 />编辑</button><button className={styles.dangerButton} onClick={remove}><FiTrash2 />删除</button></div></div>{speechError && <p className={styles.inlineError} role="alert">朗读失败：{speechError}</p>}<section className={styles.wordDetailHero}><div><span className={styles.betaPill}>词条详情</span><h1>{word.text}</h1><p>{word.phoneticUS && `US /${word.phoneticUS.replaceAll("/", "")}/`} {word.phoneticUK && `· UK /${word.phoneticUK.replaceAll("/", "")}/`}</p></div><button className={styles.primaryButton} onClick={start}>专项复习</button></section>
    <div className={styles.detailGrid}><section className={styles.panel}><h2>释义与真实语境</h2>{word.meanings.map((meaning) => <article className={styles.detailMeaning} key={meaning.id}><span>{meaning.partOfSpeech || "释义"}</span><h3>{meaning.definitionZh || "暂无中文释义"}</h3>{meaning.definitionEn && <p>{meaning.definitionEn}</p>}{meaning.examples.map((example) => <blockquote key={example.id}><b>{example.sentence}</b>{example.translation && <span>{example.translation}</span>}<button aria-label="朗读例句" onClick={() => void play(example.sentence, state.settings.preferredAccent)}><FiVolume2 /></button></blockquote>)}</article>)}</section><section className={styles.panel}><h2>学习状态</h2>{review ? <dl className={styles.dataList}><dt>当前状态</dt><dd>{statusLabels[review.status]}</dd><dt>下次复习</dt><dd>{new Date(review.dueAt).toLocaleString("zh-CN")}</dd><dt>当前间隔</dt><dd>{review.intervalMinutes} 分钟</dd><dt>连续认识</dt><dd>{review.consecutiveGoodCount}</dd><dt>总复习</dt><dd>{review.totalReviews}</dd><dt>不认识 / 模糊 / 认识</dt><dd>{review.againCount} / {review.hardCount} / {review.goodCount}</dd><dt>遗忘次数</dt><dd>{review.lapseCount}</dd></dl> : <p>等待初始化</p>}</section></div>
    <div className={styles.detailGrid}><section className={styles.panel}><h2>固定搭配</h2>{word.collocations.length ? word.collocations.map((item) => <article key={item.id} className={styles.contextItem}><b>{item.text}</b><span>{item.meaningZh}</span><p>{item.exampleSentence}</p></article>) : <p className={styles.muted}>尚未记录固定搭配</p>}</section><section className={styles.panel}><h2>来源</h2>{word.sources.length ? word.sources.map((source) => <article key={source.id} className={styles.contextItem}><b>{sourceTypeLabels[source.sourceType]} · {source.title}</b><span>{[source.examYear, source.examMonth && `${source.examMonth} 月`, source.section, source.questionNumber && `第 ${source.questionNumber} 题`].filter(Boolean).join(" · ")}</span><p>{source.originalSentence}</p></article>) : <p className={styles.muted}>尚未记录来源</p>}</section></div>
    <section className={styles.panel}><h2>最近学习记录</h2>{logs.length ? <div className={styles.logTable}>{logs.map((log) => <div key={log.id}><span>{new Date(log.reviewedAt).toLocaleString("zh-CN")}</span><b>{log.reviewMode}</b><span>{log.userAnswer || "—"}</span><span>{log.rating}</span><span>{statusLabels[log.previousStatus]} → {statusLabels[log.nextStatus]}</span></div>)}</div> : <p className={styles.muted}>还没有评分记录。浏览词条不会计入学习。</p>}</section>
  </div>;
}

function WordEditor({ initial, onCancel, onSave }: { initial: Word; onCancel(): void; onSave(word: Word): void }) {
  const [word, setWord] = useState(() => structuredClone(initial));
  const [error, setError] = useState("");
  const patch = (value: Partial<Word>) => setWord((current) => ({ ...current, ...value, updatedAt: new Date().toISOString() }));
  function save() { if (!word.text.trim()) { setError("请填写单词"); return; } if (!word.meanings.some((meaning) => meaning.definitionZh.trim() || meaning.definitionEn?.trim())) { setError("至少填写一个释义"); return; } onSave({ ...word, text: word.text.trim(), normalizedText: word.text.trim().toLowerCase().replace(/\s+/g, " ") }); }
  return <div className={styles.page}><div className={styles.detailHeader}><button className={styles.backButton} onClick={onCancel}><FiX />取消</button><button className={styles.primaryButton} onClick={save}>保存词条</button></div><div className={styles.pageTitle}><div><span className={styles.betaPill}>词条编辑</span><h1>{initial.text ? `编辑 ${initial.text}` : "添加新单词"}</h1><p>释义、语境、搭配和来源都可以独立维护。</p></div></div>{error && <p className={styles.inlineError}>{error}</p>}
    <EditorSection title="基本信息"><div className={styles.formGrid}><Field label="单词"><input value={word.text} onChange={(event) => patch({ text: event.target.value })} /></Field><Field label="英式音标"><input value={word.phoneticUK ?? ""} onChange={(event) => patch({ phoneticUK: event.target.value })} /></Field><Field label="美式音标"><input value={word.phoneticUS ?? ""} onChange={(event) => patch({ phoneticUS: event.target.value })} /></Field><Field label="英式音频地址"><input value={word.audioUK ?? ""} onChange={(event) => patch({ audioUK: event.target.value })} /></Field><Field label="美式音频地址"><input value={word.audioUS ?? ""} onChange={(event) => patch({ audioUS: event.target.value })} /></Field><Field label="笔记"><textarea value={word.note ?? ""} onChange={(event) => patch({ note: event.target.value })} /></Field></div><label className={styles.checkRow}><input type="checkbox" checked={word.isImportant} onChange={(event) => patch({ isImportant: event.target.checked })} />重点单词</label></EditorSection>
    <EditorSection title="释义与例句" action={<button onClick={() => patch({ meanings: [...word.meanings, newMeaning()] })}><FiPlus />添加释义</button>}>{word.meanings.map((meaning, index) => <MeaningEditor key={meaning.id} meaning={meaning} target={word.text} sources={word.sources} update={(next) => patch({ meanings: word.meanings.map((item) => item.id === meaning.id ? next : item) })} remove={() => word.meanings.length > 1 && patch({ meanings: word.meanings.filter((item) => item.id !== meaning.id) })} index={index} />)}</EditorSection>
    <EditorSection title="固定搭配" action={<button onClick={() => patch({ collocations: [...word.collocations, newCollocation()] })}><FiPlus />添加搭配</button>}>{word.collocations.map((item) => <CollocationEditor key={item.id} item={item} sources={word.sources} update={(next) => patch({ collocations: word.collocations.map((value) => value.id === item.id ? next : value) })} remove={() => patch({ collocations: word.collocations.filter((value) => value.id !== item.id) })} />)}{!word.collocations.length && <p className={styles.muted}>可单独记录 contribute to、be responsible for 等搭配。</p>}</EditorSection>
    <EditorSection title="来源" action={<button onClick={() => patch({ sources: [...word.sources, newSource()] })}><FiPlus />添加来源</button>}>{word.sources.map((source) => <SourceEditor key={source.id} source={source} update={(next) => patch({ sources: word.sources.map((value) => value.id === source.id ? next : value) })} remove={() => patch({ sources: word.sources.filter((value) => value.id !== source.id), meanings: word.meanings.map((meaning) => ({ ...meaning, examples: meaning.examples.map((example) => example.sourceId === source.id ? { ...example, sourceId: undefined } : example) })), collocations: word.collocations.map((item) => item.sourceId === source.id ? { ...item, sourceId: undefined } : item) })} />)}{!word.sources.length && <p className={styles.muted}>记录四级听力、阅读、写作、翻译或教材中的真实出处。</p>}</EditorSection>
    <EditorSection title="四级标签"><div className={styles.tagPicker}>{Object.entries(skillTagLabels).map(([value, label]) => <label key={value}><input type="checkbox" checked={word.tags.includes(value as SkillTag)} onChange={(event) => patch({ tags: event.target.checked ? [...word.tags, value as SkillTag] : word.tags.filter((item) => item !== value) })} />{label}</label>)}</div><Field label="自定义标签（用逗号分隔）"><input value={word.customTags.join(", ")} onChange={(event) => patch({ customTags: event.target.value.split(/[,，]/).map((item) => item.trim()).filter(Boolean) })} /></Field></EditorSection>
  </div>;
}

function newMeaning(): WordMeaning { return { id: uid("meaning"), partOfSpeech: "", definitionZh: "", definitionEn: "", acceptedAnswers: [], examples: [] }; }
function newExample(): WordExample { const now = new Date().toISOString(); return { id: uid("example"), sentence: "", translation: "", clozeSentence: "", createdAt: now, updatedAt: now }; }
function newCollocation(): Collocation { const now = new Date().toISOString(); return { id: uid("collocation"), text: "", meaningZh: "", acceptedAnswers: [], createdAt: now, updatedAt: now }; }
function newSource(): WordSource { const now = new Date().toISOString(); return { id: uid("source"), sourceType: "manual", title: "", createdAt: now, updatedAt: now }; }

function MeaningEditor({ meaning, target, sources, update, remove, index }: { meaning: WordMeaning; target: string; sources: WordSource[]; update(value: WordMeaning): void; remove(): void; index: number }) {
  const patch = (value: Partial<WordMeaning>) => update({ ...meaning, ...value });
  return <article className={styles.editorCard}><div className={styles.editorCardHeader}><b>释义 {index + 1}</b><button onClick={remove}><FiTrash2 /></button></div><div className={styles.formGrid}><Field label="词性"><input value={meaning.partOfSpeech} onChange={(event) => patch({ partOfSpeech: event.target.value })} /></Field><Field label="中文释义"><textarea value={meaning.definitionZh} onChange={(event) => patch({ definitionZh: event.target.value })} /></Field><Field label="英文释义"><textarea value={meaning.definitionEn ?? ""} onChange={(event) => patch({ definitionEn: event.target.value })} /></Field><Field label="可接受答案（逗号分隔）"><input value={meaning.acceptedAnswers.join(", ")} onChange={(event) => patch({ acceptedAnswers: event.target.value.split(/[,，]/).map((item) => item.trim()).filter(Boolean) })} /></Field></div><div className={styles.subEditorTitle}><b>例句</b><button onClick={() => patch({ examples: [...meaning.examples, newExample()] })}><FiPlus />添加例句</button></div>{meaning.examples.map((example) => <div className={styles.exampleEditor} key={example.id}><Field label="英文例句"><textarea value={example.sentence} onChange={(event) => patch({ examples: meaning.examples.map((item) => item.id === example.id ? { ...item, sentence: event.target.value, updatedAt: new Date().toISOString() } : item) })} /></Field><Field label="中文翻译"><textarea value={example.translation ?? ""} onChange={(event) => patch({ examples: meaning.examples.map((item) => item.id === example.id ? { ...item, translation: event.target.value, updatedAt: new Date().toISOString() } : item) })} /></Field><Field label="挖空句"><textarea value={example.clozeSentence ?? ""} onChange={(event) => patch({ examples: meaning.examples.map((item) => item.id === example.id ? { ...item, clozeSentence: event.target.value, updatedAt: new Date().toISOString() } : item) })} /></Field><Field label="关联来源"><select value={example.sourceId ?? ""} onChange={(event) => patch({ examples: meaning.examples.map((item) => item.id === example.id ? { ...item, sourceId: event.target.value || undefined, updatedAt: new Date().toISOString() } : item) })}><option value="">不关联</option>{sources.map((source) => <option key={source.id} value={source.id}>{source.title || sourceTypeLabels[source.sourceType]}</option>)}</select></Field><div><button onClick={() => patch({ examples: meaning.examples.map((item) => item.id === example.id ? { ...item, clozeSentence: createClozeSentence(item.sentence, target), updatedAt: new Date().toISOString() } : item) })}>根据目标单词生成挖空句</button><button className={styles.dangerText} onClick={() => patch({ examples: meaning.examples.filter((item) => item.id !== example.id) })}>删除例句</button></div></div>)}</article>;
}

function CollocationEditor({ item, sources, update, remove }: { item: Collocation; sources: WordSource[]; update(value: Collocation): void; remove(): void }) { const patch = (value: Partial<Collocation>) => update({ ...item, ...value, updatedAt: new Date().toISOString() }); return <article className={styles.editorCard}><button className={styles.deleteCorner} onClick={remove}><FiTrash2 /></button><div className={styles.formGrid}><Field label="固定搭配"><input value={item.text} onChange={(event) => patch({ text: event.target.value })} /></Field><Field label="中文含义"><input value={item.meaningZh} onChange={(event) => patch({ meaningZh: event.target.value })} /></Field><Field label="可接受答案"><input value={item.acceptedAnswers.join(", ")} onChange={(event) => patch({ acceptedAnswers: event.target.value.split(/[,，]/).map((value) => value.trim()).filter(Boolean) })} /></Field><Field label="英文例句"><textarea value={item.exampleSentence ?? ""} onChange={(event) => patch({ exampleSentence: event.target.value })} /></Field><Field label="例句翻译"><textarea value={item.exampleTranslation ?? ""} onChange={(event) => patch({ exampleTranslation: event.target.value })} /></Field><Field label="关联来源"><select value={item.sourceId ?? ""} onChange={(event) => patch({ sourceId: event.target.value || undefined })}><option value="">不关联</option>{sources.map((source) => <option key={source.id} value={source.id}>{source.title || sourceTypeLabels[source.sourceType]}</option>)}</select></Field></div></article>; }

function SourceEditor({ source, update, remove }: { source: WordSource; update(value: WordSource): void; remove(): void }) { const patch = (value: Partial<WordSource>) => update({ ...source, ...value, updatedAt: new Date().toISOString() }); return <article className={styles.editorCard}><button className={styles.deleteCorner} onClick={remove}><FiTrash2 /></button><div className={styles.formGrid}><Field label="来源类型"><select value={source.sourceType} onChange={(event) => patch({ sourceType: event.target.value as SourceType })}>{Object.entries(sourceTypeLabels).map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select></Field><Field label="标题"><input value={source.title} onChange={(event) => patch({ title: event.target.value })} /></Field><Field label="考试年份"><input type="number" value={source.examYear ?? ""} onChange={(event) => patch({ examYear: event.target.value ? Number(event.target.value) : undefined })} /></Field><Field label="考试月份"><input type="number" min="1" max="12" value={source.examMonth ?? ""} onChange={(event) => patch({ examMonth: event.target.value ? Number(event.target.value) : undefined })} /></Field><Field label="试卷编号"><input value={source.paperCode ?? ""} onChange={(event) => patch({ paperCode: event.target.value })} /></Field><Field label="Section"><input value={source.section ?? ""} onChange={(event) => patch({ section: event.target.value })} /></Field><Field label="题号"><input value={source.questionNumber ?? ""} onChange={(event) => patch({ questionNumber: event.target.value })} /></Field><Field label="原始句子"><textarea value={source.originalSentence ?? ""} onChange={(event) => patch({ originalSentence: event.target.value })} /></Field><Field label="备注"><textarea value={source.note ?? ""} onChange={(event) => patch({ note: event.target.value })} /></Field></div></article>; }

function EditorSection({ title, action, children }: { title: string; action?: React.ReactNode; children: React.ReactNode }) { return <section className={styles.editorSection}><div className={styles.panelHeading}><h2>{title}</h2>{action}</div>{children}</section>; }
function Field({ label, children }: { label: string; children: React.ReactNode }) { return <label className={styles.field}><span>{label}</span>{children}</label>; }
