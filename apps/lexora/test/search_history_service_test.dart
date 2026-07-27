import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/models/word_entry.dart';
import 'package:lexora/services/search_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'search history keeps the newest copy and preserves rich entries',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = SearchHistoryService();
      final entry = WordEntry(
        word: 'word',
        difficulty: 'A1–A2',
        frequency: 42,
        usPhonetic: '/wɜːd/',
        ukPhonetic: '/wɜːd/',
        definition: 'a unit of language',
        definitionZh: '单词',
        synonyms: const ['term'],
        synonymsZh: '词语',
        antonyms: const [],
        antonymsZh: '',
        examples: const ['This is a word.'],
        examplesZh: const ['这是一个单词。'],
        senses: const [
          WordSense(
            partOfSpeech: 'noun',
            definitions: [
              BilingualDefinition(
                definition: 'a unit of language',
                definitionZh: '单词',
              ),
            ],
          ),
        ],
      );

      await service.record('Word', entry);
      await service.record(' word ', entry);

      final records = await service.load();
      expect(records, hasLength(1));
      expect(records.single.query, 'word');
      expect(records.single.entry.senses.single.partOfSpeech, 'noun');
    },
  );
}
