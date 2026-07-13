import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import '../l10n/app_localizations.dart';
import '../models/word_entry.dart';
import '../services/generation_progress.dart';
import '../services/haptic_service.dart';
import '../services/history_service.dart';
import '../services/notification_service.dart';
import '../services/pdf_service.dart';
import '../services/pdf_settings_service.dart';
import '../services/word_service.dart';
import '../widgets/github_button.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'pdf_customization_dialog.dart';
import 'pdf_reader_screen.dart';
import 'settings_screen.dart';
import 'word_history_screen.dart';

enum _GenerationCompleteAction { ignore, open, share }

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with WidgetsBindingObserver {
  static const _onboardingKey = 'lexora.onboarding.completed.v1';
  static const _releaseNotesKey = 'lexora.release-notes.seen.$appVersion';
  final _settingsService = PdfSettingsService();
  final _pageController = PageController();
  final _generationProgress = GenerationProgress();
  final _wordService = WordService();
  final _pdfService = PdfService();
  final _historyService = HistoryService();
  final _haptics = const HapticService();
  final _notifications = NotificationService.instance;
  int _index = 0;
  int _recordsRevision = 0;
  int _wordHistoryRevision = 0;
  bool _appIsActive = true;
  bool? _onboardingCompleted;
  PdfSettings? _settings;
  bool _releaseNotesPending = false;
  bool _releaseNotesShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _generationProgress.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appIsActive != active && mounted) {
      setState(() => _appIsActive = active);
    }
  }

  Future<void> _loadInitialState() async {
    final preferences = await SharedPreferences.getInstance();
    final settings = await _settingsService.load();
    if (mounted) {
      setState(() {
        _onboardingCompleted =
            preferences.getBool(_onboardingKey) ?? false;
        _settings = settings;
        _releaseNotesPending =
            !(preferences.getBool(_releaseNotesKey) ?? false);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _onboardingCompleted == true) {
          unawaited(_showReleaseNotesIfNeeded());
        }
      });
    }
  }

  Future<void> _finishOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingKey, true);
    if (mounted) {
      setState(() => _onboardingCompleted = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showReleaseNotesIfNeeded());
      });
    }
  }

  Future<void> _showReleaseNotesIfNeeded() async {
    if (!_releaseNotesPending || _releaseNotesShowing || !mounted) return;
    _releaseNotesShowing = true;
    final strings = AppLocalizations.of(context);
    final notes = strings.isZh ? releaseNotesZh : releaseNotesEn;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.auto_awesome_rounded),
        title: Text('Lexora $appVersion · ${strings.whatsNew}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final note in notes) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(note)),
                ]),
                const SizedBox(height: 9),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.continueLabel),
          ),
        ],
      ),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_releaseNotesKey, true);
    if (mounted) {
      setState(() => _releaseNotesPending = false);
    }
    _releaseNotesShowing = false;
  }

  void _selectPage(int value, {bool animate = true}) {
    if (value == _index) return;
    if (Platform.isAndroid && animate && _pageController.hasClients) {
      setState(() => _index = value);
      _pageController.animateToPage(
        value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
      );
    } else {
      setState(() => _index = value);
      if (Platform.isAndroid && _pageController.hasClients) {
        _pageController.jumpToPage(value);
      }
    }
  }

  void _updateSettings(PdfSettings settings) {
    setState(() => _settings = settings);
    unawaited(_settingsService.save(settings));
  }

  Future<void> _showPdfCustomizer() async {
    final updated = await showPdfCustomizationDialog(context, _settings!);
    if (updated != null && mounted) _updateSettings(updated);
  }

  void _startGeneration(List<String> terms) {
    if (_generationProgress.isRunning) return;
    unawaited(_runGeneration(terms));
  }

  Future<void> _runGeneration(List<String> terms) async {
    final strings = AppLocalizations.of(context);
    final settings = _settings!;
    _generationProgress.start(terms.length);
    if (mounted) setState(() {});
    unawaited(_haptics.generationStarted());
    unawaited(_notifications.requestPermission());
    try {
      final result = await _wordService.lookupAll(
        terms,
        exampleCount: settings.exampleAmount.count,
        maxConcurrency: 4,
        onProgress: _generationProgress.updateLookup,
      );
      if (result.entries.isEmpty) {
        _generationProgress.fail(strings.noItemsGenerated);
        if (mounted) setState(() {});
        if (mounted && result.failures.isNotEmpty) {
          await _showSkippedItems(result.failures, generated: false);
        }
        return;
      }

      _generationProgress.typesetting();
      final book = await _pdfService.create(
        result.entries,
        fontSize: settings.fontSize,
        typography: settings.typography,
      );
      await _historyService.save(book);
      await _historyService.recordWords(result.entries, book.createdAt);
      _generationProgress.complete();
      await _haptics.generationCompleted();
      if (!mounted) return;
      setState(() {
        _recordsRevision++;
        _wordHistoryRevision++;
      });
      if (!_appIsActive) {
        await _notifications.showGenerationComplete(
          entryCount: result.entries.length,
          isZh: strings.isZh,
        );
      }
      if (mounted && result.failures.isNotEmpty) {
        await _showSkippedItems(result.failures, generated: true);
      }
      if (mounted) await _showGenerationComplete(book);
    } catch (error) {
      _generationProgress.fail(error.toString());
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.generationError(error.toString()))),
        );
      }
    }
  }

  Future<void> _shareBook(GeneratedBook book) async {
    final strings = AppLocalizations.of(context);
    await Share.shareXFiles(
      [XFile(book.path, mimeType: 'application/pdf')],
      subject: strings.vocabularyBook,
    );
  }

  Future<void> _openBook(GeneratedBook book) async {
    const recordsPage = 1;
    _selectPage(recordsPage, animate: false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PdfReaderScreen(book: book)),
    );
    if (mounted) _selectPage(recordsPage, animate: false);
  }

  Future<void> _showGenerationComplete(GeneratedBook book) async {
    final strings = AppLocalizations.of(context);
    final action = await showDialog<_GenerationCompleteAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded),
        title: Text(strings.generationCompleted),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(strings.generationReadyBody),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext)
                      .pop(_GenerationCompleteAction.ignore),
                  child: Text(strings.stayHere),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext)
                      .pop(_GenerationCompleteAction.share),
                  child: Text(strings.shareNow),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext)
                      .pop(_GenerationCompleteAction.open),
                  child: Text(strings.viewGenerated),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    if (action == _GenerationCompleteAction.open) {
      await _openBook(book);
    } else if (action == _GenerationCompleteAction.share) {
      await _shareBook(book);
    }
  }

  Future<void> _showSkippedItems(
    List<LookupFailure> failures, {
    required bool generated,
  }) async {
    final strings = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.manage_search_rounded),
        title: Text(strings.skippedItemsTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(generated
                  ? strings.skippedItemsBody
                  : strings.noItemsGenerated),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: failures.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.close_rounded, size: 17),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          failures[index].term,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.gotIt),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingCompleted == null || _settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_onboardingCompleted!) {
      return OnboardingScreen(onFinished: _finishOnboarding);
    }

    final strings = AppLocalizations.of(context);
    final windowWidth = MediaQuery.sizeOf(context).width;
    final wide = Platform.isAndroid
        ? windowWidth >= 680
        : windowWidth >= 520;
    final expandedNavigation = windowWidth >= 800;
    final showGitHub = _index == 0;
    final pages = [
      HomeScreen(
        settings: _settings!,
        generationRunning: _generationProgress.isRunning,
        onStartGeneration: _startGeneration,
        onCustomizePdf: _showPdfCustomizer,
      ),
      HistoryScreen(
        key: ValueKey(_recordsRevision),
        progress: _generationProgress,
        onOpenBook: _openBook,
      ),
      WordHistoryScreen(
        key: ValueKey(_wordHistoryRevision),
        generationRunning: _generationProgress.isRunning,
        onRegenerate: _startGeneration,
        onCustomizePdf: _showPdfCustomizer,
      ),
      SettingsScreen(
        settings: _settings!,
        onChanged: _updateSettings,
        onOpenTypography: _showPdfCustomizer,
      ),
    ];
    final pageContent = Platform.isAndroid
        ? ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: PageView(
              controller: _pageController,
              physics: const _LexoraPagePhysics(
                parent: ClampingScrollPhysics(),
              ),
              clipBehavior: Clip.hardEdge,
              allowImplicitScrolling: true,
              onPageChanged: (value) {
                if (_index != value) setState(() => _index = value);
              },
              children: [
                for (final page in pages)
                  RepaintBoundary(
                    child: ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: page,
                    ),
                  ),
              ],
            ),
          )
        : IndexedStack(index: _index, children: pages);
    final body = Stack(
      children: [
        pageContent,
        if (Platform.isAndroid)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top + 14,
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: ColoredBox(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: .58),
                  ),
                ),
              ),
            ),
          ),
        if (showGitHub)
          const Positioned(
            top: 16,
            right: 20,
            child: SafeArea(child: GitHubButton()),
          ),
      ],
    );

    final destinations = [
      NavigationRailDestination(
        icon: const Icon(Icons.auto_stories_outlined),
        selectedIcon: const Icon(Icons.auto_stories_rounded),
        label: Text(strings.words),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long_rounded),
        label: Text(strings.generationRecords),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.history_outlined),
        selectedIcon: const Icon(Icons.history_rounded),
        label: Text(strings.history),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings_rounded),
        label: Text(strings.settings),
      ),
    ];

    if (wide) {
      if (Platform.isMacOS) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(children: [
            SizedBox(
              width: expandedNavigation ? 220 : 76,
              child: _MacSidebar(
                selectedIndex: _index,
                destinations: destinations,
                onSelected: _selectPage,
                expanded: expandedNavigation,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: .6,
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: .32),
            ),
            Expanded(child: body),
          ]),
        );
      }
      return Scaffold(
        // The generated Windows runner has an opaque light window. Using a
        // transparent Scaffold here exposes the runner's black clear color
        // around desktop pages, especially during the first frame.
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(children: [
          SafeArea(
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: _index,
              onDestinationSelected: _selectPage,
              labelType: expandedNavigation
                  ? NavigationRailLabelType.all
                  : NavigationRailLabelType.none,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icon/lexora-icon.png',
                    width: 42,
                    height: 42,
                  ),
                ),
              ),
              destinations: destinations,
            ),
          ),
          VerticalDivider(
            width: 1,
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: .45),
          ),
          Expanded(child: body),
        ]),
      );
    }

    return Scaffold(
      body: body,
      extendBody: Platform.isAndroid,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: NavigationBar(
            backgroundColor: Theme.of(context)
                .colorScheme
                .surface
                .withValues(alpha: Platform.isAndroid ? .76 : 1),
            shadowColor: Colors.transparent,
            selectedIndex: _index,
            onDestinationSelected: _selectPage,
            destinations: [
          NavigationDestination(
            icon: destinations[0].icon,
            selectedIcon: destinations[0].selectedIcon,
            label: strings.words,
          ),
          NavigationDestination(
            icon: destinations[1].icon,
            selectedIcon: destinations[1].selectedIcon,
            label: strings.generationRecords,
          ),
          NavigationDestination(
            icon: destinations[2].icon,
            selectedIcon: destinations[2].selectedIcon,
            label: strings.history,
          ),
          NavigationDestination(
            icon: destinations[3].icon,
            selectedIcon: destinations[3].selectedIcon,
            label: strings.settings,
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LexoraPagePhysics extends PageScrollPhysics {
  const _LexoraPagePhysics({super.parent});

  @override
  _LexoraPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _LexoraPagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => const SpringDescription(
        mass: .9,
        stiffness: 260,
        damping: 31,
      );
}

class _MacSidebar extends StatelessWidget {
  const _MacSidebar({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    required this.expanded,
  });

  final int selectedIndex;
  final List<NavigationRailDestination> destinations;
  final ValueChanged<int> onSelected;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 18),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/icon/lexora-icon.png',
                  width: 30,
                  height: 30,
                ),
              ),
              if (expanded) ...[
                const SizedBox(width: 10),
                Text(
                  'Lexora',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                  ),
                ),
              ],
            ]),
          ),
          for (var index = 0; index < destinations.length; index++) ...[
            _MacSidebarItem(
              selected: selectedIndex == index,
              icon: selectedIndex == index
                  ? destinations[index].selectedIcon
                  : destinations[index].icon,
              label: destinations[index].label,
              onTap: () => onSelected(index),
              expanded: expanded,
            ),
            const SizedBox(height: 4),
          ],
          const Spacer(),
          if (expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Lexora $appVersion',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _MacSidebarItem extends StatelessWidget {
  const _MacSidebarItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.expanded,
  });

  final bool selected;
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: .13)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(children: [
              IconTheme(
                data: IconThemeData(
                  size: 20,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                child: icon,
              ),
              if (expanded) ...[
                const SizedBox(width: 11),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    child: label,
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
