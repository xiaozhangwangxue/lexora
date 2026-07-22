import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';

import '../models/word_entry.dart';
import 'pdf_service.dart';

class DocumentExportService {
  DocumentExportService({PdfService? pdfService})
    : _pdfService = pdfService ?? PdfService();

  final PdfService _pdfService;

  Future<GeneratedBook> create(
    List<WordEntry> entries, {
    required BookFormat format,
    required PdfFontSize fontSize,
    required PdfTypography typography,
    required BookPageSize pageSize,
    bool smartReorder = false,
  }) async {
    final now = DateTime.now();
    final id = const Uuid().v4();
    final directory = await getApplicationDocumentsDirectory();
    final stem = 'lexora-${DateFormat('yyyyMMdd-HHmmss').format(now)}';
    final pdfBytes =
        (format == BookFormat.images || format == BookFormat.longImage)
        ? await _pdfService.buildBytes(
            entries,
            fontSize: fontSize,
            typography: typography,
            pageSize: pageSize,
            smartReorder: smartReorder,
            showPageFurniture: format != BookFormat.longImage,
            generatedAt: now,
          )
        : null;
    final imagePaths = switch (format) {
      BookFormat.images => await _writePageImages(
        pdfBytes!,
        directory,
        stem,
        pageSize,
      ),
      BookFormat.longImage => [
        await _writeLongImage(pdfBytes!, directory, stem, pageSize),
      ],
      _ => <String>[],
    };
    final title = switch (format) {
      BookFormat.images => '$stem-images.png',
      BookFormat.longImage => '$stem-long.png',
      _ => '$stem.${format.extension}',
    };
    final file = File(
      imagePaths.isNotEmpty ? imagePaths.first : '${directory.path}/$title',
    );
    final bytes = switch (format) {
      BookFormat.pdf => await _pdfService.buildBytes(
        entries,
        fontSize: fontSize,
        typography: typography,
        pageSize: pageSize,
        smartReorder: smartReorder,
        generatedAt: now,
      ),
      BookFormat.docx => await buildDocxBytes(
        entries,
        fontSize: fontSize,
        typography: typography,
        pageSize: pageSize,
        smartReorder: smartReorder,
        generatedAt: now,
      ),
      BookFormat.epub => await buildEpubBytes(
        entries,
        fontSize: fontSize,
        typography: typography,
        pageSize: pageSize,
        smartReorder: smartReorder,
        generatedAt: now,
      ),
      BookFormat.images || BookFormat.longImage => null,
    };
    if (bytes != null) await file.writeAsBytes(bytes, flush: true);
    final contentFile = File('${directory.path}/$stem.lexora.json');
    await contentFile.writeAsString(
      jsonEncode({
        'version': 1,
        'generatedAt': now.toIso8601String(),
        'entries': entries.map((entry) => entry.toJson()).toList(),
      }),
      encoding: utf8,
      flush: true,
    );
    return GeneratedBook(
      id: id,
      title: title,
      path: file.path,
      createdAt: now,
      wordCount: entries.length,
      previewWords: entries.map((entry) => entry.word).take(6).toList(),
      format: format,
      contentPath: contentFile.path,
      paths: imagePaths,
    );
  }

  Future<List<String>> _writePageImages(
    Uint8List pdfBytes,
    Directory directory,
    String stem,
    BookPageSize pageSize,
  ) async {
    final pages = await _renderPdfPages(pdfBytes, pageSize);
    if (pages.isEmpty) {
      throw StateError(
        'Lexora could not render the generated pages as images.',
      );
    }
    final paths = <String>[];
    for (var index = 0; index < pages.length; index++) {
      final suffix = (index + 1).toString().padLeft(2, '0');
      final path = '${directory.path}/$stem-page-$suffix.png';
      await File(
        path,
      ).writeAsBytes(image_lib.encodePng(pages[index]), flush: true);
      paths.add(path);
      await _saveToGallery(path);
    }
    return paths;
  }

