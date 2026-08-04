import assert from "node:assert/strict";
import test from "node:test";
import { createClozeSentence, evaluateAnswer, normalizeAnswer } from "../app/app/beta/domain/answers.ts";
import { buildStudyQueue, createStudySession } from "../app/app/beta/domain/queue.ts";
import { MASTERED_INTERVAL, MAX_INTERVAL, ONE_DAY, TEN_MINUTES, THREE_DAYS, createReviewState, scheduleNextReview } from "../app/app/beta/domain/scheduler.ts";
import { buildDailySummary, calculateOverallStats, calculateStreak, calculateTodayStats } from "../app/app/beta/domain/stats.ts";
import { isWeakWord } from "../app/app/beta/domain/weak.ts";
import { applyReviewSubmission } from "../app/app/beta/data/repository.ts";
import { createEmptyBetaState } from "../app/app/beta/data/migration.ts";
import { defaultBetaSettings, type ReviewLog, type ReviewState, type Word } from "../app/app/beta/domain/types.ts";

const NOW = new Date("2026-08-05T10:00:00.000Z");

function state(status: ReviewState["status"] = "new", intervalMinutes = 0): ReviewState {
  return { ...createReviewState("word-1", "2026-08-01T00:00:00.000Z"), status, intervalMinutes, dueAt: "2026-08-05T09:00:00.000Z" };
}

function word(id = "word-1", createdAt = "2026-08-01T00:00:00.000Z"): Word {
  return { id, text: id.replace("word-", "word"), normalizedText: id, meanings: [{ id: `m-${id}`, partOfSpeech: "n.", definitionZh: "单词", definitionEn: "a unit of language", acceptedAnswers: [], examples: [] }], collocations: [], sources: [], tags: [], customTags: [], isImportant: false, createdAt, updatedAt: createdAt };
}

test("调度：new + again → 10 分钟后 learning", () => {
  const next = scheduleNextReview(state("new"), "again", NOW);
  assert.equal(next.status, "learning"); assert.equal(next.intervalMinutes, TEN_MINUTES); assert.equal(next.dueAt, "2026-08-05T10:10:00.000Z");
});
test("调度：new + hard → 1 天后 learning", () => { const next = scheduleNextReview(state("new"), "hard", NOW); assert.equal(next.status, "learning"); assert.equal(next.intervalMinutes, ONE_DAY); });
test("调度：new + good → 3 天后 review", () => { const next = scheduleNextReview(state("new"), "good", NOW); assert.equal(next.status, "review"); assert.equal(next.intervalMinutes, THREE_DAYS); assert.equal(next.consecutiveGoodCount, 1); });
test("调度：learning 三种评分", () => {
  assert.equal(scheduleNextReview(state("learning"), "again", NOW).intervalMinutes, TEN_MINUTES);
  assert.equal(scheduleNextReview(state("learning"), "hard", NOW).intervalMinutes, ONE_DAY);
  assert.equal(scheduleNextReview(state("learning"), "good", NOW).status, "review");
});
test("调度：lapsed 的 again 和 hard 保持 lapsed", () => { assert.equal(scheduleNextReview(state("lapsed"), "again", NOW).status, "lapsed"); assert.equal(scheduleNextReview(state("lapsed"), "hard", NOW).status, "lapsed"); });
test("调度：review + again → lapsed 且增加遗忘次数", () => { const next = scheduleNextReview(state("review", THREE_DAYS), "again", NOW); assert.equal(next.status, "lapsed"); assert.equal(next.lapseCount, 1); });
test("调度：mastered + again → lapsed", () => { assert.equal(scheduleNextReview(state("mastered", MASTERED_INTERVAL), "again", NOW).status, "lapsed"); });
test("调度：mastered + hard → review", () => { assert.equal(scheduleNextReview(state("mastered", MASTERED_INTERVAL), "hard", NOW).status, "review"); });
test("调度：review hard 为 1.5 倍并重置连续认识", () => { const next = scheduleNextReview({ ...state("review", 1000), consecutiveGoodCount: 2 }, "hard", NOW); assert.equal(next.intervalMinutes, 1500); assert.equal(next.consecutiveGoodCount, 0); });
test("调度：review good 为 2.5 倍", () => { assert.equal(scheduleNextReview(state("review", 2000), "good", NOW).intervalMinutes, 5000); });
test("调度：最大间隔不超过 60 天", () => { assert.equal(scheduleNextReview(state("review", MAX_INTERVAL), "good", NOW).intervalMinutes, MAX_INTERVAL); });
test("调度：连续 good 达标且超过 21 天进入 mastered", () => { const next = scheduleNextReview({ ...state("review", 10 * ONE_DAY), consecutiveGoodCount: 2 }, "good", NOW); assert.equal(next.status, "mastered"); assert.ok(next.intervalMinutes >= MASTERED_INTERVAL); });
test("调度：未达到连续次数不能提前 mastered", () => { const next = scheduleNextReview({ ...state("review", 10 * ONE_DAY), consecutiveGoodCount: 1 }, "good", NOW); assert.equal(next.status, "review"); });
test("调度：计数器和 reviewMode 正确更新", () => { const next = scheduleNextReview(state("new"), "good", NOW, "spelling"); assert.equal(next.totalReviews, 1); assert.equal(next.goodCount, 1); assert.equal(next.hardCount, 0); assert.equal(next.lastReviewMode, "spelling"); });

