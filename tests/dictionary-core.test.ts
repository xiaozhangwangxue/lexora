import assert from "node:assert/strict";
import test from "node:test";
import { coreDictionaryEntry } from "../app/app/dictionary-core.ts";

test("轻量词典结果可立即转换为网页词条", () => {
  const entry = coreDictionaryEntry(
    {
      dictionary: [
        {
          word: "word",
          phonetic: "/wɜːd/",
          phonetics: [
            { text: "/wɝd/", audio: "https://audio.example/word-us.mp3" },
          ],
          meanings: [
            {
              partOfSpeech: "noun",
              definitions: [
                {
                  definition: "A unit of language.",
                  example: "This is a word.",
                },
              ],
              synonyms: ["vocable"],
              antonyms: [],
            },
          ],
        },
      ],
      exact: [{ word: "word", tags: ["f:413.2"] }],
    },
    "word",
  );
  assert.ok(entry);
  assert.equal(entry.word, "word");
  assert.equal(entry.us_phonetic, "/wɝd/");
  assert.equal(entry.uk_phonetic, "/wɜːd/");
  assert.equal(entry.frequency, 413.2);
  assert.equal(entry.definition, "A unit of language.");
  assert.deepEqual(entry.synonyms, ["vocable"]);
  assert.deepEqual(entry.examples, ["This is a word."]);
  assert.deepEqual(entry.senses, [
    {
      part_of_speech: "noun",
      definitions: ["A unit of language."],
      definitions_zh: [],
    },
  ]);
});

test("Datamuse 精确结果可在主词典暂时失败时兜底", () => {
  const entry = coreDictionaryEntry(
    {
      dictionary: null,
      exact: [
        {
          word: "fallback",
          defs: ["n\ta reserve source used when the first choice fails"],
          tags: ["f:2.5"],
        },
      ],
    },
    "fallback",
  );
  assert.equal(entry?.definition, "a reserve source used when the first choice fails");
  assert.equal(entry?.frequency, 2.5);
});

test("没有可靠英文释义时不伪造词条", () => {
  assert.equal(coreDictionaryEntry({ dictionary: null, exact: [] }, "missing"), null);
});
