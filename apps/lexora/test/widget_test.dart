import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:lexora/app_version.dart';
import 'package:lexora/l10n/app_localizations.dart';
import 'package:lexora/main.dart';
import 'package:lexora/models/word_entry.dart';
import 'package:lexora/screens/history_screen.dart';
import 'package:lexora/screens/search_history_screen.dart';
import 'package:lexora/screens/search_screen.dart';
import 'package:lexora/screens/word_history_screen.dart';
import 'package:lexora/services/generation_progress.dart';
import 'package:lexora/services/history_service.dart';
import 'package:lexora/services/search_history_service.dart';
import 'package:lexora/services/word_service.dart';
import 'package:lexora/widgets/lexora_wordmark.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

class _ImmediateWordService extends WordService {
  static const entry = WordEntry(
    word: 'word',
    difficulty: 'A1–A2',
    frequency: 147.7,
    usPhonetic: '/wɜːd/',
    ukPhonetic: '/wɜːd/',
    definition: 'A unit of language.',
    definitionZh: '语言单位。',
    synonyms: [],
    synonymsZh: '',
    antonyms: [],
    antonymsZh: '',
    examples: [],
    examplesZh: [],
  );

  @override
  Future<List<String>> suggest(String rawTerm, {int maxResults = 12}) async =>
      const [];

  @override
  Future<WordEntry> lookupCore(String rawWord, {int exampleCount = 1}) async =>
      entry;

  @override
  Future<WordEntry> lookupEnglish(
    String rawWord, {
    int exampleCount = 1,
  }) async => entry;

  @override
  Future<LookupBatchResult> lookupAll(
    List<String> terms, {
    int exampleCount = 1,
    int maxConcurrency = 4,
    void Function(int completed, int total, String term)? onProgress,
  }) async =>
      const LookupBatchResult(entries: [entry], failures: [], fuzzyMatches: []);
}

class _ProgressiveWordService extends WordService {
  final core = Completer<WordEntry>();
  final english = Completer<WordEntry>();
  final full = Completer<LookupBatchResult>();

  @override
  Future<List<String>> suggest(String rawTerm, {int maxResults = 12}) async =>
      const [];

  @override
  Future<WordEntry> lookupCore(String rawWord, {int exampleCount = 1}) =>
      core.future;

  @override
  Future<WordEntry> lookupEnglish(String rawWord, {int exampleCount = 1}) =>
      english.future;

  @override
  Future<LookupBatchResult> lookupAll(
    List<String> terms, {
    int exampleCount = 1,
    int maxConcurrency = 4,
    void Function(int completed, int total, String term)? onProgress,
  }) => full.future;

  @override
  Future<void> retainOnly(String rawTerm, {int exampleCount = 1}) async {}
}

class _SuggestionWordService extends _ImmediateWordService {
  @override
  Future<List<String>> suggest(String rawTerm, {int maxResults = 12}) async =>
      const ['word', 'world', 'work'];

  @override
  Future<void> prefetchCandidates(
    Iterable<String> rawTerms, {
    int maxCandidates = 3,
  }) async {}
}

class _StaticSearchHistoryService extends SearchHistoryService {
  _StaticSearchHistoryService(this.records);

  final List<SearchHistoryRecord> records;

  @override
  Future<List<SearchHistoryRecord>> load() async => records;
}

