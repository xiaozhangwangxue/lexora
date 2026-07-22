import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('image reader keeps native two-finger zoom enabled', () async {
    final source = await File(
      'lib/screens/pdf_reader_screen.dart',
    ).readAsString();

    expect(source, contains('PhotoViewGallery.builder('));
    expect(source, contains('PhotoView('));
    expect(source, contains('maxScale: PhotoViewComputedScale.covered * 5'));
    expect(source, contains('enableRotation: false'));
  });
}
