import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_version.dart';
import 'developer_log_service.dart';

typedef InstallerOpener = Future<bool> Function(File file);
typedef CacheDirectoryProvider = Future<Directory> Function();
typedef MacUpdateFinisher = Future<void> Function();
typedef MacInstallerPreparer = Future<void> Function(File file);

class UpdateDownload {
  const UpdateDownload({
    required this.urls,
    required this.filename,
    this.sha256,
    this.size,
  });

  final List<Uri> urls;
  final String filename;
  final String? sha256;
  final int? size;
}

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.download,
    required this.notesZh,
    required this.notesEn,
  });

  final String version;
  final UpdateDownload download;
  final List<String> notesZh;
  final List<String> notesEn;

  Uri get downloadUrl => download.urls.first;
}

class UpdateService {
  UpdateService({
    http.Client? client,
    Uri? manifestUri,
    String? platformKey,
    CacheDirectoryProvider? cacheDirectory,
    InstallerOpener? openInstaller,
    MacUpdateFinisher? finishMacUpdate,
    MacInstallerPreparer? prepareMacInstaller,
    bool? isMacOS,
  }) : _client = client ?? http.Client(),
       _manifestUri = manifestUri ?? _defaultManifestUri,
       _platformKeyOverride = platformKey,
       _cacheDirectoryOverride = cacheDirectory,
       _openInstaller = openInstaller ?? _defaultOpenInstaller,
       _finishMacUpdate = finishMacUpdate ?? _defaultFinishMacUpdate,
       _prepareMacInstaller =
           prepareMacInstaller ?? _defaultPrepareMacInstaller,
       _isMacOS = isMacOS ?? Platform.isMacOS;

  static final Uri _defaultManifestUri = Uri.parse(
    'https://lexora.12323456.xyz/version.json',
  );
  static const _cacheFolderName = 'lexora_update_installers';
  static const _nativeMacUpdate = MethodChannel('lexora/native-navigation');
  final http.Client _client;
  final Uri _manifestUri;
  final String? _platformKeyOverride;
  final CacheDirectoryProvider? _cacheDirectoryOverride;
  final InstallerOpener _openInstaller;
  final MacUpdateFinisher _finishMacUpdate;
  final MacInstallerPreparer _prepareMacInstaller;
  final bool _isMacOS;

  Future<UpdateInfo?> check() async {
    final uri = _manifestUri.replace(
      queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
    );
    DeveloperLogService.instance.log(
      'update.check_started',
      data: {'manifest': _manifestUri.toString()},
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException('Update server returned ${response.statusCode}.');
    }
    // R2 objects may not carry a charset. response.body would then use
    // Latin-1 and corrupt Chinese release notes, so always decode JSON bytes
    // explicitly as UTF-8.
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final version = json['version'] as String? ?? '';
    if (version.isEmpty || !_isNewer(version, appVersion)) {
      DeveloperLogService.instance.log(
        'update.up_to_date',
        data: {'current': appVersion, 'manifestVersion': version},
      );
      return null;
    }
    final downloads = json['downloads'] as Map<String, dynamic>? ?? const {};
    final verifiedDownloads =
        json['verifiedDownloads'] as Map<String, dynamic>? ?? const {};
    final platform = _platformKeyOverride ?? _platformKey;
    final rawDownload = verifiedDownloads[platform] ?? downloads[platform];
    if (rawDownload == null) {
      throw const FormatException(
        'No installer is available for this platform.',
      );
    }
    final notes = json['releaseNotes'] as Map<String, dynamic>? ?? const {};
    final info = UpdateInfo(
      version: version,
      download: _parseDownload(rawDownload),
      notesZh: _stringList(notes['zh']),
      notesEn: _stringList(notes['en']),
    );
    DeveloperLogService.instance.log(
      'update.available',
      data: {
        'current': appVersion,
        'available': version,
        'filename': info.download.filename,
        'sources': info.download.urls.map((uri) => uri.host).toList(),
      },
    );
    return info;
  }

