import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/word_service.dart';
import '../data/beta_repository.dart';
import '../domain/learning_stats.dart';
import '../domain/review_scheduler.dart';
import '../domain/study_queue.dart';
import '../models/learning_models.dart';
import '../services/learning_pack_service.dart';

class DuplicateLearningWordException implements Exception {
  const DuplicateLearningWordException(this.wordId);

  final String wordId;
}

class BetaController extends ChangeNotifier {
  BetaController({
    BetaRepository? repository,
    WordService? wordService,
    LearningPackService? learningPackService,
  }) : _repository = repository ?? BetaRepository(),
       _wordService = wordService ?? WordService(),
       _learningPackService = learningPackService ?? LearningPackService();

  final BetaRepository _repository;
  final WordService _wordService;
  final LearningPackService _learningPackService;
  final Set<String> _submissionsInFlight = {};
  final Set<String> _enrichmentInFlight = {};
  final Set<String> _enrichmentFailed = {};
  BetaData _data = BetaData.empty();
  bool _loading = true;
  bool _saving = false;
  bool _disposed = false;
  Object? _error;
  List<LearningPackDescriptor> _availablePacks = const [];
  Map<String, InstalledLearningPack> _installedPacks = const {};
  String? _packInFlight;
  double? _packProgress;

  BetaData get data => _data;
  bool get loading => _loading;
  bool get saving => _saving;
  Object? get error => _error;
  bool get enriching => _enrichmentInFlight.isNotEmpty;
  int get pendingEnrichmentCount =>
      _data.words.where((word) => !word.isStudyReady).length;
  Set<String> get enrichmentFailed => Set.unmodifiable(_enrichmentFailed);
  List<LearningPackDescriptor> get availablePacks => _availablePacks;
  Map<String, InstalledLearningPack> get installedPacks =>
      Map.unmodifiable(_installedPacks);
  String? get packInFlight => _packInFlight;
  double? get packProgress => _packProgress;

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

