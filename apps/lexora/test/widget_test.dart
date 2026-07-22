import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lexora/app_version.dart';
import 'package:lexora/l10n/app_localizations.dart';
import 'package:lexora/main.dart';
import 'package:lexora/screens/history_screen.dart';
import 'package:lexora/screens/word_history_screen.dart';
import 'package:lexora/services/generation_progress.dart';
import 'package:lexora/services/history_service.dart';
import 'package:lexora/widgets/lexora_wordmark.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('first launch opens the onboarding tutorial', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LexoraApp());
    await pumpUi(tester);
    expect(find.text('Type, or import a whole word list'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('desktop sidebar compacts smoothly and can be toggled', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 760);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    SharedPreferences.setMockInitialValues({
      'lexora.onboarding.completed.v1': true,
      'lexora.release-notes.seen.$appVersion': true,
    });

    await tester.pumpWidget(const LexoraApp(locale: Locale('zh', 'CN')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getSize(find.byKey(const Key('desktop-sidebar'))).width, 220);

    await tester.tap(find.byKey(const Key('desktop-sidebar-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final animatedWidth = tester
        .getSize(find.byKey(const Key('desktop-sidebar')))
        .width;
    expect(animatedWidth, inExclusiveRange(76, 220));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getSize(find.byKey(const Key('desktop-sidebar'))).width, 76);

    await tester.tap(find.byKey(const Key('desktop-sidebar-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getSize(find.byKey(const Key('desktop-sidebar'))).width, 220);

    tester.view.physicalSize = const Size(760, 760);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getSize(find.byKey(const Key('desktop-sidebar'))).width, 76);
    expect(find.byKey(const Key('desktop-sidebar-toggle')), findsNothing);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('macOS first-run layout has no phantom native sidebar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1594, 1332);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const RepaintBoundary(
        key: Key('macos-onboarding-capture'),
        child: LexoraApp(),
      ),
    );
    await pumpUi(tester);
    expect(find.text('Type, or import a whole word list'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('macos-onboarding-capture')),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/qa/macos-onboarding-after.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    });
  });

  testWidgets('Lexora opens the localized word composer', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lexora.onboarding.completed.v1': true,
      'lexora.release-notes.seen.$appVersion': true,
    });
    await tester.pumpWidget(const LexoraApp(locale: Locale('zh', 'CN')));
    await pumpUi(tester);
    expect(find.byType(LexoraWordmark), findsOneWidget);
    expect(find.text('开始生成'), findsOneWidget);
    expect(find.textContaining('文档自定义'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('你的单词和短语将显示在这里'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'take off');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpUi(tester);
    expect(find.text('take off'), findsOneWidget);
    expect(find.textContaining('短语'), findsWidgets);

    await tester.tap(find.textContaining('文档自定义').first);
    await pumpUi(tester);
    expect(find.text('精细调整字体'), findsOneWidget);
    expect(find.text('单词标题'), findsOneWidget);
    expect(find.text('实时预览'), findsOneWidget);
    expect(find.textContaining('滚轮、双指'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('pdf-customization-scroll')),
      const Offset(0, -260),
    );
    await pumpUi(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await pumpUi(tester);
    expect(find.text('take off'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await pumpUi(tester);
    expect(find.text('GitHub'), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await pumpUi(tester);
    expect(find.text('把零散单词，变成真正想读的词汇书。'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Lexora 官网'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Lexora 官网'), findsOneWidget);
    expect(find.text('支持 Lexora'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
  });

  testWidgets(
    'Android resume clears focus and ignores a stale keyboard inset',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(540, 1280);
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        tester.view.resetViewInsets();
      });
      SharedPreferences.setMockInitialValues({
        'lexora.onboarding.completed.v1': true,
        'lexora.release-notes.seen.$appVersion': true,
      });

      await tester.pumpWidget(
        const RepaintBoundary(
          key: Key('android-resume-capture'),
          child: LexoraApp(locale: Locale('zh', 'CN')),
        ),
      );
      await pumpUi(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.focusNode?.hasFocus, isTrue);

      tester.view.viewInsets = const FakeViewPadding(bottom: 480);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      expect(input.focusNode?.hasFocus, isFalse);
      await tester.tap(find.text('设置').last);
      await pumpUi(tester);
      expect(find.text('文档自定义'), findsOneWidget);
      final rootScaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(rootScaffold.resizeToAvoidBottomInset, isFalse);
      expect(tester.getBottomRight(find.byType(NavigationBar)).dy, 1280);

      await tester.tap(find.text('生成记录').last);
      await pumpUi(tester);
      expect(find.text('阅读、导出或分享已生成的词汇书。'), findsOneWidget);
      expect(input.focusNode?.hasFocus, isFalse);

      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('android-resume-capture')),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/qa/android-resume-after.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      });

      debugDefaultTargetPlatformOverride = null;
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetViewInsets();
    },
  );

  testWidgets('历史批量操作显示重新生成文字', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lexora.generated.words.v1': [
        jsonEncode({
          'word': 'alpha',
          'generationCount': 2,
          'firstGeneratedAt': '2026-07-12T10:00:00.000',
          'lastGeneratedAt': '2026-07-13T10:00:00.000',
          'difficulty': 'B1',
          'starred': false,
        }),
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: WordHistoryScreen(
            generationRunning: false,
            onRegenerate: (_) {},
            onCustomizePdf: () async {},
            historyService: HistoryService(
              documentsDirectory: () async => Directory.systemTemp
                  .createTempSync('lexora-word-history-widget-'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await pumpUi(tester);
    await tester.tap(find.text('多选'));
    await pumpUi(tester);
    await tester.tap(find.text('alpha'));
    await pumpUi(tester);

    expect(find.widgetWithText(FilledButton, '重新生成'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '重新生成'));
    await pumpUi(tester);
    expect(find.text('精细调整字体'), findsOneWidget);
  });

  testWidgets('生成完成后用灰色叉替代百分比并可移除进度', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final progress = GenerationProgress()
      ..start(4)
      ..complete();
    final directory = Directory.systemTemp.createTempSync(
      'lexora-completed-progress-',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: HistoryScreen(
          progress: progress,
          onOpenBook: (_) {},
          historyService: HistoryService(
            documentsDirectory: () async => directory,
          ),
        ),
      ),
    );
    await pumpUi(tester);

    expect(find.text('100%'), findsNothing);
    final close = find.byKey(const Key('dismiss-completed-generation'));
    expect(close, findsOneWidget);
    final icon = tester.widget<Icon>(
      find.descendant(of: close, matching: find.byIcon(Icons.close_rounded)),
    );
    expect(
      icon.color,
      Theme.of(tester.element(close)).colorScheme.onSurfaceVariant,
    );

    await tester.tap(close);
    await tester.pump();
    expect(find.text('词汇书已完成'), findsNothing);
  });
}
