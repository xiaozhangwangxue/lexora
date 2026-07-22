import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PDF reader keeps the low-paint viewer configuration', () {
    final reader = File(
      'lib/screens/pdf_reader_screen.dart',
    ).readAsStringSync();
    final shell = File('lib/screens/shell_screen.dart').readAsStringSync();

    expect(reader, contains('pageDropShadow: null'));
    expect(reader, contains('limitRenderingCache: true'));
    expect(reader, contains('onePassRenderingSizeThreshold: 1440'));
    expect(shell, contains('transitionDuration: isPdf'));
    expect(shell, contains('allowSnapshotting: !isPdf'));
  });
}
