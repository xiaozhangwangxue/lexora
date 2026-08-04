import '../models/learning_models.dart';

class AnswerEvaluation {
  const AnswerEvaluation({
    required this.correct,
    required this.normalizedAnswer,
    required this.usedHint,
    required this.suggestedRating,
  });

  final bool correct;
  final String normalizedAnswer;
  final bool usedHint;
  final ReviewRating suggestedRating;
}

String normalizeAnswer(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[‘’]'), "'")
    .replaceAll(RegExp('[“”]'), '"')
    .replaceAll(RegExp(r'\s+'), ' ');

AnswerEvaluation evaluateAnswer({
  required String input,
  required String expected,
  List<String> acceptedAnswers = const [],
  bool usedHint = false,
}) {
  final normalized = normalizeAnswer(input);
  final candidates = [
    expected,
    ...acceptedAnswers,
  ].map(normalizeAnswer).where((value) => value.isNotEmpty).toSet();
  final correct = normalized.isNotEmpty && candidates.contains(normalized);
  return AnswerEvaluation(
    correct: correct,
    normalizedAnswer: normalized,
    usedHint: usedHint,
    suggestedRating: correct
        ? usedHint
              ? ReviewRating.hard
              : ReviewRating.good
        : ReviewRating.again,
  );
}

String createClozeSentence(String sentence, String target) {
  if (sentence.trim().isEmpty || target.trim().isEmpty) return sentence;
  final escaped = RegExp.escape(target.trim());
  final expression = RegExp(
    '(?<![A-Za-z0-9])$escaped(?![A-Za-z0-9])',
    caseSensitive: false,
  );
  return sentence.replaceAll(expression, '______');
}
