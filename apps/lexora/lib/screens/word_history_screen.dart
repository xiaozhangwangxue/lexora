import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/word_entry.dart';
import '../services/history_service.dart';

enum WordHistorySort { generationCount, initialLetter, generatedTime, difficulty }

class WordHistoryScreen extends StatefulWidget {
  const WordHistoryScreen({super.key});

  @override
  State<WordHistoryScreen> createState() => _WordHistoryScreenState();
}

class _WordHistoryScreenState extends State<WordHistoryScreen> {
  final _service = HistoryService();
  late Future<List<GeneratedWordRecord>> _records;
  WordHistorySort _sort = WordHistorySort.generatedTime;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _records = _service.loadWords();
  }

  Future<void> _toggleStar(GeneratedWordRecord record) async {
    await _service.setWordStarred(record.word, !record.starred);
    if (mounted) setState(() => _records = _service.loadWords());
  }

  List<GeneratedWordRecord> _sorted(List<GeneratedWordRecord> records) {
    final sorted = [...records];
    sorted.sort((a, b) {
      if (a.starred != b.starred) return a.starred ? -1 : 1;
      final comparison = switch (_sort) {
        WordHistorySort.generationCount =>
          a.generationCount.compareTo(b.generationCount),
        WordHistorySort.initialLetter => a.word.compareTo(b.word),
        WordHistorySort.generatedTime =>
          a.lastGeneratedAt.compareTo(b.lastGeneratedAt),
        WordHistorySort.difficulty =>
          _difficultyScore(a.difficulty).compareTo(_difficultyScore(b.difficulty)),
      };
      return _ascending ? comparison : -comparison;
    });
    return sorted;
  }

  int _difficultyScore(String value) {
    if (value.startsWith('A')) return 1;
    if (value.startsWith('B')) return 2;
    if (value.startsWith('C')) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.history,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.wordHistorySubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<WordHistorySort>(
                      initialValue: _sort,
                      decoration: InputDecoration(
                        labelText: strings.sortBy,
                        prefixIcon: const Icon(Icons.sort_rounded),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: WordHistorySort.generationCount,
                          child: Text(strings.generationCount),
                        ),
                        DropdownMenuItem(
                          value: WordHistorySort.initialLetter,
                          child: Text(strings.initialLetter),
                        ),
                        DropdownMenuItem(
                          value: WordHistorySort.generatedTime,
                          child: Text(strings.generatedTime),
                        ),
                        DropdownMenuItem(
                          value: WordHistorySort.difficulty,
                          child: Text(strings.difficulty),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _sort = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: _ascending ? strings.ascending : strings.descending,
                    onPressed: () => setState(() => _ascending = !_ascending),
                    icon: Icon(
                      _ascending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<GeneratedWordRecord>>(
                    future: _records,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final records = _sorted(snapshot.data ?? const []);
                      if (records.isEmpty) {
                        return Center(child: Text(strings.emptyWordHistory));
                      }
                      return ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 7,
                              ),
                              leading: CircleAvatar(
                                child: Text(record.word.characters.first.toUpperCase()),
                              ),
                              title: Text(
                                record.word,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${strings.generatedTimes(record.generationCount)}  ·  '
                                '${record.difficulty}  ·  ${_formatDate(record.lastGeneratedAt)}',
                              ),
                              trailing: IconButton(
                                tooltip: record.starred
                                    ? strings.unstarWord
                                    : strings.starWord,
                                onPressed: () => _toggleStar(record),
                                icon: Icon(
                                  record.starred
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: record.starred
                                      ? Colors.amber.shade700
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
