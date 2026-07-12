import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/main.dart';

void main() {
  testWidgets('Lexora opens on the word composer', (tester) async {
    await tester.pumpWidget(const LexoraApp());
    expect(find.text('Lexora'), findsOneWidget);
    expect(find.text('Start generating'), findsOneWidget);
    expect(find.text('Your words will appear here'), findsOneWidget);
  });
}
