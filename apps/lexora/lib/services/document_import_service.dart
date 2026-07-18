import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

class DocumentImportException implements Exception {
  const DocumentImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DocumentImportResult {
  const DocumentImportResult({
    required this.terms,
    required this.nonEmptyLineCount,
    required this.invalidLineCount,
    required this.duplicateLineCount,
  });

  final List<String> terms;
  final int nonEmptyLineCount;
  final int invalidLineCount;
  final int duplicateLineCount;
}

/// Extracts one English word or phrase per line from common document formats.
///
/// DOCX/ODT and text formats are parsed in Dart. PDF text comes from the same
/// pdfrx engine used by Lexora's reader. Legacy binary DOC files do not have a
/// stable cross-platform parser, so a conservative compatibility extractor is
/// used for plain English lists stored as ANSI or UTF-16LE text runs.
class DocumentImportService {
  const DocumentImportService();

  static const supportedExtensions = <String>{
    'txt',
    'text',
    'md',
    'markdown',
    'csv',
    'tsv',
    'rtf',
    'doc',
    'docx',
    'odt',
    'pdf',
  };

  static final RegExp _validTerm = RegExp(
    r"^[a-z][a-z'-]*(?:\s+[a-z][a-z'-]*)*$",
    caseSensitive: false,
  );

  Future<DocumentImportResult> extractBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw const DocumentImportException('The selected file is empty.');
    }
    final extension = _extensionOf(fileName);
    if (!supportedExtensions.contains(extension)) {
      throw DocumentImportException(
        'Unsupported file type: ${extension.isEmpty ? fileName : '.$extension'}',
      );
    }

