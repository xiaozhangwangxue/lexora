import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/word_entry.dart';
import '../services/pdf_service.dart';
import '../services/pdf_settings_service.dart';
import '../services/update_service.dart';
import '../widgets/github_button.dart';
import '../widgets/lexora_wordmark.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onOpenTypography,
  });

  final PdfSettings settings;
  final ValueChanged<PdfSettings> onChanged;
  final VoidCallback onOpenTypography;

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse('https://lexora.12323456.xyz');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).openWebsiteFailed)),
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
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.whatsNew,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                for (final note in notes) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: Icon(Icons.circle, size: 5),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(note)),
                    ],
                  ),
                  const SizedBox(height: 7),
                ],
                if (Platform.isMacOS) ...[
                  const SizedBox(height: 8),
                  DecoratedBox(
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
                  ),
                ],
              ],
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
              label: Text(strings.downloadAndInstall),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
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
                      child: Text(
                        strings.settings,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
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
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<BookFormat>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: BookFormat.pdf,
                                    label: Text('PDF'),
                                  ),
                                  ButtonSegment(
                                    value: BookFormat.epub,
                                    label: Text('EPUB'),
                                  ),
                                  ButtonSegment(
                                    value: BookFormat.docx,
                                    label: Text('DOCX'),
                                  ),
                                ],
                                selected: {settings.format},
                                onSelectionChanged: (value) => onChanged(
                                  settings.copyWith(format: value.first),
                                ),
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
                        title: strings.quickLinks,
                        icon: Icons.north_east_rounded,
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  Icons.system_update_alt_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              title: Text(strings.checkForUpdates),
                              subtitle: Text(strings.checkForUpdatesHint),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _checkForUpdates(context),
                            ),
                            const Divider(height: 24),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.tertiary,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.language_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(strings.officialWebsite),
                              subtitle: Text(strings.officialWebsiteHint),
                              trailing: const Icon(Icons.open_in_new_rounded),
                              onTap: () => _openWebsite(context),
                            ),
                            const Divider(height: 24),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  Icons.favorite_rounded,
                                  color: theme.colorScheme.tertiary,
                                ),
                              ),
                              title: Text(strings.donate),
                              subtitle: Text(strings.donateHint),
                              trailing: const Icon(Icons.qr_code_2_rounded),
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
