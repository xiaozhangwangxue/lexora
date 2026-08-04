import '../models/learning_models.dart';

const tenMinutes = 10;
const oneDay = 24 * 60;
const threeDays = 3 * 24 * 60;
const maxInterval = 60 * 24 * 60;
const masteredInterval = 21 * 24 * 60;

ReviewState createReviewState(String wordId, DateTime createdAt) => ReviewState(
  wordId: wordId,
  status: LearningStatus.newWord,
  dueAt: createdAt,
  intervalMinutes: 0,
  consecutiveGoodCount: 0,
  totalReviews: 0,
  againCount: 0,
  hardCount: 0,
  goodCount: 0,
  lapseCount: 0,
  createdAt: createdAt,
  updatedAt: createdAt,
);

ReviewState scheduleNextReview({
  required ReviewState state,
  required ReviewRating rating,
  required ReviewMode reviewMode,
  required DateTime reviewedAt,
}) {
  var nextStatus = state.status;
  var nextInterval = state.intervalMinutes;
  var consecutiveGood = state.consecutiveGoodCount;
  var lapseCount = state.lapseCount;

  switch (state.status) {
    case LearningStatus.newWord:
      switch (rating) {
        case ReviewRating.again:
          nextStatus = LearningStatus.learning;
          nextInterval = tenMinutes;
          consecutiveGood = 0;
        case ReviewRating.hard:
          nextStatus = LearningStatus.learning;
          nextInterval = oneDay;
          consecutiveGood = 0;
        case ReviewRating.good:
          nextStatus = LearningStatus.review;
          nextInterval = threeDays;
          consecutiveGood = 1;
      }
    case LearningStatus.learning:
    case LearningStatus.lapsed:
      switch (rating) {
        case ReviewRating.again:
          nextInterval = tenMinutes;
          consecutiveGood = 0;
        case ReviewRating.hard:
          nextInterval = oneDay;
          consecutiveGood = 0;
        case ReviewRating.good:
          nextStatus = LearningStatus.review;
          nextInterval = threeDays;
          consecutiveGood = 1;
      }
    case LearningStatus.review:
    case LearningStatus.mastered:
      switch (rating) {
        case ReviewRating.again:
          nextStatus = LearningStatus.lapsed;
          nextInterval = tenMinutes;
          consecutiveGood = 0;
          lapseCount += 1;
        case ReviewRating.hard:
          nextStatus = LearningStatus.review;
          nextInterval = (state.intervalMinutes * 1.5).round().clamp(
            oneDay,
            maxInterval,
          );
          consecutiveGood = 0;
        case ReviewRating.good:
          nextInterval = (state.intervalMinutes * 2.5).round().clamp(
            threeDays,
            maxInterval,
          );
          consecutiveGood += 1;
          nextStatus = consecutiveGood >= 3 && nextInterval >= masteredInterval
              ? LearningStatus.mastered
              : state.status == LearningStatus.mastered
              ? LearningStatus.mastered
              : LearningStatus.review;
      }
  }

  return ReviewState(
    wordId: state.wordId,
    status: nextStatus,
    dueAt: reviewedAt.add(Duration(minutes: nextInterval)),
    lastReviewedAt: reviewedAt,
    intervalMinutes: nextInterval,
    consecutiveGoodCount: consecutiveGood,
    totalReviews: state.totalReviews + 1,
    againCount: state.againCount + (rating == ReviewRating.again ? 1 : 0),
    hardCount: state.hardCount + (rating == ReviewRating.hard ? 1 : 0),
    goodCount: state.goodCount + (rating == ReviewRating.good ? 1 : 0),
    lapseCount: lapseCount,
    lastRating: rating,
    lastReviewMode: reviewMode,
    createdAt: state.createdAt,
    updatedAt: reviewedAt,
  );
}

Map<ReviewRating, ReviewState> previewSchedules(
  ReviewState state,
  ReviewMode mode,
  DateTime reviewedAt,
) => {
  for (final rating in ReviewRating.values)
    rating: scheduleNextReview(
      state: state,
      rating: rating,
      reviewMode: mode,
      reviewedAt: reviewedAt,
    ),
};
