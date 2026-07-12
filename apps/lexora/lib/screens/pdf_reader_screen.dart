import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/word_entry.dart';

class PdfReaderScreen extends StatelessWidget {
  const PdfReaderScreen({super.key, required this.book});
  final GeneratedBook book;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: PdfPreview(
        build: (_) async => Uint8List.fromList(await File(book.path).readAsBytes()),
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: book.title,
      ),
    );
  }
}
