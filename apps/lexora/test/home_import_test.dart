import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/l10n/app_localizations.dart';
import 'package:lexora/screens/home_screen.dart';
import 'package:lexora/services/document_import_service.dart';
import 'package:lexora/services/pdf_settings_service.dart';

class _FakeDocumentImportService extends DocumentImportService {
  const _FakeDocumentImportService();

  @override
  Future<DocumentImportResult> extractBytes({
    required String fileName,
    required Uint8List bytes,
  }) async => const DocumentImportResult(
    terms: ['word', 'take off'],
    nonEmptyLineCount: 3,
    invalidLineCount: 0,
    duplicateLineCount: 1,
  );
}

void main() {
  testWidgets('imports a newline-delimited text file into the home list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
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
          body: HomeScreen(
            settings: const PdfSettings(),
            generationRunning: false,
            onStartGeneration: (_) {},
            onCustomizePdf: () {},
            importService: const _FakeDocumentImportService(),
            importFilePicker: () async => [
              XFile.fromData(
                Uint8List.fromList(utf8.encode('word\ntake off\nword\n')),
                name: 'words.txt',
                mimeType: 'text/plain',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final importButton = find.widgetWithText(OutlinedButton, '导入文件');
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('word'), findsOneWidget);
    expect(find.text('take off'), findsOneWidget);
    expect(find.textContaining('已添加 2 个词条'), findsOneWidget);
  });
}
