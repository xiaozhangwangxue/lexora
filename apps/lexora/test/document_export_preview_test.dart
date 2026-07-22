import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/models/word_entry.dart';
import 'package:lexora/services/document_export_service.dart';
import 'package:lexora/services/pdf_service.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds editable DOCX and valid EPUB previews', () async {
    final entries = [
      _entry('serendipity', '意外发现美好事物的运气', originalTerm: 'serendipty'),
      _entry('take off', '起飞；突然成功；脱下'),
      _entry('meticulous', '一丝不苟的；非常仔细的'),
      _entry('resilient', '有韧性的；能迅速恢复的'),
    ];
    final service = DocumentExportService();
    final docx = await service.buildDocxBytes(
      entries,
      fontSize: PdfFontSize.small,
      pageSize: BookPageSize.a4,
      generatedAt: DateTime.utc(2026, 7, 19),
    );
    final epub = service.buildEpubBytes(
      entries,
      generatedAt: DateTime.utc(2026, 7, 19),
    );
    final output = Directory('build/qa');
    await output.create(recursive: true);
    await File('${output.path}/qa-docx-preview.docx').writeAsBytes(docx);
    await File('${output.path}/qa-epub-preview.epub').writeAsBytes(epub);

    final docxArchive = ZipDecoder().decodeBytes(docx, verify: true);
    final document = docxArchive.findFile('word/document.xml');
    expect(document, isNotNull);
    final documentXml = utf8.decode(document!.content);
    expect(documentXml, contains('serendipity'));
    expect(documentXml, contains('意外发现美好事物的运气'));
    expect(documentXml, contains('<w:tbl'));
    expect('<w:gridCol '.allMatches(documentXml), hasLength(3));

    final epubArchive = ZipDecoder().decodeBytes(epub, verify: true);
    expect(epubArchive.first.name, 'mimetype');
    expect(
      utf8.decode(epubArchive.findFile('mimetype')!.content),
      'application/epub+zip',
    );
    expect(epubArchive.findFile('EPUB/book.xhtml'), isNotNull);
    final bookXhtml = utf8.decode(
      epubArchive.findFile('EPUB/book.xhtml')!.content,
    );
    expect(bookXhtml, isNot(contains('&nbsp;')));
    expect(() => XmlDocument.parse(bookXhtml), returnsNormally);
    expect(
      () => XmlDocument.parse(
        utf8.decode(epubArchive.findFile('EPUB/nav.xhtml')!.content),
      ),
      returnsNormally,
    );
    expect(
      () => XmlDocument.parse(
        utf8.decode(epubArchive.findFile('EPUB/package.opf')!.content),
      ),
      returnsNormally,
    );
  });

  test('automatic columns adapt to paper and typography', () {
    final small = PdfTypography.fromPreset(PdfFontSize.small);
    final medium = PdfTypography.fromPreset(PdfFontSize.medium);
    final large = PdfTypography.fromPreset(PdfFontSize.large);

    expect(small.word, 12);
    expect(exportColumnCount(BookPageSize.a4, small), 3);
    expect(exportColumnCount(BookPageSize.b5, small), 3);
    expect(exportColumnCount(BookPageSize.a5, small), 2);
    expect(exportColumnCount(BookPageSize.a4, medium), 2);
    expect(exportColumnCount(BookPageSize.a4, large), 1);
  });
}

WordEntry _entry(String word, String chinese, {String? originalTerm}) =>
    WordEntry(
      word: word,
      originalTerm: originalTerm,
      difficulty: 'B1–B2',
      frequency: 7.5,
      usPhonetic: '/ˌserənˈdɪpəti/',
      ukPhonetic: '/ˌserənˈdɪpɪti/',
      definition:
          'A concise English definition for an editable vocabulary card.',
      definitionZh: chinese,
      synonyms: const ['useful', 'clear'],
      synonymsZh: '实用的，清晰的',
      antonyms: const [],
      antonymsZh: '',
      examples: const ['This is a natural example sentence.'],
      examplesZh: const ['这是一句自然的例句。'],
      phrases: const [
        PhraseEntry(
          phrase: 'a useful phrase',
          meaning: 'A phrase used with this entry.',
          meaningZh: '与该词条一起使用的短语。',
        ),
      ],
    );
