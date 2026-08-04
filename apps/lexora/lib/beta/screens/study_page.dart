import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/beta_controller.dart';
import '../domain/answer_evaluator.dart';
import '../domain/review_scheduler.dart';
import '../domain/study_queue.dart';
import '../models/learning_models.dart';
import '../services/beta_speech_service.dart';
import '../widgets/beta_ui.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key, required this.controller});

  final BetaController controller;

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();
  String? _itemId;
  bool _usedHint = false;
  AnswerEvaluation? _evaluation;
  DateTime _startedAt = DateTime.now();
  bool _speaking = false;

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocus.dispose();
    unawaited(BetaSpeechService.instance.stop());
    super.dispose();
  }

  void _syncItem(String itemId) {
    if (_itemId == itemId) return;
    _itemId = itemId;
    _answerController.clear();
    _usedHint = false;
    _evaluation = null;
    _startedAt = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final session = controller.activeSession;
    if (session == null || session.currentIndex >= session.items.length) {
      return _CompletedState(controller: controller);
    }
    final item = session.items[session.currentIndex];
    final word = controller.wordForId(item.wordId);
    if (word == null) {
      return const Center(child: Text('当前学习项对应的单词不存在，已安全跳过。'));
    }
    _syncItem(item.id);
    final reviewState = controller.data.reviewStates[word.id]!;
    final prompt = _buildPrompt(word, item.reviewMode);
    final revealed = item.state == SessionItemState.revealed;
    final previews = previewSchedules(
      reviewState,
      item.reviewMode,
      DateTime.now(),
    );
    final completed = session.items
        .where((value) => value.state == SessionItemState.completed)
        .length;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (!_answerFocus.hasFocus && !revealed) {
            unawaited(_reveal(session, item, word));
          }
        },
        const SingleActivator(LogicalKeyboardKey.digit1): () {
          if (!_answerFocus.hasFocus && revealed) {
            unawaited(_rate(session, item, ReviewRating.again));
          }
        },
        const SingleActivator(LogicalKeyboardKey.digit2): () {
          if (!_answerFocus.hasFocus && revealed) {
            unawaited(_rate(session, item, ReviewRating.hard));
          }
        },
        const SingleActivator(LogicalKeyboardKey.digit3): () {
          if (!_answerFocus.hasFocus && revealed) {
            unawaited(_rate(session, item, ReviewRating.good));
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyP): () {
          if (!_answerFocus.hasFocus) unawaited(_speak(word.text));
        },
        const SingleActivator(LogicalKeyboardKey.keyS): () {
          if (!_answerFocus.hasFocus) {
            unawaited(controller.toggleImportant(word.id));
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              sliver: SliverList.list(
                children: [
                  BetaSectionTitle(
                    '今日学习',
                    subtitle:
                        '已完成 $completed / ${session.items.length} · 稍后复习 ${laterDueCount(controller.data.reviewStates, DateTime.now())}',
                    trailing: IconButton(
                      tooltip: word.isImportant ? '取消重点' : '标记重点',
                      onPressed: () => controller.toggleImportant(word.id),
                      icon: Icon(
                        word.isImportant
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: word.isImportant ? Colors.amber.shade700 : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: session.items.isEmpty
                        ? 0
                        : completed / session.items.length,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: BetaSurface(
                        padding: const EdgeInsets.all(24),
                        child: AnimatedSize(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: const Cubic(.2, .8, .2, 1),
                          alignment: Alignment.topCenter,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  _ModeChip(mode: item.reviewMode),
                                  const Spacer(),
                                  Text(
                                    '${session.currentIndex + 1} / ${session.items.length}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              Text(
                                prompt.question,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                    ),
                              ),
                              if (prompt.subtitle != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  prompt.subtitle!,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              if (item.reviewMode == ReviewMode.spelling)
                                Align(
                                  child: OutlinedButton.icon(
                                    onPressed: _speaking
                                        ? null
                                        : () => _speak(word.text),
                                    icon: Icon(
                                      _speaking
                                          ? Icons.graphic_eq_rounded
                                          : Icons.volume_up_rounded,
                                    ),
                                    label: Text(_speaking ? '正在播放' : '播放发音'),
                                  ),
                                ),
                              if (prompt.requiresInput && !revealed) ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _answerController,
                                  focusNode: _answerFocus,
                                  textInputAction: TextInputAction.done,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    labelText: '你的答案',
                                    hintText: '先回忆，再提交答案',
                                  ),
                                  onSubmitted: (_) =>
                                      _submitAnswer(session, item, prompt),
                                ),
                                if (item.reviewMode == ReviewMode.spelling)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        setState(() => _usedHint = true);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '首字母 ${word.text.characters.firstOrNull ?? ''} · 共 ${word.text.characters.length} 个字符',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.lightbulb_outline_rounded,
                                      ),
                                      label: const Text('首字母与长度提示'),
                                    ),
                                  ),
                              ],
                              if (!revealed) ...[
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: controller.saving
                                      ? null
                                      : prompt.requiresInput
                                      ? () =>
                                            _submitAnswer(session, item, prompt)
                                      : () => _reveal(session, item, word),
                                  icon: Icon(
                                    prompt.requiresInput
                                        ? Icons.check_rounded
                                        : Icons.visibility_rounded,
                                  ),
                                  label: Text(
                                    prompt.requiresInput ? '提交答案' : '显示答案',
                                  ),
                                ),
                                TextButton(
                                  onPressed: controller.saving
                                      ? null
                                      : () => _reveal(session, item, word),
                                  child: const Text('想不起来，直接显示答案'),
                                ),
                              ],
                              if (revealed) ...[
                                _AnswerContent(
                                  word: word,
                                  prompt: prompt,
                                  userAnswer: _answerController.text,
                                  evaluation: _evaluation,
                                  onSpeakUS: () => _speak(
                                    word.text,
                                    accent: PreferredAccent.us,
                                  ),
                                  onSpeakUK: () => _speak(
                                    word.text,
                                    accent: PreferredAccent.uk,
                                  ),
                                  onSpeakExample: (text) => _speak(text),
                                ),
                                const SizedBox(height: 20),
                                const Divider(),
                                const SizedBox(height: 12),
                                Text(
                                  '根据真实回忆情况评分',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                _RatingButtons(
                                  disabled: controller.saving,
                                  showIntervals: controller
                                      .data
                                      .settings
                                      .showNextReviewTime,
                                  previews: previews,
                                  onRating: (rating) =>
                                      _rate(session, item, rating),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'Space 显示答案 · 1/2/3 评分 · P 发音 · S 重点',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAnswer(
    StudySession session,
    StudySessionItem item,
    _Prompt prompt,
  ) async {
    if (item.state == SessionItemState.revealed) return;
    final evaluation = evaluateAnswer(
      input: _answerController.text,
      expected: prompt.expectedAnswer,
      acceptedAnswers: prompt.acceptedAnswers,
      usedHint: _usedHint,
    );
    setState(() => _evaluation = evaluation);
    final word = widget.controller.wordForId(item.wordId);
    if (word != null) await _reveal(session, item, word);
  }

  Future<void> _reveal(
    StudySession session,
    StudySessionItem item,
    LearningWord word,
  ) async {
    if (item.state == SessionItemState.revealed) return;
    await widget.controller.revealCurrentItem(session.id);
    if (!mounted) return;
    final settings = widget.controller.data.settings;
    final texts = <String>[
      if (settings.autoPlayWordAudio) word.text,
      if (settings.autoPlayExampleAudio)
        ...word.meanings
            .expand((meaning) => meaning.examples)
            .map((example) => example.sentence)
            .where((text) => text.trim().isNotEmpty)
            .take(1),
    ];
    if (texts.isNotEmpty) unawaited(_speakSequence(texts));
  }

  Future<void> _rate(
    StudySession session,
    StudySessionItem item,
    ReviewRating rating,
  ) async {
    if (widget.controller.saving || item.state != SessionItemState.revealed) {
      return;
    }
    try {
      await widget.controller.submitReview(
        sessionId: session.id,
        itemId: item.id,
        rating: rating,
        reviewMode: item.reviewMode,
        answerCorrect: _evaluation?.correct,
        userAnswer: _answerController.text.trim().isEmpty
            ? null
            : _answerController.text,
        usedHint: _usedHint,
        responseTimeMs: DateTime.now().difference(_startedAt).inMilliseconds,
        submissionId: '${session.id}:${item.id}',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('评分未保存：$error，请重试。')));
      }
    }
  }

  Future<void> _speak(String text, {PreferredAccent? accent}) async {
    await _speakSequence([text], accent: accent);
  }

  Future<void> _speakSequence(
    Iterable<String> texts, {
    PreferredAccent? accent,
  }) async {
    if (_speaking) return;
    setState(() => _speaking = true);
    try {
      final settings = widget.controller.data.settings;
      for (final text in texts) {
        await BetaSpeechService.instance.speak(
          text,
          accent: accent ?? settings.preferredAccent,
          rate: settings.speechRate,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发音失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }
}

class _Prompt {
  const _Prompt({
    required this.question,
    required this.expectedAnswer,
    this.subtitle,
    this.acceptedAnswers = const [],
    this.requiresInput = false,
  });

  final String question;
  final String? subtitle;
  final String expectedAnswer;
  final List<String> acceptedAnswers;
  final bool requiresInput;
}

String _answerDifference(String input, String expected) {
  final actual = normalizeAnswer(input);
  final target = normalizeAnswer(expected);
  if (actual == target) return '答案差异：无';
  var index = 0;
  final limit = actual.length < target.length ? actual.length : target.length;
  while (index < limit &&
      actual.codeUnitAt(index) == target.codeUnitAt(index)) {
    index += 1;
  }
  if (actual.isEmpty) return '答案差异：未输入答案';
  return '答案差异：从第 ${index + 1} 个字符开始不同（$actual → $target）';
}

_Prompt _buildPrompt(LearningWord word, ReviewMode mode) {
  final meaning = word.meanings.firstOrNull;
  switch (mode) {
    case ReviewMode.wordToMeaning:
      return _Prompt(
        question: word.text,
        subtitle: [
          word.phoneticUS,
          word.phoneticUK,
        ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
        expectedAnswer: meaning?.definitionZh ?? '',
      );
    case ReviewMode.meaningToWord:
      return _Prompt(
        question: meaning?.definitionZh.isNotEmpty == true
            ? meaning!.definitionZh
            : '回忆对应英文单词',
        expectedAnswer: word.text,
        acceptedAnswers: meaning?.acceptedAnswers ?? const [],
        requiresInput: true,
      );
    case ReviewMode.spelling:
      return _Prompt(
        question: '听发音，拼写完整单词',
        subtitle: '共 ${word.text.characters.length} 个字符',
        expectedAnswer: word.text,
        acceptedAnswers: meaning?.acceptedAnswers ?? const [],
        requiresInput: true,
      );
    case ReviewMode.cloze:
      final example = word.meanings
          .expand((value) => value.examples)
          .where((value) => value.clozeSentence?.contains('______') == true)
          .firstOrNull;
      return _Prompt(
        question: example?.clozeSentence ?? '请填写：______',
        subtitle: example?.translation,
        expectedAnswer: word.text,
        acceptedAnswers: meaning?.acceptedAnswers ?? const [],
        requiresInput: true,
      );
    case ReviewMode.collocation:
      final collocation = word.collocations.firstOrNull;
      if (collocation == null) {
        return _Prompt(
          question: word.text,
          subtitle: [
            word.phoneticUS,
            word.phoneticUK,
          ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
          expectedAnswer: meaning?.definitionZh ?? '',
        );
      }
      final answers = collocation.acceptedAnswers.isEmpty
          ? [collocation.text]
          : collocation.acceptedAnswers;
      final expected = [...answers]
        ..sort((a, b) => a.length.compareTo(b.length));
      final answer = expected.first;
      final question = answer == collocation.text
          ? '${collocation.meaningZh}\n______'
          : collocation.text.replaceFirst(
              RegExp('(?<![A-Za-z])${RegExp.escape(answer)}(?![A-Za-z])'),
              '___',
            );
      return _Prompt(
        question: question,
        subtitle: collocation.meaningZh,
        expectedAnswer: answer,
        acceptedAnswers: answers,
        requiresInput: true,
      );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode});

  final ReviewMode mode;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.psychology_alt_rounded, size: 18),
    label: Text(_modeLabel(mode)),
  );
}

class _AnswerContent extends StatelessWidget {
  const _AnswerContent({
    required this.word,
    required this.prompt,
    required this.userAnswer,
    required this.evaluation,
    required this.onSpeakUS,
    required this.onSpeakUK,
    required this.onSpeakExample,
  });

  final LearningWord word;
  final _Prompt prompt;
  final String userAnswer;
  final AnswerEvaluation? evaluation;
  final VoidCallback onSpeakUS;
  final VoidCallback onSpeakUK;
  final ValueChanged<String> onSpeakExample;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 20),
      AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 160),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.text,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    [
                      if (word.phoneticUS?.isNotEmpty == true)
                        '美 ${word.phoneticUS}',
                      if (word.phoneticUK?.isNotEmpty == true)
                        '英 ${word.phoneticUK}',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onSpeakUS,
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  label: const Text('美式'),
                ),
                TextButton.icon(
                  onPressed: onSpeakUK,
                  icon: const Icon(Icons.volume_up_outlined, size: 18),
                  label: const Text('英式'),
                ),
              ],
            ),
          ],
        ),
      ),
      if (prompt.requiresInput) ...[
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (evaluation?.correct == true ? Colors.green : Colors.orange)
                .withValues(alpha: .09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '你的答案：${userAnswer.trim().isEmpty ? '（未作答）' : userAnswer}\n'
            '正确答案：${prompt.expectedAnswer}'
            '${evaluation == null ? '' : '\n${_answerDifference(userAnswer, prompt.expectedAnswer)}\n建议评分：${_ratingLabel(evaluation!.suggestedRating)}'}',
          ),
        ),
      ],
      const SizedBox(height: 18),
      for (final meaning in word.meanings) ...[
        Text(
          [
            meaning.partOfSpeech,
            meaning.definitionZh,
          ].where((value) => value.trim().isNotEmpty).join('  '),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (meaning.definitionEn?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(meaning.definitionEn!),
          ),
        for (final example in meaning.examples) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(example.sentence),
                    if (example.translation?.isNotEmpty == true)
                      Text(
                        example.translation!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '朗读例句',
                onPressed: () => onSpeakExample(example.sentence),
                icon: const Icon(Icons.volume_up_outlined, size: 20),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
      ],
      if (word.collocations.isNotEmpty) ...[
        const Divider(),
        Text('固定搭配', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final collocation in word.collocations)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text('${collocation.text}  ${collocation.meaningZh}'),
          ),
      ],
      if (word.sources.isNotEmpty) ...[
        const Divider(),
        Text('来源：${word.sources.map((value) => value.title).join(' · ')}'),
      ],
      if (word.tags.isNotEmpty || word.customTags.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final tag in word.tags) Chip(label: Text(_tagLabel(tag))),
            for (final tag in word.customTags) Chip(label: Text(tag)),
          ],
        ),
      ],
      if (word.note?.isNotEmpty == true) Text('笔记：${word.note}'),
    ],
  );
}

