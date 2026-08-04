import type { BetaSettings, ReviewMode, ReviewState, StudyMode, StudySession, StudySessionItem, Word } from "./types";
import { localDateKey } from "./time";

function hasCloze(word: Word) {
  return word.meanings.some((meaning) => meaning.examples.some((example) => Boolean(example.clozeSentence)));
}

function availableModes(word: Word, enabled: ReviewMode[]) {
  const available = enabled.filter((mode) => {
    if (mode === "cloze") return hasCloze(word);
    if (mode === "collocation") return word.collocations.length > 0;
    if (mode === "meaning-to-word") return word.meanings.some((meaning) => meaning.definitionZh.trim());
    return true;
  });
  return available.length ? available : (["word-to-meaning"] as ReviewMode[]);
}

export function selectReviewMode(word: Word, state: ReviewState, settings: BetaSettings, requested: StudyMode): ReviewMode {
  if (requested !== "mixed") {
    return availableModes(word, settings.enabledReviewModes).includes(requested) ? requested : "word-to-meaning";
  }
  if (state.status === "new" && state.totalReviews === 0) return "word-to-meaning";
  const modes = availableModes(word, settings.enabledReviewModes);
  const previousIndex = state.lastReviewMode ? modes.indexOf(state.lastReviewMode) : -1;
  return modes[(previousIndex + 1) % modes.length] ?? "word-to-meaning";
}

type BuildQueueInput = {
  words: Word[];
  reviewStates: Record<string, ReviewState>;
  settings: BetaSettings;
  session?: StudySession | null;
  now: Date;
  mode?: StudyMode;
};

function priority(state: ReviewState, now: Date) {
  if (state.status === "learning" || state.status === "lapsed") return 0;
  if (state.status === "review" || state.status === "mastered") return new Date(state.dueAt).getTime() < now.getTime() ? 1 : 2;
  return 3;
}

export function buildStudyQueue({ words, reviewStates, settings, session, now, mode = settings.defaultStudyMode }: BuildQueueInput): StudySessionItem[] {
  const wordById = new Map(words.map((word) => [word.id, word]));
  const completedKeys = new Set((session?.items ?? []).filter((item) => item.state === "completed").map((item) => item.dueKey));
  const pendingWordIds = new Set((session?.items ?? []).filter((item) => item.state !== "completed").map((item) => item.wordId));
  const due = words
    .map((word) => ({ word, state: reviewStates[word.id] }))
    .filter((item): item is { word: Word; state: ReviewState } => Boolean(item.state))
    .filter(({ state }) => state.status !== "new" && new Date(state.dueAt).getTime() <= now.getTime())
    .filter(({ word, state }) => !pendingWordIds.has(word.id) && !completedKeys.has(`${word.id}:${state.dueAt}`))
    .sort((a, b) => priority(a.state, now) - priority(b.state, now) || new Date(a.state.dueAt).getTime() - new Date(b.state.dueAt).getTime());

  const newWords = words
    .map((word) => ({ word, state: reviewStates[word.id] }))
    .filter((item): item is { word: Word; state: ReviewState } => Boolean(item.state) && item.state.status === "new")
    .filter(({ word }) => !pendingWordIds.has(word.id))
    .sort((a, b) => new Date(a.word.createdAt).getTime() - new Date(b.word.createdAt).getTime())
    .slice(0, Math.max(0, Math.min(100, settings.dailyNewWordLimit)));

  return [...due, ...newWords]
    .filter(({ word }) => wordById.has(word.id))
    .map(({ word, state }) => ({
      id: `${word.id}:${state.dueAt}:${mode}`,
      wordId: word.id,
      reviewMode: selectReviewMode(word, state, settings, mode),
      dueKey: `${word.id}:${state.dueAt}`,
      state: "pending" as const,
    }));
}

export function createStudySession(items: StudySessionItem[], now: Date, mode: StudyMode): StudySession {
  const timestamp = now.toISOString();
  return {
    id: `session-${timestamp}-${Math.random().toString(36).slice(2, 8)}`,
    localDateKey: localDateKey(now),
    status: "active",
    mode,
    items,
    currentIndex: 0,
    startedAt: timestamp,
    updatedAt: timestamp,
  };
}

export function laterDueCount(reviewStates: Record<string, ReviewState>, now: Date) {
  const today = localDateKey(now);
  const future = Object.values(reviewStates).filter((state) => {
    const due = new Date(state.dueAt);
    return due.getTime() > now.getTime() && localDateKey(due) === today;
  });
  return {
    count: future.length,
    nextDueAt: future.sort((a, b) => a.dueAt.localeCompare(b.dueAt))[0]?.dueAt,
  };
}
