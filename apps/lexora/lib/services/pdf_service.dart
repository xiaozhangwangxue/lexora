import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../models/word_entry.dart';

enum PdfFontSize {
  small(.86, .86),
  medium(1, 1),
  large(1.18, 1.42);

  const PdfFontSize(this.scale, this.bodyScale);
  final double scale;
  final double bodyScale;
}

enum BookPageSize { a4, a5, b5 }

extension BookPageSizeLayout on BookPageSize {
  PdfPageFormat get pdfFormat => switch (this) {
    BookPageSize.a4 => PdfPageFormat.a4,
    BookPageSize.a5 => PdfPageFormat.a5,
    BookPageSize.b5 => PdfPageFormat(
      176 * PdfPageFormat.mm,
      250 * PdfPageFormat.mm,
    ),
  };

  int get widthTwips => switch (this) {
    BookPageSize.a4 => 11906,
    BookPageSize.a5 => 8391,
    BookPageSize.b5 => 9978,
  };

  int get heightTwips => switch (this) {
    BookPageSize.a4 => 16838,
    BookPageSize.a5 => 11906,
    BookPageSize.b5 => 14173,
  };

  int get marginTwips => this == BookPageSize.a5 ? 420 : 500;

  String get cssName => name.toUpperCase();
}

int exportColumnCount(BookPageSize pageSize, PdfTypography typography) {
  final availableWidth =
      pageSize.pdfFormat.width - (pageSize == BookPageSize.a5 ? 32 : 40);
  final compact =
      typography.word <= 12.5 &&
      typography.definition <= 8.2 &&
      typography.related <= 7.2 &&
      typography.example <= 7.2 &&
      typography.phrase <= 7.2;
  if (compact && availableWidth / 3 >= 148) return 3;
  final readableInTwoColumns =
      typography.word <= 20 &&
      typography.definition <= 11.5 &&
      availableWidth / 2 >= 178;
  return readableInTwoColumns ? 2 : 1;
}

class PdfTypography {
  const PdfTypography({
    required this.word,
    required this.phonetic,
    required this.definition,
    required this.related,
    required this.example,
    required this.phrase,
  });

  final double word;
  final double phonetic;
  final double definition;
  final double related;
  final double example;
  final double phrase;

  factory PdfTypography.fromPreset(PdfFontSize preset) => switch (preset) {
    PdfFontSize.small => const PdfTypography(
      word: 12,
      phonetic: 7.4,
      definition: 7.4,
      related: 6.4,
      example: 6.4,
      phrase: 6.4,
    ),
    PdfFontSize.medium => const PdfTypography(
      word: 18,
      phonetic: 9,
      definition: 8.7,
      related: 7.2,
      example: 7.2,
      phrase: 7.2,
    ),
    PdfFontSize.large => const PdfTypography(
      word: 21.24,
      phonetic: 12.78,
      definition: 12.354,
      related: 10.224,
      example: 10.224,
      phrase: 10.224,
    ),
  };

  PdfTypography copyWith({
    double? word,
    double? phonetic,
    double? definition,
    double? related,
    double? example,
    double? phrase,
  }) => PdfTypography(
    word: word ?? this.word,
    phonetic: phonetic ?? this.phonetic,
    definition: definition ?? this.definition,
    related: related ?? this.related,
    example: example ?? this.example,
    phrase: phrase ?? this.phrase,
  );
}

class PdfService {
  late final Future<pw.Font> _regularFont = _assetFont(
    'assets/fonts/NotoSansSC-Regular.ttf',
  );
  late final Future<pw.Font> _boldFont = _assetFont(
    'assets/fonts/NotoSansSC-Bold.ttf',
  );
  late final Future<pw.Font> _ipaFont = _assetFont(
    'assets/fonts/NotoSans-Regular.ttf',
  );

  Future<pw.Font> _assetFont(String path) async =>
      pw.Font.ttf(await rootBundle.load(path));

  Future<GeneratedBook> create(
    List<WordEntry> entries, {
    PdfFontSize fontSize = PdfFontSize.medium,
    PdfTypography? typography,
    BookPageSize pageSize = BookPageSize.a4,
  }) async {
    final now = DateTime.now();
    final bytes = await buildBytes(
      entries,
      fontSize: fontSize,
      typography: typography,
      pageSize: pageSize,
      generatedAt: now,
    );
    final directory = await getApplicationDocumentsDirectory();
    final id = const Uuid().v4();
    final filename = 'lexora-${DateFormat('yyyyMMdd-HHmmss').format(now)}.pdf';
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return GeneratedBook(
      id: id,
      title: filename,
      path: file.path,
      createdAt: now,
      wordCount: entries.length,
      previewWords: entries.map((entry) => entry.word).take(6).toList(),
    );
  }

