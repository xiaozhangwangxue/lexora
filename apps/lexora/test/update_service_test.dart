import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/services/update_service.dart';

void main() {
  final apkBytes = <int>[0x50, 0x4b, 0x03, 0x04, 1, 2, 3, 4, 5, 6];

  test('macOS browser update opens the official download then exits', () async {
    final events = <String>[];
    final service = UpdateService(
      manifestUri: Uri.parse('https://lexora.12323456.xyz/version.json'),
      platformKey: 'macos',
      launchExternal: (uri) async {
        events.add(uri.toString());
        return true;
      },
      finishMacUpdate: () async => events.add('finish'),
      isMacOS: true,
    );
    await service.openMacDownloadPageAndQuit(
      UpdateInfo(
        version: '99.0.0',
        download: UpdateDownload(
          urls: [Uri.parse('https://example.invalid/lexora.dmg')],
          filename: 'lexora-macos-v99.0.0.dmg',
        ),
        notesZh: const [],
        notesEn: const [],
      ),
    );
    expect(events, ['https://example.invalid/lexora.dmg', 'finish']);
  });

  test('falls back to the next update manifest source', () async {
    await _withServer(
      (request, origin) async {
        if (request.uri.path == '/blocked-version.json') {
          request.response.statusCode = HttpStatus.forbidden;
          await request.response.close();
        } else if (request.uri.path == '/version.json') {
          await _json(
            request.response,
            _manifest(origin, apkBytes, sources: ['/updates/lexora.apk']),
          );
        }
      },
      (origin, cache) async {
        final service = UpdateService(
          manifestUris: [
            origin.resolve('/blocked-version.json'),
            origin.resolve('/version.json'),
          ],
          platformKey: 'android',
          cacheDirectory: () async => cache,
          isMacOS: false,
        );
        final update = await service.check();
        expect(update, isNotNull);
        expect(update!.download.urls.first.path, '/updates/lexora.apk');
      },
    );
  });

  test(
    'reports invalid manifests instead of claiming the app is current',
    () async {
      await _withServer(
        (request, origin) async {
          await _json(request.response, {'downloads': <String, Object>{}});
        },
        (origin, cache) async {
          final service = UpdateService(
            manifestUri: origin.resolve('/version.json'),
            platformKey: 'android',
            cacheDirectory: () async => cache,
            isMacOS: false,
          );
          await expectLater(service.check(), throwsA(isA<FormatException>()));
        },
      );
    },
  );

  test(
    'beta builds compare beta and stable channels and choose the newest',
    () async {
      await _withServer(
        (request, origin) async {
          if (request.uri.path == '/beta-version.json') {
            await _json(
              request.response,
              _manifest(
                origin,
                apkBytes,
                sources: ['/updates/lexora-beta.apk'],
                version: '4.1.0-beta.3',
              ),
            );
          } else if (request.uri.path == '/version.json') {
            await _json(
              request.response,
              _manifest(
                origin,
                apkBytes,
                sources: ['/updates/lexora-stable.apk'],
                version: '4.1.0',
              ),
            );
          }
        },
        (origin, cache) async {
          final service = UpdateService(
            manifestGroups: [
              [origin.resolve('/beta-version.json')],
              [origin.resolve('/version.json')],
            ],
            platformKey: 'android',
            cacheDirectory: () async => cache,
            isMacOS: false,
          );
          final update = await service.check();
          expect(update?.version, '4.1.0');
          expect(
            update?.download.urls.first.path,
            '/updates/lexora-stable.apk',
          );
        },
      );
    },
  );

  test('beta builds still receive a newer beta when stable is older', () async {
    await _withServer(
      (request, origin) async {
        final beta = request.uri.path == '/beta-version.json';
        await _json(
          request.response,
          _manifest(
            origin,
            apkBytes,
            sources: [
              beta ? '/updates/lexora-beta.apk' : '/updates/lexora-stable.apk',
            ],
            version: beta ? '4.1.0-beta.4' : '4.0.4',
          ),
        );
      },
      (origin, cache) async {
        final service = UpdateService(
          manifestGroups: [
            [origin.resolve('/beta-version.json')],
            [origin.resolve('/version.json')],
          ],
          platformKey: 'android',
          cacheDirectory: () async => cache,
          isMacOS: false,
        );
        expect((await service.check())?.version, '4.1.0-beta.4');
      },
    );
  });

  test(
    'uses the verified R2 source before opening the Android installer',
    () async {
      var primaryRequests = 0;
      var fallbackRequests = 0;
      var opened = false;
      await _withServer(
        (request, origin) async {
          if (request.uri.path == '/version.json') {
            await _json(
              request.response,
              _manifest(
                origin,
                apkBytes,
                sources: ['/updates/lexora.apk', '/github/lexora.apk'],
              ),
            );
          } else if (request.uri.path == '/updates/lexora.apk') {
            primaryRequests++;
            request.response.add(apkBytes);
            await request.response.close();
          } else if (request.uri.path == '/github/lexora.apk') {
            fallbackRequests++;
            request.response.add(apkBytes);
            await request.response.close();
          }
        },
        (origin, cache) async {
          final service = UpdateService(
            manifestUri: origin.resolve('/version.json'),
            platformKey: 'android',
            cacheDirectory: () async => cache,
            openInstaller: (file) async {
              final bytes = await file.readAsBytes();
              opened = bytes.length == apkBytes.length;
              return opened;
            },
            isMacOS: false,
          );
          final update = await service.check();
          expect(update, isNotNull);
          await service.downloadAndLaunch(update!, onProgress: (_) {});
        },
      );

      expect(primaryRequests, 1);
      expect(fallbackRequests, 0);
      expect(opened, isTrue);
    },
  );

  test(
    'falls back after a failed primary source and still verifies SHA-256',
    () async {
      var fallbackRequests = 0;
      await _withServer(
        (request, origin) async {
          if (request.uri.path == '/version.json') {
            await _json(
              request.response,
              _manifest(
                origin,
                apkBytes,
                sources: ['/updates/missing.apk', '/github/lexora.apk'],
              ),
            );
          } else if (request.uri.path == '/updates/missing.apk') {
            request.response.statusCode = 503;
            await request.response.close();
          } else if (request.uri.path == '/github/lexora.apk') {
            fallbackRequests++;
            request.response.add(apkBytes);
            await request.response.close();
          }
        },
        (origin, cache) async {
          final service = UpdateService(
            manifestUri: origin.resolve('/version.json'),
            platformKey: 'android',
            cacheDirectory: () async => cache,
            openInstaller: (_) async => true,
            isMacOS: false,
          );
          await service.downloadAndLaunch(
            (await service.check())!,
            onProgress: (_) {},
          );
        },
      );
      expect(fallbackRequests, 1);
    },
  );

  test(
    'never opens a package that fails the release integrity check',
    () async {
      var opened = false;
      await _withServer(
        (request, origin) async {
          if (request.uri.path == '/version.json') {
            final manifest = _manifest(
              origin,
              apkBytes,
              sources: ['/updates/lexora.apk'],
            );
            (manifest['verifiedDownloads']
                as Map<String, dynamic>)['android']['sha256'] = List.filled(
              64,
              '0',
            ).join();
            await _json(request.response, manifest);
          } else {
            request.response.add(apkBytes);
            await request.response.close();
          }
        },
        (origin, cache) async {
          final service = UpdateService(
            manifestUri: origin.resolve('/version.json'),
            platformKey: 'android',
            cacheDirectory: () async => cache,
            openInstaller: (_) async {
              opened = true;
              return true;
            },
            isMacOS: false,
          );
          await expectLater(
            service.downloadAndLaunch(
              (await service.check())!,
              onProgress: (_) {},
            ),
            throwsA(isA<HttpException>()),
          );
        },
      );
      expect(opened, isFalse);
    },
  );

  test(
    'finishes the macOS privacy flow only after the verified installer opens',
    () async {
      var finished = false;
      await _withServer(
        (request, origin) async {
          if (request.uri.path == '/version.json') {
            await _json(
              request.response,
              _manifest(
                origin,
                apkBytes,
                platform: 'macos',
                filename: 'lexora-macos.zip',
                sources: ['/updates/lexora-macos.zip'],
              ),
            );
          } else {
            request.response.add(apkBytes);
            await request.response.close();
          }
        },
        (origin, cache) async {
          final service = UpdateService(
            manifestUri: origin.resolve('/version.json'),
            platformKey: 'macos',
            cacheDirectory: () async => cache,
            openInstaller: (_) async => true,
            prepareMacInstaller: (_) async {},
            finishMacUpdate: () async => finished = true,
            isMacOS: true,
          );
          await service.downloadAndLaunch(
            (await service.check())!,
            onProgress: (_) {},
          );
        },
      );
      expect(finished, isTrue);
    },
  );

  test('decodes Chinese release notes as UTF-8 without a charset', () async {
    await _withServer(
      (request, origin) async {
        final bytes = utf8.encode(
          jsonEncode(
            _manifest(origin, apkBytes, sources: ['/updates/lexora.apk']),
          ),
        );
        request.response.headers.contentType = ContentType(
          'application',
          'octet-stream',
        );
        request.response.add(bytes);
        await request.response.close();
      },
      (origin, cache) async {
        final service = UpdateService(
          manifestUri: origin.resolve('/version.json'),
          platformKey: 'android',
          cacheDirectory: () async => cache,
          openInstaller: (_) async => true,
          isMacOS: false,
        );
        final update = await service.check();
        expect(update?.notesZh, ['测试']);
      },
    );
  });

  test(
    'prefers concise in-app notes over the full compatibility notes',
    () async {
      await _withServer(
        (request, origin) async {
          final manifest = _manifest(
            origin,
            apkBytes,
            sources: ['/updates/lexora.apk'],
          );
          manifest['inAppReleaseNotes'] = {
            'zh': ['精简更新'],
            'en': ['Concise update'],
          };
          await _json(request.response, manifest);
        },
        (origin, cache) async {
          final service = UpdateService(
            manifestUri: origin.resolve('/version.json'),
            platformKey: 'android',
            cacheDirectory: () async => cache,
            isMacOS: false,
          );
          final update = await service.check();
          expect(update?.notesZh, ['精简更新']);
          expect(update?.notesEn, ['Concise update']);
        },
      );
    },
  );

  test('prepares a macOS installer before opening it and then exits', () async {
    final events = <String>[];
    await _withServer(
      (request, origin) async {
        if (request.uri.path == '/version.json') {
          await _json(
            request.response,
            _manifest(
              origin,
              apkBytes,
              platform: 'macos',
              filename: 'lexora-macos.zip',
              sources: ['/updates/lexora-macos.zip'],
            ),
          );
        } else {
          request.response.add(apkBytes);
          await request.response.close();
        }
      },
      (origin, cache) async {
        final service = UpdateService(
          manifestUri: origin.resolve('/version.json'),
          platformKey: 'macos',
          cacheDirectory: () async => cache,
          prepareMacInstaller: (_) async => events.add('prepare'),
          openInstaller: (_) async {
            events.add('open');
            return true;
          },
          finishMacUpdate: () async => events.add('finish'),
          isMacOS: true,
        );
        await service.downloadAndLaunch(
          (await service.check())!,
          onProgress: (_) {},
        );
      },
    );
    expect(events, ['prepare', 'open', 'finish']);
  });

  test(
    'opens a verified macOS DMG when quarantine preparation is denied',
    () async {
      final events = <String>[];
      await _withServer(
        (request, origin) async {
          if (request.uri.path == '/version.json') {
            await _json(
              request.response,
              _manifest(
                origin,
                apkBytes,
                platform: 'macos',
                filename: 'lexora-macos.zip',
                sources: ['/updates/lexora-macos.zip'],
              ),
            );
          } else {
            request.response.add(apkBytes);
            await request.response.close();
          }
        },
        (origin, cache) async {
          final service = UpdateService(
            manifestUri: origin.resolve('/version.json'),
            platformKey: 'macos',
            cacheDirectory: () async => cache,
            prepareMacInstaller: (_) async {
              events.add('prepare-denied');
              throw const FileSystemException('Operation not permitted');
            },
            openInstaller: (_) async {
              events.add('open');
              return true;
            },
            finishMacUpdate: () async => events.add('finish'),
            isMacOS: true,
          );
          await service.downloadAndLaunch(
            (await service.check())!,
            onProgress: (_) {},
          );
        },
      );
      expect(events, ['prepare-denied', 'open', 'finish']);
    },
  );
}

