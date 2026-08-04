export type LearningStatus = "new" | "learning" | "review" | "mastered" | "lapsed";
export type ReviewRating = "again" | "hard" | "good";
export type ReviewMode = "word-to-meaning" | "meaning-to-word" | "spelling" | "cloze" | "collocation";
export type StudyMode = "mixed" | ReviewMode;
export type SessionFocus = "mixed" | "new" | "review";
export type SourceType = "cet4-listening" | "cet4-reading" | "cet4-writing" | "cet4-translation" | "textbook" | "manual" | "other";
export type SkillTag = "listening" | "reading" | "writing" | "translation" | "high-frequency" | "collocation" | "confusing" | "familiar-word-new-meaning";

export type WordExample = {
  id: string;
  sentence: string;
  translation?: string;
  clozeSentence?: string;
  sourceId?: string;
  createdAt: string;
  updatedAt: string;
};

export type WordMeaning = {
  id: string;
  partOfSpeech: string;
  definitionZh: string;
  definitionEn?: string;
  acceptedAnswers: string[];
  examples: WordExample[];
};

export type Collocation = {
  id: string;
  text: string;
  meaningZh: string;
  acceptedAnswers: string[];
  exampleSentence?: string;
  exampleTranslation?: string;
  sourceId?: string;
  createdAt: string;
  updatedAt: string;
};

export type WordSource = {
  id: string;
  sourceType: SourceType;
  title: string;
  examYear?: number;
  examMonth?: number;
  paperCode?: string;
  section?: string;
  questionNumber?: string;
  originalSentence?: string;
  note?: string;
  createdAt: string;
  updatedAt: string;
};

export type Word = {
  id: string;
  text: string;
  normalizedText: string;
  phoneticUK?: string;
  phoneticUS?: string;
  audioUK?: string;
  audioUS?: string;
  meanings: WordMeaning[];
  collocations: Collocation[];
  sources: WordSource[];
  tags: SkillTag[];
  customTags: string[];
  note?: string;
  isImportant: boolean;
  createdAt: string;
  updatedAt: string;
};

export type ReviewState = {
  wordId: string;
  status: LearningStatus;
  dueAt: string;
  lastReviewedAt?: string;
  intervalMinutes: number;
  consecutiveGoodCount: number;
  totalReviews: number;
  againCount: number;
  hardCount: number;
  goodCount: number;
  lapseCount: number;
  lastRating?: ReviewRating;
  lastReviewMode?: ReviewMode;
  createdAt: string;
  updatedAt: string;
};

export type ReviewLog = {
  id: string;
  submissionId: string;
  wordId: string;
  rating: ReviewRating;
  reviewMode: ReviewMode;
  answerCorrect?: boolean;
  userAnswer?: string;
  normalizedUserAnswer?: string;
  usedHint: boolean;
  responseTimeMs?: number;
  previousStatus: LearningStatus;
  nextStatus: LearningStatus;
  previousIntervalMinutes: number;
  nextIntervalMinutes: number;
  previousDueAt: string;
  nextDueAt: string;
  reviewedAt: string;
  localDateKey: string;
};

export type StudySessionItemState = "pending" | "revealed" | "completed";

export type StudySessionItem = {
  id: string;
  wordId: string;
  reviewMode: ReviewMode;
  dueKey: string;
  state: StudySessionItemState;
  completedAt?: string;
};

export type StudySession = {
  id: string;
  localDateKey: string;
  status: "active" | "paused" | "completed";
  mode: StudyMode;
  focus?: SessionFocus;
  items: StudySessionItem[];
  currentIndex: number;
  startedAt: string;
  updatedAt: string;
  completedAt?: string;
};

export type BetaSettings = {
  dailyNewWordLimit: number;
  defaultStudyMode: StudyMode;
  enabledReviewModes: ReviewMode[];
  preferredAccent: "uk" | "us";
  speechRate: 0.75 | 1 | 1.25;
  autoPlayWordAudio: boolean;
  autoPlayExampleAudio: boolean;
  showNextReviewTime: boolean;
  enabledLearningSources: string[];
  selectedHistoryWordIds: string[];
  selectedGeneratedBookIds: string[];
  installedLearningPacks: string[];
  updatedAt: string;
};

export type DailyStudySummary = {
  localDateKey: string;
  dueCountAtDayStart: number;
  dueCompletedCount: number;
  reviewCount: number;
  uniqueWordCount: number;
  newWordCount: number;
  goodCount: number;
  hardCount: number;
  againCount: number;
  qualifiedStudyDay: boolean;
  updatedAt: string;
};

export type BetaState = {
  schemaVersion: 3;
  words: Word[];
  reviewStates: Record<string, ReviewState>;
  reviewLogs: ReviewLog[];
  sessions: StudySession[];
  settings: BetaSettings;
  dailySummaries: Record<string, DailyStudySummary>;
  migratedAt: string;
  lastMigrationAt: string;
};

export type AnswerResult = {
  correct: boolean;
  normalizedAnswer: string;
  matchedAnswer?: string;
  usedHint: boolean;
  suggestedRating: ReviewRating;
};

export const defaultBetaSettings = (now = new Date()): BetaSettings => ({
  dailyNewWordLimit: 20,
  defaultStudyMode: "mixed",
  enabledReviewModes: ["word-to-meaning", "meaning-to-word", "spelling", "cloze", "collocation"],
  preferredAccent: "us",
  speechRate: 1,
  autoPlayWordAudio: false,
  autoPlayExampleAudio: false,
  showNextReviewTime: true,
  enabledLearningSources: ["generated", "manual"],
  selectedHistoryWordIds: [],
  selectedGeneratedBookIds: [],
  installedLearningPacks: [],
  updatedAt: now.toISOString(),
});

export const sourceTypeLabels: Record<SourceType, string> = {
  "cet4-listening": "四级听力",
  "cet4-reading": "四级阅读",
  "cet4-writing": "四级写作",
  "cet4-translation": "四级翻译",
  textbook: "教材",
  manual: "手动添加",
  other: "其他",
};

export const skillTagLabels: Record<SkillTag, string> = {
  listening: "听力",
  reading: "阅读",
  writing: "写作",
  translation: "翻译",
  "high-frequency": "高频词",
  collocation: "固定搭配",
  confusing: "易混词",
  "familiar-word-new-meaning": "熟词生义",
};

export const statusLabels: Record<LearningStatus, string> = {
  new: "新单词",
  learning: "学习中",
  review: "复习中",
  mastered: "已掌握",
  lapsed: "遗忘重学",
};

export const modeLabels: Record<ReviewMode, string> = {
  "word-to-meaning": "英译中",
  "meaning-to-word": "中译英",
  spelling: "拼写测试",
  cloze: "例句填空",
  collocation: "固定搭配填空",
};
