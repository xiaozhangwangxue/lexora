import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/haptic_service.dart';
import '../services/history_service.dart';
import '../services/pdf_service.dart';
import '../services/word_service.dart';

enum WordSort { custom, alphabetical, length, difficulty }

enum ExampleAmount {
  none(0),
  one(1),
  upToThree(3);

  const ExampleAmount(this.count);
  final int count;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onGenerated});
  final VoidCallback onGenerated;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _words = <String>[];
  final _wordService = WordService();
  final _pdfService = PdfService();
  final _historyService = HistoryService();
  final _haptics = const HapticService();
  WordSort _sort = WordSort.custom;
  PdfFontSize _fontSize = PdfFontSize.medium;
  ExampleAmount _exampleAmount = ExampleAmount.one;
  bool _showCustomization = false;
  bool _generating = false;
  double _progress = 0;
  String _status = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addWord([String? raw]) {
    final strings = AppLocalizations.of(context);
    final word = (raw ?? _controller.text).trim().toLowerCase();
    if (!RegExp(r"^[a-z][a-z'-]*$").hasMatch(word)) {
      _message(strings.invalidWord);
      return;
    }
    if (_words.contains(word)) {
      _message(strings.duplicate(word));
      return;
    }
    setState(() {
      _words.add(word);
      _controller.clear();
      _sort = WordSort.custom;
    });
    _focusNode.requestFocus();
  }

  void _applySort(WordSort value) {
    setState(() {
      _sort = value;
      switch (value) {
        case WordSort.custom:
          break;
        case WordSort.alphabetical:
          _words.sort();
          break;
        case WordSort.length:
          _words.sort((a, b) => a.length.compareTo(b.length));
          break;
        case WordSort.difficulty:
          _words.sort((a, b) => _estimatedDifficulty(a).compareTo(_estimatedDifficulty(b)));
          break;
      }
    });
  }

  int _estimatedDifficulty(String word) =>
      word.length + word.split('').where((letter) => 'qxzj'.contains(letter)).length * 2;

  Future<void> _generate() async {
    if (_words.isEmpty || _generating) return;
    final strings = AppLocalizations.of(context);
    setState(() {
      _generating = true;
      _progress = 0;
      _status = strings.preparing;
    });
    unawaited(_haptics.generationStarted());
    try {
      final entries = await _wordService.lookupAll(
        List.of(_words),
        exampleCount: _exampleAmount.count,
        maxConcurrency: 4,
        onProgress: (completed, total, word) {
          if (!mounted) return;
          setState(() {
            _status = strings.lookup(word, completed, total);
            _progress = completed / total * .88;
          });
        },
      );
      setState(() {
        _status = strings.typesetting;
        _progress = .92;
      });
      final book = await _pdfService.create(entries, fontSize: _fontSize);
      await _historyService.save(book);
      setState(() => _progress = 1);
      await _haptics.generationCompleted();
      if (!mounted) return;
      widget.onGenerated();
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
          _status = '';
        });
      }
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(children: [
              const Spacer(),
              Text('Lexora', style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1.8,
              )),
              const SizedBox(height: 6),
              Text(strings.tagline,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !_generating,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: _addWord,
                decoration: InputDecoration(
                  hintText: strings.inputHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: strings.addWord,
                    onPressed: _generating ? null : _addWord,
                    icon: const Icon(Icons.keyboard_return_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _words.isEmpty || _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_generating ? strings.generating : strings.generate),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _generating
                      ? null
                      : () => setState(() => _showCustomization = !_showCustomization),
                  icon: Icon(_showCustomization ? Icons.expand_less : Icons.tune_rounded),
                  label: Text(strings.customize),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: _showCustomization
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: _PdfOptions(
                  fontSize: _fontSize,
                  exampleAmount: _exampleAmount,
                  enabled: !_generating,
                  onFontSizeChanged: (value) => setState(() => _fontSize = value),
                  onExampleAmountChanged: (value) => setState(() => _exampleAmount = value),
                ),
              ),
              if (_generating) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _progress, borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: Text(_status, style: theme.textTheme.bodySmall)),
              ],
              const SizedBox(height: 12),
              if (_words.isNotEmpty)
                Row(children: [
                  Expanded(child: Text(strings.wordCount(_words.length), style: theme.textTheme.titleSmall)),
                  PopupMenuButton<WordSort>(
                    initialValue: _sort,
                    onSelected: _applySort,
                    tooltip: strings.sortWords,
                    itemBuilder: (context) => [
                      PopupMenuItem(value: WordSort.custom, child: Text(strings.customOrder)),
                      PopupMenuItem(value: WordSort.alphabetical, child: Text(strings.alphabetical)),
                      PopupMenuItem(value: WordSort.length, child: Text(strings.wordLength)),
                      PopupMenuItem(value: WordSort.difficulty, child: Text(strings.estimatedDifficulty)),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.swap_vert_rounded, size: 18),
                      label: Text(switch (_sort) {
                        WordSort.custom => strings.custom,
                        WordSort.alphabetical => 'A–Z',
                        WordSort.length => strings.wordLength,
                        WordSort.difficulty => strings.estimatedDifficulty,
                      }),
                    ),
                  ),
                ]),
              const SizedBox(height: 8),
              Expanded(
                flex: 5,
                child: _words.isEmpty
                    ? _EmptyList(theme: theme, strings: strings)
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        onReorderStart: (_) => unawaited(_haptics.dragStarted()),
                        proxyDecorator: (child, index, animation) => AnimatedBuilder(
                          animation: animation,
                          builder: (context, _) => Transform.scale(
                            scale: 1 + animation.value * .015,
                            child: Material(
                              color: Colors.transparent,
                              elevation: 0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [BoxShadow(
                                      color: theme.shadowColor.withValues(alpha: .18 * animation.value),
                                      blurRadius: 22,
                                      offset: const Offset(0, 8),
                                    )],
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                        itemCount: _words.length,
                        onReorderItem: (oldIndex, newIndex) {
                          if (oldIndex == newIndex) return;
                          setState(() {
                            final word = _words.removeAt(oldIndex);
                            _words.insert(newIndex, word);
                            _sort = WordSort.custom;
                          });
                          unawaited(_haptics.itemReordered());
                        },
                        itemBuilder: (context, index) {
                          final word = _words[index];
                          return Dismissible(
                            key: ValueKey(word),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => setState(() => _words.remove(word)),
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.only(right: 24),
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
                            ),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(child: Text('${index + 1}')),
                                title: Text(word, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(strings.letters(word.length)),
                                trailing: ReorderableDelayedDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(Icons.drag_indicator_rounded),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PdfOptions extends StatelessWidget {
  const _PdfOptions({
    required this.fontSize,
    required this.exampleAmount,
    required this.enabled,
    required this.onFontSizeChanged,
    required this.onExampleAmountChanged,
  });

  final PdfFontSize fontSize;
  final ExampleAmount exampleAmount;
  final bool enabled;
  final ValueChanged<PdfFontSize> onFontSizeChanged;
  final ValueChanged<ExampleAmount> onExampleAmountChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(strings.pdfFontSize, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<PdfFontSize>(
            segments: [
              ButtonSegment(value: PdfFontSize.small, label: Text(strings.small)),
              ButtonSegment(value: PdfFontSize.medium, label: Text(strings.medium)),
              ButtonSegment(value: PdfFontSize.large, label: Text(strings.large)),
            ],
            selected: {fontSize},
            onSelectionChanged: enabled ? (value) => onFontSizeChanged(value.first) : null,
          ),
        ),
        const SizedBox(height: 14),
        Text(strings.examples, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ExampleAmount>(
            segments: [
              ButtonSegment(value: ExampleAmount.none, label: Text(strings.noExamples)),
              ButtonSegment(value: ExampleAmount.one, label: Text(strings.oneExample)),
              ButtonSegment(value: ExampleAmount.upToThree, label: Text(strings.upToThreeExamples)),
            ],
            selected: {exampleAmount},
            onSelectionChanged: enabled ? (value) => onExampleAmountChanged(value.first) : null,
          ),
        ),
      ]),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.theme, required this.strings});
  final ThemeData theme;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.format_list_bulleted_add, size: 34, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          Text(strings.emptyTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(strings.emptyHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),
      );
}