Map<String, dynamic> _manifest(
  Uri origin,
  List<int> bytes, {
  String platform = 'android',
  String filename = 'lexora.apk',
  String version = '9.9.9',
  required List<String> sources,
}) => {
  'version': version,
  'releaseNotes': {
    'zh': ['测试'],
    'en': ['Test'],
  },
  'downloads': {platform: sources.first},
  'verifiedDownloads': {
    platform: {
      'filename': filename,
      'url': sources.first,
      'sources': sources
          .map((source) => origin.resolve(source).toString())
          .toList(),
      'sha256': sha256.convert(bytes).toString(),
      'size': bytes.length,
    },
  },
};

Future<void> _json(HttpResponse response, Map<String, dynamic> value) async {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(value));
  await response.close();
}

Future<void> _withServer(
  Future<void> Function(HttpRequest request, Uri origin) handler,
  Future<void> Function(Uri origin, Directory cache) body,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final origin = Uri.parse('http://${server.address.host}:${server.port}');
  final cache = await Directory.systemTemp.createTemp('lexora-update-test-');
  final subscription = server.listen((request) => handler(request, origin));
  try {
    await body(origin, cache);
  } finally {
    await subscription.cancel();
    await server.close(force: true);
    await cache.delete(recursive: true);
  }
}
