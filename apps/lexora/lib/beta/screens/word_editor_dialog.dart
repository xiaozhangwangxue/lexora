import 'package:flutter/material.dart';

import '../controllers/beta_controller.dart';
import '../domain/answer_evaluator.dart';
import '../models/learning_models.dart';

Future<void> showWordEditorDialog(
  BuildContext context, {
  required BetaController controller,
  LearningWord? word,
  String? initialText,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => _WordEditorDialog(
    controller: controller,
    word: word,
    initialText: initialText,
  ),
);

class _WordEditorDialog extends StatefulWidget {
  const _WordEditorDialog({
    required this.controller,
    this.word,
    this.initialText,
  });

  final BetaController controller;
  final LearningWord? word;
  final String? initialText;

  @override
  State<_WordEditorDialog> createState() => _WordEditorDialogState();
}

class _WordEditorDialogState extends State<_WordEditorDialog> {
  late final TextEditingController _text;
  late final TextEditingController _uk;
  late final TextEditingController _us;
  late final TextEditingController _audioUk;
  late final TextEditingController _audioUs;
  late final TextEditingController _note;
  late final TextEditingController _customTags;
  late final List<_MeaningDraft> _meanings;
  late final List<_CollocationDraft> _collocations;
  late final List<_SourceDraft> _sources;
  late final Set<SkillTag> _tags;
  late bool _important;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final word = widget.word;
    _text = TextEditingController(text: word?.text ?? widget.initialText ?? '');
    _uk = TextEditingController(text: word?.phoneticUK ?? '');
    _us = TextEditingController(text: word?.phoneticUS ?? '');
    _audioUk = TextEditingController(text: word?.audioUK ?? '');
    _audioUs = TextEditingController(text: word?.audioUS ?? '');
    _note = TextEditingController(text: word?.note ?? '');
    _customTags = TextEditingController(text: word?.customTags.join('，') ?? '');
    _meanings = word == null || word.meanings.isEmpty
        ? [_MeaningDraft.empty()]
        : word.meanings.map(_MeaningDraft.fromMeaning).toList();
    _collocations =
        word?.collocations.map(_CollocationDraft.fromCollocation).toList() ??
        [];
    _sources = word?.sources.map(_SourceDraft.fromSource).toList() ?? [];
    _tags = {...?word?.tags};
    _important = word?.isImportant ?? false;
  }

  @override
  void dispose() {
    for (final controller in [
      _text,
      _uk,
      _us,
      _audioUk,
      _audioUs,
      _note,
      _customTags,
    ]) {
      controller.dispose();
    }
    for (final value in _meanings) {
      value.dispose();
    }
    for (final value in _collocations) {
      value.dispose();
    }
    for (final value in _sources) {
      value.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _close() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (confirmContext) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('关闭后，本次编辑的内容不会保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmContext).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(confirmContext).pop(true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入单词')));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final id = widget.word?.id ?? 'word-manual-${now.microsecondsSinceEpoch}';
    try {
      final word = LearningWord(
        id: id,
        text: text,
        normalizedText: normalizeAnswer(text),
        phoneticUK: _nullable(_uk.text),
        phoneticUS: _nullable(_us.text),
        audioUK: _nullable(_audioUk.text),
        audioUS: _nullable(_audioUs.text),
        meanings: [
          for (var index = 0; index < _meanings.length; index++)
            _meanings[index].build(
              '$id-meaning-$index',
              text,
              now,
              _sources.map((value) => value.id).toSet(),
            ),
        ],
        collocations: [
          for (var index = 0; index < _collocations.length; index++)
            _collocations[index].build(
              '$id-collocation-$index',
              now,
              _sources.map((value) => value.id).toSet(),
            ),
        ],
        sources: [
          for (var index = 0; index < _sources.length; index++)
            _sources[index].build('$id-source-$index', now),
        ],
        tags: _tags.toList(),
        customTags: _splitAnswers(_customTags.text),
        note: _nullable(_note.text),
        isImportant: _important,
        createdAt: widget.word?.createdAt ?? now,
        updatedAt: now,
      );
      await widget.controller.saveWord(word);
      if (mounted) Navigator.of(context).pop();
    } on DuplicateLearningWordException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该单词已存在，请编辑已有单词')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: AlertDialog(
      title: Text(widget.word == null ? '创建学习词条' : '编辑 ${widget.word!.text}'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 860,
          maxHeight: MediaQuery.sizeOf(context).height * .76,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(
                title: '基本信息',
                child: Column(
                  children: [
                    TextField(
                      controller: _text,
                      onChanged: (_) => _changed(),
                      decoration: const InputDecoration(labelText: '单词或短语 *'),
                    ),
                    const SizedBox(height: 10),
                    _ResponsiveFields(
                      children: [
                        TextField(
                          controller: _us,
                          onChanged: (_) => _changed(),
                          decoration: const InputDecoration(labelText: '美式音标'),
                        ),
                        TextField(
                          controller: _uk,
                          onChanged: (_) => _changed(),
                          decoration: const InputDecoration(labelText: '英式音标'),
                        ),
                        TextField(
                          controller: _audioUs,
                          onChanged: (_) => _changed(),
                          decoration: const InputDecoration(
                            labelText: '美式音频地址',
                          ),
                        ),
                        TextField(
                          controller: _audioUk,
                          onChanged: (_) => _changed(),
                          decoration: const InputDecoration(
                            labelText: '英式音频地址',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _note,
                      onChanged: (_) => _changed(),
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '笔记'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('重点单词'),
                      value: _important,
                      onChanged: (value) => setState(() {
                        _important = value;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: '释义与例句',
                action: TextButton.icon(
                  onPressed: () => setState(() {
                    _meanings.add(_MeaningDraft.empty());
                    _dirty = true;
                  }),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加释义'),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < _meanings.length; index++)
                      _ReorderableCard(
                        title: '释义 ${index + 1}',
                        canDelete: _meanings.length > 1,
                        onUp: index == 0
                            ? null
                            : () => _move(_meanings, index, index - 1),
                        onDown: index == _meanings.length - 1
                            ? null
                            : () => _move(_meanings, index, index + 1),
                        onDelete: () => setState(() {
                          _meanings.removeAt(index).dispose();
                          _dirty = true;
                        }),
                        child: _MeaningEditor(
                          draft: _meanings[index],
                          targetWord: _text,
                          sources: _sources,
                          onChanged: _changed,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: '固定搭配',
                action: TextButton.icon(
                  onPressed: () => setState(() {
                    _collocations.add(_CollocationDraft.empty());
                    _dirty = true;
                  }),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加搭配'),
                ),
                child: _collocations.isEmpty
                    ? const Text('暂无固定搭配。添加后可进入“固定搭配填空”模式。')
                    : Column(
                        children: [
                          for (
                            var index = 0;
                            index < _collocations.length;
                            index++
                          )
                            _ReorderableCard(
                              title: '搭配 ${index + 1}',
                              onUp: index == 0
                                  ? null
                                  : () =>
                                        _move(_collocations, index, index - 1),
                              onDown: index == _collocations.length - 1
                                  ? null
                                  : () =>
                                        _move(_collocations, index, index + 1),
                              onDelete: () => setState(() {
                                _collocations.removeAt(index).dispose();
                                _dirty = true;
                              }),
                              child: _CollocationEditor(
                                draft: _collocations[index],
                                sources: _sources,
                                onChanged: _changed,
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: '来源',
                action: TextButton.icon(
                  onPressed: () => setState(() {
                    _sources.add(_SourceDraft.empty());
                    _dirty = true;
                  }),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加来源'),
                ),
                child: _sources.isEmpty
                    ? const Text('可记录四级真题、教材或手动收集的真实语境。')
                    : Column(
                        children: [
                          for (var index = 0; index < _sources.length; index++)
                            _ReorderableCard(
                              title: '来源 ${index + 1}',
                              onUp: index == 0
                                  ? null
                                  : () => _move(_sources, index, index - 1),
                              onDown: index == _sources.length - 1
                                  ? null
                                  : () => _move(_sources, index, index + 1),
                              onDelete: () => setState(() {
                                final removedId = _sources[index].id;
                                _sources.removeAt(index).dispose();
                                for (final meaning in _meanings) {
                                  for (final example in meaning.examples) {
                                    if (example.sourceId == removedId) {
                                      example.sourceId = null;
                                    }
                                  }
                                }
                                for (final collocation in _collocations) {
                                  if (collocation.sourceId == removedId) {
                                    collocation.sourceId = null;
                                  }
                                }
                                _dirty = true;
                              }),
                              child: _SourceEditor(
                                draft: _sources[index],
                                onChanged: _changed,
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: '四级分类与标签',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final tag in SkillTag.values)
                          FilterChip(
                            label: Text(_tagLabel(tag)),
                            selected: _tags.contains(tag),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _tags.add(tag);
                              } else {
                                _tags.remove(tag);
                              }
                              _dirty = true;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customTags,
                      onChanged: (_) => _changed(),
                      decoration: const InputDecoration(
                        labelText: '自定义标签',
                        hintText: '用逗号分隔多个标签',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : _close, child: const Text('取消')),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: const Text('保存'),
        ),
      ],
    ),
  );

  void _move<T>(List<T> list, int from, int to) {
    setState(() {
      final value = list.removeAt(from);
      list.insert(to, value);
      _dirty = true;
    });
  }
}

class _MeaningEditor extends StatefulWidget {
  const _MeaningEditor({
    required this.draft,
    required this.targetWord,
    required this.sources,
    required this.onChanged,
  });

  final _MeaningDraft draft;
  final TextEditingController targetWord;
  final List<_SourceDraft> sources;
  final VoidCallback onChanged;

  @override
  State<_MeaningEditor> createState() => _MeaningEditorState();
}

class _MeaningEditorState extends State<_MeaningEditor> {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ResponsiveFields(
        children: [
          TextField(
            controller: widget.draft.partOfSpeech,
            onChanged: (_) => widget.onChanged(),
            decoration: const InputDecoration(labelText: '词性'),
          ),
          TextField(
            controller: widget.draft.definitionZh,
            onChanged: (_) => widget.onChanged(),
            decoration: const InputDecoration(labelText: '中文释义'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: widget.draft.definitionEn,
        onChanged: (_) => widget.onChanged(),
        decoration: const InputDecoration(labelText: '英文释义'),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: widget.draft.acceptedAnswers,
        onChanged: (_) => widget.onChanged(),
        decoration: const InputDecoration(
          labelText: '可接受答案',
          hintText: '用逗号分隔',
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Text('例句', style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() {
              widget.draft.examples.add(_ExampleDraft.empty());
              widget.onChanged();
            }),
            icon: const Icon(Icons.add_rounded),
            label: const Text('添加例句'),
          ),
        ],
      ),
      for (var index = 0; index < widget.draft.examples.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('例句 ${index + 1}'),
                    const Spacer(),
                    IconButton(
                      tooltip: '删除例句',
                      onPressed: () => setState(() {
                        widget.draft.examples.removeAt(index).dispose();
                        widget.onChanged();
                      }),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                TextField(
                  controller: widget.draft.examples[index].sentence,
                  onChanged: (_) => widget.onChanged(),
                  decoration: const InputDecoration(labelText: '英文例句'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.draft.examples[index].translation,
                  onChanged: (_) => widget.onChanged(),
                  decoration: const InputDecoration(labelText: '中文翻译'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.draft.examples[index].cloze,
                  onChanged: (_) => widget.onChanged(),
                  decoration: InputDecoration(
                    labelText: '挖空句',
                    suffixIcon: IconButton(
                      tooltip: '根据目标单词生成挖空句',
                      onPressed: () {
                        widget.draft.examples[index].cloze.text =
                            createClozeSentence(
                              widget.draft.examples[index].sentence.text,
                              widget.targetWord.text,
                            );
                        widget.onChanged();
                      },
                      icon: const Icon(Icons.auto_fix_high_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  key: ValueKey(
                    'example-source-${widget.draft.examples[index].id}-'
                    '${widget.draft.examples[index].sourceId ?? 'none'}-'
                    '${widget.sources.map((value) => value.id).join(',')}',
                  ),
                  initialValue: widget.draft.examples[index].sourceId,
                  decoration: const InputDecoration(labelText: '关联来源'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('不关联'),
                    ),
                    for (final source in widget.sources)
                      DropdownMenuItem<String?>(
                        value: source.id,
                        child: Text(source.displayName),
                      ),
                  ],
                  onChanged: (value) {
                    widget.draft.examples[index].sourceId = value;
                    widget.onChanged();
                  },
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _CollocationEditor extends StatelessWidget {
  const _CollocationEditor({
    required this.draft,
    required this.sources,
    required this.onChanged,
  });

  final _CollocationDraft draft;
  final List<_SourceDraft> sources;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ResponsiveFields(
        children: [
          TextField(
            controller: draft.text,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: '固定搭配'),
          ),
          TextField(
            controller: draft.meaningZh,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: '中文含义'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: draft.acceptedAnswers,
        onChanged: (_) => onChanged(),
        decoration: const InputDecoration(
          labelText: '可接受答案',
          hintText: '例如 to，也可填写完整搭配',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: draft.exampleSentence,
        onChanged: (_) => onChanged(),
        decoration: const InputDecoration(labelText: '英文例句'),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: draft.exampleTranslation,
        onChanged: (_) => onChanged(),
        decoration: const InputDecoration(labelText: '例句翻译'),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String?>(
        key: ValueKey(
          'collocation-source-${draft.id}-${draft.sourceId ?? 'none'}-'
          '${sources.map((value) => value.id).join(',')}',
        ),
        initialValue: draft.sourceId,
        decoration: const InputDecoration(labelText: '关联来源'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('不关联')),
          for (final source in sources)
            DropdownMenuItem<String?>(
              value: source.id,
              child: Text(source.displayName),
            ),
        ],
        onChanged: (value) {
          draft.sourceId = value;
          onChanged();
        },
      ),
    ],
  );
}

class _SourceEditor extends StatefulWidget {
  const _SourceEditor({required this.draft, required this.onChanged});

  final _SourceDraft draft;
  final VoidCallback onChanged;

  @override
  State<_SourceEditor> createState() => _SourceEditorState();
}

class _SourceEditorState extends State<_SourceEditor> {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      DropdownButtonFormField<SourceType>(
        initialValue: widget.draft.type,
        decoration: const InputDecoration(labelText: '来源类型'),
        items: [
          for (final type in SourceType.values)
            DropdownMenuItem(value: type, child: Text(_sourceLabel(type))),
        ],
        onChanged: (value) => setState(() {
          widget.draft.type = value ?? SourceType.other;
          widget.onChanged();
        }),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: widget.draft.title,
        onChanged: (_) => widget.onChanged(),
        decoration: const InputDecoration(labelText: '标题'),
      ),
      const SizedBox(height: 8),
      _ResponsiveFields(
        children: [
          TextField(
            controller: widget.draft.year,
            onChanged: (_) => widget.onChanged(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '考试年份'),
          ),
          TextField(
            controller: widget.draft.month,
            onChanged: (_) => widget.onChanged(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '考试月份'),
          ),
          TextField(
            controller: widget.draft.paperCode,
            onChanged: (_) => widget.onChanged(),
            decoration: const InputDecoration(labelText: '试卷编号'),
          ),
          TextField(
            controller: widget.draft.section,
            onChanged: (_) => widget.onChanged(),
            decoration: const InputDecoration(labelText: 'Section'),
          ),
          TextField(
            controller: widget.draft.question,
            onChanged: (_) => widget.onChanged(),
            decoration: const InputDecoration(labelText: '题号'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: widget.draft.originalSentence,
        onChanged: (_) => widget.onChanged(),
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(labelText: '原始句子'),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: widget.draft.note,
        onChanged: (_) => widget.onChanged(),
        decoration: const InputDecoration(labelText: '来源备注'),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _ReorderableCard extends StatelessWidget {
  const _ReorderableCard({
    required this.title,
    required this.child,
    required this.onDelete,
    this.onUp,
    this.onDown,
    this.canDelete = true,
  });

  final String title;
  final Widget child;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onDelete;
  final bool canDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '上移',
                onPressed: onUp,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: '下移',
                onPressed: onDown,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: canDelete ? onDelete : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          child,
        ],
      ),
    ),
  );
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560) {
        return Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1) const SizedBox(height: 8),
            ],
          ],
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final child in children)
            SizedBox(width: (constraints.maxWidth - 8) / 2, child: child),
        ],
      );
    },
  );
}

class _MeaningDraft {
  _MeaningDraft({
    required this.partOfSpeech,
    required this.definitionZh,
    required this.definitionEn,
    required this.acceptedAnswers,
    required this.examples,
  });

  factory _MeaningDraft.empty() => _MeaningDraft(
    partOfSpeech: TextEditingController(),
    definitionZh: TextEditingController(),
    definitionEn: TextEditingController(),
    acceptedAnswers: TextEditingController(),
    examples: [],
  );

  factory _MeaningDraft.fromMeaning(WordMeaning value) => _MeaningDraft(
    partOfSpeech: TextEditingController(text: value.partOfSpeech),
    definitionZh: TextEditingController(text: value.definitionZh),
    definitionEn: TextEditingController(text: value.definitionEn ?? ''),
    acceptedAnswers: TextEditingController(
      text: value.acceptedAnswers.join('，'),
    ),
    examples: value.examples.map(_ExampleDraft.fromExample).toList(),
  );

  final TextEditingController partOfSpeech;
  final TextEditingController definitionZh;
  final TextEditingController definitionEn;
  final TextEditingController acceptedAnswers;
  final List<_ExampleDraft> examples;

  WordMeaning build(
    String id,
    String target,
    DateTime now,
    Set<String> validSourceIds,
  ) => WordMeaning(
    id: id,
    partOfSpeech: partOfSpeech.text.trim(),
    definitionZh: definitionZh.text.trim(),
    definitionEn: _nullable(definitionEn.text),
    acceptedAnswers: _splitAnswers(acceptedAnswers.text),
    examples: [
      for (var index = 0; index < examples.length; index++)
        examples[index].build(
          '$id-example-$index',
          target,
          now,
          validSourceIds,
        ),
    ],
  );

  void dispose() {
    partOfSpeech.dispose();
    definitionZh.dispose();
    definitionEn.dispose();
    acceptedAnswers.dispose();
    for (final value in examples) {
      value.dispose();
    }
  }
}

class _ExampleDraft {
  _ExampleDraft({
    required this.id,
    required this.sentence,
    required this.translation,
    required this.cloze,
    required this.sourceId,
    required this.createdAt,
  });
  factory _ExampleDraft.empty() => _ExampleDraft(
    id: _newDraftId('example'),
    sentence: TextEditingController(),
    translation: TextEditingController(),
    cloze: TextEditingController(),
    sourceId: null,
    createdAt: DateTime.now(),
  );
  factory _ExampleDraft.fromExample(WordExample value) => _ExampleDraft(
    id: value.id,
    sentence: TextEditingController(text: value.sentence),
    translation: TextEditingController(text: value.translation ?? ''),
    cloze: TextEditingController(text: value.clozeSentence ?? ''),
    sourceId: value.sourceId,
    createdAt: value.createdAt,
  );

  final String id;
  final TextEditingController sentence;
  final TextEditingController translation;
  final TextEditingController cloze;
  String? sourceId;
  final DateTime createdAt;

  WordExample build(
    String fallbackId,
    String target,
    DateTime now,
    Set<String> validSourceIds,
  ) => WordExample(
    id: id.isEmpty ? fallbackId : id,
    sentence: sentence.text.trim(),
    translation: _nullable(translation.text),
    clozeSentence:
        _nullable(cloze.text) ?? createClozeSentence(sentence.text, target),
    sourceId: validSourceIds.contains(sourceId) ? sourceId : null,
    createdAt: createdAt,
    updatedAt: now,
  );

  void dispose() {
    sentence.dispose();
    translation.dispose();
    cloze.dispose();
  }
}

class _CollocationDraft {
  _CollocationDraft({
    required this.id,
    required this.text,
    required this.meaningZh,
    required this.acceptedAnswers,
    required this.exampleSentence,
    required this.exampleTranslation,
    required this.sourceId,
    required this.createdAt,
  });
  factory _CollocationDraft.empty() => _CollocationDraft(
    id: _newDraftId('collocation'),
    text: TextEditingController(),
    meaningZh: TextEditingController(),
    acceptedAnswers: TextEditingController(),
    exampleSentence: TextEditingController(),
    exampleTranslation: TextEditingController(),
    sourceId: null,
    createdAt: DateTime.now(),
  );
  factory _CollocationDraft.fromCollocation(Collocation value) =>
      _CollocationDraft(
        id: value.id,
        text: TextEditingController(text: value.text),
        meaningZh: TextEditingController(text: value.meaningZh),
        acceptedAnswers: TextEditingController(
          text: value.acceptedAnswers.join('，'),
        ),
        exampleSentence: TextEditingController(
          text: value.exampleSentence ?? '',
        ),
        exampleTranslation: TextEditingController(
          text: value.exampleTranslation ?? '',
        ),
        sourceId: value.sourceId,
        createdAt: value.createdAt,
      );

  final String id;
  final TextEditingController text;
  final TextEditingController meaningZh;
  final TextEditingController acceptedAnswers;
  final TextEditingController exampleSentence;
  final TextEditingController exampleTranslation;
  String? sourceId;
  final DateTime createdAt;

  Collocation build(
    String fallbackId,
    DateTime now,
    Set<String> validSourceIds,
  ) => Collocation(
    id: id.isEmpty ? fallbackId : id,
    text: text.text.trim(),
    meaningZh: meaningZh.text.trim(),
    acceptedAnswers: _splitAnswers(acceptedAnswers.text),
    exampleSentence: _nullable(exampleSentence.text),
    exampleTranslation: _nullable(exampleTranslation.text),
    sourceId: validSourceIds.contains(sourceId) ? sourceId : null,
    createdAt: createdAt,
    updatedAt: now,
  );
  void dispose() {
    text.dispose();
    meaningZh.dispose();
    acceptedAnswers.dispose();
    exampleSentence.dispose();
    exampleTranslation.dispose();
  }
}

class _SourceDraft {
  _SourceDraft({
    required this.id,
    required this.type,
    required this.title,
    required this.year,
    required this.month,
    required this.paperCode,
    required this.section,
    required this.question,
    required this.originalSentence,
    required this.note,
    required this.createdAt,
  });
  factory _SourceDraft.empty() => _SourceDraft(
    id: _newDraftId('source'),
    type: SourceType.manual,
    title: TextEditingController(),
    year: TextEditingController(),
    month: TextEditingController(),
    paperCode: TextEditingController(),
    section: TextEditingController(),
    question: TextEditingController(),
    originalSentence: TextEditingController(),
    note: TextEditingController(),
    createdAt: DateTime.now(),
  );
  factory _SourceDraft.fromSource(WordSource value) => _SourceDraft(
    id: value.id,
    type: value.sourceType,
    title: TextEditingController(text: value.title),
    year: TextEditingController(text: value.examYear?.toString() ?? ''),
    month: TextEditingController(text: value.examMonth?.toString() ?? ''),
    paperCode: TextEditingController(text: value.paperCode ?? ''),
    section: TextEditingController(text: value.section ?? ''),
    question: TextEditingController(text: value.questionNumber ?? ''),
    originalSentence: TextEditingController(text: value.originalSentence ?? ''),
    note: TextEditingController(text: value.note ?? ''),
    createdAt: value.createdAt,
  );

  final String id;
  SourceType type;
  final TextEditingController title;
  final TextEditingController year;
  final TextEditingController month;
  final TextEditingController paperCode;
  final TextEditingController section;
  final TextEditingController question;
  final TextEditingController originalSentence;
  final TextEditingController note;
  final DateTime createdAt;

  String get displayName =>
      title.text.trim().isNotEmpty ? title.text.trim() : _sourceLabel(type);

  WordSource build(String fallbackId, DateTime now) => WordSource(
    id: id.isEmpty ? fallbackId : id,
    sourceType: type,
    title: title.text.trim(),
    examYear: int.tryParse(year.text),
    examMonth: int.tryParse(month.text),
    paperCode: _nullable(paperCode.text),
    section: _nullable(section.text),
    questionNumber: _nullable(question.text),
    originalSentence: _nullable(originalSentence.text),
    note: _nullable(note.text),
    createdAt: createdAt,
    updatedAt: now,
  );
  void dispose() {
    title.dispose();
    year.dispose();
    month.dispose();
    paperCode.dispose();
    section.dispose();
    question.dispose();
    originalSentence.dispose();
    note.dispose();
  }
}

String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

List<String> _splitAnswers(String value) => value
    .split(RegExp('[,，;；]'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toSet()
    .toList();

int _draftSequence = 0;

String _newDraftId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_draftSequence++}';

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

String _sourceLabel(SourceType type) => switch (type) {
  SourceType.cet4Listening => '四级听力',
  SourceType.cet4Reading => '四级阅读',
  SourceType.cet4Writing => '四级写作',
  SourceType.cet4Translation => '四级翻译',
  SourceType.textbook => '教材',
  SourceType.manual => '手动添加',
  SourceType.other => '其他',
};
