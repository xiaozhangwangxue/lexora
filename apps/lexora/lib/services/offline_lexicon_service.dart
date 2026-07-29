import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'developer_log_service.dart';

enum OfflineLexiconEdition {
  fast20k('fast20k'),
  full('full');

  const OfflineLexiconEdition(this.id);
  final String id;
}

class OfflineLexiconPackage {
  const OfflineLexiconPackage({
    required this.edition,
    required this.version,
    required this.rows,
    required this.archiveUrls,
    required this.archiveBytes,
    required this.archiveSha256,
    required this.databaseFilename,
    required this.databaseBytes,
    required this.databaseSha256,
  });

  final OfflineLexiconEdition edition;
  final String version;
  final int rows;
  final List<Uri> archiveUrls;
  final int archiveBytes;
  final String archiveSha256;
  final String databaseFilename;
  final int databaseBytes;
  final String databaseSha256;

  factory OfflineLexiconPackage.fromJson(
    OfflineLexiconEdition edition,
    Map<String, dynamic> json,
  ) {
    final archive =
        json['archive'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final database =
        json['database'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final urls = (archive['urls'] as List? ?? const [])
        .map((value) => Uri.tryParse(value.toString()))
        .whereType<Uri>()
        .where((uri) => uri.hasScheme && uri.host.isNotEmpty)
        .toList(growable: false);
    final package = OfflineLexiconPackage(
      edition: edition,
      version: json['version']?.toString() ?? '',
      rows: _intValue(json['rows']),
      archiveUrls: urls,
      archiveBytes: _intValue(archive['bytes']),
      archiveSha256: archive['sha256']?.toString().toLowerCase() ?? '',
      databaseFilename: database['filename']?.toString() ?? '',
      databaseBytes: _intValue(database['bytes']),
      databaseSha256: database['sha256']?.toString().toLowerCase() ?? '',
    );
    if (package.version.isEmpty ||
        package.rows < 1 ||
        package.archiveUrls.isEmpty ||
        package.archiveBytes < 1 ||
        package.archiveSha256.length != 64 ||
        package.databaseFilename.isEmpty ||
        package.databaseBytes < 1 ||
        package.databaseSha256.length != 64) {
      throw const FormatException('Offline lexicon manifest is incomplete.');
    }
    return package;
  }
}

class OfflineLexiconManifest {
  const OfflineLexiconManifest({
    required this.schemaVersion,
    required this.packages,
  });

  final int schemaVersion;
  final Map<OfflineLexiconEdition, OfflineLexiconPackage> packages;

  factory OfflineLexiconManifest.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _intValue(json['schema_version']);
    final rawPackages =
        json['packages'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final packages = <OfflineLexiconEdition, OfflineLexiconPackage>{};
    for (final edition in OfflineLexiconEdition.values) {
      final value = rawPackages[edition.id];
      if (value is Map<String, dynamic>) {
        packages[edition] = OfflineLexiconPackage.fromJson(edition, value);
      }
    }
    if (schemaVersion < 1 || packages.isEmpty) {
      throw const FormatException('Offline lexicon manifest is invalid.');
    }
    return OfflineLexiconManifest(
      schemaVersion: schemaVersion,
      packages: Map.unmodifiable(packages),
    );
  }
}

class InstalledOfflineLexicon {
  const InstalledOfflineLexicon({
    required this.edition,
    required this.version,
    required this.rows,
    required this.path,
    required this.bytes,
    required this.sha256,
  });

  final OfflineLexiconEdition edition;
  final String version;
  final int rows;
  final String path;
  final int bytes;
  final String sha256;

  Map<String, dynamic> toJson() => {
    'edition': edition.id,
    'version': version,
    'rows': rows,
    'path': path,
    'bytes': bytes,
    'sha256': sha256,
  };

  factory InstalledOfflineLexicon.fromJson(Map<String, dynamic> json) {
    return InstalledOfflineLexicon(
      edition: OfflineLexiconEdition.values.firstWhere(
        (value) => value.id == json['edition'],
      ),
      version: json['version']?.toString() ?? '',
      rows: _intValue(json['rows']),
      path: json['path']?.toString() ?? '',
      bytes: _intValue(json['bytes']),
      sha256: json['sha256']?.toString() ?? '',
    );
  }
}

abstract interface class OfflineLexiconSource {
  Future<Map<String, dynamic>?> lookup(String normalizedTerm);
  Future<List<Map<String, dynamic>>> suggest(
    String normalizedPrefix, {
    int limit,
  });
}

class OfflineLexiconService extends ChangeNotifier
    implements OfflineLexiconSource {
  OfflineLexiconService({
    http.Client? client,
    Uri? manifestUri,
    Future<Directory> Function()? supportDirectory,
  }) : _client = client ?? http.Client(),
       _manifestUri =
           manifestUri ??
           Uri.https('dict.12323456.xyz', '/v1/offline/manifest.json'),
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static final instance = OfflineLexiconService();

  static const _registryKey = 'lexora.offline_lexicon.registry.v1';
  static const _activeKey = 'lexora.offline_lexicon.active.v1';

  final http.Client _client;
  final Uri _manifestUri;
  final Future<Directory> Function() _supportDirectory;
  final Map<OfflineLexiconEdition, InstalledOfflineLexicon> _installed = {};

  Future<void>? _initializing;
  OfflineLexiconManifest? _manifest;
  OfflineLexiconEdition? _activeEdition;
  bool _downloading = false;
  OfflineLexiconEdition? _downloadingEdition;
  double? _downloadProgress;
  Object? _lastError;

  OfflineLexiconManifest? get manifest => _manifest;
  Map<OfflineLexiconEdition, InstalledOfflineLexicon> get installed =>
      Map.unmodifiable(_installed);
  OfflineLexiconEdition? get activeEdition => _activeEdition;
  InstalledOfflineLexicon? get active =>
      _activeEdition == null ? null : _installed[_activeEdition];
  bool get downloading => _downloading;
  OfflineLexiconEdition? get downloadingEdition => _downloadingEdition;
  double? get downloadProgress => _downloadProgress;
  Object? get lastError => _lastError;

  Future<void> initialize() =>
      _initializing ??= _initialize().whenComplete(() => _initializing = null);

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final rawRegistry = preferences.getString(_registryKey);
    if (rawRegistry != null) {
      try {
        final values = jsonDecode(rawRegistry) as List;
        for (final value in values.whereType<Map<String, dynamic>>()) {
          final item = InstalledOfflineLexicon.fromJson(value);
          if (await File(item.path).exists()) {
            _installed[item.edition] = item;
          }
        }
      } catch (error, stackTrace) {
        DeveloperLogService.instance.log(
          'offline_lexicon.registry_invalid',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    final activeId = preferences.getString(_activeKey);
    _activeEdition = OfflineLexiconEdition.values
        .where((value) => value.id == activeId && _installed.containsKey(value))
        .firstOrNull;
    notifyListeners();
  }

  Future<OfflineLexiconManifest> refreshManifest() async {
    final response = await _client
        .get(
          _manifestUri,
          headers: const {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw HttpException(
        'Offline lexicon manifest returned ${response.statusCode}.',
        uri: _manifestUri,
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Offline lexicon manifest is invalid.');
    }
    _manifest = OfflineLexiconManifest.fromJson(decoded);
    _lastError = null;
    notifyListeners();
    return _manifest!;
  }

  Future<void> activate(OfflineLexiconEdition? edition) async {
    await initialize();
    if (edition != null && !_installed.containsKey(edition)) {
      throw StateError('The selected offline lexicon is not installed.');
    }
    _activeEdition = edition;
    final preferences = await SharedPreferences.getInstance();
    if (edition == null) {
      await preferences.remove(_activeKey);
    } else {
      await preferences.setString(_activeKey, edition.id);
    }
    notifyListeners();
  }

  Future<void> download(
    OfflineLexiconEdition edition, {
    void Function(double? progress)? onProgress,
  }) async {
    await initialize();
    if (_downloading) {
      throw StateError('Another offline lexicon download is already running.');
    }
    _downloading = true;
    _downloadingEdition = edition;
    _downloadProgress = 0;
    _lastError = null;
    notifyListeners();
    try {
      final currentManifest = _manifest ?? await refreshManifest();
      final package = currentManifest.packages[edition];
      if (package == null) {
        throw StateError('This offline lexicon package is not available yet.');
      }
      final root = Directory(
        '${(await _supportDirectory()).path}${Platform.pathSeparator}offline-lexicon',
      );
      await root.create(recursive: true);
      final archive = File(
        '${root.path}${Platform.pathSeparator}${edition.id}-${package.version}.sqlite.gz.part',
      );
      await _downloadArchive(package, archive, (progress) {
        _downloadProgress = progress == null ? null : progress * .78;
        onProgress?.call(_downloadProgress);
        notifyListeners();
      });
      try {
        await _verifyFile(
          archive,
          expectedBytes: package.archiveBytes,
          expectedSha256: package.archiveSha256,
        );
      } catch (_) {
        // Keep the resumable path but discard bytes that can never pass the
        // signed manifest, otherwise every retry would reuse the same file.
        await archive.writeAsBytes(const [], flush: true);
        rethrow;
      }

      final candidate = File(
        '${root.path}${Platform.pathSeparator}.${edition.id}-${package.version}.sqlite.installing',
      );
      _downloadProgress = .8;
      onProgress?.call(_downloadProgress);
      notifyListeners();
      await Isolate.run(
        () => _decompressGzip(archive.path, candidate.path),
        debugName: 'lexora-offline-decompress',
      );
      _downloadProgress = .92;
      onProgress?.call(_downloadProgress);
      notifyListeners();
      await _verifyFile(
        candidate,
        expectedBytes: package.databaseBytes,
        expectedSha256: package.databaseSha256,
      );
      final rowCount = await Isolate.run(
        () => _validateLexiconDatabase(candidate.path),
        debugName: 'lexora-offline-validate',
      );
      if (rowCount != package.rows) {
        throw const FormatException(
          'Offline lexicon database row count did not match its manifest.',
        );
      }

      final finalFile = File(
        '${root.path}${Platform.pathSeparator}${edition.id}-${package.version}.sqlite',
      );
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await candidate.rename(finalFile.path);
      if (await archive.exists()) await archive.delete();
      final installed = InstalledOfflineLexicon(
        edition: edition,
        version: package.version,
        rows: package.rows,
        path: finalFile.path,
        bytes: package.databaseBytes,
        sha256: package.databaseSha256,
      );
      _installed[edition] = installed;
      _activeEdition = edition;
      await _saveRegistry();
      _downloadProgress = 1;
      onProgress?.call(1);
      DeveloperLogService.instance.log(
        'offline_lexicon.installed',
        data: {
          'edition': edition.id,
          'version': package.version,
          'rows': package.rows,
        },
      );
    } catch (error, stackTrace) {
      _lastError = error;
      DeveloperLogService.instance.log(
        'offline_lexicon.install_failed',
        data: {'edition': edition.id},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      _downloading = false;
      _downloadingEdition = null;
      notifyListeners();
    }
  }

  Future<void> _downloadArchive(
    OfflineLexiconPackage package,
    File destination,
    void Function(double? progress) onProgress,
  ) async {
    Object? lastError;
    for (final url in package.archiveUrls) {
      try {
        var existing = await destination.exists()
            ? await destination.length()
            : 0;
        if (existing >= package.archiveBytes) {
          if (existing > package.archiveBytes) {
            await destination.writeAsBytes(const [], flush: true);
            existing = 0;
          } else {
            onProgress(1);
            return;
          }
        }
        final request = http.Request('GET', url);
        request.headers['Accept'] = 'application/octet-stream';
        if (existing > 0) request.headers['Range'] = 'bytes=$existing-';
        final response = await _client
            .send(request)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200 && response.statusCode != 206) {
          throw HttpException(
            'Download returned ${response.statusCode}.',
            uri: url,
          );
        }
        if (existing > 0 && response.statusCode != 206) {
          existing = 0;
        }
        final sink = destination.openWrite(
          mode: existing > 0 ? FileMode.append : FileMode.write,
        );
        var received = existing;
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 30),
          )) {
            sink.add(chunk);
            received += chunk.length;
            onProgress(
              package.archiveBytes > 0
                  ? (received / package.archiveBytes).clamp(0, 1)
                  : null,
            );
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
        if (received != package.archiveBytes) {
          throw const FormatException(
            'Offline lexicon download was incomplete.',
          );
        }
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('All offline lexicon mirrors failed: $lastError');
  }

  Future<void> _saveRegistry() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _registryKey,
      jsonEncode(_installed.values.map((value) => value.toJson()).toList()),
    );
    if (_activeEdition == null) {
      await preferences.remove(_activeKey);
    } else {
      await preferences.setString(_activeKey, _activeEdition!.id);
    }
  }

  Future<void> _verifyFile(
    File file, {
    required int expectedBytes,
    required String expectedSha256,
  }) async {
    if (!await file.exists() || await file.length() != expectedBytes) {
      throw const FormatException('Offline lexicon file size is invalid.');
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString().toLowerCase() != expectedSha256.toLowerCase()) {
      throw const FormatException('Offline lexicon checksum is invalid.');
    }
  }

  @override
  Future<Map<String, dynamic>?> lookup(String normalizedTerm) async {
    await initialize();
    final item = active;
    if (item == null || normalizedTerm.isEmpty) return null;
    try {
      return await Isolate.run(
        () => _lookupDatabase(item.path, normalizedTerm),
        debugName: 'lexora-offline-lookup',
      );
    } catch (error, stackTrace) {
      DeveloperLogService.instance.log(
        'offline_lexicon.lookup_failed',
        data: {'edition': item.edition.id, 'term': normalizedTerm},
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> suggest(
    String normalizedPrefix, {
    int limit = 12,
  }) async {
    await initialize();
    final item = active;
    if (item == null || normalizedPrefix.isEmpty) return const [];
    try {
      return await Isolate.run(
        () => _suggestDatabase(item.path, normalizedPrefix, limit.clamp(1, 50)),
        debugName: 'lexora-offline-suggest',
      );
    } catch (error, stackTrace) {
      DeveloperLogService.instance.log(
        'offline_lexicon.suggest_failed',
        data: {'edition': item.edition.id, 'prefix': normalizedPrefix},
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

void _decompressGzip(String sourcePath, String destinationPath) {
  final input = InputFileStream(sourcePath);
  final output = OutputFileStream(destinationPath);
  try {
    if (!GZipDecoder().decodeStream(input, output)) {
      throw const FormatException('Offline lexicon archive is invalid.');
    }
  } finally {
    input.close();
    output.close();
  }
}

int _validateLexiconDatabase(String path) {
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final columns = database
        .select('PRAGMA table_info(entries)')
        .map((row) => row['name']?.toString())
        .toSet();
    if (!columns.containsAll({
      'word',
      'normalized_word',
      'frequency_rank',
      'enrichment_json',
    })) {
      throw const FormatException(
        'Offline lexicon database schema is unsupported.',
      );
    }
    return (database
                .select('SELECT count(*) AS count FROM entries')
                .single['count']
            as int?) ??
        0;
  } finally {
    database.close();
  }
}

Map<String, dynamic>? _lookupDatabase(String path, String normalizedTerm) {
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final rows = database.select(
      'SELECT * FROM entries WHERE normalized_word = ? LIMIT 1',
      [normalizedTerm],
    );
    if (rows.isEmpty) return null;
    return _lexiconRow(rows.single);
  } finally {
    database.close();
  }
}

List<Map<String, dynamic>> _suggestDatabase(
  String path,
  String normalizedPrefix,
  int limit,
) {
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final escaped = normalizedPrefix
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = database.select(
      r'''
SELECT word, normalized_word, frequency, frequency_rank
FROM entries
WHERE normalized_word LIKE ? ESCAPE '\'
ORDER BY frequency_rank
LIMIT ?
''',
      ['$escaped%', limit],
    );
    return rows
        .map(
          (row) => {
            'word': row['word'],
            'normalized_word': row['normalized_word'],
            'frequency': row['frequency'],
            'frequency_rank': row['frequency_rank'],
          },
        )
        .toList(growable: false);
  } finally {
    database.close();
  }
}

Map<String, dynamic> _lexiconRow(Row row) {
  final result = <String, dynamic>{};
  for (final column in row.keys) {
    final value = row[column];
    if (column.endsWith('_json')) {
      final key = column.substring(0, column.length - 5);
      try {
        result[key] = jsonDecode(value?.toString() ?? '');
      } catch (_) {
        result[key] = const [];
      }
    } else {
      result[column] = value;
    }
  }
  result['match_type'] = 'exact';
  return result;
}
