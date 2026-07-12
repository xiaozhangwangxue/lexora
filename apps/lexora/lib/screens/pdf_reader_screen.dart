import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';

import '../l10n/app_localizations.dart';
import '../models/word_entry.dart';

class PdfReaderScreen extends StatelessWidget {
  const PdfReaderScreen({super.key, required this.book});
  final GeneratedBook book;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).print,
            icon: const Icon(Icons.print_outlined),
            onPressed: () async {
              final bytes = await File(book.path).readAsBytes();
              await Printing.layoutPdf(name: book.title, onLayout: (_) async => bytes);
            },
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).share,
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final bytes = await File(book.path).readAsBytes();
              await Printing.sharePdf(bytes: bytes, filename: book.title);
            },
          ),
        ],
      ),
      body: PdfViewer.file(book.path),
    );
  }
}
