import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lexora/l10n/app_localizations.dart';
import 'package:lexora/main.dart';
import 'package:lexora/screens/word_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('first launch opens the onboarding tutorial', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LexoraApp());
    await tester.pumpAndSettle();
    expect(find.text('Collect words and phrases'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('Lexora opens the localized word composer', (tester) async {
    SharedPreferences.setMockInitialValues({'lexora.onboarding.completed.v1': true});
    await tester.pumpWidget(const LexoraApp(locale: Locale('zh', 'CN')));
    await tester.pumpAndSettle();
    expect(find.text('Lexora'), findsOneWidget);
    expect(find.text('开始生成'), findsOneWidget);
    expect(find.textContaining('PDF 自定义'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('你的单词和短语将显示在这里'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'take off');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('take off'), findsOneWidget);
    expect(find.textContaining('短语'), findsWidgets);

    await tester.tap(find.textContaining('PDF 自定义').first);
    await tester.pumpAndSettle();
    expect(find.text('精细调整字体'), findsOneWidget);
    expect(find.text('单词标题'), findsOneWidget);
    expect(find.text('实时预览'), findsOneWidget);
    expect(find.textContaining('滚轮、双指'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('pdf-customization-scroll')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('take off'), findsOneWidget);

    await tester.tap(find.text('生成记录'));
    await tester.pumpAndSettle();
    expect(find.text('GitHub'), findsNothing);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('把零散单词，变成真正想读的词汇书。'), findsOneWidget);
    expect(find.text('Lexora 官网'), findsOneWidget);
    expect(find.text('支持 Lexora'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
  });

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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('多选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '重新生成'), findsOneWidget);
  });
}
