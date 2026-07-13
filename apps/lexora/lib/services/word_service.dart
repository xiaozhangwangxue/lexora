import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_entry.dart';

class WordLookupException implements Exception {
  const WordLookupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WordService {
  WordService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _cachePrefix = 'lexora.word.v3';
  static const _cacheLifetime = Duration(days: 14);

  /// Looks up several words concurrently while preserving their input order.
  ///
  /// Dictionary work is network-bound, so a small pool of asynchronous workers
  /// is faster and lighter than creating CPU isolates. The limit also avoids
  /// overwhelming the public dictionary and translation services.
  Future<List<WordEntry>> lookupAll(
    List<String> words, {
    int exampleCount = 1,
    int maxConcurrency = 4,
    void Function(int completed, int total, String word)? onProgress,
  }) async {
    if (words.isEmpty) return const [];
    final results = List<WordEntry?>.filled(words.length, null);
    var nextIndex = 0;
    var completed = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= words.length) return;
        results[index] = await lookup(words[index], exampleCount: exampleCount);
        completed++;
        onProgress?.call(completed, words.length, words[index]);
      }
    }

    final workerCount = min(max(1, maxConcurrency), words.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results.cast<WordEntry>();
  }

  Future<WordEntry> lookup(String rawWord, {int exampleCount = 1}) async {
    final word = rawWord.trim().toLowerCase();
    final preferences = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix.$exampleCount.$word';
    final cached = _readCache(preferences.getString(cacheKey));
    if (cached != null) return cached;
    final dictionaryUri = Uri.https(
      'api.dictionaryapi.dev',
      '/api/v2/entries/en/$word',
    );
    final relatedUri = Uri.https('api.datamuse.com', '/words', {
      'ml': word,
      'md': 'f',
      'max': '12',
    });

    final responses = await Future.wait([
      _client.get(dictionaryUri).timeout(const Duration(seconds: 15)),
      _client.get(relatedUri).timeout(const Duration(seconds: 15)),
    ]);
    if (responses.first.statusCode != 200) {
      throw WordLookupException('No dictionary entry was found for “$word”.');
    }

    final dictionary = (jsonDecode(responses.first.body) as List).first
        as Map<String, dynamic>;
    final meanings = (dictionary['meanings'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    if (meanings.isEmpty) {
      throw WordLookupException('The dictionary entry for “$word” is empty.');
    }
    final definitions = (meanings.first['definitions'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final primary = definitions.isEmpty
        ? <String, dynamic>{}
        : definitions.first;
    final definition = primary['definition'] as String? ?? 'No definition';
    final examples = _findExamples(meanings).take(exampleCount).toList();

    final phonetics = (dictionary['phonetics'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final phonetic = dictionary['phonetic'] as String? ?? '';
    final usPhonetic = _phoneticFor(phonetics, '-us') ?? phonetic;
    final ukPhonetic = _phoneticFor(phonetics, '-uk') ?? phonetic;

    final sameMeaning = meanings
        .expand((meaning) => (meaning['synonyms'] as List? ?? const []))
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    final opposites = meanings
        .expand((meaning) => (meaning['antonyms'] as List? ?? const []))
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();

    double frequency = 0;
    final related = jsonDecode(responses.last.body) as List;
    for (final item in related.cast<Map<String, dynamic>>()) {
      if ((item['word'] as String?)?.toLowerCase() == word) {
        final tags = (item['tags'] as List? ?? const []).cast<String>();
        final frequencyTag = tags.where((tag) => tag.startsWith('f:'));
        if (frequencyTag.isNotEmpty) {
          frequency = double.tryParse(frequencyTag.first.substring(2)) ?? 0;
        }
      } else if (sameMeaning.length < 6) {
        sameMeaning.add(item['word'] as String);
      }
    }

    final synonyms = sameMeaning.toSet().take(6).toList();
    final antonyms = opposites.toSet().take(6).toList();
    final translations = await Future.wait([
      _translate(definition),
      ...examples.map(_translate),
      if (synonyms.isNotEmpty) _translate(synonyms.join(', ')),
      if (antonyms.isNotEmpty) _translate(antonyms.join(', ')),
    ]);
    var translationIndex = 0;
    final definitionZh = translations[translationIndex++];
    final examplesZh = [
      for (var i = 0; i < examples.length; i++) translations[translationIndex++],
    ];
    final synonymsZh = synonyms.isEmpty ? '' : translations[translationIndex++];
    final antonymsZh = antonyms.isEmpty ? '' : translations[translationIndex++];

    final entry = WordEntry(
      word: word,
      difficulty: _difficulty(word, frequency),
      frequency: frequency,
      usPhonetic: usPhonetic.isEmpty ? '—' : usPhonetic,
      ukPhonetic: ukPhonetic.isEmpty ? '—' : ukPhonetic,
      definition: definition,
      definitionZh: definitionZh,
      synonyms: synonyms,
      synonymsZh: synonymsZh,
      antonyms: antonyms,
      antonymsZh: antonymsZh,
      examples: examples,
      examplesZh: examplesZh,
    );
    await preferences.setString(cacheKey, jsonEncode({
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
      'entry': entry.toJson(),
    }));
    return entry;
  }

  WordEntry? _readCache(String? value) {
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(json['cachedAt'] as String);
      if (DateTime.now().toUtc().difference(cachedAt) > _cacheLifetime) {
        return null;
      }
      return WordEntry.fromJson(json['entry'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String? _phoneticFor(List<Map<String, dynamic>> phonetics, String suffix) {
    for (final item in phonetics) {
      final audio = item['audio'] as String? ?? '';
      final text = item['text'] as String? ?? '';
      if (audio.toLowerCase().contains(suffix) && text.isNotEmpty) return text;
    }
    return null;
  }

  List<String> _findExamples(List<Map<String, dynamic>> meanings) {
    final examples = <String>[];
    for (final meaning in meanings) {
      for (final item in (meaning['definitions'] as List? ?? const [])) {
        final example = (item as Map<String, dynamic>)['example'] as String?;
        if (example != null && example.isNotEmpty && !examples.contains(example)) {
          examples.add(example);
        }
      }
    }
    return examples;
  }

  Future<String> _translate(String text) async {
    try {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {
        'q': text,
        'langpair': 'en|zh-CN',
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return '翻译暂不可用';
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ((data['responseData'] as Map<String, dynamic>)['translatedText']
              as String?) ??
          '翻译暂不可用';
    } catch (_) {
      return '翻译暂不可用';
    }
  }

  String _difficulty(String word, double frequency) {
    if (frequency >= 20 || (frequency == 0 && word.length <= 4)) return 'A1–A2';
    if (frequency >= 5 || word.length <= 7) return 'B1–B2';
    return 'C1–C2';
  }
}
