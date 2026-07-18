import 'dart:io';

void main() {
  final project = File('macos/Runner.xcodeproj/project.pbxproj');
  if (!project.existsSync()) {
    stderr.writeln('Run flutter create for macOS before this script.');
    exitCode = 1;
    return;
  }

  final source = project.readAsStringSync();
  const marker = r'export PATH=\"$SRCROOT/../tool:$PATH\"; ';
  if (source.contains(marker)) return;
  const shellScriptPrefix = 'shellScript = "';
  if (!source.contains(shellScriptPrefix)) {
    stderr.writeln('No Xcode shell build phases were found.');
    exitCode = 1;
    return;
  }
  project.writeAsStringSync(
    source.replaceAll(shellScriptPrefix, '$shellScriptPrefix$marker'),
  );
}
