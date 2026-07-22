import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collapsed macOS sidebar centers the doubled application icon', () {
    final source = File(
      'packaging/macos/MainFlutterWindow.swift',
    ).readAsStringSync();

    expect(source, contains('.frame(width: 68, height: 68)'));
    expect(
      source,
      contains(
        '.frame(maxWidth: .infinity, alignment: expanded ? .leading : .center)',
      ),
    );
    expect(source, contains('.frame(width: expanded ? 218 : 96)'));
  });
}
