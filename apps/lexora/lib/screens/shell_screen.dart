import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/word_entry.dart';
import '../services/pdf_settings_service.dart';
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

  void _showGenerated(GeneratedBook _) {
    setState(() {
      _recordsRevision++;
      _wordHistoryRevision++;
      _index = 1;
    });
  }

  void _updateSettings(PdfSettings settings) {
    setState(() => _settings = settings);
    unawaited(_settingsService.save(settings));
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    if (!Platform.isAndroid) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 420) return;
    final next = velocity < 0 ? _index + 1 : _index - 1;
    if (next >= 0 && next < 4) setState(() => _index = next);
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
        appIsActive: _appIsActive,
        onGenerated: _showGenerated,
        onOpenSettings: () => setState(() => _index = 3),
      ),
      HistoryScreen(key: ValueKey(_recordsRevision)),
      WordHistoryScreen(key: ValueKey(_wordHistoryRevision)),
      SettingsScreen(
        settings: _settings!,
        onChanged: _updateSettings,
      ),
    ];
    final body = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _handleHorizontalSwipe,
      child: Stack(
        children: [
          IndexedStack(index: _index, children: pages),
          if (showGitHub)
            const Positioned(
              top: 16,
              right: 20,
              child: SafeArea(child: GitHubButton()),
            ),
        ],
      ),
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
        backgroundColor: Colors.transparent,
        body: Row(children: [
          SafeArea(
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
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
        onDestinationSelected: (value) => setState(() => _index = value),
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