  Future<String> _writeLongImage(
    Uint8List pdfBytes,
    Directory directory,
    String stem,
    BookPageSize pageSize,
  ) async {
    final pages = await _renderPdfPages(pdfBytes, pageSize);
    if (pages.isEmpty) {
      throw StateError('Lexora could not render the generated long image.');
    }
    final compactPages = [
      for (final page in pages)
        image_lib.trim(
          page,
          mode: image_lib.TrimMode.topLeftColor,
          sides: image_lib.Trim.top | image_lib.Trim.bottom,
          fuzzy: .015,
          padding: 18,
        ),
    ];
    final width = compactPages.fold<int>(
      0,
      (value, page) => page.width > value ? page.width : value,
    );
    final gapCount = (compactPages.length - 1).clamp(0, 1000000);
    final height =
        compactPages.fold<int>(0, (value, page) => value + page.height) +
        gapCount * 8;
    final output = image_lib.Image(
      width: width,
      height: height,
      numChannels: 4,
    );
    image_lib.fill(output, color: image_lib.ColorRgba8(255, 255, 255, 255));
    var y = 0;
    for (final page in compactPages) {
      image_lib.compositeImage(
        output,
        page,
        dstX: (width - page.width) ~/ 2,
        dstY: y,
      );
      y += page.height + 8;
    }
    final path = '${directory.path}/$stem-long.png';
    await File(path).writeAsBytes(image_lib.encodePng(output), flush: true);
    await _saveToGallery(path);
    return path;
  }

  Future<List<image_lib.Image>> _renderPdfPages(
    Uint8List bytes,
    BookPageSize pageSize,
  ) async {
    final targetWidth = switch (pageSize) {
      BookPageSize.a4 => 1240,
      BookPageSize.a5 => 874,
      BookPageSize.b5 => 1039,
    };
    final document = await PdfDocument.openData(
      bytes,
      sourceName: 'lexora-image-${const Uuid().v4()}',
    );
    try {
      final output = <image_lib.Image>[];
      for (final page in document.pages) {
        final rendered = await page.render(
          fullWidth: targetWidth.toDouble(),
          fullHeight: targetWidth * page.height / page.width,
        );
        if (rendered == null) continue;
        try {
          output.add(rendered.createImageNF());
        } finally {
          rendered.dispose();
        }
      }
      return output;
    } finally {
      await document.dispose();
    }
  }

  Future<void> _saveToGallery(String path) async {
    try {
      await Gal.putImage(path, album: 'Lexora');
    } catch (_) {
      // The export remains available in Generated records on platforms that
      // do not expose a system photo library or deny photo permissions.
    }
  }

  Future<Uint8List> buildDocxBytes(
    List<WordEntry> entries, {
    PdfFontSize fontSize = PdfFontSize.medium,
    PdfTypography? typography,
    BookPageSize pageSize = BookPageSize.a4,
    bool smartReorder = false,
    DateTime? generatedAt,
  }) async {
    final date = generatedAt ?? DateTime.now();
    final type = typography ?? PdfTypography.fromPreset(fontSize);
    final archive = Archive();
    void add(String name, String value) =>
        archive.addFile(ArchiveFile.string(name, value));

    add('[Content_Types].xml', _docxContentTypes);
    add('_rels/.rels', _docxRootRelationships);
    add('docProps/core.xml', _docxCore(date));
    add('docProps/app.xml', _docxApp);
    add('word/_rels/document.xml.rels', _docxDocumentRelationships);
    add('word/_rels/fontTable.xml.rels', _docxFontRelationships);
    add('word/fontTable.xml', _docxFontTable);
    add('word/styles.xml', _docxStyles(type));
    final orderedEntries = smartReorder ? _smartOrder(entries) : entries;
    add(
      'word/document.xml',
      _docxDocument(orderedEntries, date, type, pageSize),
    );
    final latinFont = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final chineseFont = await rootBundle.load(
      'assets/fonts/NotoSansSC-Regular.ttf',
    );
    archive.addFile(
      ArchiveFile.bytes(
        'word/fonts/NotoSans.odttf',
        _obfuscateFont(
          latinFont.buffer.asUint8List(
            latinFont.offsetInBytes,
            latinFont.lengthInBytes,
          ),
          'a1b2c3d4e5f6478899aabbccddeeff01',
        ),
      ),
    );
    archive.addFile(
      ArchiveFile.bytes(
        'word/fonts/NotoSansSC.odttf',
        _obfuscateFont(
          chineseFont.buffer.asUint8List(
            chineseFont.offsetInBytes,
            chineseFont.lengthInBytes,
          ),
          'b2c3d4e5f6074899aabbccddeeff0123',
        ),
      ),
    );
    return Uint8List.fromList(ZipEncoder().encode(archive, level: 6));
  }

