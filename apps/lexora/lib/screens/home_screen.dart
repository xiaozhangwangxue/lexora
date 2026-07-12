import 'package:flutter/material.dart';

import '../models/word_entry.dart';
import '../services/history_service.dart';
import '../services/pdf_service.dart';
import '../services/word_service.dart';

enum WordSort { custom, alphabetical, length, difficulty }

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
  WordSort _sort = WordSort.custom;
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
    final word = (raw ?? _controller.text).trim().toLowerCase();
    if (!RegExp(r"^[a-z][a-z'-]*$").hasMatch(word)) {
      _message('Please enter one English word.');
      return;
    }
    if (_words.contains(word)) {
      _message('“$word” is already in the list.');
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

  int _estimatedDifficulty(String word) => word.length +
      word.split('').where((letter) => 'qxzj'.contains(letter)).length * 2;

  Future<void> _generate() async {
    if (_words.isEmpty || _generating) return;
    setState(() {
      _generating = true;
      _progress = 0;
      _status = 'Preparing your vocabulary book…';
    });
    final entries = <WordEntry>[];
    try {
      for (var i = 0; i < _words.length; i++) {
        setState(() {
          _status = 'Looking up ${_words[i]}  ·  ${i + 1}/${_words.length}';
          _progress = i / (_words.length + 1);
        });
        entries.add(await _wordService.lookup(_words[i]));
      }
      setState(() {
        _status = 'Typesetting the bilingual PDF…';
        _progress = .92;
      });
      final book = await _pdfService.create(entries);
      await _historyService.save(book);
      setState(() => _progress = 1);
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

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Text('Words in. A beautiful bilingual book out.',
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
                  hintText: 'Type an English word and press Enter',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Add word',
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
                  label: Text(_generating ? 'Generating…' : 'Start generating'),
                ),
              ),
              if (_generating) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _progress, borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_status, style: theme.textTheme.bodySmall),
                ),
              ],
              const SizedBox(height: 18),
              if (_words.isNotEmpty)
                Row(children: [
                  Expanded(child: Text('${_words.length} ${_words.length == 1 ? 'word' : 'words'}',
                      style: theme.textTheme.titleSmall)),
                  PopupMenuButton<WordSort>(
                    initialValue: _sort,
                    onSelected: _applySort,
                    tooltip: 'Sort words',
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: WordSort.custom, child: Text('Custom order')),
                      PopupMenuItem(value: WordSort.alphabetical, child: Text('Alphabetical')),
                      PopupMenuItem(value: WordSort.length, child: Text('Word length')),
                      PopupMenuItem(value: WordSort.difficulty, child: Text('Estimated difficulty')),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.swap_vert_rounded, size: 18),
                      label: Text(switch (_sort) {
                        WordSort.custom => 'Custom',
                        WordSort.alphabetical => 'A–Z',
                        WordSort.length => 'Length',
                        WordSort.difficulty => 'Difficulty',
                      }),
                    ),
                  ),
                ]),
              const SizedBox(height: 8),
              Expanded(
                flex: 5,
                child: _words.isEmpty
                    ? _EmptyList(theme: theme)
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: _words.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final word = _words.removeAt(oldIndex);
                            _words.insert(newIndex, word);
                            _sort = WordSort.custom;
                          });
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
                                subtitle: Text('${word.length} letters'),
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

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.format_list_bulleted_add, size: 34, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          Text('Your words will appear here', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('Long-press to reorder · swipe left to delete',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),
      );
}
