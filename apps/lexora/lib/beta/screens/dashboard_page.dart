import 'package:flutter/material.dart';

import '../controllers/beta_controller.dart';
import '../domain/learning_stats.dart';
import '../domain/study_queue.dart';
import '../models/learning_models.dart';
import '../widgets/beta_ui.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.controller,
    required this.onOpenStudy,
  });

  final BetaController controller;
  final VoidCallback onOpenStudy;

  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    final now = DateTime.now();
    final today = calculateTodayStats(data.reviewLogs, now);
    final queue = buildStudyQueue(
      words: data.words,
      reviewStates: data.reviewStates,
      settings: data.settings,
      now: now,
      mode: data.settings.defaultStudyMode,
      session: controller.activeSessionFor(SessionFocus.newWords),
      focus: SessionFocus.newWords,
    );
    final dueCount = data.reviewStates.values
        .where(
          (state) =>
              state.status != LearningStatus.newWord &&
              !state.dueAt.isAfter(now),
        )
        .length;
    final newCount = queue.where((item) {
      return data.reviewStates[item.wordId]?.status == LearningStatus.newWord;
    }).length;
    final mastered = data.reviewStates.values
        .where((state) => state.status == LearningStatus.mastered)
        .length;
    final started = data.reviewStates.values
        .where((state) => state.status != LearningStatus.newWord)
        .length;
    final mastery = started == 0 ? 0.0 : mastered / started;
    final streak = calculateStreak(data.dailySummaries, now);
    final logsByWord = groupReviewLogsByWord(data.reviewLogs);
    final weakIds = data.words
        .where((word) {
          final state = data.reviewStates[word.id];
          if (state == null) return false;
          return isWeakWord(state, logsByWord[word.id] ?? const <ReviewLog>[]);
        })
        .map((word) => word.id)
        .toSet();
    final active = controller.activeSessionFor(SessionFocus.newWords);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          sliver: SliverList.list(
            children: [
              const BetaSectionTitle(
                '今天',
                subtitle: '先主动回忆，再查看答案；每次评分都会决定下一次复习时间。',
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 920
                      ? 4
                      : constraints.maxWidth >= 540
                      ? 2
                      : 1;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  final metrics = [
                    BetaMetric(
                      label: '当前到期复习',
                      value: '$dueCount',
                      icon: Icons.schedule_rounded,
                    ),
                    BetaMetric(
                      label: '今日新词',
                      value: '$newCount',
                      icon: Icons.fiber_new_rounded,
                    ),
                    BetaMetric(
                      label: '今日已完成',
                      value: '${today.uniqueWordCount}',
                      icon: Icons.task_alt_rounded,
                    ),
                    BetaMetric(
                      label: '今日复习次数',
                      value: '${today.reviewCount}',
                      icon: Icons.replay_rounded,
                    ),
                  ];
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final metric in metrics)
                        SizedBox(width: width, child: metric),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              BetaSurface(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active == null ? '开始今日学习' : '继续今日学习',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          controller.pendingEnrichmentCount > 0 && queue.isEmpty
                              ? '正在联网补全 ${controller.pendingEnrichmentCount} 个词条，释义就绪后才会开始复习。'
                              : active == null
                              ? queue.isEmpty
                                    ? '今天的到期任务已经完成。'
                                    : '已准备 ${queue.length} 张主动回忆卡片。'
                              : '已完成 ${active.items.where((item) => item.state == SessionItemState.completed).length} / ${active.items.length} 张卡片。',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    );
                    final button = FilledButton.icon(
                      onPressed: queue.isEmpty && active == null
                          ? null
                          : () async {
                              await controller.startStudy(
                                focus: SessionFocus.newWords,
                              );
                              onOpenStudy();
                            },
                      icon: Icon(
                        active == null
                            ? Icons.play_arrow_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(active == null ? '开始今日学习' : '继续学习'),
                    );
                    return compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              copy,
                              const SizedBox(height: 18),
                              button,
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: copy),
                              const SizedBox(width: 24),
                              button,
                            ],
                          );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const BetaSectionTitle('学习概览'),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 560
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: BetaMetric(
                          label: '连续学习',
                          value: '$streak 天',
                          icon: Icons.local_fire_department_rounded,
                          accent: Colors.orange,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: BetaMetric(
                          label: '总体掌握率',
                          value: '${(mastery * 100).round()}%',
                          icon: Icons.workspace_premium_rounded,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const BetaSectionTitle('专项学习', subtitle: '专项学习仍使用同一份复习状态和学习记录。'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Specialty(
                    label: '听力',
                    icon: Icons.headphones_rounded,
                    count: _tagCount(data.words, SkillTag.listening),
                    onTap: () => _startSpecial(
                      controller,
                      data.words
                          .where(
                            (word) => word.tags.contains(SkillTag.listening),
                          )
                          .map((word) => word.id)
                          .toSet(),
                      onOpenStudy,
                    ),
                  ),
                  _Specialty(
                    label: '阅读',
                    icon: Icons.chrome_reader_mode_rounded,
                    count: _tagCount(data.words, SkillTag.reading),
                    onTap: () => _startSpecial(
                      controller,
                      data.words
                          .where((word) => word.tags.contains(SkillTag.reading))
                          .map((word) => word.id)
                          .toSet(),
                      onOpenStudy,
                    ),
                  ),
                  _Specialty(
                    label: '写作',
                    icon: Icons.edit_note_rounded,
                    count: _tagCount(data.words, SkillTag.writing),
                    onTap: () => _startSpecial(
                      controller,
                      data.words
                          .where((word) => word.tags.contains(SkillTag.writing))
                          .map((word) => word.id)
                          .toSet(),
                      onOpenStudy,
                    ),
                  ),
                  _Specialty(
                    label: '翻译',
                    icon: Icons.translate_rounded,
                    count: _tagCount(data.words, SkillTag.translation),
                    onTap: () => _startSpecial(
                      controller,
                      data.words
                          .where(
                            (word) => word.tags.contains(SkillTag.translation),
                          )
                          .map((word) => word.id)
                          .toSet(),
                      onOpenStudy,
                    ),
                  ),
                  _Specialty(
                    label: '固定搭配',
                    icon: Icons.link_rounded,
                    count: data.words
                        .where((word) => word.collocations.isNotEmpty)
                        .length,
                    onTap: () => _startSpecial(
                      controller,
                      data.words
                          .where((word) => word.collocations.isNotEmpty)
                          .map((word) => word.id)
                          .toSet(),
                      onOpenStudy,
                    ),
                  ),
                  _Specialty(
                    label: '薄弱词',
                    icon: Icons.healing_rounded,
                    count: weakIds.length,
                    onTap: () =>
                        _startSpecial(controller, weakIds, onOpenStudy),
                  ),
                  _Specialty(
                    label: '重点词',
                    icon: Icons.star_rounded,
                    count: data.words.where((word) => word.isImportant).length,
                    onTap: () => _startSpecial(
                      controller,
                      data.words
                          .where((word) => word.isImportant)
                          .map((word) => word.id)
                          .toSet(),
                      onOpenStudy,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

int _tagCount(List<LearningWord> words, SkillTag tag) =>
    words.where((word) => word.tags.contains(tag)).length;

Future<void> _startSpecial(
  BetaController controller,
  Set<String> ids,
  VoidCallback onOpenStudy,
) async {
  if (ids.isEmpty) return;
  final session = await controller.startStudy(restrictToWordIds: ids);
  if (session != null) onOpenStudy();
}

class _Specialty extends StatelessWidget {
  const _Specialty({
    required this.label,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 19),
    label: Text('$label · $count'),
    onPressed: count == 0 ? null : onTap,
  );
}
