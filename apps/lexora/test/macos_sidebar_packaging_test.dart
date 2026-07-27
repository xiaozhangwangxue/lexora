import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collapsed macOS sidebar and window chrome stay usable', () {
    final source = File(
      'packaging/macos/MainFlutterWindow.swift',
    ).readAsStringSync();

    expect(source, contains('.frame(width: 36, height: 36)'));
    expect(
      source,
      contains(
        '.frame(maxWidth: .infinity, alignment: expanded ? .leading : .center)',
      ),
    );
    expect(
      source,
      contains('let sidebarWidth: CGFloat = expanded ? 224 : 112'),
    );
    expect(source, contains('minSize = NSSize(width: 980, height: 680)'));
    expect(source, contains('WindowChromeBridge('));
    expect(source, contains('(sidebarWidth - groupWidth) / 2'));
    expect(source, contains('isLiveResizing || reduceMotion'));
    expect(source, contains('.background(LexoraBackdrop())'));
    expect(source, contains('LegacyVisualEffect(material: .sidebar)'));
    expect(source, isNot(contains('.padding(5)')));
    expect(source, isNot(contains('simplified: isLiveResizing')));
  });

  test('macOS release declares photo-library usage before image export', () {
    final workflow = File(
      '../../.github/workflows/build-release.yml',
    ).readAsStringSync();

    expect(workflow, contains('NSPhotoLibraryUsageDescription'));
    expect(workflow, contains('NSPhotoLibraryAddUsageDescription'));
  });
}
