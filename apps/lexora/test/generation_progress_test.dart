import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/services/generation_progress.dart';

void main() {
  test('generation progress moves lookup and typesetting into one timeline', () {
    final progress = GenerationProgress();

    progress.start(4);
    expect(progress.isRunning, isTrue);
    expect(progress.value, 0);

    progress.updateLookup(2, 4, 'take off');
    expect(progress.currentTerm, 'take off');
    expect(progress.value, closeTo(.44, .001));

    progress.typesetting();
    expect(progress.stage, GenerationStage.typesetting);
    expect(progress.value, .94);

    progress.complete();
    expect(progress.isRunning, isFalse);
    expect(progress.value, 1);
  });
}
