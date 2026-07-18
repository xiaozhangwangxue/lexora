import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_entry.dart';

class HistoryService {
  static const _key = 'lexora.generated.books';
  static const _wordKey = 'lexora.generated.words.v1';

  Future<List<GeneratedBook>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_key) ?? const [])
        .map(
          (item) =>
              GeneratedBook.fromJson(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> save(GeneratedBook book) async {
    final preferences = await SharedPreferences.getInstance();
    final books = await load();
    books.removeWhere((item) => item.id == book.id);
    books.insert(0, book);
    await preferences.setStringList(
      _key,
      books.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> remove(String id) async {
    await removeMany({id});
  }

  Future<void> removeMany(Set<String> ids) async {
    if (ids.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final books = await load();
    books.removeWhere((item) => ids.contains(item.id));
    await preferences.setStringList(
      _key,
      books.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<List<GeneratedWordRecord>> loadWords() async {
    final preferences = await SharedPreferences.getInstance();
    final records = <GeneratedWordRecord>[];
    for (final item in preferences.getStringList(_wordKey) ?? const []) {
      try {
        records.add(
          GeneratedWordRecord.fromJson(
            jsonDecode(item) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Keep one malformed legacy entry from hiding the rest of the history.
      }
    }
    return records;
  }

  Future<void> recordWords(
    List<WordEntry> entries,
    DateTime generatedAt,
  ) async {
    final records = await loadWords();
    final byWord = {for (final record in records) record.word: record};
    for (final entry in entries) {
      final previous = byWord[entry.word];
      byWord[entry.word] = previous == null
          ? GeneratedWordRecord(
              word: entry.word,
              generationCount: 1,
              firstGeneratedAt: generatedAt,
              lastGeneratedAt: generatedAt,
              difficulty: entry.difficulty,
            )
          : previous.copyWith(
              generationCount: previous.generationCount + 1,
              lastGeneratedAt: generatedAt,
              difficulty: entry.difficulty,
            );
    }
    await _saveWords(byWord.values);
  }

  Future<void> setWordStarred(String word, bool starred) async {
    final records = await loadWords();
    final updated = [
      for (final record in records)
        if (record.word == word) record.copyWith(starred: starred) else record,
    ];
    await _saveWords(updated);
  }

  Future<void> removeWords(Set<String> words) async {
    if (words.isEmpty) return;
    final records = await loadWords();
    await _saveWords(records.where((record) => !words.contains(record.word)));
  }

  Future<void> _saveWords(Iterable<GeneratedWordRecord> records) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _wordKey,
      records.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }
}
