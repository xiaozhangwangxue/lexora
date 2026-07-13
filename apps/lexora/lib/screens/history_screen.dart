import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/word_entry.dart';
import '../services/generation_progress.dart';
import '../services/history_service.dart';
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.progress,
    required this.onOpenBook,
  });

  final GenerationProgress progress;
  final ValueChanged<GeneratedBook> onOpenBook;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = HistoryService();
  late Future<List<GeneratedBook>> _books;
  final _selectedIds = <String>{};
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _books = _service.load();
  }

  Future<void> _export(GeneratedBook book) async {
    const pdfType = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
    );
    final output = await getSaveLocation(
      suggestedName: book.title,
      acceptedTypeGroups: const [pdfType],
    );
    if (output == null) return;
    await File(book.path).copy(output.path);
  }

  Future<void> _share(GeneratedBook book) async {
    final strings = AppLocalizations.of(context);
    await Share.shareXFiles(
      [XFile(book.path, mimeType: 'application/pdf')],
      subject: strings.vocabularyBook,
    );
  }

  Future<void> _delete(GeneratedBook book) async {
    await _service.remove(book.id);
    final file = File(book.path);
    if (await file.exists()) await file.delete();
    setState(() => _books = _service.load());
  }

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selectedIds.clear();
    });
  }

  void _toggleBook(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _toggleAll(List<GeneratedBook> books) {
    setState(() {
      if (_selectedIds.length == books.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(books.map((book) => book.id));
      }
    });
  }

  Future<void> _shareSelected(List<GeneratedBook> books) async {
    final strings = AppLocalizations.of(context);
    final files = <XFile>[];
    for (final book in books.where((book) => _selectedIds.contains(book.id))) {
      if (await File(book.path).exists()) {
        files.add(XFile(book.path, mimeType: 'application/pdf'));
      }
    }
    if (!mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.noFilesToShare)),
      );
      return;
    }
    await Share.shareXFiles(files, subject: strings.vocabularyBook);
  }

  Future<void> _deleteSelected(List<GeneratedBook> books) async {
    if (_selectedIds.isEmpty) return;
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text(strings.confirmDeleteTitle),
        content: Text(strings.confirmDeleteBody(_selectedIds.length)),
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
    final selected = Set<String>.of(_selectedIds);
    await _service.removeMany(selected);
    for (final book in books.where((book) => selected.contains(book.id))) {
      final file = File(book.path);
      if (await file.exists()) await file.delete();
    }
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _selecting = false;
      _books = _service.load();
    });
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    strings.generationRecords,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _toggleSelecting,
                  icon: Icon(_selecting
                      ? Icons.close_rounded
                      : Icons.library_add_check_outlined),
                  label: Text(_selecting
                      ? strings.finishSelecting
                      : strings.select),
                ),
              ]),
              const SizedBox(height: 4),
              Text(strings.historySubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              AnimatedBuilder(
                animation: widget.progress,
                builder: (context, _) => widget.progress.isVisible
                    ? Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: _GenerationProgressCard(
                          progress: widget.progress,
                          strings: strings,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: FutureBuilder<List<GeneratedBook>>(
                  future: _books,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final books = snapshot.data ?? const [];
                    if (books.isEmpty) {
                      return Center(child: Text(strings.emptyHistory));
                    }
                    return Column(children: [
                      if (_selecting) ...[
                        _BulkActionBar(
                          selectedCount: _selectedIds.length,
                          allSelected: _selectedIds.length == books.length,
                          onSelectAll: () => _toggleAll(books),
                          onShare: _selectedIds.isEmpty
                              ? null
                              : () => _shareSelected(books),
                          onDelete: _selectedIds.isEmpty
                              ? null
                              : () => _deleteSelected(books),
                          strings: strings,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Expanded(
                        child: ListView.separated(
                          itemCount: books.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final book = books[index];
                            final selected = _selectedIds.contains(book.id);
                            return Card(
                              color: selected
                                  ? theme.colorScheme.primaryContainer
                                      .withValues(alpha: .55)
                                  : null,
                              child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                            leading: _selecting
                                ? Checkbox(
                                    value: selected,
                                    onChanged: (_) => _toggleBook(book.id),
                                  )
                                : Container(
                                    width: 44,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                            title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${strings.termCount(book.wordCount)} · ${_formatDate(book.createdAt)}'),
                            onTap: _selecting
                                ? () => _toggleBook(book.id)
                                : () => widget.onOpenBook(book),
                            trailing: _selecting
                                ? null
                                : PopupMenuButton<String>(
                              tooltip: strings.moreActions,
                              onSelected: (action) {
                                if (action == 'export') _export(book);
                                if (action == 'share') _share(book);
                                if (action == 'delete') _delete(book);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  enabled: false,
                                  child: SizedBox(
                                    width: 250,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          strings.firstWords,
                                          style: theme.textTheme.labelLarge,
                                        ),
                                        const SizedBox(height: 7),
                                        if (book.previewWords.isEmpty)
                                          Text(
                                            strings.noPreviewWords,
                                            style: theme.textTheme.bodySmall,
                                          )
                                        else
                                          Wrap(
                                            spacing: 5,
                                            runSpacing: 5,
                                            children: [
                                              for (final word in book.previewWords)
                                                Chip(
                                                  visualDensity: VisualDensity.compact,
                                                  label: Text(word),
                                                ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const PopupMenuDivider(),
                                if (!Platform.isAndroid)
                                  PopupMenuItem(value: 'export', child: Text(strings.exportTo)),
                                PopupMenuItem(value: 'share', child: Text(strings.share)),
                                const PopupMenuDivider(),
                                PopupMenuItem(value: 'delete', child: Text(strings.delete)),
                              ],
                            ),
                              ),
                            );
                          },
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}'
        ' ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onShare,
    required this.onDelete,
    required this.strings,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback? onShare;
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
          child: Row(children: [
            Checkbox(
              value: allSelected,
              onChanged: (_) => onSelectAll(),
            ),
            Expanded(child: Text(strings.selectedCount(selectedCount))),
            IconButton(
              tooltip: strings.shareSelected,
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded),
            ),
            IconButton(
              tooltip: strings.deleteSelected,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ]),
        ),
      );
}

class _GenerationProgressCard extends StatelessWidget {
  const _GenerationProgressCard({
    required this.progress,
    required this.strings,
  });

  final GenerationProgress progress;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = progress.stage == GenerationStage.failed;
    final completed = progress.stage == GenerationStage.completed;
    final color = failed
        ? theme.colorScheme.error
        : completed
            ? Colors.teal
            : theme.colorScheme.primary;
    final title = switch (progress.stage) {
      GenerationStage.idle => '',
      GenerationStage.lookingUp => strings.lookupProgressTitle,
      GenerationStage.typesetting => strings.typesetting,
      GenerationStage.completed => strings.generationCompleted,
      GenerationStage.failed => strings.generationFailed,
    };
    final detail = switch (progress.stage) {
      GenerationStage.lookingUp => progress.currentTerm.isEmpty
          ? strings.preparing
          : strings.lookup(
              progress.currentTerm,
              progress.completed,
              progress.total,
            ),
      GenerationStage.typesetting => strings.typesettingHint,
      GenerationStage.completed => strings.generationCompletedHint,
      GenerationStage.failed => progress.error,
      GenerationStage.idle => '',
    };

    return Card(
      color: color.withValues(alpha: .09),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: .28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
              failed
                  ? Icons.error_outline_rounded
                  : completed
                      ? Icons.check_circle_outline_rounded
                      : Icons.auto_awesome_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text('${(progress.value * 100).round()}%'),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.value,
            color: color,
            backgroundColor: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ]),
      ),
    );
  }
}
