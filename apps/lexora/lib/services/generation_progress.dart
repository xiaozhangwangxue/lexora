import 'package:flutter/foundation.dart';

enum GenerationStage { idle, lookingUp, typesetting, completed, failed }

class GenerationProgress extends ChangeNotifier {
  GenerationStage _stage = GenerationStage.idle;
  int _completed = 0;
  int _total = 0;
  String _currentTerm = '';
  String _error = '';

  GenerationStage get stage => _stage;
  int get completed => _completed;
  int get total => _total;
  String get currentTerm => _currentTerm;
  String get error => _error;
  bool get isRunning =>
      _stage == GenerationStage.lookingUp ||
      _stage == GenerationStage.typesetting;
  bool get isVisible => _stage != GenerationStage.idle;

  double get value => switch (_stage) {
        GenerationStage.idle => 0,
        GenerationStage.lookingUp =>
          _total == 0
              ? 0
              : (_completed / _total * .88).clamp(0, .88).toDouble(),
        GenerationStage.typesetting => .94,
        GenerationStage.completed => 1,
        GenerationStage.failed => 1,
      };

  void start(int total) {
    _stage = GenerationStage.lookingUp;
    _completed = 0;
    _total = total;
    _currentTerm = '';
    _error = '';
    notifyListeners();
  }

  void updateLookup(int completed, int total, String term) {
    _stage = GenerationStage.lookingUp;
    _completed = completed;
    _total = total;
    _currentTerm = term;
    notifyListeners();
  }

  void typesetting() {
    _stage = GenerationStage.typesetting;
    _currentTerm = '';
    notifyListeners();
  }

  void complete() {
    _stage = GenerationStage.completed;
    _completed = _total;
    _currentTerm = '';
    notifyListeners();
  }

  void fail(String error) {
    _stage = GenerationStage.failed;
    _error = error;
    _currentTerm = '';
    notifyListeners();
  }

  void reset() {
    _stage = GenerationStage.idle;
    _completed = 0;
    _total = 0;
    _currentTerm = '';
    _error = '';
    notifyListeners();
  }
}
