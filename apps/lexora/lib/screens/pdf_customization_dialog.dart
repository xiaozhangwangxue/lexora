import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/word_entry.dart';
import '../services/pdf_service.dart';
import '../services/pdf_settings_service.dart';

Future<PdfSettings?> showPdfCustomizationDialog(
  BuildContext context,
  PdfSettings settings,
) => showGeneralDialog<PdfSettings>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.black.withValues(alpha: .24),
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 210),
  pageBuilder: (_, __, ___) => _PdfCustomizationDialog(initial: settings),
  transitionBuilder: (context, animation, secondaryAnimation, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: const Cubic(.23, 1, .32, 1),
      reverseCurve: const Cubic(.77, 0, .175, 1),
    );
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: ScaleTransition(
        scale: Tween<double>(begin: .985, end: 1).animate(curved),
        child: RepaintBoundary(child: child),
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
  late final ValueNotifier<PdfTypography> _typography = ValueNotifier(
    widget.initial.typography,
  );
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _typography.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    // Keep the sheet below the status bar/notch and above the keyboard.  The
    // dialog is scrollable, so on a short phone it becomes a compact sheet
    // instead of covering system UI or making the action buttons unreachable.
    final maxHeight =
        (media.size.height -
                media.viewPadding.top -
                media.viewPadding.bottom -
                media.viewInsets.bottom -
                24)
            .clamp(280.0, double.infinity)
            .toDouble();
    final surfaceColor = theme.colorScheme.surface;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 660, maxHeight: maxHeight),
              child: RepaintBoundary(
                child: Material(
                  color: surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: .48,
                      ),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 16, 14),
                        child: Row(
                          children: [
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
                          ],
                        ),
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
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                20,
                                34,
                                20,
                              ),
                              child: Listener(
                                behavior: HitTestBehavior.translucent,
                                onPointerSignal: _handlePointerSignal,
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
                                        _formatChip(
                                          BookFormat.pdf,
                                          'PDF',
                                          Icons.picture_as_pdf_outlined,
                                        ),
                                        _formatChip(
                                          BookFormat.epub,
                                          'EPUB',
                                          Icons.menu_book_outlined,
                                        ),
                                        _formatChip(
                                          BookFormat.docx,
                                          'DOCX',
                                          Icons.description_outlined,
                                        ),
                                        _formatChip(
                                          BookFormat.images,
                                          strings.pageImages,
                                          Icons.photo_library_outlined,
                                        ),
                                        _formatChip(
                                          BookFormat.longImage,
                                          strings.longImage,
                                          Icons.panorama_vertical_outlined,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
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
                                        selected: {_settings.pageSize},
                                        onSelectionChanged: (value) => setState(
                                          () => _settings = _settings.copyWith(
                                            pageSize: value.first,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        8,
                                        8,
                                        8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              theme.colorScheme.outlineVariant,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              strings.smartReorder,
                                              style: theme.textTheme.labelLarge,
                                            ),
                                          ),
                                          Switch(
                                            value: _settings.smartReorder,
                                            onChanged: (value) => setState(
                                              () => _settings = _settings
                                                  .copyWith(
                                                    smartReorder: value,
                                                  ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: strings.smartReorderHelp,
                                            onPressed: _showSmartReorderHelp,
                                            icon: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: const BoxDecoration(
                                                color: Colors.black,
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                '?',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
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
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
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
                                            label: FittedBox(
                                              child: Text(strings.small),
                                            ),
                                          ),
                                          ButtonSegment(
                                            value: PdfFontSize.medium,
                                            label: FittedBox(
                                              child: Text(strings.medium),
                                            ),
                                          ),
                                          ButtonSegment(
                                            value: PdfFontSize.large,
                                            label: FittedBox(
                                              child: Text(strings.large),
                                            ),
                                          ),
                                        ],
                                        selected: {_settings.fontSize},
                                        onSelectionChanged: (value) =>
                                            _applyPreset(value.first),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    ValueListenableBuilder<PdfTypography>(
                                      valueListenable: _typography,
                                      builder: (context, typography, _) =>
                                          RepaintBoundary(
                                            child: _TypographyPreview(
                                              typography: typography,
                                              label: strings.typographyPreview,
                                            ),
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    _FontSlider(
                                      label: strings.wordTitleFont,
                                      value: _settings.typography.word,
                                      min: 6,
                                      max: 30,
                                      onChanged: (value) => _updateTypography(
                                        _settings.typography.copyWith(
                                          word: value,
                                        ),
                                      ),
                                    ),
                                    _FontSlider(
                                      label: strings.phoneticFont,
                                      value: _settings.typography.phonetic,
                                      min: 6,
                                      max: 18,
                                      onChanged: (value) => _updateTypography(
                                        _settings.typography.copyWith(
                                          phonetic: value,
                                        ),
                                      ),
                                    ),
                                    _FontSlider(
                                      label: strings.definitionFont,
                                      value: _settings.typography.definition,
                                      min: 6,
                                      max: 18,
                                      onChanged: (value) => _updateTypography(
                                        _settings.typography.copyWith(
                                          definition: value,
                                        ),
                                      ),
                                    ),
                                    _FontSlider(
                                      label: strings.relatedFont,
                                      value: _settings.typography.related,
                                      min: 6,
                                      max: 16,
                                      onChanged: (value) => _updateTypography(
                                        _settings.typography.copyWith(
                                          related: value,
                                        ),
                                      ),
                                    ),
                                    _FontSlider(
                                      label: strings.exampleFont,
                                      value: _settings.typography.example,
                                      min: 6,
                                      max: 16,
                                      onChanged: (value) => _updateTypography(
                                        _settings.typography.copyWith(
                                          example: value,
                                        ),
                                      ),
                                    ),
                                    _FontSlider(
                                      label: strings.phraseFont,
                                      value: _settings.typography.phrase,
                                      min: 6,
                                      max: 16,
                                      onChanged: (value) => _updateTypography(
                                        _settings.typography.copyWith(
                                          phrase: value,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      strings.examples,
                                      style: theme.textTheme.labelLarge,
                                    ),
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
                                              child: Text(
                                                strings.upToThreeExamples,
                                              ),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateTypography(PdfTypography typography) {
    _settings = _settings.copyWith(typography: typography);
    _typography.value = typography;
  }

  void _applyPreset(PdfFontSize preset) {
    setState(() => _settings = _settings.applyPreset(preset));
    _typography.value = _settings.typography;
  }

  Widget _formatChip(BookFormat format, String label, IconData icon) =>
      ChoiceChip(
        selected: _settings.format == format,
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onSelected: (_) =>
            setState(() => _settings = _settings.copyWith(format: format)),
      );

  Future<void> _showSmartReorderHelp() => showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final strings = AppLocalizations.of(dialogContext);
      return AlertDialog(
        icon: const Icon(Icons.auto_awesome_rounded),
        title: Text(strings.smartReorder),
        content: Text(strings.smartReorderHint),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.gotIt),
          ),
        ],
      );
    },
  );

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

class _FontSlider extends StatefulWidget {
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
  State<_FontSlider> createState() => _FontSliderState();
}

class _FontSliderState extends State<_FontSlider> {
  late double _value = widget.value;

  @override
  void didUpdateWidget(covariant _FontSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _value = widget.value;
  }

  void _change(double value) {
    setState(() => _value = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final slider = Slider(
        value: _value.clamp(widget.min, widget.max).toDouble(),
        min: widget.min,
        max: widget.max,
        divisions: ((widget.max - widget.min) * 2).round(),
        onChanged: _change,
      );
      final valueLabel = Text(
        '${_value.toStringAsFixed(1)} pt',
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.labelMedium,
      );
      if (constraints.maxWidth < 430) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(widget.label)),
                  valueLabel,
                ],
              ),
              slider,
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          children: [
            SizedBox(width: 124, child: Text(widget.label)),
            Expanded(child: slider),
            SizedBox(width: 48, child: valueLabel),
          ],
        ),
      );
    },
  );
}

class _TypographyPreview extends StatelessWidget {
  const _TypographyPreview({required this.typography, required this.label});

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
