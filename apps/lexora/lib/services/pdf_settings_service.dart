import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_entry.dart';
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
    this.format = BookFormat.pdf,
    this.pageSize = BookPageSize.a4,
    this.smartReorder = false,
    this.typography = const PdfTypography(
      word: 18,
      phonetic: 9,
      definition: 8.7,
      related: 7.2,
      example: 7.2,
      phrase: 7.2,
    ),
  });

  final PdfFontSize fontSize;
  final ExampleAmount exampleAmount;
  final BookFormat format;
  final BookPageSize pageSize;
  final bool smartReorder;
  final PdfTypography typography;

  PdfSettings copyWith({
    PdfFontSize? fontSize,
    ExampleAmount? exampleAmount,
    BookFormat? format,
    BookPageSize? pageSize,
    bool? smartReorder,
    PdfTypography? typography,
  }) => PdfSettings(
    fontSize: fontSize ?? this.fontSize,
    exampleAmount: exampleAmount ?? this.exampleAmount,
    format: format ?? this.format,
    pageSize: pageSize ?? this.pageSize,
    smartReorder: smartReorder ?? this.smartReorder,
    typography: typography ?? this.typography,
  );

  PdfSettings applyPreset(PdfFontSize preset) =>
      copyWith(fontSize: preset, typography: PdfTypography.fromPreset(preset));
}

class PdfSettingsService {
  static const _fontSizeKey = 'lexora.pdf.font-size.v1';
  static const _exampleAmountKey = 'lexora.pdf.example-amount.v1';
  static const _formatKey = 'lexora.document.format.v1';
  static const _pageSizeKey = 'lexora.document.page-size.v1';
  static const _smartReorderKey = 'lexora.document.smart-reorder.v1';
  static const _typographyPrefix = 'lexora.pdf.typography.v1';

  Future<PdfSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final fontSize = _enumByName(
      PdfFontSize.values,
      preferences.getString(_fontSizeKey),
      PdfFontSize.medium,
    );
    final defaults = PdfTypography.fromPreset(fontSize);
    return PdfSettings(
      fontSize: fontSize,
      exampleAmount: _enumByName(
        ExampleAmount.values,
        preferences.getString(_exampleAmountKey),
        ExampleAmount.one,
      ),
      format: _enumByName(
        BookFormat.values,
        preferences.getString(_formatKey),
        BookFormat.pdf,
      ),
      pageSize: _enumByName(
        BookPageSize.values,
        preferences.getString(_pageSizeKey),
        BookPageSize.a4,
      ),
      smartReorder: preferences.getBool(_smartReorderKey) ?? false,
      typography: PdfTypography(
        word: preferences.getDouble('$_typographyPrefix.word') ?? defaults.word,
        phonetic:
            preferences.getDouble('$_typographyPrefix.phonetic') ??
            defaults.phonetic,
        definition:
            preferences.getDouble('$_typographyPrefix.definition') ??
            defaults.definition,
        related:
            preferences.getDouble('$_typographyPrefix.related') ??
            defaults.related,
        example:
            preferences.getDouble('$_typographyPrefix.example') ??
            defaults.example,
        phrase:
            preferences.getDouble('$_typographyPrefix.phrase') ??
            defaults.phrase,
      ),
    );
  }

  Future<void> save(PdfSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_fontSizeKey, settings.fontSize.name);
    await preferences.setString(_exampleAmountKey, settings.exampleAmount.name);
    await preferences.setString(_formatKey, settings.format.name);
    await preferences.setString(_pageSizeKey, settings.pageSize.name);
    await preferences.setBool(_smartReorderKey, settings.smartReorder);
    await Future.wait([
      preferences.setDouble(
        '$_typographyPrefix.word',
        settings.typography.word,
      ),
      preferences.setDouble(
        '$_typographyPrefix.phonetic',
        settings.typography.phonetic,
      ),
      preferences.setDouble(
        '$_typographyPrefix.definition',
        settings.typography.definition,
      ),
      preferences.setDouble(
        '$_typographyPrefix.related',
        settings.typography.related,
      ),
      preferences.setDouble(
        '$_typographyPrefix.example',
        settings.typography.example,
      ),
      preferences.setDouble(
        '$_typographyPrefix.phrase',
        settings.typography.phrase,
      ),
    ]);
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
