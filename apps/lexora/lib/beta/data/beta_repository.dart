import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/word_entry.dart';
import '../../services/history_service.dart';
import '../../services/search_history_service.dart';
import '../domain/answer_evaluator.dart';
import '../domain/learning_stats.dart';
import '../domain/review_scheduler.dart';
import '../models/learning_models.dart';

class BetaDataException implements Exception {
  const BetaDataException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message：$cause';
}

class ReviewSubmission {
  const ReviewSubmission({
    required this.submissionId,
    required this.sessionId,
    required this.itemId,
    required this.rating,
    required this.reviewMode,
    required this.reviewedAt,
    this.answerCorrect,
    this.userAnswer,
    this.usedHint = false,
    this.responseTimeMs,
  });

  final String submissionId;
  final String sessionId;
  final String itemId;
  final ReviewRating rating;
  final ReviewMode reviewMode;
  final DateTime reviewedAt;
  final bool? answerCorrect;
  final String? userAnswer;
  final bool usedHint;
  final int? responseTimeMs;
}

class BetaRepository {
  BetaRepository({
    Future<Directory> Function()? documentsDirectory,
    SearchHistoryService? searchHistoryService,
    HistoryService? historyService,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _searchHistoryService = searchHistoryService ?? SearchHistoryService(),
       _historyService = historyService ?? HistoryService();

  static const _backupKey = 'lexora.learning.beta.v3.recovery';
  static const _migrationKey = 'lexora.learning.beta.v3.migrated';
  static const _fileName = 'lexora-learning-v3.json';

  final Future<Directory> Function() _documentsDirectory;
  final SearchHistoryService _searchHistoryService;
  final HistoryService _historyService;

  Future<BetaData> load({
    List<SearchHistoryRecord>? legacySearchRecords,
    List<GeneratedWordRecord>? legacyGeneratedWords,
    DateTime? now,
  }) async {
    final file = await _dataFile();
    final preferences = await SharedPreferences.getInstance();
    Object? fileError;
    if (await file.exists()) {
      try {
        return _decode(await file.readAsString());
      } catch (error) {
        fileError = error;
      }
    }

    final recovery = preferences.getString(_backupKey);
    if (recovery != null) {
      try {
        final data = _decode(recovery);
        await file.writeAsString(recovery, encoding: utf8, flush: true);
        return data;
      } catch (_) {
        // Keep the original file and recovery value untouched for diagnosis.
      }
    }
    if (fileError != null) {
      throw BetaDataException('学习数据无法读取，原始文件已保留', fileError);
    }

    final timestamp = now ?? DateTime.now();
    final searchRecords =
        legacySearchRecords ?? await _searchHistoryService.load();
    final generatedWords =
        legacyGeneratedWords ?? await _historyService.loadWords();
    final migrated = migrateLegacyData(
      searchRecords: searchRecords,
      generatedWords: generatedWords,
      now: timestamp,
    );
    await save(migrated);
    await preferences.setString(_migrationKey, timestamp.toIso8601String());
    return migrated;
  }

  Future<void> save(BetaData data) async {
    final raw = jsonEncode(data.toJson());
    final preferences = await SharedPreferences.getInstance();
    final file = await _dataFile();
    try {
      await preferences.setString(_backupKey, raw);
      final temporary = File('${file.path}.writing');
      await temporary.writeAsString(raw, encoding: utf8, flush: true);
      await file.writeAsBytes(await temporary.readAsBytes(), flush: true);
      if (await temporary.exists()) await temporary.delete();
    } catch (error) {
      throw BetaDataException('学习进度保存失败', error);
    }
  }

  Future<File> _dataFile() async {
    final directory = await _documentsDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    return File('${directory.path}/$_fileName');
  }

  BetaData _decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map) throw const FormatException('Root must be an object.');
    final data = BetaData.fromJson(json.cast<String, dynamic>());
    if (data.schemaVersion != BetaData.currentSchemaVersion) {
      throw FormatException('Unsupported schema ${data.schemaVersion}.');
    }
    return repairReferences(data);
  }
}