  static Uint8List _obfuscateFont(Uint8List source, String keyHex) {
    final output = Uint8List.fromList(source);
    final key = Uint8List(16);
    for (var index = 0; index < key.length; index++) {
      final offset = index * 2;
      key[index] = int.parse(keyHex.substring(offset, offset + 2), radix: 16);
    }
    for (var index = 0; index < 32 && index < output.length; index++) {
      output[index] ^= key[15 - (index % 16)];
    }
    return output;
  }

  Future<Uint8List> buildEpubBytes(
    List<WordEntry> entries, {
    PdfFontSize fontSize = PdfFontSize.medium,
    PdfTypography? typography,
    BookPageSize pageSize = BookPageSize.a4,
    bool smartReorder = false,
    DateTime? generatedAt,
  }) async {
    final date = generatedAt ?? DateTime.now();
    final type = typography ?? PdfTypography.fromPreset(fontSize);
    final orderedEntries = smartReorder ? _smartOrder(entries) : entries;
    final latinFont = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final chineseFont = await rootBundle.load(
      'assets/fonts/NotoSansSC-Regular.ttf',
    );
    final archive = Archive()
      ..addFile(
        ArchiveFile.noCompress(
          'mimetype',
          'application/epub+zip'.length,
          utf8.encode('application/epub+zip'),
        ),
      )
      ..addFile(ArchiveFile.string('META-INF/container.xml', _epubContainer))
      ..addFile(ArchiveFile.string('EPUB/package.opf', _epubPackage(date)))
      ..addFile(ArchiveFile.string('EPUB/nav.xhtml', _epubNavigation))
      ..addFile(
        ArchiveFile.string(
          'EPUB/book.xhtml',
          _epubDocument(orderedEntries, date, type),
        ),
      )
      ..addFile(
        ArchiveFile.string('EPUB/style.css', _epubStyles(type, pageSize)),
      )
      ..addFile(
        ArchiveFile.bytes(
          'EPUB/fonts/NotoSans-Regular.ttf',
          latinFont.buffer.asUint8List(
            latinFont.offsetInBytes,
            latinFont.lengthInBytes,
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'EPUB/fonts/NotoSansSC-Regular.ttf',
          chineseFont.buffer.asUint8List(
            chineseFont.offsetInBytes,
            chineseFont.lengthInBytes,
          ),
        ),
      );
    return Uint8List.fromList(ZipEncoder().encode(archive, level: 6));
  }

  static List<WordEntry> _smartOrder(List<WordEntry> entries) =>
      entries.toList()
        ..sort((a, b) => _entryWeight(b).compareTo(_entryWeight(a)));

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

  static String _xml(String value) => const HtmlEscape(
    HtmlEscapeMode.element,
  ).convert(value).replaceAll('&#39;', '&apos;');

  static String _paragraph(
    String text, {
    String style = 'Body',
    bool bold = false,
    String? color,
    double? size,
    bool keepNext = false,
  }) {
    if (text.trim().isEmpty) return '';
    final escapedText = _xml(
      text,
    ).replaceAll('\n', '</w:t><w:br/><w:t xml:space="preserve">');
    final sizeXml = size == null
        ? ''
        : '<w:sz w:val="${(size * 2).round()}"/><w:szCs w:val="${(size * 2).round()}"/>';
    final colorXml = color == null ? '' : '<w:color w:val="$color"/>';
    return '<w:p><w:pPr><w:pStyle w:val="$style"/>'
        '${keepNext ? '<w:keepNext/>' : ''}</w:pPr><w:r><w:rPr>'
        '<w:rFonts w:ascii="Noto Sans" w:hAnsi="Noto Sans" w:eastAsia="Noto Sans SC" w:cs="Noto Sans"/><w:lang w:val="en-US" w:eastAsia="zh-CN"/>'
        '${bold ? '<w:b/><w:bCs/>' : ''}$colorXml$sizeXml</w:rPr>'
        '<w:t xml:space="preserve">$escapedText</w:t></w:r></w:p>';
  }

  static String _entryCell(
    WordEntry entry,
    int number,
    PdfTypography type,
    int width,
  ) {
    final related = entry.synonyms.isEmpty && entry.antonyms.isEmpty
        ? ''
        : '${entry.synonyms.isEmpty ? '' : 'Synonyms / 近义词  ${entry.synonyms.join(' · ')}${entry.synonymsZh.isEmpty ? '' : '\n${entry.synonymsZh}'}'}'
              '${entry.synonyms.isNotEmpty && entry.antonyms.isNotEmpty ? '\n' : ''}'
              '${entry.antonyms.isEmpty ? '' : 'Antonyms / 反义词  ${entry.antonyms.join(' · ')}${entry.antonymsZh.isEmpty ? '' : '\n${entry.antonymsZh}'}'}';
    final examples = <String>[];
    for (var index = 0; index < entry.examples.length; index++) {
      examples.add(entry.examples[index]);
      if (index < entry.examplesZh.length) {
        examples.add(entry.examplesZh[index]);
      }
    }
    final phrases = <String>[];
    for (final phrase in entry.phrases) {
      phrases.add('${phrase.phrase}\n${phrase.meaning}\n${phrase.meaningZh}');
    }
    return '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/>'
        '<w:shd w:fill="F6F7F9"/><w:tcBorders><w:top w:val="single" w:sz="18" w:color="FFFFFF"/>'
        '<w:left w:val="single" w:sz="18" w:color="FFFFFF"/><w:bottom w:val="single" w:sz="18" w:color="FFFFFF"/>'
        '<w:right w:val="single" w:sz="18" w:color="FFFFFF"/></w:tcBorders>'
        '<w:tcMar><w:top w:w="100" w:type="dxa"/>'
        '<w:left w:w="140" w:type="dxa"/><w:bottom w:w="100" w:type="dxa"/>'
        '<w:right w:w="140" w:type="dxa"/></w:tcMar></w:tcPr>'
        '${_paragraph('$number  ${entry.word}', style: 'EntryTitle', bold: true, size: type.word, keepNext: true)}'
        '${entry.isFuzzyMatch ? _paragraph('(${entry.originalTerm})', style: 'Meta', color: '737780', size: type.related) : ''}'
        '${_paragraph('${entry.difficulty}   ·   freq ${entry.frequency.toStringAsFixed(1)}', style: 'Meta', color: '4E5B8C', size: type.related)}'
        '${_paragraph('US 美式  ${entry.usPhonetic}    UK 英式  ${entry.ukPhonetic}', style: 'Phonetic', color: '5C6270', size: type.phonetic)}'
        '${_paragraph(entry.definition, size: type.definition)}'
        '${_paragraph(entry.definitionZh, style: 'Chinese', bold: true, color: '243A8F', size: type.definition)}'
        '${_paragraph(related, style: 'Compact', size: type.related)}'
        '${_paragraph(examples.join('\n'), style: 'Example', size: type.example)}'
        '${_paragraph(phrases.isEmpty ? '' : 'Phrases / 常用短语\n${phrases.join('\n')}', style: 'Compact', size: type.phrase)}'
        '</w:tc>';
  }

  static String _docxDocument(
    List<WordEntry> entries,
    DateTime date,
    PdfTypography type,
    BookPageSize pageSize,
  ) {
    final columns = exportColumnCount(pageSize, type);
    final margin = pageSize.marginTwips;
    final usableWidth = pageSize.widthTwips - margin * 2;
    final cellWidth = usableWidth ~/ columns;
    final rows = StringBuffer();
    for (var index = 0; index < entries.length; index += columns) {
      rows.write('<w:tr><w:trPr><w:cantSplit/></w:trPr>');
      for (var column = 0; column < columns; column++) {
        final entryIndex = index + column;
        if (entryIndex < entries.length) {
          rows.write(
            _entryCell(entries[entryIndex], entryIndex + 1, type, cellWidth),
          );
        } else {
          rows.write(
            '<w:tc><w:tcPr><w:tcW w:w="$cellWidth" w:type="dxa"/></w:tcPr><w:p/></w:tc>',
          );
        }
      }
      rows.write('</w:tr>');
    }
    final grid = List.filled(columns, '<w:gridCol w:w="$cellWidth"/>').join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>${_paragraph('LEXORA', style: 'Brand', bold: true, size: 11)}'
        '${_paragraph('My vocabulary book', style: 'Title', bold: true, color: '243A8F', size: 24)}'
        '${_paragraph('我的双语词汇册  ·  ${entries.length} entries / 词条  ·  ${DateFormat('yyyy-MM-dd').format(date)}', style: 'Subtitle', color: '737780', size: 10)}'
        '<w:tbl><w:tblPr><w:tblW w:w="$usableWidth" w:type="dxa"/><w:tblLayout w:type="fixed"/>'
        '<w:tblCellMar><w:top w:w="60" w:type="dxa"/><w:left w:w="60" w:type="dxa"/>'
        '<w:bottom w:w="60" w:type="dxa"/><w:right w:w="60" w:type="dxa"/></w:tblCellMar>'
        '<w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/>'
        '<w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>'
        '</w:tblPr><w:tblGrid>$grid</w:tblGrid>$rows</w:tbl>'
        '<w:sectPr><w:pgSz w:w="${pageSize.widthTwips}" w:h="${pageSize.heightTwips}"/><w:pgMar w:top="$margin" w:right="$margin" w:bottom="$margin" w:left="$margin" w:header="280" w:footer="280" w:gutter="0"/></w:sectPr>'
        '</w:body></w:document>';
  }

  static String _docxStyles(PdfTypography type) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Noto Sans" w:hAnsi="Noto Sans" w:eastAsia="Noto Sans SC" w:cs="Noto Sans"/><w:lang w:val="en-US" w:eastAsia="zh-CN"/><w:sz w:val="${(type.definition * 2).round()}"/></w:rPr></w:rPrDefault>'
      '<w:pPrDefault><w:pPr><w:spacing w:before="0" w:after="32" w:line="240" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
      '${_style('Body', after: 32)}${_style('Brand', after: 20)}${_style('Title', after: 20)}'
      '${_style('Subtitle', after: 100)}${_style('EntryTitle', after: 20)}${_style('Meta', after: 20)}'
      '${_style('Phonetic', after: 24)}${_style('Chinese', after: 28)}${_style('Compact', after: 24)}'
      '${_style('Example', after: 28, left: 90, border: true)}</w:styles>';

  static String _style(
    String id, {
    required int after,
    int left = 0,
    bool border = false,
  }) =>
      '<w:style w:type="paragraph" w:styleId="$id"><w:name w:val="$id"/>'
      '<w:pPr><w:spacing w:before="0" w:after="$after" w:line="240" w:lineRule="auto"/>'
      '${left == 0 ? '' : '<w:ind w:left="$left"/>'}'
      '${border ? '<w:pBdr><w:left w:val="single" w:sz="12" w:space="5" w:color="34BFA3"/></w:pBdr>' : ''}'
      '</w:pPr></w:style>';

  static String _epubDocument(
    List<WordEntry> entries,
    DateTime date,
    PdfTypography type,
  ) {
    final cards = StringBuffer();
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      cards.write(
        '<article class="entry"><p class="number">${index + 1}</p>'
        '<h2 xml:lang="en">${_xml(entry.word)}</h2>'
        '${entry.isFuzzyMatch ? '<p class="original">(${_xml(entry.originalTerm!)})</p>' : ''}'
        '<p class="meta"><span>${_xml(entry.difficulty)}</span><span>freq ${entry.frequency.toStringAsFixed(1)}</span></p>'
        '<p class="phonetic"><span>US 美式</span> ${_xml(entry.usPhonetic)}<br/><span>UK 英式</span> ${_xml(entry.ukPhonetic)}</p>'
        '<p xml:lang="en">${_xml(entry.definition)}</p><p class="zh strong" xml:lang="zh-CN">${_xml(entry.definitionZh)}</p>',
      );
      if (entry.synonyms.isNotEmpty) {
        cards.write(
          '<p class="compact"><strong>Synonyms / 近义词</strong>&#160; ${_xml(entry.synonyms.join(' · '))}<br/><span class="zh">${_xml(entry.synonymsZh)}</span></p>',
        );
      }
      if (entry.antonyms.isNotEmpty) {
        cards.write(
          '<p class="compact"><strong>Antonyms / 反义词</strong>&#160; ${_xml(entry.antonyms.join(' · '))}<br/><span class="zh">${_xml(entry.antonymsZh)}</span></p>',
        );
      }
      if (entry.examples.isNotEmpty) {
        cards.write('<div class="examples">');
        for (var item = 0; item < entry.examples.length; item++) {
          cards.write(
            '<p><strong>${_xml(entry.examples[item])}</strong><br/><span class="zh">${item < entry.examplesZh.length ? _xml(entry.examplesZh[item]) : ''}</span></p>',
          );
        }
        cards.write('</div>');
      }
      if (entry.phrases.isNotEmpty) {
        cards.write('<div class="phrases"><strong>Phrases / 常用短语</strong>');
        for (final phrase in entry.phrases) {
          cards.write(
            '<p><strong>${_xml(phrase.phrase)}</strong><br/>${_xml(phrase.meaning)}<br/><span class="zh">${_xml(phrase.meaningZh)}</span></p>',
          );
        }
        cards.write('</div>');
      }
      cards.write('</article>');
    }
    return '<?xml version="1.0" encoding="utf-8"?>'
        '<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en"><head>'
        '<meta charset="utf-8"/><meta name="viewport" content="width=device-width"/>'
        '<title>Lexora vocabulary book</title><link rel="stylesheet" href="style.css"/></head>'
        '<body><main><p class="brand">LEXORA</p><h1>My vocabulary book</h1>'
        '<p class="subtitle">我的双语词汇册 · ${entries.length} entries / 词条 · ${DateFormat('yyyy-MM-dd').format(date)}</p>'
        '<section class="entries">$cards</section></main></body></html>';
  }

