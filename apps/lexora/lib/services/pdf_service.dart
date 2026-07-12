import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../models/word_entry.dart';

enum PdfFontSize {
  small(1),
  medium(1.18),
  large(1.38);

  const PdfFontSize(this.scale);
  final double scale;
}

class PdfService {
  Future<GeneratedBook> create(
    List<WordEntry> entries, {
    PdfFontSize fontSize = PdfFontSize.medium,
  }) async {
    final regular = await PdfGoogleFonts.notoSansSCRegular();
    final bold = await PdfGoogleFonts.notoSansSCBold();
    // Noto Sans SC does not contain the complete IPA Extensions block. Keep it
    // for Chinese text, and explicitly render phonetics with Noto Sans.
    final ipa = await PdfGoogleFonts.notoSansRegular();
    double size(double value) => value * fontSize.scale;
    final document = pw.Document(
      title: 'Lexora Vocabulary Book',
      author: 'Lexora',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('LEXORA', style: pw.TextStyle(font: bold, fontSize: size(11))),
              pw.Text('${entries.length} words / 单词 · ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
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
              style: pw.TextStyle(font: bold, fontSize: size(27), color: PdfColors.indigo900)),
          pw.SizedBox(height: 4),
          pw.Text('我的双语词汇册',
              style: pw.TextStyle(fontSize: size(13), color: PdfColors.grey700)),
          pw.SizedBox(height: 20),
          ...entries.asMap().entries.map(
                (indexed) => _entry(
                  indexed.key + 1,
                  indexed.value,
                  bold,
                  ipa,
                  fontSize.scale,
                ),
              ),
        ],
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final id = const Uuid().v4();
    final filename = 'lexora-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.pdf';
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(await document.save(), flush: true);
    return GeneratedBook(
      id: id,
      title: filename,
      path: file.path,
      createdAt: DateTime.now(),
      wordCount: entries.length,
    );
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
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300, width: .5),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('$number', style: pw.TextStyle(fontSize: size(8), color: PdfColors.grey600)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: pw.Text(entry.word, style: pw.TextStyle(font: bold, fontSize: size(20)))),
          pill(entry.difficulty, PdfColors.indigo100),
          pw.SizedBox(width: 5),
          pill('freq ${entry.frequency.toStringAsFixed(1)}', PdfColors.teal100),
        ]),
        pw.SizedBox(height: 5),
        pw.Wrap(crossAxisAlignment: pw.WrapCrossAlignment.center, children: [
          pw.Text('US 美式  ', style: pw.TextStyle(fontSize: size(8), color: PdfColors.grey700)),
          pw.Text(entry.usPhonetic,
              style: pw.TextStyle(font: ipa, fontSize: size(9), color: PdfColors.grey700)),
          pw.SizedBox(width: 16),
          pw.Text('UK 英式  ', style: pw.TextStyle(fontSize: size(8), color: PdfColors.grey700)),
          pw.Text(entry.ukPhonetic,
              style: pw.TextStyle(font: ipa, fontSize: size(9), color: PdfColors.grey700)),
        ]),
        pw.SizedBox(height: 8),
        pw.Text(entry.definition, style: pw.TextStyle(fontSize: size(10))),
        pw.SizedBox(height: 3),
        pw.Text(entry.definitionZh,
            style: pw.TextStyle(font: bold, fontSize: size(10), color: PdfColors.indigo900)),
        if (entry.synonyms.isNotEmpty || entry.antonyms.isNotEmpty) ...[
          pw.SizedBox(height: 7),
          pw.Text('Synonyms / 近义词  ${entry.synonyms.join(' · ')}', style: pw.TextStyle(fontSize: size(8))),
          pw.Text(entry.synonymsZh, style: pw.TextStyle(fontSize: size(8), color: PdfColors.indigo700)),
          pw.Text('Antonyms / 反义词  ${entry.antonyms.isEmpty ? '—' : entry.antonyms.join(' · ')}',
              style: pw.TextStyle(fontSize: size(8))),
          pw.Text(entry.antonymsZh, style: pw.TextStyle(fontSize: size(8), color: PdfColors.indigo700)),
        ],
        if (entry.examples.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.only(left: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: PdfColors.teal400, width: 2)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entry.examples.length; i++) ...[
                  if (i > 0) pw.SizedBox(height: 6),
                  pw.Text(entry.examples[i], style: pw.TextStyle(font: bold, fontSize: size(8))),
                  pw.SizedBox(height: 2),
                  pw.Text(entry.examplesZh[i], style: pw.TextStyle(fontSize: size(8))),
                ],
              ],
            ),
          ),
        ],
      ]),
    );
  }
}
