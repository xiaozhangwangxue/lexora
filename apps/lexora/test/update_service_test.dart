import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/services/update_service.dart';

void main() {
  final apkBytes = <int>[0x50, 0x4b, 0x03, 0x04, 1, 2, 3, 4, 5, 6];

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
}

Map<String, dynamic> _manifest(
  Uri origin,
  List<int> bytes, {
  String platform = 'android',
  String filename = 'lexora.apk',
  required List<String> sources,
}) => {
  'version': '9.9.9',
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
