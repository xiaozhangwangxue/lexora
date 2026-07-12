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

    final entries = await WordService(client: client).lookupAll(
      const ['alpha', 'bravo', 'charlie', 'delta'],
      exampleCount: 0,
      maxConcurrency: 4,
    );

    expect(entries.map((entry) => entry.word), ['alpha', 'bravo', 'charlie', 'delta']);
    expect(peakDictionaryRequests, greaterThan(1));

    final requestsAfterFirstRun = requestCount;
    await WordService(client: client).lookupAll(
      const ['alpha', 'bravo', 'charlie', 'delta'],
      exampleCount: 0,
      maxConcurrency: 4,
    );
    expect(requestCount, requestsAfterFirstRun, reason: 'fresh results should come from cache');
  });
}