  static String _epubStyles(PdfTypography type, BookPageSize pageSize) {
    return '''
@charset "utf-8";
@font-face { font-family: "Lexora Latin"; src: url("fonts/NotoSans-Regular.ttf"); }
@font-face { font-family: "Lexora Chinese"; src: url("fonts/NotoSansSC-Regular.ttf"); }
@page { size: ${pageSize.cssName}; margin: 9mm; }
html, body { margin: 0; padding: 0; }
body { font-family: "Lexora Chinese", "Lexora Latin", sans-serif; font-size: ${type.definition}pt; line-height: 1.38; text-align: left !important; -webkit-hyphens: none; hyphens: none; }
main { margin: 0 auto; padding: 9mm; max-width: 46em; }
.brand { margin: 0; font-size: 8pt; font-weight: bold; letter-spacing: .08em; }
h1 { margin: 2pt 0; font-size: 20pt; line-height: 1.12; text-align: left !important; }
.subtitle { margin: 0 0 10pt; font-size: 8pt; opacity: .72; }
.entry { display: block; margin: 0 0 7pt; padding: 7pt; border: .6pt solid #d9dce2; page-break-inside: avoid; break-inside: avoid; text-align: left !important; }
.entry p, .entry h2 { text-align: left !important; overflow-wrap: break-word; word-break: normal; -webkit-hyphens: none; hyphens: none; }
.entry h2 { display: block; margin: 0 0 2pt; font-size: ${type.word}pt; line-height: 1.08; }
.number { float: left; width: 1.8em; margin: 1pt 4pt 0 0 !important; font-size: ${type.related}pt !important; opacity: .68; }
.original { margin: 0 0 2pt 2em !important; font-size: ${type.related}pt !important; opacity: .7; }
.meta { clear: both; margin: 2pt 0 !important; font-size: ${type.related}pt !important; }
.meta span { display: inline-block; margin-right: 10pt; }
p { margin: 2.5pt 0; font-size: ${type.definition}pt; }
.phonetic { clear: both; font-family: "Lexora Latin", "Lexora Chinese", sans-serif; font-size: ${type.phonetic}pt !important; opacity: .76; }
.phonetic span { font-family: "Lexora Chinese", sans-serif; }
.zh { color: #3450a4; }.strong { font-weight: bold; }
.compact, .compact *, .phrases, .phrases p { font-size: ${type.related}pt; }
.examples { margin: 4pt 0; padding-left: 6pt; border-left: 2pt solid #34bfa3; }
.examples, .examples * { font-size: ${type.example}pt; }
.phrases { margin-top: 4pt; }
''';
  }

