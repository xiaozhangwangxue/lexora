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
    required this.example,
    required this.exampleZh,
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
  final String example;
  final String exampleZh;

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
        'example': example,
        'exampleZh': exampleZh,
      };
}

class GeneratedBook {
  const GeneratedBook({
    required this.id,
    required this.title,
    required this.path,
    required this.createdAt,
    required this.wordCount,
  });

  final String id;
  final String title;
  final String path;
  final DateTime createdAt;
  final int wordCount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'path': path,
        'createdAt': createdAt.toIso8601String(),
        'wordCount': wordCount,
      };

  factory GeneratedBook.fromJson(Map<String, dynamic> json) => GeneratedBook(
        id: json['id'] as String,
        title: json['title'] as String,
        path: json['path'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        wordCount: json['wordCount'] as int,
      );
}
