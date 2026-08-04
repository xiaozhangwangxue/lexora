import { createClozeSentence } from "../domain/answers";
import { createReviewState } from "../domain/scheduler";
import { defaultBetaSettings, type BetaState, type Collocation, type SkillTag, type Word, type WordExample, type WordMeaning } from "../domain/types";

type JsonRecord = Record<string, unknown>;

function record(value: unknown): JsonRecord {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as JsonRecord) : {};
}

function text(value: unknown) {
  return typeof value === "string"
    ? value.replace(/\\r\\n|\\n|\\r/g, "\n").replace(/\r\n?/g, "\n").trim()
    : "";
}

function list(value: unknown) {
  return Array.isArray(value) ? value : [];
}

function stableId(prefix: string, value: string, index = 0) {
  const slug = value.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fff]+/g, "-").replace(/^-|-$/g, "").slice(0, 54) || "item";
  return `${prefix}-${slug}-${index}`;
}

function parseExamples(entry: JsonRecord, target: string, now: string): WordExample[] {
  const examples = list(entry.examples);
  const translated = list(entry.examples_zh);
  return examples.map((raw, index) => {
    const item = record(raw);
    const sentence = text(item.sentence) || text(item.example) || text(item.text) || text(raw);
    const translation = text(item.translation_zh) || text(item.translation) || text(translated[index]);
    return {
      id: stableId("example", sentence, index),
      sentence,
      translation: translation || undefined,
      clozeSentence: sentence ? createClozeSentence(sentence, target) : undefined,
      createdAt: now,
      updatedAt: now,
    };
  }).filter((example) => example.sentence);
}

type DefinitionGroup = { partOfSpeech: string; lines: string[] };

const partOfSpeechPattern = /^(n|v|vt|vi|adj|adv|prep|pron|conj|num|art|aux|modal|int|abbr)\.?\s+(.*)$/i;

function definitionGroups(value: string, fallbackPartOfSpeech: string): DefinitionGroup[] {
  const groups = new Map<string, DefinitionGroup>();
  const order: string[] = [];
  const fallback = fallbackPartOfSpeech.replace(/\.$/, "").trim().toLowerCase();
  for (const rawLine of value.split("\n")) {
    const line = rawLine.trim();
    if (!line) continue;
    const match = line.match(partOfSpeechPattern);
    const bracket = line.match(/^(\[[^\]]+\])\s*(.*)$/);
    const partOfSpeech = match?.[1]?.toLowerCase() || bracket?.[1] || fallback || "释义";
    const content = (match?.[2] || (bracket ? `${bracket[1]} ${bracket[2]}` : line)).trim();
    if (!content) continue;
    if (!groups.has(partOfSpeech)) {
      groups.set(partOfSpeech, { partOfSpeech, lines: [] });
      order.push(partOfSpeech);
    }
    groups.get(partOfSpeech)!.lines.push(content);
  }
  return order.map((key) => groups.get(key)!);
}

function pairedDefinitions(definitionEn: string, definitionZh: string, fallbackPartOfSpeech: string) {
  const english = definitionGroups(definitionEn, fallbackPartOfSpeech);
  const chinese = definitionGroups(definitionZh, fallbackPartOfSpeech);
  const englishByPart = new Map(english.map((group) => [group.partOfSpeech, group]));
  const chineseByPart = new Map(chinese.map((group) => [group.partOfSpeech, group]));
  const keys = [...new Set([...english.map((group) => group.partOfSpeech), ...chinese.map((group) => group.partOfSpeech)])];
  if (!keys.length) return [{ partOfSpeech: fallbackPartOfSpeech || "释义", definitionEn: "", definitionZh: "" }];
  return keys.map((partOfSpeech) => ({
    partOfSpeech,
    definitionEn: englishByPart.get(partOfSpeech)?.lines.join("\n") ?? "",
    definitionZh: chineseByPart.get(partOfSpeech)?.lines.join("\n") ?? "",
  }));
}

