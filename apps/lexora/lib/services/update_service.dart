import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../app_version.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.notesZh,
    required this.notesEn,
  });

  final String version;
  final Uri downloadUrl;
  final List<String> notesZh;
  final List<String> notesEn;
}

class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _manifestUri =
      Uri.parse('https://lexora.12323456.xyz/version.json');
  static const _cacheFolderName = 'lexora_update_installers';
  final http.Client _client;

  Future<UpdateInfo?> check() async {
    final uri = _manifestUri.replace(
      queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException('Update server returned ${response.statusCode}.');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final version = json['version'] as String? ?? '';
    if (version.isEmpty || !_isNewer(version, appVersion)) return null;
    final downloads = json['downloads'] as Map<String, dynamic>? ?? const {};
    final platformKey = _platformKey;
    final rawUrl = downloads[platformKey] as String?;
    if (rawUrl == null || rawUrl.isEmpty) {
      throw const FormatException('No installer is available for this platform.');
    }
    final notes = json['releaseNotes'] as Map<String, dynamic>? ?? const {};
    return UpdateInfo(
      version: version,
      downloadUrl: _manifestUri.resolve(rawUrl),
      notesZh: _stringList(notes['zh']),
      notesEn: _stringList(notes['en']),
    );
  }

  Future<void> downloadAndLaunch(
    UpdateInfo info, {
    required void Function(double?) onProgress,
  }) async {
    final request = http.Request('GET', info.downloadUrl);
    final response = await _client.send(request).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('Installer download returned ${response.statusCode}.');
    }
    final cache = await _cacheDirectory();
    final filename = info.downloadUrl.pathSegments.last;
    final file = File('${cache.path}/$filename');
    final sink = file.openWrite();
    final total = response.contentLength;
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(total == null || total <= 0 ? null : received / total);
      }
    } finally {
      await sink.close();
    }
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      throw FileSystemException(result.message, file.path);
    }
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
    final base = await getTemporaryDirectory();
    final directory = Directory('${base.path}/$_cacheFolderName');
    await directory.create(recursive: true);
    return directory;
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