test("答案：规范化首尾空格、大小写、连续空格和弯引号", () => { assert.equal(normalizeAnswer("  Take   Part In  "), "take part in"); assert.equal(normalizeAnswer("Don’t"), "don't"); });
test("答案：acceptedAnswers 生效", () => { assert.equal(evaluateAnswer("participate in", ["take part in", "participate in"]).correct, true); });
test("答案：连字符和撇号不会被删除", () => { assert.equal(normalizeAnswer("people-to-people"), "people-to-people"); assert.equal(normalizeAnswer("don't"), "don't"); });
test("答案：空答案错误，提示会降低建议评分", () => { assert.equal(evaluateAnswer("", ["word"]).suggestedRating, "again"); assert.equal(evaluateAnswer("word", ["word"], true).suggestedRating, "hard"); });
test("答案：只挖空完整目标词形", () => { assert.equal(createClozeSentence("We address the issue, not an addressee.", "address"), "We ______ the issue, not an addressee."); });

test("队列：未来 dueAt 不进入，等于 now 会进入", () => {
  const w = word(); const settings = defaultBetaSettings(NOW);
  assert.equal(buildStudyQueue({ words: [w], reviewStates: { [w.id]: { ...state("review"), dueAt: "2026-08-05T10:01:00.000Z" } }, settings, now: NOW }).length, 0);
  assert.equal(buildStudyQueue({ words: [w], reviewStates: { [w.id]: { ...state("review"), dueAt: NOW.toISOString() } }, settings, now: NOW }).length, 1);
});
test("队列：learning 和 lapsed 排在 review 前", () => {
  const words = [word("word-r"), word("word-l"), word("word-x")];
  const reviews = { "word-r": { ...state("review"), wordId: "word-r" }, "word-l": { ...state("learning"), wordId: "word-l" }, "word-x": { ...state("lapsed"), wordId: "word-x" } };
  const result = buildStudyQueue({ words, reviewStates: reviews, settings: defaultBetaSettings(NOW), now: NOW });
  assert.deepEqual(result.map((item) => item.wordId), ["word-l", "word-x", "word-r"]);
});
test("队列：每日新词上限只限制新词", () => {
  const words = Array.from({ length: 5 }, (_, index) => word(`word-${index}`, `2026-08-0${index + 1}T00:00:00.000Z`));
  const reviews = Object.fromEntries(words.map((item, index) => [item.id, { ...state(index < 3 ? "review" : "new"), wordId: item.id }]));
  const settings = { ...defaultBetaSettings(NOW), dailyNewWordLimit: 1 };
  assert.equal(buildStudyQueue({ words, reviewStates: reviews, settings, now: NOW }).length, 4);
});
test("队列：新词上限 0 时仍保留到期任务", () => { const w = word(); assert.equal(buildStudyQueue({ words: [w], reviewStates: { [w.id]: state("review") }, settings: { ...defaultBetaSettings(NOW), dailyNewWordLimit: 0 }, now: NOW }).length, 1); });
test("队列：同一单词不重复加入已有 pending", () => { const w = word(); const reviews = { [w.id]: state("review") }; const item = buildStudyQueue({ words: [w], reviewStates: reviews, settings: defaultBetaSettings(NOW), now: NOW })[0]; const session = createStudySession([item], NOW, "mixed"); assert.equal(buildStudyQueue({ words: [w], reviewStates: reviews, settings: defaultBetaSettings(NOW), session, now: NOW }).length, 0); });
test("队列：新词按照 createdAt 排序", () => { const words = [word("word-b", "2026-08-02T00:00:00.000Z"), word("word-a", "2026-08-01T00:00:00.000Z")]; const reviews = Object.fromEntries(words.map((item) => [item.id, { ...state("new"), wordId: item.id }])); assert.deepEqual(buildStudyQueue({ words, reviewStates: reviews, settings: defaultBetaSettings(NOW), now: NOW }).map((item) => item.wordId), ["word-a", "word-b"]); });
test("队列：缺失 ReviewState 的单词不会导致崩溃", () => { assert.deepEqual(buildStudyQueue({ words: [word()], reviewStates: {}, settings: defaultBetaSettings(NOW), now: NOW }), []); });

