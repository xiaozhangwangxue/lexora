import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import '../l10n/app_localizations.dart';
import '../models/word_entry.dart';
import '../services/generation_progress.dart';
import '../services/document_export_service.dart';
import '../services/haptic_service.dart';
import '../services/history_service.dart';
import '../services/notification_service.dart';
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

class _ShellScreenState extends State<ShellScreen> with WidgetsBindingObserver {
  static const _onboardingKey = 'lexora.onboarding.completed.v1';
  static const _releaseNotesKey = 'lexora.release-notes.seen.$appVersion';
  final _settingsService = PdfSettingsService();
  final _pageController = PageController();
  final _generationProgress = GenerationProgress();
  final _wordService = WordService();
  final _documentService = DocumentExportService();
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
  bool? _desktopSidebarExpandedPreference;
  Completer<void>? _resumeCompleter;

  bool get _isAndroid =>
      Platform.isAndroid ||
      debugDefaultTargetPlatformOverride == TargetPlatform.android;

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
    if (_resumeCompleter?.isCompleted == false) _resumeCompleter!.complete();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isAndroid) {
      if (state == AppLifecycleState.resumed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_synchronizeAndroidAfterResume());
        });
      } else {
        _dismissAndroidKeyboard();
      }
    }
    final active = state == AppLifecycleState.resumed;
    if (active && _resumeCompleter?.isCompleted == false) {
      _resumeCompleter!.complete();
      _resumeCompleter = null;
    }
    if (_appIsActive != active && mounted) {
      setState(() => _appIsActive = active);
    }
  }

  void _dismissAndroidKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }

  Future<void> _synchronizeAndroidAfterResume() async {
    _dismissAndroidKeyboard();
    // Android can restore the Flutter surface before dispatching the final IME
    // inset. Repeating the hide request on the next frame prevents a stale
    // keyboard height from surviving the trip through the launcher.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    _dismissAndroidKeyboard();
    if (_pageController.hasClients) {
      // A PageView ballistic animation can be suspended while Android parks
      // the Flutter surface. Jumping to the selected page on resume releases
      // the stale gesture/animation state that otherwise makes the whole UI
      // appear frozen after a long idle period.
      _pageController.jumpToPage(_index);
    }
    setState(() {});
  }

  Future<void> _waitUntilAppIsActive() async {
    if (_appIsActive || !mounted) return;
    _resumeCompleter ??= Completer<void>();
    await _resumeCompleter!.future;
  }

  Future<void> _loadInitialState() async {
    final preferences = await SharedPreferences.getInstance();
    final settings = await _settingsService.load();
    if (mounted) {
      setState(() {
        _onboardingCompleted = preferences.getBool(_onboardingKey) ?? false;
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(note)),
                  ],
                ),
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
    _dismissAndroidHomeKeyboard(value);
    if (_isAndroid && animate && _pageController.hasClients) {
      setState(() => _index = value);
      _pageController.animateToPage(
        value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
      );
    } else {
      setState(() => _index = value);
      if (_isAndroid && _pageController.hasClients) {
        _pageController.jumpToPage(value);
      }
    }
  }

  void _dismissAndroidHomeKeyboard(int destination) {
    if (!_isAndroid || _index != 0 || destination == 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
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
          await _showLookupResults(
            result.failures,
            result.fuzzyMatches,
            generated: false,
          );
        }
        return;
      }

      _generationProgress.typesetting();
      final book = await _documentService.create(
        result.entries,
        format: settings.format,
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
        // Never create a modal route while Android has parked the Flutter
        // surface. A background dialog can leave a stale modal barrier after
        // long idle periods and make the resumed UI appear completely frozen.
        await _waitUntilAppIsActive();
      }
      if (mounted) {
        await _showGenerationComplete(
          book,
          failures: result.failures,
          fuzzyMatches: result.fuzzyMatches,
        );
      }
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
    await Share.shareXFiles([
      XFile(book.path, mimeType: book.format.mimeType),
    ], subject: strings.vocabularyBook);
  }

  Future<void> _openBook(GeneratedBook book) async {
    const recordsPage = 1;
    _selectPage(recordsPage, animate: false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PdfReaderScreen(book: book)),
    );
    if (mounted) _selectPage(recordsPage, animate: false);
  }

  Future<void> _showGenerationComplete(
    GeneratedBook book, {
    List<LookupFailure> failures = const [],
    List<FuzzyMatch> fuzzyMatches = const [],
  }) async {
    final strings = AppLocalizations.of(context);
    final itemCount = failures.length + fuzzyMatches.length;
    final listHeight = (itemCount * 48.0).clamp(64.0, 190.0).toDouble();
    final action = await showDialog<_GenerationCompleteAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded),
        title: Text(strings.generationCompleted),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.generationReadyBody),
              if (itemCount > 0) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  strings.lookupResultsTitle,
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  fuzzyMatches.isNotEmpty
                      ? strings.lookupResultsBody(failures.isNotEmpty)
                      : strings.skippedItemsBody,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: listHeight,
                  child: Scrollbar(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: itemCount,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (context, index) => _lookupResultRow(
                        context,
                        strings,
                        failures,
                        fuzzyMatches,
                        index,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(_GenerationCompleteAction.ignore),
                      child: Text(strings.stayHere),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(_GenerationCompleteAction.share),
                      child: Text(strings.shareNow),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(
                        dialogContext,
                      ).pop(_GenerationCompleteAction.open),
                      child: Text(strings.viewGenerated),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

  Future<void> _showLookupResults(
    List<LookupFailure> failures,
    List<FuzzyMatch> fuzzyMatches, {
    required bool generated,
  }) async {
    final strings = AppLocalizations.of(context);
    final itemCount = failures.length + fuzzyMatches.length;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.manage_search_rounded),
        title: Text(
          fuzzyMatches.isEmpty
              ? strings.skippedItemsTitle
              : strings.lookupResultsTitle,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fuzzyMatches.isNotEmpty
                    ? strings.lookupResultsBody(failures.isNotEmpty)
                    : (generated
                          ? strings.skippedItemsBody
                          : strings.noItemsGenerated),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) => _lookupResultRow(
                    context,
                    strings,
                    failures,
                    fuzzyMatches,
                    index,
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

  Widget _lookupResultRow(
    BuildContext context,
    AppLocalizations strings,
    List<LookupFailure> failures,
    List<FuzzyMatch> fuzzyMatches,
    int index,
  ) {
    final isFailure = index < failures.length;
    final text = isFailure
        ? failures[index].term
        : strings.fuzzyMatchedTerm(
            fuzzyMatches[index - failures.length].term,
            fuzzyMatches[index - failures.length].matchedTerm,
          );
    final color = isFailure
        ? Theme.of(context).colorScheme.error
        : Colors.amber.shade700;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.close_rounded,
            size: 17,
            color: color,
            semanticLabel: isFailure
                ? strings.lookupFailed
                : strings.fuzzyMatched,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingCompleted == null || _settings == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_onboardingCompleted!) {
      return OnboardingScreen(onFinished: _finishOnboarding);
    }

    final strings = AppLocalizations.of(context);
    final windowWidth = MediaQuery.sizeOf(context).width;
    final wide = _isAndroid ? windowWidth >= 680 : windowWidth >= 520;
    final autoExpandedNavigation = windowWidth >= 820;
    final expandedNavigation =
        autoExpandedNavigation && (_desktopSidebarExpandedPreference ?? true);
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
    final pageContent = _isAndroid
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
                _dismissAndroidHomeKeyboard(value);
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
        if (_isAndroid)
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: .58),
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
      return Scaffold(
        // The generated Windows runner has an opaque light window. Using a
        // transparent Scaffold here exposes the runner's black clear color
        // around desktop pages, especially during the first frame.
        backgroundColor: Platform.isMacOS
            ? Colors.transparent
            : Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: !_isAndroid,
        body: Row(
          children: [
            AnimatedContainer(
              key: const Key('desktop-sidebar'),
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeInOutCubicEmphasized,
              width: expandedNavigation ? 220 : 76,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: _DesktopSidebar(
                selectedIndex: _index,
                destinations: destinations,
                onSelected: _selectPage,
                expanded: expandedNavigation,
                isMacOS: Platform.isMacOS,
                onToggle: () => setState(() {
                  _desktopSidebarExpandedPreference = !expandedNavigation;
                }),
              ),
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: .45),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      // The Android IME inset can remain stale for one frame after returning
      // from the launcher. Keeping the app shell at full height prevents that
      // stale value from reserving a large blank area. Dialogs that need to sit
      // above the live keyboard handle viewInsets locally.
      resizeToAvoidBottomInset: !_isAndroid,
      body: body,
      extendBody: _isAndroid,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: NavigationBar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: _isAndroid ? .76 : 1),
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
  SpringDescription get spring =>
      const SpringDescription(mass: .9, stiffness: 260, damping: 31);
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    required this.expanded,
    required this.isMacOS,
    required this.onToggle,
  });

  final int selectedIndex;
  final List<NavigationRailDestination> destinations;
  final ValueChanged<int> onSelected;
  final bool expanded;
  final bool isMacOS;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        // AnimatedContainer changes the constraint on every frame. Waiting
        // until there is enough real space before revealing labels prevents
        // text from overflowing during expansion, while hiding it early makes
        // the collapse feel continuous instead of snapping at the end.
        final showLabels = expanded && constraints.maxWidth >= 180;
        final content = SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 18),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/icon/lexora-icon.png',
                          width: 30,
                          height: 30,
                        ),
                      ),
                      if (showLabels) ...[
                        const SizedBox(width: 10),
                        Text(
                          'Lexora',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                for (var index = 0; index < destinations.length; index++) ...[
                  _DesktopSidebarItem(
                    selected: selectedIndex == index,
                    icon: selectedIndex == index
                        ? destinations[index].selectedIcon
                        : destinations[index].icon,
                    label: destinations[index].label,
                    onTap: () => onSelected(index),
                    expanded: showLabels,
                  ),
                  const SizedBox(height: 4),
                ],
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('desktop-sidebar-toggle'),
                        tooltip: expanded
                            ? 'Collapse sidebar'
                            : 'Expand sidebar',
                        onPressed: onToggle,
                        icon: AnimatedRotation(
                          turns: expanded ? 0 : .5,
                          duration: const Duration(milliseconds: 460),
                          curve: Curves.easeInOutCubicEmphasized,
                          child: const Icon(Icons.menu_rounded),
                        ),
                      ),
                      if (showLabels)
                        Expanded(
                          child: Text(
                            'Lexora $appVersion',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        if (!isMacOS) return content;
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: ColoredBox(
              color: theme.colorScheme.surface.withValues(alpha: .46),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class _DesktopSidebarItem extends StatelessWidget {
  const _DesktopSidebarItem({
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
    final item = Material(
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
            child: Row(
              children: [
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
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      child: label,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (expanded) return item;
    final message = label is Text ? (label as Text).data : null;
    return Tooltip(message: message ?? '', child: item);
  }
}
