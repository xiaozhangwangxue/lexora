import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_entry.dart';

class SearchHistoryRecord {
  const SearchHistoryRecord({
    required this.query,
    required this.resolvedWord,
    required this.searchedAt,
    required this.entry,
  });

  final String query;
  final String resolvedWord;
  final DateTime searchedAt;
  final WordEntry entry;

  Map<String, dynamic> toJson() => {
    'query': query,
    'resolvedWord': resolvedWord,
    'searchedAt': searchedAt.toIso8601String(),
    'entry': entry.toJson(),
  };

  factory SearchHistoryRecord.fromJson(Map<String, dynamic> json) =>
      SearchHistoryRecord(
        query: json['query'] as String? ?? '',
        resolvedWord: json['resolvedWord'] as String? ?? '',
        searchedAt: DateTime.parse(json['searchedAt'] as String),
        entry: WordEntry.fromJson(json['entry'] as Map<String, dynamic>),
      );
}

class SearchHistoryService {
  static const _key = 'lexora.search.history.v1';
  static const _limit = 120;

  Future<List<SearchHistoryRecord>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return const [];
    try {
      final records = (jsonDecode(raw) as List)
          .map(
            (item) =>
                SearchHistoryRecord.fromJson(item as Map<String, dynamic>),
          )
          .where(
            (item) => item.query.isNotEmpty && item.resolvedWord.isNotEmpty,
          )
          .toList();
      records.sort((a, b) => b.searchedAt.compareTo(a.searchedAt));
      return records;
    } catch (_) {
      return const [];
    }
  }

  Future<void> record(String query, WordEntry entry) async {
    final normalized = _normalize(query);
    final records = [...await load()]
      ..removeWhere(
        (item) =>
            _normalize(item.query) == normalized ||
            _normalize(item.resolvedWord) == _normalize(entry.word),
      )
      ..insert(
        0,
        SearchHistoryRecord(
          query: normalized,
          resolvedWord: entry.word,
          searchedAt: DateTime.now(),
          entry: entry,
        ),
      );
    await _save(records.take(_limit).toList(growable: false));
  }

  Future<void> remove(SearchHistoryRecord record) async {
    final records = [...await load()]
      ..removeWhere(
        (item) =>
            item.searchedAt == record.searchedAt && item.query == record.query,
      );
    await _save(records);
  }

  Future<void> clear() => _save(const []);

  Future<void> _save(List<SearchHistoryRecord> records) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(records.map((item) => item.toJson()).toList()),
    );
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
