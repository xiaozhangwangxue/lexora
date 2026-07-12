import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../models/word_entry.dart';

class PdfService {
  Future<GeneratedBook> create(List<WordEntry> entries) async {
    final regular = await PdfGoogleFonts.notoSansSCRegular();
    final bold = await PdfGoogleFonts.notoSansSCBold();
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
              pw.Text('LEXORA', style: pw.TextStyle(font: bold, fontSize: 11)),
              pw.Text('${entries.length} words / 单词 · ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (context) => [
          pw.Text('My vocabulary book',
              style: pw.TextStyle(font: bold, fontSize: 27, color: PdfColors.indigo900)),
          pw.SizedBox(height: 4),
          pw.Text('我的双语词汇册',
              style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
          pw.SizedBox(height: 20),
          ...entries.asMap().entries.map((indexed) => _entry(indexed.key + 1, indexed.value, bold)),
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

  pw.Widget _entry(int number, WordEntry entry, pw.Font bold) {
    pw.Widget pill(String text, PdfColor color) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 7)),
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
          pw.Text('$number', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: pw.Text(entry.word, style: pw.TextStyle(font: bold, fontSize: 20))),
          pill(entry.difficulty, PdfColors.indigo100),
          pw.SizedBox(width: 5),
          pill('freq ${entry.frequency.toStringAsFixed(1)}', PdfColors.teal100),
        ]),
        pw.SizedBox(height: 5),
        pw.Text('US 美式 ${entry.usPhonetic}    UK 英式 ${entry.ukPhonetic}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 8),
        pw.Text(entry.definition, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 3),
        pw.Text(entry.definitionZh,
            style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.indigo900)),
        if (entry.synonyms.isNotEmpty || entry.antonyms.isNotEmpty) ...[
          pw.SizedBox(height: 7),
          pw.Text('Synonyms / 近义词  ${entry.synonyms.join(' · ')}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text(entry.synonymsZh, style: const pw.TextStyle(fontSize: 8, color: PdfColors.indigo700)),
          pw.Text('Antonyms / 反义词  ${entry.antonyms.isEmpty ? '—' : entry.antonyms.join(' · ')}',
              style: const pw.TextStyle(fontSize: 8)),
          pw.Text(entry.antonymsZh, style: const pw.TextStyle(fontSize: 8, color: PdfColors.indigo700)),
        ],
        if (entry.example.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.only(left: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: PdfColors.teal400, width: 2)),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(entry.example, style: pw.TextStyle(font: bold, fontSize: 8)),
              pw.SizedBox(height: 2),
              pw.Text(entry.exampleZh, style: const pw.TextStyle(fontSize: 8)),
            ]),
          ),
        ],
      ]),
    );
  }
}
