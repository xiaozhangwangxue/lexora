"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { FiArrowLeft, FiEye, FiHeadphones, FiHelpCircle, FiPause, FiPlay, FiStar, FiVolume2, FiZap } from "react-icons/fi";
import { evaluateAnswer } from "../domain/answers";
import { laterDueCount } from "../domain/queue";
import { previewSchedules } from "../domain/scheduler";
import { formatInterval, localDateKey } from "../domain/time";
import { modeLabels, sourceTypeLabels, skillTagLabels, type AnswerResult, type BetaSettings, type ReviewMode, type ReviewRating, type SessionFocus, type Word } from "../domain/types";
import { playWord, speakText, stopSpeech } from "../services/speech";
import { useBetaStore } from "../store";
import styles from "../beta.module.css";

function answersFor(word: Word, mode: ReviewMode) {
  if (mode === "meaning-to-word" || mode === "spelling" || mode === "cloze") return [word.text, ...word.meanings.flatMap((meaning) => meaning.acceptedAnswers)];
  if (mode === "collocation") return word.collocations.flatMap((collocation) => [collocation.text, ...collocation.acceptedAnswers]);
  return [];
}

function promptFor(word: Word, mode: ReviewMode) {
  const firstMeaning = word.meanings[0];
  const example = word.meanings.flatMap((meaning) => meaning.examples).find((item) => item.clozeSentence);
  const collocation = word.collocations[0];
  if (mode === "meaning-to-word") return { eyebrow: "中译英", title: firstMeaning?.definitionZh || "根据释义写出单词", detail: firstMeaning?.partOfSpeech };
  if (mode === "spelling") return { eyebrow: "拼写测试", title: "听发音，写出完整单词", detail: `${word.text.length} 个字母` };
  if (mode === "cloze") return { eyebrow: "例句填空", title: example?.clozeSentence || word.text, detail: example?.translation };
  if (mode === "collocation") return { eyebrow: "固定搭配", title: collocation?.meaningZh || "写出对应固定搭配", detail: collocation?.exampleSentence };
  return { eyebrow: "英译中", title: word.text, detail: [word.phoneticUS && `US /${word.phoneticUS.replaceAll("/", "")}/`, word.phoneticUK && `UK /${word.phoneticUK.replaceAll("/", "")}/`].filter(Boolean).join(" · ") };
}

export function StudyView({ goHome, focus, title, openReview }: { goHome(): void; focus: SessionFocus; title: string; openReview?(): void }) {
  const { state, activeSession } = useBetaStore();
  const recentSession = useMemo(() => activeSession?.focus === focus ? activeSession : [...state.sessions].reverse().find((session) => session.localDateKey === localDateKey() && session.focus === focus) ?? null, [activeSession, focus, state.sessions]);
  const currentItem = recentSession?.items[recentSession.currentIndex];
  return <StudySessionView key={currentItem?.id ?? recentSession?.id ?? `empty-${focus}`} goHome={goHome} focus={focus} title={title} openReview={openReview} />;
}

