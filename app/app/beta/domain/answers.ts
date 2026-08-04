import type { AnswerResult } from "./types";

export function normalizeAnswer(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/\s+/g, " ");
}

export function evaluateAnswer(userAnswer: string, answers: string[], usedHint = false): AnswerResult {
  const normalizedAnswer = normalizeAnswer(userAnswer);
  const normalizedAccepted = answers.map((answer) => ({ original: answer, normalized: normalizeAnswer(answer) }));
  const match = normalizedAccepted.find((answer) => answer.normalized === normalizedAnswer && normalizedAnswer.length > 0);
  const correct = Boolean(match);
  return {
    correct,
    normalizedAnswer,
    matchedAnswer: match?.original,
    usedHint,
    suggestedRating: correct ? (usedHint ? "hard" : "good") : normalizedAnswer ? "hard" : "again",
  };
}

export function createClozeSentence(sentence: string, target: string) {
  if (!sentence.trim() || !target.trim()) return sentence;
  const escaped = target.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const expression = new RegExp(`(?<![A-Za-z'-])${escaped}(?![A-Za-z'-])`, "gi");
  return sentence.replace(expression, "______");
}
