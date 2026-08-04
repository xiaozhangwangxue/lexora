import type { ReviewLog, ReviewState } from "./types";

export function isWeakWord(state: ReviewState, recentLogs: ReviewLog[]) {
  const logs = [...recentLogs].sort((a, b) => b.reviewedAt.localeCompare(a.reviewedAt));
  if (logs.slice(0, 3).filter((log) => log.rating === "again").length >= 2) return true;
  if (state.lapseCount >= 3) return true;
  const spelling = logs.filter((log) => log.reviewMode === "spelling" && typeof log.answerCorrect === "boolean");
  if (spelling.slice(0, 2).length === 2 && spelling.slice(0, 2).every((log) => log.answerCorrect === false)) return true;
  if (logs.slice(0, 4).filter((log) => log.rating === "hard").length >= 3) return true;
  if (logs.some((log) => log.previousStatus === "mastered" && log.rating === "again")) return true;
  return false;
}
