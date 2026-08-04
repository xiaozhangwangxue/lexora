"use client";

import { FiArrowRight, FiBook, FiCheckCircle, FiClock, FiHeadphones, FiPenTool, FiRefreshCw, FiSun, FiTrendingUp } from "react-icons/fi";
import { buildStudyQueue, laterDueCount } from "../domain/queue";
import { calculateOverallStats, calculateStreak, calculateTodayStats, groupReviewLogsByWord } from "../domain/stats";
import { isWeakWord } from "../domain/weak";
import { useBetaStore } from "../store";
import styles from "../beta.module.css";

export function Dashboard({ openStudy, openLibrary }: { openStudy(): void; openLibrary(): void }) {
  const { state, loaded, activeSession, startStudy } = useBetaStore();
  const now = new Date();
  const queue = buildStudyQueue({ words: state.words, reviewStates: state.reviewStates, settings: state.settings, session: activeSession, now });
  const dueCount = Object.values(state.reviewStates).filter((review) => review.status !== "new" && new Date(review.dueAt) <= now).length;
  const newCount = queue.filter((item) => state.reviewStates[item.wordId]?.status === "new").length;
  const later = laterDueCount(state.reviewStates, now);
  const today = calculateTodayStats(state.reviewLogs, now);
  const overall = calculateOverallStats(state.words, state.reviewStates, state.reviewLogs);
  const streak = calculateStreak(state.dailySummaries, now);
  const logsByWord = groupReviewLogsByWord(state.reviewLogs);

  function begin(wordIds?: string[]) {
    const session = startStudy(undefined, wordIds);
    if (session) openStudy();
  }

  const weakIds = state.words.filter((word) => {
    const review = state.reviewStates[word.id];
    return review && isWeakWord(review, (logsByWord.get(word.id) ?? []).slice(-10));
  }).map((word) => word.id);

  if (!loaded) return <div className={styles.loadingState}>正在读取学习数据…</div>;
  return <div className={styles.page}>
    <div className={styles.pageTitle}><div><span className={styles.betaPill}>Lexora Beta</span><h1>今天，先把该记住的记住。</h1><p>主动回忆、真实语境和间隔重复会共同决定下一次见面。</p></div><div className={styles.dateBadge}>{new Intl.DateTimeFormat("zh-CN", { month: "long", day: "numeric", weekday: "short" }).format(now)}</div></div>

    <section className={styles.heroCard}>
      <div className={styles.heroNumbers}>
        <Metric icon={<FiRefreshCw />} label="当前待复习" value={dueCount} />
        <Metric icon={<FiBook />} label="今日新词" value={newCount} />
        <Metric icon={<FiClock />} label="稍后复习" value={later.count} />
        <Metric icon={<FiCheckCircle />} label="今日已完成" value={today.completedTaskCount} />
      </div>
      <button className={styles.studyButton} disabled={!activeSession && queue.length === 0} onClick={() => begin()}>{activeSession ? "继续今日学习" : queue.length ? "开始今日学习" : "今天的到期任务已完成"}<FiArrowRight /></button>
      {!state.words.length && <button className={styles.secondaryButton} onClick={openLibrary}>先添加第一个单词</button>}
    </section>

    <div className={styles.dashboardGrid}>
      <section className={styles.panel}><div className={styles.panelHeading}><h2>学习节奏</h2><span>来自真实评分</span></div><div className={styles.streakRow}><FiSun /><div><b>{streak} 天</b><span>连续学习</span></div><div><b>{Math.round(overall.masteryRate * 100)}%</b><span>总体掌握率</span></div><div><b>{today.reviewCount}</b><span>今日复习次数</span></div></div></section>
      <section className={styles.panel}><div className={styles.panelHeading}><h2>总体数据</h2><span>{overall.totalWords} 个单词</span></div><div className={styles.compactStats}><span><b>{overall.new}</b>尚未学习</span><span><b>{overall.learning}</b>学习中</span><span><b>{overall.review}</b>复习中</span><span><b>{overall.mastered}</b>已掌握</span><span><b>{overall.weakCount}</b>薄弱词</span></div></section>
    </div>

    <section className={styles.panel}><div className={styles.panelHeading}><h2>专项学习</h2><span>仍使用同一套复习记录</span></div><div className={styles.specialGrid}>
      <Special icon={<FiHeadphones />} label="听力" onClick={() => begin(state.words.filter((word) => word.tags.includes("listening")).map((word) => word.id))} />
      <Special icon={<FiBook />} label="阅读" onClick={() => begin(state.words.filter((word) => word.tags.includes("reading")).map((word) => word.id))} />
      <Special icon={<FiPenTool />} label="写作" onClick={() => begin(state.words.filter((word) => word.tags.includes("writing")).map((word) => word.id))} />
      <Special icon={<FiPenTool />} label="翻译" onClick={() => begin(state.words.filter((word) => word.tags.includes("translation")).map((word) => word.id))} />
      <Special icon={<FiBook />} label="固定搭配" onClick={() => begin(state.words.filter((word) => word.collocations.length > 0).map((word) => word.id))} />
      <Special icon={<FiTrendingUp />} label="薄弱词" count={weakIds.length} onClick={() => begin(weakIds)} />
    </div></section>
  </div>;
}

function Metric({ icon, label, value }: { icon: React.ReactNode; label: string; value: number }) {
  return <div className={styles.metric}>{icon}<span>{label}</span><b>{value}</b></div>;
}

function Special({ icon, label, count, onClick }: { icon: React.ReactNode; label: string; count?: number; onClick(): void }) {
  return <button className={styles.specialButton} onClick={onClick}>{icon}<span>{label}</span>{typeof count === "number" && <b>{count}</b>}<FiArrowRight /></button>;
}