  StudySession? activeSessionFor(SessionFocus focus) {
    final sessions =
        _data.sessions
            .where(
              (session) =>
                  session.status == SessionStatus.active &&
                  session.focus == focus &&
                  session.localDateKey == localDateKey(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions.firstOrNull;
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
      unawaited(refreshLearningPacks());
      unawaited(enrichIncompleteWords());
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

  Future<void> enrichIncompleteWords({Iterable<String>? wordIds}) async {
    final selected = wordIds?.toSet();
    final pending = _data.words
        .where(
          (word) =>
              !word.isStudyReady &&
              !_enrichmentInFlight.contains(word.id) &&
              (selected == null || selected.contains(word.id)),
        )
        .toList(growable: false);
    if (pending.isEmpty || _disposed) return;

    // Small batches keep the UI responsive and allow WordService to use its
    // existing parallel/offline/server race without creating an unbounded
    // request burst after a large history migration.
    for (var offset = 0; offset < pending.length && !_disposed; offset += 8) {
      final batch = pending.skip(offset).take(8).toList(growable: false);
      _enrichmentInFlight.addAll(batch.map((word) => word.id));
      notifyListeners();
      try {
        final result = await _wordService.lookupAll(
          batch.map((word) => word.text).toList(growable: false),
          exampleCount: 3,
        );
        final byTerm = {
          for (final entry in result.entries)
            entry.word.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '):
                entry,
        };
        final words = [..._data.words];
        var changed = false;
        for (final original in batch) {
          final entry = byTerm[original.normalizedText];
          if (entry == null) {
            _enrichmentFailed.add(original.id);
            continue;
          }
          final enriched =
              learningWordFromEntry(
                entry,
                createdAt: original.createdAt,
                sourceTitle: original.sources.firstOrNull?.title ?? 'Lexora 词典',
              ).copyWith(
                isImportant: original.isImportant,
                customTags: original.customTags,
                note: original.note,
                updatedAt: DateTime.now(),
              );
          if (!enriched.isStudyReady) {
            _enrichmentFailed.add(original.id);
            continue;
          }
          final index = words.indexWhere((word) => word.id == original.id);
          if (index >= 0) {
            words[index] = enriched;
            changed = true;
            _enrichmentFailed.remove(original.id);
          }
        }
        if (changed) {
          _data = _data.copyWith(words: words, updatedAt: DateTime.now());
          await _repository.save(_data);
        }
      } catch (_) {
        _enrichmentFailed.addAll(batch.map((word) => word.id));
      } finally {
        _enrichmentInFlight.removeAll(batch.map((word) => word.id));
        if (!_disposed) notifyListeners();
      }
    }
  }

  Future<void> refreshLearningPacks() async {
    try {
      final values = await Future.wait([
        _learningPackService.fetchManifest(),
        _learningPackService.installed(),
      ]);
      _availablePacks = values[0] as List<LearningPackDescriptor>;
      _installedPacks = values[1] as Map<String, InstalledLearningPack>;
    } catch (_) {
      _installedPacks = await _learningPackService.installed();
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> installLearningPack(LearningPackDescriptor pack) async {
    if (_packInFlight != null) return;
    _packInFlight = pack.id;
    _packProgress = 0;
    notifyListeners();
    try {
      final entries = await _learningPackService.install(
        pack,
        onProgress: (value) {
          _packProgress = value;
          if (!_disposed) notifyListeners();
        },
      );
      final words = [..._data.words];
      final states = {..._data.reviewStates};
      final now = DateTime.now();
      for (final entry in entries) {
        final imported = learningWordFromEntry(
          entry,
          createdAt: now,
          sourceTitle: '预设词库:${pack.id}',
        );
        final index = words.indexWhere(
          (word) => word.normalizedText == imported.normalizedText,
        );
        if (index < 0) {
          words.add(imported);
          states[imported.id] = createReviewState(imported.id, now);
        } else {
          final existing = words[index];
          final hasSource = existing.sources.any(
            (source) => source.title == '预设词库:${pack.id}',
          );
          if (!hasSource) {
            words[index] = existing.copyWith(
              meanings: existing.isStudyReady
                  ? existing.meanings
                  : imported.meanings,
              phoneticUS: existing.phoneticUS?.isNotEmpty == true
                  ? existing.phoneticUS
                  : imported.phoneticUS,
              phoneticUK: existing.phoneticUK?.isNotEmpty == true
                  ? existing.phoneticUK
                  : imported.phoneticUK,
              sources: [...existing.sources, ...imported.sources],
              updatedAt: now,
            );
          }
        }
      }
      _data = _data.copyWith(
        words: words,
        reviewStates: states,
        updatedAt: now,
      );
      await _repository.save(_data);
      _installedPacks = await _learningPackService.installed();
    } finally {
      _packInFlight = null;
      _packProgress = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> uninstallLearningPack(String packId) async {
    await _learningPackService.uninstall(packId);
    final sourceTitle = '预设词库:$packId';
    final words = <LearningWord>[];
    final removedIds = <String>{};
    for (final word in _data.words) {
      final remainingSources = word.sources
          .where((source) => source.title != sourceTitle)
          .toList(growable: false);
      if (remainingSources.isEmpty &&
          word.sources.any((source) => source.title == sourceTitle)) {
        removedIds.add(word.id);
      } else {
        words.add(word.copyWith(sources: remainingSources));
      }
    }
    final states = {..._data.reviewStates}
      ..removeWhere((wordId, _) => removedIds.contains(wordId));
    final logs = _data.reviewLogs
        .where((log) => !removedIds.contains(log.wordId))
        .toList(growable: false);
    _data = _data.copyWith(
      words: words,
      reviewStates: states,
      reviewLogs: logs,
      updatedAt: DateTime.now(),
    );
    await _repository.save(_data);
    _installedPacks = await _learningPackService.installed();
    if (!_disposed) notifyListeners();
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
    SessionFocus focus = SessionFocus.mixed,
  }) async {
    final existing = activeSessionFor(focus);
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
      focus: focus,
    );
    if (items.isEmpty) return null;
    final session = createStudySession(
      items: items,
      mode: selectedMode,
      now: now,
      focus: focus,
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
      focus: session.focus,
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
