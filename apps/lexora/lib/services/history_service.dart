import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_entry.dart';

class HistoryService {
  static const _key = 'lexora.generated.books';

  Future<List<GeneratedBook>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_key) ?? const [])
        .map((item) => GeneratedBook.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            ))
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
    final preferences = await SharedPreferences.getInstance();
    final books = await load();
    books.removeWhere((item) => item.id == id);
    await preferences.setStringList(
      _key,
      books.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }
}
