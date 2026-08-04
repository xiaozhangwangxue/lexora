import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/beta/controllers/beta_controller.dart';
import 'package:lexora/beta/data/beta_repository.dart';
import 'package:lexora/beta/domain/answer_evaluator.dart';
import 'package:lexora/beta/domain/learning_stats.dart';
import 'package:lexora/beta/domain/review_scheduler.dart';
import 'package:lexora/beta/domain/study_queue.dart';
import 'package:lexora/beta/models/learning_models.dart';
import 'package:lexora/models/word_entry.dart';
import 'package:lexora/services/search_history_service.dart';

void main() {
  final now = DateTime(2026, 8, 5, 12);

  group('复习调度', () {
    test('new + again -> 10 分钟后 learning', () {
      final next = scheduleNextReview(
        state: _state(LearningStatus.newWord, now),
        rating: ReviewRating.again,
        reviewMode: ReviewMode.wordToMeaning,
        reviewedAt: now,
      );
      expect(next.status, LearningStatus.learning);
      expect(next.intervalMinutes, tenMinutes);
      expect(next.dueAt, now.add(const Duration(minutes: tenMinutes)));
    });

    test('new + hard -> 1 天后 learning', () {
      final next = _schedule(LearningStatus.newWord, ReviewRating.hard, now);
      expect(next.status, LearningStatus.learning);
      expect(next.intervalMinutes, oneDay);
    });

    test('new + good -> 3 天后 review', () {
      final next = _schedule(LearningStatus.newWord, ReviewRating.good, now);
      expect(next.status, LearningStatus.review);
      expect(next.intervalMinutes, threeDays);
      expect(next.consecutiveGoodCount, 1);
    });

    test('learning 和 lapsed 按规则重学', () {
      expect(
        _schedule(
          LearningStatus.learning,
          ReviewRating.again,
          now,
        ).intervalMinutes,
        tenMinutes,
      );
      expect(
        _schedule(
          LearningStatus.learning,
          ReviewRating.hard,
          now,
        ).intervalMinutes,
        oneDay,
      );
      expect(
        _schedule(LearningStatus.lapsed, ReviewRating.good, now).status,
        LearningStatus.review,
      );
    });

    test('review + again -> lapsed 且 lapseCount 增加', () {
      final next = scheduleNextReview(
        state: _state(LearningStatus.review, now, lapseCount: 2),
        rating: ReviewRating.again,
        reviewMode: ReviewMode.spelling,
        reviewedAt: now,
      );
      expect(next.status, LearningStatus.lapsed);
      expect(next.lapseCount, 3);
      expect(next.lastReviewMode, ReviewMode.spelling);
    });

    test('mastered + again 退出掌握，hard 降回 review', () {
      expect(
        _schedule(LearningStatus.mastered, ReviewRating.again, now).status,
        LearningStatus.lapsed,
      );
      expect(
        _schedule(LearningStatus.mastered, ReviewRating.hard, now).status,
        LearningStatus.review,
      );
    });

    test('review hard 约 1.5 倍，good 约 2.5 倍', () {
      final state = _state(LearningStatus.review, now, interval: 1000);
      expect(
        scheduleNextReview(
          state: state,
          rating: ReviewRating.hard,
          reviewMode: ReviewMode.cloze,
          reviewedAt: now,
        ).intervalMinutes,
        1500,
      );
      expect(
        scheduleNextReview(
          state: state,
          rating: ReviewRating.good,
          reviewMode: ReviewMode.cloze,
          reviewedAt: now,
        ).intervalMinutes,
        threeDays,
      );
      expect(
        scheduleNextReview(
          state: _state(LearningStatus.review, now, interval: 5000),
          rating: ReviewRating.good,
          reviewMode: ReviewMode.cloze,
          reviewedAt: now,
        ).intervalMinutes,
        12500,
      );
    });

    test('间隔不超过 60 天', () {
      final next = scheduleNextReview(
        state: _state(LearningStatus.review, now, interval: maxInterval),
        rating: ReviewRating.good,
        reviewMode: ReviewMode.wordToMeaning,
        reviewedAt: now,
      );
      expect(next.intervalMinutes, maxInterval);
    });

    test('连续 good 达标且达到 21 天才进入 mastered', () {
      final almost = _state(
        LearningStatus.review,
        now,
        interval: 9 * oneDay,
        consecutiveGood: 2,
      );
      final mastered = scheduleNextReview(
        state: almost,
        rating: ReviewRating.good,
        reviewMode: ReviewMode.wordToMeaning,
        reviewedAt: now,
      );
      expect(mastered.intervalMinutes, greaterThanOrEqualTo(masteredInterval));
      expect(mastered.status, LearningStatus.mastered);
      final short = scheduleNextReview(
        state: _state(
          LearningStatus.review,
          now,
          interval: oneDay,
          consecutiveGood: 2,
        ),
        rating: ReviewRating.good,
        reviewMode: ReviewMode.wordToMeaning,
        reviewedAt: now,
      );
      expect(short.status, LearningStatus.review);
    });

    test('计数器和固定 reviewedAt 正确更新', () {
      final next = _schedule(LearningStatus.review, ReviewRating.good, now);
      expect(next.totalReviews, 1);
      expect(next.goodCount, 1);
      expect(next.hardCount, 0);
      expect(next.lastReviewedAt, now);
    });
  });

  group('答案判定', () {
    test('忽略首尾、大小写、连续空格和弯引号', () {
      expect(normalizeAnswer('  Take   Part In  '), 'take part in');
      expect(normalizeAnswer('Don’t'), "don't");
    });

    test('acceptedAnswers 生效且空答案错误', () {
      expect(
        evaluateAnswer(
          input: 'took part in',
          expected: 'take part in',
          acceptedAnswers: const ['took part in'],
        ).correct,
        isTrue,
      );
      expect(evaluateAnswer(input: ' ', expected: 'word').correct, isFalse);
    });

    test('不删除连字符和撇号，提示降低建议评分', () {
      expect(normalizeAnswer('people-to-people'), 'people-to-people');
      expect(normalizeAnswer("student's"), "student's");
      expect(
        evaluateAnswer(
          input: 'word',
          expected: 'word',
          usedHint: true,
        ).suggestedRating,
        ReviewRating.hard,
      );
    });

    test('挖空只替换完整目标词形', () {
      expect(
        createClozeSentence('A word and wordplay.', 'word'),
        'A ______ and wordplay.',
      );
    });
  });

  group('来源关联', () {
    test('例句与固定搭配的来源关联可完整持久化', () {
      final source = WordSource(
        id: 'source-reading',
        sourceType: SourceType.cet4Reading,
        title: '2026 年四级阅读',
        createdAt: now,
        updatedAt: now,
      );
      final word = LearningWord(
        id: 'word-source',
        text: 'address',
        normalizedText: 'address',
        meanings: [
          WordMeaning(
            id: 'meaning-source',
            partOfSpeech: 'v.',
            definitionZh: '处理',
            examples: [
              WordExample(
                id: 'example-source',
                sentence: 'We must address the issue.',
                sourceId: source.id,
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        ],
        collocations: [
          Collocation(
            id: 'collocation-source',
            text: 'address an issue',
            meaningZh: '处理问题',
            sourceId: source.id,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        sources: [source],
        createdAt: now,
        updatedAt: now,
      );

      final restored = LearningWord.fromJson(word.toJson());
      expect(restored.meanings.single.examples.single.sourceId, source.id);
      expect(restored.collocations.single.sourceId, source.id);
      expect(restored.sources.single.title, source.title);
    });

    test('数据修复会保留有效来源并清除孤立来源', () {
      final source = WordSource(
        id: 'source-valid',
        sourceType: SourceType.cet4Listening,
        title: '四级听力',
        createdAt: now,
        updatedAt: now,
      );
      final word = LearningWord(
        id: 'word-source-repair',
        text: 'issue',
        normalizedText: 'issue',
        meanings: [
          WordMeaning(
            id: 'meaning-source-repair',
            partOfSpeech: 'n.',
            definitionZh: '问题',
            examples: [
              WordExample(
                id: 'example-valid',
                sentence: 'A valid source.',
                sourceId: source.id,
                createdAt: now,
                updatedAt: now,
              ),
              WordExample(
                id: 'example-orphan',
                sentence: 'An orphan source.',
                sourceId: 'missing',
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        ],
        collocations: [
          Collocation(
            id: 'collocation-orphan',
            text: 'raise an issue',
            meaningZh: '提出问题',
            sourceId: 'missing',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        sources: [source],
        createdAt: now,
        updatedAt: now,
      );
      final repaired = repairReferences(
        BetaData.empty(now).copyWith(words: [word]),
      ).words.single;

      expect(repaired.meanings.single.examples.first.sourceId, source.id);
      expect(repaired.meanings.single.examples.last.sourceId, isNull);
      expect(repaired.collocations.single.sourceId, isNull);
    });
  });

  group('今日队列', () {
    test('未来任务不进入，等于 now 的任务进入', () {
      final words = [_word('a', now), _word('b', now)];
      final states = {
        words[0].id: _state(LearningStatus.review, now).copyWithDue(now),
        words[1].id: _state(
          LearningStatus.review,
          now,
        ).copyWithDue(now.add(const Duration(minutes: 1))),
      };
      final queue = buildStudyQueue(
        words: words,
        reviewStates: states,
        settings: BetaSettings(updatedAt: now),
        now: now,
      );
      expect(queue.map((item) => item.wordId), [words[0].id]);
    });

    test('learning 和 lapsed 优先于 review', () {
      final words = [
        _word('review', now),
        _word('learning', now),
        _word('lapsed', now),
      ];
      final states = {
        words[0].id: _state(LearningStatus.review, now),
        words[1].id: _state(LearningStatus.learning, now),
        words[2].id: _state(LearningStatus.lapsed, now),
      };
      final queue = buildStudyQueue(
        words: words,
        reviewStates: states,
        settings: BetaSettings(updatedAt: now),
        now: now,
      );
      expect(queue.first.wordId, words[1].id);
      expect(queue[1].wordId, words[2].id);
    });

    test('每日新词上限只限制新词，0 仍保留到期任务', () {
      final due = List.generate(30, (i) => _word('due-$i', now));
      final fresh = List.generate(
        50,
        (i) => _word('new-$i', now.add(Duration(seconds: i))),
      );
      final states = {
        for (final word in due) word.id: _state(LearningStatus.review, now),
        for (final word in fresh) word.id: _state(LearningStatus.newWord, now),
      };
      final queue = buildStudyQueue(
        words: [...due, ...fresh],
        reviewStates: states,
        settings: BetaSettings(dailyNewWordLimit: 20, updatedAt: now),
        now: now,
      );
      expect(queue, hasLength(50));
      final zero = buildStudyQueue(
        words: [...due, ...fresh],
        reviewStates: states,
        settings: BetaSettings(dailyNewWordLimit: 0, updatedAt: now),
        now: now,
      );
      expect(zero, hasLength(30));
    });

    test('已有未完成 SessionItem 不重复，缺失状态不崩溃', () {
      final word = _word('word', now);
      final item = StudySessionItem(
        id: 'item',
        wordId: word.id,
        reviewMode: ReviewMode.wordToMeaning,
        state: SessionItemState.pending,
      );
      final session = createStudySession(
        items: [item],
        mode: StudyMode.mixed,
        now: now,
      );
      expect(
        buildStudyQueue(
          words: [word, _word('missing', now)],
          reviewStates: {word.id: _state(LearningStatus.newWord, now)},
          settings: BetaSettings(updatedAt: now),
          now: now,
          session: session,
        ),
        isEmpty,
      );
    });

    test('新词按创建时间排序，数据不足安全回退英译中', () {
      final late = _word('late', now.add(const Duration(minutes: 1)));
      final early = _word('early', now);
      final states = {
        late.id: _state(LearningStatus.newWord, now),
        early.id: _state(LearningStatus.newWord, now),
      };
      final queue = buildStudyQueue(
        words: [late, early],
        reviewStates: states,
        settings: BetaSettings(
          enabledReviewModes: const [ReviewMode.cloze],
          updatedAt: now,
        ),
        now: now,
      );
      expect(queue.first.wordId, early.id);
      expect(queue.first.reviewMode, ReviewMode.wordToMeaning);
    });
  });

  group('薄弱词和统计', () {
    test('所有薄弱词规则', () {
      expect(
        isWeakWord(_state(LearningStatus.review, now), [
          _log(now, ReviewRating.again),
          _log(now, ReviewRating.good),
          _log(now, ReviewRating.again),
        ]),
        isTrue,
      );
      expect(
        isWeakWord(_state(LearningStatus.review, now, lapseCount: 3), []),
        isTrue,
      );
      expect(
        isWeakWord(_state(LearningStatus.review, now), [
          _log(
            now,
            ReviewRating.hard,
            mode: ReviewMode.spelling,
            correct: false,
          ),
          _log(
            now,
            ReviewRating.hard,
            mode: ReviewMode.spelling,
            correct: false,
          ),
        ]),
        isTrue,
      );
      expect(
        isWeakWord(_state(LearningStatus.review, now), [
          _log(now, ReviewRating.hard),
          _log(now, ReviewRating.hard),
          _log(now, ReviewRating.good),
          _log(now, ReviewRating.hard),
        ]),
        isTrue,
      );
      expect(
        isWeakWord(_state(LearningStatus.review, now), [
          _log(now, ReviewRating.again, previous: LearningStatus.mastered),
        ]),
        isTrue,
      );
      expect(
        isWeakWord(_state(LearningStatus.review, now), [
          _log(now, ReviewRating.good),
        ]),
        isFalse,
      );
    });

    test('今日统计、成功率和拼写正确率', () {
      final logs = [
        _log(now, ReviewRating.good, mode: ReviewMode.spelling, correct: true),
        _log(now, ReviewRating.hard, mode: ReviewMode.spelling, correct: false),
        _log(now.subtract(const Duration(days: 1)), ReviewRating.good),
      ];
      final stats = calculateTodayStats(logs, now);
      expect(stats.reviewCount, 2);
      expect(stats.recallSuccessRate, .5);
      expect(stats.spellingAccuracy, .5);
    });

    test('仅打开应用不形成学习日，10 次复习形成学习日', () {
      expect(
        buildDailySummary(
          dateKey: localDateKey(now),
          dueCountAtDayStart: 0,
          dueCompletedCount: 0,
          logs: const [],
          now: now,
        ).qualifiedStudyDay,
        isFalse,
      );
      final logs = List.generate(
        10,
        (i) => _log(now.add(Duration(minutes: i)), ReviewRating.good),
      );
      expect(
        buildDailySummary(
          dateKey: localDateKey(now),
          dueCountAtDayStart: 0,
          dueCompletedCount: 0,
          logs: logs,
          now: now,
        ).qualifiedStudyDay,
        isTrue,
      );
    });

    test('连续学习天数按本地日期', () {
      DailyStudySummary day(DateTime date) => DailyStudySummary(
        localDateKey: localDateKey(date),
        dueCountAtDayStart: 1,
        dueCompletedCount: 1,
        reviewCount: 1,
        uniqueWordCount: 1,
        newWordCount: 0,
        goodCount: 1,
        hardCount: 0,
        againCount: 0,
        qualifiedStudyDay: true,
        updatedAt: date,
      );
      final yesterday = now.subtract(const Duration(days: 1));
      expect(
        calculateStreak({
          localDateKey(now): day(now),
          localDateKey(yesterday): day(yesterday),
        }, now),
        2,
      );
    });
  });

  group('旧数据迁移和原子评分', () {
    test('迁移保留释义、例句、短语和音标，不伪造日志', () {
      final entry = _entry();
      final data = migrateLegacyData(
        searchRecords: [
          SearchHistoryRecord(
            query: 'word',
            resolvedWord: 'word',
            searchedAt: now,
            entry: entry,
          ),
        ],
        generatedWords: const [],
        now: now,
      );
      expect(data.schemaVersion, BetaData.currentSchemaVersion);
      expect(data.words, hasLength(1));
      expect(data.words.first.meanings.first.definitionZh, '语言单位。');
      expect(
        data.words.first.meanings.first.examples.first.sentence,
        'This is a word.',
      );
      expect(data.words.first.collocations.first.text, 'in a word');
      expect(data.reviewStates.values.single.status, LearningStatus.newWord);
      expect(data.reviewLogs, isEmpty);
    });

    test('迁移按 normalizedText 去重且输入不被修改', () {
      final records = [
        SearchHistoryRecord(
          query: 'Word',
          resolvedWord: 'word',
          searchedAt: now,
          entry: _entry(),
        ),
        SearchHistoryRecord(
          query: 'word',
          resolvedWord: 'word',
          searchedAt: now,
          entry: _entry(),
        ),
      ];
      final data = migrateLegacyData(
        searchRecords: records,
        generatedWords: const [],
        now: now,
      );
      expect(data.words, hasLength(1));
      expect(records, hasLength(2));
    });

    test('一次评分同时更新状态、追加日志并完成 SessionItem，submissionId 幂等', () {
      final word = _word('word', now);
      final session = createStudySession(
        items: [
          StudySessionItem(
            id: 'item',
            wordId: word.id,
            reviewMode: ReviewMode.spelling,
            state: SessionItemState.revealed,
          ),
        ],
        mode: StudyMode.spelling,
        now: now,
      );
      var data = BetaData.empty(now).copyWith(
        words: [word],
        reviewStates: {word.id: _state(LearningStatus.newWord, now)},
        sessions: [session],
      );
      final submission = ReviewSubmission(
        submissionId: 'once',
        sessionId: session.id,
        itemId: 'item',
        rating: ReviewRating.good,
        reviewMode: ReviewMode.spelling,
        reviewedAt: now,
        answerCorrect: true,
        userAnswer: 'word',
      );
      data = applyReviewSubmission(data, submission);
      expect(data.reviewStates[word.id]!.status, LearningStatus.review);
      expect(data.reviewLogs, hasLength(1));
      expect(
        data.sessions.single.items.single.state,
        SessionItemState.completed,
      );
      expect(applyReviewSubmission(data, submission).reviewLogs, hasLength(1));
    });

    test('修复孤立引用，不让删除单词后统计崩溃', () {
      final word = _word('word', now);
      final data = repairReferences(
        BetaData.empty(now).copyWith(
          words: [word],
          reviewStates: {
            word.id: _state(LearningStatus.newWord, now),
            'orphan': _state(LearningStatus.review, now, wordId: 'orphan'),
          },
          reviewLogs: [_log(now, ReviewRating.good, wordId: 'orphan')],
        ),
      );
      expect(data.reviewStates.keys, {word.id});
      expect(data.reviewLogs, isEmpty);
    });

    test('评分保存失败时回滚状态并允许用户重试', () async {
      final word = _word('rollback', now);
      final item = StudySessionItem(
        id: 'item-rollback',
        wordId: word.id,
        reviewMode: ReviewMode.wordToMeaning,
        state: SessionItemState.revealed,
      );
      final session = createStudySession(
        items: [item],
        mode: StudyMode.mixed,
        now: now,
      );
      final repository = _FailingBetaRepository(
        BetaData.empty(now).copyWith(
          words: [word],
          reviewStates: {word.id: createReviewState(word.id, now)},
          sessions: [session],
        ),
      );
      final controller = BetaController(repository: repository);
      await controller.initialize();
      repository.failSaves = true;

      await expectLater(
        controller.submitReview(
          sessionId: session.id,
          itemId: item.id,
          rating: ReviewRating.good,
          reviewMode: item.reviewMode,
          submissionId: 'rollback-submission',
        ),
        throwsStateError,
      );

      expect(controller.data.reviewLogs, isEmpty);
      expect(
        controller.data.sessions.first.items.first.state,
        SessionItemState.revealed,
      );
      controller.dispose();
    });
  });
}

class _FailingBetaRepository extends BetaRepository {
  _FailingBetaRepository(this.saved);

  BetaData saved;
  bool failSaves = false;

  @override
  Future<BetaData> load({
    List<dynamic>? legacySearchRecords,
    List<dynamic>? legacyGeneratedWords,
    DateTime? now,
  }) async => saved;

  @override
  Future<void> save(BetaData data) async {
    if (failSaves) throw StateError('disk full');
    saved = data;
  }
}

ReviewState _state(
  LearningStatus status,
  DateTime now, {
  String wordId = 'word-1',
  int interval = threeDays,
  int lapseCount = 0,
  int consecutiveGood = 0,
}) => ReviewState(
  wordId: wordId,
  status: status,
  dueAt: now,
  intervalMinutes: status == LearningStatus.newWord ? 0 : interval,
  consecutiveGoodCount: consecutiveGood,
  totalReviews: 0,
  againCount: 0,
  hardCount: 0,
  goodCount: 0,
  lapseCount: lapseCount,
  createdAt: now,
  updatedAt: now,
);

ReviewState _schedule(
  LearningStatus status,
  ReviewRating rating,
  DateTime now,
) => scheduleNextReview(
  state: _state(status, now),
  rating: rating,
  reviewMode: ReviewMode.wordToMeaning,
  reviewedAt: now,
);

LearningWord _word(String text, DateTime createdAt) => LearningWord(
  id: 'word-$text',
  text: text,
  normalizedText: text,
  meanings: [
    WordMeaning(id: 'meaning-$text', partOfSpeech: 'n.', definitionZh: '含义'),
  ],
  createdAt: createdAt,
  updatedAt: createdAt,
);

ReviewLog _log(
  DateTime date,
  ReviewRating rating, {
  String wordId = 'word-1',
  ReviewMode mode = ReviewMode.wordToMeaning,
  bool? correct,
  LearningStatus previous = LearningStatus.review,
}) => ReviewLog(
  id: 'log-${date.microsecondsSinceEpoch}-$rating-$wordId',
  submissionId: 'submission-${date.microsecondsSinceEpoch}-$rating-$wordId',
  wordId: wordId,
  rating: rating,
  reviewMode: mode,
  answerCorrect: correct,
  usedHint: false,
  previousStatus: previous,
  nextStatus: LearningStatus.review,
  previousIntervalMinutes: threeDays,
  nextIntervalMinutes: threeDays,
  previousDueAt: date,
  nextDueAt: date.add(const Duration(days: 3)),
  reviewedAt: date,
  localDateKey: localDateKey(date),
);

WordEntry _entry() => const WordEntry(
  word: 'word',
  difficulty: 'A1–A2',
  frequency: 100,
  usPhonetic: '/wɝːd/',
  ukPhonetic: '/wɜːd/',
  definition: 'A unit of language.',
  definitionZh: '语言单位。',
  synonyms: [],
  synonymsZh: '',
  antonyms: [],
  antonymsZh: '',
  examples: ['This is a word.'],
  examplesZh: ['这是一个单词。'],
  phrases: [
    PhraseEntry(phrase: 'in a word', meaning: 'briefly', meaningZh: '总之'),
  ],
);

extension on ReviewState {
  ReviewState copyWithDue(DateTime dueAt) => ReviewState(
    wordId: wordId,
    status: status,
    dueAt: dueAt,
    lastReviewedAt: lastReviewedAt,
    intervalMinutes: intervalMinutes,
    consecutiveGoodCount: consecutiveGoodCount,
    totalReviews: totalReviews,
    againCount: againCount,
    hardCount: hardCount,
    goodCount: goodCount,
    lapseCount: lapseCount,
    lastRating: lastRating,
    lastReviewMode: lastReviewMode,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
