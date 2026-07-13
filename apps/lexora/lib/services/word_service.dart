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

class LookupFailure {
  const LookupFailure({required this.term, required this.message});

  final String term;
  final String message;
}

class LookupBatchResult {
  const LookupBatchResult({required this.entries, required this.failures});

  final List<WordEntry> entries;
  final List<LookupFailure> failures;
}

class WordService {
  WordService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _cachePrefix = 'lexora.word.v4';
  static const _cacheLifetime = Duration(days: 14);

  /// Looks up several words concurrently while preserving their input order.
  ///
  /// Dictionary work is network-bound, so a small pool of asynchronous workers
  /// is faster and lighter than creating CPU isolates. The limit also avoids
  /// overwhelming the public dictionary and translation services.
  Future<LookupBatchResult> lookupAll(
    List<String> terms, {
    int exampleCount = 1,
    int maxConcurrency = 4,
    void Function(int completed, int total, String term)? onProgress,
  }) async {
    if (terms.isEmpty) {
      return const LookupBatchResult(entries: [], failures: []);
    }
    final results = List<WordEntry?>.filled(terms.length, null);
    final failures = List<LookupFailure?>.filled(terms.length, null);
    var nextIndex = 0;
    var completed = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= terms.length) return;
        final term = terms[index];
        try {
          results[index] = await lookup(term, exampleCount: exampleCount);
        } catch (error) {
          failures[index] = LookupFailure(
            term: term,
            message: error is WordLookupException
                ? error.message
                : error.toString(),
          );
        } finally {
          completed++;
          onProgress?.call(completed, terms.length, term);
        }
      }
    }

    final workerCount = min(max(1, maxConcurrency), terms.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return LookupBatchResult(
      entries: results.whereType<WordEntry>().toList(),
      failures: failures.whereType<LookupFailure>().toList(),
    );
  }

  Future<WordEntry> lookup(String rawWord, {int exampleCount = 1}) async {
    final word = _normalizeTerm(rawWord);
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
      'md': 'dfr',
      'ipa': '1',
      'max': '30',
    });
    final exactUri = Uri.https('api.datamuse.com', '/words', {
      'sp': word,
      'qe': 'sp',
      'md': 'dfr',
      'ipa': '1',
      'max': '8',
    });

    final responses = await Future.wait([
      _client.get(dictionaryUri).timeout(const Duration(seconds: 15)),
      _client.get(relatedUri).timeout(const Duration(seconds: 15)),
      _client.get(exactUri).timeout(const Duration(seconds: 15)),
    ]);

    Map<String, dynamic>? dictionary;
    if (responses.first.statusCode == 200) {
      try {
        final decoded = _decodeJson(responses.first) as List;
        if (decoded.isNotEmpty) {
          dictionary = decoded.first as Map<String, dynamic>;
        }
      } catch (_) {
        dictionary = null;
      }
    }

    final meanings = (dictionary?['meanings'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final definitions = meanings.isEmpty
        ? <Map<String, dynamic>>[]
        : (meanings.first['definitions'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
    final primary = definitions.isEmpty
        ? <String, dynamic>{}
        : definitions.first;
    final related = _decodeDatamuse(responses[1]);
    final exactResults = _decodeDatamuse(responses[2]);
    final exact = _exactDatamuseItem(exactResults, word);
    final dictionaryDefinition = primary['definition'] as String? ?? '';
    final datamuseDefinition = _definitionFromDatamuse(exact);
    final definition = dictionaryDefinition.isNotEmpty
        ? dictionaryDefinition
        : datamuseDefinition;
    if (definition.isEmpty) {
      throw WordLookupException('No dictionary entry was found for “$word”.');
    }
    final examples = _findExamples(meanings).take(exampleCount).toList();

    final phonetics = (dictionary?['phonetics'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final phonetic = dictionary?['phonetic'] as String? ?? '';
    final datamusePhonetic = _metadataTag(exact, 'pron:');
    final fallbackPhonetic =
        phonetic.isEmpty ? datamusePhonetic : phonetic;
    final usPhonetic = _phoneticFor(phonetics, '-us') ?? fallbackPhonetic;
    final ukPhonetic = _phoneticFor(phonetics, '-uk') ?? fallbackPhonetic;

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

    var frequency = _frequencyFromDatamuse(exact);
    final phraseDrafts = <MapEntry<String, String>>[];
    final seenPhrases = <String>{};
    for (final item in related) {
      final relatedWord = _normalizeTerm(item['word'] as String? ?? '');
      if (relatedWord.isEmpty) continue;
      if (relatedWord == word && frequency == 0) {
        frequency = _frequencyFromDatamuse(item);
      } else if (!relatedWord.contains(' ') && sameMeaning.length < 6) {
        sameMeaning.add(relatedWord);
      }
      if (relatedWord != word &&
          relatedWord.contains(' ') &&
          seenPhrases.add(relatedWord)) {
        final meaning = _definitionFromDatamuse(item);
        if (meaning.isNotEmpty) {
          phraseDrafts.add(MapEntry(relatedWord, meaning));
        }
      }
    }

    final synonyms = sameMeaning.toSet().take(6).toList();
    final antonyms = opposites.toSet().take(6).toList();
    final translations = await Future.wait([
      _translate(definition),
      ...examples.map(_translate),
      if (synonyms.isNotEmpty) _translate(synonyms.join(', ')),
      if (antonyms.isNotEmpty) _translate(antonyms.join(', ')),
      ...phraseDrafts.take(3).map((item) => _translate(item.value)),
    ]);
    var translationIndex = 0;
    final definitionZh = translations[translationIndex++];
    final examplesZh = [
      for (var i = 0; i < examples.length; i++) translations[translationIndex++],
    ];
    final synonymsZh = synonyms.isEmpty ? '' : translations[translationIndex++];
    final antonymsZh = antonyms.isEmpty ? '' : translations[translationIndex++];
    final phrases = <PhraseEntry>[
      for (final phrase in phraseDrafts.take(3))
        PhraseEntry(
          phrase: phrase.key,
          meaning: phrase.value,
          meaningZh: translations[translationIndex++],
        ),
    ];

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
      phrases: phrases,
    );
    await preferences.setString(cacheKey, jsonEncode({
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
      'entry': entry.toJson(),
    }));
    return entry;
  }

  String _normalizeTerm(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  List<Map<String, dynamic>> _decodeDatamuse(http.Response response) {
    if (response.statusCode != 200) return const [];
    try {
      return (_decodeJson(response) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic>? _exactDatamuseItem(
    List<Map<String, dynamic>> results,
    String term,
  ) {
    for (final item in results) {
      if (_normalizeTerm(item['word'] as String? ?? '') == term) return item;
    }
    return null;
  }

  String _definitionFromDatamuse(Map<String, dynamic>? item) {
    final definitions = (item?['defs'] as List? ?? const [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty);
    if (definitions.isEmpty) return '';
    final first = definitions.first;
    final separator = first.indexOf('\t');
    return separator >= 0 ? first.substring(separator + 1).trim() : first;
  }

  String _metadataTag(Map<String, dynamic>? item, String prefix) {
    final tags = (item?['tags'] as List? ?? const [])
        .map((value) => value.toString());
    for (final tag in tags) {
      if (tag.startsWith(prefix)) return tag.substring(prefix.length).trim();
    }
    return '';
  }

  double _frequencyFromDatamuse(Map<String, dynamic>? item) =>
      double.tryParse(_metadataTag(item, 'f:')) ?? 0;

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
      final data = _decodeJson(response) as Map<String, dynamic>;
      return ((data['responseData'] as Map<String, dynamic>)['translatedText']
              as String?) ??
          '翻译暂不可用';
    } catch (_) {
      return '翻译暂不可用';
    }
  }

  dynamic _decodeJson(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes));

  String _difficulty(String word, double frequency) {
    final letterCount = word.replaceAll(' ', '').length;
    if (frequency >= 20 || (frequency == 0 && letterCount <= 4)) return 'A1–A2';
    if (frequency >= 5 || letterCount <= 7) return 'B1–B2';
    return 'C1–C2';
  }
}
