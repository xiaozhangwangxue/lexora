import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
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
import 'settings_screen.dart';
import 'word_history_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with WidgetsBindingObserver {
  static const _onboardingKey = 'lexora.onboarding.completed.v1';
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
      });
    }
  }

  Future<void> _finishOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingKey, true);
    if (mounted) setState(() => _onboardingCompleted = true);
  }

  void _selectPage(int value, {bool animate = true}) {
    if (value == _index) return;
    if (Platform.isAndroid && animate && _pageController.hasClients) {
      _pageController.animateToPage(
        value,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
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

  void _startGeneration(List<String> terms) {
    if (_generationProgress.isRunning) return;
    _selectPage(1);
    unawaited(_runGeneration(terms));
  }

  Future<void> _runGeneration(List<String> terms) async {
    final strings = AppLocalizations.of(context);
    final settings = _settings!;
    _generationProgress.start(terms.length);
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
        if (mounted && result.failures.isNotEmpty) {
          await _showSkippedItems(result.failures, generated: false);
        }
        return;
      }

      _generationProgress.typesetting();
      final book = await _pdfService.create(
        result.entries,
        fontSize: settings.fontSize,
      );
      await _historyService.save(book);
      await _historyService.recordWords(result.entries, book.createdAt);
      _generationProgress.complete();
      await _haptics.generationCompleted();
      if (!mounted) return;
      setState(() {
        _recordsRevision++;
        _wordHistoryRevision++;
        _index = 1;
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
    } catch (error) {
      _generationProgress.fail(error.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.generationError(error.toString()))),
        );
      }
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
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final showGitHub = _index == 0 || _index == 3;
    final pages = [
      HomeScreen(
        settings: _settings!,
        generationRunning: _generationProgress.isRunning,
        onStartGeneration: _startGeneration,
        onOpenSettings: () => _selectPage(3),
      ),
      HistoryScreen(
        key: ValueKey(_recordsRevision),
        progress: _generationProgress,
      ),
      WordHistoryScreen(key: ValueKey(_wordHistoryRevision)),
      SettingsScreen(
        settings: _settings!,
        onChanged: _updateSettings,
      ),
    ];
    final pageContent = Platform.isAndroid
        ? PageView(
            controller: _pageController,
            physics: const _LexoraPagePhysics(),
            onPageChanged: (value) {
              if (_index != value) setState(() => _index = value);
            },
            children: pages,
          )
        : IndexedStack(index: _index, children: pages);
    final body = Stack(
      children: [
        pageContent,
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
              width: 220,
              child: _MacSidebar(
                selectedIndex: _index,
                destinations: destinations,
                onSelected: _selectPage,
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
        backgroundColor: Colors.transparent,
        body: Row(children: [
          SafeArea(
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: _index,
              onDestinationSelected: _selectPage,
              labelType: NavigationRailLabelType.all,
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
      bottomNavigationBar: NavigationBar(
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
        mass: .82,
        stiffness: 185,
        damping: 24,
      );
}

class _MacSidebar extends StatelessWidget {
  const _MacSidebar({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<NavigationRailDestination> destinations;
  final ValueChanged<int> onSelected;

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
              const SizedBox(width: 10),
              Text(
                'Lexora',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.4,
                ),
              ),
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
            ),
            const SizedBox(height: 4),
          ],
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Lexora 0.4.0',
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
  });

  final bool selected;
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;

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
              const SizedBox(width: 11),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  child: label,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
