import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/services/document_import_service.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = DocumentImportService();

  test('plain text import keeps one normalized term per line', () async {
    final result = await service.extractBytes(
      fileName: 'words.txt',
      bytes: Uint8List.fromList(
        utf8.encode('Apple\n2. take off\nAPPLE\nnot,a,term\nwell-being\n'),
      ),
    );

    expect(result.terms, ['apple', 'take off', 'well-being']);
    expect(result.duplicateLineCount, 1);
    expect(result.invalidLineCount, 1);
  });

  test('DOCX import preserves Word paragraphs as separate entries', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'word/document.xml',
          '''<?xml version="1.0" encoding="UTF-8"?>
          <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
              <w:p><w:r><w:t>Serendipity</w:t></w:r></w:p>
              <w:p><w:r><w:t>break the ice</w:t></w:r></w:p>
            </w:body>
          </w:document>''',
        ),
      );
    final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));

    final result = await service.extractBytes(
      fileName: 'vocabulary.docx',
      bytes: bytes,
    );

    expect(result.terms, ['serendipity', 'break the ice']);
  });

  test('legacy DOC compatibility reads UTF-16LE word-list runs', () async {
    final content = 'apple\r\nbanana\r\ntake off\r\n';
    final bytes = <int>[0xd0, 0xcf, 0x11, 0xe0];
    for (final code in content.codeUnits) {
      bytes
        ..add(code)
        ..add(0);
    }

    final result = await service.extractBytes(
      fileName: 'legacy.doc',
      bytes: Uint8List.fromList(bytes),
    );

    expect(result.terms, containsAll(['apple', 'banana', 'take off']));
  });

  test(
    'PDF import extracts selectable text by line',
    () async {
      final document = pw.Document()
        ..addPage(
          pw.Page(
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [pw.Text('apple'), pw.Text('take off')],
            ),
          ),
        );
      final bytes = await document.save();

      final result = await service.extractBytes(
        fileName: 'vocabulary.pdf',
        bytes: bytes,
      );

      expect(result.terms, containsAll(['apple', 'take off']));
    },
    skip: 'pdfrx native assets are only bundled in built applications',
  );
}
