import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/beta_controller.dart';
import '../models/learning_models.dart';
import 'dashboard_page.dart';
import 'learning_settings_page.dart';
import 'library_page.dart';
import 'stats_page.dart';
import 'study_page.dart';

class BetaLearningScreen extends StatefulWidget {
  const BetaLearningScreen({super.key, this.active = true, this.controller});

  final bool active;
  final BetaController? controller;

  @override
  State<BetaLearningScreen> createState() => _BetaLearningScreenState();
}

class _BetaLearningScreenState extends State<BetaLearningScreen>
    with WidgetsBindingObserver {
  late final BetaController _controller = widget.controller ?? BetaController();
  int _index = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeIfNeeded();
  }

  @override
  void didUpdateWidget(covariant BetaLearningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _initializeIfNeeded();
  }

  void _initializeIfNeeded() {
    if (!widget.active || _initialized) return;
    _initialized = true;
    unawaited(_controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.refreshDueTasks());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      if (_controller.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_controller.error != null && _controller.data.words.isEmpty) {
        return _ErrorState(
          error: _controller.error!,
          onRetry: _controller.retry,
        );
      }
      final pages = [
        DashboardPage(controller: _controller, onOpenStudy: () => _select(1)),
        StudyPage(
          controller: _controller,
          focus: SessionFocus.newWords,
          title: '今日学习',
          onOpenReview: () => _select(2),
        ),
        StudyPage(
          controller: _controller,
          focus: SessionFocus.reviews,
          title: '今日复习',
        ),
        LibraryPage(controller: _controller),
        StatsPage(controller: _controller),
        LearningSettingsPage(controller: _controller),
      ];
      final width = MediaQuery.sizeOf(context).width;
      final showTopNavigation = width >= 720;
      final desktop = Platform.isMacOS && showTopNavigation;
      return Column(
        children: [
          _Header(
            selectedIndex: _index,
            onSelected: _select,
            showNavigation: showTopNavigation,
            desktop: desktop,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              switchInCurve: const Cubic(.2, .8, .2, 1),
              switchOutCurve: const Cubic(.4, 0, 1, 1),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(.012, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
            ),
          ),
          if (!showTopNavigation)
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard_rounded),
                  label: '首页',
                ),
                NavigationDestination(
                  icon: Icon(Icons.school_outlined),
                  selectedIcon: Icon(Icons.school_rounded),
                  label: '学习',
                ),
                NavigationDestination(
                  icon: Icon(Icons.replay_outlined),
                  selectedIcon: Icon(Icons.replay_rounded),
                  label: '复习',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book_rounded),
                  label: '词库',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights_rounded),
                  label: '统计',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune_rounded),
                  label: '设置',
                ),
              ],
            ),
        ],
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.selectedIndex,
    required this.onSelected,
    required this.showNavigation,
    required this.desktop,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool showNavigation;
  final bool desktop;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(24, desktop ? 42 : 18, 24, 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lexora 学习 Beta',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '面向大学英语四级的个人词汇学习系统',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 720)
                TextButton.icon(
                  onPressed: () => onSelected(3),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加单词'),
                ),
            ],
          ),
          if (showNavigation) ...[
            const SizedBox(height: 16),
            _DesktopTabs(selectedIndex: selectedIndex, onSelected: onSelected),
          ],
        ],
      ),
    ),
  );
}

class _DesktopTabs extends StatelessWidget {
  const _DesktopTabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    ('首页', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
    ('今日学习', Icons.school_outlined, Icons.school_rounded),
    ('今日复习', Icons.replay_outlined, Icons.replay_rounded),
    ('单词库', Icons.menu_book_outlined, Icons.menu_book_rounded),
    ('统计', Icons.insights_outlined, Icons.insights_rounded),
    ('学习设置', Icons.tune_outlined, Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var index = 0; index < _items.length; index++)
              Expanded(
                child: Semantics(
                  selected: selectedIndex == index,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelected(index),
                    child: AnimatedContainer(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 170),
                      curve: const Cubic(.2, .82, .2, 1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selectedIndex == index
                            ? Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selectedIndex == index
                                ? _items[index].$3
                                : _items[index].$2,
                            size: 18,
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              _items[index].$1,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text('学习数据暂时无法打开', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新读取'),
            ),
          ],
        ),
      ),
    ),
  );
}
