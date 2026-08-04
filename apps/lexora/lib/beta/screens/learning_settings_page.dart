import 'package:flutter/material.dart';

import '../controllers/beta_controller.dart';
import '../models/learning_models.dart';
import '../services/learning_pack_service.dart';
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
              _LearningContentCard(controller: controller),
              const SizedBox(height: 14),
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

class _LearningContentCard extends StatelessWidget {
  const _LearningContentCard({required this.controller});

  final BetaController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.data.settings;
    final enabled = settings.enabledLearningSources.toSet();
    final generatedCount = controller.data.words
        .where(
          (word) =>
              word.isStudyReady &&
              word.sources.any((source) => source.title.contains('词汇书生成记录')),
        )
        .length;
    return BetaSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('想要学习的内容', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '只会学习已经取得完整中英文释义的词条，可同时启用多个来源。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('正确生成过的词汇书'),
            subtitle: Text('$generatedCount 个已就绪词条'),
            value: enabled.contains('generated'),
            onChanged: (value) =>
                _toggleSource(controller, settings, 'generated', value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('直接查词添加的内容'),
            subtitle: const Text('在单词库中联网查词并加入的词条'),
            value: enabled.contains('manual'),
            onChanged: (value) =>
                _toggleSource(controller, settings, 'manual', value),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  '从历史新建学习内容',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _chooseHistory(context, controller),
                icon: const Icon(Icons.playlist_add_check_rounded),
                label: Text(
                  settings.selectedHistoryWordIds.isEmpty
                      ? '选择单词'
                      : '已选 ${settings.selectedHistoryWordIds.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '预设词汇书',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '刷新词库清单',
                onPressed: controller.refreshLearningPacks,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (controller.availablePacks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('正在读取服务器词库，或当前网络不可用。'),
            )
          else
            for (final pack in controller.availablePacks)
              _LearningPackTile(controller: controller, pack: pack),
        ],
      ),
    );
  }

  static void _toggleSource(
    BetaController controller,
    BetaSettings settings,
    String source,
    bool selected,
  ) {
    final values = settings.enabledLearningSources.toSet();
    selected ? values.add(source) : values.remove(source);
    controller.updateSettings(
      settings.copyWith(enabledLearningSources: values.toList()),
    );
  }

  static Future<void> _chooseHistory(
    BuildContext context,
    BetaController controller,
  ) async {
    final candidates =
        controller.data.words
            .where(
              (word) => word.sources.any(
                (source) =>
                    source.title.contains('查词记录') ||
                    source.title.contains('生成记录'),
              ),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final selected = controller.data.settings.selectedHistoryWordIds.toSet();
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('从历史选择单词'),
          content: SizedBox(
            width: 520,
            height: 460,
            child: candidates.isEmpty
                ? const Center(child: Text('历史中还没有可选择的单词。'))
                : ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final word = candidates[index];
                      return CheckboxListTile(
                        value: selected.contains(word.id),
                        title: Text(word.text),
                        subtitle: Text(
                          word.isStudyReady ? '释义已就绪' : '等待联网补全释义',
                        ),
                        onChanged: (value) => setDialogState(() {
                          value == true
                              ? selected.add(word.id)
                              : selected.remove(word.id);
                        }),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: const Text('保存选择'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final settings = controller.data.settings;
    final sources = settings.enabledLearningSources.toSet();
    result.isEmpty
        ? sources.remove('historySelected')
        : sources.add('historySelected');
    await controller.updateSettings(
      settings.copyWith(
        enabledLearningSources: sources.toList(),
        selectedHistoryWordIds: result.toList(),
      ),
    );
    await controller.enrichIncompleteWords(wordIds: result);
  }
}

class _LearningPackTile extends StatelessWidget {
  const _LearningPackTile({required this.controller, required this.pack});

  final BetaController controller;
  final LearningPackDescriptor pack;

  @override
  Widget build(BuildContext context) {
    final installed = controller.installedPacks.containsKey(pack.id);
    final selected = controller.data.settings.enabledLearningSources.contains(
      'preset:${pack.id}',
    );
    final busy = controller.packInFlight == pack.id;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.titleZh,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${pack.entryCount} 词 · ${pack.license} · ${pack.descriptionZh}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (busy)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: LinearProgressIndicator(
                        value: controller.packProgress,
                      ),
                    ),
                ],
              ),
            ),
            if (installed) ...[
              Switch(
                value: selected,
                onChanged: (value) {
                  final settings = controller.data.settings;
                  final values = settings.enabledLearningSources.toSet();
                  value
                      ? values.add('preset:${pack.id}')
                      : values.remove('preset:${pack.id}');
                  controller.updateSettings(
                    settings.copyWith(enabledLearningSources: values.toList()),
                  );
                },
              ),
              IconButton(
                tooltip: '删除下载的词库',
                onPressed: busy
                    ? null
                    : () => controller.uninstallLearningPack(pack.id),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ] else
              FilledButton.tonalIcon(
                onPressed: controller.packInFlight == null
                    ? () => controller.installLearningPack(pack)
                    : null,
                icon: const Icon(Icons.download_rounded),
                label: const Text('下载'),
              ),
          ],
        ),
      ),
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
