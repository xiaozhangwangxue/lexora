import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/scheduler.dart';
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

  final _pending = <Map<String, Object?>>[];
  final _frameSamples = <double>[];
  final _coalescedEvents = <String, _CoalescedEvent>{};
  final _uptime = Stopwatch()..start();
  late final String _sessionId =
      '${DateTime.now().toUtc().microsecondsSinceEpoch}-$pid';
  bool _enabled = false;
  int _sequence = 0;
  File? _file;
  Timer? _flushTimer;
  Timer? _coalescedFlushTimer;
  Future<void>? _flushInFlight;
  bool _timingsCallbackAttached = false;

  bool get enabled => _enabled;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(_enabledKey) ?? false;
    if (_enabled) {
      await _ensureFile();
      _attachTimingsCallback();
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
      _attachTimingsCallback();
      log('developer_logging.enabled', data: _environment());
    } else {
      _flushCoalescedEvents();
      _detachTimingsCallback();
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
      'session': _sessionId,
      'sequence': ++_sequence,
      'uptimeMs': _uptime.elapsedMilliseconds,
      'event': event,
      if (data.isNotEmpty) 'data': data,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString(),
    };
    _pending.add(record);
    if (_pending.length >= 40) {
      unawaited(flush());
    } else {
      _flushTimer ??= Timer(const Duration(milliseconds: 900), () {
        _flushTimer = null;
        unawaited(flush());
      });
    }
  }

  /// Coalesces high-frequency input such as scroll-wheel and trackpad signals.
  /// Exact pointer down/up/cancel events continue to use [log].
  void logCoalesced(String event, {Map<String, Object?> data = const {}}) {
    if (!_enabled) return;
    final now = DateTime.now().toUtc();
    final aggregate = _coalescedEvents[event];
    if (aggregate == null) {
      _coalescedEvents[event] = _CoalescedEvent(
        count: 1,
        first: now,
        last: now,
        firstData: data,
        lastData: data,
      );
    } else {
      aggregate.count++;
      aggregate
        ..last = now
        ..lastData = data;
    }
    _coalescedFlushTimer ??= Timer(
      const Duration(milliseconds: 100),
      _flushCoalescedEvents,
    );
  }

  /// Records a complete start/success/failure span without delaying UI work.
  Future<T> trace<T>(
    String operation,
    Future<T> Function() task, {
    Map<String, Object?> data = const {},
    Map<String, Object?> Function(T value)? result,
  }) async {
    final stopwatch = Stopwatch()..start();
    log('$operation.started', data: data);
    try {
      final value = await task();
      stopwatch.stop();
      log(
        '$operation.completed',
        data: {
          ...data,
          'durationMs': stopwatch.elapsedMilliseconds,
          if (result != null) ...result(value),
        },
      );
      return value;
    } catch (error, stackTrace) {
      stopwatch.stop();
      log(
        '$operation.failed',
        data: {...data, 'durationMs': stopwatch.elapsedMilliseconds},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> flush() async {
    if (_pending.isEmpty) return _flushInFlight ?? Future.value();
    if (_flushInFlight != null) {
      await _flushInFlight;
      if (_pending.isNotEmpty) await flush();
      return;
    }
    final records = List<Map<String, Object?>>.of(_pending);
    _pending.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
    _flushInFlight = () async {
      final batch = await Isolate.run(
        () => records.map((record) => '${jsonEncode(record)}\n').join(),
      );
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
    _coalescedFlushTimer?.cancel();
    _coalescedFlushTimer = null;
    _coalescedEvents.clear();
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
    'buildNumber': appBuildNumber,
    'session': _sessionId,
    'pid': pid,
    'platform': Platform.operatingSystem,
    'platformVersion': Platform.operatingSystemVersion,
    'locale': Platform.localeName,
    'processors': Platform.numberOfProcessors,
  };

  void _flushCoalescedEvents() {
    _coalescedFlushTimer?.cancel();
    _coalescedFlushTimer = null;
    if (!_enabled || _coalescedEvents.isEmpty) {
      _coalescedEvents.clear();
      return;
    }
    final events = Map<String, _CoalescedEvent>.of(_coalescedEvents);
    _coalescedEvents.clear();
    for (final entry in events.entries) {
      final value = entry.value;
      log(
        entry.key,
        data: {
          'count': value.count,
          'firstTime': value.first.toIso8601String(),
          'lastTime': value.last.toIso8601String(),
          'first': value.firstData,
          'last': value.lastData,
        },
      );
    }
  }

  void _attachTimingsCallback() {
    if (_timingsCallbackAttached) return;
    SchedulerBinding.instance.addTimingsCallback(_handleFrameTimings);
    _timingsCallbackAttached = true;
  }

  void _detachTimingsCallback() {
    if (!_timingsCallbackAttached) return;
    SchedulerBinding.instance.removeTimingsCallback(_handleFrameTimings);
    _timingsCallbackAttached = false;
    _frameSamples.clear();
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    if (!_enabled) return;
    for (final timing in timings) {
      _frameSamples.add(
        (timing.buildDuration + timing.rasterDuration).inMicroseconds / 1000,
      );
    }
    if (_frameSamples.length < 60) return;
    final samples = List<double>.of(_frameSamples)..sort();
    _frameSamples.clear();
    double percentile(double value) {
      final index = ((samples.length - 1) * value).round();
      return samples[index];
    }

    log(
      'performance.frame_summary',
      data: {
        'frames': samples.length,
        'p50Ms': percentile(.50),
        'p95Ms': percentile(.95),
        'worstMs': samples.last,
        'over16_7Ms': samples.where((value) => value > 16.7).length,
        'over32Ms': samples.where((value) => value > 32).length,
      },
    );
  }
}

class _CoalescedEvent {
  _CoalescedEvent({
    required this.count,
    required this.first,
    required this.last,
    required this.firstData,
    required this.lastData,
  });

  int count;
  final DateTime first;
  DateTime last;
  final Map<String, Object?> firstData;
  Map<String, Object?> lastData;
}
