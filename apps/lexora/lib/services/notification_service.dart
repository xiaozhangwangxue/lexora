import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionRequested = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open Lexora',
      ),
      windows: WindowsInitializationSettings(
        appName: 'Lexora',
        appUserModelId: 'xyz.12323456.lexora',
        guid: 'a70d53b0-6132-4dc4-b771-2f8aef5c6de2',
      ),
    );
    try {
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (_) {
      // Notifications are optional and must never block app startup.
    }
  }

  Future<void> requestPermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    await initialize();
    if (!_initialized) return;
    try {
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else if (Platform.isMacOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: false, sound: true);
      }
    } catch (_) {
      // The app remains fully usable when permission is denied or unavailable.
    }
  }

  Future<void> showGenerationComplete({
    required int wordCount,
    required bool isZh,
  }) async {
    await initialize();
    if (!_initialized) return;
    final title = isZh ? '词汇书已生成' : 'Vocabulary book ready';
    final body = isZh
        ? '已完成 $wordCount 个单词的查询与 PDF 排版。'
        : '$wordCount ${wordCount == 1 ? 'word is' : 'words are'} ready in your PDF.';
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'lexora_generation',
        'Lexora generation',
        channelDescription: 'Completed vocabulary book notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );
    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {
      // A notification failure must not turn a successful PDF into an error.
    }
  }
}
