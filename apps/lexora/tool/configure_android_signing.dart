import 'dart:io';

void main() {
  final file = File('android/app/build.gradle.kts');
  var source = file.readAsStringSync();
  const signingConfig = r'''
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH"))
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }
''';

  if (!source.contains('System.getenv("ANDROID_KEYSTORE_PATH")')) {
    source = source.replaceFirst('android {\n', 'android {\n$signingConfig');
  }
  source = source.replaceFirst(
    'signingConfig = signingConfigs.getByName("debug")',
    'signingConfig = signingConfigs.getByName("release")',
  );
  if (!source.contains('signingConfigs.getByName("release")')) {
    stderr.writeln('Could not locate the generated release build type.');
    exitCode = 1;
    return;
  }
  file.writeAsStringSync(source);
}
