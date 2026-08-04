import 'package:flutter/material.dart';

import '../controllers/beta_controller.dart';
import '../domain/learning_stats.dart';
import '../models/learning_models.dart';
import '../widgets/beta_ui.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.controller});

  final BetaController controller;

  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    final today = calculateTodayStats(data.reviewLogs, DateTime.now());
    final counts = {
      for (final status in LearningStatus.values)
        status: data.reviewStates.values
            .where((value) => value.status == status)
            .length,
    };
    final started = data.words.length - (counts[LearningStatus.newWord] ?? 0);
    final mastery = started == 0
        ? 0.0
        : (counts[LearningStatus.mastered] ?? 0) / started;
    final logsByWord = groupReviewLogsByWord(data.reviewLogs);
    final weak = data.words.where((word) {
      final state = data.reviewStates[word.id];
      if (state == null) return false;
      return isWeakWord(state, logsByWord[word.id] ?? const <ReviewLog>[]);
    }).length;
    final metrics = [
      ('今日复习次数', '${today.reviewCount}', Icons.replay_rounded),
      ('今日学习单词数', '${today.uniqueWordCount}', Icons.menu_book_rounded),
      ('今日新学单词数', '${today.newWordCount}', Icons.fiber_new_rounded),
      ('今日认识', '${today.goodCount}', Icons.sentiment_satisfied_alt_rounded),
      ('今日模糊', '${today.hardCount}', Icons.sentiment_neutral_rounded),
      ('今日不认识', '${today.againCount}', Icons.sentiment_dissatisfied_rounded),
      (
        '回忆成功率',
        '${(today.recallSuccessRate * 100).round()}%',
        Icons.psychology_rounded,
      ),
      (
        '拼写正确率',
        '${(today.spellingAccuracy * 100).round()}%',
        Icons.spellcheck_rounded,
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          sliver: SliverList.list(
            children: [
              const BetaSectionTitle(
                '学习统计',
                subtitle: '所有数字均由真实复习状态和追加式 ReviewLog 计算。',
              ),
              const SizedBox(height: 18),
              _MetricGrid(metrics: metrics),
              const SizedBox(height: 26),
              const BetaSectionTitle('总体统计'),
              const SizedBox(height: 12),
              BetaSurface(
                child: Column(
                  children: [
                    _Row('总单词数', '${data.words.length}'),
                    _Row('尚未学习', '${counts[LearningStatus.newWord] ?? 0}'),
                    _Row('学习中', '${counts[LearningStatus.learning] ?? 0}'),
                    _Row('复习中', '${counts[LearningStatus.review] ?? 0}'),
                    _Row('已掌握', '${counts[LearningStatus.mastered] ?? 0}'),
                    _Row('遗忘重学', '${counts[LearningStatus.lapsed] ?? 0}'),
                    _Row('薄弱词', '$weak'),
                    _Row(
                      '重点词',
                      '${data.words.where((word) => word.isImportant).length}',
                    ),
                    _Row('总复习次数', '${data.reviewLogs.length}'),
                    _Row(
                      '总遗忘次数',
                      '${data.reviewStates.values.fold<int>(0, (sum, value) => sum + value.lapseCount)}',
                    ),
                    const Divider(),
                    _Row('总体掌握率', '${(mastery * 100).round()}%', strong: true),
                    _Row(
                      '连续学习',
                      '${calculateStreak(data.dailySummaries, DateTime.now())} 天',
                      strong: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const BetaSectionTitle('最近学习日'),
              const SizedBox(height: 12),
              BetaSurface(
                child: data.dailySummaries.isEmpty
                    ? const Text('完成有效复习后，学习日记录会显示在这里。')
                    : Column(
                        children: [
                          for (final summary
                              in (data.dailySummaries.values.toList()..sort(
                                    (a, b) => b.localDateKey.compareTo(
                                      a.localDateKey,
                                    ),
                                  ))
                                  .take(14))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                summary.qualifiedStudyDay
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                              ),
                              title: Text(summary.localDateKey),
                              subtitle: Text(
                                '${summary.reviewCount} 次复习 · ${summary.uniqueWordCount} 个单词 · '
                                '认识 ${summary.goodCount}',
                              ),
                              trailing: Text(
                                summary.qualifiedStudyDay ? '有效学习日' : '未达标',
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<(String, String, IconData)> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 4
          : constraints.maxWidth >= 540
          ? 2
          : 1;
      const gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: width,
              child: BetaMetric(
                label: metric.$1,
                value: metric.$2,
                icon: metric.$3,
              ),
            ),
        ],
      );
    },
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
