export type AppTab = "search" | "book" | "records" | "history" | "settings";
export type BookFormat = "pdf" | "epub" | "docx" | "images" | "longImage";
export type PageSize = "a4" | "a5" | "b5";
export type FontPreset = "small" | "medium" | "large";
export type ExampleCount = 0 | 1 | 3;

export type DictionaryEntry = {
  word: string;
  normalized_word?: string;
  requested_term?: string;
  matched_word?: string;
  match_type?: string;
  difficulty?: string;
  frequency?: number;
  pos?: string;
  us_phonetic?: string;
  uk_phonetic?: string;
  definition?: string;
  definition_zh?: string;
  synonyms?: unknown[];
  antonyms?: unknown[];
  examples?: unknown[];
  phrases?: unknown[];
  phrase_entries?: unknown[];
  related_words?: unknown[];
  related_entries?: unknown[];
  senses?: unknown[];
  display_senses?: unknown[];
  display_related?: unknown[];
  display_synonyms?: unknown[];
  display_antonyms?: unknown[];
};

export type WordItem = {
  id: string;
  term: string;
  status: "idle" | "loading" | "ready" | "missing";
  matched?: string;
  difficulty?: string;
  frequency?: number;
};

export type GeneratedBook = {
  id: string;
  title: string;
  filename: string;
  createdAt: number;
  wordCount: number;
  previewWords: string[];
  format: BookFormat;
  mime: string;
  size: number;
};

export type SearchRecord = {
  id: string;
  query: string;
  resolvedWord: string;
  searchedAt: number;
  difficulty?: string;
  frequency?: number;
  entry: DictionaryEntry;
};

export type GeneratedWordRecord = {
  word: string;
  generationCount: number;
  firstGeneratedAt: number;
  lastGeneratedAt: number;
  difficulty?: string;
  starred: boolean;
};

export type Typography = {
  word: number;
  phonetic: number;
  definition: number;
  related: number;
  example: number;
  phrase: number;
};

export type AppSettings = {
  title: string;
  fontPreset: FontPreset;
  examples: ExampleCount;
  format: BookFormat;
  pageSize: PageSize;
  smartReorder: boolean;
  typography: Typography;
  searchScale: number;
  serverAcceleration: boolean;
  developerMode: boolean;
};

export const defaultSettings: AppSettings = {
  title: "My vocabulary book",
  fontPreset: "medium",
  examples: 1,
  format: "pdf",
  pageSize: "a4",
  smartReorder: false,
  typography: {
    word: 11,
    phonetic: 9,
    definition: 8.7,
    related: 7.2,
    example: 7.2,
    phrase: 7.2,
  },
  searchScale: 1,
  serverAcceleration: true,
  developerMode: false,
};

