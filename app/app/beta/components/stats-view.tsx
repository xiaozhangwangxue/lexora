"use client";

import { FiActivity, FiBarChart2, FiCheckCircle, FiEdit3, FiSun, FiTarget, FiTrendingUp, FiXCircle } from "react-icons/fi";
import { calculateOverallStats, calculateStreak, calculateTodayStats } from "../domain/stats";
import { useBetaStore } from "../store";
import styles from "../beta.module.css";

export function StatsView() {
  const { state, loaded } = useBetaStore();
  if (!loaded) return <div className={styles.loadingState}>正在计算统计…</div>;
  const today = calculateTodayStats(state.reviewLogs);
  const overall = calculateOverallStats(state.words, state.reviewStates, state.reviewLogs);
  const streak = calculateStreak(state.dailySummaries);
  return <div className={styles.page}>
    <div className={styles.pageTitle}><div><span className={styles.betaPill}>真实 ReviewLog</span><h1>学习统计</h1><p>浏览和添加不会虚增数据，只有完成评分才会进入统计。</p></div></div>
    <section className={styles.statsHero}><div><FiSun /><span>连续学习</span><b>{streak} 天</b></div><div><FiTarget /><span>总体掌握率</span><b>{Math.round(overall.masteryRate * 100)}%</b></div><div><FiActivity /><span>总复习次数</span><b>{overall.totalReviews}</b></div></section>
    <div className={styles.detailGrid}><section className={styles.panel}><div className={styles.panelHeading}><h2>今日表现</h2><span>{new Date().toLocaleDateString("zh-CN")}</span></div><div className={styles.statsList}><Stat icon={<FiBarChart2 />} label="今日复习次数" value={today.reviewCount} /><Stat icon={<FiCheckCircle />} label="今日学习单词数" value={today.uniqueWordCount} /><Stat icon={<FiTrendingUp />} label="今日新学单词" value={today.newWordCount} /><Stat icon={<FiTarget />} label="回忆成功率" value={`${Math.round(today.recallSuccessRate * 100)}%`} /><Stat icon={<FiEdit3 />} label="拼写正确率" value={`${Math.round(today.spellingAccuracy * 100)}%`} /></div><div className={styles.ratingBreakdown}><span className={styles.goodDot}>认识 <b>{today.goodCount}</b></span><span className={styles.hardDot}>模糊 <b>{today.hardCount}</b></span><span className={styles.againDot}>不认识 <b>{today.againCount}</b></span></div></section>
      <section className={styles.panel}><div className={styles.panelHeading}><h2>总体词库</h2><span>{overall.totalWords} 个词</span></div><div className={styles.statsList}><Stat icon={<FiXCircle />} label="尚未学习" value={overall.new} /><Stat icon={<FiActivity />} label="学习中" value={overall.learning} /><Stat icon={<FiTrendingUp />} label="复习中" value={overall.review} /><Stat icon={<FiCheckCircle />} label="已掌握" value={overall.mastered} /><Stat icon={<FiXCircle />} label="遗忘重学" value={overall.lapsed} /></div></section></div>
    <section className={styles.panel}><div className={styles.panelHeading}><h2>需要关注</h2><span>由系统计算</span></div><div className={styles.compactStats}><span><b>{overall.weakCount}</b>薄弱词</span><span><b>{overall.importantCount}</b>重点词</span><span><b>{overall.totalLapses}</b>总遗忘次数</span><span><b>{overall.totalReviews}</b>完整学习日志</span></div></section>
  </div>;
}

function Stat({ icon, label, value }: { icon: React.ReactNode; label: string; value: string | number }) {
  return <div>{icon}<span>{label}</span><b>{value}</b></div>;
}