function log(rating: ReviewLog["rating"], overrides: Partial<ReviewLog> = {}): ReviewLog {
  return { id: Math.random().toString(), submissionId: Math.random().toString(), wordId: "word-1", rating, reviewMode: "word-to-meaning", usedHint: false, previousStatus: "review", nextStatus: rating === "again" ? "lapsed" : "review", previousIntervalMinutes: 10, nextIntervalMinutes: 20, previousDueAt: NOW.toISOString(), nextDueAt: NOW.toISOString(), reviewedAt: NOW.toISOString(), localDateKey: "2026-08-05", ...overrides };
}
test("薄弱词：最近 3 次有 2 次 again", () => { assert.equal(isWeakWord(state("review"), [log("again"), log("good"), log("again")]), true); });
test("薄弱词：lapseCount >= 3", () => { assert.equal(isWeakWord({ ...state("review"), lapseCount: 3 }, []), true); });
test("薄弱词：连续两次拼写错误", () => { assert.equal(isWeakWord(state("review"), [log("hard", { reviewMode: "spelling", answerCorrect: false }), log("hard", { reviewMode: "spelling", answerCorrect: false })]), true); });
test("薄弱词：最近 4 次有 3 次 hard", () => { assert.equal(isWeakWord(state("review"), [log("hard"), log("hard"), log("good"), log("hard")]), true); });
test("薄弱词：mastered 后 again", () => { assert.equal(isWeakWord(state("lapsed"), [log("again", { previousStatus: "mastered" })]), true); });
test("薄弱词与用户重点标记彼此独立", () => { assert.equal(isWeakWord(state("review"), [log("good"), log("good")]), false); assert.equal(isWeakWord(state("review"), []), false); });

test("统计：掌握率分母为已开始学习单词，无已学习时为 0", () => {
  const words = [word("word-1"), word("word-2")];
  assert.equal(calculateOverallStats(words, { "word-1": state("mastered"), "word-2": { ...state("new"), wordId: "word-2" } }, []).masteryRate, 1);
  assert.equal(calculateOverallStats([words[1]], { "word-2": { ...state("new"), wordId: "word-2" } }, []).masteryRate, 0);
});
test("统计：今日只使用本地日期日志并正确计算成功率", () => { const stats = calculateTodayStats([log("good"), log("hard"), log("good", { localDateKey: "2026-08-04" })], new Date(2026, 7, 5, 12)); assert.equal(stats.reviewCount, 2); assert.equal(stats.recallSuccessRate, .5); });
test("统计：拼写正确率只统计拼写模式", () => { const stats = calculateTodayStats([log("good", { reviewMode: "spelling", answerCorrect: true }), log("good", { reviewMode: "spelling", answerCorrect: false }), log("good", { reviewMode: "cloze", answerCorrect: true })], new Date(2026, 7, 5, 12)); assert.equal(stats.spellingAccuracy, .5); });
test("统计：仅打开应用不会形成有效学习日", () => { assert.equal(buildDailySummary("2026-08-05", 0, [], 0).qualifiedStudyDay, false); });
test("统计：10 次复习或完成 1-9 个到期任务形成有效学习日", () => { assert.equal(buildDailySummary("2026-08-05", 0, Array.from({ length: 10 }, () => log("good")), 0).qualifiedStudyDay, true); assert.equal(buildDailySummary("2026-08-05", 3, [log("good")], 3).qualifiedStudyDay, true); });
test("统计：连续学习天数按本地日期连续", () => { const summaries = { "2026-08-03": buildDailySummary("2026-08-03", 0, Array.from({ length: 10 }, () => log("good", { localDateKey: "2026-08-03" })), 0), "2026-08-04": buildDailySummary("2026-08-04", 0, Array.from({ length: 10 }, () => log("good", { localDateKey: "2026-08-04" })), 0) }; assert.equal(calculateStreak(summaries, new Date(2026, 7, 5, 12)), 2); });

test("评分写入：ReviewState、ReviewLog 和 SessionItem 在同一状态提交", () => {
  const w = word(); const initial = createEmptyBetaState(NOW); initial.words = [w]; initial.reviewStates[w.id] = createReviewState(w.id, w.createdAt); const item = buildStudyQueue({ words: [w], reviewStates: initial.reviewStates, settings: initial.settings, now: NOW })[0]; const session = createStudySession([{ ...item, state: "revealed" }], NOW, "mixed"); initial.sessions = [session];
  const result = applyReviewSubmission(initial, { sessionId: session.id, itemId: item.id, submissionId: "submission-1", rating: "again", reviewMode: item.reviewMode, reviewedAt: NOW, usedHint: false });
  assert.equal(result.state.reviewStates[w.id].status, "learning"); assert.equal(result.state.reviewLogs.length, 1); assert.equal(result.state.sessions[0].items[0].state, "completed");
  const duplicate = applyReviewSubmission(result.state, { sessionId: session.id, itemId: item.id, submissionId: "submission-1", rating: "again", reviewMode: item.reviewMode, reviewedAt: NOW, usedHint: false });
  assert.equal(duplicate.state.reviewLogs.length, 1);
});
