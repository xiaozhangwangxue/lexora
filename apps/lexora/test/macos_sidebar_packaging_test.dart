import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collapsed macOS sidebar and window chrome stay usable', () {
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
    expect(
      source,
      contains('let sidebarWidth: CGFloat = expanded ? 218 : 112'),
    );
    expect(source, contains('minSize = NSSize(width: 980, height: 680)'));
    expect(source, contains('WindowChromeBridge('));
    expect(source, contains('(sidebarWidth - groupWidth) / 2'));
    expect(source, contains('isLiveResizing || reduceMotion'));
    expect(source, contains('LexoraBackdrop(simplified: isLiveResizing)'));
  });

  test('macOS release declares photo-library usage before image export', () {
    final workflow = File(
      '../../.github/workflows/build-release.yml',
    ).readAsStringSync();

    expect(workflow, contains('NSPhotoLibraryUsageDescription'));
    expect(workflow, contains('NSPhotoLibraryAddUsageDescription'));
  });
}
