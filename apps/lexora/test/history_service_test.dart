import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/models/word_entry.dart';
import 'package:lexora/services/history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generated word history counts generations and keeps stars', () async {
    SharedPreferences.setMockInitialValues({});
    final service = HistoryService();
    final firstTime = DateTime.utc(2026, 7, 13, 8);
    final secondTime = firstTime.add(const Duration(hours: 1));

    await service.recordWords(
      [_entry('lucid', 'B1–B2'), _entry('serendipity', 'C1–C2')],
      firstTime,
    );
    await service.recordWords([_entry('lucid', 'B2–C1')], secondTime);
    await service.setWordStarred('lucid', true);

    final records = await service.loadWords();
    final lucid = records.singleWhere((record) => record.word == 'lucid');
    final serendipity =
        records.singleWhere((record) => record.word == 'serendipity');

    expect(lucid.generationCount, 2);
    expect(lucid.firstGeneratedAt, firstTime);
    expect(lucid.lastGeneratedAt, secondTime);
    expect(lucid.difficulty, 'B2–C1');
    expect(lucid.starred, isTrue);
    expect(serendipity.generationCount, 1);
    expect(serendipity.starred, isFalse);
  });

  test('legacy generated books load without preview words', () async {
    final createdAt = DateTime.utc(2026, 7, 13, 9);
    SharedPreferences.setMockInitialValues({
      'lexora.generated.books': [
        jsonEncode({
          'id': 'legacy',
          'title': 'legacy.pdf',
          'path': '/tmp/legacy.pdf',
          'createdAt': createdAt.toIso8601String(),
          'wordCount': 3,
        }),
      ],
    });

    final books = await HistoryService().load();

    expect(books, hasLength(1));
    expect(books.single.previewWords, isEmpty);
  });
}

WordEntry _entry(String word, String difficulty) => WordEntry(
      word: word,
      difficulty: difficulty,
      frequency: 4.2,
      usPhonetic: '/test/',
      ukPhonetic: '/test/',
      definition: 'definition',
      definitionZh: '释义',
      synonyms: const [],
      synonymsZh: '',
      antonyms: const [],
      antonymsZh: '',
      examples: const [],
      examplesZh: const [],
    );
