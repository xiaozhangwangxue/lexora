import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/word_service.dart';
import '../data/beta_repository.dart';
import '../domain/learning_stats.dart';
import '../domain/review_scheduler.dart';
import '../domain/study_queue.dart';
import '../models/learning_models.dart';

class DuplicateLearningWordException implements Exception {
  const DuplicateLearningWordException(this.wordId);

  final String wordId;
}

class BetaController extends ChangeNotifier {
  BetaController({BetaRepository? repository, WordService? wordService})
    : _repository = repository ?? BetaRepository(),
      _wordService = wordService ?? WordService();

  final BetaRepository _repository;
  final WordService _wordService;
  final Set<String> _submissionsInFlight = {};
  BetaData _data = BetaData.empty();
  bool _loading = true;
  bool _saving = false;
  bool _disposed = false;
  Object? _error;

  BetaData get data => _data;
  bool get loading => _loading;
  bool get saving => _saving;
  Object? get error => _error;

  StudySession? get activeSession {
    final active =
        _data.sessions
            .where(
              (session) =>
                  session.status == SessionStatus.active &&
                  session.localDateKey == localDateKey(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return active.firstOrNull;
  }

  Future<void> initialize() async {
    if (_disposed) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final loaded = await _repository.load();
      if (_disposed) return;
      _data = loaded;
      await _ensureTodaySummary(DateTime.now());
    } catch (error) {
      if (!_disposed) _error = error;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() => initialize();

  Future<LearningWord> lookupAndAdd(String rawTerm) async {
    final term = rawTerm.trim();
    if (term.isEmpty) throw ArgumentError('请输入英文单词或短语');
    final normalized = term.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final duplicate = _data.words
        .where((word) => word.normalizedText == normalized)
        .firstOrNull;
    if (duplicate != null) {
      throw DuplicateLearningWordException(duplicate.id);
    }
    final batch = await _wordService.lookupAll([term], exampleCount: 3);
    if (batch.entries.isEmpty) {
      throw StateError(batch.failures.firstOrNull?.message ?? '没有找到可靠的词典结果');
    }
    final word = learningWordFromEntry(batch.entries.first);
    await saveWord(word);
    return word;
  }

  Future<void> saveWord(LearningWord word) async {
    final normalized = word.text.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final duplicate = _data.words
        .where(
          (candidate) =>
              candidate.normalizedText == normalized && candidate.id != word.id,
        )
        .firstOrNull;
    if (duplicate != null) {
      throw DuplicateLearningWordException(duplicate.id);
    }
    final now = DateTime.now();
    final normalizedWord = word.copyWith(
      text: word.text.trim(),
      normalizedText: normalized,
      updatedAt: now,
    );
    final words = [..._data.words];
    final index = words.indexWhere((candidate) => candidate.id == word.id);
    if (index < 0) {
      words.add(normalizedWord);
    } else {
      words[index] = normalizedWord;
    }
    _data = _data.copyWith(
      words: words,
      reviewStates: {
        ..._data.reviewStates,
        word.id:
            _data.reviewStates[word.id] ??
            createReviewState(word.id, word.createdAt),
      },
      updatedAt: now,
    );
    await _persist();
  }

  Future<void> toggleImportant(String wordId) async {
    final words = [
      for (final word in _data.words)
        if (word.id == wordId)
          word.copyWith(
            isImportant: !word.isImportant,
            updatedAt: DateTime.now(),
          )
        else
          word,
    ];
    _data = _data.copyWith(words: words, updatedAt: DateTime.now());
    await _persist();
  }

  Future<void> deleteWord(String wordId) async {
    final words = _data.words.where((word) => word.id != wordId).toList();
    final states = {..._data.reviewStates}..remove(wordId);
    final logs = _data.reviewLogs.where((log) => log.wordId != wordId).toList();
    final sessions = _data.sessions
        .map(
          (session) => session.copyWith(
            items: session.items
                .where((item) => item.wordId != wordId)
                .toList(),
            updatedAt: DateTime.now(),
          ),
        )
        .toList();
    _data = _data.copyWith(
      words: words,
      reviewStates: states,
      reviewLogs: logs,
      sessions: sessions,
      updatedAt: DateTime.now(),
    );
    await _persist();
  }

  Future<StudySession?> startStudy({
    StudyMode? mode,
    Set<String>? restrictToWordIds,
  }) async {
    final existing = activeSession;
    if (existing != null && restrictToWordIds == null) return existing;
    final now = DateTime.now();
    final selectedMode = mode ?? _data.settings.defaultStudyMode;
    final items = buildStudyQueue(
      words: _data.words,
      reviewStates: _data.reviewStates,
      settings: _data.settings,
      now: now,
      mode: selectedMode,
      restrictToWordIds: restrictToWordIds,
    );
    if (items.isEmpty) return null;
    final session = createStudySession(
      items: items,
      mode: selectedMode,
      now: now,
    );
    final previousSessions = [
      for (final value in _data.sessions)
        if (value.status == SessionStatus.active)
          value.copyWith(status: SessionStatus.paused, updatedAt: now)
        else
          value,
    ];
    _data = _data.copyWith(
      sessions: [...previousSessions, session],
      updatedAt: now,
    );
    await _persist();
    return session;
  }

  LearningWord? wordForId(String id) =>
      _data.words.where((word) => word.id == id).firstOrNull;

  Future<void> revealCurrentItem(String sessionId) async {
    final sessionIndex = _data.sessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (sessionIndex < 0) return;
    final session = _data.sessions[sessionIndex];
    if (session.currentIndex >= session.items.length) return;
    final items = [...session.items];
    final item = items[session.currentIndex];
    if (item.state == SessionItemState.completed) return;
    items[session.currentIndex] = item.copyWith(
      state: SessionItemState.revealed,
    );
    final sessions = [..._data.sessions];
    sessions[sessionIndex] = session.copyWith(
      items: items,
      updatedAt: DateTime.now(),
    );
    _data = _data.copyWith(sessions: sessions, updatedAt: DateTime.now());
    await _persist();
  }

  Future<bool> submitReview({
    required String sessionId,
    required String itemId,
    required ReviewRating rating,
    required ReviewMode reviewMode,
    bool? answerCorrect,
    String? userAnswer,
    bool usedHint = false,
    int? responseTimeMs,
    String? submissionId,
  }) async {
    final id =
        submissionId ??
        '$sessionId-$itemId-${DateTime.now().microsecondsSinceEpoch}';
    if (_submissionsInFlight.contains(id) ||
        _data.reviewLogs.any((log) => log.submissionId == id)) {
      return false;
    }
    _submissionsInFlight.add(id);
    _saving = true;
    if (!_disposed) notifyListeners();
    final previousData = _data;
    try {
      final now = DateTime.now();
      final next = applyReviewSubmission(
        _data,
        ReviewSubmission(
          submissionId: id,
          sessionId: sessionId,
          itemId: itemId,
          rating: rating,
          reviewMode: reviewMode,
          reviewedAt: now,
          answerCorrect: answerCorrect,
          userAnswer: userAnswer,
          usedHint: usedHint,
          responseTimeMs: responseTimeMs,
        ),
      );
      if (identical(next, _data)) return false;
      _data = _completeOrExtendSession(next, sessionId, now);
      await _repository.save(_data);
      _error = null;
      return true;
    } catch (error) {
      _data = previousData;
      _error = error;
      rethrow;
    } finally {
      _submissionsInFlight.remove(id);
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  BetaData _completeOrExtendSession(
    BetaData data,
    String sessionId,
    DateTime now,
  ) {
    final index = data.sessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (index < 0) return data;
    final session = data.sessions[index];
    if (session.items.any((item) => item.state != SessionItemState.completed)) {
      return data;
    }
    final appended = buildStudyQueue(
      words: data.words,
      reviewStates: data.reviewStates,
      settings: data.settings,
      now: now,
      mode: session.mode,
      session: session,
      includeNewWords: false,
    );
    final sessions = [...data.sessions];
    sessions[index] = appended.isEmpty
        ? session.copyWith(
            status: SessionStatus.completed,
            currentIndex: session.items.length,
            completedAt: now,
            updatedAt: now,
          )
        : session.copyWith(
            items: [...session.items, ...appended],
            currentIndex: session.items.length,
            updatedAt: now,
          );
    return data.copyWith(sessions: sessions, updatedAt: now);
  }

  Future<void> updateSettings(BetaSettings settings) async {
    _data = _data.copyWith(
      settings: settings.copyWith(updatedAt: DateTime.now()),
      updatedAt: DateTime.now(),
    );
    await _persist();
  }

  Future<void> refreshDueTasks() async {
    if (_disposed) return;
    await _ensureTodaySummary(DateTime.now());
    if (!_disposed) notifyListeners();
  }

  Future<void> _ensureTodaySummary(DateTime now) async {
    final key = localDateKey(now);
    if (_data.dailySummaries.containsKey(key)) return;
    final dueCount = _data.reviewStates.values
        .where(
          (state) =>
              state.status != LearningStatus.newWord &&
              !state.dueAt.isAfter(now),
        )
        .length;
    _data = _data.copyWith(
      dailySummaries: {
        ..._data.dailySummaries,
        key: buildDailySummary(
          dateKey: key,
          dueCountAtDayStart: dueCount,
          dueCompletedCount: 0,
          logs: _data.reviewLogs,
          now: now,
        ),
      },
      updatedAt: now,
    );
    await _repository.save(_data);
  }

  Future<void> _persist() async {
    _saving = true;
    _error = null;
    if (!_disposed) notifyListeners();
    try {
      await _repository.save(_data);
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
