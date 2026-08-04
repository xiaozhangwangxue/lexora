import '../models/learning_models.dart';

List<ReviewMode> availableReviewModes(
  LearningWord word,
  ReviewState state,
  BetaSettings settings,
) {
  final enabled = settings.enabledReviewModes.toSet();
  final available = <ReviewMode>[];
  if (enabled.contains(ReviewMode.wordToMeaning)) {
    available.add(ReviewMode.wordToMeaning);
  }
  if (enabled.contains(ReviewMode.meaningToWord) &&
      word.meanings.any((value) => value.definitionZh.trim().isNotEmpty)) {
    available.add(ReviewMode.meaningToWord);
  }
  if (enabled.contains(ReviewMode.spelling) &&
      (word.phoneticUS?.isNotEmpty == true ||
          word.phoneticUK?.isNotEmpty == true ||
          word.meanings.isNotEmpty)) {
    available.add(ReviewMode.spelling);
  }
  if (enabled.contains(ReviewMode.cloze) &&
      word.meanings.any(
        (meaning) => meaning.examples.any(
          (example) => example.clozeSentence?.contains('______') == true,
        ),
      )) {
    available.add(ReviewMode.cloze);
  }
  if (enabled.contains(ReviewMode.collocation) &&
      word.collocations.isNotEmpty) {
    available.add(ReviewMode.collocation);
  }
  if (available.isEmpty) return const [ReviewMode.wordToMeaning];
  if (state.status == LearningStatus.newWord) {
    return [
      ReviewMode.wordToMeaning,
      ...available.where((value) => value != ReviewMode.wordToMeaning),
    ];
  }
  return available;
}

ReviewMode chooseReviewMode(
  LearningWord word,
  ReviewState state,
  StudyMode mode,
  BetaSettings settings,
) {
  final available = availableReviewModes(word, state, settings);
  if (mode != StudyMode.mixed) {
    final requested = ReviewMode.values.firstWhere(
      (value) => value.name == mode.name,
      orElse: () => ReviewMode.wordToMeaning,
    );
    if (available.contains(requested)) return requested;
  }
  if (state.status == LearningStatus.newWord) {
    return ReviewMode.wordToMeaning;
  }
  final previous = state.lastReviewMode;
  final rotated = available.where((value) => value != previous).toList();
  final candidates = rotated.isEmpty ? available : rotated;
  return candidates[state.totalReviews % candidates.length];
}

int _priority(ReviewState state, DateTime now) {
  if (state.status == LearningStatus.learning ||
      state.status == LearningStatus.lapsed) {
    return 0;
  }
  if (state.dueAt.isBefore(now)) return 1;
  return 2;
}

List<StudySessionItem> buildStudyQueue({
  required List<LearningWord> words,
  required Map<String, ReviewState> reviewStates,
  required BetaSettings settings,
  required DateTime now,
  StudyMode mode = StudyMode.mixed,
  StudySession? session,
  Set<String>? restrictToWordIds,
  bool includeNewWords = true,
  SessionFocus focus = SessionFocus.mixed,
}) {
  final validWords = {
    for (final word in words)
      if (word.isStudyReady &&
          _learningSourceEnabled(word, settings) &&
          (restrictToWordIds == null || restrictToWordIds.contains(word.id)))
        word.id: word,
  };
  final existingPending = <String>{
    for (final item in session?.items ?? const <StudySessionItem>[])
      if (item.state != SessionItemState.completed) item.wordId,
  };
  final due = <LearningWord>[];
  final fresh = <LearningWord>[];
  for (final word in validWords.values) {
    final state = reviewStates[word.id];
    if (state == null || existingPending.contains(word.id)) continue;
    if (state.status == LearningStatus.newWord &&
        includeNewWords &&
        focus != SessionFocus.reviews) {
      fresh.add(word);
    } else if (state.status != LearningStatus.newWord &&
        !state.dueAt.isAfter(now) &&
        focus != SessionFocus.newWords) {
      due.add(word);
    }
  }
  due.sort((a, b) {
    final left = reviewStates[a.id]!;
    final right = reviewStates[b.id]!;
    final priority = _priority(left, now).compareTo(_priority(right, now));
    if (priority != 0) return priority;
    return left.dueAt.compareTo(right.dueAt);
  });
  fresh.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final selected = [...due, ...fresh.take(settings.dailyNewWordLimit)];
  return selected
      .map(
        (word) => StudySessionItem(
          id: '${word.id}-${now.microsecondsSinceEpoch}',
          wordId: word.id,
          reviewMode: chooseReviewMode(
            word,
            reviewStates[word.id]!,
            mode,
            settings,
          ),
          state: SessionItemState.pending,
        ),
      )
      .toList();
}

bool _learningSourceEnabled(LearningWord word, BetaSettings settings) {
  final enabled = settings.enabledLearningSources.toSet();
  if (enabled.contains('all')) return true;
  if (enabled.contains('manual') &&
      (word.sources.isEmpty ||
          word.sources.any((source) => source.title == 'Lexora 词典'))) {
    return true;
  }
  if (enabled.contains('generated') &&
      word.sources.any((source) => source.title.contains('词汇书生成记录'))) {
    return true;
  }
  if (enabled.contains('historySelected') &&
      settings.selectedHistoryWordIds.contains(word.id)) {
    return true;
  }
  for (final source in word.sources) {
    if (source.title.startsWith('预设词库:') &&
        enabled.contains('preset:${source.title.substring('预设词库:'.length)}')) {
      return true;
    }
  }
  return false;
}

StudySession createStudySession({
  required List<StudySessionItem> items,
  required StudyMode mode,
  required DateTime now,
  SessionFocus focus = SessionFocus.mixed,
}) => StudySession(
  id: 'session-${now.microsecondsSinceEpoch}',
  localDateKey: localDateKey(now),
  status: SessionStatus.active,
  mode: mode,
  focus: focus,
  items: items,
  currentIndex: 0,
  startedAt: now,
  updatedAt: now,
);

int laterDueCount(Map<String, ReviewState> states, DateTime now) => states
    .values
    .where(
      (state) =>
          state.status != LearningStatus.newWord && state.dueAt.isAfter(now),
    )
    .length;
