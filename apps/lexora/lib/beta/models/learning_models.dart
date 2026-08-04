enum LearningStatus { newWord, learning, review, mastered, lapsed }

enum ReviewRating { again, hard, good }

enum ReviewMode { wordToMeaning, meaningToWord, spelling, cloze, collocation }

enum StudyMode {
  mixed,
  wordToMeaning,
  meaningToWord,
  spelling,
  cloze,
  collocation,
}

enum SourceType {
  cet4Listening,
  cet4Reading,
  cet4Writing,
  cet4Translation,
  textbook,
  manual,
  other,
}

enum SkillTag {
  listening,
  reading,
  writing,
  translation,
  highFrequency,
  collocation,
  confusing,
  familiarWordNewMeaning,
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    values.where((value) => value.name == raw).firstOrNull ?? fallback;

String localDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class WordExample {
  const WordExample({
    required this.id,
    required this.sentence,
    required this.createdAt,
    required this.updatedAt,
    this.translation,
    this.clozeSentence,
    this.sourceId,
  });

  final String id;
  final String sentence;
  final String? translation;
  final String? clozeSentence;
  final String? sourceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sentence': sentence,
    if (translation != null) 'translation': translation,
    if (clozeSentence != null) 'clozeSentence': clozeSentence,
    if (sourceId != null) 'sourceId': sourceId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory WordExample.fromJson(Map<String, dynamic> json) => WordExample(
    id: json['id']?.toString() ?? '',
    sentence: json['sentence']?.toString() ?? '',
    translation: json['translation']?.toString(),
    clozeSentence: json['clozeSentence']?.toString(),
    sourceId: json['sourceId']?.toString(),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class WordMeaning {
  const WordMeaning({
    required this.id,
    required this.partOfSpeech,
    required this.definitionZh,
    this.definitionEn,
    this.acceptedAnswers = const [],
    this.examples = const [],
  });

  final String id;
  final String partOfSpeech;
  final String definitionZh;
  final String? definitionEn;
  final List<String> acceptedAnswers;
  final List<WordExample> examples;

  Map<String, dynamic> toJson() => {
    'id': id,
    'partOfSpeech': partOfSpeech,
    'definitionZh': definitionZh,
    if (definitionEn != null) 'definitionEn': definitionEn,
    'acceptedAnswers': acceptedAnswers,
    'examples': examples.map((value) => value.toJson()).toList(),
  };

  factory WordMeaning.fromJson(Map<String, dynamic> json) => WordMeaning(
    id: json['id']?.toString() ?? '',
    partOfSpeech: json['partOfSpeech']?.toString() ?? '',
    definitionZh: json['definitionZh']?.toString() ?? '',
    definitionEn: json['definitionEn']?.toString(),
    acceptedAnswers: (json['acceptedAnswers'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(),
    examples: (json['examples'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => WordExample.fromJson(value.cast<String, dynamic>()))
        .toList(),
  );
}

class Collocation {
  const Collocation({
    required this.id,
    required this.text,
    required this.meaningZh,
    required this.createdAt,
    required this.updatedAt,
    this.acceptedAnswers = const [],
    this.exampleSentence,
    this.exampleTranslation,
    this.sourceId,
  });

  final String id;
  final String text;
  final String meaningZh;
  final List<String> acceptedAnswers;
  final String? exampleSentence;
  final String? exampleTranslation;
  final String? sourceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'meaningZh': meaningZh,
    'acceptedAnswers': acceptedAnswers,
    if (exampleSentence != null) 'exampleSentence': exampleSentence,
    if (exampleTranslation != null) 'exampleTranslation': exampleTranslation,
    if (sourceId != null) 'sourceId': sourceId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Collocation.fromJson(Map<String, dynamic> json) => Collocation(
    id: json['id']?.toString() ?? '',
    text: json['text']?.toString() ?? '',
    meaningZh: json['meaningZh']?.toString() ?? '',
    acceptedAnswers: (json['acceptedAnswers'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(),
    exampleSentence: json['exampleSentence']?.toString(),
    exampleTranslation: json['exampleTranslation']?.toString(),
    sourceId: json['sourceId']?.toString(),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class WordSource {
  const WordSource({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.examYear,
    this.examMonth,
    this.paperCode,
    this.section,
    this.questionNumber,
    this.originalSentence,
    this.note,
  });

  final String id;
  final SourceType sourceType;
  final String title;
  final int? examYear;
  final int? examMonth;
  final String? paperCode;
  final String? section;
  final String? questionNumber;
  final String? originalSentence;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceType': sourceType.name,
    'title': title,
    if (examYear != null) 'examYear': examYear,
    if (examMonth != null) 'examMonth': examMonth,
    if (paperCode != null) 'paperCode': paperCode,
    if (section != null) 'section': section,
    if (questionNumber != null) 'questionNumber': questionNumber,
    if (originalSentence != null) 'originalSentence': originalSentence,
    if (note != null) 'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory WordSource.fromJson(Map<String, dynamic> json) => WordSource(
    id: json['id']?.toString() ?? '',
    sourceType: _enumValue(
      SourceType.values,
      json['sourceType'],
      SourceType.other,
    ),
    title: json['title']?.toString() ?? '',
    examYear: (json['examYear'] as num?)?.toInt(),
    examMonth: (json['examMonth'] as num?)?.toInt(),
    paperCode: json['paperCode']?.toString(),
    section: json['section']?.toString(),
    questionNumber: json['questionNumber']?.toString(),
    originalSentence: json['originalSentence']?.toString(),
    note: json['note']?.toString(),
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class LearningWord {
  const LearningWord({
    required this.id,
    required this.text,
    required this.normalizedText,
    required this.meanings,
    required this.createdAt,
    required this.updatedAt,
    this.phoneticUK,
    this.phoneticUS,
    this.audioUK,
    this.audioUS,
    this.collocations = const [],
    this.sources = const [],
    this.tags = const [],
    this.customTags = const [],
    this.note,
    this.isImportant = false,
  });

  final String id;
  final String text;
  final String normalizedText;
  final String? phoneticUK;
  final String? phoneticUS;
  final String? audioUK;
  final String? audioUS;
  final List<WordMeaning> meanings;
  final List<Collocation> collocations;
  final List<WordSource> sources;
  final List<SkillTag> tags;
  final List<String> customTags;
  final String? note;
  final bool isImportant;
  final DateTime createdAt;
  final DateTime updatedAt;

  LearningWord copyWith({
    String? text,
    String? normalizedText,
    String? phoneticUK,
    String? phoneticUS,
    String? audioUK,
    String? audioUS,
    List<WordMeaning>? meanings,
    List<Collocation>? collocations,
    List<WordSource>? sources,
    List<SkillTag>? tags,
    List<String>? customTags,
    String? note,
    bool? isImportant,
    DateTime? updatedAt,
  }) => LearningWord(
    id: id,
    text: text ?? this.text,
    normalizedText: normalizedText ?? this.normalizedText,
    phoneticUK: phoneticUK ?? this.phoneticUK,
    phoneticUS: phoneticUS ?? this.phoneticUS,
    audioUK: audioUK ?? this.audioUK,
    audioUS: audioUS ?? this.audioUS,
    meanings: meanings ?? this.meanings,
    collocations: collocations ?? this.collocations,
    sources: sources ?? this.sources,
    tags: tags ?? this.tags,
    customTags: customTags ?? this.customTags,
    note: note ?? this.note,
    isImportant: isImportant ?? this.isImportant,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'normalizedText': normalizedText,
    if (phoneticUK != null) 'phoneticUK': phoneticUK,
    if (phoneticUS != null) 'phoneticUS': phoneticUS,
    if (audioUK != null) 'audioUK': audioUK,
    if (audioUS != null) 'audioUS': audioUS,
    'meanings': meanings.map((value) => value.toJson()).toList(),
    'collocations': collocations.map((value) => value.toJson()).toList(),
    'sources': sources.map((value) => value.toJson()).toList(),
    'tags': tags.map((value) => value.name).toList(),
    'customTags': customTags,
    if (note != null) 'note': note,
    'isImportant': isImportant,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LearningWord.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return LearningWord(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      normalizedText:
          json['normalizedText']?.toString() ??
          json['text']?.toString().trim().toLowerCase() ??
          '',
      phoneticUK: json['phoneticUK']?.toString(),
      phoneticUS: json['phoneticUS']?.toString(),
      audioUK: json['audioUK']?.toString(),
      audioUS: json['audioUS']?.toString(),
      meanings: (json['meanings'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => WordMeaning.fromJson(value.cast<String, dynamic>()))
          .toList(),
      collocations: (json['collocations'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Collocation.fromJson(value.cast<String, dynamic>()))
          .toList(),
      sources: (json['sources'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => WordSource.fromJson(value.cast<String, dynamic>()))
          .toList(),
      tags: (json['tags'] as List? ?? const [])
          .map((value) => _enumValue(SkillTag.values, value, SkillTag.reading))
          .toSet()
          .toList(),
      customTags: (json['customTags'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      note: json['note']?.toString(),
      isImportant: json['isImportant'] == true,
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
    );
  }
}

class ReviewState {
  const ReviewState({
    required this.wordId,
    required this.status,
    required this.dueAt,
    required this.intervalMinutes,
    required this.consecutiveGoodCount,
    required this.totalReviews,
    required this.againCount,
    required this.hardCount,
    required this.goodCount,
    required this.lapseCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastReviewedAt,
    this.lastRating,
    this.lastReviewMode,
  });

  final String wordId;
  final LearningStatus status;
  final DateTime dueAt;
  final DateTime? lastReviewedAt;
  final int intervalMinutes;
  final int consecutiveGoodCount;
  final int totalReviews;
  final int againCount;
  final int hardCount;
  final int goodCount;
  final int lapseCount;
  final ReviewRating? lastRating;
  final ReviewMode? lastReviewMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'wordId': wordId,
    'status': status.name,
    'dueAt': dueAt.toIso8601String(),
    if (lastReviewedAt != null)
      'lastReviewedAt': lastReviewedAt!.toIso8601String(),
    'intervalMinutes': intervalMinutes,
    'consecutiveGoodCount': consecutiveGoodCount,
    'totalReviews': totalReviews,
    'againCount': againCount,
    'hardCount': hardCount,
    'goodCount': goodCount,
    'lapseCount': lapseCount,
    if (lastRating != null) 'lastRating': lastRating!.name,
    if (lastReviewMode != null) 'lastReviewMode': lastReviewMode!.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ReviewState.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return ReviewState(
      wordId: json['wordId']?.toString() ?? '',
      status: _enumValue(
        LearningStatus.values,
        json['status'],
        LearningStatus.newWord,
      ),
      dueAt: DateTime.tryParse(json['dueAt']?.toString() ?? '') ?? createdAt,
      lastReviewedAt: DateTime.tryParse(
        json['lastReviewedAt']?.toString() ?? '',
      ),
      intervalMinutes: (json['intervalMinutes'] as num?)?.toInt() ?? 0,
      consecutiveGoodCount:
          (json['consecutiveGoodCount'] as num?)?.toInt() ?? 0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      againCount: (json['againCount'] as num?)?.toInt() ?? 0,
      hardCount: (json['hardCount'] as num?)?.toInt() ?? 0,
      goodCount: (json['goodCount'] as num?)?.toInt() ?? 0,
      lapseCount: (json['lapseCount'] as num?)?.toInt() ?? 0,
      lastRating: json['lastRating'] == null
          ? null
          : _enumValue(
              ReviewRating.values,
              json['lastRating'],
              ReviewRating.again,
            ),
      lastReviewMode: json['lastReviewMode'] == null
          ? null
          : _enumValue(
              ReviewMode.values,
              json['lastReviewMode'],
              ReviewMode.wordToMeaning,
            ),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
    );
  }
}

class ReviewLog {
  const ReviewLog({
    required this.id,
    required this.submissionId,
    required this.wordId,
    required this.rating,
    required this.reviewMode,
    required this.usedHint,
    required this.previousStatus,
    required this.nextStatus,
    required this.previousIntervalMinutes,
    required this.nextIntervalMinutes,
    required this.previousDueAt,
    required this.nextDueAt,
    required this.reviewedAt,
    required this.localDateKey,
    this.answerCorrect,
    this.userAnswer,
    this.normalizedUserAnswer,
    this.responseTimeMs,
  });

  final String id;
  final String submissionId;
  final String wordId;
  final ReviewRating rating;
  final ReviewMode reviewMode;
  final bool? answerCorrect;
  final String? userAnswer;
  final String? normalizedUserAnswer;
  final bool usedHint;
  final int? responseTimeMs;
  final LearningStatus previousStatus;
  final LearningStatus nextStatus;
  final int previousIntervalMinutes;
  final int nextIntervalMinutes;
  final DateTime previousDueAt;
  final DateTime nextDueAt;
  final DateTime reviewedAt;
  final String localDateKey;

  Map<String, dynamic> toJson() => {
    'id': id,
    'submissionId': submissionId,
    'wordId': wordId,
    'rating': rating.name,
    'reviewMode': reviewMode.name,
    if (answerCorrect != null) 'answerCorrect': answerCorrect,
    if (userAnswer != null) 'userAnswer': userAnswer,
    if (normalizedUserAnswer != null)
      'normalizedUserAnswer': normalizedUserAnswer,
    'usedHint': usedHint,
    if (responseTimeMs != null) 'responseTimeMs': responseTimeMs,
    'previousStatus': previousStatus.name,
    'nextStatus': nextStatus.name,
    'previousIntervalMinutes': previousIntervalMinutes,
    'nextIntervalMinutes': nextIntervalMinutes,
    'previousDueAt': previousDueAt.toIso8601String(),
    'nextDueAt': nextDueAt.toIso8601String(),
    'reviewedAt': reviewedAt.toIso8601String(),
    'localDateKey': localDateKey,
  };

  factory ReviewLog.fromJson(Map<String, dynamic> json) => ReviewLog(
    id: json['id']?.toString() ?? '',
    submissionId:
        json['submissionId']?.toString() ?? json['id']?.toString() ?? '',
    wordId: json['wordId']?.toString() ?? '',
    rating: _enumValue(ReviewRating.values, json['rating'], ReviewRating.again),
    reviewMode: _enumValue(
      ReviewMode.values,
      json['reviewMode'],
      ReviewMode.wordToMeaning,
    ),
    answerCorrect: json['answerCorrect'] as bool?,
    userAnswer: json['userAnswer']?.toString(),
    normalizedUserAnswer: json['normalizedUserAnswer']?.toString(),
    usedHint: json['usedHint'] == true,
    responseTimeMs: (json['responseTimeMs'] as num?)?.toInt(),
    previousStatus: _enumValue(
      LearningStatus.values,
      json['previousStatus'],
      LearningStatus.newWord,
    ),
    nextStatus: _enumValue(
      LearningStatus.values,
      json['nextStatus'],
      LearningStatus.learning,
    ),
    previousIntervalMinutes:
        (json['previousIntervalMinutes'] as num?)?.toInt() ?? 0,
    nextIntervalMinutes: (json['nextIntervalMinutes'] as num?)?.toInt() ?? 0,
    previousDueAt:
        DateTime.tryParse(json['previousDueAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    nextDueAt:
        DateTime.tryParse(json['nextDueAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    reviewedAt:
        DateTime.tryParse(json['reviewedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    localDateKey: json['localDateKey']?.toString() ?? '',
  );
}

enum SessionStatus { active, paused, completed }

enum SessionItemState { pending, revealed, completed }

class StudySessionItem {
  const StudySessionItem({
    required this.id,
    required this.wordId,
    required this.reviewMode,
    required this.state,
    this.completedAt,
  });

  final String id;
  final String wordId;
  final ReviewMode reviewMode;
  final SessionItemState state;
  final DateTime? completedAt;

  StudySessionItem copyWith({SessionItemState? state, DateTime? completedAt}) =>
      StudySessionItem(
        id: id,
        wordId: wordId,
        reviewMode: reviewMode,
        state: state ?? this.state,
        completedAt: completedAt ?? this.completedAt,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'wordId': wordId,
    'reviewMode': reviewMode.name,
    'state': state.name,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  factory StudySessionItem.fromJson(Map<String, dynamic> json) =>
      StudySessionItem(
        id: json['id']?.toString() ?? '',
        wordId: json['wordId']?.toString() ?? '',
        reviewMode: _enumValue(
          ReviewMode.values,
          json['reviewMode'],
          ReviewMode.wordToMeaning,
        ),
        state: _enumValue(
          SessionItemState.values,
          json['state'],
          SessionItemState.pending,
        ),
        completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      );
}

class StudySession {
  const StudySession({
    required this.id,
    required this.localDateKey,
    required this.status,
    required this.mode,
    required this.items,
    required this.currentIndex,
    required this.startedAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String localDateKey;
  final SessionStatus status;
  final StudyMode mode;
  final List<StudySessionItem> items;
  final int currentIndex;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  StudySession copyWith({
    SessionStatus? status,
    List<StudySessionItem>? items,
    int? currentIndex,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) => StudySession(
    id: id,
    localDateKey: localDateKey,
    status: status ?? this.status,
    mode: mode,
    items: items ?? this.items,
    currentIndex: currentIndex ?? this.currentIndex,
    startedAt: startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'localDateKey': localDateKey,
    'status': status.name,
    'mode': mode.name,
    'items': items.map((value) => value.toJson()).toList(),
    'currentIndex': currentIndex,
    'startedAt': startedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
    id: json['id']?.toString() ?? '',
    localDateKey: json['localDateKey']?.toString() ?? '',
    status: _enumValue(
      SessionStatus.values,
      json['status'],
      SessionStatus.paused,
    ),
    mode: _enumValue(StudyMode.values, json['mode'], StudyMode.mixed),
    items: (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) => StudySessionItem.fromJson(value.cast<String, dynamic>()),
        )
        .toList(),
    currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
    startedAt:
        DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
  );
}

enum PreferredAccent { uk, us }

class BetaSettings {
  const BetaSettings({
    this.dailyNewWordLimit = 20,
    this.defaultStudyMode = StudyMode.mixed,
    this.enabledReviewModes = ReviewMode.values,
    this.preferredAccent = PreferredAccent.us,
    this.speechRate = 1,
    this.autoPlayWordAudio = false,
    this.autoPlayExampleAudio = false,
    this.showNextReviewTime = true,
    required this.updatedAt,
  });

  final int dailyNewWordLimit;
  final StudyMode defaultStudyMode;
  final List<ReviewMode> enabledReviewModes;
  final PreferredAccent preferredAccent;
  final double speechRate;
  final bool autoPlayWordAudio;
  final bool autoPlayExampleAudio;
  final bool showNextReviewTime;
  final DateTime updatedAt;

  BetaSettings copyWith({
    int? dailyNewWordLimit,
    StudyMode? defaultStudyMode,
    List<ReviewMode>? enabledReviewModes,
    PreferredAccent? preferredAccent,
    double? speechRate,
    bool? autoPlayWordAudio,
    bool? autoPlayExampleAudio,
    bool? showNextReviewTime,
    DateTime? updatedAt,
  }) => BetaSettings(
    dailyNewWordLimit: dailyNewWordLimit ?? this.dailyNewWordLimit,
    defaultStudyMode: defaultStudyMode ?? this.defaultStudyMode,
    enabledReviewModes: enabledReviewModes ?? this.enabledReviewModes,
    preferredAccent: preferredAccent ?? this.preferredAccent,
    speechRate: speechRate ?? this.speechRate,
    autoPlayWordAudio: autoPlayWordAudio ?? this.autoPlayWordAudio,
    autoPlayExampleAudio: autoPlayExampleAudio ?? this.autoPlayExampleAudio,
    showNextReviewTime: showNextReviewTime ?? this.showNextReviewTime,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'dailyNewWordLimit': dailyNewWordLimit,
    'defaultStudyMode': defaultStudyMode.name,
    'enabledReviewModes': enabledReviewModes
        .map((value) => value.name)
        .toList(),
    'preferredAccent': preferredAccent.name,
    'speechRate': speechRate,
    'autoPlayWordAudio': autoPlayWordAudio,
    'autoPlayExampleAudio': autoPlayExampleAudio,
    'showNextReviewTime': showNextReviewTime,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory BetaSettings.fromJson(Map<String, dynamic> json) => BetaSettings(
    dailyNewWordLimit: ((json['dailyNewWordLimit'] as num?)?.toInt() ?? 20)
        .clamp(0, 100),
    defaultStudyMode: _enumValue(
      StudyMode.values,
      json['defaultStudyMode'],
      StudyMode.mixed,
    ),
    enabledReviewModes: (json['enabledReviewModes'] as List? ?? const [])
        .map(
          (value) =>
              _enumValue(ReviewMode.values, value, ReviewMode.wordToMeaning),
        )
        .toSet()
        .toList()
        .ifEmpty(ReviewMode.values),
    preferredAccent: _enumValue(
      PreferredAccent.values,
      json['preferredAccent'],
      PreferredAccent.us,
    ),
    speechRate: (json['speechRate'] as num?)?.toDouble() ?? 1,
    autoPlayWordAudio: json['autoPlayWordAudio'] == true,
    autoPlayExampleAudio: json['autoPlayExampleAudio'] == true,
    showNextReviewTime: json['showNextReviewTime'] != false,
    updatedAt:
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.now(),
  );
}

class DailyStudySummary {
  const DailyStudySummary({
    required this.localDateKey,
    required this.dueCountAtDayStart,
    required this.dueCompletedCount,
    required this.reviewCount,
    required this.uniqueWordCount,
    required this.newWordCount,
    required this.goodCount,
    required this.hardCount,
    required this.againCount,
    required this.qualifiedStudyDay,
    required this.updatedAt,
  });

  final String localDateKey;
  final int dueCountAtDayStart;
  final int dueCompletedCount;
  final int reviewCount;
  final int uniqueWordCount;
  final int newWordCount;
  final int goodCount;
  final int hardCount;
  final int againCount;
  final bool qualifiedStudyDay;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'localDateKey': localDateKey,
    'dueCountAtDayStart': dueCountAtDayStart,
    'dueCompletedCount': dueCompletedCount,
    'reviewCount': reviewCount,
    'uniqueWordCount': uniqueWordCount,
    'newWordCount': newWordCount,
    'goodCount': goodCount,
    'hardCount': hardCount,
    'againCount': againCount,
    'qualifiedStudyDay': qualifiedStudyDay,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DailyStudySummary.fromJson(Map<String, dynamic> json) =>
      DailyStudySummary(
        localDateKey: json['localDateKey']?.toString() ?? '',
        dueCountAtDayStart: (json['dueCountAtDayStart'] as num?)?.toInt() ?? 0,
        dueCompletedCount: (json['dueCompletedCount'] as num?)?.toInt() ?? 0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        uniqueWordCount: (json['uniqueWordCount'] as num?)?.toInt() ?? 0,
        newWordCount: (json['newWordCount'] as num?)?.toInt() ?? 0,
        goodCount: (json['goodCount'] as num?)?.toInt() ?? 0,
        hardCount: (json['hardCount'] as num?)?.toInt() ?? 0,
        againCount: (json['againCount'] as num?)?.toInt() ?? 0,
        qualifiedStudyDay: json['qualifiedStudyDay'] == true,
        updatedAt:
            DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class BetaData {
  const BetaData({
    required this.schemaVersion,
    required this.words,
    required this.reviewStates,
    required this.reviewLogs,
    required this.sessions,
    required this.dailySummaries,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
    this.migratedAt,
  });

  static const currentSchemaVersion = 3;

  final int schemaVersion;
  final List<LearningWord> words;
  final Map<String, ReviewState> reviewStates;
  final List<ReviewLog> reviewLogs;
  final List<StudySession> sessions;
  final Map<String, DailyStudySummary> dailySummaries;
  final BetaSettings settings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? migratedAt;

  factory BetaData.empty([DateTime? now]) {
    final timestamp = now ?? DateTime.now();
    return BetaData(
      schemaVersion: currentSchemaVersion,
      words: const [],
      reviewStates: const {},
      reviewLogs: const [],
      sessions: const [],
      dailySummaries: const {},
      settings: BetaSettings(updatedAt: timestamp),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  BetaData copyWith({
    List<LearningWord>? words,
    Map<String, ReviewState>? reviewStates,
    List<ReviewLog>? reviewLogs,
    List<StudySession>? sessions,
    Map<String, DailyStudySummary>? dailySummaries,
    BetaSettings? settings,
    DateTime? updatedAt,
    DateTime? migratedAt,
  }) => BetaData(
    schemaVersion: currentSchemaVersion,
    words: words ?? this.words,
    reviewStates: reviewStates ?? this.reviewStates,
    reviewLogs: reviewLogs ?? this.reviewLogs,
    sessions: sessions ?? this.sessions,
    dailySummaries: dailySummaries ?? this.dailySummaries,
    settings: settings ?? this.settings,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    migratedAt: migratedAt ?? this.migratedAt,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'words': words.map((value) => value.toJson()).toList(),
    'reviewStates': reviewStates.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'reviewLogs': reviewLogs.map((value) => value.toJson()).toList(),
    'sessions': sessions.map((value) => value.toJson()).toList(),
    'dailySummaries': dailySummaries.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'settings': settings.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (migratedAt != null) 'migratedAt': migratedAt!.toIso8601String(),
  };

  factory BetaData.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return BetaData(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      words: (json['words'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => LearningWord.fromJson(value.cast<String, dynamic>()))
          .where((value) => value.id.isNotEmpty && value.text.isNotEmpty)
          .toList(),
      reviewStates: (json['reviewStates'] as Map? ?? const {})
          .map<String, ReviewState>(
            (key, value) => MapEntry(
              key.toString(),
              ReviewState.fromJson((value as Map).cast<String, dynamic>()),
            ),
          ),
      reviewLogs: (json['reviewLogs'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => ReviewLog.fromJson(value.cast<String, dynamic>()))
          .toList(),
      sessions: (json['sessions'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => StudySession.fromJson(value.cast<String, dynamic>()))
          .toList(),
      dailySummaries: (json['dailySummaries'] as Map? ?? const {})
          .map<String, DailyStudySummary>(
            (key, value) => MapEntry(
              key.toString(),
              DailyStudySummary.fromJson(
                (value as Map).cast<String, dynamic>(),
              ),
            ),
          ),
      settings: BetaSettings.fromJson(
        (json['settings'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
      migratedAt: DateTime.tryParse(json['migratedAt']?.toString() ?? ''),
    );
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension _ListDefault<T> on List<T> {
  List<T> ifEmpty(List<T> fallback) => isEmpty ? fallback : this;
}
