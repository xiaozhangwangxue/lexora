import 'package:flutter/material.dart';

import '../services/history_service.dart';
import 'search_history_screen.dart';
import 'word_history_screen.dart';

class HistoryHubScreen extends StatefulWidget {
  const HistoryHubScreen({
    super.key,
    required this.generationRunning,
    required this.onRegenerate,
    required this.onCustomizePdf,
    required this.onSearch,
    this.historyService,
  });

  final bool generationRunning;
  final ValueChanged<List<String>> onRegenerate;
  final Future<void> Function() onCustomizePdf;
  final ValueChanged<String> onSearch;
  final HistoryService? historyService;

  @override
  State<HistoryHubScreen> createState() => _HistoryHubScreenState();
}

class _HistoryHubScreenState extends State<HistoryHubScreen> {
  int _tab = 0;

  bool get _isZh =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isZh ? '历史' : 'History',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      icon: const Icon(Icons.auto_stories_outlined),
                      label: Text(_isZh ? '生成历史' : 'Generated words'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: const Icon(Icons.manage_search_rounded),
                      label: Text(_isZh ? '搜索历史' : 'Search history'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (value) =>
                      setState(() => _tab = value.first),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      WordHistoryScreen(
                        embedded: true,
                        generationRunning: widget.generationRunning,
                        onRegenerate: widget.onRegenerate,
                        onCustomizePdf: widget.onCustomizePdf,
                        historyService: widget.historyService,
                      ),
                      SearchHistoryScreen(onSearch: widget.onSearch),
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
