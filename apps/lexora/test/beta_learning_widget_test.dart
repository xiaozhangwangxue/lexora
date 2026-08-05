import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/beta/controllers/beta_controller.dart';
import 'package:lexora/beta/data/beta_repository.dart';
import 'package:lexora/beta/domain/review_scheduler.dart';
import 'package:lexora/beta/models/learning_models.dart';
import 'package:lexora/beta/screens/beta_learning_screen.dart';

void main() {
  testWidgets('移动端完成主动回忆、显示答案、评分和持久化闭环', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final now = DateTime.now();
    final word = LearningWord(
      id: 'word-1',
      text: 'word',
      normalizedText: 'word',
      phoneticUS: '/wɝːd/',
      meanings: [
        WordMeaning(
          id: 'meaning-1',
          partOfSpeech: 'n.',
          definitionZh: '语言单位。',
          definitionEn: 'A unit of language.',
          examples: [
            WordExample(
              id: 'example-1',
              sentence: 'This is a word.',
              translation: '这是一个单词。',
              clozeSentence: 'This is a ______.',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    final repository = _MemoryBetaRepository(
      BetaData.empty(now).copyWith(
        words: [word],
        reviewStates: {word.id: createReviewState(word.id, now)},
      ),
    );
    final controller = BetaController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: BetaLearningScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lexora 学习 Beta'), findsOneWidget);
    expect(find.text('开始今日学习'), findsWidgets);
    expect(find.text('语言单位。'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '开始今日学习').first);
    await tester.pumpAndSettle();
    expect(find.text('word'), findsOneWidget);
    expect(find.text('语言单位。'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '显示答案'));
    await tester.pumpAndSettle();
    expect(find.textContaining('语言单位。'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '认识'), findsOneWidget);

    final goodButton = find.widgetWithText(OutlinedButton, '认识');
    await tester.ensureVisible(goodButton);
    await tester.pump();
    await tester.tap(goodButton);
    await tester.tap(goodButton);
    await tester.pumpAndSettle();

    expect(controller.data.reviewLogs, hasLength(1));
    expect(
      controller.data.reviewStates[word.id]!.status,
      LearningStatus.review,
    );
    expect(repository.saved.reviewLogs, hasLength(1));
    expect(find.text('今日学习已完成'), findsOneWidget);
    expect(find.text('进入今日复习'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360x640 下 Beta 导航和空状态不横向溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final controller = BetaController(
      repository: _MemoryBetaRepository(BetaData.empty()),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: BetaLearningScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('当前到期复习'), findsOneWidget);
    expect(find.byKey(const ValueKey('beta-mobile-tabs')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryBetaRepository extends BetaRepository {
  _MemoryBetaRepository(this.saved);

  BetaData saved;

  @override
  Future<BetaData> load({
    List<dynamic>? legacySearchRecords,
    List<dynamic>? legacyGeneratedWords,
    DateTime? now,
  }) async => saved;

  @override
  Future<void> save(BetaData data) async {
    saved = data;
  }
}