function parseMeanings(entry: JsonRecord, target: string, now: string): WordMeaning[] {
  const rawSenses = list(entry.display_senses).length ? list(entry.display_senses) : list(entry.senses);
  const meanings: WordMeaning[] = [];
  rawSenses.forEach((rawSense, senseIndex) => {
    const sense = record(rawSense);
    const partOfSpeech = text(sense.part_of_speech) || text(sense.partOfSpeech) || text(sense.pos) || text(entry.pos);
    const definitions = list(sense.definitions).length ? list(sense.definitions) : [sense];
    definitions.forEach((rawDefinition, definitionIndex) => {
      const definition = record(rawDefinition);
      const definitionZh = text(definition.definition_zh) || text(definition.definitionZh) || text(definition.meaning_zh) || text(definition.translation) || text(sense.definition_zh);
      const definitionEn = text(definition.definition) || text(definition.definition_en) || text(definition.meaning) || text(sense.definition);
      if (!definitionZh && !definitionEn) return;
      pairedDefinitions(definitionEn, definitionZh, partOfSpeech).forEach((pair, pairIndex) => meanings.push({
        id: stableId("meaning", `${pair.partOfSpeech}-${pair.definitionZh || pair.definitionEn}`, senseIndex * 1000 + definitionIndex * 100 + pairIndex),
        partOfSpeech: pair.partOfSpeech,
        definitionZh: pair.definitionZh,
        definitionEn: pair.definitionEn || undefined,
        acceptedAnswers: [],
        examples: pairIndex === 0 ? parseExamples(definition, target, now) : [],
      }));
    });
  });
  if (!meanings.length) {
    const definitionZh = text(entry.definition_zh) || text(entry.meaning_zh);
    const definitionEn = text(entry.definition) || text(entry.meaning);
    pairedDefinitions(definitionEn, definitionZh, text(entry.pos)).forEach((pair, index) => meanings.push({
      id: stableId("meaning", pair.definitionZh || pair.definitionEn || target, index),
      partOfSpeech: pair.partOfSpeech,
      definitionZh: pair.definitionZh,
      definitionEn: pair.definitionEn || undefined,
      acceptedAnswers: [],
      examples: index === 0 ? parseExamples(entry, target, now) : [],
    }));
  } else {
    const rootExamples = parseExamples(entry, target, now);
    if (rootExamples.length && !meanings.some((meaning) => meaning.examples.length)) meanings[0].examples = rootExamples;
  }
  return meanings;
}

function parseCollocations(entry: JsonRecord, now: string): Collocation[] {
  const raw = list(entry.phrase_entries).length ? list(entry.phrase_entries) : list(entry.phrases);
  return raw.map((value, index) => {
    const item = record(value);
    const collocation = text(item.phrase) || text(item.text) || text(value);
    const meaningZh = text(item.meaning_zh) || text(item.translation_zh) || text(item.meaningZh);
    return {
      id: stableId("collocation", collocation, index),
      text: collocation,
      meaningZh,
      acceptedAnswers: [],
      exampleSentence: text(item.example_sentence) || text(item.exampleSentence) || undefined,
      exampleTranslation: text(item.example_translation) || text(item.exampleTranslation) || undefined,
      createdAt: now,
      updatedAt: now,
    };
  }).filter((item) => item.text);
}

