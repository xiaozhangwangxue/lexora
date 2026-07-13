import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/pdf_service.dart';
import '../services/pdf_settings_service.dart';

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
        SnackBar(
          content: Text(AppLocalizations.of(context).openWebsiteFailed),
        ),
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    strings.donateHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(builder: (context, constraints) {
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
                  }),
                ]),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
            children: [
              Text(
                strings.settings,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: .72),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.auto_stories_rounded,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.settingsIntroTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              strings.settingsIntroBody,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.55,
                                color: theme.colorScheme.onSurfaceVariant,
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
                    Text(strings.pdfFontSize, style: theme.textTheme.labelLarge),
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
                    Text(strings.examples, style: theme.textTheme.labelLarge),
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
                child: Column(children: [
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
                ]),
              ),
            ],
          ),
        ),
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
              Row(children: [
                Icon(icon, size: 20),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ]),
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
  Widget build(BuildContext context) => Column(children: [
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
      ]);
}
