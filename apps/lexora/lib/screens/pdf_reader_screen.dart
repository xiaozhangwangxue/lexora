import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/word_entry.dart';

/// A unified vocabulary-book reader. PDF uses the native PDF engine while
/// EPUB and DOCX use Lexora's semantic sidecar, so all three formats keep the
/// same in-app navigation, sharing and pinch-to-zoom experience.
class PdfReaderScreen extends StatelessWidget {
  const PdfReaderScreen({super.key, required this.book});
  final GeneratedBook book;

  @override
  Widget build(BuildContext context) => switch (book.format) {
    BookFormat.pdf => _PdfBookReader(book: book),
    BookFormat.epub || BookFormat.docx => _EditableBookReader(book: book),
    BookFormat.images || BookFormat.longImage => _ImageBookReader(book: book),
  };
}

class _ImageBookReader extends StatefulWidget {
  const _ImageBookReader({required this.book});

  final GeneratedBook book;

  @override
  State<_ImageBookReader> createState() => _ImageBookReaderState();
}

class _ImageBookReaderState extends State<_ImageBookReader> {
  final _pageController = PageController();
  late final List<PhotoViewController> _photoControllers = [
    for (final _ in widget.book.allPaths) PhotoViewController(),
  ];
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _photoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paths = widget.book.allPaths;
    final strings = AppLocalizations.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final isLong = widget.book.format == BookFormat.longImage;
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          isLong || paths.length <= 1
              ? widget.book.title
              : '${widget.book.title}  ${_page + 1}/${paths.length}',
        ),
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: strings.share,
            onPressed: () => Share.shareXFiles([
              for (final path in paths) XFile(path, mimeType: 'image/png'),
            ], subject: strings.vocabularyBook),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: RepaintBoundary(
        child: isLong
            ? PhotoView(
                key: ValueKey(paths.first),
                imageProvider: FileImage(File(paths.first)),
                controller: _photoControllers.first,
                backgroundDecoration: BoxDecoration(color: surface),
                initialScale: PhotoViewComputedScale.covered,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 5,
                enableRotation: false,
                filterQuality: FilterQuality.medium,
              )
            : PhotoViewGallery.builder(
                pageController: _pageController,
                backgroundDecoration: BoxDecoration(color: surface),
                scrollPhysics: const ClampingScrollPhysics(),
                enableRotation: false,
                itemCount: paths.length,
                onPageChanged: (value) {
                  if (_page != value) setState(() => _page = value);
                },
                builder: (context, index) => PhotoViewGalleryPageOptions(
                  imageProvider: FileImage(File(paths[index])),
                  controller: _photoControllers[index],
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained * .9,
                  maxScale: PhotoViewComputedScale.covered * 5,
                  filterQuality: FilterQuality.medium,
                ),
              ),
      ),
    );
  }
}

class _PdfBookReader extends StatelessWidget {
  const _PdfBookReader({required this.book});

  final GeneratedBook book;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Scaffold(
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
              await Printing.layoutPdf(
                name: book.title,
                onLayout: (_) async => bytes,
              );
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
      body: RepaintBoundary(
        child: ColoredBox(
          color: surface,
          child: PdfViewer.file(
            book.path,
            params: PdfViewerParams(
              backgroundColor: surface,
              // A blurred shadow is repainted around every visible page while
              // scrolling and zooming. The surrounding surface already
              // separates pages, so removing it materially lowers GPU work.
              pageDropShadow: null,
              limitRenderingCache: true,
              onePassRenderingSizeThreshold: 1440,
              maxImageBytesCachedOnMemory: 64 * 1024 * 1024,
              horizontalCacheExtent: .35,
              verticalCacheExtent: .75,
              scrollPhysics: const ClampingScrollPhysics(),
              scaleByPointerScale: .82,
              sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
                calculateInitialZoom: (_, __, fitZoom, ___) => fitZoom,
              ),
              scrollByMouseWheel: .24,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableBookReader extends StatefulWidget {
  const _EditableBookReader({required this.book});

  final GeneratedBook book;

  @override
  State<_EditableBookReader> createState() => _EditableBookReaderState();
}

class _EditableBookReaderState extends State<_EditableBookReader> {
  late final Future<List<WordEntry>> _entries = _loadEntries();
  final _transformation = TransformationController();

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  Future<List<WordEntry>> _loadEntries() async {
    final path = widget.book.contentPath;
    if (path == null) return const [];
    final file = File(path);
    if (!await file.exists()) return const [];
    return compute(_decodeReaderEntries, await file.readAsString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final surface = theme.colorScheme.surface;
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(widget.book.title),
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: strings.openExternally,
            onPressed: () => OpenFilex.open(widget.book.path),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
          IconButton(
            tooltip: strings.share,
            onPressed: () => Share.shareXFiles([
              XFile(widget.book.path, mimeType: widget.book.format.mimeType),
            ], subject: strings.vocabularyBook),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<WordEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const [];
          if (entries.isEmpty) {
            return Center(child: Text(strings.readerContentUnavailable));
          }
          return GestureDetector(
            onDoubleTap: () => _transformation.value = Matrix4.identity(),
            child: InteractiveViewer(
              transformationController: _transformation,
              minScale: .75,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(80),
              constrained: true,
              panEnabled: true,
              scaleEnabled: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEXORA',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.vocabularyBook,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 720 ? 2 : 1;
                            final width = columns == 1
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 10) / 2;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (
                                  var index = 0;
                                  index < entries.length;
                                  index++
                                )
                                  SizedBox(
                                    width: width,
                                    child: _EntryCard(
                                      number: index + 1,
                                      entry: entries[index],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

List<WordEntry> _decodeReaderEntries(String source) {
  final data = jsonDecode(source) as Map<String, dynamic>;
  return (data['entries'] as List? ?? const [])
      .whereType<Map>()
      .map((item) => WordEntry.fromJson(item.cast<String, dynamic>()))
      .toList();
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.number, required this.entry});

  final int number;
  final WordEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$number', style: theme.textTheme.labelSmall),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.word,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (entry.isFuzzyMatch)
                        Text(
                          '(${entry.originalTerm})',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                    ],
                  ),
                ),
                _Pill(text: entry.difficulty),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'US 美式  ${entry.usPhonetic}    UK 英式  ${entry.ukPhonetic}',
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
            const SizedBox(height: 5),
            Text(entry.definition),
            Text(
              entry.definitionZh,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (entry.synonyms.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text('Synonyms / 近义词  ${entry.synonyms.join(' · ')}'),
              if (entry.synonymsZh.isNotEmpty)
                Text(
                  entry.synonymsZh,
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
            ],
            if (entry.antonyms.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Antonyms / 反义词  ${entry.antonyms.join(' · ')}'),
              if (entry.antonymsZh.isNotEmpty)
                Text(
                  entry.antonymsZh,
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
            ],
            if (entry.examples.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.teal.shade400, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (
                      var index = 0;
                      index < entry.examples.length;
                      index++
                    ) ...[
                      Text(
                        entry.examples[index],
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (index < entry.examplesZh.length)
                        Text(entry.examplesZh[index]),
                      if (index + 1 < entry.examples.length)
                        const SizedBox(height: 5),
                    ],
                  ],
                ),
              ),
            ],
            if (entry.phrases.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Phrases / 常用短语',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              for (final phrase in entry.phrases) ...[
                const SizedBox(height: 3),
                Text(
                  phrase.phrase,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(phrase.meaning),
                Text(
                  phrase.meaningZh,
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: Theme.of(context).textTheme.labelSmall),
  );
}
