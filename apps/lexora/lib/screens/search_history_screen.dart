import 'package:flutter/material.dart';

import '../services/search_history_service.dart';

class SearchHistoryScreen extends StatefulWidget {
  const SearchHistoryScreen({
    super.key,
    required this.onSearch,
    this.historyService,
  });

  final ValueChanged<String> onSearch;
  final SearchHistoryService? historyService;

  @override
  State<SearchHistoryScreen> createState() => _SearchHistoryScreenState();
}

class _SearchHistoryScreenState extends State<SearchHistoryScreen> {
  late final SearchHistoryService _service;
  late Future<List<SearchHistoryRecord>> _records;

  bool get _isZh =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';

  @override
  void initState() {
    super.initState();
    _service = widget.historyService ?? SearchHistoryService();
    _records = _service.load();
  }

  Future<void> _remove(SearchHistoryRecord record) async {
    await _service.remove(record);
    if (mounted) setState(() => _records = _service.load());
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
      final records = snapshot.data ?? const [];
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
      return ListView.separated(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        itemCount: records.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final record = records[index];
          return ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(
              record.resolvedWord,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              record.query == record.resolvedWord
                  ? _date(record.searchedAt)
                  : '${record.query} → ${record.resolvedWord}  ·  ${_date(record.searchedAt)}',
            ),
            trailing: IconButton(
              tooltip: _isZh ? '删除记录' : 'Delete',
              onPressed: () => _remove(record),
              icon: const Icon(Icons.close_rounded),
            ),
            onTap: () => widget.onSearch(record.resolvedWord),
          );
        },
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