  Future<void> downloadAndLaunch(
    UpdateInfo info, {
    required void Function(double?) onProgress,
  }) async {
    try {
      DeveloperLogService.instance.log(
        'update.download_started',
        data: {'version': info.version, 'filename': info.download.filename},
      );
      final file = await _downloadValidated(info.download, onProgress);
      DeveloperLogService.instance.log(
        'update.download_validated',
        data: {'path': file.path, 'bytes': await file.length()},
      );
      if (_isMacOS) await _prepareMacInstaller(file);
      if (!await _openInstaller(file)) {
        throw FileSystemException(
          'The system installer could not be opened.',
          file.path,
        );
      }
      DeveloperLogService.instance.log(
        'update.installer_opened',
        data: {'path': file.path, 'platform': _platformKey},
      );
      if (_isMacOS) await _finishMacUpdate();
    } catch (error, stack) {
      DeveloperLogService.instance.log(
        'update.failed',
        data: {'version': info.version, 'filename': info.download.filename},
        error: error,
        stackTrace: stack,
      );
      await DeveloperLogService.instance.flush();
      rethrow;
    }
  }

  Future<File> _downloadValidated(
    UpdateDownload download,
    void Function(double?) onProgress,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      for (final url in download.urls) {
        try {
          DeveloperLogService.instance.log(
            'update.source_attempt',
            data: {'attempt': attempt + 1, 'host': url.host, 'path': url.path},
          );
          return await _downloadFrom(url, download, onProgress);
        } catch (error, stack) {
          lastError = error;
          DeveloperLogService.instance.log(
            'update.source_failed',
            data: {'attempt': attempt + 1, 'host': url.host},
            error: error,
            stackTrace: stack,
          );
          onProgress(0);
        }
      }
    }
    throw HttpException(
      'All verified download sources failed. ${lastError ?? ''}'.trim(),
    );
  }

  Future<File> _downloadFrom(
    Uri url,
    UpdateDownload download,
    void Function(double?) onProgress,
  ) async {
    // Keep the HTTP client's normal User-Agent. A custom updater agent was
    // classified as automated traffic by the site's Cloudflare rules even
    // though the manifest request from the same device was allowed.
    final request = http.Request('GET', url)
      ..headers['accept'] = 'application/octet-stream';
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw HttpException(
        'Installer source returned ${response.statusCode}.',
        uri: url,
      );
    }

    final cache = await _cacheDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final finalFile = File('${cache.path}/$stamp-${download.filename}');
    final partial = File('${finalFile.path}.part');
    final sink = partial.openWrite();
    final responseTotal = response.contentLength;
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 35),
      )) {
        sink.add(chunk);
        received += chunk.length;
        final total = download.size ?? responseTotal;
        onProgress(total == null || total <= 0 ? null : received / total);
      }
      await sink.flush();
      await sink.close();
      if (responseTotal != null && received != responseTotal) {
        throw const FormatException('The installer download was incomplete.');
      }
      if (download.size != null && received != download.size) {
        throw const FormatException(
          'The installer size did not match the release.',
        );
      }
      await _verifyFile(partial, download);
      onProgress(1);
      return partial.rename(finalFile.path);
    } catch (_) {
      await sink.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<void> _verifyFile(File file, UpdateDownload download) async {
    final expectedHash = download.sha256?.toLowerCase().replaceFirst(
      RegExp(r'^sha256:'),
      '',
    );
    if (expectedHash != null && expectedHash.isNotEmpty) {
      final actualHash = (await sha256.bind(file.openRead()).first).toString();
      if (actualHash != expectedHash) {
        throw const FormatException('The installer integrity check failed.');
      }
    }
    await _verifyContainer(file, download.filename.toLowerCase());
  }

  static Future<void> _verifyContainer(File file, String filename) async {
    final length = await file.length();
    if (length < 4) {
      throw const FormatException('The installer file is invalid.');
    }
    final reader = await file.open();
    try {
      final head = await reader.read(4);
      bool matches(List<int> signature) {
        if (head.length < signature.length) return false;
        for (var index = 0; index < signature.length; index++) {
          if (head[index] != signature[index]) return false;
        }
        return true;
      }

      if ((filename.endsWith('.apk') || filename.endsWith('.zip')) &&
          !(matches(const [0x50, 0x4b, 0x03, 0x04]) ||
              matches(const [0x50, 0x4b, 0x05, 0x06]) ||
              matches(const [0x50, 0x4b, 0x07, 0x08]))) {
        throw const FormatException('The downloaded ZIP/APK is invalid.');
      }
      if (filename.endsWith('.exe') && !matches(const [0x4d, 0x5a])) {
        throw const FormatException(
          'The downloaded Windows installer is invalid.',
        );
      }
      if (filename.endsWith('.tar.gz') && !matches(const [0x1f, 0x8b])) {
        throw const FormatException('The downloaded Linux archive is invalid.');
      }
      if (filename.endsWith('.dmg')) {
        if (length < 512) {
          throw const FormatException('The downloaded DMG is invalid.');
        }
        await reader.setPosition(length - 512);
        final trailer = await reader.read(4);
        if (ascii.decode(trailer, allowInvalid: true) != 'koly') {
          throw const FormatException('The downloaded DMG is invalid.');
        }
      }
    } finally {
      await reader.close();
    }
  }

  UpdateDownload _parseDownload(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      final uri = _manifestUri.resolve(raw);
      return UpdateDownload(urls: [uri], filename: uri.pathSegments.last);
    }
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('The update download entry is invalid.');
    }
    final rawSources = raw['sources'];
    final urls = <Uri>[];
    if (rawSources is List) {
      for (final source in rawSources.whereType<String>()) {
        if (source.isNotEmpty) {
          urls.add(_manifestUri.resolve(source));
        }
      }
    }
    final rawUrl = raw['url'];
    if (urls.isEmpty && rawUrl is String && rawUrl.isNotEmpty) {
      urls.add(_manifestUri.resolve(rawUrl));
    }
    if (urls.isEmpty) {
      throw const FormatException('The update has no usable download source.');
    }
    final filename = raw['filename'] as String? ?? urls.first.pathSegments.last;
    return UpdateDownload(
      urls: urls,
      filename: filename,
      sha256: raw['sha256'] as String?,
      size: (raw['size'] as num?)?.toInt(),
    );
  }

  static Future<void> cleanupCachedInstallers() async {
    try {
      final base = await getTemporaryDirectory();
      final directory = Directory('${base.path}/$_cacheFolderName');
      if (!await directory.exists()) return;
      await for (final entity in directory.list()) {
        if (entity is File) await entity.delete();
      }
    } catch (_) {
      // Cache cleanup is best-effort and must never block app startup.
    }
  }

  Future<Directory> _cacheDirectory() async {
    if (_cacheDirectoryOverride != null) return _cacheDirectoryOverride();
    final base = await getTemporaryDirectory();
    final directory = Directory('${base.path}/$_cacheFolderName');
    await directory.create(recursive: true);
    return directory;
  }

  static Future<bool> _defaultOpenInstaller(File file) async {
    if (Platform.isMacOS) {
      try {
        return await _nativeMacUpdate.invokeMethod<bool>(
              'openMacInstaller',
              file.path,
            ) ??
            false;
      } catch (_) {
        // Fall through to the cross-platform opener.
      }
    }
    final result = await OpenFilex.open(file.path);
    return result.type == ResultType.done;
  }

  static Future<void> _defaultPrepareMacInstaller(File file) async {
    // Files created by a sandboxed app are tagged with quarantine flag 0x02
    // ("created without user consent"). macOS then denies the copied app with
    // a generic "can't be opened" error before Gatekeeper can offer Open
    // Anyway. The update button is an explicit user action, so replace that
    // flag with the normal user-approved download quarantine value.
    // A sandboxed app cannot reliably launch /usr/bin/xattr. The native
    // runner performs setxattr(2) inside the already-authorized process.
    await _nativeMacUpdate.invokeMethod<void>('prepareMacInstaller', file.path);
  }

  static Future<void> _defaultFinishMacUpdate() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final opened = await launchUrl(
        Uri.parse(
          'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension',
        ),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        await launchUrl(
          Uri.parse(
            'x-apple.systempreferences:com.apple.preference.security?General',
          ),
          mode: LaunchMode.externalApplication,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
    } finally {
      // Opening System Settings is best-effort; it must never prevent the old
      // app from terminating after the installer is ready.
      exit(0);
    }
  }

  static String get _platformKey {
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    throw UnsupportedError('Updates are not supported on this platform.');
  }

  static List<String> _stringList(dynamic value) =>
      value is List ? value.whereType<String>().toList() : const [];

  static bool _isNewer(String candidate, String current) {
    List<int> parts(String value) => value
        .replaceFirst(RegExp(r'^v'), '')
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final a = parts(candidate);
    final b = parts(current);
    for (var index = 0; index < 3; index++) {
      final left = index < a.length ? a[index] : 0;
      final right = index < b.length ? b[index] : 0;
      if (left != right) return left > right;
    }
    return false;
  }
}
