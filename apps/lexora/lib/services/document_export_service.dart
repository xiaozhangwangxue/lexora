import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
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
  }) async {
    final now = DateTime.now();
    final id = const Uuid().v4();
    final directory = await getApplicationDocumentsDirectory();
    final stem = 'lexora-${DateFormat('yyyyMMdd-HHmm').format(now)}';
    final title = '$stem.${format.extension}';
    final file = File('${directory.path}/$title');
    final bytes = switch (format) {
      BookFormat.pdf => await _pdfService.buildBytes(
        entries,
        fontSize: fontSize,
        typography: typography,
        pageSize: pageSize,
        generatedAt: now,
      ),
      BookFormat.docx => await buildDocxBytes(
        entries,
        fontSize: fontSize,
        typography: typography,
        pageSize: pageSize,
        generatedAt: now,
      ),
      BookFormat.epub => buildEpubBytes(
        entries,
        fontSize: fontSize,
        typography: typography,
        pageSize: pageSize,
        generatedAt: now,
      ),
    };
    await file.writeAsBytes(bytes, flush: true);
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
    );
  }

  Future<Uint8List> buildDocxBytes(
    List<WordEntry> entries, {
    PdfFontSize fontSize = PdfFontSize.medium,
    PdfTypography? typography,
    BookPageSize pageSize = BookPageSize.a4,
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
    add('word/document.xml', _docxDocument(entries, date, type, pageSize));
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

  Uint8List buildEpubBytes(
    List<WordEntry> entries, {
    PdfFontSize fontSize = PdfFontSize.medium,
    PdfTypography? typography,
    BookPageSize pageSize = BookPageSize.a4,
    DateTime? generatedAt,
  }) {
    final date = generatedAt ?? DateTime.now();
    final type = typography ?? PdfTypography.fromPreset(fontSize);
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
          _epubDocument(entries, date, type),
        ),
      )
      ..addFile(
        ArchiveFile.string('EPUB/style.css', _epubStyles(type, pageSize)),
      );
    return Uint8List.fromList(ZipEncoder().encode(archive, level: 6));
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
        '<article class="entry"><header><span class="number">${index + 1}</span><div><h2>${_xml(entry.word)}</h2>'
        '${entry.isFuzzyMatch ? '<p class="original">(${_xml(entry.originalTerm!)})</p>' : ''}</div>'
        '<span class="pill">${_xml(entry.difficulty)}</span><span class="pill frequency">freq ${entry.frequency.toStringAsFixed(1)}</span></header>'
        '<p class="phonetic">US 美式&#160; ${_xml(entry.usPhonetic)} &#160;&#160; UK 英式&#160; ${_xml(entry.ukPhonetic)}</p>'
        '<p>${_xml(entry.definition)}</p><p class="zh strong">${_xml(entry.definitionZh)}</p>',
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
        '<body><main><div class="brand">LEXORA</div><h1>My vocabulary book</h1>'
        '<p class="subtitle">我的双语词汇册 · ${entries.length} entries / 词条 · ${DateFormat('yyyy-MM-dd').format(date)}</p>'
        '<section class="grid">$cards</section></main></body></html>';
  }

  static String _epubStyles(PdfTypography type, BookPageSize pageSize) {
    final columns = exportColumnCount(pageSize, type);
    return '''
@charset "utf-8";
@page { size: ${pageSize.cssName}; margin: 10mm; }
:root { color: #17181c; background: #fff; font-family: system-ui, -apple-system, "Noto Sans CJK SC", sans-serif; }
body { margin: 0; } main { max-width: 1080px; margin: 0 auto; padding: 1.2rem; }
.brand { font-size: .78rem; font-weight: 800; letter-spacing: .08em; } h1 { color: #243a8f; margin: .18rem 0; font-size: 2rem; }
.subtitle { color: #737780; margin: 0 0 1rem; }.grid { display: grid; grid-template-columns: repeat($columns,minmax(0,1fr)); gap: .55rem; align-items: start; }
.entry { break-inside: avoid; background: #f6f7f9; border: 1px solid #d9dce2; border-radius: .7rem; padding: .72rem; }
.entry header { display: flex; align-items: flex-start; gap: .45rem; }.entry h2 { font-size: ${type.word}px; line-height: 1.05; margin: 0; }.number,.original,.phonetic,.subtitle { color:#737780; }
.original { font-size: ${type.related}px; margin:.1rem 0 0; }.pill { margin-left:auto; border-radius: 999px; background:#dfe3ff; color:#303c75; padding:.22rem .46rem; font-size:${type.related}px; white-space:nowrap; }.pill + .pill { margin-left:0; }.frequency{background:#d8f4ed;color:#1b6458;}
p { font-size:${type.definition}px; line-height:1.34; margin:.28rem 0; }.phonetic { font-size:${type.phonetic}px; }.zh { color:#3450a4; }.strong{font-weight:700;}.compact,.compact *,.phrases,.phrases p { font-size:${type.related}px; }.examples { border-left:3px solid #34bfa3; padding-left:.48rem; }.examples,.examples * { font-size:${type.example}px; }
@media (max-width: 680px) { .grid { grid-template-columns: 1fr; } main { padding:.8rem; } }
''';
  }

  static String _epubPackage(DateTime date) =>
      '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="book-id">urn:uuid:${const Uuid().v4()}</dc:identifier><dc:title>Lexora Vocabulary Book</dc:title><dc:language>zh-CN</dc:language><dc:creator>Lexora</dc:creator><meta property="dcterms:modified">${DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(date.toUtc())}</meta></metadata>
<manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="book" href="book.xhtml" media-type="application/xhtml+xml"/><item id="css" href="style.css" media-type="text/css"/></manifest><spine><itemref idref="book"/></spine></package>''';

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
