"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { buildStudyQueue, createStudySession, isStudyReady, learningSourceEnabled } from "./domain/queue";
import type { BetaSettings, BetaState, ReviewMode, ReviewRating, SessionFocus, StudyMode, StudySession, Word, WordSource } from "./domain/types";
import { createEmptyBetaState, dictionaryEntryToWord } from "./data/migration";
import { applyReviewSubmission, ensureTodaySummary, loadBetaState, removeWord, saveBetaState, upsertWord } from "./data/repository";
import { localDateKey } from "./domain/time";
import { createReviewState } from "./domain/scheduler";
import { loadLearningPack } from "./services/learning-packs";
import { clearEnrichmentCache, enrichmentCacheCount, readEnrichmentCache, writeEnrichmentCache } from "./services/enrichment-cache";

type GeneratedBookSelection = {
  id: string;
  title: string;
  words: Array<{ term: string; entry?: unknown }>;
};

type SubmitInput = {
  sessionId: string;
  itemId: string;
  rating: ReviewRating;
  reviewMode: ReviewMode;
  userAnswer?: string;
  answerCorrect?: boolean;
  usedHint: boolean;
  responseTimeMs?: number;
};

type BetaStoreValue = {
  state: BetaState;
  loaded: boolean;
  error: string;
  activeSession: StudySession | null;
  packWords: Word[];
  libraryWords: Word[];
  enriching: boolean;
  enrichmentCompleted: number;
  enrichmentTotal: number;
  pendingEnrichmentCount: number;
  enrichmentCacheEntries: number;
  saveWord(word: Word): void;
  importDictionaryWord(entry: unknown, fallback: string): Word;
  deleteWord(wordId: string): void;
  toggleImportant(wordId: string): void;
  updateSettings(settings: Partial<BetaSettings>): void;
  startStudy(mode?: StudyMode, wordIds?: string[], focus?: SessionFocus): StudySession | null;
  reloadLearningPacks(): Promise<void>;
  refreshEnrichment(): Promise<void>;
  confirmAddedTerms(wordIds: string[]): Promise<void>;
  selectGeneratedBook(book: GeneratedBookSelection, selected: boolean): void;
  clearLocalEnrichmentCache(): Promise<void>;
  revealItem(sessionId: string, itemId: string): void;
  submitReview(input: SubmitInput): void;
  refreshCompletedSession(sessionId: string): StudySession | null;
};

const BetaStore = createContext<BetaStoreValue | null>(null);

