import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/haptic_service.dart';
import '../services/pdf_service.dart';
import '../services/pdf_settings_service.dart';

enum WordSort { custom, alphabetical, length, difficulty }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.generationRunning,
    required this.onStartGeneration,
    required this.onCustomizePdf,
  });

  final PdfSettings settings;
  final bool generationRunning;
  final ValueChanged<List<String>> onStartGeneration;
  final VoidCallback onCustomizePdf;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _words = <String>[];
  final _haptics = const HapticService();
  WordSort _sort = WordSort.custom;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addWord([String? raw]) {
    final strings = AppLocalizations.of(context);
    final word = (raw ?? _controller.text)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (!RegExp(r"^[a-z][a-z'-]*(?:\s+[a-z][a-z'-]*)*$")
        .hasMatch(word)) {
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
      word.replaceAll(' ', '').length +
      word.split('').where((letter) => 'qxzj'.contains(letter)).length * 2;

  Future<void> _generate() async {
    if (_words.isEmpty || widget.generationRunning) return;
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.auto_awesome_rounded),
        title: Text(strings.confirmGenerationTitle),
        content: Text(strings.confirmGenerationBody(_words.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.confirmGeneration),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (Platform.isAndroid) {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!mounted) return;
    final terms = List<String>.of(_words);
    setState(() {
      _words.clear();
      _sort = WordSort.custom;
    });
    widget.onStartGeneration(terms);
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final isMac = Platform.isMacOS;
    final itemRadius = isMac ? 12.0 : 20.0;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMac ? 920 : 840),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isMac ? 36 : 20,
              isMac ? 24 : 24,
              isMac ? 36 : 20,
              16,
            ),
            child: Column(children: [
              if (!isMac) const Spacer() else const SizedBox(height: 8),
              Align(
                alignment: isMac ? Alignment.centerLeft : Alignment.center,
                child: Text('Lexora', style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.8,
                )),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: isMac ? Alignment.centerLeft : Alignment.center,
                child: Text(strings.tagline,
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              SizedBox(height: isMac ? 20 : 24),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: _addWord,
                decoration: InputDecoration(
                  hintText: strings.inputHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: strings.addWord,
                    onPressed: _addWord,
                    icon: const Icon(Icons.keyboard_return_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: isMac ? 44 : 50,
                child: FilledButton.icon(
                  onPressed: _words.isEmpty || widget.generationRunning
                      ? null
                      : _generate,
                  icon: widget.generationRunning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(widget.generationRunning
                      ? strings.generationInProgress
                      : strings.generate),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onCustomizePdf,
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(
                    '${strings.pdfSettings}  ·  '
                    '${_fontSizeLabel(strings, widget.settings.fontSize)}  ·  '
                    '${_exampleLabel(strings, widget.settings.exampleAmount)}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_words.isNotEmpty)
                Row(children: [
                  Expanded(child: Text(strings.termCount(_words.length), style: theme.textTheme.titleSmall)),
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
                                borderRadius: BorderRadius.circular(itemRadius),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(itemRadius),
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
                                borderRadius: BorderRadius.circular(itemRadius),
                              ),
                              child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
                            ),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(child: Text('${index + 1}')),
                                title: Text(word, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${strings.characters(word.replaceAll(' ', '').length)}'
                                  '${word.contains(' ') ? ' · ${strings.phrase}' : ''}',
                                ),
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

  String _fontSizeLabel(AppLocalizations strings, PdfFontSize value) =>
      switch (value) {
        PdfFontSize.small => strings.small,
        PdfFontSize.medium => strings.medium,
        PdfFontSize.large => strings.large,
      };

  String _exampleLabel(AppLocalizations strings, ExampleAmount value) =>
      switch (value) {
        ExampleAmount.none => strings.noExamples,
        ExampleAmount.one => strings.oneExample,
        ExampleAmount.upToThree => strings.upToThreeExamples,
      };
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
