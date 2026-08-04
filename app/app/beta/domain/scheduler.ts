import type { ReviewMode, ReviewRating, ReviewState } from "./types";
import { addMinutes } from "./time";

export const TEN_MINUTES = 10;
export const ONE_DAY = 24 * 60;
export const THREE_DAYS = 3 * 24 * 60;
export const MAX_INTERVAL = 60 * 24 * 60;
export const MASTERED_INTERVAL = 21 * 24 * 60;

export type ReviewScheduleResult = ReviewState;

export function createReviewState(wordId: string, createdAt: string): ReviewState {
  return {
    wordId,
    status: "new",
    dueAt: createdAt,
    intervalMinutes: 0,
    consecutiveGoodCount: 0,
    totalReviews: 0,
    againCount: 0,
    hardCount: 0,
    goodCount: 0,
    lapseCount: 0,
    createdAt,
    updatedAt: createdAt,
  };
}

export function scheduleNextReview(
  state: ReviewState,
  rating: ReviewRating,
  reviewedAt: Date,
  reviewMode: ReviewMode = "word-to-meaning",
): ReviewScheduleResult {
  const previousStatus = state.status;
  let nextStatus = previousStatus;
  let nextInterval = state.intervalMinutes;
  let consecutiveGoodCount = state.consecutiveGoodCount;
  let lapseCount = state.lapseCount;

  if (previousStatus === "new" || previousStatus === "learning" || previousStatus === "lapsed") {
    if (rating === "again") {
      nextStatus = previousStatus === "lapsed" ? "lapsed" : "learning";
      nextInterval = TEN_MINUTES;
      consecutiveGoodCount = 0;
    } else if (rating === "hard") {
      nextStatus = previousStatus === "lapsed" ? "lapsed" : "learning";
      nextInterval = ONE_DAY;
      consecutiveGoodCount = 0;
    } else {
      nextStatus = "review";
      nextInterval = THREE_DAYS;
      consecutiveGoodCount = 1;
    }
  } else if (rating === "again") {
    nextStatus = "lapsed";
    nextInterval = TEN_MINUTES;
    consecutiveGoodCount = 0;
    lapseCount += 1;
  } else if (rating === "hard") {
    nextStatus = "review";
    nextInterval = Math.min(MAX_INTERVAL, Math.max(ONE_DAY, Math.round(state.intervalMinutes * 1.5)));
    consecutiveGoodCount = 0;
  } else {
    nextInterval = Math.min(MAX_INTERVAL, Math.max(THREE_DAYS, Math.round(state.intervalMinutes * 2.5)));
    consecutiveGoodCount += 1;
    nextStatus = consecutiveGoodCount >= 3 && nextInterval >= MASTERED_INTERVAL ? "mastered" : previousStatus === "mastered" ? "mastered" : "review";
  }

  const timestamp = reviewedAt.toISOString();
  return {
    ...state,
    status: nextStatus,
    dueAt: addMinutes(reviewedAt, nextInterval).toISOString(),
    lastReviewedAt: timestamp,
    intervalMinutes: nextInterval,
    consecutiveGoodCount,
    totalReviews: state.totalReviews + 1,
    againCount: state.againCount + (rating === "again" ? 1 : 0),
    hardCount: state.hardCount + (rating === "hard" ? 1 : 0),
    goodCount: state.goodCount + (rating === "good" ? 1 : 0),
    lapseCount,
    lastRating: rating,
    lastReviewMode: reviewMode,
    updatedAt: timestamp,
  };
}

export function previewSchedules(state: ReviewState, reviewedAt = new Date(), mode: ReviewMode = "word-to-meaning") {
  return {
    again: scheduleNextReview(state, "again", reviewedAt, mode),
    hard: scheduleNextReview(state, "hard", reviewedAt, mode),
    good: scheduleNextReview(state, "good", reviewedAt, mode),
  };
}
