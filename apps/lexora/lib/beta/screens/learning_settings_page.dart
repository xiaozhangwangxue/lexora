import 'package:flutter/material.dart';

import '../controllers/beta_controller.dart';
import '../models/learning_models.dart';
import '../widgets/beta_ui.dart';

class LearningSettingsPage extends StatefulWidget {
  const LearningSettingsPage({super.key, required this.controller});

  final BetaController controller;

  @override
  State<LearningSettingsPage> createState() => _LearningSettingsPageState();
}

class _LearningSettingsPageState extends State<LearningSettingsPage> {
  late double _dailyLimit = widget.controller.data.settings.dailyNewWordLimit
      .toDouble();

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final settings = controller.data.settings;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          sliver: SliverList.list(
            children: [
              const BetaSectionTitle(
                '学习设置',
                subtitle: '这些设置只控制学习系统，不会改变词汇书的 PDF 排版设置。',
              ),
              const SizedBox(height: 18),
              BetaSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '每日新词数量：${settings.dailyNewWordLimit}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Slider(
                      value: _dailyLimit,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${_dailyLimit.round()}',
                      onChanged: (value) => setState(() => _dailyLimit = value),
                      onChangeEnd: (value) => controller.updateSettings(
                        settings.copyWith(dailyNewWordLimit: value.round()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<StudyMode>(
                      initialValue: settings.defaultStudyMode,
                      decoration: const InputDecoration(labelText: '默认学习模式'),
                      items: [
                        for (final value in StudyMode.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_studyModeLabel(value)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          controller.updateSettings(
                            settings.copyWith(defaultStudyMode: value),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '启用的复习模式',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final mode in ReviewMode.values)
                          FilterChip(
                            label: Text(_reviewModeLabel(mode)),
                            selected: settings.enabledReviewModes.contains(
                              mode,
                            ),
                            onSelected: (selected) {
                              final modes = [...settings.enabledReviewModes];
                              if (selected) {
                                modes.add(mode);
                              } else if (modes.length > 1) {
                                modes.remove(mode);
                              }
                              controller.updateSettings(
                                settings.copyWith(
                                  enabledReviewModes: modes.toSet().toList(),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BetaSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('发音设置', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    SegmentedButton<PreferredAccent>(
                      segments: const [
                        ButtonSegment(
                          value: PreferredAccent.us,
                          label: Text('美式'),
                          icon: Icon(Icons.volume_up_rounded),
                        ),
                        ButtonSegment(
                          value: PreferredAccent.uk,
                          label: Text('英式'),
                          icon: Icon(Icons.volume_up_outlined),
                        ),
                      ],
                      selected: {settings.preferredAccent},
                      onSelectionChanged: (value) => controller.updateSettings(
                        settings.copyWith(preferredAccent: value.first),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<double>(
                      initialValue: settings.speechRate,
                      decoration: const InputDecoration(labelText: '朗读速度'),
                      items: const [
                        DropdownMenuItem(value: .75, child: Text('0.75x')),
                        DropdownMenuItem(value: 1, child: Text('1.0x')),
                        DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          controller.updateSettings(
                            settings.copyWith(speechRate: value),
                          );
                        }
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('显示答案后自动播放单词'),
                      value: settings.autoPlayWordAudio,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(autoPlayWordAudio: value),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('显示答案后自动播放例句'),
                      value: settings.autoPlayExampleAudio,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(autoPlayExampleAudio: value),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('显示下次复习时间'),
                      value: settings.showNextReviewTime,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(showNextReviewTime: value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BetaSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('数据信息', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _Info('当前数据版本', '${controller.data.schemaVersion}'),
                    _Info('单词数量', '${controller.data.words.length}'),
                    _Info('复习记录数量', '${controller.data.reviewLogs.length}'),
                    _Info(
                      '最近一次数据迁移',
                      controller.data.migratedAt?.toLocal().toString() ??
                          '无需迁移',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '学习数据会保存在应用文档目录，并同时保留恢复副本。Beta 不提供危险的一键清空数据按钮。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

String _studyModeLabel(StudyMode value) => switch (value) {
  StudyMode.mixed => '综合模式',
  StudyMode.wordToMeaning => '英译中',
  StudyMode.meaningToWord => '中译英',
  StudyMode.spelling => '拼写测试',
  StudyMode.cloze => '例句填空',
  StudyMode.collocation => '固定搭配填空',
};

String _reviewModeLabel(ReviewMode value) => switch (value) {
  ReviewMode.wordToMeaning => '英译中',
  ReviewMode.meaningToWord => '中译英',
  ReviewMode.spelling => '拼写测试',
  ReviewMode.cloze => '例句填空',
  ReviewMode.collocation => '固定搭配填空',
};
