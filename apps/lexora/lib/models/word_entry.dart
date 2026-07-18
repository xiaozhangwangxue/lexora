class PhraseEntry {
  const PhraseEntry({
    required this.phrase,
    required this.meaning,
    required this.meaningZh,
  });

  final String phrase;
  final String meaning;
  final String meaningZh;

  Map<String, dynamic> toJson() => {
    'phrase': phrase,
    'meaning': meaning,
    'meaningZh': meaningZh,
  };

  factory PhraseEntry.fromJson(Map<String, dynamic> json) => PhraseEntry(
    phrase: json['phrase'] as String,
    meaning: json['meaning'] as String,
    meaningZh: json['meaningZh'] as String,
  );
}

class WordEntry {
  const WordEntry({
    required this.word,
    required this.difficulty,
    required this.frequency,
    required this.usPhonetic,
    required this.ukPhonetic,
    required this.definition,
    required this.definitionZh,
    required this.synonyms,
    required this.synonymsZh,
    required this.antonyms,
    required this.antonymsZh,
    required this.examples,
    required this.examplesZh,
    this.phrases = const [],
    this.originalTerm,
  });

  final String word;
  final String difficulty;
  final double frequency;
  final String usPhonetic;
  final String ukPhonetic;
  final String definition;
  final String definitionZh;
  final List<String> synonyms;
  final String synonymsZh;
  final List<String> antonyms;
  final String antonymsZh;
  final List<String> examples;
  final List<String> examplesZh;
  final List<PhraseEntry> phrases;

  /// The term supplied by the user when [word] is a validated fuzzy match.
  /// It stays null for exact matches and for records saved by older versions.
  final String? originalTerm;

  bool get isFuzzyMatch =>
      originalTerm != null &&
      originalTerm!.trim().toLowerCase() != word.trim().toLowerCase();

  WordEntry withOriginalTerm(String value) => WordEntry(
    word: word,
    difficulty: difficulty,
    frequency: frequency,
    usPhonetic: usPhonetic,
    ukPhonetic: ukPhonetic,
    definition: definition,
    definitionZh: definitionZh,
    synonyms: synonyms,
    synonymsZh: synonymsZh,
    antonyms: antonyms,
    antonymsZh: antonymsZh,
    examples: examples,
    examplesZh: examplesZh,
    phrases: phrases,
    originalTerm: value,
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'difficulty': difficulty,
    'frequency': frequency,
    'usPhonetic': usPhonetic,
    'ukPhonetic': ukPhonetic,
    'definition': definition,
    'definitionZh': definitionZh,
    'synonyms': synonyms,
    'synonymsZh': synonymsZh,
    'antonyms': antonyms,
    'antonymsZh': antonymsZh,
    'examples': examples,
    'examplesZh': examplesZh,
    'phrases': phrases.map((item) => item.toJson()).toList(),
    if (originalTerm != null) 'originalTerm': originalTerm,
  };

  factory WordEntry.fromJson(Map<String, dynamic> json) => WordEntry(
    word: json['word'] as String,
    difficulty: json['difficulty'] as String,
    frequency: (json['frequency'] as num).toDouble(),
    usPhonetic: json['usPhonetic'] as String,
    ukPhonetic: json['ukPhonetic'] as String,
    definition: json['definition'] as String,
    definitionZh: json['definitionZh'] as String,
    synonyms: (json['synonyms'] as List).cast<String>(),
    synonymsZh: json['synonymsZh'] as String,
    antonyms: (json['antonyms'] as List).cast<String>(),
    antonymsZh: json['antonymsZh'] as String,
    examples: (json['examples'] as List).cast<String>(),
    examplesZh: (json['examplesZh'] as List).cast<String>(),
    phrases: (json['phrases'] as List? ?? const [])
        .map((item) => PhraseEntry.fromJson(item as Map<String, dynamic>))
        .toList(),
    originalTerm: json['originalTerm'] as String?,
  );
}

class GeneratedBook {
  const GeneratedBook({
    required this.id,
    required this.title,
    required this.path,
    required this.createdAt,
    required this.wordCount,
    this.previewWords = const [],
  });

  final String id;
  final String title;
  final String path;
  final DateTime createdAt;
  final int wordCount;
  final List<String> previewWords;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'path': path,
    'createdAt': createdAt.toIso8601String(),
    'wordCount': wordCount,
    'previewWords': previewWords,
  };

  factory GeneratedBook.fromJson(Map<String, dynamic> json) => GeneratedBook(
    id: json['id'] as String,
    title: json['title'] as String,
    path: json['path'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    wordCount: (json['wordCount'] as num).toInt(),
    previewWords: (json['previewWords'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(),
  );
}

class GeneratedWordRecord {
  const GeneratedWordRecord({
    required this.word,
    required this.generationCount,
    required this.firstGeneratedAt,
    required this.lastGeneratedAt,
    required this.difficulty,
    this.starred = false,
  });

  final String word;
  final int generationCount;
  final DateTime firstGeneratedAt;
  final DateTime lastGeneratedAt;
  final String difficulty;
  final bool starred;

  GeneratedWordRecord copyWith({
    int? generationCount,
    DateTime? firstGeneratedAt,
    DateTime? lastGeneratedAt,
    String? difficulty,
    bool? starred,
  }) => GeneratedWordRecord(
    word: word,
    generationCount: generationCount ?? this.generationCount,
    firstGeneratedAt: firstGeneratedAt ?? this.firstGeneratedAt,
    lastGeneratedAt: lastGeneratedAt ?? this.lastGeneratedAt,
    difficulty: difficulty ?? this.difficulty,
    starred: starred ?? this.starred,
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'generationCount': generationCount,
    'firstGeneratedAt': firstGeneratedAt.toIso8601String(),
    'lastGeneratedAt': lastGeneratedAt.toIso8601String(),
    'difficulty': difficulty,
    'starred': starred,
  };

  factory GeneratedWordRecord.fromJson(Map<String, dynamic> json) =>
      GeneratedWordRecord(
        word: json['word'] as String,
        generationCount: (json['generationCount'] as num).toInt(),
        firstGeneratedAt: DateTime.parse(json['firstGeneratedAt'] as String),
        lastGeneratedAt: DateTime.parse(json['lastGeneratedAt'] as String),
        difficulty: json['difficulty'] as String? ?? 'B1–B2',
        starred: json['starred'] as bool? ?? false,
      );
}
