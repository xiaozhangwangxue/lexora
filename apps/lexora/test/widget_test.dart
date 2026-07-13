import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/main.dart';
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
}
