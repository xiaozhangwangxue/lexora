import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexora/services/word_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'lookupAll performs bounded concurrent work and preserves word order',
    () async {
      SharedPreferences.setMockInitialValues({});
      var activeDictionaryRequests = 0;
      var peakDictionaryRequests = 0;
      var requestCount = 0;

      final client = MockClient((request) async {
        requestCount++;
        if (request.url.host == 'api.dictionaryapi.dev') {
          activeDictionaryRequests++;
          if (activeDictionaryRequests > peakDictionaryRequests) {
            peakDictionaryRequests = activeDictionaryRequests;
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
          activeDictionaryRequests--;
          final word = request.url.pathSegments.last;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                {
                  'word': word,
                  'phonetic': '/$word/',
                  'phonetics': const [],
                  'meanings': [
                    {
                      'partOfSpeech': 'noun',
                      'synonyms': const [],
                      'antonyms': const [],
                      'definitions': [
                        {'definition': '$word definition'},
                      ],
                    },
                  ],
                },
              ]),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.host == 'api.datamuse.com') {
          return http.Response('[]', 200);
        }
        if (request.url.host == 'api.mymemory.translated.net') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'responseData': {'translatedText': '中文翻译'},
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('not found', 404);
      });

      final result = await WordService(client: client).lookupAll(
        const ['alpha', 'bravo', 'charlie', 'delta'],
        exampleCount: 0,
        maxConcurrency: 4,
      );

      expect(result.entries.map((entry) => entry.word), [
        'alpha',
        'bravo',
        'charlie',
        'delta',
      ]);
      expect(result.failures, isEmpty);
      expect(result.fuzzyMatches, isEmpty);
      expect(peakDictionaryRequests, greaterThan(1));

      final requestsAfterFirstRun = requestCount;
      await WordService(client: client).lookupAll(
        const ['alpha', 'bravo', 'charlie', 'delta'],
        exampleCount: 0,
        maxConcurrency: 4,
      );
      expect(
        requestCount,
        requestsAfterFirstRun,
        reason: 'fresh results should come from cache',
      );
    },
  );

  test(
    'lookupAll skips missing entries without cancelling successful work',
    () async {
      SharedPreferences.setMockInitialValues({});
      final progress = <String>[];
      final client = MockClient((request) async {
        if (request.url.host == 'api.dictionaryapi.dev') {
          final term = Uri.decodeComponent(request.url.pathSegments.last);
          if (term == 'missing') return http.Response('{}', 404);
          return http.Response(
            jsonEncode([
              {
                'word': term,
                'phonetics': const [],
                'meanings': [
                  {
                    'synonyms': const [],
                    'antonyms': const [],
                    'definitions': [
                      {'definition': '$term definition'},
                    ],
                  },
                ],
              },
            ]),
            200,
          );
        }
        if (request.url.host == 'api.datamuse.com') {
          return http.Response('[]', 200);
        }
        if (request.url.host == 'api.mymemory.translated.net') {
          return http.Response(
            jsonEncode({
              'responseData': {'translatedText': '中文翻译'},
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final result = await WordService(client: client).lookupAll(
        const ['alpha', 'missing', 'bravo'],
        exampleCount: 0,
        maxConcurrency: 3,
        onProgress: (_, __, term) => progress.add(term),
      );

      expect(result.entries.map((entry) => entry.word), ['alpha', 'bravo']);
      expect(result.failures.map((failure) => failure.term), ['missing']);
      expect(result.fuzzyMatches, isEmpty);
      expect(progress, hasLength(3));
    },
  );

  test(
    'lookupAll accepts a close spelling suggestion after validating it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((request) async {
        if (request.url.host == 'api.dictionaryapi.dev') {
          final term = Uri.decodeComponent(request.url.pathSegments.last);
          if (term == 'aple') return http.Response('{}', 404);
          if (term == 'apple') {
            return http.Response(
              jsonEncode([
                {
                  'word': 'apple',
                  'phonetics': const [],
                  'meanings': [
                    {
                      'partOfSpeech': 'noun',
                      'synonyms': const [],
                      'antonyms': const [],
                      'definitions': [
                        {'definition': 'a round fruit'},
                      ],
                    },
                  ],
                },
              ]),
              200,
            );
          }
          return http.Response('{}', 404);
        }
        if (request.url.host == 'api.datamuse.com') {
          if (request.url.path == '/sug') {
            return http.Response(
              jsonEncode([
                {'word': 'apple', 'score': 1000},
                {'word': 'apply', 'score': 900},
              ]),
              200,
            );
          }
          if (request.url.queryParameters['sp'] == 'apple') {
            return http.Response(
              jsonEncode([
                {
                  'word': 'apple',
                  'defs': ['n\ta round fruit'],
                  'tags': ['f:24.0'],
                },
              ]),
              200,
            );
          }
          return http.Response('[]', 200);
        }
        if (request.url.host == 'api.mymemory.translated.net') {
          return http.Response(
            jsonEncode({
              'responseData': {'translatedText': '苹果'},
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final result = await WordService(
        client: client,
      ).lookupAll(const ['aple'], exampleCount: 0);

      expect(result.entries.single.word, 'apple');
      expect(result.failures, isEmpty);
      expect(result.fuzzyMatches, hasLength(1));
      expect(result.fuzzyMatches.single.term, 'aple');
      expect(result.fuzzyMatches.single.matchedTerm, 'apple');
      expect(result.entries.single.originalTerm, 'aple');
      expect(result.entries.single.isFuzzyMatch, isTrue);
    },
  );

  test(
    'exact dictionary result survives failures from optional providers',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((request) async {
        if (request.url.host == 'api.dictionaryapi.dev') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                {
                  'word': 'word',
                  'phonetic': '/wɜːd/',
                  'phonetics': const [],
                  'meanings': [
                    {
                      'partOfSpeech': 'noun',
                      'synonyms': const [],
                      'antonyms': const [],
                      'definitions': [
                        {'definition': 'a unit of language'},
                      ],
                    },
                  ],
                },
              ]),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.host == 'api.datamuse.com') {
          throw http.ClientException('optional provider unavailable');
        }
        if (request.url.host == 'api.mymemory.translated.net') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'responseData': {'translatedText': '单词'},
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('not found', 404);
      });

      final entry = await WordService(
        client: client,
      ).lookup('word', exampleCount: 0);

      expect(entry.word, 'word');
      expect(entry.definition, 'a unit of language');
      expect(entry.definitionZh, '单词');
      expect(entry.senses.single.partOfSpeech, 'noun');
      expect(
        entry.senses.single.definitions.single.definition,
        'a unit of language',
      );
      expect(entry.senses.single.definitions.single.definitionZh, '单词');
    },
  );

  test('suggest returns normalized unique candidates', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/sug');
      return http.Response(
        jsonEncode([
          {'word': 'Word'},
          {'word': 'word'},
          {'word': 'word play'},
        ]),
        200,
      );
    });
    final suggestions = await WordService(
      client: client,
    ).suggest('  WOR ', maxResults: 8);
    expect(suggestions, ['word', 'word play']);
  });

  test('Datamuse exact definition survives dictionary outage', () async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((request) async {
      if (request.url.host == 'api.dictionaryapi.dev') {
        throw http.ClientException('dictionary unavailable');
      }
      if (request.url.host == 'api.datamuse.com' &&
          request.url.queryParameters['sp'] == 'word') {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {
                'word': 'word',
                'defs': ['n\ta unit of language'],
                'tags': ['pron:wɜːd', 'f:210.0'],
              },
            ]),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.host == 'api.datamuse.com') {
        return http.Response('[]', 200);
      }
      if (request.url.host == 'api.mymemory.translated.net') {
        return http.Response(
          jsonEncode({
            'responseData': {'translatedText': '单词'},
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final entry = await WordService(
      client: client,
    ).lookup('word', exampleCount: 0);

    expect(entry.word, 'word');
    expect(entry.definition, 'a unit of language');
    expect(entry.frequency, 210);
  });

  test('Datamuse ARPAbet fallback is converted to readable IPA', () async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((request) async {
      if (request.url.host == 'api.dictionaryapi.dev') {
        return http.Response('{}', 404);
      }
      if (request.url.host == 'api.datamuse.com' &&
          request.url.queryParameters['sp'] == 'excellently') {
        return http.Response(
          jsonEncode([
            {
              'word': 'excellently',
              'defs': ['adv\tin an excellent manner'],
              'tags': ['pron:EH1 K S AH0 L AH0 N T L IY0', 'f:1.2'],
            },
          ]),
          200,
        );
      }
      if (request.url.host == 'api.datamuse.com') {
        return http.Response('[]', 200);
      }
      if (request.url.host == 'api.mymemory.translated.net') {
        return http.Response(
          jsonEncode({
            'responseData': {'translatedText': '出色地'},
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final entry = await WordService(
      client: client,
    ).lookup('excellently', exampleCount: 0);

    expect(entry.usPhonetic, '/ˈɛksələntli/');
    expect(entry.ukPhonetic, '/ˈɛksələntli/');
    expect(entry.usPhonetic, isNot(contains('EH1')));
  });

  test(
    'lookupAll rejects a suggestion that is not sufficiently similar',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((request) async {
        if (request.url.host == 'api.dictionaryapi.dev') {
          return http.Response('{}', 404);
        }
        if (request.url.host == 'api.datamuse.com') {
          if (request.url.path == '/sug') {
            return http.Response(
              jsonEncode([
                {'word': 'unrelated', 'score': 1000},
              ]),
              200,
            );
          }
          return http.Response('[]', 200);
        }
        return http.Response('not found', 404);
      });

      final result = await WordService(
        client: client,
      ).lookupAll(const ['zzqx'], exampleCount: 0);

      expect(result.entries, isEmpty);
      expect(result.fuzzyMatches, isEmpty);
      expect(result.failures.single.term, 'zzqx');
    },
  );

  test('lookup supports a phrase and keeps related phrase meanings', () async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((request) async {
      if (request.url.host == 'api.dictionaryapi.dev') {
        return http.Response('{}', 404);
      }
      if (request.url.host == 'api.datamuse.com') {
        if (request.url.queryParameters.containsKey('sp')) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                {
                  'word': 'take off',
                  'defs': ['v\tto leave the ground'],
                  'tags': ['pron:teɪk ɔf', 'f:7.5'],
                },
              ]),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode([
            {
              'word': 'take it easy',
              'defs': ['v\tto relax and avoid stress'],
              'tags': ['f:2.0'],
            },
          ]),
          200,
        );
      }
      if (request.url.host == 'api.mymemory.translated.net') {
        final source = request.url.queryParameters['q'];
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'responseData': {'translatedText': '中译：$source'},
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not found', 404);
    });

    final entry = await WordService(
      client: client,
    ).lookup('  Take   Off  ', exampleCount: 0);

    expect(entry.word, 'take off');
    expect(entry.definition, 'to leave the ground');
    expect(entry.usPhonetic, 'teɪk ɔf');
    expect(entry.phrases, hasLength(1));
    expect(entry.phrases.single.phrase, 'take it easy');
    expect(entry.phrases.single.meaningZh, contains('中译'));
  });

  test(
    'suggestion prefetch warms only three English entries and one translation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dictionaryTerms = <String>[];
      final translatedTexts = <String>[];
      final client = MockClient((request) async {
        if (request.url.host == 'api.dictionaryapi.dev') {
          final term = Uri.decodeComponent(request.url.pathSegments.last);
          dictionaryTerms.add(term);
          return http.Response(
            jsonEncode([
              {
                'word': term,
                'phonetics': const [],
                'meanings': [
                  {
                    'partOfSpeech': 'noun',
                    'synonyms': const [],
                    'antonyms': const [],
                    'definitions': [
                      {'definition': '$term definition'},
                    ],
                  },
                ],
              },
            ]),
            200,
          );
        }
        if (request.url.host == 'api.datamuse.com') {
          return http.Response('[]', 200);
        }
        if (request.url.host == 'api.mymemory.translated.net') {
          translatedTexts.add(request.url.queryParameters['q'] ?? '');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'responseData': {'translatedText': '中文翻译'},
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('not found', 404);
      });

      await WordService(client: client).prefetchCandidates(const [
        'alpha',
        'bravo',
        'charlie',
        'delta',
        'echo',
      ]);

      expect(dictionaryTerms.toSet(), {'alpha', 'bravo', 'charlie'});
      expect(translatedTexts, ['alpha definition']);
    },
  );

  test('translation work never exceeds two concurrent requests', () async {
    SharedPreferences.setMockInitialValues({});
    var activeTranslations = 0;
    var peakTranslations = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'api.dictionaryapi.dev') {
        return http.Response(
          jsonEncode([
            {
              'word': 'rich',
              'phonetics': const [],
              'meanings': [
                {
                  'partOfSpeech': 'adjective',
                  'synonyms': ['wealthy', 'abundant', 'vivid'],
                  'antonyms': ['poor', 'plain'],
                  'definitions': [
                    {'definition': 'having a great deal of resources'},
                    {'definition': 'producing a strong impression'},
                  ],
                },
              ],
            },
          ]),
          200,
        );
      }
      if (request.url.host == 'api.datamuse.com') {
        return http.Response('[]', 200);
      }
      if (request.url.host == 'api.mymemory.translated.net') {
        activeTranslations++;
        peakTranslations = max(peakTranslations, activeTranslations);
        await Future<void>.delayed(const Duration(milliseconds: 12));
        activeTranslations--;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'responseData': {'translatedText': '中文翻译'},
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not found', 404);
    });

    await WordService(client: client).lookup('rich', exampleCount: 0);

    expect(peakTranslations, lessThanOrEqualTo(2));
    expect(peakTranslations, greaterThan(0));
  });
}
