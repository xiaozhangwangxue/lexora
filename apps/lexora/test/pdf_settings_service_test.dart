import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/services/pdf_service.dart';
import 'package:lexora/services/pdf_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('large preset increases every mobile-reading font size', () {
    const settings = PdfSettings();
    final large = settings.applyPreset(PdfFontSize.large);

    expect(large.typography.word, greaterThan(settings.typography.word));
    expect(
      large.typography.definition,
      greaterThan(settings.typography.definition * 1.35),
    );
    expect(
      large.typography.example,
      greaterThan(settings.typography.example * 1.35),
    );
  });

  test('fine-grained typography settings persist', () async {
    SharedPreferences.setMockInitialValues({});
    final service = PdfSettingsService();
    final customized = const PdfSettings().copyWith(
      typography: const PdfTypography(
        word: 24,
        phonetic: 13,
        definition: 12,
        related: 10,
        example: 11,
        phrase: 10.5,
      ),
    );

    await service.save(customized);
    final loaded = await service.load();

    expect(loaded.typography.word, 24);
    expect(loaded.typography.phonetic, 13);
    expect(loaded.typography.definition, 12);
    expect(loaded.typography.example, 11);
  });
}
