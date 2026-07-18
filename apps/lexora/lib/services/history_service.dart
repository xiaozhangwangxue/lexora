import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_entry.dart';

class HistoryService {
  HistoryService({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;
  static const _key = 'lexora.generated.books';
  static const _wordKey = 'lexora.generated.words.v1';
  static const _snapshotName = 'lexora-history-v2.json';

  Future<List<GeneratedBook>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final books = _decodeBooks(preferences.getStringList(_key));
    final snapshot = await _readSnapshot();
    for (final book in _decodeBookMaps(snapshot?['books'])) {
      if (!books.any((candidate) => candidate.id == book.id)) books.add(book);
    }
    books.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // If an update changed the preferences domain, the durable index in the
    // Documents container repopulates SharedPreferences automatically.
    if (books.isNotEmpty && preferences.getStringList(_key)?.isEmpty != false) {
      await preferences.setStringList(
        _key,
        books.map((item) => jsonEncode(item.toJson())).toList(),
      );
    }
    return books;
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
    await _writeSnapshot(books: books);
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
    await _writeSnapshot(books: books);
  }

  Future<List<GeneratedWordRecord>> loadWords() async {
    final preferences = await SharedPreferences.getInstance();
    final records = _decodeWords(preferences.getStringList(_wordKey));
    final snapshot = await _readSnapshot();
    for (final record in _decodeWordMaps(snapshot?['words'])) {
      if (!records.any((candidate) => candidate.word == record.word)) {
        records.add(record);
      }
    }
    if (records.isNotEmpty &&
        preferences.getStringList(_wordKey)?.isEmpty != false) {
      await preferences.setStringList(
        _wordKey,
        records.map((item) => jsonEncode(item.toJson())).toList(),
      );
    }
    return records;
  }

  List<GeneratedWordRecord> _decodeWords(List<String>? source) {
    final records = <GeneratedWordRecord>[];
    for (final item in source ?? const []) {
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
    await _writeSnapshot(words: records.toList());
  }

  List<GeneratedBook> _decodeBooks(List<String>? source) {
    final books = <GeneratedBook>[];
    for (final item in source ?? const []) {
      try {
        books.add(
          GeneratedBook.fromJson(jsonDecode(item) as Map<String, dynamic>),
        );
      } catch (_) {
        // Keep one malformed legacy item from hiding valid generated books.
      }
    }
    return books;
  }

  List<GeneratedBook> _decodeBookMaps(dynamic source) {
    if (source is! List) return const [];
    final books = <GeneratedBook>[];
    for (final item in source.whereType<Map>()) {
      try {
        books.add(GeneratedBook.fromJson(item.cast<String, dynamic>()));
      } catch (_) {}
    }
    return books;
  }

  List<GeneratedWordRecord> _decodeWordMaps(dynamic source) {
    if (source is! List) return const [];
    final records = <GeneratedWordRecord>[];
    for (final item in source.whereType<Map>()) {
      try {
        records.add(GeneratedWordRecord.fromJson(item.cast<String, dynamic>()));
      } catch (_) {}
    }
    return records;
  }

  Future<Map<String, dynamic>?> _readSnapshot() async {
    try {
      final directory = await _documentsDirectory();
      final file = File('${directory.path}/$_snapshotName');
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSnapshot({
    List<GeneratedBook>? books,
    List<GeneratedWordRecord>? words,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final existing = await _readSnapshot();
      final resolvedBooks =
          books ??
          _decodeBooks(
            preferences.getStringList(_key),
          ).ifEmpty(() => _decodeBookMaps(existing?['books']));
      final resolvedWords =
          words ??
          _decodeWords(
            preferences.getStringList(_wordKey),
          ).ifEmpty(() => _decodeWordMaps(existing?['words']));
      final directory = await _documentsDirectory();
      final file = File('${directory.path}/$_snapshotName');
      await file.writeAsString(
        jsonEncode({
          'version': 2,
          'books': resolvedBooks.map((item) => item.toJson()).toList(),
          'words': resolvedWords.map((item) => item.toJson()).toList(),
        }),
        encoding: utf8,
        flush: true,
      );
    } catch (_) {
      // SharedPreferences remains the fallback on platforms where the
      // documents provider is temporarily unavailable.
    }
  }
}

extension _ListFallback<T> on List<T> {
  List<T> ifEmpty(List<T> Function() fallback) => isEmpty ? fallback() : this;
}
