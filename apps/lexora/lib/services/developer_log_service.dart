import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';

/// Opt-in JSON-lines diagnostics. Logging is a cheap branch while disabled;
/// while enabled, writes are buffered and flushed in batches off the frame.
class DeveloperLogService {
  DeveloperLogService._();

  static final instance = DeveloperLogService._();
  static const _enabledKey = 'lexora.developer-logging.enabled.v1';
  static const _maxFileBytes = 8 * 1024 * 1024;

  final _pending = <String>[];
  bool _enabled = false;
  File? _file;
  Timer? _flushTimer;
  Future<void>? _flushInFlight;

  bool get enabled => _enabled;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(_enabledKey) ?? false;
    if (_enabled) {
      await _ensureFile();
      log('session.start', data: _environment());
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
    if (value) {
      await _ensureFile();
      log('developer_logging.enabled', data: _environment());
    } else {
      await flush();
      _flushTimer?.cancel();
      _flushTimer = null;
    }
  }

  void log(
    String event, {
    Map<String, Object?> data = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_enabled) return;
    final record = <String, Object?>{
      'time': DateTime.now().toUtc().toIso8601String(),
      'event': event,
      if (data.isNotEmpty) 'data': data,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString(),
    };
    _pending.add('${jsonEncode(record)}\n');
    if (_pending.length >= 40) {
      unawaited(flush());
    } else {
      _flushTimer ??= Timer(const Duration(milliseconds: 900), () {
        _flushTimer = null;
        unawaited(flush());
      });
    }
  }

  Future<void> flush() async {
    if (_pending.isEmpty) return _flushInFlight ?? Future.value();
    if (_flushInFlight != null) {
      await _flushInFlight;
      if (_pending.isNotEmpty) await flush();
      return;
    }
    final batch = _pending.join();
    _pending.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
    _flushInFlight = () async {
      final file = await _ensureFile();
      await _rotateIfNeeded(file, batch.length);
      await (await _ensureFile()).writeAsString(
        batch,
        mode: FileMode.append,
        encoding: utf8,
        flush: false,
      );
    }();
    try {
      await _flushInFlight;
    } finally {
      _flushInFlight = null;
    }
  }

  Future<File> exportFullLog() async {
    await flush();
    final directory = await _logDirectory();
    final export = File(
      '${directory.path}/lexora-diagnostics-$appVersion.jsonl',
    );
    final sink = export.openWrite(mode: FileMode.write, encoding: utf8);
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where(
              (file) =>
                  file.path.endsWith('.jsonl') && file.path != export.path,
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      await sink.addStream(file.openRead());
    }
    await sink.flush();
    await sink.close();
    return export;
  }

  Future<void> deleteLogs() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
    if (_flushInFlight != null) await _flushInFlight;
    final directory = await _logDirectory();
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File) await entity.delete();
      }
    }
    _file = null;
    if (_enabled) {
      await _ensureFile();
      log('logs.deleted', data: _environment());
    }
  }

  Future<File> _ensureFile() async {
    if (_file != null) return _file!;
    final directory = await _logDirectory();
    _file = File('${directory.path}/lexora-current.jsonl');
    return _file!;
  }

  Future<Directory> _logDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/diagnostics');
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _rotateIfNeeded(File file, int incomingBytes) async {
    if (!await file.exists()) return;
    if (await file.length() + incomingBytes <= _maxFileBytes) return;
    final previous = File('${file.parent.path}/lexora-previous.jsonl');
    if (await previous.exists()) await previous.delete();
    await file.rename(previous.path);
    _file = null;
  }

  Map<String, Object?> _environment() => {
    'appVersion': appVersion,
    'platform': Platform.operatingSystem,
    'platformVersion': Platform.operatingSystemVersion,
    'locale': Platform.localeName,
    'processors': Platform.numberOfProcessors,
  };
}
