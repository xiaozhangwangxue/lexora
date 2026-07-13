import 'package:shared_preferences/shared_preferences.dart';

import 'pdf_service.dart';

enum ExampleAmount {
  none(0),
  one(1),
  upToThree(3);

  const ExampleAmount(this.count);
  final int count;
}

class PdfSettings {
  const PdfSettings({
    this.fontSize = PdfFontSize.medium,
    this.exampleAmount = ExampleAmount.one,
  });

  final PdfFontSize fontSize;
  final ExampleAmount exampleAmount;

  PdfSettings copyWith({
    PdfFontSize? fontSize,
    ExampleAmount? exampleAmount,
  }) =>
      PdfSettings(
        fontSize: fontSize ?? this.fontSize,
        exampleAmount: exampleAmount ?? this.exampleAmount,
      );
}

class PdfSettingsService {
  static const _fontSizeKey = 'lexora.pdf.font-size.v1';
  static const _exampleAmountKey = 'lexora.pdf.example-amount.v1';

  Future<PdfSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    return PdfSettings(
      fontSize: _enumByName(
        PdfFontSize.values,
        preferences.getString(_fontSizeKey),
        PdfFontSize.medium,
      ),
      exampleAmount: _enumByName(
        ExampleAmount.values,
        preferences.getString(_exampleAmountKey),
        ExampleAmount.one,
      ),
    );
  }

  Future<void> save(PdfSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_fontSizeKey, settings.fontSize.name);
    await preferences.setString(
      _exampleAmountKey,
      settings.exampleAmount.name,
    );
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
