import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

  factory PdfTypography.fromPreset(PdfFontSize preset) => PdfTypography(
        word: 18 * preset.scale,
        phonetic: 9 * preset.bodyScale,
        definition: 8.7 * preset.bodyScale,
        related: 7.2 * preset.bodyScale,
        example: 7.2 * preset.bodyScale,
        phrase: 7.2 * preset.bodyScale,
      );

  PdfTypography copyWith({
    double? word,
    double? phonetic,
    double? definition,
    double? related,
    double? example,
    double? phrase,
  }) =>
      PdfTypography(
        word: word ?? this.word,
        phonetic: phonetic ?? this.phonetic,
        definition: definition ?? this.definition,
        related: related ?? this.related,
        example: example ?? this.example,
        phrase: phrase ?? this.phrase,
      );
}

class PdfService {
  late final Future<pw.Font> _regularFont = PdfGoogleFonts.notoSansSCRegular();
  late final Future<pw.Font> _boldFont = PdfGoogleFonts.notoSansSCBold();
  late final Future<pw.Font> _ipaFont = PdfGoogleFonts.notoSansRegular();

  Future<GeneratedBook> create(
    List<WordEntry> entries, {
    PdfFontSize fontSize = PdfFontSize.medium,
    PdfTypography? typography,
  }) async {
    final now = DateTime.now();
    final bytes = await buildBytes(
      entries,
      fontSize: fontSize,
      typography: typography,
      generatedAt: now,
    );
    final directory = await getApplicationDocumentsDirectory();
    final id = const Uuid().v4();
    final filename = 'lexora-${DateFormat('yyyyMMdd-HHmm').format(now)}.pdf';
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
    DateTime? generatedAt,
  }) async {
    final date = generatedAt ?? DateTime.now();
    final fonts = await Future.wait([_regularFont, _boldFont, _ipaFont]);
    final regular = fonts[0];
    final bold = fonts[1];
    // Noto Sans SC does not contain the complete IPA Extensions block. Keep it
    // for Chinese text, and explicitly render phonetics with Noto Sans.
    final ipa = fonts[2];
    final resolvedTypography =
        typography ?? PdfTypography.fromPreset(fontSize);
    double size(double value) => value * fontSize.scale;
    final useTwoColumns = fontSize != PdfFontSize.large;
    final document = pw.Document(
      title: 'Lexora Vocabulary Book',
      author: 'Lexora',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // Keep the printable margins compact.  The entry flow below is a
        // spanning Wrap, so a page can continue with the next card instead
        // of leaving a large unused block at the bottom of a page.
        margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 20),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('LEXORA', style: pw.TextStyle(font: bold, fontSize: size(11))),
              pw.Text('${entries.length} entries / 词条 · ${DateFormat('yyyy-MM-dd').format(date)}',
                  style: pw.TextStyle(fontSize: size(8), color: PdfColors.grey600)),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(fontSize: size(8), color: PdfColors.grey600)),
        ),
        build: (context) => [
          pw.Text('My vocabulary book',
              style: pw.TextStyle(font: bold, fontSize: size(24), color: PdfColors.indigo900)),
          pw.SizedBox(height: 2),
          pw.Text('我的双语词汇册',
              style: pw.TextStyle(fontSize: size(11), color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          ..._entryLayout(
            entries,
            bold,
            ipa,
            resolvedTypography,
            twoColumns: useTwoColumns,
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
    required bool twoColumns,
  }) {
    if (!twoColumns) {
      return [
        for (var index = 0; index < entries.length; index++) ...[
          _entry(
            index + 1,
            entries[index],
            bold,
            ipa,
            typography,
          ),
          if (index != entries.length - 1) pw.SizedBox(height: 7),
        ],
      ];
    }

    const columnGap = 6.0;
    const horizontalMargin = 24.0;
    final columnWidth =
        (PdfPageFormat.a4.width - horizontalMargin * 2 - columnGap) / 2;

    // GridView lays out complete rows.  When one card is taller than its
    // neighbour, that row reserves the taller card's height and creates the
    // conspicuous blank area visible in the exported PDF.  Wrap is a
    // SpanningWidget, so it keeps the two-column presentation while allowing
    // the next card to continue naturally on the next page.
    return [
      pw.Wrap(
        spacing: columnGap,
        runSpacing: 5,
        crossAxisAlignment: pw.WrapCrossAlignment.start,
        children: [
          for (var index = 0; index < entries.length; index++)
            pw.SizedBox(
              width: columnWidth,
              child: _entry(
                index + 1,
                entries[index],
                bold,
                ipa,
                typography,
              ),
            ),
        ],
      ),
    ];
  }

  pw.Widget _entry(
    int number,
    WordEntry entry,
    pw.Font bold,
    pw.Font ipa,
    PdfTypography typography,
  ) {
    pw.Widget pill(String text, PdfColor color) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: typography.related),
          ),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300, width: .5),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('$number', style: pw.TextStyle(fontSize: typography.related, color: PdfColors.grey600)),
          pw.SizedBox(width: 7),
          pw.Expanded(child: pw.Text(entry.word, style: pw.TextStyle(font: bold, fontSize: typography.word))),
          pill(entry.difficulty, PdfColors.indigo100),
          pw.SizedBox(width: 5),
          pill('freq ${entry.frequency.toStringAsFixed(1)}', PdfColors.teal100),
        ]),
        pw.SizedBox(height: 3),
        pw.Wrap(crossAxisAlignment: pw.WrapCrossAlignment.center, children: [
          pw.Text('US 美式  ', style: pw.TextStyle(fontSize: typography.phonetic - 1, color: PdfColors.grey700)),
          pw.Text(entry.usPhonetic,
              style: pw.TextStyle(font: ipa, fontSize: typography.phonetic, color: PdfColors.grey700)),
          pw.SizedBox(width: 10),
          pw.Text('UK 英式  ', style: pw.TextStyle(fontSize: typography.phonetic - 1, color: PdfColors.grey700)),
          pw.Text(entry.ukPhonetic,
              style: pw.TextStyle(font: ipa, fontSize: typography.phonetic, color: PdfColors.grey700)),
        ]),
        pw.SizedBox(height: 3),
        pw.Text(entry.definition, style: pw.TextStyle(fontSize: typography.definition)),
        pw.SizedBox(height: 2),
        pw.Text(entry.definitionZh,
            style: pw.TextStyle(font: bold, fontSize: typography.definition, color: PdfColors.indigo900)),
        if (entry.synonyms.isNotEmpty || entry.antonyms.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          if (entry.synonyms.isNotEmpty) ...[
            pw.Text('Synonyms / 近义词  ${entry.synonyms.join(' · ')}',
                style: pw.TextStyle(fontSize: typography.related)),
            if (entry.synonymsZh.isNotEmpty && entry.synonymsZh != '—')
              pw.Text(entry.synonymsZh,
                  style: pw.TextStyle(fontSize: typography.related, color: PdfColors.indigo700)),
          ],
          if (entry.antonyms.isNotEmpty) ...[
            if (entry.synonyms.isNotEmpty) pw.SizedBox(height: 2),
            pw.Text('Antonyms / 反义词  ${entry.antonyms.join(' · ')}',
                style: pw.TextStyle(fontSize: typography.related)),
            if (entry.antonymsZh.isNotEmpty && entry.antonymsZh != '—')
              pw.Text(entry.antonymsZh,
                  style: pw.TextStyle(fontSize: typography.related, color: PdfColors.indigo700)),
          ],
        ],
        if (entry.examples.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Container(
            padding: const pw.EdgeInsets.only(left: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: PdfColors.teal400, width: 2)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entry.examples.length; i++) ...[
                  if (i > 0) pw.SizedBox(height: 4),
                  pw.Text(entry.examples[i], style: pw.TextStyle(font: bold, fontSize: typography.example)),
                  pw.SizedBox(height: 1),
                  pw.Text(entry.examplesZh[i], style: pw.TextStyle(fontSize: typography.example)),
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
      ]),
    );
  }
}
