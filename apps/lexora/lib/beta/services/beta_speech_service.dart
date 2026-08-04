import 'package:flutter_tts/flutter_tts.dart';

import '../models/learning_models.dart';

class BetaSpeechService {
  BetaSpeechService._();

  static final instance = BetaSpeechService._();
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> speak(
    String text, {
    required PreferredAccent accent,
    required double rate,
  }) async {
    if (text.trim().isEmpty) throw StateError('没有可朗读的内容');
    await stop();
    if (!_configured) {
      await _tts.awaitSpeakCompletion(true);
      _configured = true;
    }
    await _tts.setLanguage(accent == PreferredAccent.uk ? 'en-GB' : 'en-US');
    await _tts.setSpeechRate((rate / 2).clamp(.3, .65));
    final result = await _tts.speak(text);
    if (result != 1) throw StateError('系统语音暂时无法播放');
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Speech failures never block the learning flow.
    }
  }
}
