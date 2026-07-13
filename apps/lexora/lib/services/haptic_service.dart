import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps Lexora's tactile feedback subtle and Android-only.
class HapticService {
  const HapticService();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> dragStarted() => _play(HapticFeedback.selectionClick);

  Future<void> itemReordered() => _play(HapticFeedback.lightImpact);

  Future<void> generationStarted() => _play(HapticFeedback.mediumImpact);

  Future<void> generationCompleted() async {
    if (!_isAndroid) return;
    try {
      // Android 11+ gets the native confirmation pulse. The small tick that
      // follows also acts as a gentle fallback on older Android versions.
      await HapticFeedback.successNotification();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await HapticFeedback.selectionClick();
    } on PlatformException {
      // Haptics should never interrupt PDF generation or navigation.
    } on MissingPluginException {
      // Some test or embedded environments do not expose platform haptics.
    }
  }

  Future<void> _play(Future<void> Function() feedback) async {
    if (!_isAndroid) return;
    try {
      await feedback();
    } on PlatformException {
      // Haptics are an enhancement, so silently preserve the primary action.
    } on MissingPluginException {
      // Some test or embedded environments do not expose platform haptics.
    }
  }
}
