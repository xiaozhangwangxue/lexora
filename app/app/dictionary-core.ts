import type { DictionaryEntry } from "./types";

type UnknownRecord = Record<string, unknown>;

function record(value: unknown): UnknownRecord {
  return value && typeof value === "object" ? (value as UnknownRecord) : {};
}

function rows(value: unknown): UnknownRecord[] {
  return Array.isArray(value) ? value.map(record) : [];
}

function text(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function unique(values: string[], limit = 12) {
  return [...new Set(values.filter(Boolean))].slice(0, limit);
}

function datamuseDefinition(value: UnknownRecord) {
  const definition = (Array.isArray(value.defs) ? value.defs : [])
    .map(text)
    .find(Boolean);
  return definition?.replace(/^[a-z]+\s*[\t.]\s*/i, "") ?? "";
}

function datamuseFrequency(value: UnknownRecord) {
  const tag = (Array.isArray(value.tags) ? value.tags : [])
    .map(text)
    .find((item) => item.startsWith("f:"));
  const frequency = Number(tag?.slice(2));
  return Number.isFinite(frequency) ? frequency : undefined;
}

/** Convert the lightweight edge response into the same shape as the open lexicon. */
export function coreDictionaryEntry(
  payload: unknown,
  requestedTerm: string,
): DictionaryEntry | null {
  const source = record(payload);
  const dictionary = rows(source.dictionary)[0] ?? {};
  const exactRows = rows(source.exact);
  const normalized = requestedTerm.trim().toLowerCase();
  const exact =
    exactRows.find((item) => text(item.word).toLowerCase() === normalized) ??
    exactRows[0] ??
    {};
  const meanings = rows(dictionary.meanings);
  const senses = meanings
    .map((meaning) => {
      const definitions = rows(meaning.definitions)
        .map((item) => text(item.definition))
        .filter(Boolean)
        .slice(0, 3);
      return {
        part_of_speech: text(meaning.partOfSpeech),
        definitions,
        definitions_zh: [],
      };
    })
    .filter((sense) => sense.definitions.length > 0);
  const fallbackDefinition = datamuseDefinition(exact);
  if (senses.length === 0 && fallbackDefinition) {
    senses.push({
      part_of_speech: "definition",
      definitions: [fallbackDefinition],
      definitions_zh: [],
    });
  }
  const definition = senses[0]?.definitions[0] ?? fallbackDefinition;
  if (!definition) return null;

  const phonetics = rows(dictionary.phonetics);
  const fallbackPhonetic = text(dictionary.phonetic);
  const phoneticFor = (accent: "us" | "uk") =>
    text(
      phonetics.find((item) =>
        text(item.audio).toLowerCase().includes(`-${accent}`),
      )?.text,
    ) || fallbackPhonetic;
  const examples = unique(
    meanings.flatMap((meaning) =>
      rows(meaning.definitions).map((item) => text(item.example)),
    ),
    8,
  );

  return {
    word: text(dictionary.word) || text(exact.word) || normalized,
    normalized_word: normalized,
    requested_term: normalized,
    match_type: "exact",
    difficulty: undefined,
    frequency: datamuseFrequency(exact),
    pos: text(meanings[0]?.partOfSpeech),
    us_phonetic: phoneticFor("us"),
    uk_phonetic: phoneticFor("uk"),
    definition,
    synonyms: unique(
      meanings.flatMap((meaning) =>
        Array.isArray(meaning.synonyms) ? meaning.synonyms.map(text) : [],
      ),
    ),
    antonyms: unique(
      meanings.flatMap((meaning) =>
        Array.isArray(meaning.antonyms) ? meaning.antonyms.map(text) : [],
      ),
    ),
    examples,
    senses,
  };
}
