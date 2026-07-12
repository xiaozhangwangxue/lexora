import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('first launch opens the onboarding tutorial', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LexoraApp());
    await tester.pumpAndSettle();
    expect(find.text('Collect your words'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('Lexora opens the localized word composer', (tester) async {
    SharedPreferences.setMockInitialValues({'lexora.onboarding.completed.v1': true});
    tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(const LexoraApp());
    await tester.pumpAndSettle();
    expect(find.text('Lexora'), findsOneWidget);
    expect(find.text('开始生成'), findsOneWidget);
    expect(find.text('自定义 PDF'), findsOneWidget);
    expect(find.text('你的单词将显示在这里'), findsOneWidget);
  });
}