function StudySessionView({ goHome, focus, title, openReview }: { goHome(): void; focus: SessionFocus; title: string; openReview?(): void }) {
  const { state, activeSession, startStudy, pendingEnrichmentCount, enriching, refreshEnrichment, revealItem, submitReview, refreshCompletedSession, toggleImportant } = useBetaStore();
  const recentSession = useMemo(() => activeSession?.focus === focus ? activeSession : [...state.sessions].reverse().find((session) => session.localDateKey === localDateKey() && session.focus === focus) ?? null, [activeSession, focus, state.sessions]);
  const currentItem = recentSession?.items[recentSession.currentIndex];
  const word = state.words.find((item) => item.id === currentItem?.wordId);
  const review = word ? state.reviewStates[word.id] : undefined;
  const [answer, setAnswer] = useState("");
  const [result, setResult] = useState<AnswerResult | null>(null);
  const [usedHint, setUsedHint] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [message, setMessage] = useState("");
  const cardStartedAt = useRef(Date.now());
  const saving = useRef(false);

  useEffect(() => {
    if (word && currentItem?.reviewMode === "spelling" && state.settings.autoPlayWordAudio) void play();
    return stopSpeech;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentItem?.id]);

  async function play(accent: "us" | "uk" = state.settings.preferredAccent) {
    if (!word || playing) return;
    setPlaying(true); setMessage("");
    try { await playWord(word, state.settings, accent); } catch (cause) { setMessage(cause instanceof Error ? cause.message : "发音失败"); } finally { setPlaying(false); }
  }

  function reveal() {
    if (!recentSession || !currentItem || !word || currentItem.state !== "pending") return;
    const requiresInput = currentItem.reviewMode !== "word-to-meaning";
    if (requiresInput) setResult(evaluateAnswer(answer, answersFor(word, currentItem.reviewMode), usedHint));
    revealItem(recentSession.id, currentItem.id);
    if (state.settings.autoPlayExampleAudio) {
      const example = word.meanings.flatMap((meaning) => meaning.examples)[0];
      if (example?.sentence) void speakText(example.sentence, state.settings).catch(() => setMessage("例句朗读失败，不影响继续学习"));
    }
  }

  function rate(rating: ReviewRating) {
    if (!recentSession || !currentItem || !word || currentItem.state !== "revealed" || saving.current) return;
    saving.current = true;
    try {
      submitReview({
        sessionId: recentSession.id,
        itemId: currentItem.id,
        rating,
        reviewMode: currentItem.reviewMode,
        userAnswer: answer || undefined,
        answerCorrect: result?.correct,
        usedHint,
        responseTimeMs: Date.now() - cardStartedAt.current,
      });
    } catch (cause) {
      saving.current = false;
      setMessage(cause instanceof Error ? cause.message : "评分保存失败，请重试");
    }
  }

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement;
      const typing = target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable;
      if (typing && event.key !== "Enter") return;
      if (event.key === " " && currentItem?.state === "pending") { event.preventDefault(); reveal(); }
      if (event.key.toLowerCase() === "p") void play();
      if (event.key.toLowerCase() === "s" && word) toggleImportant(word.id);
      if (event.key === "Enter" && currentItem?.state === "pending") { event.preventDefault(); reveal(); }
      if (currentItem?.state === "revealed" && ["1", "2", "3"].includes(event.key)) rate(({ "1": "again", "2": "hard", "3": "good" } as const)[event.key as "1" | "2" | "3"]);
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  });

  if (!recentSession) return <EmptyStudy goHome={goHome} focus={focus} title={title} pending={pendingEnrichmentCount} enriching={enriching} retry={() => void refreshEnrichment()} start={() => startStudy(undefined, undefined, focus)} />;
  if (recentSession.status === "completed" || !currentItem) {
    const later = laterDueCount(state.reviewStates, new Date());
    return <div className={styles.studyPage}><button className={styles.backButton} onClick={goHome}><FiArrowLeft />返回首页</button><section className={styles.completionCard}><FiPause /><span className={styles.betaPill}>{title}已完成</span><h1>这轮回忆已经结束。</h1>{later.count ? <p>今天稍后还有 {later.count} 个单词需要复习。最近一次：{later.nextDueAt ? new Date(later.nextDueAt).toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" }) : "—"}</p> : <p>今天没有更多到期任务，明天再见。</p>}<div>{focus === "new" && openReview && <button className={styles.primaryButton} onClick={openReview}>进入今日复习</button>}<button className={styles.secondaryButton} onClick={() => refreshCompletedSession(recentSession.id)}>检查新到期任务</button><button className={styles.secondaryButton} onClick={goHome}>完成</button></div></section></div>;
  }
  if (!word || !review) return <div className={styles.emptyState}><h2>当前单词不存在</h2><p>这张卡片已跳过，其他学习数据没有受到影响。</p><button onClick={goHome}>返回首页</button></div>;

  const revealed = currentItem.state === "revealed";
  const prompt = promptFor(word, currentItem.reviewMode);
  const schedules = previewSchedules(review, new Date(), currentItem.reviewMode);
  const completed = recentSession.items.filter((item) => item.state === "completed").length;
  const progress = recentSession.items.length ? completed / recentSession.items.length : 0;
  return <div className={styles.studyPage}>
    <header className={styles.studyHeader}><button className={styles.backButton} onClick={goHome}><FiArrowLeft />暂停并返回</button><div className={styles.studyProgress}><span>{completed} / {recentSession.items.length}</span><div><i style={{ width: `${progress * 100}%` }} /></div></div><span>{modeLabels[currentItem.reviewMode]}</span></header>
    <section className={`${styles.recallCard} ${revealed ? styles.revealedCard : ""}`}>
      <div className={styles.cardTop}><span className={styles.modePill}>{prompt.eyebrow}</span><div><button aria-label="播放单词发音" onClick={() => void play()} disabled={playing}>{playing ? <FiVolume2 /> : <FiPlay />}</button><button aria-label={word.isImportant ? "取消重点" : "标记重点"} className={word.isImportant ? styles.starred : ""} onClick={() => toggleImportant(word.id)}><FiStar /></button></div></div>
      <div className={styles.question}><h1>{prompt.title}</h1>{prompt.detail && <p>{prompt.detail}</p>}{currentItem.reviewMode === "spelling" && usedHint && <strong>首字母：{word.text[0]?.toUpperCase()} · {word.text.length} 个字母</strong>}</div>
      {currentItem.reviewMode !== "word-to-meaning" && !revealed && <div className={styles.answerInput}><label htmlFor="study-answer">你的答案</label><input id="study-answer" autoFocus value={answer} onChange={(event) => setAnswer(event.target.value)} placeholder="先独立回忆，再提交" /><div>{currentItem.reviewMode === "spelling" && <button onClick={() => setUsedHint(true)}><FiHelpCircle />显示首字母提示</button>}<button className={styles.primaryButton} onClick={reveal}>提交答案</button></div></div>}
      {!revealed && currentItem.reviewMode === "word-to-meaning" && <button className={styles.revealButton} onClick={reveal}><FiEye />显示答案 <kbd>Space</kbd></button>}
      {revealed && <AnswerPanel word={word} answer={answer} expected={answersFor(word, currentItem.reviewMode)[0] ?? word.text} result={result} play={play} settings={state.settings} />}
      {message && <p className={styles.inlineError} role="alert">{message}</p>}
      {revealed && <div className={styles.ratingArea}><div className={styles.ratingHelp}><b>按真实回忆情况评分</b><span>1 不认识 · 2 模糊 · 3 认识</span></div><div className={styles.ratingButtons}><RatingButton tone="again" label="不认识" interval={formatInterval(schedules.again.intervalMinutes)} onClick={() => rate("again")} /><RatingButton tone="hard" label="模糊" interval={formatInterval(schedules.hard.intervalMinutes)} onClick={() => rate("hard")} /><RatingButton tone="good" label="认识" interval={formatInterval(schedules.good.intervalMinutes)} onClick={() => rate("good")} /></div>{state.settings.showNextReviewTime && <p className={styles.nextReviewHint}>评分后将按你的选择安排到 10 分钟、1 天或更长间隔，不会立即重复出现。</p>}</div>}
    </section>
  </div>;
}

function AnswerPanel({ word, answer, expected, result, play, settings }: { word: Word; answer: string; expected: string; result: AnswerResult | null; play(accent?: "us" | "uk"): void; settings: BetaSettings }) {
  return <div className={styles.answerPanel}>
    <div className={styles.answerTitle}><div><h2>{word.text}</h2><p>{word.phoneticUS && `US /${word.phoneticUS.replaceAll("/", "")}/`} {word.phoneticUK && `· UK /${word.phoneticUK.replaceAll("/", "")}/`}</p></div><div><button onClick={() => play("us")}><FiHeadphones />美式</button><button onClick={() => play("uk")}><FiHeadphones />英式</button></div></div>
    {result && <div className={result.correct ? styles.correctAnswer : styles.incorrectAnswer}><b>{result.correct ? "回答正确" : "再看一遍正确答案"}</b><span>你的答案：{answer || "（空）"}</span><span>正确答案：{result.matchedAnswer ?? expected}</span><span>{answerDifference(answer, result.matchedAnswer ?? expected)}</span>{result.usedHint && <small>本题使用了提示，建议选择“模糊”。</small>}</div>}
    <div className={styles.meaningList}>{word.meanings.map((meaning) => <article key={meaning.id}><span>{meaning.partOfSpeech || "释义"}</span><h3>{meaning.definitionZh || "暂无中文释义"}</h3>{meaning.definitionEn && <p>{meaning.definitionEn}</p>}{meaning.examples.map((example) => <blockquote key={example.id}><b>{example.sentence}</b>{example.translation && <span>{example.translation}</span>}<button onClick={() => void speakText(example.sentence, settings).catch(() => undefined)} aria-label="朗读例句"><FiVolume2 /></button></blockquote>)}</article>)}</div>
    {word.collocations.length > 0 && <section className={styles.answerSection}><h3>固定搭配</h3>{word.collocations.map((item) => <p key={item.id}><b>{item.text}</b><span>{item.meaningZh}</span></p>)}</section>}
    {word.sources.length > 0 && <section className={styles.answerSection}><h3>真实来源</h3>{word.sources.map((source) => <p key={source.id}><b>{sourceTypeLabels[source.sourceType]} · {source.title}</b><span>{source.originalSentence}</span></p>)}</section>}
    {(word.tags.length > 0 || word.customTags.length > 0) && <div className={styles.tagRow}>{word.tags.map((tag) => <span key={tag}>{skillTagLabels[tag]}</span>)}{word.customTags.map((tag) => <span key={tag}>{tag}</span>)}</div>}
    {word.note && <p className={styles.noteBox}><b>笔记</b>{word.note}</p>}
  </div>;
}

function answerDifference(input: string, expected: string) {
  const actual = input.trim().toLowerCase().replace(/\s+/g, " ");
  const target = expected.trim().toLowerCase().replace(/\s+/g, " ");
  if (actual === target) return "答案差异：无";
  if (!actual) return "答案差异：未输入答案";
  let index = 0;
  while (index < actual.length && index < target.length && actual[index] === target[index]) index += 1;
  return `答案差异：从第 ${index + 1} 个字符开始不同（${actual} → ${target}）`;
}

function RatingButton({ tone, label, interval, onClick }: { tone: string; label: string; interval: string; onClick(): void }) {
  return <button className={styles[tone]} onClick={onClick}><b>{label}</b><span>{interval}</span></button>;
}

function EmptyStudy({ goHome, focus, title, pending, enriching, retry, start }: { goHome(): void; focus: SessionFocus; title: string; pending: number; enriching: boolean; retry(): void; start(): void }) {
  return <div className={styles.studyPage}><button className={styles.backButton} onClick={goHome}><FiArrowLeft />返回首页</button><div className={styles.emptyState}><FiZap /><h2>{pending > 0 && focus === "new" ? "正在补全学习内容" : `暂无${title}任务`}</h2><p>{pending > 0 && focus === "new" ? `有 ${pending} 个词条正在联网查找可靠的中英文释义，补全前不会进入学习。` : focus === "new" ? "已选内容中没有尚未学习的新词。" : "已学单词尚未到复习时间。"}</p>{pending > 0 && <button className={styles.secondaryButton} onClick={retry}>{enriching ? "正在联网补全…" : "重新联网补全"}</button>}<button className={styles.primaryButton} onClick={start}>{focus === "new" ? "开始今日学习" : "检查今日复习"}</button></div></div>;
}