  /// Builds the exact PDF bytes used by the app without writing a platform
  /// file. This keeps layout verification and the production export on the
  /// same code path.
  Future<Uint8List> buildBytes(
    List<WordEntry> entries, {
    PdfFontSize fontSize = PdfFontSize.medium,
    PdfTypography? typography,
    BookPageSize pageSize = BookPageSize.a4,
    bool smartReorder = false,
    bool showPageFurniture = true,
    DateTime? generatedAt,
  }) async {
    final date = generatedAt ?? DateTime.now();
    final fonts = await Future.wait([_regularFont, _boldFont, _ipaFont]);
    final regular = fonts[0];
    final bold = fonts[1];
    // Noto Sans SC does not contain the complete IPA Extensions block. Keep it
    // for Chinese text, and explicitly render phonetics with Noto Sans.
    final ipa = fonts[2];
    final resolvedTypography = typography ?? PdfTypography.fromPreset(fontSize);
    double size(double value) => value * fontSize.scale;
    final columnCount = exportColumnCount(pageSize, resolvedTypography);
    final document = pw.Document(
      title: 'Lexora Vocabulary Book',
      author: 'Lexora',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: pageSize.pdfFormat,
        // Keep the printable margins compact.  The entry flow below is a
        // spanning Wrap, so a page can continue with the next card instead
        // of leaving a large unused block at the bottom of a page.
        margin: pageSize == BookPageSize.a5
            ? const pw.EdgeInsets.fromLTRB(15, 13, 15, 13)
            : const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
        header: showPageFurniture
            ? (context) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'LEXORA',
                      style: pw.TextStyle(font: bold, fontSize: size(11)),
                    ),
                    pw.Text(
                      '${entries.length} entries / 词条 · ${DateFormat('yyyy-MM-dd').format(date)}',
                      style: pw.TextStyle(
                        fontSize: size(8),
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              )
            : null,
        footer: showPageFurniture
            ? (context) => pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  '${context.pageNumber} / ${context.pagesCount}',
                  style: pw.TextStyle(
                    fontSize: size(8),
                    color: PdfColors.grey600,
                  ),
                ),
              )
            : null,
        build: (context) => [
          pw.Text(
            'My vocabulary book',
            style: pw.TextStyle(
              font: bold,
              fontSize: size(24),
              color: PdfColors.indigo900,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '我的双语词汇册',
            style: pw.TextStyle(fontSize: size(11), color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 5),
          ..._entryLayout(
            entries,
            bold,
            ipa,
            resolvedTypography,
            columnCount: columnCount,
            smartReorder: smartReorder,
          ),
        ],
      ),
    );

