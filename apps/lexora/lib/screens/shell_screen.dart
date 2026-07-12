import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'home_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  int _historyRevision = 0;

  void _showHistory() {
    setState(() {
      _historyRevision++;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories),
                  label: Text('Words'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: Text('History'),
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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_stories_outlined), label: 'Words'),
          NavigationDestination(icon: Icon(Icons.history_outlined), label: 'History'),
        ],
      ),
    );
  }
}
