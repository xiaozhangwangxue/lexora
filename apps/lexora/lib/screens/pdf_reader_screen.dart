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
    final surface = Theme.of(context).colorScheme.surface;
    return Scaffold(
      // macOS uses a transparent app theme for the Liquid Glass shell. The
      // reader must still be an opaque route, otherwise the generation list
      // underneath bleeds through beside the PDF page.
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(book.title),
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
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
      body: ColoredBox(
        color: surface,
        child: PdfViewer.file(
          book.path,
          params: PdfViewerParams(
            backgroundColor: surface,
            // Fit the complete A4 page on first open. Users can still zoom
            // and pan, but no part of the page is cut off by a narrow window.
            calculateInitialZoom: (_, __, fitZoom, ___) => fitZoom,
            scrollByMouseWheel: .24,
          ),
        ),
      ),
    );
  }
}
