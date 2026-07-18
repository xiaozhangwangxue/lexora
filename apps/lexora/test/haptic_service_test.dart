import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/services/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') calls.add(call);
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('plays restrained Android feedback for drag and generation', () async {
    const haptics = HapticService();

    await haptics.dragStarted();
    await haptics.itemReordered();
    await haptics.generationStarted();
    await haptics.generationCompleted();

    expect(calls.map((call) => call.arguments), [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.successNotification',
      'HapticFeedbackType.selectionClick',
    ]);
  });

  test('does not play Lexora haptics on non-Android platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    const haptics = HapticService();

    await haptics.dragStarted();
    await haptics.itemReordered();
    await haptics.generationStarted();
    await haptics.generationCompleted();

    expect(calls, isEmpty);
  });
}