export function BetaProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState(() => createEmptyBetaState());
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState("");
  const [packWords, setPackWords] = useState<Word[]>([]);
  const [enriching, setEnriching] = useState(false);
  const [enrichmentCompleted, setEnrichmentCompleted] = useState(0);
  const [enrichmentTotal, setEnrichmentTotal] = useState(0);
  const [enrichmentCacheEntries, setEnrichmentCacheEntries] = useState(0);

  const commit = useCallback((next: BetaState) => {
    try {
      saveBetaState(next);
      setState(next);
      setError("");
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : "保存失败";
      setError(message);
      throw cause;
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function initialize() {
      await Promise.resolve();
      try {
        const next = ensureTodaySummary(loadBetaState());
        saveBetaState(next);
        if (!cancelled) setState(next);
        const cached = await enrichmentCacheCount().catch(() => 0);
        if (!cancelled) setEnrichmentCacheEntries(cached);
      } catch (cause) {
        if (!cancelled) setError(cause instanceof Error ? cause.message : "数据加载失败");
      } finally {
        if (!cancelled) setLoaded(true);
      }
    }
    void initialize();
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    const refresh = () => {
      if (document.visibilityState !== "visible") return;
      setState((current) => {
        const next = ensureTodaySummary(current);
        if (next === current) return current;
        saveBetaState(next);
        return next;
      });
    };
    document.addEventListener("visibilitychange", refresh);
    window.addEventListener("focus", refresh);
    return () => {
      document.removeEventListener("visibilitychange", refresh);
      window.removeEventListener("focus", refresh);
    };
  }, []);

  const activeSession = useMemo(() => state.sessions.find((session) => session.status === "active" && session.localDateKey === localDateKey()) ?? null, [state.sessions]);
  const libraryWords = useMemo(() => {
    const combined = [...state.words, ...packWords.filter((word) => !state.words.some((saved) => saved.normalizedText === word.normalizedText))];
    return combined.filter((word) => learningSourceEnabled(word, state.settings));
  }, [packWords, state.settings, state.words]);

  const saveWord = useCallback((word: Word) => commit(upsertWord(state, word)), [commit, state]);
  const deleteWord = useCallback((wordId: string) => commit(removeWord(state, wordId)), [commit, state]);
  const toggleImportant = useCallback((wordId: string) => {
    const word = state.words.find((item) => item.id === wordId);
    if (!word) return;
    commit(upsertWord(state, { ...word, isImportant: !word.isImportant }));
  }, [commit, state]);
  const updateSettings = useCallback((settings: Partial<BetaSettings>) => commit({ ...state, settings: { ...state.settings, ...settings, updatedAt: new Date().toISOString() } }), [commit, state]);
  const importDictionaryWord = useCallback((entry: unknown, fallback: string) => dictionaryEntryToWord(entry, fallback), []);

  const reloadLearningPacks = useCallback(async () => {
    const loadedWords: Word[] = [];
    for (const id of state.settings.installedLearningPacks) {
      const payload = await loadLearningPack(id);
      if (!payload) continue;
      const timestamp = new Date().toISOString();
      const source: WordSource = { id: `preset-${id}`, sourceType: "other", title: `预设词库:${id}`, createdAt: timestamp, updatedAt: timestamp };
      for (const entry of payload.entries) {
        const value = dictionaryEntryToWord(entry, "");
        if (!value.normalizedText || !isStudyReady(value)) continue;
        loadedWords.push({ ...value, sources: [source] });
      }
    }
    setPackWords(loadedWords);
  }, [state.settings.installedLearningPacks]);

  useEffect(() => {
    if (!loaded) return;
    const frame = window.requestAnimationFrame(() => { void reloadLearningPacks(); });
    return () => window.cancelAnimationFrame(frame);
  }, [loaded, reloadLearningPacks]);

  const confirmAddedTerms = useCallback(async (wordIds: string[]) => {
    if (enriching) return;
    const selectedIds = [...new Set(wordIds)];
    const incomplete = state.words.filter((word) => selectedIds.includes(word.id) && !isStudyReady(word));
    setEnriching(true);
    setEnrichmentCompleted(0);
    setEnrichmentTotal(incomplete.length);
    try {
      const replacements: Array<Word | null> = [];
      for (let offset = 0; offset < incomplete.length; offset += 4) {
        const batch = incomplete.slice(offset, offset + 4);
        const values = await Promise.all(batch.map(async (word) => {
          try {
            let raw = await readEnrichmentCache(word.normalizedText);
            if (!raw) {
              const response = await fetch(`/api/web/lookup?term=${encodeURIComponent(word.text)}`, { cache: "no-store", headers: { "x-lexora-device": betaDeviceId() } });
              if (!response.ok) return null;
              raw = await response.json();
              await writeEnrichmentCache(word.normalizedText, raw);
            }
            const enriched = dictionaryEntryToWord(raw, word.text);
            if (enriched.normalizedText !== word.normalizedText || !isStudyReady(enriched)) return null;
            return { ...enriched, id: word.id, sources: word.sources, tags: [...new Set([...word.tags, ...enriched.tags])], customTags: word.customTags, note: word.note, isImportant: word.isImportant, createdAt: word.createdAt };
          } catch { return null; }
          finally { setEnrichmentCompleted((value) => value + 1); }
        }));
        replacements.push(...values);
      }
      const byId = new Map(replacements.filter((word): word is Word => Boolean(word)).map((word) => [word.id, word]));
      commit({
        ...state,
        words: state.words.map((word) => byId.get(word.id) ?? word),
        settings: {
          ...state.settings,
          selectedHistoryWordIds: selectedIds,
          enabledLearningSources: [...new Set([...state.settings.enabledLearningSources.filter((source) => source !== "manual"), "historySelected"])],
          updatedAt: new Date().toISOString(),
        },
      });
      setEnrichmentCacheEntries(await enrichmentCacheCount().catch(() => enrichmentCacheEntries));
    } finally {
      setEnriching(false);
    }
  }, [commit, enriching, enrichmentCacheEntries, state]);

  const refreshEnrichment = useCallback(async () => {
    await confirmAddedTerms(state.settings.selectedHistoryWordIds);
  }, [confirmAddedTerms, state.settings.selectedHistoryWordIds]);

  const selectGeneratedBook = useCallback((book: GeneratedBookSelection, selected: boolean) => {
    const selectedIds = new Set(state.settings.selectedGeneratedBookIds);
    if (selected) selectedIds.add(book.id); else selectedIds.delete(book.id);
    let words = state.words;
    let reviewStates = state.reviewStates;
    if (selected) {
      const timestamp = new Date().toISOString();
      const source: WordSource = { id: `generated-${book.id}`, sourceType: "other", title: `词汇书生成记录:${book.id}`, note: book.title, createdAt: timestamp, updatedAt: timestamp };
      const byNormalized = new Map(words.map((word) => [word.normalizedText, word]));
      for (const item of book.words) {
        const imported = dictionaryEntryToWord(item.entry ?? {}, item.term);
        if (!imported.normalizedText) continue;
        const existing = byNormalized.get(imported.normalizedText);
        const base = existing && (isStudyReady(existing) || !isStudyReady(imported)) ? existing : { ...imported, id: existing?.id ?? imported.id, createdAt: existing?.createdAt ?? imported.createdAt };
        byNormalized.set(imported.normalizedText, { ...base, sources: [...(existing?.sources ?? []), ...(!existing?.sources.some((value) => value.id === source.id) ? [source] : [])] });
      }
      words = [...byNormalized.values()];
      reviewStates = { ...reviewStates };
      for (const word of words) reviewStates[word.id] ??= createReviewState(word.id, word.createdAt);
    }
    commit({
      ...state,
      words,
      reviewStates,
      settings: {
        ...state.settings,
        selectedGeneratedBookIds: [...selectedIds],
        enabledLearningSources: [...new Set([...state.settings.enabledLearningSources, "generated"])],
        updatedAt: new Date().toISOString(),
      },
    });
  }, [commit, state]);

  const clearLocalEnrichmentCache = useCallback(async () => {
    await clearEnrichmentCache();
    setEnrichmentCacheEntries(0);
  }, []);

  const startStudy = useCallback((mode: StudyMode = state.settings.defaultStudyMode, wordIds?: string[], focus: SessionFocus = "mixed") => {
    if (!wordIds?.length && activeSession?.focus === focus) return activeSession;
    const combined = [...state.words, ...packWords.filter((word) => !state.words.some((saved) => saved.normalizedText === word.normalizedText))];
    const words = wordIds?.length ? combined.filter((word) => wordIds.includes(word.id)) : combined;
    const reviewStates = { ...state.reviewStates };
    for (const word of words) reviewStates[word.id] ??= createReviewState(word.id, word.createdAt);
    const items = buildStudyQueue({ words, reviewStates, settings: state.settings, now: new Date(), mode, focus, forceSelected: Boolean(wordIds?.length) });
    if (!items.length) return null;
    const session = createStudySession(items, new Date(), mode, focus);
    const timestamp = new Date().toISOString();
    const previousSessions = state.sessions.map((item) => item.status === "active" ? { ...item, status: "paused" as const, updatedAt: timestamp } : item);
    const selectedIds = new Set(items.map((item) => item.wordId));
    const selectedPackWords = words.filter((word) => selectedIds.has(word.id) && !state.words.some((saved) => saved.id === word.id));
    commit({ ...state, words: [...state.words, ...selectedPackWords], reviewStates, sessions: [...previousSessions, session] });
    return session;
  }, [activeSession, commit, packWords, state]);

  const revealItem = useCallback((sessionId: string, itemId: string) => {
    const timestamp = new Date().toISOString();
    const sessions = state.sessions.map((session) => session.id !== sessionId ? session : {
      ...session,
      updatedAt: timestamp,
      items: session.items.map((item) => item.id === itemId && item.state === "pending" ? { ...item, state: "revealed" as const } : item),
    });
    commit({ ...state, sessions });
  }, [commit, state]);

  const submitReview = useCallback((input: SubmitInput) => {
    const result = applyReviewSubmission(state, {
      ...input,
      submissionId: `${input.sessionId}:${input.itemId}`,
      reviewedAt: new Date(),
    });
    commit(result.state);
  }, [commit, state]);

  const refreshCompletedSession = useCallback((sessionId: string) => {
    const session = state.sessions.find((item) => item.id === sessionId);
    if (!session) return null;
    const additions = buildStudyQueue({ words: state.words, reviewStates: state.reviewStates, settings: state.settings, session, now: new Date(), mode: session.mode, focus: session.focus ?? "mixed" });
    if (!additions.length) return null;
    const next = { ...session, status: "active" as const, items: [...session.items, ...additions], currentIndex: session.items.length, completedAt: undefined, updatedAt: new Date().toISOString() };
    commit({ ...state, sessions: state.sessions.map((item) => item.id === session.id ? next : item) });
    return next;
  }, [commit, state]);

  const value = useMemo<BetaStoreValue>(() => ({ state, loaded, error, activeSession, packWords, libraryWords, enriching, enrichmentCompleted, enrichmentTotal, pendingEnrichmentCount: state.settings.selectedHistoryWordIds.filter((id) => {
    const word = state.words.find((item) => item.id === id);
    return !word || !isStudyReady(word);
  }).length, enrichmentCacheEntries, saveWord, importDictionaryWord, deleteWord, toggleImportant, updateSettings, startStudy, reloadLearningPacks, refreshEnrichment, confirmAddedTerms, selectGeneratedBook, clearLocalEnrichmentCache, revealItem, submitReview, refreshCompletedSession }), [state, loaded, error, activeSession, packWords, libraryWords, enriching, enrichmentCompleted, enrichmentTotal, enrichmentCacheEntries, saveWord, importDictionaryWord, deleteWord, toggleImportant, updateSettings, startStudy, reloadLearningPacks, refreshEnrichment, confirmAddedTerms, selectGeneratedBook, clearLocalEnrichmentCache, revealItem, submitReview, refreshCompletedSession]);
  return <BetaStore.Provider value={value}>{children}</BetaStore.Provider>;
}

function betaDeviceId() {
  const key = "lexora-beta-device-id";
  let value = localStorage.getItem(key);
  if (!value) { value = crypto.randomUUID(); localStorage.setItem(key, value); }
  return value;
}

export function useBetaStore() {
  const value = useContext(BetaStore);
  if (!value) throw new Error("BetaProvider 未初始化");
  return value;
}