export function dictionaryEntryToWord(raw: unknown, fallbackText: string, now = new Date()): Word {
  const entry = record(raw);
  const timestamp = now.toISOString();
  const displayText = text(entry.word) || fallbackText.trim();
  const normalizedText = displayText.trim().toLowerCase().replace(/\s+/g, " ");
  const collocations = parseCollocations(entry, timestamp);
  const tags: SkillTag[] = [];
  if (collocations.length) tags.push("collocation");
  if (Number(entry.frequency ?? 0) >= 500) tags.push("high-frequency");
  return {
    id: stableId("word", normalizedText),
    text: displayText,
    normalizedText,
    phoneticUK: text(entry.uk_phonetic) || text(entry.phoneticUK) || undefined,
    phoneticUS: text(entry.us_phonetic) || text(entry.phoneticUS) || undefined,
    meanings: parseMeanings(entry, displayText, timestamp),
    collocations,
    sources: [],
    tags,
    customTags: [],
    note: undefined,
    isImportant: false,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

function migrateLegacyWords(legacy: JsonRecord, now: Date) {
  const searches = list(legacy.searches).map(record);
  const searchByTerm = new Map<string, JsonRecord>();
  searches.forEach((search) => {
    const entry = record(search.entry);
    [text(search.query), text(search.resolvedWord), text(entry.word)].filter(Boolean).forEach((term) => searchByTerm.set(term.toLowerCase(), entry));
  });
  const seen = new Set<string>();
  return list(legacy.words).map(record).map((item) => {
    const term = text(item.term) || text(item.word);
    const normalized = term.toLowerCase().replace(/\s+/g, " ");
    if (!normalized || seen.has(normalized)) return null;
    seen.add(normalized);
    const word = dictionaryEntryToWord(searchByTerm.get(normalized) ?? {}, term, now);
    return { ...word, id: text(item.id) || word.id };
  }).filter((word): word is Word => Boolean(word));
}

export function createEmptyBetaState(now = new Date()): BetaState {
  const timestamp = now.toISOString();
  return {
    schemaVersion: 3,
    words: [],
    reviewStates: {},
    reviewLogs: [],
    sessions: [],
    settings: defaultBetaSettings(now),
    dailySummaries: {},
    migratedAt: timestamp,
    lastMigrationAt: timestamp,
  };
}

export function migrateToBetaState(betaRaw: unknown, legacyRaw: unknown, now = new Date()): BetaState {
  const existing = record(betaRaw);
  if (existing.schemaVersion === 3 && Array.isArray(existing.words)) {
    return repairBetaState(existing as BetaState);
  }
  const legacy = record(legacyRaw);
  const words = migrateLegacyWords(legacy, now);
  const state = createEmptyBetaState(now);
  state.words = words;
  state.reviewStates = Object.fromEntries(words.map((word) => [word.id, createReviewState(word.id, word.createdAt)]));
  return state;
}

function repairSourceReference<T extends { sourceId?: string }>(
  value: T,
  sourceIds: Set<string>,
): T {
  if (!value.sourceId || sourceIds.has(value.sourceId)) return value;
  const repaired = { ...value };
  delete repaired.sourceId;
  return repaired;
}

export function repairBetaState(state: BetaState): BetaState {
  const words = state.words.map((word) => {
    const sources = word.sources ?? [];
    const sourceIds = new Set(sources.map((source) => source.id));
    const meanings = (word.meanings ?? []).flatMap((meaning, meaningIndex) => {
      const pairs = pairedDefinitions(text(meaning.definitionEn), text(meaning.definitionZh), text(meaning.partOfSpeech));
      const examples = (meaning.examples ?? []).map((example) => repairSourceReference({
        ...example,
        sentence: text(example.sentence),
        translation: text(example.translation) || undefined,
      }, sourceIds)).filter((example) => example.sentence);
      return pairs.map((pair, pairIndex) => ({
        ...meaning,
        id: pairIndex === 0 ? meaning.id : stableId("meaning", `${word.normalizedText}-${pair.partOfSpeech}`, meaningIndex * 100 + pairIndex),
        partOfSpeech: pair.partOfSpeech,
        definitionEn: pair.definitionEn || undefined,
        definitionZh: pair.definitionZh,
        examples: pairIndex === 0 ? examples : [],
      }));
    });
    return {
      ...word,
      sources,
      meanings,
      collocations: (word.collocations ?? []).map((collocation) =>
        repairSourceReference(collocation, sourceIds)),
    };
  });
  const wordIds = new Set(words.map((word) => word.id));
  const reviewStates = Object.fromEntries(
    words.map((word) => [
      word.id,
      state.reviewStates[word.id] ?? createReviewState(word.id, word.createdAt),
    ]),
  );
  const sessions = state.sessions.map((session) => {
    const items = session.items.filter((item) => wordIds.has(item.wordId));
    return {
      ...session,
      items,
      currentIndex: items.length
        ? Math.min(Math.max(session.currentIndex, 0), items.length - 1)
        : 0,
    };
  });
  return {
    ...state,
    settings: {
      ...defaultBetaSettings(),
      ...state.settings,
      enabledLearningSources: state.settings.enabledLearningSources ?? ["generated", "manual"],
      selectedHistoryWordIds: state.settings.selectedHistoryWordIds ?? [],
      selectedGeneratedBookIds: state.settings.selectedGeneratedBookIds ?? [],
      installedLearningPacks: state.settings.installedLearningPacks ?? [],
    },
    words,
    reviewStates,
    reviewLogs: state.reviewLogs.filter((log) => wordIds.has(log.wordId)),
    sessions,
  };
}
