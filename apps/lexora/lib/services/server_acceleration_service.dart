import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ServerAccelerationSource {
  Future<bool> isEnabled();
}

class ServerAccelerationService extends ChangeNotifier
    implements ServerAccelerationSource {
  ServerAccelerationService._();

  static final instance = ServerAccelerationService._();
  static const preferenceKey = 'lexora.direct-batch-acceleration.enabled.v2';

  bool _enabled = true;
  bool _initialized = false;
  Future<void>? _initializing;

  bool get enabled => _enabled;

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializing ??= _load().whenComplete(() {
      _initialized = true;
      _initializing = null;
    });
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getBool(preferenceKey) ?? true;
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  @override
  Future<bool> isEnabled() async {
    await initialize();
    return _enabled;
  }

  Future<void> setEnabled(bool value) async {
    await initialize();
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(preferenceKey, value);
  }
}
