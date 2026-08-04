import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/beta_controller.dart';
import '../domain/learning_stats.dart';
import '../models/learning_models.dart';
import '../services/beta_speech_service.dart';
import '../widgets/beta_ui.dart';
import 'word_editor_dialog.dart';

enum _ContentFilter {
  all,
  withExamples,
  withoutExamples,
  withSources,
  withoutSources,
  withCollocations,
  withoutCollocations,
}

enum _PerformanceFilter { all, weak, important, dueToday, overdue }

enum _WordSort {
  recent,
  earliest,
  due,
  mostLapses,
  mostReviews,
  leastReviews,
  alphabetical,
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.controller});

  final BetaController controller;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _search = TextEditingController();
  final _add = TextEditingController();
  LearningStatus? _status;
  SkillTag? _tag;
  SourceType? _sourceType;
  _ContentFilter _content = _ContentFilter.all;
  _PerformanceFilter _performance = _PerformanceFilter.all;
  _WordSort _sort = _WordSort.recent;
  bool _adding = false;

  @override
  void dispose() {
    _search.dispose();
    _add.dispose();
    super.dispose();
  }

  List<LearningWord> _filteredWords(Map<String, List<ReviewLog>> logsByWord) {
    final data = widget.controller.data;
    final query = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    final words = data.words.where((word) {
      final review = data.reviewStates[word.id];
      if (review == null) return false;
      if (_status != null && review.status != _status) return false;
      if (_tag != null && !word.tags.contains(_tag)) return false;
      if (_sourceType != null &&
          !word.sources.any((source) => source.sourceType == _sourceType)) {
        return false;
      }
      final hasExamples = word.meanings.any(
        (meaning) => meaning.examples.isNotEmpty,
      );
      switch (_content) {
        case _ContentFilter.all:
          break;
        case _ContentFilter.withExamples:
          if (!hasExamples) return false;
        case _ContentFilter.withoutExamples:
          if (hasExamples) return false;
        case _ContentFilter.withSources:
          if (word.sources.isEmpty) return false;
        case _ContentFilter.withoutSources:
          if (word.sources.isNotEmpty) return false;
        case _ContentFilter.withCollocations:
          if (word.collocations.isEmpty) return false;
        case _ContentFilter.withoutCollocations:
          if (word.collocations.isNotEmpty) return false;
      }
      final logs = logsByWord[word.id] ?? const <ReviewLog>[];
      switch (_performance) {
        case _PerformanceFilter.all:
          break;
        case _PerformanceFilter.weak:
          if (!isWeakWord(review, logs)) return false;
        case _PerformanceFilter.important:
          if (!word.isImportant) return false;
        case _PerformanceFilter.dueToday:
          final end = DateTime(now.year, now.month, now.day + 1);
          if (review.dueAt.isAfter(end)) return false;
        case _PerformanceFilter.overdue:
          if (!review.dueAt.isBefore(now) ||
              review.status == LearningStatus.newWord) {
            return false;
          }
      }
      if (query.isEmpty) return true;
      final haystack = [
        word.text,
        ...word.meanings.expand(
          (meaning) => [
            meaning.definitionZh,
            meaning.definitionEn ?? '',
            ...meaning.examples.expand(
              (example) => [example.sentence, example.translation ?? ''],
            ),
          ],
        ),
        ...word.collocations.expand(
          (item) => [item.text, item.meaningZh, item.exampleSentence ?? ''],
        ),
        ...word.sources.expand(
          (source) => [source.title, source.originalSentence ?? ''],
        ),
        ...word.customTags,
      ].join('\n').toLowerCase();
      return haystack.contains(query);
    }).toList();
    words.sort((a, b) {
      final left = data.reviewStates[a.id]!;
      final right = data.reviewStates[b.id]!;
      return switch (_sort) {
        _WordSort.recent => b.createdAt.compareTo(a.createdAt),
        _WordSort.earliest => a.createdAt.compareTo(b.createdAt),
        _WordSort.due => left.dueAt.compareTo(right.dueAt),
        _WordSort.mostLapses => right.lapseCount.compareTo(left.lapseCount),
        _WordSort.mostReviews => right.totalReviews.compareTo(
          left.totalReviews,
        ),
        _WordSort.leastReviews => left.totalReviews.compareTo(
          right.totalReviews,
        ),
        _WordSort.alphabetical => a.normalizedText.compareTo(b.normalizedText),
      };
    });
    return words;
  }

  Future<void> _lookupAndAdd() async {
    final term = _add.text.trim();
    if (term.isEmpty || _adding) return;
    setState(() => _adding = true);
    try {
      final word = await widget.controller.lookupAndAdd(term);
      _add.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${word.text} 已加入学习单词库')));
      }
    } on DuplicateLearningWordException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('该单词已存在'),
            action: SnackBarAction(
              label: '查看',
              onPressed: () {
                final word = widget.controller.wordForId(error.wordId);
                if (word != null) unawaited(_showDetails(word));
              },
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final manual = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('未找到可靠词典结果'),
          content: Text('$error\n\n可以稍后重试，或手动创建词条。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('手动创建'),
            ),
          ],
        ),
      );
      if (manual == true && mounted) {
        await showWordEditorDialog(
          context,
          controller: widget.controller,
          initialText: term,
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _showDetails(LearningWord word) => showDialog<void>(
    context: context,
    builder: (dialogContext) => _WordDetailsDialog(
      controller: widget.controller,
      wordId: word.id,
      onEdit: (updated) async {
        Navigator.of(dialogContext).pop();
        await showWordEditorDialog(
          context,
          controller: widget.controller,
          word: updated,
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final logsByWord = groupReviewLogsByWord(widget.controller.data.reviewLogs);
    final words = _filteredWords(logsByWord);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BetaSectionTitle(
                '单词库',
                subtitle:
                    '搜索释义、例句、固定搭配、来源和标签；共 ${widget.controller.data.words.length} 个词。',
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  final addField = TextField(
                    controller: _add,
                    onSubmitted: (_) => _lookupAndAdd(),
                    decoration: InputDecoration(
                      labelText: '添加单词或短语',
                      hintText: '联网补全多释义、例句和搭配',
                      prefixIcon: const Icon(Icons.add_rounded),
                      suffixIcon: IconButton(
                        tooltip: '查词并添加',
                        onPressed: _adding ? null : _lookupAndAdd,
                        icon: _adding
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                  );
                  final searchField = TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: '搜索单词库',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  );
                  return compact
                      ? Column(
                          children: [
                            addField,
                            const SizedBox(height: 10),
                            searchField,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: addField),
                            const SizedBox(width: 10),
                            Expanded(child: searchField),
                          ],
                        );
                },
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Dropdown<LearningStatus?>(
                      value: _status,
                      label: '状态',
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('全部状态'),
                        ),
                        for (final value in LearningStatus.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_statusLabel(value)),
                          ),
                      ],
                      onChanged: (value) => setState(() => _status = value),
                    ),
                    _Dropdown<SkillTag?>(
                      value: _tag,
                      label: '四级分类',
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('全部分类'),
                        ),
                        for (final value in SkillTag.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_tagLabel(value)),
                          ),
                      ],
                      onChanged: (value) => setState(() => _tag = value),
                    ),
                    _Dropdown<SourceType?>(
                      value: _sourceType,
                      label: '来源类型',
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('全部来源'),
                        ),
                        for (final value in SourceType.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_sourceTypeLabel(value)),
                          ),
                      ],
                      onChanged: (value) => setState(() => _sourceType = value),
                    ),
                    _Dropdown<_ContentFilter>(
                      value: _content,
                      label: '数据',
                      items: [
                        for (final value in _ContentFilter.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_contentLabel(value)),
                          ),
                      ],
                      onChanged: (value) => setState(() => _content = value!),
                    ),
                    _Dropdown<_PerformanceFilter>(
                      value: _performance,
                      label: '表现',
                      items: [
                        for (final value in _PerformanceFilter.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_performanceLabel(value)),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _performance = value!),
                    ),
                    _Dropdown<_WordSort>(
                      value: _sort,
                      label: '排序',
                      items: [
                        for (final value in _WordSort.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_sortLabel(value)),
                          ),
                      ],
                      onChanged: (value) => setState(() => _sort = value!),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: words.isEmpty
              ? const _EmptyLibrary()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    final word = words[index];
                    final review =
                        widget.controller.data.reviewStates[word.id]!;
                    final logs = logsByWord[word.id] ?? const <ReviewLog>[];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BetaSurface(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            8,
                            10,
                            8,
                          ),
                          onTap: () => _showDetails(word),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  word.text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (word.isImportant)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.star_rounded,
                                    size: 18,
                                    color: Colors.amber,
                                  ),
                                ),
                              if (isWeakWord(review, logs))
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.healing_rounded, size: 18),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${word.meanings.firstOrNull?.definitionZh.isNotEmpty == true ? word.meanings.first.definitionZh : '暂无中文释义'}\n'
                            '${_statusLabel(review.status)} · ${_dueLabel(review)} · ${word.sources.length} 个来源',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: word.isImportant ? '取消重点' : '标记重点',
                            onPressed: () =>
                                widget.controller.toggleImportant(word.id),
                            icon: Icon(
                              word.isImportant
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _WordDetailsDialog extends StatelessWidget {
  const _WordDetailsDialog({
    required this.controller,
    required this.wordId,
    required this.onEdit,
  });

  final BetaController controller;
  final String wordId;
  final ValueChanged<LearningWord> onEdit;

  @override
  Widget build(BuildContext context) {
    final word = controller.wordForId(wordId);
    if (word == null) return const AlertDialog(content: Text('单词不存在'));
    final review = controller.data.reviewStates[wordId]!;
    final logs =
        controller.data.reviewLogs.where((log) => log.wordId == wordId).toList()
          ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    void speak(String text, PreferredAccent accent) {
      unawaited(
        BetaSpeechService.instance
            .speak(
              text,
              accent: accent,
              rate: controller.data.settings.speechRate,
            )
            .catchError((Object error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('朗读失败：$error')));
              }
            }),
      );
    }

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 10),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.text,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  [word.phoneticUS, word.phoneticUK]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '美式发音',
            onPressed: () => speak(word.text, PreferredAccent.us),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          IconButton(
            tooltip: '英式发音',
            onPressed: () => speak(word.text, PreferredAccent.uk),
            icon: const Icon(Icons.volume_up_outlined),
          ),
          IconButton(
            tooltip: '编辑',
            onPressed: () => onEdit(word),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final meaning in word.meanings) ...[
                Text(
                  '${meaning.partOfSpeech}  ${meaning.definitionZh}'.trim(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (meaning.definitionEn?.isNotEmpty == true)
                  Text(meaning.definitionEn!),
                for (final example in meaning.examples)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(example.sentence),
                    subtitle: Text(example.translation ?? ''),
                    trailing: IconButton(
                      tooltip: '朗读例句',
                      onPressed: () => speak(
                        example.sentence,
                        controller.data.settings.preferredAccent,
                      ),
                      icon: const Icon(Icons.volume_up_outlined),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              if (word.collocations.isNotEmpty) ...[
                const Divider(),
                Text('固定搭配', style: Theme.of(context).textTheme.titleMedium),
                for (final item in word.collocations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.text),
                    subtitle: Text(
                      '${item.meaningZh}\n${item.exampleSentence ?? ''}',
                    ),
                  ),
              ],
              if (word.sources.isNotEmpty) ...[
                const Divider(),
                Text('来源', style: Theme.of(context).textTheme.titleMedium),
                for (final source in word.sources)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(source.title),
                    subtitle: Text(
                      [
                            if (source.examYear != null) '${source.examYear} 年',
                            if (source.examMonth != null)
                              '${source.examMonth} 月',
                            source.section,
                            source.questionNumber,
                            source.originalSentence,
                            source.note,
                          ]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                    ),
                  ),
              ],
              const Divider(),
              Text('学习状态', style: Theme.of(context).textTheme.titleMedium),
              Text(
                '当前状态：${_statusLabel(review.status)}\n'
                '下次复习：${_dueLabel(review)}\n'
                '当前间隔：${review.intervalMinutes} 分钟\n'
                '连续认识：${review.consecutiveGoodCount}\n'
                '总复习：${review.totalReviews} · 不认识 ${review.againCount} · 模糊 ${review.hardCount} · 认识 ${review.goodCount}\n'
                '遗忘次数：${review.lapseCount}',
              ),
              if (logs.isNotEmpty) ...[
                const Divider(),
                Text('最近学习记录', style: Theme.of(context).textTheme.titleMedium),
                for (final log in logs.take(10))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      '${log.reviewedAt.toLocal()} · ${_ratingLabel(log.rating)}',
                    ),
                    subtitle: Text(
                      '${_modeLabel(log.reviewMode)} · ${log.userAnswer ?? '自我回忆'} · '
                      '${_statusLabel(log.previousStatus)} → ${_statusLabel(log.nextStatus)}',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (confirmContext) => AlertDialog(
                title: const Text('删除这个单词？'),
                content: const Text('相关复习状态、会话项和学习记录也会一并删除。此操作不可撤销。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(confirmContext).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(confirmContext).pop(true),
                    child: const Text('确认删除'),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await controller.deleteWord(wordId);
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('删除'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: DropdownButton<T>(
      value: value,
      hint: Text(label),
      items: items,
      onChanged: onChanged,
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.menu_book_outlined, size: 52),
        const SizedBox(height: 12),
        Text('还没有符合条件的单词', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('可以从上方查词添加，旧版查词和生成记录会在首次进入时自动迁移。'),
      ],
    ),
  );
}

String _statusLabel(LearningStatus value) => switch (value) {
  LearningStatus.newWord => '新单词',
  LearningStatus.learning => '学习中',
  LearningStatus.review => '复习中',
  LearningStatus.mastered => '已掌握',
  LearningStatus.lapsed => '遗忘重学',
};

String _dueLabel(ReviewState state) {
  if (state.status == LearningStatus.newWord) return '尚未学习';
  final difference = state.dueAt.difference(DateTime.now());
  if (difference.isNegative) return '已到期';
  if (difference.inHours < 1) return '${difference.inMinutes} 分钟后';
  if (difference.inDays < 1) return '${difference.inHours} 小时后';
  return '${difference.inDays} 天后';
}

String _tagLabel(SkillTag tag) => switch (tag) {
  SkillTag.listening => '听力',
  SkillTag.reading => '阅读',
  SkillTag.writing => '写作',
  SkillTag.translation => '翻译',
  SkillTag.highFrequency => '高频词',
  SkillTag.collocation => '固定搭配',
  SkillTag.confusing => '易混词',
  SkillTag.familiarWordNewMeaning => '熟词生义',
};

String _sourceTypeLabel(SourceType type) => switch (type) {
  SourceType.cet4Listening => '四级听力',
  SourceType.cet4Reading => '四级阅读',
  SourceType.cet4Writing => '四级写作',
  SourceType.cet4Translation => '四级翻译',
  SourceType.textbook => '教材',
  SourceType.manual => '手动添加',
  SourceType.other => '其他',
};

String _contentLabel(_ContentFilter value) => switch (value) {
  _ContentFilter.all => '全部数据',
  _ContentFilter.withExamples => '有例句',
  _ContentFilter.withoutExamples => '无例句',
  _ContentFilter.withSources => '有来源',
  _ContentFilter.withoutSources => '无来源',
  _ContentFilter.withCollocations => '有固定搭配',
  _ContentFilter.withoutCollocations => '无固定搭配',
};

String _performanceLabel(_PerformanceFilter value) => switch (value) {
  _PerformanceFilter.all => '全部表现',
  _PerformanceFilter.weak => '薄弱词',
  _PerformanceFilter.important => '重点词',
  _PerformanceFilter.dueToday => '今天到期',
  _PerformanceFilter.overdue => '已经过期',
};

String _sortLabel(_WordSort value) => switch (value) {
  _WordSort.recent => '最近添加',
  _WordSort.earliest => '最早添加',
  _WordSort.due => '最早到期',
  _WordSort.mostLapses => '遗忘最多',
  _WordSort.mostReviews => '复习最多',
  _WordSort.leastReviews => '复习最少',
  _WordSort.alphabetical => '字母顺序',
};

String _ratingLabel(ReviewRating value) => switch (value) {
  ReviewRating.again => '不认识',
  ReviewRating.hard => '模糊',
  ReviewRating.good => '认识',
};

String _modeLabel(ReviewMode value) => switch (value) {
  ReviewMode.wordToMeaning => '英译中',
  ReviewMode.meaningToWord => '中译英',
  ReviewMode.spelling => '拼写',
  ReviewMode.cloze => '例句填空',
  ReviewMode.collocation => '固定搭配',
};

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
