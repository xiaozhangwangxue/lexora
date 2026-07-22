import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'screens/shell_screen.dart';
import 'services/developer_log_service.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final logs = DeveloperLogService.instance;
      await logs.initialize();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        logs.log(
          'flutter.error',
          error: details.exception,
          stackTrace: details.stack,
          data: {
            'library': details.library,
            'context': details.context?.toString(),
          },
        );
        unawaited(logs.flush());
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        logs.log('platform.error', error: error, stackTrace: stack);
        unawaited(logs.flush());
        return true;
      };
      await UpdateService.cleanupCachedInstallers();
      await NotificationService.instance.initialize();
      logs.log('app.ready');
      runApp(const LexoraApp());
    },
    (error, stack) {
      DeveloperLogService.instance.log(
        'zone.error',
        error: error,
        stackTrace: stack,
      );
      unawaited(DeveloperLogService.instance.flush());
    },
  );
}

class LexoraApp extends StatelessWidget {
  const LexoraApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final isApple = defaultTargetPlatform == TargetPlatform.macOS;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final seed = isApple
        ? const Color(0xFF635BFF)
        : isWindows
        ? const Color(0xFF0067C0)
        : const Color(0xFF3154D8);
    return MaterialApp(
      title: 'Lexora',
      debugShowCheckedModeBanner: false,
      locale: locale,
      // Windows can report a system-wide dark preference even when the
      // desktop window is using the light Lexora surface. Keep the Windows
      // shell legible and consistent with its native light desktop chrome.
      themeMode: isWindows ? ThemeMode.light : ThemeMode.system,
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
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final radius = transparent ? 12.0 : 24.0;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: transparent ? 'SF Pro Text' : null,
      visualDensity: transparent
          ? VisualDensity.compact
          : VisualDensity.standard,
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
              ? BorderSide(color: scheme.outlineVariant.withValues(alpha: .5))
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: transparent
              ? BorderSide(color: scheme.outlineVariant.withValues(alpha: .5))
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
