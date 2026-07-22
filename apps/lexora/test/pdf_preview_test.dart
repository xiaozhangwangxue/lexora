import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/models/word_entry.dart';
import 'package:lexora/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders the production PDF layout preview', () async {
    final entries = [
      _entry(
        'serendipity',
        '/ˌserənˈdɪpəti/',
        '意外发现美好事物的运气',
        originalTerm: 'serendipty',
      ),
      _entry('take off', '/teɪk ɔf/', '起飞；突然成功；脱下'),
      _entry('meticulous', '/məˈtɪkjələs/', '一丝不苟的；非常仔细的'),
      _entry('resilient', '/rɪˈzɪliənt/', '有韧性的；能迅速恢复的'),
      _entry('by and large', '/baɪ ən lɑːdʒ/', '总的来说；大体上'),
      _entry('ephemeral', '/ɪˈfemərəl/', '短暂的；转瞬即逝的'),
      _entry('pragmatic', '/præɡˈmætɪk/', '务实的；讲求实际的'),
      _entry('break the ice', '/breɪk ði aɪs/', '打破冷场；缓和气氛'),
    ];

    final bytes = await PdfService().buildBytes(
      entries,
      generatedAt: DateTime(2026, 7, 13),
    );
    final output = File('build/qa/qa-pdf-preview.pdf');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes, flush: true);

    final compactBytes = await PdfService().buildBytes(
      entries,
      fontSize: PdfFontSize.small,
      generatedAt: DateTime(2026, 7, 13),
    );
    final compactOutput = File('build/qa/qa-pdf-preview-small.pdf');
    await compactOutput.writeAsBytes(compactBytes, flush: true);

    expect(bytes, isNotEmpty);
    expect(await output.length(), greaterThan(15000));
    expect(compactBytes, isNotEmpty);
    expect(await compactOutput.length(), greaterThan(15000));
  });
}

WordEntry _entry(
  String word,
  String phonetic,
  String chinese, {
  String? originalTerm,
}) => WordEntry(
  word: word,
  originalTerm: originalTerm,
  difficulty: 'B1–B2',
  frequency: 7.5,
  usPhonetic: phonetic,
  ukPhonetic: phonetic,
  definition: 'A concise English definition that demonstrates the layout.',
  definitionZh: chinese,
  synonyms: const ['useful', 'clear'],
  synonymsZh: '实用的，清晰的',
  antonyms: const [],
  antonymsZh: '',
  examples: const ['This is a natural example sentence for the entry.'],
  examplesZh: const ['这是该词条的一句自然例句。'],
  phrases: const [
    PhraseEntry(
      phrase: 'a useful related phrase',
      meaning: 'A phrase commonly used with this entry.',
      meaningZh: '与这个词条常见的相关短语。',
    ),
  ],
);
