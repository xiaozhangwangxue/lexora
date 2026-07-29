import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_entry.dart';
import 'developer_log_service.dart';
import 'offline_lexicon_service.dart';

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
  WordService({http.Client? client, OfflineLexiconSource? offlineLexicon})
    : _client = client ?? http.Client(),
      _offlineLexicon = offlineLexicon ?? OfflineLexiconService.instance;

  final http.Client _client;
  final OfflineLexiconSource _offlineLexicon;
  final Map<String, WordEntry> _memoryCache = {};
  final Map<String, Future<WordEntry>> _inFlightLookups = {};
  final Map<String, List<String>> _suggestionCache = {};
  final Map<String, Future<List<String>>> _inFlightSuggestions = {};
  final Map<String, String> _translationCache = {};
  final Map<String, Future<String>> _inFlightTranslations = {};
  final Map<String, List<http.Response?>> _sourceCache = {};
  final Map<String, Future<List<http.Response?>>> _inFlightSourceLookups = {};
  final Map<String, http.Response?> _providerCache = {};
  final Map<String, Future<http.Response?>> _inFlightProviders = {};
  final Map<String, WordEntry> _coreCache = {};
  final Map<String, Future<WordEntry>> _inFlightCoreLookups = {};
  final Map<String, WordEntry> _englishCache = {};
  final Map<String, Future<WordEntry>> _inFlightEnglishLookups = {};
  final Queue<Completer<void>> _translationWaiters = Queue();
  int _activeTranslations = 0;
  String? _retainedLookupKey;
  // Bump the cache when provider/fallback semantics change so incomplete
  // results from older releases do not keep causing exact words to fail.
  static const _cachePrefix = 'lexora.word.v9';
  static const _cacheLifetime = Duration(days: 14);
  static const _translationUnavailable = '翻译暂不可用';
  static const _maxTranslationConcurrency = 2;
  static const _openLexiconHost = 'dict.12323456.xyz';

  /// Returns the essential dictionary result without waiting for optional
  /// translations, related words, phrases, synonyms or antonyms.
  ///
  /// The search UI renders immediately and uses this future to replace its
  /// lightweight placeholder. [lookup] can run alongside it; provider-level
  /// in-flight de-duplication prevents duplicate backend requests.
  Future<WordEntry> lookupCore(String rawWord, {int exampleCount = 1}) async {
    final word = _normalizeTerm(rawWord);
    final fullKey = '$exampleCount|$word';
    final full = _memoryCache[fullKey];
    if (full != null) {
      DeveloperLogService.instance.log(
        'search.core.cache_hit',
        data: {'term': word, 'source': 'full-memory'},
      );
      return full;
    }
    final cached = _coreCache[word];
    if (cached != null) {
      DeveloperLogService.instance.log(
        'search.core.cache_hit',
        data: {'term': word, 'source': 'core-memory'},
      );
      return cached;
    }
    return _inFlightCoreLookups.putIfAbsent(word, () async {
      final stopwatch = Stopwatch()..start();
      DeveloperLogService.instance.log(
        'search.core.started',
        data: {'term': word, 'exampleCount': exampleCount},
      );
      try {
        final offlinePayload = await _offlineLexicon.lookup(word);
        if (offlinePayload != null) {
          try {
            final lexiconResponses = _coreResponsesFromLexicon(
              _lexiconPayloadResponse(offlinePayload),
              word,
            );
            final entry = _coreEntryFromResponses(
              word,
              lexiconResponses[0],
              lexiconResponses[1],
              exampleCount: exampleCount,
            );
            _coreCache[word] = entry;
            DeveloperLogService.instance.log(
              'search.core.completed',
              data: {
                'term': word,
                'durationMs': stopwatch.elapsedMilliseconds,
                'source': 'offline-lexicon',
                'definitionChars': entry.definition.length,
                'senses': entry.senses.length,
                'examples': entry.examples.length,
                'hasPrimaryTranslation': entry.definitionZh.isNotEmpty,
              },
            );
            return entry;
          } catch (error, stackTrace) {
            DeveloperLogService.instance.log(
              'search.core.offline_lexicon_invalid',
              data: {'term': word},
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
        final uris = _providerUris(word);
        http.Response? dictionaryResponse;
        http.Response? exactResponse;
        final dictionaryFuture =
            _providerResponse(
              word,
              'dictionary',
              uris.dictionary,
              timeout: const Duration(seconds: 5),
              attempts: 1,
            ).then((response) {
              dictionaryResponse = response;
              return response;
            });
        final exactFuture =
            _providerResponse(
              word,
              'exact',
              uris.exact,
              timeout: const Duration(seconds: 4),
              attempts: 1,
            ).then((response) {
              exactResponse = response;
              return response;
            });
        final lexiconFuture = _providerResponse(
          word,
          'open-lexicon',
          Uri.https(_openLexiconHost, '/v1/lookup', {'term': word}),
          timeout: const Duration(milliseconds: 1200),
          attempts: 1,
        );
        final edgeFuture = _firstSuccessfulEdgeGet(
          [
            Uri.https('lexora.12323456.xyz', '/api/dictionary/core', {
              'term': word,
            }),
            Uri.https(
              'lexora-official.xiaozhangwangxue.workers.dev',
              '/api/dictionary/core',
              {'term': word},
            ),
          ],
          timeout: const Duration(milliseconds: 1500),
          operation: 'edge-core',
          term: word,
        );
        final firstCandidate = Completer<WordEntry>();
        var completedSource = '';

        void offer(
          String source,
          http.Response? dictionary,
          http.Response? exact,
        ) {
          if (firstCandidate.isCompleted) return;
          try {
            final entry = _coreEntryFromResponses(
              word,
              dictionary,
              exact,
              exampleCount: exampleCount,
            );
            completedSource = source;
            firstCandidate.complete(entry);
          } catch (_) {
            // Another concurrently running provider may still yield a result.
          }
        }

        unawaited(
          lexiconFuture.then((response) {
            if (response?.statusCode != 200) return;
            try {
              final lexiconResponses = _coreResponsesFromLexicon(
                response!,
                word,
              );
              offer('open-lexicon', lexiconResponses[0], lexiconResponses[1]);
            } catch (error, stackTrace) {
              DeveloperLogService.instance.log(
                'search.core.open_lexicon_invalid',
                data: {'term': word},
                error: error,
                stackTrace: stackTrace,
              );
            }
          }),
        );
        unawaited(
          dictionaryFuture.then(
            (response) => offer('dictionary-direct', response, exactResponse),
          ),
        );
        unawaited(
          exactFuture.then(
            (response) =>
                offer('datamuse-direct', dictionaryResponse, response),
          ),
        );
        unawaited(
          edgeFuture.then((response) {
            if (response?.statusCode != 200) return;
            try {
              final edgeResponses = _coreResponsesFromEdge(response!);
              offer('cloudflare-edge', edgeResponses[0], edgeResponses[1]);
            } catch (error, stackTrace) {
              DeveloperLogService.instance.log(
                'search.core.edge_invalid',
                data: {'term': word},
                error: error,
                stackTrace: stackTrace,
              );
            }
          }),
        );

        // Return whichever valid source wins instead of always waiting for a
        // slower edge request. Direct provider futures remain shared with the
        // complete lookup and continue safely in the background.
        final remainingMilliseconds = max(
          1,
          1800 - stopwatch.elapsedMilliseconds,
        );
        final entry = await firstCandidate.future.timeout(
          Duration(milliseconds: remainingMilliseconds),
          onTimeout: () => _coreEntryFromResponses(
            word,
            dictionaryResponse,
            exactResponse,
            exampleCount: exampleCount,
          ),
        );
        _coreCache[word] = entry;
        DeveloperLogService.instance.log(
          'search.core.completed',
          data: {
            'term': word,
            'durationMs': stopwatch.elapsedMilliseconds,
            'source': completedSource.isEmpty
                ? 'partial-timeout'
                : completedSource,
            'definitionChars': entry.definition.length,
            'senses': entry.senses.length,
            'examples': entry.examples.length,
            'hasPrimaryTranslation': entry.definitionZh.isNotEmpty,
          },
        );
        return entry;
      } catch (error, stackTrace) {
        DeveloperLogService.instance.log(
          'search.core.failed',
          data: {'term': word, 'durationMs': stopwatch.elapsedMilliseconds},
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      } finally {
        _inFlightCoreLookups.remove(word);
      }
    });
  }

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

  /// Returns every available English section without waiting for translation.
  /// This is the second progressive search stage after [lookupCore].
  Future<WordEntry> lookupEnglish(
    String rawWord, {
    int exampleCount = 1,
  }) async {
    final word = _normalizeTerm(rawWord);
    final key = '$exampleCount|$word';
    final full = _memoryCache[key];
    if (full != null) return full;
    final cached = _englishCache[key];
    if (cached != null) return cached;
    return _inFlightEnglishLookups.putIfAbsent(key, () async {
      final stopwatch = Stopwatch()..start();
      DeveloperLogService.instance.log(
        'search.english.started',
        data: {'term': word, 'exampleCount': exampleCount},
      );
      try {
        final entry = await _lookupUncached(
          word,
          exampleCount: exampleCount,
          lookupKey: key,
          translate: false,
        );
        _englishCache[key] = entry;
        DeveloperLogService.instance.log(
          'search.english.completed',
          data: {
            'term': word,
            'durationMs': stopwatch.elapsedMilliseconds,
            'senses': entry.senses.length,
            'relatedWords': entry.relatedWords.length,
            'synonyms': entry.synonyms.length,
            'antonyms': entry.antonyms.length,
            'examples': entry.examples.length,
            'phrases': entry.phrases.length,
          },
        );
        return entry;
      } finally {
        _inFlightEnglishLookups.remove(key);
      }
    });
  }

  Future<List<String>> suggest(String rawTerm, {int maxResults = 12}) async {
    final term = _normalizeTerm(rawTerm);
    if (term.isEmpty) return const [];
    final key = '$maxResults|$term';
    final cached = _suggestionCache[key];
    if (cached != null) {
      DeveloperLogService.instance.log(
        'search.suggestions.cache_hit',
        data: {'term': term, 'count': cached.length},
      );
      return cached;
    }
    return _inFlightSuggestions.putIfAbsent(key, () async {
      final stopwatch = Stopwatch()..start();
      DeveloperLogService.instance.log(
        'search.suggestions.started',
        data: {'term': term, 'maxResults': maxResults},
      );
      try {
        final suggestions = await _fetchSuggestions(
          term,
          maxResults: maxResults,
        );
        _suggestionCache[key] = suggestions;
        DeveloperLogService.instance.log(
          'search.suggestions.completed',
          data: {
            'term': term,
            'durationMs': stopwatch.elapsedMilliseconds,
            'count': suggestions.length,
            'results': suggestions,
          },
        );
        return suggestions;
      } catch (error, stackTrace) {
        DeveloperLogService.instance.log(
          'search.suggestions.failed',
          data: {'term': term, 'durationMs': stopwatch.elapsedMilliseconds},
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      } finally {
        _inFlightSuggestions.remove(key);
      }
    });
  }

  Future<List<String>> _fetchSuggestions(
    String term, {
    required int maxResults,
  }) async {
    final offlineSuggestions =
        (await _offlineLexicon.suggest(
              term,
              limit: max(1, min(maxResults, 24)),
            ))
            .map(
              (item) => _normalizeTerm(
                item['normalized_word']?.toString() ??
                    item['word']?.toString() ??
                    '',
              ),
            )
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false);
    if (offlineSuggestions.isNotEmpty) {
      return offlineSuggestions.take(maxResults).toList(growable: false);
    }
    final directFuture = _getWithRetry(
      Uri.https('api.datamuse.com', '/sug', {
        's': term,
        'max': '${max(1, min(maxResults, 24))}',
      }),
      timeout: const Duration(seconds: 8),
      operation: 'suggestions',
      term: term,
    );
    final lexiconResponse = await _getWithRetry(
      Uri.https(_openLexiconHost, '/v1/suggest', {
        'prefix': term,
        'limit': '${max(1, min(maxResults, 24))}',
      }),
      timeout: const Duration(milliseconds: 1200),
      attempts: 1,
      operation: 'open-lexicon-suggestions',
      term: term,
    );
    final lexiconSuggestions = _decodeLexiconSuggestions(lexiconResponse);
    if (lexiconSuggestions.isNotEmpty) {
      return lexiconSuggestions.take(maxResults).toList(growable: false);
    }
    final response = await directFuture;
    if (response == null) return const [];
    return _decodeDatamuse(response)
        .map((item) => _normalizeTerm(item['word'] as String? ?? ''))
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(maxResults)
        .toList(growable: false);
  }

  List<String> _decodeLexiconSuggestions(http.Response? response) {
    if (response?.statusCode != 200) return const [];
    try {
      final values = _decodeJson(response!) as List;
      return values
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => _normalizeTerm(
              item['normalized_word']?.toString() ??
                  item['word']?.toString() ??
                  '',
            ),
          )
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> prefetch(String rawWord, {int exampleCount = 1}) async {
    try {
      await lookup(rawWord, exampleCount: exampleCount);
    } catch (_) {
      // Prefetching is opportunistic; the explicit search reports errors.
    }
  }

  /// Warms every visible suggestion with a bounded network worker pool.
  Future<void> prefetchAll(
    Iterable<String> rawTerms, {
    int exampleCount = 3,
    int maxConcurrency = 4,
  }) async {
    final terms = rawTerms
        .map(_normalizeTerm)
        .where((term) => term.isNotEmpty)
        .toSet()
        .toList(growable: false);
    var next = 0;

    Future<void> worker() async {
      while (next < terms.length) {
        final term = terms[next++];
        await prefetch(term, exampleCount: exampleCount);
      }
    }

    final workers = min(max(1, maxConcurrency), terms.length);
    await Future.wait(List.generate(workers, (_) => worker()));
  }

  /// Warms only the lightweight core result for at most three likely
  /// suggestions. Full related-word and translation requests are deliberately
  /// deferred until the user actually submits a term, otherwise typing can
  /// consume the same network connections needed by the selected result.
  Future<void> prefetchCandidates(
    Iterable<String> rawTerms, {
    int maxCandidates = 3,
  }) async {
    final terms = rawTerms
        .map(_normalizeTerm)
        .where((term) => term.isNotEmpty)
        .toSet()
        .take(max(1, min(maxCandidates, 3)))
        .toList(growable: false);
    if (terms.isEmpty) return;

    await Future.wait(
      terms.map((term) async {
        try {
          await lookupCore(term, exampleCount: 1);
        } catch (_) {
          // Suggestion prefetching is opportunistic.
        }
      }),
    );
  }

  /// Starts a new suggestion session in which candidates may be cached.
  void allowSuggestionCaching() {
    _retainedLookupKey = null;
  }

  /// Keeps only the selected result after an explicit search.
  ///
  /// In-flight suggestion requests check the retained key before writing, so a
  /// late candidate cannot silently repopulate the cache after this cleanup.
  Future<void> retainOnly(String rawWord, {int exampleCount = 3}) async {
    final word = _normalizeTerm(rawWord);
    final lookupKey = '$exampleCount|$word';
    final persistentKey = '$_cachePrefix.$exampleCount.$word';
    _retainedLookupKey = lookupKey;
    _memoryCache.removeWhere((key, _) => key != lookupKey);
    _suggestionCache.clear();
    _sourceCache.removeWhere((key, _) => key != word);
    _inFlightSourceLookups.removeWhere((key, _) => key != word);
    _providerCache.removeWhere((key, _) => !key.startsWith('$word|'));
    _inFlightProviders.removeWhere((key, _) => !key.startsWith('$word|'));
    _coreCache.removeWhere((key, _) => key != word);
    _inFlightCoreLookups.removeWhere((key, _) => key != word);
    _englishCache.removeWhere((key, _) => key != lookupKey);
    _inFlightEnglishLookups.removeWhere((key, _) => key != lookupKey);

    final preferences = await SharedPreferences.getInstance();
    final obsolete = preferences.getKeys().where(
      (key) => key.startsWith('lexora.word.') && key != persistentKey,
    );
    await Future.wait(obsolete.map(preferences.remove));
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
        operation: 'fuzzy-suggestions',
        term: term,
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
    final key = '$exampleCount|$word';
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null) {
      DeveloperLogService.instance.log(
        'search.full.cache_hit',
        data: {'term': word, 'exampleCount': exampleCount, 'source': 'memory'},
      );
      return memoryEntry;
    }
    return _inFlightLookups.putIfAbsent(key, () async {
      final stopwatch = Stopwatch()..start();
      DeveloperLogService.instance.log(
        'search.full.started',
        data: {'term': word, 'exampleCount': exampleCount},
      );
      try {
        final entry = await _lookupUncached(
          word,
          exampleCount: exampleCount,
          lookupKey: key,
        );
        if (_retainedLookupKey == null || _retainedLookupKey == key) {
          _memoryCache[key] = entry;
        }
        _coreCache[word] = entry;
        DeveloperLogService.instance.log(
          'search.full.completed',
          data: {
            'term': word,
            'durationMs': stopwatch.elapsedMilliseconds,
            'senses': entry.senses.length,
            'synonyms': entry.synonyms.length,
            'antonyms': entry.antonyms.length,
            'examples': entry.examples.length,
            'phrases': entry.phrases.length,
            'relatedWords': entry.relatedWords.length,
          },
        );
        return entry;
      } catch (error, stackTrace) {
        DeveloperLogService.instance.log(
          'search.full.failed',
          data: {
            'term': word,
            'exampleCount': exampleCount,
            'durationMs': stopwatch.elapsedMilliseconds,
          },
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      } finally {
        _inFlightLookups.remove(key);
      }
    });
  }

  Future<WordEntry> _lookupUncached(
    String word, {
    required int exampleCount,
    required String lookupKey,
    bool translate = true,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix.$exampleCount.$word';
    final cached = _readCache(preferences.getString(cacheKey));
    if (cached != null) {
      DeveloperLogService.instance.log(
        'search.full.cache_hit',
        data: {
          'term': word,
          'exampleCount': exampleCount,
          'source': 'persistent',
        },
      );
      return cached;
    }
    // Every provider is isolated. Previously one timeout in the optional
    // related-word request made Future.wait discard a perfectly valid exact
    // dictionary response (even for common words such as "word").
    final responses = await _lookupSources(word);
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
    final senseDrafts = <MapEntry<String, List<String>>>[];
    for (final meaning in meanings.take(6)) {
      final partOfSpeech = (meaning['partOfSpeech'] as String? ?? '').trim();
      final items = (meaning['definitions'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((item) => (item['definition'] as String? ?? '').trim())
          .where((item) => item.isNotEmpty)
          .take(3)
          .toList(growable: false);
      if (items.isNotEmpty) {
        senseDrafts.add(MapEntry(partOfSpeech, items));
      }
    }
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
    final datamusePhonetic = _arpabetToIpa(_metadataTag(exact, 'pron:'));
    final fallbackPhonetic = phonetic.isEmpty ? datamusePhonetic : phonetic;
    final usPhonetic = _arpabetToIpa(
      _phoneticFor(phonetics, '-us') ?? fallbackPhonetic,
    );
    final ukPhonetic = _arpabetToIpa(
      _phoneticFor(phonetics, '-uk') ?? fallbackPhonetic,
    );

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
    final relatedDrafts = <MapEntry<String, String>>[];
    final seenPhrases = <String>{};
    final seenRelated = <String>{word};
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
      } else if (!relatedWord.contains(' ') &&
          seenRelated.add(relatedWord) &&
          relatedDrafts.length < 8) {
        final meaning = _definitionFromDatamuse(item);
        if (meaning.isNotEmpty) {
          relatedDrafts.add(MapEntry(relatedWord, meaning));
        }
      }
    }

    final synonyms = sameMeaning.toSet().take(6).toList();
    final antonyms = opposites.toSet().take(6).toList();
    final richDefinitions = senseDrafts
        .expand((sense) => sense.value)
        .toList(growable: false);
    if (!translate) {
      return WordEntry(
        word: word,
        difficulty: _difficulty(word, frequency),
        frequency: frequency,
        usPhonetic: usPhonetic.isEmpty ? '—' : usPhonetic,
        ukPhonetic: ukPhonetic.isEmpty ? '—' : ukPhonetic,
        definition: definition,
        definitionZh: _translationCache[definition] ?? '',
        synonyms: synonyms,
        synonymsZh: '',
        antonyms: antonyms,
        antonymsZh: '',
        examples: examples,
        examplesZh: const [],
        phrases: [
          for (final phrase in phraseDrafts.take(3))
            PhraseEntry(
              phrase: phrase.key,
              meaning: phrase.value,
              meaningZh: '',
            ),
        ],
        senses: [
          for (final sense in senseDrafts)
            WordSense(
              partOfSpeech: sense.key,
              definitions: [
                for (final item in sense.value)
                  BilingualDefinition(
                    definition: item,
                    definitionZh: _translationCache[item] ?? '',
                  ),
              ],
            ),
        ],
        relatedWords: [
          for (final related in relatedDrafts)
            RelatedWord(
              word: related.key,
              meaning: related.value,
              meaningZh: '',
            ),
        ],
      );
    }
    DeveloperLogService.instance.log(
      'search.translation_batch.queued',
      data: {
        'term': word,
        'definition': definition.isEmpty ? 0 : 1,
        'examples': examples.length,
        'synonyms': synonyms.length,
        'antonyms': antonyms.length,
        'phrases': phraseDrafts.take(3).length,
        'senseDefinitions': richDefinitions.length,
        'relatedWords': relatedDrafts.length,
        'total':
            1 +
            examples.length +
            synonyms.length +
            antonyms.length +
            phraseDrafts.take(3).length +
            richDefinitions.length +
            relatedDrafts.length,
      },
    );
    final translationStopwatch = Stopwatch()..start();
    final translationInputs = [
      definition,
      ...examples,
      ...synonyms,
      ...antonyms,
      ...phraseDrafts.take(3).map((item) => item.value),
      ...richDefinitions,
      ...relatedDrafts.map((item) => item.value),
    ];
    final translations = await _translateBatch(translationInputs);
    DeveloperLogService.instance.log(
      'search.translation_batch.completed',
      data: {
        'term': word,
        'durationMs': translationStopwatch.elapsedMilliseconds,
        'results': translations.length,
        'unavailable': translations
            .where((item) => item == _translationUnavailable)
            .length,
      },
    );
    var translationIndex = 0;
    final definitionZh = translations[translationIndex++];
    final examplesZh = [
      for (var i = 0; i < examples.length; i++)
        translations[translationIndex++],
    ];
    final synonymTranslations = <String, String>{
      for (final synonym in synonyms) synonym: translations[translationIndex++],
    };
    final antonymTranslations = <String, String>{
      for (final antonym in antonyms) antonym: translations[translationIndex++],
    };
    final synonymsZh = synonymTranslations.values.join('、');
    final antonymsZh = antonymTranslations.values.join('、');
    final phrases = <PhraseEntry>[
      for (final phrase in phraseDrafts.take(3))
        PhraseEntry(
          phrase: phrase.key,
          meaning: phrase.value,
          meaningZh: translations[translationIndex++],
        ),
    ];
    final senses = <WordSense>[];
    for (final sense in senseDrafts) {
      senses.add(
        WordSense(
          partOfSpeech: sense.key,
          definitions: [
            for (final definition in sense.value)
              BilingualDefinition(
                definition: definition,
                definitionZh: translations[translationIndex++],
              ),
          ],
        ),
      );
    }
    final relatedWords = <RelatedWord>[
      for (final related in relatedDrafts)
        RelatedWord(
          word: related.key,
          meaning: related.value,
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
      synonymTranslations: synonymTranslations,
      antonyms: antonyms,
      antonymsZh: antonymsZh,
      antonymTranslations: antonymTranslations,
      examples: examples,
      examplesZh: examplesZh,
      phrases: phrases,
      senses: senses,
      relatedWords: relatedWords,
    );
    if (_retainedLookupKey == null || _retainedLookupKey == lookupKey) {
      await preferences.setString(
        cacheKey,
        jsonEncode({
          'cachedAt': DateTime.now().toUtc().toIso8601String(),
          'entry': entry.toJson(),
        }),
      );
    }
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

  Future<http.Response?> _firstSuccessfulEdgeGet(
    List<Uri> uris, {
    required Duration timeout,
    required String operation,
    required String term,
  }) {
    final completer = Completer<http.Response?>();
    var pending = uris.length;
    for (final uri in uris) {
      unawaited(
        _getWithRetry(
              uri,
              timeout: timeout,
              attempts: 1,
              operation: operation,
              term: term,
            )
            .then((response) {
              if (response?.statusCode == 200 && !completer.isCompleted) {
                completer.complete(response);
              }
            })
            .whenComplete(() {
              pending--;
              if (pending == 0 && !completer.isCompleted) {
                completer.complete(null);
              }
            }),
      );
    }
    return completer.future;
  }

  Future<http.Response?> _getWithRetry(
    Uri uri, {
    Duration timeout = const Duration(seconds: 15),
    int attempts = 2,
    String operation = 'http',
    String? term,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final stopwatch = Stopwatch()..start();
      DeveloperLogService.instance.log(
        'backend.request.started',
        data: {
          'operation': operation,
          if (term != null) 'term': term,
          'attempt': attempt + 1,
          'attempts': attempts,
          'timeoutMs': timeout.inMilliseconds,
          'method': 'GET',
          'uri': uri.toString(),
        },
      );
      try {
        final response = await _client.get(uri).timeout(timeout);
        DeveloperLogService.instance.log(
          'backend.request.completed',
          data: {
            'operation': operation,
            if (term != null) 'term': term,
            'attempt': attempt + 1,
            'durationMs': stopwatch.elapsedMilliseconds,
            'status': response.statusCode,
            'bytes': response.bodyBytes.length,
            'headers': response.headers,
            'bodyPreview': _logPreview(
              utf8.decode(response.bodyBytes, allowMalformed: true),
              limit: 1600,
            ),
          },
        );
        if (response.statusCode < 500 || attempt == attempts - 1) {
          return response;
        }
      } catch (error, stackTrace) {
        DeveloperLogService.instance.log(
          'backend.request.failed',
          data: {
            'operation': operation,
            if (term != null) 'term': term,
            'attempt': attempt + 1,
            'durationMs': stopwatch.elapsedMilliseconds,
            'uri': uri.toString(),
          },
          error: error,
          stackTrace: stackTrace,
        );
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

  String _arpabetToIpa(String value) {
    final source = value.trim();
    if (source.isEmpty) return '';
    if (source.contains('/') ||
        RegExp(r'[əɪʊæʌɔɑɛɜɝɚŋθðʃʒ]').hasMatch(source)) {
      return source;
    }
    const vowels = {
      'AA': 'ɑ',
      'AE': 'æ',
      'AO': 'ɔ',
      'AW': 'aʊ',
      'AY': 'aɪ',
      'EH': 'ɛ',
      'EY': 'eɪ',
      'IH': 'ɪ',
      'IY': 'i',
      'OW': 'oʊ',
      'OY': 'ɔɪ',
      'UH': 'ʊ',
      'UW': 'u',
    };
    const consonants = {
      'B': 'b',
      'CH': 'tʃ',
      'D': 'd',
      'DH': 'ð',
      'F': 'f',
      'G': 'ɡ',
      'HH': 'h',
      'JH': 'dʒ',
      'K': 'k',
      'L': 'l',
      'M': 'm',
      'N': 'n',
      'NG': 'ŋ',
      'P': 'p',
      'R': 'ɹ',
      'S': 's',
      'SH': 'ʃ',
      'T': 't',
      'TH': 'θ',
      'V': 'v',
      'W': 'w',
      'Y': 'j',
      'Z': 'z',
      'ZH': 'ʒ',
    };
    final output = StringBuffer();
    for (final rawToken in source.toUpperCase().split(RegExp(r'\s+'))) {
      final match = RegExp(r'^([A-Z]+)([012])?$').firstMatch(rawToken);
      if (match == null) return source;
      final token = match.group(1)!;
      final stress = match.group(2);
      String? sound;
      if (token == 'AH') {
        sound = stress == '0' ? 'ə' : 'ʌ';
      } else if (token == 'ER') {
        sound = stress == '0' ? 'ɚ' : 'ɝ';
      } else {
        sound = vowels[token] ?? consonants[token];
      }
      if (sound == null) return source;
      if (stress == '1') output.write('ˈ');
      if (stress == '2') output.write('ˌ');
      output.write(sound);
    }
    return '/$output/';
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

  Future<List<String>> _translateBatch(List<String> inputs) async {
    final normalized = inputs.map((value) => value.trim()).toList();
    final missing = normalized
        .where(
          (value) => value.isNotEmpty && !_translationCache.containsKey(value),
        )
        .toSet()
        .toList(growable: false);
    if (missing.isNotEmpty) {
      final stopwatch = Stopwatch()..start();
      DeveloperLogService.instance.log(
        'backend.translation_batch.started',
        data: {
          'total': normalized.length,
          'uniqueMissing': missing.length,
          'cached': normalized.length - missing.length,
        },
      );
      final chunks = <List<String>>[
        for (var offset = 0; offset < missing.length; offset += 24)
          missing.sublist(offset, min(offset + 24, missing.length)),
      ];
      final edgeResults = await Future.wait(
        chunks.map(_fetchEdgeTranslationBatch),
      );
      for (var chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
        final chunk = chunks[chunkIndex];
        final edge = edgeResults[chunkIndex];
        if (edge != null) {
          for (var index = 0; index < chunk.length; index++) {
            final translated = edge[index].trim();
            if (translated.isNotEmpty) {
              _translationCache[chunk[index]] = translated;
            }
          }
        }
      }
      final unresolved = missing
          .where((value) => !_translationCache.containsKey(value))
          .toList(growable: false);
      if (unresolved.isNotEmpty) {
        final fallback = await Future.wait(unresolved.map(_translate));
        for (var index = 0; index < unresolved.length; index++) {
          final translated = fallback[index];
          if (translated != _translationUnavailable && translated.isNotEmpty) {
            _translationCache[unresolved[index]] = translated;
          }
        }
      }
      DeveloperLogService.instance.log(
        'backend.translation_batch.completed',
        data: {
          'durationMs': stopwatch.elapsedMilliseconds,
          'requested': missing.length,
          'resolved': missing
              .where((value) => _translationCache.containsKey(value))
              .length,
          'unavailable': missing
              .where((value) => !_translationCache.containsKey(value))
              .length,
        },
      );
    }
    return normalized
        .map(
          (value) => value.isEmpty
              ? ''
              : (_translationCache[value] ?? _translationUnavailable),
        )
        .toList(growable: false);
  }

  Future<List<String>?> _fetchEdgeTranslationBatch(List<String> texts) async {
    if (texts.isEmpty) return const [];
    final endpoints = [
      Uri.https('lexora.12323456.xyz', '/api/translate/batch'),
      Uri.https(
        'lexora-official.xiaozhangwangxue.workers.dev',
        '/api/translate/batch',
      ),
    ];
    final completer = Completer<List<String>?>();
    var pending = endpoints.length;

    Future<void> request(Uri uri) async {
      final stopwatch = Stopwatch()..start();
      DeveloperLogService.instance.log(
        'backend.translation_edge.started',
        data: {
          'uri': uri.toString(),
          'items': texts.length,
          'chars': texts.fold<int>(0, (sum, value) => sum + value.length),
        },
      );
      try {
        final response = await _client
            .post(
              uri,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
                'accept': 'application/json',
              },
              body: jsonEncode({'texts': texts}),
            )
            .timeout(const Duration(milliseconds: 4200));
        DeveloperLogService.instance.log(
          'backend.translation_edge.completed',
          data: {
            'uri': uri.toString(),
            'durationMs': stopwatch.elapsedMilliseconds,
            'status': response.statusCode,
            'bytes': response.bodyBytes.length,
            'bodyPreview': _logPreview(
              utf8.decode(response.bodyBytes, allowMalformed: true),
              limit: 1200,
            ),
          },
        );
        if (response.statusCode == 200) {
          final payload = _decodeJson(response) as Map<String, dynamic>;
          final values = (payload['translations'] as List? ?? const [])
              .map((value) => value.toString())
              .toList(growable: false);
          if (values.length == texts.length &&
              values.any((value) => value.trim().isNotEmpty) &&
              !completer.isCompleted) {
            completer.complete(values);
            return;
          }
        }
      } catch (error, stackTrace) {
        DeveloperLogService.instance.log(
          'backend.translation_edge.failed',
          data: {
            'uri': uri.toString(),
            'durationMs': stopwatch.elapsedMilliseconds,
            'items': texts.length,
          },
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }
    }

    for (final endpoint in endpoints) {
      unawaited(request(endpoint));
    }
    return completer.future;
  }

  Future<String> _translate(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return '';
    final cached = _translationCache[normalized];
    if (cached != null) {
      DeveloperLogService.instance.log(
        'backend.translation.cache_hit',
        data: {'chars': normalized.length, 'text': _logPreview(normalized)},
      );
      return cached;
    }
    return _inFlightTranslations.putIfAbsent(normalized, () async {
      final stopwatch = Stopwatch()..start();
      DeveloperLogService.instance.log(
        'backend.translation.started',
        data: {'chars': normalized.length, 'text': _logPreview(normalized)},
      );
      try {
        final translation = await _fetchTranslation(normalized);
        if (translation != _translationUnavailable) {
          _translationCache[normalized] = translation;
        }
        DeveloperLogService.instance.log(
          'backend.translation.completed',
          data: {
            'chars': normalized.length,
            'durationMs': stopwatch.elapsedMilliseconds,
            'available': translation != _translationUnavailable,
            'result': _logPreview(translation),
          },
        );
        return translation;
      } catch (error, stackTrace) {
        DeveloperLogService.instance.log(
          'backend.translation.failed',
          data: {
            'chars': normalized.length,
            'durationMs': stopwatch.elapsedMilliseconds,
          },
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      } finally {
        _inFlightTranslations.remove(normalized);
      }
    });
  }

  Future<String> _fetchTranslation(String text) async {
    await _acquireTranslationPermit();
    try {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {
        'q': text,
        'langpair': 'en|zh-CN',
      });
      for (var attempt = 0; attempt < 3; attempt++) {
        final stopwatch = Stopwatch()..start();
        DeveloperLogService.instance.log(
          'backend.translation_request.started',
          data: {
            'attempt': attempt + 1,
            'chars': text.length,
            'text': _logPreview(text),
          },
        );
        try {
          final response = await _client
              .get(uri)
              .timeout(const Duration(seconds: 15));
          DeveloperLogService.instance.log(
            'backend.translation_request.completed',
            data: {
              'attempt': attempt + 1,
              'durationMs': stopwatch.elapsedMilliseconds,
              'status': response.statusCode,
              'bytes': response.bodyBytes.length,
              'headers': response.headers,
              'bodyPreview': _logPreview(
                utf8.decode(response.bodyBytes, allowMalformed: true),
                limit: 1200,
              ),
            },
          );
          if (response.statusCode == 200) {
            final data = _decodeJson(response) as Map<String, dynamic>;
            final translated =
                ((data['responseData']
                            as Map<String, dynamic>?)?['translatedText']
                        as String?)
                    ?.trim();
            if (translated != null && translated.isNotEmpty) {
              return translated;
            }
            return _translationUnavailable;
          }
          if (response.statusCode != 429 && response.statusCode < 500) {
            return _translationUnavailable;
          }
        } catch (error, stackTrace) {
          DeveloperLogService.instance.log(
            'backend.translation_request.failed',
            data: {
              'attempt': attempt + 1,
              'durationMs': stopwatch.elapsedMilliseconds,
              'chars': text.length,
            },
            error: error,
            stackTrace: stackTrace,
          );
          if (attempt == 2) return _translationUnavailable;
        }
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 550 * (1 << attempt)),
          );
        }
      }
      return _translationUnavailable;
    } finally {
      _releaseTranslationPermit();
    }
  }

  Future<List<http.Response?>> _lookupSources(String rawWord) {
    final word = _normalizeTerm(rawWord);
    final cached = _sourceCache[word];
    if (cached != null) return Future.value(cached);
    return _inFlightSourceLookups.putIfAbsent(word, () async {
      try {
        final stopwatch = Stopwatch()..start();
        final uris = _providerUris(word);
        Future<List<http.Response?>> directLookup() => Future.wait([
          _providerResponse(
            word,
            'dictionary',
            uris.dictionary,
            timeout: const Duration(seconds: 5),
            attempts: 1,
          ),
          _providerResponse(
            word,
            'related',
            uris.related,
            timeout: const Duration(seconds: 3),
            attempts: 1,
          ),
          _providerResponse(
            word,
            'exact',
            uris.exact,
            timeout: const Duration(seconds: 4),
            attempts: 1,
          ),
          _providerResponse(
            word,
            'synonyms',
            uris.synonyms,
            timeout: const Duration(seconds: 3),
            attempts: 1,
          ),
          _providerResponse(
            word,
            'antonyms',
            uris.antonyms,
            timeout: const Duration(seconds: 3),
            attempts: 1,
          ),
        ]);
        List<http.Response?> responses;
        final offlinePayload = await _offlineLexicon.lookup(word);
        if (offlinePayload != null) {
          try {
            responses = _sourceResponsesFromLexicon(
              _lexiconPayloadResponse(offlinePayload),
              word,
              requireCompleted: true,
            );
            DeveloperLogService.instance.log(
              'search.sources.offline_lexicon_presented',
              data: {
                'term': word,
                'durationMs': stopwatch.elapsedMilliseconds,
                'availableProviders': responses
                    .where((response) => response?.statusCode == 200)
                    .length,
              },
            );
            if (_retainedLookupKey == null ||
                _retainedLookupKey!.endsWith('|$word')) {
              _sourceCache[word] = responses;
            }
            return responses;
          } catch (error, stackTrace) {
            DeveloperLogService.instance.log(
              'search.sources.offline_lexicon_incomplete',
              data: {'term': word},
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
        final lexiconFuture = _providerResponse(
          word,
          'open-lexicon',
          Uri.https(_openLexiconHost, '/v1/lookup', {'term': word}),
          timeout: const Duration(milliseconds: 1200),
          attempts: 1,
        );
        final lexiconResponse = await lexiconFuture;
        if (lexiconResponse?.statusCode == 200) {
          try {
            responses = _sourceResponsesFromLexicon(
              lexiconResponse!,
              word,
              requireCompleted: true,
            );
            DeveloperLogService.instance.log(
              'search.sources.open_lexicon_presented',
              data: {
                'term': word,
                'durationMs': stopwatch.elapsedMilliseconds,
                'availableProviders': responses
                    .where((response) => response?.statusCode == 200)
                    .length,
              },
            );
            if (_retainedLookupKey == null ||
                _retainedLookupKey!.endsWith('|$word')) {
              _sourceCache[word] = responses;
            }
            return responses;
          } catch (error, stackTrace) {
            DeveloperLogService.instance.log(
              'search.sources.open_lexicon_incomplete',
              data: {'term': word},
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
        final edgeFuture = _firstSuccessfulEdgeGet(
          [
            Uri.https('lexora.12323456.xyz', '/api/dictionary/full', {
              'term': word,
            }),
            Uri.https(
              'lexora-official.xiaozhangwangxue.workers.dev',
              '/api/dictionary/full',
              {'term': word},
            ),
          ],
          timeout: const Duration(milliseconds: 1850),
          operation: 'edge-full',
          term: word,
        );
        final edgeResponse = await edgeFuture;
        if (edgeResponse?.statusCode == 200) {
          try {
            responses = _sourceResponsesFromEdge(edgeResponse!);
            DeveloperLogService.instance.log(
              'search.sources.edge_presented',
              data: {
                'term': word,
                'durationMs': stopwatch.elapsedMilliseconds,
                'availableProviders': responses
                    .where((response) => response?.statusCode == 200)
                    .length,
              },
            );
          } catch (error, stackTrace) {
            DeveloperLogService.instance.log(
              'search.sources.edge_invalid',
              data: {'term': word},
              error: error,
              stackTrace: stackTrace,
            );
            responses = await directLookup();
          }
        } else {
          responses = await directLookup();
        }
        if (responses.any((response) => response?.statusCode == 200) &&
            (_retainedLookupKey == null ||
                _retainedLookupKey!.endsWith('|$word'))) {
          _sourceCache[word] = responses;
        }
        return responses;
      } finally {
        _inFlightSourceLookups.remove(word);
      }
    });
  }

  _ProviderUris _providerUris(String word) => _ProviderUris(
    dictionary: Uri.https('api.dictionaryapi.dev', '/api/v2/entries/en/$word'),
    related: Uri.https('api.datamuse.com', '/words', {
      'ml': word,
      'md': 'dfr',
      'ipa': '1',
      'max': '30',
    }),
    exact: Uri.https('api.datamuse.com', '/words', {
      'sp': word,
      'md': 'dfrp',
      'ipa': '1',
      'max': '8',
    }),
    synonyms: Uri.https('api.datamuse.com', '/words', {
      'rel_syn': word,
      'md': 'f',
      'max': '12',
    }),
    antonyms: Uri.https('api.datamuse.com', '/words', {
      'rel_ant': word,
      'max': '12',
    }),
  );

  Future<http.Response?> _providerResponse(
    String word,
    String provider,
    Uri uri, {
    required Duration timeout,
    required int attempts,
  }) {
    final key = '$word|$provider';
    if (_providerCache.containsKey(key)) {
      DeveloperLogService.instance.log(
        'backend.provider.cache_hit',
        data: {'term': word, 'provider': provider},
      );
      return Future.value(_providerCache[key]);
    }
    return _inFlightProviders.putIfAbsent(key, () async {
      try {
        final response = await _getWithRetry(
          uri,
          timeout: timeout,
          attempts: attempts,
          operation: provider,
          term: word,
        );
        if (response != null) {
          _providerCache[key] = response;
        }
        return response;
      } finally {
        _inFlightProviders.remove(key);
      }
    });
  }

  WordEntry _coreEntryFromResponses(
    String word,
    http.Response? dictionaryResponse,
    http.Response? exactResponse, {
    required int exampleCount,
  }) {
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
        .toList(growable: false);
    final exact = _exactDatamuseItem(
      _decodeDatamuseNullable(exactResponse),
      word,
    );
    final dictionaryDefinition = definitions
        .map((item) => (item['definition'] as String? ?? '').trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final definition = dictionaryDefinition.isNotEmpty
        ? dictionaryDefinition
        : _definitionFromDatamuse(exact);
    if (definition.isEmpty) {
      throw WordLookupException('No dictionary entry was found for “$word”.');
    }
    final phonetics = (dictionary?['phonetics'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final phonetic = dictionary?['phonetic'] as String? ?? '';
    final datamusePhonetic = _arpabetToIpa(_metadataTag(exact, 'pron:'));
    final fallbackPhonetic = phonetic.isEmpty ? datamusePhonetic : phonetic;
    final sameMeaning = meanings
        .expand((meaning) => (meaning['synonyms'] as List? ?? const []))
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(6)
        .toList(growable: false);
    final opposites = meanings
        .expand((meaning) => (meaning['antonyms'] as List? ?? const []))
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(6)
        .toList(growable: false);
    final examples = _findExamples(
      meanings,
    ).take(exampleCount).toList(growable: false);
    final senses = <WordSense>[
      for (final meaning in meanings.take(6))
        if ((meaning['definitions'] as List? ?? const []).isNotEmpty)
          WordSense(
            partOfSpeech: (meaning['partOfSpeech'] as String? ?? '').trim(),
            definitions: [
              for (final item
                  in (meaning['definitions'] as List? ?? const [])
                      .cast<Map<String, dynamic>>()
                      .take(3))
                if ((item['definition'] as String? ?? '').trim().isNotEmpty)
                  BilingualDefinition(
                    definition: (item['definition'] as String).trim(),
                    definitionZh:
                        _translationCache[(item['definition'] as String)
                            .trim()] ??
                        '',
                  ),
            ],
          ),
    ];
    final frequency = _frequencyFromDatamuse(exact);
    return WordEntry(
      word: word,
      difficulty: _difficulty(word, frequency),
      frequency: frequency,
      usPhonetic: _arpabetToIpa(
        _phoneticFor(phonetics, '-us') ?? fallbackPhonetic,
      ),
      ukPhonetic: _arpabetToIpa(
        _phoneticFor(phonetics, '-uk') ?? fallbackPhonetic,
      ),
      definition: definition,
      definitionZh: _translationCache[definition] ?? '',
      synonyms: sameMeaning,
      synonymsZh: '',
      antonyms: opposites,
      antonymsZh: '',
      examples: examples,
      examplesZh: const [],
      senses: senses,
    );
  }

  List<http.Response?> _coreResponsesFromLexicon(
    http.Response response,
    String requestedWord,
  ) {
    final responses = _sourceResponsesFromLexicon(
      response,
      requestedWord,
      requireCompleted: false,
    );
    return [responses[0], responses[2]];
  }

  http.Response _lexiconPayloadResponse(Map<String, dynamic> payload) =>
      http.Response(
        jsonEncode(payload),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );

  List<http.Response?> _sourceResponsesFromLexicon(
    http.Response response,
    String requestedWord, {
    required bool requireCompleted,
  }) {
    final payload = _decodeJson(response) as Map<String, dynamic>;
    final normalizedWord = _normalizeTerm(
      payload['normalized_word']?.toString() ??
          payload['word']?.toString() ??
          '',
    );
    if (normalizedWord != requestedWord ||
        payload['match_type']?.toString() == 'fuzzy') {
      throw const FormatException('Open lexicon returned a non-exact match.');
    }
    final frequency =
        double.tryParse(payload['frequency']?.toString() ?? '') ?? 0;
    if (frequency > 10) {
      throw const FormatException('Open lexicon frequency is not normalized.');
    }
    if (requireCompleted) {
      final enrichment =
          payload['enrichment'] as Map<String, dynamic>? ?? const {};
      if (enrichment['status'] != 'completed') {
        throw const FormatException('Open lexicon entry is still enriching.');
      }
    }

    final senses = (payload['senses'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final meanings = <Map<String, dynamic>>[];
    for (final sense in senses.take(12)) {
      final definitions = (sense['definitions'] as List? ?? const [])
          .map((value) => _cleanLexiconText(value))
          .where((value) => value.isNotEmpty)
          .take(3)
          .map<Map<String, dynamic>>(
            (value) => <String, dynamic>{'definition': value},
          )
          .toList(growable: true);
      if (definitions.isEmpty) continue;
      meanings.add({
        'partOfSpeech': _cleanLexiconText(sense['pos']),
        'definitions': definitions,
        'synonyms': <String>[],
        'antonyms': <String>[],
      });
    }

    final fallbackDefinitions = _cleanLexiconText(
      payload['definition'],
    ).split('\n').where((value) => value.trim().isNotEmpty).toList();
    if (meanings.isEmpty && fallbackDefinitions.isNotEmpty) {
      meanings.add({
        'partOfSpeech': _cleanLexiconText(payload['pos']),
        'definitions': [
          for (final value in fallbackDefinitions.take(3))
            <String, dynamic>{'definition': value.trim()},
        ],
        'synonyms': <String>[],
        'antonyms': <String>[],
      });
    }
    if (meanings.isEmpty) {
      throw const FormatException('Open lexicon entry has no definition.');
    }

    final synonyms = _lexiconStringList(payload['synonyms']);
    final antonyms = _lexiconStringList(payload['antonyms']);
    meanings.first['synonyms'] = synonyms;
    meanings.first['antonyms'] = antonyms;
    final definitionMaps = meanings
        .expand(
          (meaning) => (meaning['definitions'] as List)
              .whereType<Map<String, dynamic>>(),
        )
        .toList(growable: false);
    final examples = _lexiconStringList(payload['examples']);
    for (
      var index = 0;
      index < min(definitionMaps.length, examples.length);
      index++
    ) {
      definitionMaps[index]['example'] = examples[index];
    }

    final us = _normalizeLexiconPhonetic(payload['us_phonetic']);
    final uk = _normalizeLexiconPhonetic(payload['uk_phonetic']);
    final primaryDefinition = _cleanLexiconText(
      definitionMaps.first['definition'],
    );
    final frequencyTag = frequency > 0
        ? 'f:${pow(10, frequency - 3).toStringAsFixed(4)}'
        : '';
    final exactTags = <String>[
      if (frequencyTag.isNotEmpty) frequencyTag,
      if (us.isNotEmpty) 'pron:$us',
    ];
    final exact = [
      {
        'word': normalizedWord,
        'defs': ['${_cleanLexiconText(payload['pos'])}\t$primaryDefinition'],
        'tags': exactTags,
      },
    ];
    final dictionary = [
      {
        'word': normalizedWord,
        'phonetic': us.isNotEmpty ? us : uk,
        'phonetics': [
          if (us.isNotEmpty) {'text': us, 'audio': 'lexora-us.mp3'},
          if (uk.isNotEmpty) {'text': uk, 'audio': 'lexora-uk.mp3'},
        ],
        'meanings': meanings,
      },
    ];

    final relationEntries = [
      ..._lexiconNamedEntries(payload['phrase_entries']),
      ..._lexiconNamedEntries(payload['related_entries']),
    ];
    final related = [
      for (final item in relationEntries)
        {
          'word': item.$1,
          'defs': ['\t${item.$2}'],
          'tags': <String>[],
        },
    ];
    final synonymItems = [
      for (final value in synonyms) {'word': value, 'tags': <String>[]},
    ];
    final antonymItems = [
      for (final value in antonyms) {'word': value, 'tags': <String>[]},
    ];

    http.Response encoded(Object value) => http.Response(
      jsonEncode(value),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
    return [
      encoded(dictionary),
      encoded(related),
      encoded(exact),
      encoded(synonymItems),
      encoded(antonymItems),
    ];
  }

  String _cleanLexiconText(Object? value) => (value ?? '')
      .toString()
      .replaceAll(r'\n', '\n')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();

  String _normalizeLexiconPhonetic(Object? value) => _cleanLexiconText(value)
      .replaceAll('ә', 'ə')
      .replaceAll(':', 'ː')
      .replaceAll("'", 'ˈ')
      .replaceAll('ˈˈ', 'ˈ')
      .replaceAll(RegExp(r'^/+|/+$'), '');

  List<String> _lexiconStringList(Object? value) => (value as List? ?? const [])
      .map(_cleanLexiconText)
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);

  List<(String, String)> _lexiconNamedEntries(Object? value) =>
      (value as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => (
              _normalizeTerm(item['word']?.toString() ?? ''),
              _cleanLexiconText(item['definition'] ?? item['meaning'] ?? ''),
            ),
          )
          .where((item) => item.$1.isNotEmpty && item.$2.isNotEmpty)
          .toList(growable: false);

  List<http.Response?> _coreResponsesFromEdge(http.Response response) {
    final payload = _decodeJson(response) as Map<String, dynamic>;
    http.Response? encoded(Object? value) => value == null
        ? null
        : http.Response(
            jsonEncode(value),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
    return [encoded(payload['dictionary']), encoded(payload['exact'])];
  }

  List<http.Response?> _sourceResponsesFromEdge(http.Response response) {
    final payload = _decodeJson(response) as Map<String, dynamic>;
    http.Response? encoded(Object? value) => value == null
        ? null
        : http.Response(
            jsonEncode(value),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
    return [
      encoded(payload['dictionary']),
      encoded(payload['related']),
      encoded(payload['exact']),
      encoded(payload['synonyms']),
      encoded(payload['antonyms']),
    ];
  }

  Future<void> _acquireTranslationPermit() async {
    if (_activeTranslations < _maxTranslationConcurrency) {
      _activeTranslations++;
      return;
    }
    final waiter = Completer<void>();
    _translationWaiters.add(waiter);
    await waiter.future;
  }

  void _releaseTranslationPermit() {
    if (_translationWaiters.isNotEmpty) {
      _translationWaiters.removeFirst().complete();
    } else {
      _activeTranslations--;
    }
  }

  dynamic _decodeJson(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes));

  String _logPreview(String value, {int limit = 320}) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= limit
        ? compact
        : '${compact.substring(0, limit)}…';
  }

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

class _ProviderUris {
  const _ProviderUris({
    required this.dictionary,
    required this.related,
    required this.exact,
    required this.synonyms,
    required this.antonyms,
  });

  final Uri dictionary;
  final Uri related;
  final Uri exact;
  final Uri synonyms;
  final Uri antonyms;
}
