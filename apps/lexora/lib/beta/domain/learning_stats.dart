import '../models/learning_models.dart';

Map<String, List<ReviewLog>> groupReviewLogsByWord(Iterable<ReviewLog> logs) {
  final grouped = <String, List<ReviewLog>>{};
  for (final log in logs) {
    grouped.putIfAbsent(log.wordId, () => <ReviewLog>[]).add(log);
  }
  return grouped;
}

bool isWeakWord(ReviewState state, List<ReviewLog> recentLogs) {
  final logs = [...recentLogs]
    ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
  if (logs.take(3).where((log) => log.rating == ReviewRating.again).length >=
      2) {
    return true;
  }
  if (state.lapseCount >= 3) return true;
  final spelling = logs
      .where(
        (log) =>
            log.reviewMode == ReviewMode.spelling && log.answerCorrect != null,
      )
      .take(2)
      .toList();
  if (spelling.length == 2 &&
      spelling.every((log) => log.answerCorrect == false)) {
    return true;
  }
  if (logs.take(4).where((log) => log.rating == ReviewRating.hard).length >=
      3) {
    return true;
  }
  return logs.any(
    (log) =>
        log.previousStatus == LearningStatus.mastered &&
        log.rating == ReviewRating.again,
  );
}

class TodayStats {
  const TodayStats({
    required this.reviewCount,
    required this.uniqueWordCount,
    required this.newWordCount,
    required this.goodCount,
    required this.hardCount,
    required this.againCount,
    required this.recallSuccessRate,
    required this.spellingAccuracy,
  });

  final int reviewCount;
  final int uniqueWordCount;
  final int newWordCount;
  final int goodCount;
  final int hardCount;
  final int againCount;
  final double recallSuccessRate;
  final double spellingAccuracy;
}

TodayStats calculateTodayStats(List<ReviewLog> logs, DateTime date) {
  final key = localDateKey(date);
  final today = logs.where((log) => log.localDateKey == key).toList();
  final spelling = today
      .where(
        (log) =>
            log.reviewMode == ReviewMode.spelling && log.answerCorrect != null,
      )
      .toList();
  final good = today.where((log) => log.rating == ReviewRating.good).length;
  return TodayStats(
    reviewCount: today.length,
    uniqueWordCount: today.map((log) => log.wordId).toSet().length,
    newWordCount: today
        .where((log) => log.previousStatus == LearningStatus.newWord)
        .map((log) => log.wordId)
        .toSet()
        .length,
    goodCount: good,
    hardCount: today.where((log) => log.rating == ReviewRating.hard).length,
    againCount: today.where((log) => log.rating == ReviewRating.again).length,
    recallSuccessRate: today.isEmpty ? 0 : good / today.length,
    spellingAccuracy: spelling.isEmpty
        ? 0
        : spelling.where((log) => log.answerCorrect == true).length /
              spelling.length,
  );
}

DailyStudySummary buildDailySummary({
  required String dateKey,
  required int dueCountAtDayStart,
  required int dueCompletedCount,
  required List<ReviewLog> logs,
  required DateTime now,
}) {
  final dayLogs = logs.where((log) => log.localDateKey == dateKey).toList();
  final qualified =
      dayLogs.length >= 10 ||
      (dueCountAtDayStart >= 1 &&
          dueCountAtDayStart <= 9 &&
          dueCompletedCount >= dueCountAtDayStart &&
          dayLogs.isNotEmpty);
  return DailyStudySummary(
    localDateKey: dateKey,
    dueCountAtDayStart: dueCountAtDayStart,
    dueCompletedCount: dueCompletedCount,
    reviewCount: dayLogs.length,
    uniqueWordCount: dayLogs.map((log) => log.wordId).toSet().length,
    newWordCount: dayLogs
        .where((log) => log.previousStatus == LearningStatus.newWord)
        .map((log) => log.wordId)
        .toSet()
        .length,
    goodCount: dayLogs.where((log) => log.rating == ReviewRating.good).length,
    hardCount: dayLogs.where((log) => log.rating == ReviewRating.hard).length,
    againCount: dayLogs.where((log) => log.rating == ReviewRating.again).length,
    qualifiedStudyDay: qualified,
    updatedAt: now,
  );
}

int calculateStreak(Map<String, DailyStudySummary> summaries, DateTime today) {
  var cursor = DateTime(today.year, today.month, today.day);
  if (summaries[localDateKey(cursor)]?.qualifiedStudyDay != true) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (summaries[localDateKey(cursor)]?.qualifiedStudyDay == true) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