class _RatingButtons extends StatelessWidget {
  const _RatingButtons({
    required this.disabled,
    required this.showIntervals,
    required this.previews,
    required this.onRating,
  });

  final bool disabled;
  final bool showIntervals;
  final Map<ReviewRating, ReviewState> previews;
  final ValueChanged<ReviewRating> onRating;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 520;
      final buttons = [
        _RatingButton(
          rating: ReviewRating.again,
          interval: showIntervals
              ? previews[ReviewRating.again]!.intervalMinutes
              : null,
          disabled: disabled,
          onTap: onRating,
        ),
        _RatingButton(
          rating: ReviewRating.hard,
          interval: showIntervals
              ? previews[ReviewRating.hard]!.intervalMinutes
              : null,
          disabled: disabled,
          onTap: onRating,
        ),
        _RatingButton(
          rating: ReviewRating.good,
          interval: showIntervals
              ? previews[ReviewRating.good]!.intervalMinutes
              : null,
          disabled: disabled,
          onTap: onRating,
        ),
      ];
      return compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final button in buttons) ...[
                  button,
                  if (button != buttons.last) const SizedBox(height: 8),
                ],
              ],
            )
          : Row(
              children: [
                for (var index = 0; index < buttons.length; index++) ...[
                  Expanded(child: buttons[index]),
                  if (index != buttons.length - 1) const SizedBox(width: 8),
                ],
              ],
            );
    },
  );
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.rating,
    required this.interval,
    required this.disabled,
    required this.onTap,
  });

  final ReviewRating rating;
  final int? interval;
  final bool disabled;
  final ValueChanged<ReviewRating> onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: disabled ? null : () => onTap(rating),
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
    child: Column(
      children: [
        Text(
          _ratingLabel(rating),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (interval != null)
          Text(
            _intervalLabel(interval!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    ),
  );
}

class _CompletedState extends StatelessWidget {
  const _CompletedState({required this.controller});

  final BetaController controller;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final later =
        controller.data.reviewStates.values
            .where(
              (state) =>
                  state.status != LearningStatus.newWord &&
                  state.dueAt.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BetaSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.task_alt_rounded, size: 54),
                const SizedBox(height: 14),
                Text(
                  '当前任务已完成',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  later.isEmpty
                      ? '今天暂时没有更多到期任务。'
                      : '今天稍后还有 ${later.length} 个单词需要复习\n最近一次：${TimeOfDay.fromDateTime(later.first.dueAt).format(context)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => controller.startStudy(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新检查到期任务'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _modeLabel(ReviewMode mode) => switch (mode) {
  ReviewMode.wordToMeaning => '英译中',
  ReviewMode.meaningToWord => '中译英',
  ReviewMode.spelling => '拼写测试',
  ReviewMode.cloze => '例句填空',
  ReviewMode.collocation => '固定搭配填空',
};

String _ratingLabel(ReviewRating rating) => switch (rating) {
  ReviewRating.again => '不认识',
  ReviewRating.hard => '模糊',
  ReviewRating.good => '认识',
};

String _intervalLabel(int minutes) {
  if (minutes < 60) return '$minutes 分钟';
  if (minutes < 24 * 60) return '${(minutes / 60).round()} 小时';
  return '${(minutes / (24 * 60)).round()} 天';
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
