import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_version.dart';
import '../l10n/app_localizations.dart';
import '../models/word_entry.dart';
import '../services/developer_log_service.dart';
import '../services/offline_lexicon_service.dart';
import '../services/pdf_service.dart';
import '../services/pdf_settings_service.dart';
import '../services/server_acceleration_service.dart';
import '../services/update_service.dart';
import '../widgets/github_button.dart';
import '../widgets/lexora_wordmark.dart';
import '../widgets/release_notes_content.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onOpenTypography,
    required this.onClearSearchCache,
  });

  final PdfSettings settings;
  final ValueChanged<PdfSettings> onChanged;
  final VoidCallback onOpenTypography;
  final Future<void> Function() onClearSearchCache;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _offlineLexicon = OfflineLexiconService.instance;
  final _serverAcceleration = ServerAccelerationService.instance;

  PdfSettings get settings => widget.settings;
  ValueChanged<PdfSettings> get onChanged => widget.onChanged;
  VoidCallback get onOpenTypography => widget.onOpenTypography;

  Future<void> _showClearCacheDialog(BuildContext context) async {
    final strings = AppLocalizations.of(context);
    var searchCache = true;
    var installerCache = false;
    var offlineLexicons = false;
    var busy = false;
    String? result;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> clearSelected() async {
            if (!searchCache && !installerCache && !offlineLexicons) return;
            setDialogState(() {
              busy = true;
              result = null;
            });
            try {
              if (searchCache) await widget.onClearSearchCache();
              if (installerCache) {
                await UpdateService.cleanupCachedInstallers();
              }
              if (offlineLexicons) await _offlineLexicon.removeAll();
              setDialogState(() {
                result = strings.isZh
                    ? '所选缓存已清除。词汇书、生成记录、搜索历史和学习进度均已保留。'
                    : 'Selected caches were cleared. Books, history, and learning progress were preserved.';
              });
            } catch (error) {
              setDialogState(() {
                result = strings.isZh
                    ? '清除失败：$error'
                    : 'Cleanup failed: $error';
              });
            } finally {
              setDialogState(() => busy = false);
            }
          }

          return AlertDialog(
            icon: const Icon(Icons.cleaning_services_rounded),
            title: Text(strings.isZh ? '自定义清除缓存' : 'Choose caches to clear'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.isZh
                          ? '只选择需要重新下载或重新查询的内容。用户数据不会被列入清理范围。'
                          : 'Only select content that can be downloaded or queried again. User data is excluded.',
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: searchCache,
                      onChanged: busy
                          ? null
                          : (value) => setDialogState(
                              () => searchCache = value ?? false,
                            ),
                      title: Text(
                        strings.isZh
                            ? '查词与翻译缓存'
                            : 'Dictionary and translation cache',
                      ),
                      subtitle: Text(
                        strings.isZh
                            ? '下次查询时会重新从词典服务获取。'
                            : 'Dictionary data will be fetched again on the next lookup.',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: installerCache,
                      onChanged: busy
                          ? null
                          : (value) => setDialogState(
                              () => installerCache = value ?? false,
                            ),
                      title: Text(
                        strings.isZh ? '更新安装包缓存' : 'Update installer cache',
                      ),
                      subtitle: Text(
                        strings.isZh
                            ? '只清除已经下载到临时目录的安装文件。'
                            : 'Only removes installers saved in the temporary folder.',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: offlineLexicons,
                      onChanged: busy || _offlineLexicon.downloading
                          ? null
                          : (value) => setDialogState(
                              () => offlineLexicons = value ?? false,
                            ),
                      title: Text(
                        strings.isZh
                            ? '已下载的离线词典包'
                            : 'Downloaded offline dictionaries',
                      ),
                      subtitle: Text(
                        strings.isZh
                            ? '删除极速版和完整版；联网查词不受影响。'
                            : 'Removes Fast and Full editions; online lookup remains available.',
                      ),
                    ),
                    if (result != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        result!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              result!.startsWith('清除失败') ||
                                  result!.startsWith('Cleanup failed')
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(strings.close),
              ),
              FilledButton.icon(
                onPressed:
                    busy ||
                        (!searchCache && !installerCache && !offlineLexicons)
                    ? null
                    : clearSelected,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_sweep_rounded),
                label: Text(
                  strings.isZh
                      ? (busy ? '正在清除…' : '清除所选缓存')
                      : (busy ? 'Clearing…' : 'Clear selected'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _offlineLexicon.addListener(_offlineLexiconChanged);
    _serverAcceleration.addListener(_serverAccelerationChanged);
    unawaited(_offlineLexicon.initialize());
    unawaited(_serverAcceleration.initialize());
  }

  @override
  void dispose() {
    _offlineLexicon.removeListener(_offlineLexiconChanged);
    _serverAcceleration.removeListener(_serverAccelerationChanged);
    super.dispose();
  }

  void _offlineLexiconChanged() {
    if (mounted) setState(() {});
  }

  void _serverAccelerationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _setServerAcceleration(bool value) async {
    await _serverAcceleration.setEnabled(value);
    DeveloperLogService.instance.log(
      'settings.server_acceleration_changed',
      data: {'enabled': value},
    );
  }

  Future<void> _activateOfflineLexicon(
    BuildContext context,
    OfflineLexiconEdition? edition,
  ) async {
    try {
      await _offlineLexicon.activate(edition);
    } catch (error) {
      if (context.mounted) {
        final strings = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.offlineLexiconFailed('$error'))),
        );
      }
    }
  }

  Future<void> _downloadOfflineLexicon(
    BuildContext context,
    OfflineLexiconEdition edition,
  ) async {
    final strings = AppLocalizations.of(context);
    try {
      final manifest =
          _offlineLexicon.manifest ?? await _offlineLexicon.refreshManifest();
      if (!context.mounted) return;
      final package = manifest.packages[edition];
      if (package == null) {
        throw StateError('Package is not available yet.');
      }
      final name = edition == OfflineLexiconEdition.fast20k
          ? strings.fastLexicon
          : strings.fullLexicon;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.downloadLexiconTitle),
          content: Text(
            strings.downloadLexiconBody(
              name,
              _formatFileSize(package.archiveBytes),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.download_rounded),
              label: Text(strings.downloadLexicon),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _offlineLexicon.download(edition);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.offlineLexiconFailed('$error'))),
        );
      }
    }
  }

  Future<void> _setDeveloperMode(bool value) async {
    await DeveloperLogService.instance.setEnabled(value);
    if (mounted) setState(() {});
  }

  Future<void> _exportLogs(BuildContext context) async {
    final strings = AppLocalizations.of(context);
    try {
      DeveloperLogService.instance.log('logs.export_requested');
      final file = await DeveloperLogService.instance.exportFullLog();
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/x-ndjson'),
      ], subject: 'Lexora $appVersion diagnostics');
    } catch (error, stack) {
      DeveloperLogService.instance.log(
        'logs.export_failed',
        error: error,
        stackTrace: stack,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.exportLogsFailed(error.toString()))),
        );
      }
    }
  }

  Future<void> _deleteLogs(BuildContext context) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteLogs),
        content: Text(strings.deleteLogsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DeveloperLogService.instance.deleteLogs();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.logsDeleted)));
    }
  }

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse('https://lexora.12323456.xyz');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).openWebsiteFailed)),
      );
    }
  }

  Future<void> _openLicense(BuildContext context) async {
    final uri = Uri.parse(
      'https://github.com/xiaozhangwangxue/lexora/blob/main/LICENSE',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).openGitHubFailed)),
      );
    }
  }

  Future<void> _showDonation(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) {
      final strings = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(strings.donationChannels),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.donateHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final vertical = constraints.maxWidth < 440;
                    final codes = [
                      _DonationCode(
                        asset: 'assets/donate/wechat.png',
                        label: strings.wechatPay,
                      ),
                      _DonationCode(
                        asset: 'assets/donate/alipay.jpg',
                        label: strings.alipay,
                      ),
                    ];
                    return vertical
                        ? Column(
                            children: [
                              codes.first,
                              const SizedBox(height: 20),
                              codes.last,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: codes.first),
                              const SizedBox(width: 18),
                              Expanded(child: codes.last),
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.close),
          ),
        ],
      );
    },
  );

  Future<void> _checkForUpdates(BuildContext context) async {
    final strings = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
          child: SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34),
                  child: Text(
                    strings.checkingForUpdates,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final update = await UpdateService().check();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (update == null) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline_rounded),
            title: Text(strings.upToDate),
            content: Text(strings.upToDateBody),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(strings.gotIt),
              ),
            ],
          ),
        );
        return;
      }
      final notes = strings.isZh ? update.notesZh : update.notesEn;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.system_update_alt_rounded),
          title: Text(strings.updateAvailable(update.version)),
          content: ReleaseNotesContent(
            notes: notes,
            isZh: strings.isZh,
            extra: Platform.isMacOS
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.privacy_tip_outlined, size: 20),
                          const SizedBox(width: 9),
                          Expanded(child: Text(strings.macUpdateExitHint)),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.download_rounded),
              label: Text(
                Platform.isMacOS
                    ? strings.openOfficialDownload
                    : strings.downloadAndInstall,
              ),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted && Platform.isMacOS) {
        await UpdateService().openMacDownloadPageAndQuit(update);
      } else if (confirmed == true && context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _UpdateDownloadDialog(update: update),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.updateFailed(error.toString()))),
      );
    }
  }

  Widget _buildOfflinePackageTile(
    BuildContext context,
    OfflineLexiconEdition edition, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final strings = AppLocalizations.of(context);
    final installed = _offlineLexicon.installed[edition];
    final package = _offlineLexicon.manifest?.packages[edition];
    final selected = _offlineLexicon.activeEdition == edition;
    final details = <String>[
      subtitle,
      if (installed != null)
        '${strings.offlineLexiconRows(installed.rows)} · v${installed.version}'
      else if (package != null)
        '${strings.offlineLexiconRows(package.rows)} · ${_formatFileSize(package.archiveBytes)}',
    ].join('\n');
    final busy = _offlineLexicon.downloading;
    return _OfflineLexiconTile(
      icon: icon,
      title: title,
      subtitle: details,
      selected: selected,
      status: selected
          ? strings.offlineLexiconInstalled
          : installed != null
          ? strings.offlineLexiconAvailable
          : null,
      buttonLabel: installed != null
          ? strings.useLexicon
          : strings.downloadLexicon,
      onPressed: busy
          ? null
          : installed != null
          ? () => _activateOfflineLexicon(context, edition)
          : () => _downloadOfflineLexicon(context, edition),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            strings.settings,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (Theme.of(context).platform ==
                              TargetPlatform.android) ...[
                            const SizedBox(width: 9),
                            Text(
                              'v$appVersion',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const GitHubButton(),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 36),
                    children: [
                      Card(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: .72,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                constraints: const BoxConstraints(
                                  minWidth: 106,
                                ),
                                height: 52,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withValues(
                                    alpha: .72,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: .65),
                                  ),
                                ),
                                child: const Center(
                                  child: LexoraWordmark(
                                    fontSize: 24,
                                    alignment: TextAlign.left,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      strings.settingsIntroTitle,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      strings.settingsIntroBody,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            height: 1.55,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: strings.pdfSettings,
                        icon: Icons.tune_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.exportFormat,
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final choice in [
                                  (BookFormat.pdf, 'PDF'),
                                  (BookFormat.epub, 'EPUB'),
                                  (BookFormat.docx, 'DOCX'),
                                  (BookFormat.images, strings.pageImages),
                                  (BookFormat.longImage, strings.longImage),
                                ])
                                  ChoiceChip(
                                    selected: settings.format == choice.$1,
                                    label: Text(choice.$2),
                                    onSelected: (_) => onChanged(
                                      settings.copyWith(format: choice.$1),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              strings.paperSize,
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<BookPageSize>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: BookPageSize.a4,
                                    label: Text('A4'),
                                  ),
                                  ButtonSegment(
                                    value: BookPageSize.a5,
                                    label: Text('A5'),
                                  ),
                                  ButtonSegment(
                                    value: BookPageSize.b5,
                                    label: Text('B5'),
                                  ),
                                ],
                                selected: {settings.pageSize},
                                onSelectionChanged: (value) => onChanged(
                                  settings.copyWith(pageSize: value.first),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              strings.paperSizeHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              strings.pdfFontSize,
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<PdfFontSize>(
                                segments: [
                                  ButtonSegment(
                                    value: PdfFontSize.small,
                                    label: Text(strings.small),
                                  ),
                                  ButtonSegment(
                                    value: PdfFontSize.medium,
                                    label: Text(strings.medium),
                                  ),
                                  ButtonSegment(
                                    value: PdfFontSize.large,
                                    label: Text(strings.large),
                                  ),
                                ],
                                selected: {settings.fontSize},
                                onSelectionChanged: (value) => onChanged(
                                  settings.applyPreset(value.first),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: onOpenTypography,
                                icon: const Icon(Icons.tune_rounded),
                                label: Text(strings.fineTuneTypography),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              strings.examples,
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<ExampleAmount>(
                                segments: [
                                  ButtonSegment(
                                    value: ExampleAmount.none,
                                    label: Text(strings.noExamples),
                                  ),
                                  ButtonSegment(
                                    value: ExampleAmount.one,
                                    label: Text(strings.oneExample),
                                  ),
                                  ButtonSegment(
                                    value: ExampleAmount.upToThree,
                                    label: Text(strings.upToThreeExamples),
                                  ),
                                ],
                                selected: {settings.exampleAmount},
                                onSelectionChanged: (value) => onChanged(
                                  settings.copyWith(exampleAmount: value.first),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: strings.serverAcceleration,
                        icon: Icons.cloud_sync_rounded,
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            _serverAcceleration.enabled
                                ? Icons.bolt_rounded
                                : Icons.cloud_off_outlined,
                            color: _serverAcceleration.enabled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            _serverAcceleration.enabled
                                ? strings.serverAccelerationEnabled
                                : strings.serverAccelerationDisabled,
                          ),
                          subtitle: Text(
                            strings.serverAccelerationHint,
                            style: const TextStyle(height: 1.45),
                          ),
                          value: _serverAcceleration.enabled,
                          onChanged: _setServerAcceleration,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: strings.offlineLexicon,
                        icon: Icons.offline_bolt_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.offlineLexiconHint,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _OfflineLexiconTile(
                              icon: Icons.cloud_outlined,
                              title: strings.onlineLexicon,
                              subtitle: strings.isZh
                                  ? '无需下载，自动使用双服务器和原有词典来源'
                                  : 'No download; uses the dual-server service and existing providers',
                              selected: _offlineLexicon.activeEdition == null,
                              buttonLabel: strings.useOnlineOnly,
                              onPressed: _offlineLexicon.downloading
                                  ? null
                                  : () =>
                                        _activateOfflineLexicon(context, null),
                            ),
                            const Divider(height: 22),
                            _buildOfflinePackageTile(
                              context,
                              OfflineLexiconEdition.fast20k,
                              icon: Icons.bolt_rounded,
                              title: strings.fastLexicon,
                              subtitle: strings.fastLexiconHint,
                            ),
                            const Divider(height: 22),
                            _buildOfflinePackageTile(
                              context,
                              OfflineLexiconEdition.full,
                              icon: Icons.library_books_rounded,
                              title: strings.fullLexicon,
                              subtitle: strings.fullLexiconHint,
                            ),
                            if (_offlineLexicon.downloading) ...[
                              const SizedBox(height: 15),
                              LinearProgressIndicator(
                                value: _offlineLexicon.downloadProgress,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                strings.downloadingLexicon,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: strings.isZh ? '搜索结果字体' : 'Search result text',
                        icon: Icons.text_fields_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.isZh
                                  ? '精细调整释义、例句和联想词的显示大小。默认值已针对手机阅读优化。'
                                  : 'Fine-tune definitions, examples, and related-word text. The default is optimized for phone reading.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.text_decrease_rounded),
                                Expanded(
                                  child: Slider(
                                    value: settings.searchTextScale,
                                    min: .8,
                                    max: 1.5,
                                    divisions: 14,
                                    label:
                                        '${(settings.searchTextScale * 100).round()}%',
                                    onChanged: (value) => onChanged(
                                      settings.copyWith(searchTextScale: value),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.text_increase_rounded),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    '${(settings.searchTextScale * 100).round()}%',
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: settings.searchTextScale == 1
                                  ? null
                                  : () => onChanged(
                                      settings.copyWith(searchTextScale: 1),
                                    ),
                              child: Text(strings.isZh ? '恢复默认' : 'Reset'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: strings.isZh ? '缓存管理' : 'Cache management',
                        icon: Icons.cleaning_services_rounded,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.delete_sweep_outlined),
                          title: Text(
                            strings.isZh ? '自定义清除缓存' : 'Choose caches to clear',
                          ),
                          subtitle: Text(
                            strings.isZh
                                ? '选择清除查词、更新安装包或离线词典缓存；不会删除个人数据。'
                                : 'Clear lookup, installer, or offline dictionary caches without deleting personal data.',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _showClearCacheDialog(context),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: strings.developerMode,
                        icon: Icons.terminal_rounded,
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(strings.developerLogging),
                              subtitle: Text(strings.developerLoggingHint),
                              value: DeveloperLogService.instance.enabled,
                              onChanged: _setDeveloperMode,
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              switchInCurve: const Cubic(.23, 1, .32, 1),
                              switchOutCurve: Curves.easeOut,
                              child: DeveloperLogService.instance.enabled
                                  ? Column(
                                      key: const ValueKey('developer-actions'),
                                      children: [
                                        const Divider(height: 20),
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(
                                            Icons.ios_share_rounded,
                                          ),
                                          title: Text(strings.exportLogs),
                                          subtitle: Text(
                                            strings.exportLogsHint,
                                          ),
                                          onTap: () => _exportLogs(context),
                                        ),
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(
                                            Icons.delete_outline_rounded,
                                            color: theme.colorScheme.error,
                                          ),
                                          title: Text(strings.deleteLogs),
                                          onTap: () => _deleteLogs(context),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('developer-actions-hidden'),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: strings.quickLinks,
                        icon: Icons.north_east_rounded,
                        child: Column(
                          children: [
                            _QuickLinkTile(
                              icon: Icons.system_update_alt_rounded,
                              color: theme.colorScheme.primary,
                              background: theme.colorScheme.primaryContainer,
                              title: strings.checkForUpdates,
                              subtitle: strings.checkForUpdatesHint,
                              onTap: () => _checkForUpdates(context),
                            ),
                            const Divider(height: 24),
                            _QuickLinkTile(
                              icon: Icons.language_rounded,
                              color: Colors.white,
                              background: theme.colorScheme.primary,
                              title: strings.officialWebsite,
                              subtitle: strings.officialWebsiteHint,
                              onTap: () => _openWebsite(context),
                            ),
                            const Divider(height: 24),
                            _QuickLinkTile(
                              icon: Icons.balance_rounded,
                              color: theme.colorScheme.secondary,
                              background: theme.colorScheme.secondaryContainer,
                              title: strings.openSourceLicense,
                              subtitle: strings.openSourceLicenseHint,
                              onTap: () => _openLicense(context),
                            ),
                            const Divider(height: 24),
                            _QuickLinkTile(
                              icon: Icons.favorite_rounded,
                              color: theme.colorScheme.tertiary,
                              background: theme.colorScheme.tertiaryContainer,
                              title: strings.donate,
                              subtitle: strings.donateHint,
                              trailing: Icons.qr_code_2_rounded,
                              onTap: () => _showDonation(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}

class _OfflineLexiconTile extends StatelessWidget {
  const _OfflineLexiconTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.buttonLabel,
    required this.onPressed,
    this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final String? status;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: const Cubic(.23, 1, .32, 1),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: .55)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: .42)
              : theme.colorScheme.outlineVariant.withValues(alpha: .65),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              selected ? Icons.check_rounded : icon,
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          status!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (!selected)
            TextButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class _UpdateDownloadDialog extends StatefulWidget {
  const _UpdateDownloadDialog({required this.update});

  final UpdateInfo update;

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  double? _progress = 0;
  String? _error;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _download());
  }

  Future<void> _download() async {
    setState(() {
      _error = null;
      _progress = 0;
      _launching = false;
    });
    try {
      await UpdateService().downloadAndLaunch(
        widget.update,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      setState(() => _launching = true);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return PopScope(
      canPop: _error != null,
      child: AlertDialog(
        icon: Icon(
          _error == null
              ? Icons.downloading_rounded
              : Icons.error_outline_rounded,
        ),
        title: Text(
          _launching ? strings.launchingInstaller : strings.downloadingUpdate,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error == null) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 10),
                Text(
                  _progress == null
                      ? strings.downloadingUpdate
                      : '${(_progress! * 100).clamp(0, 100).round()}%',
                ),
              ] else
                Text(strings.updateFailed(_error!)),
            ],
          ),
        ),
        actions: _error == null
            ? null
            : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(strings.cancel),
                ),
                FilledButton(onPressed: _download, child: Text(strings.retry)),
              ],
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing = Icons.open_in_new_rounded,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData trailing;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(18));
    return Material(
      key: ValueKey('quick-link-$title'),
      type: MaterialType.transparency,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        shape: const RoundedRectangleBorder(borderRadius: radius),
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(trailing),
        onTap: onTap,
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 9),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
}

class _DonationCode extends StatelessWidget {
  const _DonationCode({required this.asset, required this.label});

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 230,
        constraints: const BoxConstraints(maxHeight: 310),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
      const SizedBox(height: 9),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}