BetaData migrateLegacyData({
  required List<SearchHistoryRecord> searchRecords,
  required List<GeneratedWordRecord> generatedWords,
  required DateTime now,
}) {
  final byNormalized = <String, LearningWord>{};
  for (final record in [
    ...searchRecords,
  ]..sort((a, b) => a.searchedAt.compareTo(b.searchedAt))) {
    final word = learningWordFromEntry(
      record.entry,
      createdAt: record.searchedAt,
      sourceTitle: 'Lexora 查词记录',
    );
    final existing = byNormalized[word.normalizedText];
    if (existing == null || _richness(word) > _richness(existing)) {
      byNormalized[word.normalizedText] = word;
    }
  }
  for (final record in generatedWords) {
    final normalized = normalizeAnswer(record.word);
    if (normalized.isEmpty || byNormalized.containsKey(normalized)) continue;
    final id = _stableId('word', normalized);
    byNormalized[normalized] = LearningWord(
      id: id,
      text: record.word,
      normalizedText: normalized,
      meanings: [
        WordMeaning(id: '$id-meaning-0', partOfSpeech: '', definitionZh: ''),
      ],
      sources: [
        WordSource(
          id: '$id-source-generated',
          sourceType: SourceType.other,
          title: 'Lexora 词汇书生成记录',
          createdAt: record.firstGeneratedAt,
          updatedAt: record.lastGeneratedAt,
        ),
      ],
      isImportant: record.starred,
      createdAt: record.firstGeneratedAt,
      updatedAt: record.lastGeneratedAt,
    );
  }
  final words = byNormalized.values.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return BetaData(
    schemaVersion: BetaData.currentSchemaVersion,
    words: words,
    reviewStates: {
      for (final word in words)
        word.id: createReviewState(word.id, word.createdAt),
    },
    reviewLogs: const [],
    sessions: const [],
    dailySummaries: const {},
    settings: BetaSettings(updatedAt: now),
    createdAt: now,
    updatedAt: now,
    migratedAt: now,
  );
}

