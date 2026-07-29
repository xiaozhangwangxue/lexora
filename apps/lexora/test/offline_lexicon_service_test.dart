import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexora/services/offline_lexicon_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'downloads, validates, activates, and searches an offline lexicon',
    () async {
      SharedPreferences.setMockInitialValues({});
      final temporary = await Directory.systemTemp.createTemp(
        'lexora-offline-test-',
      );
      addTearDown(() => temporary.delete(recursive: true));

      final source = File('${temporary.path}/source.sqlite');
      final database = sqlite3.open(source.path);
      database
        ..execute('''
CREATE TABLE entries (
  id INTEGER PRIMARY KEY,
  word TEXT NOT NULL,
  normalized_word TEXT NOT NULL,
  definition TEXT NOT NULL DEFAULT '',
  definition_zh TEXT NOT NULL DEFAULT '',
  frequency REAL NOT NULL DEFAULT 0,
  frequency_rank INTEGER NOT NULL,
  senses_json TEXT NOT NULL DEFAULT '[]',
  enrichment_json TEXT NOT NULL DEFAULT '{}'
)
''')
        ..execute(
          '''
INSERT INTO entries (
  id, word, normalized_word, definition, definition_zh,
  frequency, frequency_rank, senses_json, enrichment_json
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
          [
            1,
            'word',
            'word',
            'A unit of language.',
            '语言单位。',
            7.2,
            1,
            jsonEncode([
              {
                'pos': 'noun',
                'definitions': ['A unit of language.'],
              },
            ]),
            jsonEncode({'status': 'completed'}),
          ],
        )
        ..close();

      final databaseBytes = await source.readAsBytes();
      final archiveBytes = GZipEncoder().encode(databaseBytes);
      final manifest = {
        'schema_version': 1,
        'packages': {
          'fast20k': {
            'version': 'test-1',
            'rows': 1,
            'archive': {
              'urls': ['https://downloads.example.test/fast.sqlite.gz'],
              'bytes': archiveBytes.length,
              'sha256': sha256.convert(archiveBytes).toString(),
            },
            'database': {
              'filename': 'fast.sqlite',
              'bytes': databaseBytes.length,
              'sha256': sha256.convert(databaseBytes).toString(),
            },
          },
        },
      };
      final client = MockClient((request) async {
        if (request.url.path.endsWith('manifest.json')) {
          return http.Response.bytes(
            utf8.encode(jsonEncode(manifest)),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.endsWith('fast.sqlite.gz')) {
          return http.Response.bytes(
            archiveBytes,
            200,
            headers: {
              'content-type': 'application/octet-stream',
              'content-length': '${archiveBytes.length}',
            },
          );
        }
        return http.Response('not found', 404);
      });
      final service = OfflineLexiconService(
        client: client,
        manifestUri: Uri.parse(
          'https://downloads.example.test/offline/manifest.json',
        ),
        supportDirectory: () async => temporary,
      );

      await service.download(OfflineLexiconEdition.fast20k);

      expect(service.activeEdition, OfflineLexiconEdition.fast20k);
      expect(service.active?.rows, 1);
      expect(
        await service.lookup('word'),
        containsPair('definition_zh', '语言单位。'),
      );
      expect(
        await service.suggest('wo'),
        contains(containsPair('normalized_word', 'word')),
      );

      await service.activate(null);
      expect(service.active, isNull);
      expect(await service.lookup('word'), isNull);
    },
  );
}
