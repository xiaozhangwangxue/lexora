import { normalizeAnswer } from "../domain/answers";
import { buildDailySummary } from "../domain/stats";
import { createReviewState, scheduleNextReview } from "../domain/scheduler";
import { localDateKey } from "../domain/time";
import type { BetaState, ReviewLog, ReviewMode, ReviewRating, StudySession, Word } from "../domain/types";
import { createEmptyBetaState, migrateToBetaState } from "./migration";

export const BETA_STATE_KEY = "lexora-web-state-v3";
export const LEGACY_STATE_KEY = "lexora-web-state-v2";
export const BETA_RECOVERY_KEY = "lexora-web-state-v3-recovery";
export const BETA_CORRUPT_KEY = "lexora-web-state-v3-corrupt";

function parse(raw: string | null) {
  if (!raw) return null;
  return JSON.parse(raw) as unknown;
}

export function loadBetaState(storage: Storage = localStorage, now = new Date()) {
  const existingRaw = storage.getItem(BETA_STATE_KEY);
  try {
    const state = migrateToBetaState(parse(existingRaw), parse(storage.getItem(LEGACY_STATE_KEY)), now);
    if (!existingRaw) saveBetaState(state, storage);
    return state;
  } catch (error) {
    if (existingRaw) storage.setItem(BETA_CORRUPT_KEY, existingRaw);
    const recoveryRaw = storage.getItem(BETA_RECOVERY_KEY);
    if (recoveryRaw) {
      try {
        return migrateToBetaState(parse(recoveryRaw), null, now);
      } catch {
        // Preserve both snapshots and surface the original migration error.
      }
    }
    throw new Error(error instanceof Error ? `数据迁移失败：${error.message}` : "数据迁移失败");
  }
}

export function saveBetaState(state: BetaState, storage: Storage = localStorage) {
  const serialized = JSON.stringify(state);
  const previous = storage.getItem(BETA_STATE_KEY);
  if (previous && previous !== serialized) {
    try {
      const candidate = JSON.parse(previous) as Partial<BetaState>;
      if (candidate.schemaVersion === 3 && Array.isArray(candidate.words)) {
        storage.setItem(BETA_RECOVERY_KEY, previous);
      }
    } catch {
      storage.setItem(BETA_CORRUPT_KEY, previous);
    }
  }
  storage.setItem(BETA_STATE_KEY, serialized);
}

export function upsertWord(state: BetaState, word: Word) {
  const existing = state.words.find((item) => item.normalizedText === word.normalizedText && item.id !== word.id);
  if (existing) throw new Error("该单词已存在");
  const timestamp = new Date().toISOString();
  const found = state.words.some((item) => item.id === word.id);
  const words = found ? state.words.map((item) => item.id === word.id ? { ...word, updatedAt: timestamp } : item) : [...state.words, word];
  return {
    ...state,
    words,
    reviewStates: state.reviewStates[word.id] ? state.reviewStates : { ...state.reviewStates, [word.id]: createReviewState(word.id, word.createdAt) },
  };
}

export function removeWord(state: BetaState, wordId: string): BetaState {
  const reviewStates = { ...state.reviewStates };
  delete reviewStates[wordId];
  return {
    ...state,
    words: state.words.filter((word) => word.id !== wordId),
    reviewStates,
    reviewLogs: state.reviewLogs.filter((log) => log.wordId !== wordId),
    sessions: state.sessions.map((session) => ({ ...session, items: session.items.filter((item) => item.wordId !== wordId) })),
  };
}

export type ReviewSubmission = {
  sessionId: string;
  itemId: string;
  submissionId: string;
  rating: ReviewRating;
  reviewMode: ReviewMode;
  reviewedAt: Date;
  userAnswer?: string;
  answerCorrect?: boolean;
  usedHint: boolean;
  responseTimeMs?: number;
};

