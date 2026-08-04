"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { buildStudyQueue, createStudySession } from "./domain/queue";
import type { BetaSettings, BetaState, ReviewMode, ReviewRating, StudyMode, StudySession, Word } from "./domain/types";
import { createEmptyBetaState, dictionaryEntryToWord } from "./data/migration";
import { applyReviewSubmission, ensureTodaySummary, loadBetaState, removeWord, saveBetaState, upsertWord } from "./data/repository";
import { localDateKey } from "./domain/time";

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
  saveWord(word: Word): void;
  importDictionaryWord(entry: unknown, fallback: string): Word;
  deleteWord(wordId: string): void;
  toggleImportant(wordId: string): void;
  updateSettings(settings: Partial<BetaSettings>): void;
  startStudy(mode?: StudyMode, wordIds?: string[]): StudySession | null;
  revealItem(sessionId: string, itemId: string): void;
  submitReview(input: SubmitInput): void;
  refreshCompletedSession(sessionId: string): StudySession | null;
};

const BetaStore = createContext<BetaStoreValue | null>(null);

export function BetaProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState(() => createEmptyBetaState());
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState("");

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

  const saveWord = useCallback((word: Word) => commit(upsertWord(state, word)), [commit, state]);
  const deleteWord = useCallback((wordId: string) => commit(removeWord(state, wordId)), [commit, state]);
  const toggleImportant = useCallback((wordId: string) => {
    const word = state.words.find((item) => item.id === wordId);
    if (!word) return;
    commit(upsertWord(state, { ...word, isImportant: !word.isImportant }));
  }, [commit, state]);
  const updateSettings = useCallback((settings: Partial<BetaSettings>) => commit({ ...state, settings: { ...state.settings, ...settings, updatedAt: new Date().toISOString() } }), [commit, state]);
  const importDictionaryWord = useCallback((entry: unknown, fallback: string) => dictionaryEntryToWord(entry, fallback), []);

  const startStudy = useCallback((mode: StudyMode = state.settings.defaultStudyMode, wordIds?: string[]) => {
    if (!wordIds?.length && activeSession) return activeSession;
    const words = wordIds?.length ? state.words.filter((word) => wordIds.includes(word.id)) : state.words;
    const items = buildStudyQueue({ words, reviewStates: state.reviewStates, settings: state.settings, now: new Date(), mode });
    if (!items.length) return null;
    const session = createStudySession(items, new Date(), mode);
    const timestamp = new Date().toISOString();
    const previousSessions = state.sessions.map((item) => item.status === "active" ? { ...item, status: "paused" as const, updatedAt: timestamp } : item);
    commit({ ...state, sessions: [...previousSessions, session] });
    return session;
  }, [activeSession, commit, state]);

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
    const additions = buildStudyQueue({ words: state.words, reviewStates: state.reviewStates, settings: state.settings, session, now: new Date(), mode: session.mode });
    if (!additions.length) return null;
    const next = { ...session, status: "active" as const, items: [...session.items, ...additions], currentIndex: session.items.length, completedAt: undefined, updatedAt: new Date().toISOString() };
    commit({ ...state, sessions: state.sessions.map((item) => item.id === session.id ? next : item) });
    return next;
  }, [commit, state]);

  const value = useMemo<BetaStoreValue>(() => ({ state, loaded, error, activeSession, saveWord, importDictionaryWord, deleteWord, toggleImportant, updateSettings, startStudy, revealItem, submitReview, refreshCompletedSession }), [state, loaded, error, activeSession, saveWord, importDictionaryWord, deleteWord, toggleImportant, updateSettings, startStudy, revealItem, submitReview, refreshCompletedSession]);
  return <BetaStore.Provider value={value}>{children}</BetaStore.Provider>;
}

export function useBetaStore() {
  const value = useContext(BetaStore);
  if (!value) throw new Error("BetaProvider 未初始化");
  return value;
}
