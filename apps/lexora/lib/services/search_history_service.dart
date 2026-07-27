import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_entry.dart';
import 'developer_log_service.dart';

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
    final stopwatch = Stopwatch()..start();
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) {
      DeveloperLogService.instance.log(
        'history.search.loaded',
        data: {'durationMs': stopwatch.elapsedMilliseconds, 'records': 0},
      );
      return const [];
    }
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
      DeveloperLogService.instance.log(
        'history.search.loaded',
        data: {
          'durationMs': stopwatch.elapsedMilliseconds,
          'records': records.length,
        },
      );
      return records;
    } catch (error, stackTrace) {
      DeveloperLogService.instance.log(
        'history.search.load_failed',
        data: {'durationMs': stopwatch.elapsedMilliseconds},
        error: error,
        stackTrace: stackTrace,
      );
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
    final saved = records.take(_limit).toList(growable: false);
    await _save(saved);
    DeveloperLogService.instance.log(
      'history.search.recorded',
      data: {
        'query': normalized,
        'resolvedWord': entry.word,
        'fuzzy': entry.isFuzzyMatch,
        'records': saved.length,
      },
    );
  }

  Future<void> remove(SearchHistoryRecord record) async {
    final records = [...await load()]
      ..removeWhere(
        (item) =>
            item.searchedAt == record.searchedAt && item.query == record.query,
      );
    await _save(records);
    DeveloperLogService.instance.log(
      'history.search.removed_one',
      data: {'query': record.query, 'remaining': records.length},
    );
  }

  Future<void> removeMany(Iterable<SearchHistoryRecord> selected) async {
    final keys = selected
        .map((item) => '${item.searchedAt.toIso8601String()}|${item.query}')
        .toSet();
    final records = [...await load()]
      ..removeWhere(
        (item) =>
            keys.contains('${item.searchedAt.toIso8601String()}|${item.query}'),
      );
    await _save(records);
    DeveloperLogService.instance.log(
      'history.search.removed_many',
      data: {'removed': keys.length, 'remaining': records.length},
    );
  }

  Future<void> clear() async {
    await _save(const []);
    DeveloperLogService.instance.log('history.search.cleared');
  }

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