void main() {
  testWidgets('first launch opens the onboarding tutorial', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LexoraApp());
    await pumpUi(tester);
    expect(find.text('Look it up before you save it'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('compact release notes remain scrollable on a small phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    SharedPreferences.setMockInitialValues({
      'lexora.onboarding.completed.v1': true,
    });

    await tester.pumpWidget(const LexoraApp(locale: Locale('zh', 'CN')));
    await pumpUi(tester);
    expect(find.textContaining('Lexora $appVersion'), findsOneWidget);
    expect(find.text('查看完整更新内容'), findsOneWidget);
    expect(find.text('继续使用'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('继续使用'));
    await pumpUi(tester);
    expect(find.text('搜索英文单词或短语'), findsOneWidget);
  });

  testWidgets('search suggestions float above content without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final controller = SearchScreenController();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('zh')],
        home: Scaffold(
          body: SearchScreen(
            active: true,
            controller: controller,
            vocabularyTerms: const [],
            onVocabularyChanged: (_) {},
            onHistoryChanged: () {},
            wordService: _SuggestionWordService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'wo');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text('其他联想'), findsOneWidget);
    expect(find.text('world'), findsOneWidget);
    final fieldRect = tester.getRect(find.byType(TextField));
    final panelRect = tester.getRect(
      find.byKey(const Key('search-suggestion-panel')),
    );
    expect(panelRect.left, closeTo(fieldRect.left, .01));
    expect(panelRect.right, closeTo(fieldRect.right, .01));
    expect(tester.takeException(), isNull);
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

  testWidgets('Windows uses the Fluent navigation and Chinese font fallback', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 760);
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    SharedPreferences.setMockInitialValues({
      'lexora.onboarding.completed.v1': true,
      'lexora.release-notes.seen.$appVersion': true,
    });

    await tester.pumpWidget(const LexoraApp(locale: Locale('zh', 'CN')));
    await pumpUi(tester);

    final navigation = find.byKey(const Key('windows-winui-navigation'));
    expect(navigation, findsOneWidget);
    expect(find.byType(fluent.NavigationView), findsOneWidget);
    final fluentTheme = fluent.FluentTheme.of(tester.element(navigation));
    expect(fluentTheme.typography.body?.fontFamily, 'Segoe UI Variable');
    expect(
      fluentTheme.typography.body?.fontFamilyFallback,
      contains('Microsoft YaHei UI'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
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
    expect(find.text('Look it up before you save it'), findsOneWidget);

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

  testWidgets('Lexora opens search and navigates to the vocabulary book', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'lexora.onboarding.completed.v1': true,
      'lexora.release-notes.seen.$appVersion': true,
    });
    await tester.pumpWidget(const LexoraApp(locale: Locale('zh', 'CN')));
    await pumpUi(tester);
    expect(find.byType(LexoraWordmark), findsOneWidget);
    expect(find.text('搜索英文单词或短语'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);
    await tester.tap(find.byIcon(Icons.auto_stories_outlined));
    await pumpUi(tester);
    expect(find.text('开始生成'), findsOneWidget);
    expect(find.textContaining('文档自定义'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('你的单词和短语将显示在这里'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'take off');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpUi(tester);
    expect(find.text('take off'), findsOneWidget);
    expect(find.textContaining('短语'), findsWidgets);

    final homeInput = tester.widget<TextField>(find.byType(TextField));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(homeInput.focusNode?.hasFocus, isTrue);

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
    expect(homeInput.focusNode?.hasFocus, isFalse);

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
    final quickLinkMaterial = tester.widget<Material>(
      find.byKey(const ValueKey('quick-link-检查更新')),
    );
    expect(quickLinkMaterial.clipBehavior, Clip.antiAlias);
    expect(
      quickLinkMaterial.borderRadius,
      const BorderRadius.all(Radius.circular(18)),
    );
  });

  testWidgets('search result hides shell chrome and stays responsive', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(540, 760);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    SharedPreferences.setMockInitialValues({});
    final controller = SearchScreenController();
    bool? resultVisible;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('zh')],
        home: Scaffold(
          body: SearchScreen(
            active: true,
            controller: controller,
            vocabularyTerms: const [],
            onVocabularyChanged: (_) {},
            onHistoryChanged: () {},
            onResultVisibilityChanged: (visible) => resultVisible = visible,
            wordService: _ImmediateWordService(),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.search('word');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(resultVisible, isTrue);
    expect(find.text('word'), findsWidgets);
    expect(find.text('freq 147.7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search enters immediately and progressively fills the result', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = SearchScreenController();
    final service = _ProgressiveWordService();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SearchScreen(
            active: true,
            controller: controller,
            vocabularyTerms: const [],
            onVocabularyChanged: (_) {},
            onHistoryChanged: () {},
            wordService: service,
          ),
        ),
      ),
    );
    await tester.pump();
    controller.search('word');
    await tester.pump();

    expect(find.text('word'), findsWidgets);
    expect(find.text('核心释义'), findsOneWidget);
    expect(find.byKey(const ValueKey('translations-loading')), findsOneWidget);

    service.core.complete(_ImmediateWordService.entry);
    await tester.pump();
    expect(find.text('A unit of language.'), findsOneWidget);
    expect(find.byKey(const ValueKey('translations-loading')), findsOneWidget);

    service.english.complete(_ImmediateWordService.entry);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('translations-background-loading')),
      findsOneWidget,
    );

    const fullEntry = WordEntry(
      word: 'word',
      difficulty: 'A1–A2',
      frequency: 147.7,
      usPhonetic: '/wɜːd/',
      ukPhonetic: '/wɜːd/',
      definition: 'A unit of language.',
      definitionZh: '语言单位。',
      synonyms: ['term'],
      synonymsZh: '词语',
      antonyms: [],
      antonymsZh: '',
      examples: ['This is a word.'],
      examplesZh: ['这是一个单词。'],
      phrases: [
        PhraseEntry(phrase: 'in a word', meaning: 'briefly', meaningZh: '简而言之'),
      ],
    );
    service.full.complete(
      const LookupBatchResult(
        entries: [fullEntry],
        failures: [],
        fuzzyMatches: [],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('正在补充完整翻译…'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('This is a word.'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('This is a word.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('in a word'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('in a word'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search history opens a draggable result sheet in place', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final record = SearchHistoryRecord(
      query: 'word',
      resolvedWord: 'word',
      searchedAt: DateTime.utc(2026, 7, 27),
      entry: const WordEntry(
        word: 'word',
        difficulty: 'A1–A2',
        frequency: 147.7,
        usPhonetic: '/wɜːd/',
        ukPhonetic: '/wɜːd/',
        definition: 'A unit of language.',
        definitionZh: '语言单位。',
        synonyms: ['term'],
        synonymsZh: '词语',
        antonyms: [],
        antonymsZh: '',
        examples: [],
        examplesZh: [],
      ),
    );
    final service = _ImmediateWordService();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: SearchHistoryScreen(
              historyService: _StaticSearchHistoryService([record]),
              onCreateVocabularyBook: (_) {},
              onSearch: (selected) => showLexoraWordSheet(
                context: context,
                term: selected.resolvedWord,
                initialEntry: selected.entry,
                wordService: service,
                vocabularyTerms: const [],
                onToggleVocabulary: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('word'));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const Key('lexora-word-sheet'));
    expect(sheet, findsOneWidget);
    final draggable = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(draggable.snap, isFalse);
    expect(draggable.controller, isNotNull);
    final initialHeight = tester.getSize(sheet).height;
    await tester.drag(sheet, const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(tester.getSize(sheet).height, greaterThan(initialHeight));

    final termLink = find.ancestor(
      of: find.text('term'),
      matching: find.byType(InkWell),
    );
    expect(termLink, findsOneWidget);
    await tester.tap(termLink);
    await tester.pump(const Duration(milliseconds: 70));
    expect(find.byKey(const ValueKey('result-word')), findsOneWidget);
    expect(find.byKey(const ValueKey('result-term')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('result-word')), findsNothing);
    expect(find.byKey(const ValueKey('result-term')), findsOneWidget);
    expect(find.byTooltip('返回上一个单词'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    expect(find.byTooltip('返回上一个单词'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(find.text('word'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
      expect(find.text('v$appVersion'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('开发者模式'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('详细诊断日志'), findsOneWidget);
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
