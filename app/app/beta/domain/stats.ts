import type { DailyStudySummary, ReviewLog, ReviewState, Word } from "./types";
import { localDateKey } from "./time";
import { isWeakWord } from "./weak";

export function groupReviewLogsByWord(logs: ReviewLog[]) {
  const grouped = new Map<string, ReviewLog[]>();
  for (const log of logs) {
    const current = grouped.get(log.wordId);
    if (current) current.push(log);
    else grouped.set(log.wordId, [log]);
  }
  return grouped;
}

export function calculateTodayStats(logs: ReviewLog[], date = new Date()) {
  const key = localDateKey(date);
  const today = logs.filter((log) => log.localDateKey === key);
  const spelling = today.filter((log) => log.reviewMode === "spelling" && typeof log.answerCorrect === "boolean");
  const unique = new Set(today.map((log) => log.wordId));
  const newWordIds = new Set(today.filter((log) => log.previousStatus === "new").map((log) => log.wordId));
  const goodCount = today.filter((log) => log.rating === "good").length;
  const hardCount = today.filter((log) => log.rating === "hard").length;
  const againCount = today.filter((log) => log.rating === "again").length;
  return {
    reviewCount: today.length,
    uniqueWordCount: unique.size,
    newWordCount: newWordIds.size,
    goodCount,
    hardCount,
    againCount,
    recallSuccessRate: today.length ? goodCount / today.length : 0,
    spellingAccuracy: spelling.length ? spelling.filter((log) => log.answerCorrect).length / spelling.length : 0,
    completedTaskCount: today.length,
  };
}

export function calculateOverallStats(words: Word[], states: Record<string, ReviewState>, logs: ReviewLog[]) {
  const counts = { new: 0, learning: 0, review: 0, mastered: 0, lapsed: 0 };
  let weakCount = 0;
  let importantCount = 0;
  let totalLapses = 0;
  const logsByWord = groupReviewLogsByWord(logs);
  for (const word of words) {
    const state = states[word.id];
    if (!state) continue;
    counts[state.status] += 1;
    totalLapses += state.lapseCount;
    if (word.isImportant) importantCount += 1;
    if (isWeakWord(state, (logsByWord.get(word.id) ?? []).slice(-10))) weakCount += 1;
  }
  const started = words.length - counts.new;
  return {
    totalWords: words.length,
    ...counts,
    weakCount,
    importantCount,
    totalReviews: logs.length,
    totalLapses,
    masteryRate: started ? counts.mastered / started : 0,
  };
}

export function buildDailySummary(
  dateKey: string,
  dueCountAtDayStart: number,
  logs: ReviewLog[],
  dueCompletedCount: number,
): DailyStudySummary {
  const dayLogs = logs.filter((log) => log.localDateKey === dateKey);
  const uniqueWordCount = new Set(dayLogs.map((log) => log.wordId)).size;
  const newWordCount = new Set(dayLogs.filter((log) => log.previousStatus === "new").map((log) => log.wordId)).size;
  const qualifiedStudyDay = dayLogs.length >= 10 || (dueCountAtDayStart >= 1 && dueCountAtDayStart <= 9 && dueCompletedCount >= dueCountAtDayStart && dayLogs.length >= 1);
  return {
    localDateKey: dateKey,
    dueCountAtDayStart,
    dueCompletedCount,
    reviewCount: dayLogs.length,
    uniqueWordCount,
    newWordCount,
    goodCount: dayLogs.filter((log) => log.rating === "good").length,
    hardCount: dayLogs.filter((log) => log.rating === "hard").length,
    againCount: dayLogs.filter((log) => log.rating === "again").length,
    qualifiedStudyDay,
    updatedAt: new Date().toISOString(),
  };
}

export function calculateStreak(summaries: Record<string, DailyStudySummary>, today = new Date()) {
  let streak = 0;
  const cursor = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  if (!summaries[localDateKey(cursor)]?.qualifiedStudyDay) cursor.setDate(cursor.getDate() - 1);
  while (summaries[localDateKey(cursor)]?.qualifiedStudyDay) {
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}
