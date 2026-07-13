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
  small(.86),
  medium(1),
  large(1.18);

  const PdfFontSize(this.scale);
  final double scale;
}

class PdfService {
  late final Future<pw.Font> _regularFont = PdfGoogleFonts.notoSansSCRegular();
  late final Future<pw.Font> _boldFont = PdfGoogleFonts.notoSansSCBold();
  late final Future<pw.Font> _ipaFont = PdfGoogleFonts.notoSansRegular();

  Future<GeneratedBook> create(
    List<WordEntry> entries, {
    PdfFontSize fontSize = PdfFontSize.medium,
  }) async {
    final now = DateTime.now();
    final bytes = await buildBytes(
      entries,
      fontSize: fontSize,
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
    DateTime? generatedAt,
  }) async {
    final date = generatedAt ?? DateTime.now();
    final fonts = await Future.wait([_regularFont, _boldFont, _ipaFont]);
    final regular = fonts[0];
    final bold = fonts[1];
    // Noto Sans SC does not contain the complete IPA Extensions block. Keep it
    // for Chinese text, and explicitly render phonetics with Noto Sans.
    final ipa = fonts[2];
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
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 26),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
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
          pw.SizedBox(height: 12),
          ..._entryLayout(
            entries,
            bold,
            ipa,
            fontSize.scale,
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
    double scale, {
    required bool twoColumns,
  }) {
    if (!twoColumns) {
      return [
        for (var index = 0; index < entries.length; index++) ...[
          _entry(index + 1, entries[index], bold, ipa, scale),
          if (index != entries.length - 1) pw.SizedBox(height: 7),
        ],
      ];
    }

    final rows = <pw.Widget>[];
    for (var index = 0; index < entries.length; index += 2) {
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _entry(index + 1, entries[index], bold, ipa, scale),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: index + 1 < entries.length
                  ? _entry(
                      index + 2,
                      entries[index + 1],
                      bold,
                      ipa,
                      scale,
                    )
                  : pw.SizedBox(),
            ),
          ],
        ),
      );
      if (index + 2 < entries.length) rows.add(pw.SizedBox(height: 8));
    }
    return rows;
  }

  pw.Widget _entry(
    int number,
    WordEntry entry,
    pw.Font bold,
    pw.Font ipa,
    double scale,
  ) {
    double size(double value) => value * scale;
    pw.Widget pill(String text, PdfColor color) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Text(text, style: pw.TextStyle(fontSize: size(7))),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300, width: .5),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('$number', style: pw.TextStyle(fontSize: size(8), color: PdfColors.grey600)),
          pw.SizedBox(width: 7),
          pw.Expanded(child: pw.Text(entry.word, style: pw.TextStyle(font: bold, fontSize: size(18)))),
          pill(entry.difficulty, PdfColors.indigo100),
          pw.SizedBox(width: 5),
          pill('freq ${entry.frequency.toStringAsFixed(1)}', PdfColors.teal100),
        ]),
        pw.SizedBox(height: 3),
        pw.Wrap(crossAxisAlignment: pw.WrapCrossAlignment.center, children: [
          pw.Text('US 美式  ', style: pw.TextStyle(fontSize: size(8), color: PdfColors.grey700)),
          pw.Text(entry.usPhonetic,
              style: pw.TextStyle(font: ipa, fontSize: size(9), color: PdfColors.grey700)),
          pw.SizedBox(width: 10),
          pw.Text('UK 英式  ', style: pw.TextStyle(fontSize: size(8), color: PdfColors.grey700)),
          pw.Text(entry.ukPhonetic,
              style: pw.TextStyle(font: ipa, fontSize: size(9), color: PdfColors.grey700)),
        ]),
        pw.SizedBox(height: 5),
        pw.Text(entry.definition, style: pw.TextStyle(fontSize: size(8.7))),
        pw.SizedBox(height: 2),
        pw.Text(entry.definitionZh,
            style: pw.TextStyle(font: bold, fontSize: size(8.7), color: PdfColors.indigo900)),
        if (entry.synonyms.isNotEmpty || entry.antonyms.isNotEmpty) ...[
          pw.SizedBox(height: 5),
          if (entry.synonyms.isNotEmpty) ...[
            pw.Text('Synonyms / 近义词  ${entry.synonyms.join(' · ')}',
                style: pw.TextStyle(fontSize: size(7.2))),
            if (entry.synonymsZh.isNotEmpty && entry.synonymsZh != '—')
              pw.Text(entry.synonymsZh,
                  style: pw.TextStyle(fontSize: size(7.2), color: PdfColors.indigo700)),
          ],
          if (entry.antonyms.isNotEmpty) ...[
            if (entry.synonyms.isNotEmpty) pw.SizedBox(height: 2),
            pw.Text('Antonyms / 反义词  ${entry.antonyms.join(' · ')}',
                style: pw.TextStyle(fontSize: size(7.2))),
            if (entry.antonymsZh.isNotEmpty && entry.antonymsZh != '—')
              pw.Text(entry.antonymsZh,
                  style: pw.TextStyle(fontSize: size(7.2), color: PdfColors.indigo700)),
          ],
        ],
        if (entry.examples.isNotEmpty) ...[
          pw.SizedBox(height: 5),
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
                  pw.Text(entry.examples[i], style: pw.TextStyle(font: bold, fontSize: size(7.2))),
                  pw.SizedBox(height: 1),
                  pw.Text(entry.examplesZh[i], style: pw.TextStyle(fontSize: size(7.2))),
                ],
              ],
            ),
          ),
        ],
        if (entry.phrases.isNotEmpty) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            'Phrases / 常用短语',
            style: pw.TextStyle(
              font: bold,
              fontSize: size(7.4),
              color: PdfColors.indigo900,
            ),
          ),
          pw.SizedBox(height: 2),
          for (var i = 0; i < entry.phrases.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 3),
            pw.Text(
              entry.phrases[i].phrase,
              style: pw.TextStyle(font: bold, fontSize: size(7.2)),
            ),
            pw.Text(
              entry.phrases[i].meaning,
              style: pw.TextStyle(fontSize: size(7)),
            ),
            pw.Text(
              entry.phrases[i].meaningZh,
              style: pw.TextStyle(
                fontSize: size(7),
                color: PdfColors.indigo700,
              ),
            ),
          ],
        ],
      ]),
    );
  }
}
