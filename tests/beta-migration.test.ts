import assert from "node:assert/strict";
import test from "node:test";
import { dictionaryEntryToWord, migrateToBetaState, repairBetaState } from "../app/app/beta/data/migration.ts";
import { BETA_CORRUPT_KEY, BETA_RECOVERY_KEY, BETA_STATE_KEY, loadBetaState, saveBetaState } from "../app/app/beta/data/repository.ts";

const NOW = new Date("2026-08-05T10:00:00.000Z");
const legacy = {
  words: [{ id: "legacy-1", term: "Address", status: "ready" }],
  searches: [{ query: "address", resolvedWord: "address", entry: { word: "address", us_phonetic: "əˈdres", uk_phonetic: "əˈdres", definition: "A place or to deal with a problem.", definition_zh: "地址；处理，应对", pos: "n.; v.", examples: ["We must address the problem."], examples_zh: ["我们必须处理这个问题。"], phrases: [{ phrase: "address a problem", meaning_zh: "处理问题" }] } }],
};

test("迁移：旧单词、释义和例句得到保留", () => {
  const state = migrateToBetaState(null, legacy, NOW);
  assert.equal(state.words.length, 1);
  assert.equal(state.words[0].text, "address");
  assert.equal(state.words[0].meanings[0].definitionZh, "地址；处理，应对");
  assert.equal(state.words[0].meanings[0].examples[0].sentence, "We must address the problem.");
  assert.equal(state.words[0].meanings[0].examples[0].translation, "我们必须处理这个问题。");
});
test("迁移：缺失数组初始化为空并保留至少一个释义", () => { const word = dictionaryEntryToWord({}, "plain", NOW); assert.deepEqual(word.tags, []); assert.deepEqual(word.customTags, []); assert.deepEqual(word.sources, []); assert.equal(word.meanings.length, 1); });
test("迁移：旧单词 ReviewState 初始化为 new，不伪造 ReviewLog", () => { const state = migrateToBetaState(null, legacy, NOW); assert.equal(state.reviewStates["legacy-1"].status, "new"); assert.deepEqual(state.reviewLogs, []); });
test("迁移：相同旧词不会重复", () => { const state = migrateToBetaState(null, { ...legacy, words: [...legacy.words, { id: "legacy-2", term: " address " }] }, NOW); assert.equal(state.words.length, 1); });
test("迁移：重复执行 schemaVersion 3 数据保持幂等", () => { const first = migrateToBetaState(null, legacy, NOW); const second = migrateToBetaState(first, legacy, NOW); assert.deepEqual(second, first); });
test("迁移：非法单项不会导致整个迁移崩溃", () => { const state = migrateToBetaState(null, { words: [null, {}, { term: "valid" }] }, NOW); assert.equal(state.words.length, 1); assert.equal(state.words[0].text, "valid"); });
test("迁移：多释义、多搭配和音标得到结构化保存", () => { const word = dictionaryEntryToWord({ word: "expand", us_phonetic: "ɪkˈspænd", display_senses: [{ part_of_speech: "verb", definitions: [{ definition_zh: "扩大", definition: "become larger" }, { definition_zh: "展开", definition: "spread out" }] }], phrase_entries: [{ phrase: "expand into", meaning_zh: "扩展到" }] }, "expand", NOW); assert.equal(word.meanings.length, 2); assert.equal(word.collocations.length, 1); assert.equal(word.phoneticUS, "ɪkˈspænd"); });
test("迁移：词典换行按词性配对且不会把字面换行符显示给用户", () => {
  const word = dictionaryEntryToWord({
    word: "access",
    senses: [{ partOfSpeech: "n", definitions: [{
      definition: "n. the right to use something\\nn. a way of entering",
      definitionZh: "n. 使用权；通路\\nvt. 访问；存取\\n[计] 访问",
    }] }],
  }, "access", NOW);
  assert.equal(word.meanings[0].partOfSpeech, "n");
  assert.equal(word.meanings[0].definitionEn, "the right to use something\na way of entering");
  assert.equal(word.meanings[0].definitionZh, "使用权；通路");
  assert.equal(word.meanings[1].partOfSpeech, "vt");
  assert.equal(word.meanings[1].definitionZh, "访问；存取");
  assert.ok(word.meanings.every((meaning) => !meaning.definitionZh.includes("\\n") && !(meaning.definitionEn ?? "").includes("\\n")));
});
test("迁移：自动挖空只替换完整目标单词", () => { const word = dictionaryEntryToWord({ word: "address", examples: ["We address it; the addressee agrees."] }, "address", NOW); assert.equal(word.meanings[0].examples[0].clozeSentence, "We ______ it; the addressee agrees."); });
test("迁移：修复孤立状态、日志和会话项", () => {
  const state = migrateToBetaState(null, legacy, NOW);
  const repaired = repairBetaState({
    ...state,
    reviewStates: { ...state.reviewStates, missing: state.reviewStates["legacy-1"] },
    reviewLogs: [{
      id: "orphan", submissionId: "orphan", wordId: "missing", rating: "good", reviewMode: "spelling", usedHint: false,
      previousStatus: "new", nextStatus: "review", previousIntervalMinutes: 0, nextIntervalMinutes: 4320,
      previousDueAt: NOW.toISOString(), nextDueAt: NOW.toISOString(), reviewedAt: NOW.toISOString(), localDateKey: "2026-08-05",
    }],
    sessions: [{ id: "session", localDateKey: "2026-08-05", status: "active", mode: "mixed", currentIndex: 9, startedAt: NOW.toISOString(), updatedAt: NOW.toISOString(), items: [{ id: "orphan-item", wordId: "missing", reviewMode: "spelling", state: "pending", dueKey: `missing:${NOW.toISOString()}` }] }],
  });
  assert.deepEqual(Object.keys(repaired.reviewStates), ["legacy-1"]);
  assert.deepEqual(repaired.reviewLogs, []);
  assert.deepEqual(repaired.sessions[0].items, []);
  assert.equal(repaired.sessions[0].currentIndex, 0);
});

