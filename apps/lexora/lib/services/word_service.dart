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

class FuzzyMatch {
  const FuzzyMatch({required this.term, required this.matchedTerm});

  final String term;
  final String matchedTerm;
}

class LookupBatchResult {
  const LookupBatchResult({
    required this.entries,
    required this.failures,
    required this.fuzzyMatches,
  });

  final List<WordEntry> entries;
  final List<LookupFailure> failures;
  final List<FuzzyMatch> fuzzyMatches;
}

class WordService {
  WordService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  // Bump the cache when provider/fallback semantics change so incomplete
  // results from older releases do not keep causing exact words to fail.
  static const _cachePrefix = 'lexora.word.v5';
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
      return const LookupBatchResult(
        entries: [],
        failures: [],
        fuzzyMatches: [],
      );
    }
    final results = List<WordEntry?>.filled(terms.length, null);
    final failures = List<LookupFailure?>.filled(terms.length, null);
    final fuzzyMatches = List<FuzzyMatch?>.filled(terms.length, null);
    var nextIndex = 0;
    var completed = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= terms.length) return;
        final term = terms[index];
        try {
          results[index] = await lookup(term, exampleCount: exampleCount);
        } on WordLookupException catch (exactError) {
          final fuzzyResult = await _lookupFuzzy(
            term,
            exampleCount: exampleCount,
          );
          if (fuzzyResult != null) {
            final matchedEntry = fuzzyResult.entry.withOriginalTerm(term);
            results[index] = matchedEntry;
            fuzzyMatches[index] = FuzzyMatch(
              term: term,
              matchedTerm: matchedEntry.word,
            );
          } else {
            failures[index] = LookupFailure(
              term: term,
              message: exactError.message,
            );
          }
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
      fuzzyMatches: fuzzyMatches.whereType<FuzzyMatch>().toList(),
    );
  }

  Future<_FuzzyLookupResult?> _lookupFuzzy(
    String rawTerm, {
    required int exampleCount,
  }) async {
    final term = _normalizeTerm(rawTerm);
    if (term.isEmpty) return null;
    try {
      final suggestionUri = Uri.https('api.datamuse.com', '/sug', {
        's': term,
        'max': '12',
      });
      final response = await _getWithRetry(
        suggestionUri,
        timeout: const Duration(seconds: 10),
      );
      if (response == null) return null;
      final suggestions =
          _decodeDatamuse(response)
              .map((item) => _normalizeTerm(item['word'] as String? ?? ''))
              .where((candidate) => _isSafeFuzzyMatch(term, candidate))
              .toSet()
              .toList()
            ..sort(
              (left, right) => _editDistance(
                term,
                left,
              ).compareTo(_editDistance(term, right)),
            );

      for (final candidate in suggestions.take(3)) {
        try {
          final entry = await lookup(candidate, exampleCount: exampleCount);
          return _FuzzyLookupResult(entry);
        } on WordLookupException {
          // A spelling suggestion still needs a complete dictionary result.
        }
      }
    } catch (_) {
      // Fuzzy lookup is an optional fallback; preserve the original failure.
    }
    return null;
  }

  bool _isSafeFuzzyMatch(String term, String candidate) {
    if (candidate.isEmpty || candidate == term) return false;
    if (term.split(' ').length != candidate.split(' ').length) return false;
    final distance = _editDistance(term, candidate);
    final longest = max(term.length, candidate.length);
    final maxDistance = longest <= 4 ? 1 : (longest <= 8 ? 2 : 3);
    final similarity = longest == 0 ? 0 : 1 - (distance / longest);
    return distance <= maxDistance && similarity >= 0.78;
  }

  int _editDistance(String left, String right) {
    final previous = List<int>.generate(right.length + 1, (index) => index);
    for (var leftIndex = 1; leftIndex <= left.length; leftIndex++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = leftIndex;
      for (var rightIndex = 1; rightIndex <= right.length; rightIndex++) {
        final substitutionCost = left[leftIndex - 1] == right[rightIndex - 1]
            ? 0
            : 1;
        current[rightIndex] = min(
          min(current[rightIndex - 1] + 1, previous[rightIndex] + 1),
          previous[rightIndex - 1] + substitutionCost,
        );
      }
      for (var index = 0; index < current.length; index++) {
        previous[index] = current[index];
      }
    }
    return previous.last;
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
      'md': 'dfrp',
      'ipa': '1',
      'max': '8',
    });
    final synonymsUri = Uri.https('api.datamuse.com', '/words', {
      'rel_syn': word,
      'md': 'f',
      'max': '12',
    });
    final antonymsUri = Uri.https('api.datamuse.com', '/words', {
      'rel_ant': word,
      'max': '12',
    });

    // Every provider is isolated. Previously one timeout in the optional
    // related-word request made Future.wait discard a perfectly valid exact
    // dictionary response (even for common words such as "word").
    final responses = await Future.wait([
      _getWithRetry(dictionaryUri),
      _getWithRetry(relatedUri),
      _getWithRetry(exactUri),
      _getWithRetry(synonymsUri),
      _getWithRetry(antonymsUri),
    ]);
    final dictionaryResponse = responses[0];
    final relatedResponse = responses[1];
    final exactResponse = responses[2];
    final synonymsResponse = responses[3];
    final antonymsResponse = responses[4];

    Map<String, dynamic>? dictionary;
    if (dictionaryResponse?.statusCode == 200) {
      try {
        final decoded = _decodeJson(dictionaryResponse!) as List;
        if (decoded.isNotEmpty) {
          dictionary = decoded.first as Map<String, dynamic>;
        }
      } catch (_) {
        dictionary = null;
      }
    }

    final meanings = (dictionary?['meanings'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final definitions = meanings
        .expand(
          (meaning) => (meaning['definitions'] as List? ?? const [])
              .cast<Map<String, dynamic>>(),
        )
        .toList();
    final primary = definitions.firstWhere(
      (item) => (item['definition'] as String? ?? '').trim().isNotEmpty,
      orElse: () => <String, dynamic>{},
    );
    final related = _decodeDatamuseNullable(relatedResponse);
    final exactResults = _decodeDatamuseNullable(exactResponse);
    final datamuseSynonyms = _decodeDatamuseNullable(synonymsResponse);
    final datamuseAntonyms = _decodeDatamuseNullable(antonymsResponse);
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
    final fallbackPhonetic = phonetic.isEmpty ? datamusePhonetic : phonetic;
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
    sameMeaning.addAll(
      datamuseSynonyms
          .map((item) => _normalizeTerm(item['word'] as String? ?? ''))
          .where((item) => item.isNotEmpty && item != word),
    );
    opposites.addAll(
      datamuseAntonyms
          .map((item) => _normalizeTerm(item['word'] as String? ?? ''))
          .where((item) => item.isNotEmpty && item != word),
    );

    var frequency = _frequencyFromDatamuse(exact);
    final phraseDrafts = <MapEntry<String, String>>[];
    final seenPhrases = <String>{};
    for (final item in related) {
      final relatedWord = _normalizeTerm(item['word'] as String? ?? '');
      if (relatedWord.isEmpty) continue;
      if (relatedWord == word && frequency == 0) {
        frequency = _frequencyFromDatamuse(item);
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
      for (var i = 0; i < examples.length; i++)
        translations[translationIndex++],
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
    await preferences.setString(
      cacheKey,
      jsonEncode({
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
        'entry': entry.toJson(),
      }),
    );
    return entry;
  }

  String _normalizeTerm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  List<Map<String, dynamic>> _decodeDatamuse(http.Response response) {
    if (response.statusCode != 200) return const [];
    try {
      return (_decodeJson(response) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> _decodeDatamuseNullable(http.Response? response) =>
      response == null ? const [] : _decodeDatamuse(response);

  Future<http.Response?> _getWithRetry(
    Uri uri, {
    Duration timeout = const Duration(seconds: 15),
    int attempts = 2,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final response = await _client.get(uri).timeout(timeout);
        if (response.statusCode < 500 || attempt == attempts - 1) {
          return response;
        }
      } catch (_) {
        if (attempt == attempts - 1) return null;
      }
      await Future<void>.delayed(Duration(milliseconds: 180 * (attempt + 1)));
    }
    return null;
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
    final tags = (item?['tags'] as List? ?? const []).map(
      (value) => value.toString(),
    );
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
        if (example != null &&
            example.isNotEmpty &&
            !examples.contains(example)) {
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
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
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

class _FuzzyLookupResult {
  const _FuzzyLookupResult(this.entry);

  final WordEntry entry;
}
