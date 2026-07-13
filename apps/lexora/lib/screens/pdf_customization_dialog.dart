import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/pdf_service.dart';
import '../services/pdf_settings_service.dart';

Future<PdfSettings?> showPdfCustomizationDialog(
  BuildContext context,
  PdfSettings settings,
) =>
    showGeneralDialog<PdfSettings>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: .24),
      transitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (_, __, ___) => _PdfCustomizationDialog(initial: settings),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .055),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: .92, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );

class _PdfCustomizationDialog extends StatefulWidget {
  const _PdfCustomizationDialog({required this.initial});

  final PdfSettings initial;

  @override
  State<_PdfCustomizationDialog> createState() =>
      _PdfCustomizationDialogState();
}

class _PdfCustomizationDialogState extends State<_PdfCustomizationDialog> {
  late PdfSettings _settings = widget.initial;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final glassColor = theme.colorScheme.surface.withValues(
      alpha: Platform.isMacOS ? .74 : .98,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 660,
            maxHeight: size.height - 40,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: Platform.isMacOS ? 30 : 12,
                sigmaY: Platform.isMacOS ? 30 : 12,
              ),
              child: Material(
                color: glassColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: .48),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 16, 14),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.tertiary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.text_fields_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.fineTuneTypography,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              strings.fineTuneTypographyHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: strings.close,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: const {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                          PointerDeviceKind.stylus,
                        },
                      ),
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        interactive: true,
                        radius: const Radius.circular(20),
                        thickness: 6,
                        child: SingleChildScrollView(
                          key: const Key('pdf-customization-scroll'),
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 20, 34, 20),
                          child: Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerSignal: _handlePointerSignal,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  strings.fontPreset,
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                              Icon(
                                Icons.unfold_more_rounded,
                                size: 17,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  strings.scrollToAdjust,
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<PdfFontSize>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(
                                  value: PdfFontSize.small,
                                  label: FittedBox(child: Text(strings.small)),
                                ),
                                ButtonSegment(
                                  value: PdfFontSize.medium,
                                  label: FittedBox(child: Text(strings.medium)),
                                ),
                                ButtonSegment(
                                  value: PdfFontSize.large,
                                  label: FittedBox(child: Text(strings.large)),
                                ),
                              ],
                              selected: {_settings.fontSize},
                              onSelectionChanged: (value) => setState(
                                () => _settings =
                                    _settings.applyPreset(value.first),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _TypographyPreview(
                            typography: _settings.typography,
                            label: strings.typographyPreview,
                          ),
                          const SizedBox(height: 20),
                          _FontSlider(
                            label: strings.wordTitleFont,
                            value: _settings.typography.word,
                            min: 14,
                            max: 30,
                            onChanged: (value) => _updateTypography(
                              _settings.typography.copyWith(word: value),
                            ),
                          ),
                          _FontSlider(
                            label: strings.phoneticFont,
                            value: _settings.typography.phonetic,
                            min: 8,
                            max: 18,
                            onChanged: (value) => _updateTypography(
                              _settings.typography.copyWith(phonetic: value),
                            ),
                          ),
                          _FontSlider(
                            label: strings.definitionFont,
                            value: _settings.typography.definition,
                            min: 8,
                            max: 18,
                            onChanged: (value) => _updateTypography(
                              _settings.typography.copyWith(definition: value),
                            ),
                          ),
                          _FontSlider(
                            label: strings.relatedFont,
                            value: _settings.typography.related,
                            min: 7,
                            max: 16,
                            onChanged: (value) => _updateTypography(
                              _settings.typography.copyWith(related: value),
                            ),
                          ),
                          _FontSlider(
                            label: strings.exampleFont,
                            value: _settings.typography.example,
                            min: 7,
                            max: 16,
                            onChanged: (value) => _updateTypography(
                              _settings.typography.copyWith(example: value),
                            ),
                          ),
                          _FontSlider(
                            label: strings.phraseFont,
                            value: _settings.typography.phrase,
                            min: 7,
                            max: 16,
                            onChanged: (value) => _updateTypography(
                              _settings.typography.copyWith(phrase: value),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(strings.examples,
                              style: theme.textTheme.labelLarge),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ExampleAmount>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(
                                  value: ExampleAmount.none,
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(strings.noExamples),
                                  ),
                                ),
                                ButtonSegment(
                                  value: ExampleAmount.one,
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(strings.oneExample),
                                  ),
                                ),
                                ButtonSegment(
                                  value: ExampleAmount.upToThree,
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(strings.upToThreeExamples),
                                  ),
                                ),
                              ],
                              selected: {_settings.exampleAmount},
                              onSelectionChanged: (value) => setState(
                                () => _settings = _settings.copyWith(
                                  exampleAmount: value.first,
                                ),
                              ),
                            ),
                          ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(strings.cancel),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () =>
                              Navigator.of(context).pop(_settings),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(strings.saveChanges),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateTypography(PdfTypography typography) {
    setState(() => _settings = _settings.copyWith(typography: typography));
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      final position = _scrollController.position;
      final target = (position.pixels + scroll.scrollDelta.dy)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      _scrollController.jumpTo(target);
    });
  }
}

class _FontSlider extends StatelessWidget {
  const _FontSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final slider = Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: ((max - min) * 2).round(),
            onChanged: onChanged,
          );
          final valueLabel = Text(
            '${value.toStringAsFixed(1)} pt',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium,
          );
          if (constraints.maxWidth < 430) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text(label)),
                  valueLabel,
                ]),
                slider,
              ]),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              SizedBox(width: 124, child: Text(label)),
              Expanded(child: slider),
              SizedBox(width: 48, child: valueLabel),
            ]),
          );
        },
      );
}

class _TypographyPreview extends StatelessWidget {
  const _TypographyPreview({
    required this.typography,
    required this.label,
  });

  final PdfTypography typography;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    double preview(double value) => value.clamp(9, 24).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(
            'serendipity',
            style: TextStyle(
              fontSize: preview(typography.word),
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'US /ˌserənˈdɪpəti/  ·  UK /ˌserənˈdɪpɪti/',
            style: TextStyle(fontSize: preview(typography.phonetic)),
          ),
          const SizedBox(height: 5),
          Text(
            'The pleasant discovery of something unexpected.',
            style: TextStyle(fontSize: preview(typography.definition)),
          ),
          Text(
            '意外发现美好事物的幸运。',
            style: TextStyle(
              fontSize: preview(typography.definition),
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