test("迁移：保留有效来源关联并清除孤立来源关联", () => {
  const state = migrateToBetaState(null, legacy, NOW);
  const word = state.words[0];
  const source = {
    id: "source-reading",
    sourceType: "cet4-reading" as const,
    title: "2026 年四级阅读",
    createdAt: NOW.toISOString(),
    updatedAt: NOW.toISOString(),
  };
  const repaired = repairBetaState({
    ...state,
    words: [{
      ...word,
      sources: [source],
      meanings: [{
        ...word.meanings[0],
        examples: [
          { id: "valid", sentence: "Valid.", sourceId: source.id, createdAt: NOW.toISOString(), updatedAt: NOW.toISOString() },
          { id: "orphan", sentence: "Orphan.", sourceId: "missing", createdAt: NOW.toISOString(), updatedAt: NOW.toISOString() },
        ],
      }],
      collocations: [{ id: "orphan-collocation", text: "address an issue", meaningZh: "处理问题", acceptedAnswers: [], sourceId: "missing", createdAt: NOW.toISOString(), updatedAt: NOW.toISOString() }],
    }],
  });
  assert.equal(repaired.words[0].meanings[0].examples[0].sourceId, source.id);
  assert.equal(repaired.words[0].meanings[0].examples[1].sourceId, undefined);
  assert.equal(repaired.words[0].collocations[0].sourceId, undefined);
});

function memoryStorage() {
  const values = new Map<string, string>();
  return {
    get length() { return values.size; },
    clear() { values.clear(); },
    getItem(key: string) { return values.get(key) ?? null; },
    key(index: number) { return [...values.keys()][index] ?? null; },
    removeItem(key: string) { values.delete(key); },
    setItem(key: string, value: string) { values.set(key, value); },
  } satisfies Storage;
}

test("持久化：保存新状态前保留上一份可恢复快照", () => {
  const storage = memoryStorage();
  const first = migrateToBetaState(null, legacy, NOW);
  const second = { ...first, updatedAt: "2026-08-05T10:01:00.000Z" };
  saveBetaState(first, storage);
  saveBetaState(second, storage);
  assert.deepEqual(
    JSON.parse(storage.getItem(BETA_RECOVERY_KEY)!),
    JSON.parse(JSON.stringify(first)),
  );
});

test("持久化：当前快照损坏时保留原文并从恢复副本读取", () => {
  const storage = memoryStorage();
  const state = migrateToBetaState(null, legacy, NOW);
  storage.setItem(BETA_RECOVERY_KEY, JSON.stringify(state));
  storage.setItem(BETA_STATE_KEY, "{broken");
  assert.deepEqual(loadBetaState(storage, NOW), JSON.parse(JSON.stringify(state)));
  assert.equal(storage.getItem(BETA_CORRUPT_KEY), "{broken");
});
