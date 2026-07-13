import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'screens/shell_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  runApp(const LexoraApp());
}

class LexoraApp extends StatelessWidget {
  const LexoraApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final isApple = Platform.isMacOS;
    final isWindows = Platform.isWindows;
    final seed = isApple
        ? const Color(0xFF635BFF)
        : isWindows
            ? const Color(0xFF0067C0)
            : const Color(0xFF3154D8);
    return MaterialApp(
      title: 'Lexora',
      debugShowCheckedModeBanner: false,
      locale: locale,
      themeMode: ThemeMode.system,
      theme: _theme(seed, Brightness.light, transparent: isApple),
      darkTheme: _theme(seed, Brightness.dark, transparent: isApple),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ShellScreen(),
    );
  }

  ThemeData _theme(
    Color seed,
    Brightness brightness, {
    required bool transparent,
  }) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final radius = transparent ? 12.0 : 24.0;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: transparent ? 'SF Pro Text' : null,
      visualDensity: transparent ? VisualDensity.compact : VisualDensity.standard,
      scaffoldBackgroundColor: transparent
          ? Colors.transparent
          : brightness == Brightness.light
              ? const Color(0xFFF7F8FC)
              : const Color(0xFF101116),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: transparent
            ? (brightness == Brightness.light
                ? Colors.white.withValues(alpha: .72)
                : const Color(0xFF1A1C23).withValues(alpha: .76))
            : brightness == Brightness.light
                ? Colors.white
                : const Color(0xFF1A1C23),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: transparent
              ? BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: .5),
                )
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: transparent
              ? BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: .5),
                )
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary, width: 1.25),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: transparent
            ? (brightness == Brightness.light
                ? Colors.white.withValues(alpha: .68)
                : const Color(0xFF1A1C23).withValues(alpha: .72))
            : brightness == Brightness.light
                ? Colors.white
                : const Color(0xFF1A1C23),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(transparent ? 12 : 20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(transparent ? 10 : 20),
          ),
        ),
      ),
    );
  }
}