  static String _epubPackage(DateTime date) =>
      '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="book-id">urn:uuid:${const Uuid().v4()}</dc:identifier><dc:title>Lexora Vocabulary Book</dc:title><dc:language>zh-CN</dc:language><dc:creator>Lexora</dc:creator><meta property="dcterms:modified">${DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(date.toUtc())}</meta></metadata>
<manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="book" href="book.xhtml" media-type="application/xhtml+xml"/><item id="css" href="style.css" media-type="text/css"/><item id="latin-font" href="fonts/NotoSans-Regular.ttf" media-type="font/ttf"/><item id="chinese-font" href="fonts/NotoSansSC-Regular.ttf" media-type="font/ttf"/></manifest><spine><itemref idref="book"/></spine></package>''';

  static const _epubContainer = '''<?xml version="1.0" encoding="utf-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="EPUB/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>''';
  static const _epubNavigation = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head><body><nav epub:type="toc"><h1>Contents</h1><ol><li><a href="book.xhtml">Vocabulary book</a></li></ol></nav></body></html>''';
  static const _docxContentTypes =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="odttf" ContentType="application/vnd.openxmlformats-officedocument.obfuscatedFont"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>''';
  static const _docxRootRelationships =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>''';
  static const _docxDocumentRelationships =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/></Relationships>''';
  static const _docxFontRelationships =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/font" Target="fonts/NotoSans.odttf"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/font" Target="fonts/NotoSansSC.odttf"/></Relationships>''';
  static const _docxFontTable =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:font w:name="Noto Sans"><w:family w:val="swiss"/><w:charset w:val="00"/><w:embedRegular r:id="rId1" w:fontKey="{A1B2C3D4-E5F6-4788-99AA-BBCCDDEEFF01}"/></w:font><w:font w:name="Noto Sans SC"><w:family w:val="swiss"/><w:charset w:val="86"/><w:embedRegular r:id="rId2" w:fontKey="{B2C3D4E5-F607-4899-AABB-CCDDEEFF0123}"/></w:font></w:fonts>''';
  static String _docxCore(DateTime date) =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>Lexora Vocabulary Book</dc:title><dc:creator>Lexora</dc:creator><dcterms:created xsi:type="dcterms:W3CDTF">${date.toUtc().toIso8601String()}</dcterms:created></cp:coreProperties>''';
  static const _docxApp =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Lexora</Application></Properties>''';
}
