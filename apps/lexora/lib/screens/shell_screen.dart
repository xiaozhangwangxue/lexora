import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  static const _onboardingKey = 'lexora.onboarding.completed.v1';
  int _index = 0;
  int _historyRevision = 0;
  bool? _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _loadOnboarding();
  }

  Future<void> _loadOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _onboardingCompleted = preferences.getBool(_onboardingKey) ?? false);
    }
  }

  Future<void> _finishOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingKey, true);
    if (mounted) setState(() => _onboardingCompleted = true);
  }

  void _showHistory() {
    setState(() {
      _historyRevision++;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingCompleted == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_onboardingCompleted!) return OnboardingScreen(onFinished: _finishOnboarding);

    final strings = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final body = IndexedStack(
      index: _index,
      children: [
        HomeScreen(onGenerated: _showHistory),
        HistoryScreen(key: ValueKey(_historyRevision)),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(children: [
          SafeArea(
            child: NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/icon/lexora-icon.png', width: 42, height: 42),
                ),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.auto_stories_outlined),
                  selectedIcon: const Icon(Icons.auto_stories),
                  label: Text(strings.words),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.history_outlined),
                  selectedIcon: const Icon(Icons.history),
                  label: Text(strings.history),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
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
          NavigationDestination(icon: const Icon(Icons.auto_stories_outlined), label: strings.words),
          NavigationDestination(icon: const Icon(Icons.history_outlined), label: strings.history),
        ],
      ),
    );
  }
}