LearningWord learningWordFromEntry(
  WordEntry entry, {
  DateTime? createdAt,
  String sourceTitle = 'Lexora 词典',
}) {
  final timestamp = createdAt ?? DateTime.now();
  final normalized = normalizeAnswer(entry.word);
  final id = _stableId('word', normalized);
  final examples = <WordExample>[];
  for (var index = 0; index < entry.examples.length; index++) {
    final sentence = entry.examples[index].trim();
    if (sentence.isEmpty) continue;
    examples.add(
      WordExample(
        id: '$id-example-$index',
        sentence: sentence,
        translation: index < entry.examplesZh.length
            ? entry.examplesZh[index]
            : null,
        clozeSentence: createClozeSentence(sentence, entry.word),
        sourceId: '$id-source-0',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
  }
  final meanings = <WordMeaning>[];
  for (var senseIndex = 0; senseIndex < entry.senses.length; senseIndex++) {
    final sense = entry.senses[senseIndex];
    for (
      var definitionIndex = 0;
      definitionIndex < sense.definitions.length;
      definitionIndex++
    ) {
      final definition = sense.definitions[definitionIndex];
      meanings.add(
        WordMeaning(
          id: '$id-meaning-$senseIndex-$definitionIndex',
          partOfSpeech: sense.partOfSpeech,
          definitionZh: definition.definitionZh,
          definitionEn: definition.definition,
          acceptedAnswers: [entry.word],
          examples: meanings.isEmpty ? examples : const [],
        ),
      );
    }
  }
  if (meanings.isEmpty) {
    meanings.add(
      WordMeaning(
        id: '$id-meaning-0',
        partOfSpeech: '',
        definitionZh: entry.definitionZh,
        definitionEn: entry.definition,
        acceptedAnswers: [entry.word],
        examples: examples,
      ),
    );
  }
  final collocations = <Collocation>[
    for (var index = 0; index < entry.phrases.length; index++)
      Collocation(
        id: '$id-collocation-$index',
        text: entry.phrases[index].phrase,
        meaningZh: entry.phrases[index].meaningZh,
        acceptedAnswers: _collocationAnswers(entry.phrases[index].phrase),
        exampleSentence: entry.phrases[index].meaning,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
  ];
  return LearningWord(
    id: id,
    text: entry.word,
    normalizedText: normalized,
    phoneticUK: entry.ukPhonetic,
    phoneticUS: entry.usPhonetic,
    meanings: meanings,
    collocations: collocations,
    sources: [
      WordSource(
        id: '$id-source-0',
        sourceType: SourceType.other,
        title: sourceTitle,
        originalSentence: examples.firstOrNull?.sentence,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    ],
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

List<String> _collocationAnswers(String phrase) {
  const particles = {
    'to',
    'in',
    'on',
    'at',
    'for',
    'from',
    'with',
    'of',
    'by',
    'into',
    'about',
    'through',
  };
  final tokens = normalizeAnswer(phrase).split(' ');
  final particle = tokens.where(particles.contains).lastOrNull;
  return [phrase, if (particle != null) particle];
}

int _richness(LearningWord word) =>
    word.meanings.fold<int>(
      0,
      (sum, value) =>
          sum + value.definitionZh.length + (value.definitionEn?.length ?? 0),
    ) +
    word.collocations.length * 20 +
    word.meanings.fold<int>(
      0,
      (sum, value) => sum + value.examples.length * 20,
    );

String _stableId(String prefix, String value) {
  var hash = 2166136261;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  return '$prefix-${hash.toRadixString(16)}';
}

BetaData repairReferences(BetaData data) {
  final words = data.words.map(_repairWordSourceReferences).toList();
  final wordIds = words.map((word) => word.id).toSet();
  final states = <String, ReviewState>{
    for (final word in words)
      word.id:
          data.reviewStates[word.id] ??
          createReviewState(word.id, word.createdAt),
  };
  return data.copyWith(
    words: words,
    reviewStates: states,
    reviewLogs: data.reviewLogs
        .where((log) => wordIds.contains(log.wordId))
        .toList(),
    sessions: data.sessions.map((session) {
      final items = session.items
          .where((item) => wordIds.contains(item.wordId))
          .toList();
      return session.copyWith(
        items: items,
        currentIndex: session.currentIndex.clamp(
          0,
          items.isEmpty ? 0 : items.length - 1,
        ),
      );
    }).toList(),
  );
}

LearningWord _repairWordSourceReferences(LearningWord word) {
  final sourceIds = word.sources.map((source) => source.id).toSet();
  return word.copyWith(
    meanings: [
      for (final meaning in word.meanings)
        WordMeaning(
          id: meaning.id,
          partOfSpeech: meaning.partOfSpeech,
          definitionZh: meaning.definitionZh,
          definitionEn: meaning.definitionEn,
          acceptedAnswers: meaning.acceptedAnswers,
          examples: [
            for (final example in meaning.examples)
              WordExample(
                id: example.id,
                sentence: example.sentence,
                translation: example.translation,
                clozeSentence: example.clozeSentence,
                sourceId: sourceIds.contains(example.sourceId)
                    ? example.sourceId
                    : null,
                createdAt: example.createdAt,
                updatedAt: example.updatedAt,
              ),
          ],
        ),
    ],
    collocations: [
      for (final collocation in word.collocations)
        Collocation(
          id: collocation.id,
          text: collocation.text,
          meaningZh: collocation.meaningZh,
          acceptedAnswers: collocation.acceptedAnswers,
          exampleSentence: collocation.exampleSentence,
          exampleTranslation: collocation.exampleTranslation,
          sourceId: sourceIds.contains(collocation.sourceId)
              ? collocation.sourceId
              : null,
          createdAt: collocation.createdAt,
          updatedAt: collocation.updatedAt,
        ),
    ],
  );
}

BetaData applyReviewSubmission(BetaData data, ReviewSubmission submission) {
  if (data.reviewLogs.any(
    (log) => log.submissionId == submission.submissionId,
  )) {
    return data;
  }
  final sessionIndex = data.sessions.indexWhere(
    (session) => session.id == submission.sessionId,
  );
  if (sessionIndex < 0) return data;
  final session = data.sessions[sessionIndex];
  final itemIndex = session.items.indexWhere(
    (item) => item.id == submission.itemId,
  );
  if (itemIndex < 0 ||
      session.items[itemIndex].state == SessionItemState.completed) {
    return data;
  }
  final item = session.items[itemIndex];
  final previous = data.reviewStates[item.wordId];
  if (previous == null) return data;
  final next = scheduleNextReview(
    state: previous,
    rating: submission.rating,
    reviewMode: submission.reviewMode,
    reviewedAt: submission.reviewedAt,
  );
  final normalized = submission.userAnswer == null
      ? null
      : normalizeAnswer(submission.userAnswer!);
  final log = ReviewLog(
    id: 'log-${submission.submissionId}',
    submissionId: submission.submissionId,
    wordId: item.wordId,
    rating: submission.rating,
    reviewMode: submission.reviewMode,
    answerCorrect: submission.answerCorrect,
    userAnswer: submission.userAnswer,
    normalizedUserAnswer: normalized,
    usedHint: submission.usedHint,
    responseTimeMs: submission.responseTimeMs,
    previousStatus: previous.status,
    nextStatus: next.status,
    previousIntervalMinutes: previous.intervalMinutes,
    nextIntervalMinutes: next.intervalMinutes,
    previousDueAt: previous.dueAt,
    nextDueAt: next.dueAt,
    reviewedAt: submission.reviewedAt,
    localDateKey: localDateKey(submission.reviewedAt),
  );
  final items = [...session.items];
  items[itemIndex] = item.copyWith(
    state: SessionItemState.completed,
    completedAt: submission.reviewedAt,
  );
  var nextIndex = itemIndex + 1;
  while (nextIndex < items.length &&
      items[nextIndex].state == SessionItemState.completed) {
    nextIndex += 1;
  }
  final sessions = [...data.sessions];
  sessions[sessionIndex] = session.copyWith(
    items: items,
    currentIndex: nextIndex.clamp(0, items.length),
    updatedAt: submission.reviewedAt,
  );
  final logs = [...data.reviewLogs, log];
  final dateKey = localDateKey(submission.reviewedAt);
  final summaries = {...data.dailySummaries};
  final existingSummary = summaries[dateKey];
  summaries[dateKey] = buildDailySummary(
    dateKey: dateKey,
    dueCountAtDayStart: existingSummary?.dueCountAtDayStart ?? 0,
    dueCompletedCount:
        (existingSummary?.dueCompletedCount ?? 0) +
        (previous.status == LearningStatus.newWord ? 0 : 1),
    logs: logs,
    now: submission.reviewedAt,
  );
  return data.copyWith(
    reviewStates: {...data.reviewStates, item.wordId: next},
    reviewLogs: logs,
    sessions: sessions,
    dailySummaries: summaries,
    updatedAt: submission.reviewedAt,
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
