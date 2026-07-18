import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/word_entry.dart';
import '../services/history_service.dart';

enum WordHistorySort {
  generationCount,
  initialLetter,
  generatedTime,
  difficulty,
}

class WordHistoryScreen extends StatefulWidget {
  const WordHistoryScreen({
    super.key,
    required this.generationRunning,
    required this.onRegenerate,
    required this.onCustomizePdf,
  });

  final bool generationRunning;
  final ValueChanged<List<String>> onRegenerate;
  final Future<void> Function() onCustomizePdf;

  @override
  State<WordHistoryScreen> createState() => _WordHistoryScreenState();
}

class _WordHistoryScreenState extends State<WordHistoryScreen> {
  final _service = HistoryService();
  final _selectedWords = <String>{};
  late Future<List<GeneratedWordRecord>> _records;
  WordHistorySort _sort = WordHistorySort.generatedTime;
  bool _ascending = false;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _records = _service.loadWords();
  }

  Future<void> _toggleStar(GeneratedWordRecord record) async {
    await _service.setWordStarred(record.word, !record.starred);
    if (mounted) setState(() => _records = _service.loadWords());
  }

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selectedWords.clear();
    });
  }

  void _toggleWord(String word) {
    setState(() {
      if (!_selectedWords.add(word)) _selectedWords.remove(word);
    });
  }

  void _toggleAll(List<GeneratedWordRecord> records) {
    setState(() {
      if (_selectedWords.length == records.length) {
        _selectedWords.clear();
      } else {
        _selectedWords
          ..clear()
          ..addAll(records.map((record) => record.word));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedWords.isEmpty) return;
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text(strings.confirmDeleteTitle),
        content: Text(strings.confirmDeleteBody(_selectedWords.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.removeWords(Set<String>.of(_selectedWords));
    if (!mounted) return;
    setState(() {
      _selectedWords.clear();
      _selecting = false;
      _records = _service.loadWords();
    });
  }

  Future<void> _regenerateSelected(List<GeneratedWordRecord> records) async {
    final strings = AppLocalizations.of(context);
    if (widget.generationRunning) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.generationAlreadyRunning)));
      return;
    }
    if (_selectedWords.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.replay_rounded),
        title: Text(strings.confirmRegenerateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.confirmRegenerateBody(_selectedWords.length)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onCustomizePdf,
                icon: const Icon(Icons.tune_rounded),
                label: Text(strings.fineTuneTypography),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.regenerateSelected),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final words = [
      for (final record in records)
        if (_selectedWords.contains(record.word)) record.word,
    ];
    setState(() {
      _selectedWords.clear();
      _selecting = false;
    });
    widget.onRegenerate(words);
  }

  List<GeneratedWordRecord> _sorted(List<GeneratedWordRecord> records) {
    final sorted = [...records];
    sorted.sort((a, b) {
      if (a.starred != b.starred) return a.starred ? -1 : 1;
      final comparison = switch (_sort) {
        WordHistorySort.generationCount => a.generationCount.compareTo(
          b.generationCount,
        ),
        WordHistorySort.initialLetter => a.word.compareTo(b.word),
        WordHistorySort.generatedTime => a.lastGeneratedAt.compareTo(
          b.lastGeneratedAt,
        ),
        WordHistorySort.difficulty => _difficultyScore(
          a.difficulty,
        ).compareTo(_difficultyScore(b.difficulty)),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.history,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _toggleSelecting,
                      icon: Icon(
                        _selecting
                            ? Icons.close_rounded
                            : Icons.library_add_check_outlined,
                      ),
                      label: Text(
                        _selecting ? strings.finishSelecting : strings.select,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  strings.wordHistorySubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final sortField = DropdownButtonFormField<WordHistorySort>(
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
                    );
                    final orderButton = IconButton.filledTonal(
                      tooltip: _ascending
                          ? strings.ascending
                          : strings.descending,
                      onPressed: () => setState(() => _ascending = !_ascending),
                      icon: Icon(
                        _ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                      ),
                    );
                    if (constraints.maxWidth < 410) {
                      return Column(
                        children: [
                          sortField,
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: orderButton,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: sortField),
                        const SizedBox(width: 10),
                        orderButton,
                      ],
                    );
                  },
                ),
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
                      return Column(
                        children: [
                          if (_selecting) ...[
                            _WordBulkActionBar(
                              selectedCount: _selectedWords.length,
                              allSelected:
                                  _selectedWords.length == records.length,
                              onSelectAll: () => _toggleAll(records),
                              onRegenerate: _selectedWords.isEmpty
                                  ? null
                                  : () => _regenerateSelected(records),
                              onDelete: _selectedWords.isEmpty
                                  ? null
                                  : _deleteSelected,
                              strings: strings,
                            ),
                            const SizedBox(height: 12),
                          ],
                          Expanded(
                            child: ListView.separated(
                              itemCount: records.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final record = records[index];
                                final selected = _selectedWords.contains(
                                  record.word,
                                );
                                return Card(
                                  color: selected
                                      ? theme.colorScheme.primaryContainer
                                            .withValues(alpha: .55)
                                      : null,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 7,
                                    ),
                                    leading: _selecting
                                        ? Checkbox(
                                            value: selected,
                                            onChanged: (_) =>
                                                _toggleWord(record.word),
                                          )
                                        : CircleAvatar(
                                            child: Text(
                                              record.word.characters.first
                                                  .toUpperCase(),
                                            ),
                                          ),
                                    title: Text(
                                      record.word,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    subtitle: Text(
                                      '${strings.generatedTimes(record.generationCount)}  ·  '
                                      '${record.difficulty}  ·  ${_formatDate(record.lastGeneratedAt)}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: _selecting
                                        ? () => _toggleWord(record.word)
                                        : null,
                                    trailing: _selecting
                                        ? null
                                        : IconButton(
                                            tooltip: record.starred
                                                ? strings.unstarWord
                                                : strings.starWord,
                                            onPressed: () =>
                                                _toggleStar(record),
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
                            ),
                          ),
                        ],
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

class _WordBulkActionBar extends StatelessWidget {
  const _WordBulkActionBar({
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onRegenerate,
    required this.onDelete,
    required this.strings,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback? onRegenerate;
  final VoidCallback? onDelete;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Checkbox(value: allSelected, onChanged: (_) => onSelectAll()),
          Expanded(child: Text(strings.selectedCount(selectedCount))),
          FilledButton.tonalIcon(
            onPressed: onRegenerate,
            icon: const Icon(Icons.replay_rounded),
            label: Text(strings.regenerateSelected),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: strings.deleteSelected,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    ),
  );
}