    final text = switch (extension) {
      'docx' => _extractDocx(bytes),
      'odt' => _extractOdt(bytes),
      'pdf' => await _extractPdf(bytes, fileName),
      'doc' => _extractLegacyDoc(bytes),
      'rtf' => _extractRtf(bytes),
      _ => _decodePlainText(bytes),
    };
    return parseLines(text);
  }

  DocumentImportResult parseLines(String text) {
    final terms = <String>[];
    final seen = <String>{};
    var nonEmpty = 0;
    var invalid = 0;
    var duplicates = 0;

    for (final rawLine
        in text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      var line = rawLine
          .replaceAll('\u0000', '')
          .replaceAll('’', "'")
          .replaceAll('‘', "'")
          .trim();
      if (line.isEmpty) continue;
      nonEmpty++;
      line = line
          .replaceFirst(RegExp(r'^\s*(?:(?:[-*•·‣▪])|(?:\d{1,5}[.)、]))\s*'), '')
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ');
      if (!_validTerm.hasMatch(line) || line.length > 120) {
        invalid++;
        continue;
      }
      if (!seen.add(line)) {
        duplicates++;
        continue;
      }
      terms.add(line);
    }

    return DocumentImportResult(
      terms: terms,
      nonEmptyLineCount: nonEmpty,
      invalidLineCount: invalid,
      duplicateLineCount: duplicates,
    );
  }

  String _extensionOf(String fileName) {
    final name = fileName.toLowerCase();
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1);
  }

  String _decodePlainText(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }
    return utf8.decode(bytes, allowMalformed: true).replaceFirst('\ufeff', '');
  }

  String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
    final codes = <int>[];
    for (var index = 0; index + 1 < bytes.length; index += 2) {
      codes.add(
        littleEndian
            ? bytes[index] | (bytes[index + 1] << 8)
            : (bytes[index] << 8) | bytes[index + 1],
      );
    }
    return String.fromCharCodes(codes);
  }

  String _extractDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final document = archive.findFile('word/document.xml');
      if (document == null) {
        throw const DocumentImportException(
          'This DOCX file does not contain a Word document body.',
        );
      }
      return _paragraphText(utf8.decode(document.content));
    } on DocumentImportException {
      rethrow;
    } catch (error) {
      throw DocumentImportException('Could not read the DOCX file: $error');
    }
  }

  String _extractOdt(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final content = archive.findFile('content.xml');
      if (content == null) {
        throw const DocumentImportException(
          'This ODT file does not contain document text.',
        );
      }
      return _paragraphText(utf8.decode(content.content));
    } on DocumentImportException {
      rethrow;
    } catch (error) {
      throw DocumentImportException('Could not read the ODT file: $error');
    }
  }

  String _paragraphText(String source) {
    final document = XmlDocument.parse(source);
    final lines = <String>[];
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'p') continue;
      final buffer = StringBuffer();
      for (final descendant in element.descendants) {
        if (descendant is XmlText) {
          buffer.write(descendant.value);
        } else if (descendant is XmlElement &&
            (descendant.name.local == 'tab' || descendant.name.local == 'br')) {
          buffer.write(' ');
        }
      }
      final line = buffer.toString().trim();
      if (line.isNotEmpty) lines.add(line);
    }
    return lines.join('\n');
  }

  Future<String> _extractPdf(Uint8List bytes, String fileName) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openData(bytes, sourceName: fileName);
      final text = StringBuffer();
      for (final page in document.pages) {
        final pageText = await page.loadText();
        if (pageText == null || pageText.fullText.trim().isEmpty) continue;
        if (text.isNotEmpty) text.writeln();
        text.write(pageText.fullText);
      }
      if (text.toString().trim().isEmpty) {
        throw const DocumentImportException(
          'No selectable text was found in this PDF. Scanned PDFs need OCR first.',
        );
      }
      return text.toString();
    } on DocumentImportException {
      rethrow;
    } catch (error) {
      throw DocumentImportException('Could not extract PDF text: $error');
    } finally {
      await document?.dispose();
    }
  }

  String _extractRtf(Uint8List bytes) {
    var text = _decodePlainText(bytes);
    text = text.replaceAllMapped(
      RegExp(r"\\'([0-9a-fA-F]{2})"),
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    );
    text = text
        .replaceAll(RegExp(r'\\par[d]?\b\s*', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'\\line\b\s*', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'\\tab\b\s*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\\[a-zA-Z]+-?\d*\s?'), '')
        .replaceAll(RegExp(r'[{}]'), '');
    return text;
  }

  String _extractLegacyDoc(Uint8List bytes) {
    final candidates = <String>[];

    // Word 97-2003 commonly stores the visible text as UTF-16LE runs.
    final utf16Buffer = StringBuffer();
    void flushUtf16() {
      final value = utf16Buffer.toString();
      if (value.trim().length >= 2) candidates.add(value);
      utf16Buffer.clear();
    }

    for (var index = 0; index + 1 < bytes.length; index += 2) {
      final low = bytes[index];
      final high = bytes[index + 1];
      if (high == 0 &&
          (low == 9 || low == 10 || low == 13 || (low >= 32 && low <= 126))) {
        utf16Buffer.writeCharCode(low);
      } else {
        flushUtf16();
      }
    }
    flushUtf16();

    // Older/"compressed" DOC pieces can also be stored as 8-bit runs.
    final ansiBuffer = StringBuffer();
    void flushAnsi() {
      final value = ansiBuffer.toString();
      if (value.trim().length >= 2) candidates.add(value);
      ansiBuffer.clear();
    }

    for (final byte in bytes) {
      if (byte == 9 ||
          byte == 10 ||
          byte == 13 ||
          (byte >= 32 && byte <= 126)) {
        ansiBuffer.writeCharCode(byte);
      } else {
        flushAnsi();
      }
    }
    flushAnsi();

    final useful = candidates
        .where((value) => value.contains('\n') || value.contains('\r'))
        .join('\n');
    if (useful.trim().isEmpty) {
      throw const DocumentImportException(
        'Could not read this legacy DOC file. Save it as DOCX or TXT and try again.',
      );
    }
    return useful;
  }
}