export function applyReviewSubmission(state: BetaState, submission: ReviewSubmission): { state: BetaState; log: ReviewLog } {
  if (state.reviewLogs.some((log) => log.submissionId === submission.submissionId)) {
    const existing = state.reviewLogs.find((log) => log.submissionId === submission.submissionId)!;
    return { state, log: existing };
  }
  const sessionIndex = state.sessions.findIndex((session) => session.id === submission.sessionId);
  if (sessionIndex < 0) throw new Error("学习会话不存在");
  const session = state.sessions[sessionIndex];
  const itemIndex = session.items.findIndex((item) => item.id === submission.itemId);
  if (itemIndex < 0) throw new Error("当前学习卡片不存在");
  const item = session.items[itemIndex];
  if (item.state === "completed") throw new Error("这张卡片已经完成");
  const word = state.words.find((candidate) => candidate.id === item.wordId);
  if (!word) throw new Error("当前单词不存在，已停止评分");
  const previous = state.reviewStates[word.id] ?? createReviewState(word.id, word.createdAt);
  const next = scheduleNextReview(previous, submission.rating, submission.reviewedAt, submission.reviewMode);
  const reviewedAt = submission.reviewedAt.toISOString();
  const log: ReviewLog = {
    id: `review-${submission.submissionId}`,
    submissionId: submission.submissionId,
    wordId: word.id,
    rating: submission.rating,
    reviewMode: submission.reviewMode,
    answerCorrect: submission.answerCorrect,
    userAnswer: submission.userAnswer,
    normalizedUserAnswer: submission.userAnswer === undefined ? undefined : normalizeAnswer(submission.userAnswer),
    usedHint: submission.usedHint,
    responseTimeMs: submission.responseTimeMs,
    previousStatus: previous.status,
    nextStatus: next.status,
    previousIntervalMinutes: previous.intervalMinutes,
    nextIntervalMinutes: next.intervalMinutes,
    previousDueAt: previous.dueAt,
    nextDueAt: next.dueAt,
    reviewedAt,
    localDateKey: localDateKey(submission.reviewedAt),
  };
  const items = session.items.map((candidate, index) => index === itemIndex ? { ...candidate, state: "completed" as const, completedAt: reviewedAt } : candidate);
  const nextPending = items.findIndex((candidate, index) => index > itemIndex && candidate.state !== "completed");
  const complete = items.every((candidate) => candidate.state === "completed");
  const nextSession: StudySession = {
    ...session,
    items,
    currentIndex: nextPending >= 0 ? nextPending : itemIndex,
    status: complete ? "completed" : "active",
    updatedAt: reviewedAt,
    completedAt: complete ? reviewedAt : undefined,
  };
  const reviewLogs = [...state.reviewLogs, log];
  const sessions = state.sessions.map((candidate, index) => index === sessionIndex ? nextSession : candidate);
  const dateKey = localDateKey(submission.reviewedAt);
  const previousSummary = state.dailySummaries[dateKey];
  const dueCompletedCount = reviewLogs.filter((candidate) => candidate.localDateKey === dateKey && candidate.previousStatus !== "new").length;
  const summary = buildDailySummary(dateKey, previousSummary?.dueCountAtDayStart ?? 0, reviewLogs, dueCompletedCount);
  return {
    state: {
      ...state,
      reviewStates: { ...state.reviewStates, [word.id]: next },
      reviewLogs,
      sessions,
      dailySummaries: { ...state.dailySummaries, [dateKey]: summary },
    },
    log,
  };
}

export function ensureTodaySummary(state: BetaState, now = new Date()) {
  const key = localDateKey(now);
  if (state.dailySummaries[key]) return state;
  const dueCount = Object.values(state.reviewStates).filter((review) => review.status !== "new" && new Date(review.dueAt).getTime() <= now.getTime()).length;
  return { ...state, dailySummaries: { ...state.dailySummaries, [key]: buildDailySummary(key, dueCount, state.reviewLogs, 0) } };
}

export function safeInitialState(now = new Date()) {
  if (typeof window === "undefined") return createEmptyBetaState(now);
  return ensureTodaySummary(loadBetaState(localStorage, now), now);
}
