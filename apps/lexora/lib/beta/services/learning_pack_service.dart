import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/word_entry.dart';

class LearningPackDescriptor {
  const LearningPackDescriptor({
    required this.id,
    required this.titleZh,
    required this.titleEn,
    required this.descriptionZh,
    required this.version,
    required this.entryCount,
    required this.bytes,
    required this.sha256,
    required this.urls,
    required this.license,
    required this.attribution,
  });

  final String id;
  final String titleZh;
  final String titleEn;
  final String descriptionZh;
  final String version;
  final int entryCount;
  final int bytes;
  final String sha256;
  final List<Uri> urls;
  final String license;
  final String attribution;

  factory LearningPackDescriptor.fromJson(Map<String, dynamic> json) {
    final pack = LearningPackDescriptor(
      id: json['id']?.toString() ?? '',
      titleZh: json['titleZh']?.toString() ?? '',
      titleEn: json['titleEn']?.toString() ?? '',
      descriptionZh: json['descriptionZh']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256']?.toString().toLowerCase() ?? '',
      urls: (json['urls'] as List? ?? const [])
          .map((value) => Uri.tryParse(value.toString()))
          .whereType<Uri>()
          .where((value) => value.hasScheme && value.host.isNotEmpty)
          .toList(growable: false),
      license: json['license']?.toString() ?? '',
      attribution: json['attribution']?.toString() ?? '',
    );
    if (pack.id.isEmpty ||
        pack.titleZh.isEmpty ||
        pack.version.isEmpty ||
        pack.entryCount < 1 ||
        pack.bytes < 1 ||
        pack.sha256.length != 64 ||
        pack.urls.isEmpty ||
        pack.license.isEmpty) {
      throw const FormatException('学习词库清单不完整。');
    }
    return pack;
  }
}

class InstalledLearningPack {
  const InstalledLearningPack({
    required this.id,
    required this.version,
    required this.path,
    required this.entryCount,
  });

  final String id;
  final String version;
  final String path;
  final int entryCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'path': path,
    'entryCount': entryCount,
  };

  factory InstalledLearningPack.fromJson(Map<String, dynamic> json) =>
      InstalledLearningPack(
        id: json['id']?.toString() ?? '',
        version: json['version']?.toString() ?? '',
        path: json['path']?.toString() ?? '',
        entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
      );
}

class LearningPackService {
  LearningPackService({http.Client? client, Uri? manifestUri})
    : _client = client ?? http.Client(),
      _manifestUri =
          manifestUri ??
          Uri.https(
            'lexora.12323456.xyz',
            '/downloads/lexora-learning-packs-manifest.json',
          );

  static const _registryKey = 'lexora.learning.packs.v1';
  final http.Client _client;
  final Uri _manifestUri;

  Future<List<LearningPackDescriptor>> fetchManifest() async {
    final response = await _client
        .get(_manifestUri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException('词库清单返回 ${response.statusCode}', uri: _manifestUri);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['packs'] is! List) {
      throw const FormatException('学习词库清单格式错误。');
    }
    return (decoded['packs'] as List)
        .whereType<Map>()
        .map(
          (value) =>
              LearningPackDescriptor.fromJson(value.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<Map<String, InstalledLearningPack>> installed() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_registryKey);
    if (raw == null) return {};
    try {
      final values = jsonDecode(raw) as List;
      final result = <String, InstalledLearningPack>{};
      for (final value in values.whereType<Map>()) {
        final item = InstalledLearningPack.fromJson(
          value.cast<String, dynamic>(),
        );
        if (item.id.isNotEmpty && await File(item.path).exists()) {
          result[item.id] = item;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<List<WordEntry>> install(
    LearningPackDescriptor pack, {
    void Function(double value)? onProgress,
  }) async {
    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}learning-packs',
    );
    await directory.create(recursive: true);
    final archiveFile = File(
      '${directory.path}${Platform.pathSeparator}.${pack.id}-${pack.version}.json.gz.part',
    );
    Object? lastError;
    for (final url in pack.urls) {
      try {
        final request = http.Request('GET', url);
        final response = await _client
            .send(request)
            .timeout(const Duration(seconds: 25));
        if (response.statusCode != 200) {
          throw HttpException('下载返回 ${response.statusCode}', uri: url);
        }
        final sink = archiveFile.openWrite();
        var received = 0;
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call((received / pack.bytes).clamp(0, 1));
        }
        await sink.close();
        final bytes = await archiveFile.readAsBytes();
        if (bytes.length != pack.bytes ||
            sha256.convert(bytes).toString() != pack.sha256) {
          throw const FormatException('学习词库校验失败。');
        }
        final jsonBytes = GZipDecoder().decodeBytes(bytes, verify: true);
        final decoded = jsonDecode(utf8.decode(jsonBytes));
        if (decoded is! Map || decoded['entries'] is! List) {
          throw const FormatException('学习词库内容格式错误。');
        }
        final entries = (decoded['entries'] as List)
            .whereType<Map>()
            .map((value) => WordEntry.fromJson(value.cast<String, dynamic>()))
            .where(
              (entry) =>
                  entry.word.trim().isNotEmpty &&
                  entry.definition.trim().isNotEmpty &&
                  entry.definitionZh.trim().isNotEmpty,
            )
            .toList(growable: false);
        if (entries.length != pack.entryCount) {
          throw const FormatException('学习词库完整性检查失败。');
        }
        final installedFile = File(
          '${directory.path}${Platform.pathSeparator}${pack.id}-${pack.version}.json.gz',
        );
        await installedFile.writeAsBytes(bytes, flush: true);
        final registry = await installed();
        registry[pack.id] = InstalledLearningPack(
          id: pack.id,
          version: pack.version,
          path: installedFile.path,
          entryCount: entries.length,
        );
        await _saveRegistry(registry);
        return entries;
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('学习词库下载失败：$lastError');
  }

  Future<void> uninstall(String packId) async {
    final registry = await installed();
    final item = registry.remove(packId);
    if (item != null) {
      final file = File(item.path);
      if (await file.exists()) {
        // User explicitly requested deleting downloaded expansion packs.
        await file.delete();
      }
    }
    await _saveRegistry(registry);
  }

  Future<void> _saveRegistry(Map<String, InstalledLearningPack> values) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _registryKey,
      jsonEncode(values.values.map((value) => value.toJson()).toList()),
    );
  }
}
