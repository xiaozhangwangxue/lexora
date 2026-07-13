import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexora/services/word_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('lookupAll performs bounded concurrent work and preserves word order', () async {
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
        return http.Response(jsonEncode([
          {
            'word': word,
            'phonetic': '/$word/',
            'phonetics': const [],
            'meanings': [
              {
                'synonyms': const [],
                'antonyms': const [],
                'definitions': [
                  {'definition': '$word definition'},
                ],
              },
            ],
          },
        ]), 200);
      }
      if (request.url.host == 'api.datamuse.com') {
        return http.Response('[]', 200);
      }
      if (request.url.host == 'api.mymemory.translated.net') {
        return http.Response(jsonEncode({
          'responseData': {'translatedText': '中文翻译'},
        }), 200);
      }
      return http.Response('not found', 404);
    });

    final result = await WordService(client: client).lookupAll(
      const ['alpha', 'bravo', 'charlie', 'delta'],
      exampleCount: 0,
      maxConcurrency: 4,
    );

    expect(result.entries.map((entry) => entry.word), ['alpha', 'bravo', 'charlie', 'delta']);
    expect(result.failures, isEmpty);
    expect(peakDictionaryRequests, greaterThan(1));

    final requestsAfterFirstRun = requestCount;
    await WordService(client: client).lookupAll(
      const ['alpha', 'bravo', 'charlie', 'delta'],
      exampleCount: 0,
      maxConcurrency: 4,
    );
    expect(requestCount, requestsAfterFirstRun, reason: 'fresh results should come from cache');
  });

  test('lookupAll skips missing entries without cancelling successful work', () async {
    SharedPreferences.setMockInitialValues({});
    final progress = <String>[];
    final client = MockClient((request) async {
      if (request.url.host == 'api.dictionaryapi.dev') {
        final term = Uri.decodeComponent(request.url.pathSegments.last);
        if (term == 'missing') return http.Response('{}', 404);
        return http.Response(jsonEncode([
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
        ]), 200);
      }
      if (request.url.host == 'api.datamuse.com') {
        return http.Response('[]', 200);
      }
      if (request.url.host == 'api.mymemory.translated.net') {
        return http.Response(jsonEncode({
          'responseData': {'translatedText': '中文翻译'},
        }), 200);
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
    expect(progress, hasLength(3));
  });

  test('lookup supports a phrase and keeps related phrase meanings', () async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((request) async {
      if (request.url.host == 'api.dictionaryapi.dev') {
        return http.Response('{}', 404);
      }
      if (request.url.host == 'api.datamuse.com') {
        if (request.url.queryParameters.containsKey('sp')) {
          return http.Response.bytes(utf8.encode(jsonEncode([
            {
              'word': 'take off',
              'defs': ['v\tto leave the ground'],
              'tags': ['pron:teɪk ɔf', 'f:7.5'],
            },
          ])), 200, headers: const {
            'content-type': 'application/json; charset=utf-8',
          });
        }
        return http.Response(jsonEncode([
          {
            'word': 'take it easy',
            'defs': ['v\tto relax and avoid stress'],
            'tags': ['f:2.0'],
          },
        ]), 200);
      }
      if (request.url.host == 'api.mymemory.translated.net') {
        final source = request.url.queryParameters['q'];
        return http.Response.bytes(utf8.encode(jsonEncode({
          'responseData': {'translatedText': '中译：$source'},
        })), 200, headers: const {
          'content-type': 'application/json; charset=utf-8',
        });
      }
      return http.Response('not found', 404);
    });

    final entry = await WordService(client: client).lookup(
      '  Take   Off  ',
      exampleCount: 0,
    );

    expect(entry.word, 'take off');
    expect(entry.definition, 'to leave the ground');
    expect(entry.usPhonetic, 'teɪk ɔf');
    expect(entry.phrases, hasLength(1));
    expect(entry.phrases.single.phrase, 'take it easy');
    expect(entry.phrases.single.meaningZh, contains('中译'));
  });
}