    return document.save();
  }

  List<pw.Widget> _entryLayout(
    List<WordEntry> entries,
    pw.Font bold,
    pw.Font ipa,
    PdfTypography typography, {
    required int columnCount,
    required bool smartReorder,
  }) {
    final orderedEntries = smartReorder
        ? (entries.toList()
            ..sort((a, b) => _entryWeight(b).compareTo(_entryWeight(a))))
        : entries;
    if (columnCount == 1) {
      return [
        for (var index = 0; index < orderedEntries.length; index++) ...[
          _entry(
            index + 1,
            orderedEntries[index],
            bold,
            ipa,
            typography,
            denseHeader: false,
          ),
          if (index != orderedEntries.length - 1) pw.SizedBox(height: 4),
        ],
      ];
    }

    final columns = List.generate(columnCount, (_) => <pw.Widget>[]);
    final columnWeights = List<double>.filled(columnCount, 0);
    for (var index = 0; index < orderedEntries.length; index++) {
      final columnIndex = smartReorder
          ? columnWeights.indexOf(columnWeights.reduce((a, b) => a < b ? a : b))
          : index % columnCount;
      final column = columns[columnIndex];
      final entry = orderedEntries[index];
      column.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3),
          child: _entry(
            index + 1,
            entry,
            bold,
            ipa,
            typography,
            denseHeader: columnCount == 3,
          ),
        ),
      );
      column.add(pw.SizedBox(height: 3));
      columnWeights[columnIndex] += _entryWeight(entry);
    }

    // Each partition flows independently across pages. Unlike a row-based
    // grid or Wrap, a short card no longer inherits the height of the taller
    // card beside it, so the next entry immediately consumes the free space.
    return [
      pw.Partitions(
        children: [
          for (final column in columns)
            pw.Partition(child: pw.Column(children: column)),
        ],
      ),
    ];
  }

  static double _entryWeight(WordEntry entry) {
    var weight = (90 + entry.word.length * 3 + entry.definition.length)
        .toDouble();
    weight += entry.definitionZh.length * 1.15;
    weight += (entry.synonyms.length + entry.antonyms.length) * 14;
    weight += entry.examples.fold<int>(0, (sum, value) => sum + value.length);
    weight += entry.examplesZh.fold<int>(0, (sum, value) => sum + value.length);
    for (final phrase in entry.phrases) {
      weight +=
          phrase.phrase.length * 2 +
          phrase.meaning.length +
          phrase.meaningZh.length;
    }
    return weight.toDouble();
  }

  pw.Widget _entry(
    int number,
    WordEntry entry,
    pw.Font bold,
    pw.Font ipa,
    PdfTypography typography, {
    required bool denseHeader,
  }) {
    pw.Widget pill(String text, PdfColor color) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(text, style: pw.TextStyle(fontSize: typography.related)),
    );

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(7, 5, 7, 5),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300, width: .5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                '$number',
                style: pw.TextStyle(
                  fontSize: typography.related,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(width: 7),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      entry.word,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: typography.word,
                      ),
                    ),
                    if (entry.isFuzzyMatch) ...[
                      pw.SizedBox(height: 1),
                      pw.Text(
                        '(${entry.originalTerm})',
                        style: pw.TextStyle(
                          fontSize: typography.related,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!denseHeader) ...[
                pill(entry.difficulty, PdfColors.indigo100),
                pw.SizedBox(width: 5),
                pill(
                  'freq ${entry.frequency.toStringAsFixed(1)}',
                  PdfColors.teal100,
                ),
              ],
            ],
          ),
          if (denseHeader) ...[
            pw.SizedBox(height: 2),
            pw.Wrap(
              spacing: 4,
              children: [
                pill(entry.difficulty, PdfColors.indigo100),
                pill(
                  'freq ${entry.frequency.toStringAsFixed(1)}',
                  PdfColors.teal100,
                ),
              ],
            ),
          ],
          pw.SizedBox(height: 3),
          pw.Wrap(
            crossAxisAlignment: pw.WrapCrossAlignment.center,
            children: [
              pw.Text(
                'US 美式  ',
                style: pw.TextStyle(
                  fontSize: typography.phonetic - 1,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                entry.usPhonetic,
                style: pw.TextStyle(
                  font: ipa,
                  fontSize: typography.phonetic,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                'UK 英式  ',
                style: pw.TextStyle(
                  fontSize: typography.phonetic - 1,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                entry.ukPhonetic,
                style: pw.TextStyle(
                  font: ipa,
                  fontSize: typography.phonetic,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            entry.definition,
            style: pw.TextStyle(fontSize: typography.definition),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            entry.definitionZh,
            style: pw.TextStyle(
              font: bold,
              fontSize: typography.definition,
              color: PdfColors.indigo900,
            ),
          ),
          if (entry.synonyms.isNotEmpty || entry.antonyms.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            if (entry.synonyms.isNotEmpty) ...[
              pw.Text(
                'Synonyms / 近义词  ${entry.synonyms.join(' · ')}',
                style: pw.TextStyle(fontSize: typography.related),
              ),
              if (entry.synonymsZh.isNotEmpty && entry.synonymsZh != '—')
                pw.Text(
                  entry.synonymsZh,
                  style: pw.TextStyle(
                    fontSize: typography.related,
                    color: PdfColors.indigo700,
                  ),
                ),
            ],
            if (entry.antonyms.isNotEmpty) ...[
              if (entry.synonyms.isNotEmpty) pw.SizedBox(height: 2),
              pw.Text(
                'Antonyms / 反义词  ${entry.antonyms.join(' · ')}',
                style: pw.TextStyle(fontSize: typography.related),
              ),
              if (entry.antonymsZh.isNotEmpty && entry.antonymsZh != '—')
                pw.Text(
                  entry.antonymsZh,
                  style: pw.TextStyle(
                    fontSize: typography.related,
                    color: PdfColors.indigo700,
                  ),
                ),
            ],
          ],
          if (entry.examples.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Container(
              padding: const pw.EdgeInsets.only(left: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.teal400, width: 2),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < entry.examples.length; i++) ...[
                    if (i > 0) pw.SizedBox(height: 4),
                    pw.Text(
                      entry.examples[i],
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: typography.example,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      entry.examplesZh[i],
                      style: pw.TextStyle(fontSize: typography.example),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (entry.phrases.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Phrases / 常用短语',
              style: pw.TextStyle(
                font: bold,
                fontSize: typography.phrase + .2,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 2),
            for (var i = 0; i < entry.phrases.length; i++) ...[
              if (i > 0) pw.SizedBox(height: 3),
              pw.Text(
                entry.phrases[i].phrase,
                style: pw.TextStyle(font: bold, fontSize: typography.phrase),
              ),
              pw.Text(
                entry.phrases[i].meaning,
                style: pw.TextStyle(fontSize: typography.phrase),
              ),
              pw.Text(
                entry.phrases[i].meaningZh,
                style: pw.TextStyle(
                  fontSize: typography.phrase,
                  color: PdfColors.indigo700,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
