import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/word_entry.dart';
import '../services/search_history_service.dart';
import '../services/word_service.dart';
import '../widgets/lexora_wordmark.dart';

class SearchScreenController {
  void Function(String term)? _search;
  VoidCallback? _reset;

  void search(String term) => _search?.call(term);
  void reset() => _reset?.call();
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.active,
    required this.controller,
    required this.vocabularyTerms,
    required this.onVocabularyChanged,
    required this.onHistoryChanged,
    this.onResultVisibilityChanged,
    this.textScale = 1,
    this.wordService,
    this.historyService,
  });

  final bool active;
  final SearchScreenController controller;
  final List<String> vocabularyTerms;
  final ValueChanged<List<String>> onVocabularyChanged;
  final VoidCallback onHistoryChanged;
  final ValueChanged<bool>? onResultVisibilityChanged;
  final double textScale;
  final WordService? wordService;
  final SearchHistoryService? historyService;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final WordService _wordService;
  late final SearchHistoryService _historyService;
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  List<SearchHistoryRecord> _history = const [];
  List<String> _remoteSuggestions = const [];
  WordEntry? _entry;
  String _searchedTerm = '';
  String? _error;
  bool _loading = false;
  Timer? _debounce;
  int _suggestionRevision = 0;

  bool get _isZh =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';

  @override
  void initState() {
    super.initState();
    _wordService = widget.wordService ?? WordService();
    _historyService = widget.historyService ?? SearchHistoryService();
    widget.controller._search = _search;
    widget.controller._reset = _reset;
    unawaited(_reloadHistory());
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._search = null;
      oldWidget.controller._reset = null;
      widget.controller._search = _search;
      widget.controller._reset = _reset;
    }
    if (oldWidget.active && !widget.active) {
      _focusNode.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
  }

  @override
  void dispose() {
    widget.controller._search = null;
    widget.controller._reset = null;
    _debounce?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _reloadHistory() async {
    final history = await _historyService.load();
    if (mounted) setState(() => _history = history);
  }

  void _queryChanged(String value) {
    _debounce?.cancel();
    final query = _normalize(value);
    if (query.isEmpty) {
      setState(() => _remoteSuggestions = const []);
      widget.onResultVisibilityChanged?.call(
        _entry != null || _loading || _error != null,
      );
      return;
    }
    _wordService.allowSuggestionCaching();
    final revision = ++_suggestionRevision;
    _debounce = Timer(const Duration(milliseconds: 130), () async {
      final suggestions = await _wordService.suggest(query, maxResults: 12);
      if (!mounted || revision != _suggestionRevision) return;
      setState(() => _remoteSuggestions = suggestions);
      final visibleTerms = <String>{
        ..._matchingHistory.map((record) => record.resolvedWord),
        ...suggestions,
      };
      widget.onResultVisibilityChanged?.call(visibleTerms.isNotEmpty);
      unawaited(
        _wordService.prefetchAll(
          visibleTerms,
          exampleCount: 3,
          maxConcurrency: 4,
        ),
      );
    });
    setState(() {});
    widget.onResultVisibilityChanged?.call(_matchingHistory.isNotEmpty);
  }

  List<SearchHistoryRecord> get _matchingHistory {
    final query = _normalize(_textController.text);
    if (query.isEmpty) return const [];
    final matches = _history.where((record) {
      final candidate = _normalize(record.resolvedWord);
      final original = _normalize(record.query);
      return candidate.contains(query) || original.contains(query);
    }).toList();
    matches.sort((a, b) {
      final aPrefix =
          _normalize(a.resolvedWord).startsWith(query) ||
          _normalize(a.query).startsWith(query);
      final bPrefix =
          _normalize(b.resolvedWord).startsWith(query) ||
          _normalize(b.query).startsWith(query);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
      return b.searchedAt.compareTo(a.searchedAt);
    });
    return matches.take(5).toList(growable: false);
  }

  List<String> get _freshSuggestions {
    final searched = {
      for (final record in _matchingHistory) _normalize(record.resolvedWord),
      for (final record in _matchingHistory) _normalize(record.query),
    };
    return _remoteSuggestions
        .where((item) => !searched.contains(_normalize(item)))
        .take(7)
        .toList(growable: false);
  }

  Future<void> _search(String raw) async {
    final term = _normalize(raw);
    if (term.isEmpty) return;
    _debounce?.cancel();
    _suggestionRevision++;
    _textController.text = term;
    _textController.selection = TextSelection.collapsed(offset: term.length);
    _focusNode.unfocus();
    widget.onResultVisibilityChanged?.call(true);
    setState(() {
      _loading = true;
      _error = null;
      _remoteSuggestions = const [];
      _searchedTerm = term;
    });
    final result = await _wordService.lookupAll(
      [term],
      exampleCount: 3,
      maxConcurrency: 1,
    );
    if (!mounted) return;
    if (result.entries.isEmpty) {
      setState(() {
        _loading = false;
        _entry = null;
        _error = _isZh
            ? '没有找到“$term”的可靠词典结果。请检查拼写后重试。'
            : 'No reliable dictionary result was found for “$term”. Check the spelling and try again.';
      });
      widget.onResultVisibilityChanged?.call(false);
      return;
    }
    final entry = result.entries.first;
    await _historyService.record(term, entry);
    await _wordService.retainOnly(entry.word, exampleCount: 3);
    await _reloadHistory();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _entry = entry;
    });
    widget.onResultVisibilityChanged?.call(true);
    widget.onHistoryChanged();
  }

  void _toggleVocabulary() {
    final entry = _entry;
    if (entry != null) _toggleVocabularyEntry(entry);
  }

  void _toggleVocabularyEntry(WordEntry entry) {
    final next = [...widget.vocabularyTerms];
    final index = next.indexWhere(
      (item) => _normalize(item) == _normalize(entry.word),
    );
    final added = index < 0;
    if (added) {
      next.add(entry.word);
    } else {
      next.removeAt(index);
    }
    HapticFeedback.selectionClick();
    widget.onVocabularyChanged(next);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1700),
          behavior: SnackBarBehavior.floating,
          content: Text(
            added
                ? (_isZh ? '已添加到“词汇书”列表' : 'Added to Vocabulary Book')
                : (_isZh ? '已从“词汇书”列表移除' : 'Removed from Vocabulary Book'),
          ),
        ),
      );
  }

  bool get _isAdded {
    final entry = _entry;
    if (entry == null) return false;
    return widget.vocabularyTerms.any(
      (item) => _normalize(item) == _normalize(entry.word),
    );
  }

  void _reset() {
    _debounce?.cancel();
    _suggestionRevision++;
    _focusNode.unfocus();
    _textController.clear();
    setState(() {
      _remoteSuggestions = const [];
      _entry = null;
      _searchedTerm = '';
      _error = null;
      _loading = false;
    });
    widget.onResultVisibilityChanged?.call(false);
  }

  Future<void> _showWordPreview(String term) async {
    final normalized = _normalize(term);
    if (normalized.isEmpty || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _WordPreviewSheet(
        term: normalized,
        wordService: _wordService,
        isZh: _isZh,
        vocabularyTerms: widget.vocabularyTerms,
        onToggleVocabulary: _toggleVocabularyEntry,
        onSearch: (next) {
          Navigator.of(sheetContext).pop();
          _search(next);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scaledMedia = media.copyWith(
      textScaler: TextScaler.linear(
        (media.textScaler.scale(16) / 16 * widget.textScale).clamp(.7, 2),
      ),
    );
    return MediaQuery(data: scaledMedia, child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final hasQuery = _textController.text.trim().isNotEmpty;
    final showSuggestions =
        _focusNode.hasFocus &&
        hasQuery &&
        (_matchingHistory.isNotEmpty || _freshSuggestions.isNotEmpty);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final compactHeader =
        _entry != null || _loading || _error != null || showSuggestions;
    final motionDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 340);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              children: [
                AnimatedSize(
                  duration: motionDuration,
                  curve: const Cubic(.22, 1, .36, 1),
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: compactHeader ? 8 : 220,
                    child: compactHeader
                        ? null
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: LexoraWordmark(fontSize: 64, hero: true),
                            ),
                          ),
                  ),
                ),
                _SearchField(
                  controller: _textController,
                  focusNode: _focusNode,
                  hint: _isZh ? '搜索英文单词或短语' : 'Search a word or phrase',
                  onChanged: _queryChanged,
                  onSubmitted: _search,
                ),
                AnimatedSwitcher(
                  duration: reduceMotion
                      ? const Duration(milliseconds: 100)
                      : const Duration(milliseconds: 260),
                  switchInCurve: const Cubic(.22, 1, .36, 1),
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) {
                    final fade = FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                    if (reduceMotion) return fade;
                    return SizeTransition(
                      sizeFactor: animation,
                      alignment: Alignment.topCenter,
                      child: fade,
                    );
                  },
                  child: showSuggestions
                      ? _SuggestionPanel(
                          key: const ValueKey('suggestions'),
                          history: _matchingHistory,
                          fresh: _freshSuggestions,
                          isZh: _isZh,
                          onSelected: _search,
                        )
                      : const SizedBox(key: ValueKey('no-suggestions')),
                ),
                if (_entry == null && !_loading && _error == null)
                  const Spacer(flex: 3)
                else
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? _SearchError(message: _error!)
                        : _ResultView(
                            entry: _entry!,
                            searchedTerm: _searchedTerm,
                            isZh: _isZh,
                            added: _isAdded,
                            onToggleVocabulary: _toggleVocabulary,
                            onSearch: _search,
                            onPreview: _showWordPreview,
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    textInputAction: TextInputAction.search,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: IconButton(
        tooltip: hint,
        onPressed: () => onSubmitted(controller.text),
        icon: const Icon(Icons.keyboard_return_rounded),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
    ),
  );
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    super.key,
    required this.history,
    required this.fresh,
    required this.isZh,
    required this.onSelected,
  });

  final List<SearchHistoryRecord> history;
  final List<String> fresh;
  final bool isZh;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 6),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: [
            if (history.isNotEmpty) ...[
              _heading(context, isZh ? '搜索过' : 'From your history'),
              for (final record in history)
                _row(
                  context,
                  icon: Icons.history_rounded,
                  term: record.resolvedWord,
                  subtitle: record.query == record.resolvedWord
                      ? null
                      : record.query,
                ),
            ],
            if (fresh.isNotEmpty) ...[
              if (history.isNotEmpty) const Divider(height: 12),
              _heading(context, isZh ? '其他联想' : 'Other suggestions'),
              for (final term in fresh)
                _row(context, icon: Icons.search_rounded, term: term),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String value) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 7, 18, 4),
    child: Text(
      value,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String term,
    String? subtitle,
  }) => ListTile(
    dense: true,
    leading: Icon(icon, size: 20),
    title: Text(term, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: IconButton(
      tooltip: isZh ? '搜索 $term' : 'Search $term',
      onPressed: () => onSelected(term),
      icon: const Icon(Icons.keyboard_return_rounded, size: 20),
    ),
    onTap: () => onSelected(term),
  );
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.entry,
    required this.searchedTerm,
    required this.isZh,
    required this.added,
    required this.onToggleVocabulary,
    required this.onSearch,
    required this.onPreview,
    this.scrollController,
  });

  final WordEntry entry;
  final String searchedTerm;
  final bool isZh;
  final bool added;
  final VoidCallback onToggleVocabulary;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onPreview;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senses = entry.senses.isEmpty
        ? [
            WordSense(
              partOfSpeech: '',
              definitions: [
                BilingualDefinition(
                  definition: entry.definition,
                  definitionZh: entry.definitionZh,
                ),
              ],
            ),
          ]
        : entry.senses;
    return SelectionArea(
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.only(top: 22, bottom: 40),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.word,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                  if (entry.isFuzzyMatch)
                    Text(
                      isZh
                          ? '由“${entry.originalTerm}”匹配'
                          : 'Matched from “${entry.originalTerm}”',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    'US ${entry.usPhonetic}   ·   UK ${entry.ukPhonetic}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
              final metrics = Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  Chip(label: Text(entry.difficulty)),
                  Chip(
                    label: Text('freq ${entry.frequency.toStringAsFixed(1)}'),
                  ),
                  IconButton(
                    tooltip: isZh
                        ? '难度和词频说明'
                        : 'About difficulty and frequency',
                    onPressed: () => _showMetricsHelp(context),
                    icon: Icon(
                      Icons.help_outline_rounded,
                      size: 19,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        tooltip: added
                            ? (isZh ? '从词汇书移除' : 'Remove from Vocabulary Book')
                            : (isZh ? '添加到词汇书' : 'Add to Vocabulary Book'),
                        onPressed: onToggleVocabulary,
                        icon: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? const Duration(milliseconds: 100)
                              : const Duration(milliseconds: 180),
                          switchInCurve: const Cubic(.22, 1, .36, 1),
                          child: Icon(
                            added ? Icons.check_rounded : Icons.add_rounded,
                            key: ValueKey(added),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  metrics,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          for (final sense in senses)
            if (sense.definitions.isNotEmpty)
              _section(
                context,
                title: sense.partOfSpeech.isEmpty
                    ? (isZh ? '释义' : 'Definitions')
                    : _partOfSpeechLabel(sense.partOfSpeech, isZh),
                children: [
                  for (final definition in sense.definitions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(definition.definition),
                          if (definition.definitionZh.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                definition.definitionZh,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
          if (entry.relatedWords.isNotEmpty)
            _section(
              context,
              title: isZh ? '联想词' : 'Related words',
              children: [
                for (final related in entry.relatedWords)
                  _LinkedDefinition(
                    word: related.word,
                    meaning: related.meaning,
                    meaningZh: related.meaningZh,
                    onTap: onSearch,
                    onDoubleTap: onPreview,
                  ),
              ],
            ),
          if (entry.synonyms.isNotEmpty)
            _WordLinks(
              title: isZh ? '近义词' : 'Synonyms',
              words: entry.synonyms,
              translation: entry.synonymsZh,
              translations: entry.synonymTranslations,
              onSearch: onSearch,
              onPreview: onPreview,
            ),
          if (entry.antonyms.isNotEmpty)
            _WordLinks(
              title: isZh ? '反义词' : 'Antonyms',
              words: entry.antonyms,
              translation: entry.antonymsZh,
              translations: entry.antonymTranslations,
              onSearch: onSearch,
              onPreview: onPreview,
            ),
          if (entry.examples.isNotEmpty)
            _section(
              context,
              title: isZh ? '例句' : 'Examples',
              children: [
                for (var index = 0; index < entry.examples.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightedText(
                          text: entry.examples[index],
                          term: searchedTerm,
                        ),
                        if (index < entry.examplesZh.length)
                          Text(
                            entry.examplesZh[index],
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          if (entry.phrases.isNotEmpty)
            _section(
              context,
              title: isZh ? '短语与常用搭配' : 'Phrases & collocations',
              children: [
                for (final phrase in entry.phrases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightedText(
                          text: phrase.phrase,
                          term: searchedTerm,
                        ),
                        if (phrase.meaning.isNotEmpty) Text(phrase.meaning),
                        if (phrase.meaningZh.isNotEmpty)
                          Text(
                            phrase.meaningZh,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );

  Future<void> _showMetricsHelp(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.insights_outlined),
      title: Text(isZh ? '难度与词频' : 'Difficulty & frequency'),
      content: Text(
        isZh
            ? '难度使用 CEFR 等级：A1–A2 为基础，B1–B2 为中级，C1–C2 为高级。词频是语料库中的相对常见程度，数值越高通常越常用；它不是百分比。'
            : 'Difficulty follows CEFR: A1–A2 is foundational, B1–B2 intermediate, and C1–C2 advanced. Frequency is a relative corpus score: higher usually means more common; it is not a percentage.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isZh ? '知道了' : 'Got it'),
        ),
      ],
    ),
  );
}

class _LinkedDefinition extends StatelessWidget {
  const _LinkedDefinition({
    required this.word,
    required this.meaning,
    required this.meaningZh,
    required this.onTap,
    required this.onDoubleTap,
  });

  final String word;
  final String meaning;
  final String meaningZh;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onDoubleTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onTap(word),
          onDoubleTap: () => onDoubleTap(word),
          child: Text(
            word,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        if (meaning.isNotEmpty) Text(meaning),
        if (meaningZh.isNotEmpty)
          Text(
            meaningZh,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    ),
  );
}

class _WordLinks extends StatelessWidget {
  const _WordLinks({
    required this.title,
    required this.words,
    required this.translation,
    required this.translations,
    required this.onSearch,
    required this.onPreview,
  });

  final String title;
  final List<String> words;
  final String translation;
  final Map<String, String> translations;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onPreview;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 7,
          children: [
            for (final word in words)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => onSearch(word),
                    onDoubleTap: () => onPreview(word),
                    child: Text(
                      word,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  if (translations[word]?.isNotEmpty == true)
                    Text(
                      translations[word]!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (translations.isEmpty && translation.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            translation,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}

String _partOfSpeechLabel(String value, bool isZh) {
  if (!isZh) return value;
  const translations = {
    'noun': '名词',
    'verb': '动词',
    'adjective': '形容词',
    'adverb': '副词',
    'pronoun': '代词',
    'preposition': '介词',
    'conjunction': '连词',
    'interjection': '感叹词',
    'determiner': '限定词',
    'article': '冠词',
    'numeral': '数词',
    'auxiliary verb': '助动词',
    'modal verb': '情态动词',
    'phrase': '短语',
  };
  final normalized = value.trim().toLowerCase();
  final translated = translations[normalized];
  return translated == null ? value : '$value · $translated';
}

class _WordPreviewSheet extends StatefulWidget {
  const _WordPreviewSheet({
    required this.term,
    required this.wordService,
    required this.isZh,
    required this.vocabularyTerms,
    required this.onToggleVocabulary,
    required this.onSearch,
  });

  final String term;
  final WordService wordService;
  final bool isZh;
  final List<String> vocabularyTerms;
  final ValueChanged<WordEntry> onToggleVocabulary;
  final ValueChanged<String> onSearch;

  @override
  State<_WordPreviewSheet> createState() => _WordPreviewSheetState();
}

class _WordPreviewSheetState extends State<_WordPreviewSheet> {
  late final Future<WordEntry> _entry = _load();
  bool? _addedOverride;

  Future<WordEntry> _load() async {
    final result = await widget.wordService.lookupAll(
      [widget.term],
      exampleCount: 3,
      maxConcurrency: 1,
    );
    if (result.entries.isEmpty) {
      throw WordLookupException(
        widget.isZh ? '没有找到可靠的词典结果。' : 'No reliable result was found.',
      );
    }
    return result.entries.first;
  }

  bool _isAdded(WordEntry entry) =>
      _addedOverride ??
      widget.vocabularyTerms.any(
        (item) => item.trim().toLowerCase() == entry.word.trim().toLowerCase(),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: .54,
      minChildSize: .28,
      maxChildSize: .96,
      snap: true,
      snapSizes: const [.54, .96],
      shouldCloseOnMinExtent: true,
      expand: false,
      builder: (context, scrollController) => Material(
        color: theme.colorScheme.surface,
        elevation: 12,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Stack(
          children: [
            FutureBuilder<WordEntry>(
              future: _entry,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return CustomScrollView(
                    controller: scrollController,
                    slivers: const [
                      SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverFillRemaining(
                        child: _SearchError(
                          message: snapshot.error?.toString() ?? '',
                        ),
                      ),
                    ],
                  );
                }
                final entry = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                  child: _ResultView(
                    entry: entry,
                    searchedTerm: widget.term,
                    isZh: widget.isZh,
                    added: _isAdded(entry),
                    onToggleVocabulary: () {
                      widget.onToggleVocabulary(entry);
                      setState(() => _addedOverride = !_isAdded(entry));
                    },
                    onSearch: widget.onSearch,
                    onPreview: widget.onSearch,
                    scrollController: scrollController,
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                child: Container(
                  width: 38,
                  height: 5,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({required this.text, required this.term});
  final String text;
  final String term;

  @override
  Widget build(BuildContext context) {
    final query = term.trim();
    if (query.isEmpty) return Text(text);
    final matches = RegExp(
      RegExp.escape(query),
      caseSensitive: false,
    ).allMatches(text).toList();
    if (matches.isEmpty) return Text(text);
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(children: spans));
  }
}
