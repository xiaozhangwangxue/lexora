import 'package:flutter/material.dart';

import '../services/search_history_service.dart';

enum SearchHistorySort { searchedTime, initialLetter, difficulty, frequency }

class SearchHistoryScreen extends StatefulWidget {
  const SearchHistoryScreen({
    super.key,
    required this.onSearch,
    required this.onCreateVocabularyBook,
    this.historyService,
  });

  final ValueChanged<String> onSearch;
  final ValueChanged<List<String>> onCreateVocabularyBook;
  final SearchHistoryService? historyService;

  @override
  State<SearchHistoryScreen> createState() => _SearchHistoryScreenState();
}

class _SearchHistoryScreenState extends State<SearchHistoryScreen> {
  late final SearchHistoryService _service;
  late Future<List<SearchHistoryRecord>> _records;
  SearchHistorySort _sort = SearchHistorySort.searchedTime;
  bool _ascending = false;
  bool _selecting = false;
  final Set<String> _selected = {};

  bool get _isZh =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';

  @override
  void initState() {
    super.initState();
    _service = widget.historyService ?? SearchHistoryService();
    _records = _service.load();
  }

  String _key(SearchHistoryRecord record) =>
      '${record.searchedAt.toIso8601String()}|${record.query}';

  Future<void> _removeMany(Iterable<SearchHistoryRecord> records) async {
    await _service.removeMany(records);
    if (!mounted) return;
    setState(() {
      _records = _service.load();
      _selected.clear();
      _selecting = false;
    });
  }

  List<SearchHistoryRecord> _sorted(List<SearchHistoryRecord> source) {
    final records = [...source];
    int compare(SearchHistoryRecord a, SearchHistoryRecord b) {
      switch (_sort) {
        case SearchHistorySort.searchedTime:
          return a.searchedAt.compareTo(b.searchedAt);
        case SearchHistorySort.initialLetter:
          return a.resolvedWord.toLowerCase().compareTo(
            b.resolvedWord.toLowerCase(),
          );
        case SearchHistorySort.difficulty:
          return a.entry.difficulty.compareTo(b.entry.difficulty);
        case SearchHistorySort.frequency:
          return a.entry.frequency.compareTo(b.entry.frequency);
      }
    }

    records.sort((a, b) => _ascending ? compare(a, b) : compare(b, a));
    return records;
  }

  void _createBook(List<SearchHistoryRecord> records) {
    final terms = records
        .where((record) => _selected.contains(_key(record)))
        .map((record) => record.resolvedWord)
        .toSet()
        .toList(growable: false);
    if (terms.isEmpty) return;
    widget.onCreateVocabularyBook(terms);
    setState(() {
      _selected.clear();
      _selecting = false;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<SearchHistoryRecord>>(
    future: _records,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final records = _sorted(snapshot.data ?? const []);
      if (records.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _isZh
                  ? '搜索过的单词和短语将显示在这里。'
                  : 'Words and phrases you search will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<SearchHistorySort>(
                  value: _sort,
                  items: [
                    DropdownMenuItem(
                      value: SearchHistorySort.searchedTime,
                      child: Text(_isZh ? '搜索时间' : 'Search time'),
                    ),
                    DropdownMenuItem(
                      value: SearchHistorySort.initialLetter,
                      child: Text(_isZh ? '首字母' : 'Initial'),
                    ),
                    DropdownMenuItem(
                      value: SearchHistorySort.difficulty,
                      child: Text(_isZh ? '难度' : 'Difficulty'),
                    ),
                    DropdownMenuItem(
                      value: SearchHistorySort.frequency,
                      child: Text(_isZh ? '词频' : 'Frequency'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sort = value);
                  },
                ),
                IconButton(
                  tooltip: _ascending
                      ? (_isZh ? '升序' : 'Ascending')
                      : (_isZh ? '降序' : 'Descending'),
                  onPressed: () => setState(() => _ascending = !_ascending),
                  icon: Icon(
                    _ascending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => setState(() {
                    _selecting = !_selecting;
                    if (!_selecting) _selected.clear();
                  }),
                  icon: Icon(
                    _selecting ? Icons.close_rounded : Icons.checklist_rounded,
                  ),
                  label: Text(
                    _selecting
                        ? (_isZh ? '取消' : 'Cancel')
                        : (_isZh ? '多选' : 'Select'),
                  ),
                ),
              ],
            ),
          ),
          if (_selecting)
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    final all = records.map(_key).toSet();
                    if (_selected.length == all.length) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(all);
                    }
                  }),
                  child: Text(_isZh ? '全选' : 'Select all'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _removeMany(
                          records.where(
                            (record) => _selected.contains(_key(record)),
                          ),
                        ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(_isZh ? '删除' : 'Delete'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _createBook(records),
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: Text(_isZh ? '生成词汇书' : 'Create book'),
                ),
              ],
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 6, bottom: 36),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final record = records[index];
                final key = _key(record);
                return ListTile(
                  leading: _selecting
                      ? Checkbox(
                          value: _selected.contains(key),
                          onChanged: (_) => setState(() {
                            _selected.contains(key)
                                ? _selected.remove(key)
                                : _selected.add(key);
                          }),
                        )
                      : const Icon(Icons.history_rounded),
                  title: Text(
                    record.resolvedWord,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${record.entry.difficulty} · '
                    'freq ${record.entry.frequency.toStringAsFixed(1)} · '
                    '${_date(record.searchedAt)}'
                    '${record.query == record.resolvedWord ? '' : '\n${record.query} → ${record.resolvedWord}'}',
                  ),
                  trailing: _selecting
                      ? null
                      : IconButton(
                          tooltip: _isZh ? '删除记录' : 'Delete',
                          onPressed: () => _removeMany([record]),
                          icon: const Icon(Icons.close_rounded),
                        ),
                  onTap: _selecting
                      ? () => setState(() {
                          _selected.contains(key)
                              ? _selected.remove(key)
                              : _selected.add(key);
                        })
                      : () => widget.onSearch(record.resolvedWord),
                );
              },
            ),
          ),
        ],
      );
    },
  );

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
