import 'dart:io';

const minimumWidth = 980;
const minimumHeight = 680;

void main() {
  _configureWindows();
  _configureLinux();
}

void _configureWindows() {
  final file = File('windows/runner/win32_window.cpp');
  if (!file.existsSync()) return;
  var source = file.readAsStringSync();
  if (source.contains('LEXORA_MINIMUM_WINDOW_SIZE')) return;
  const marker = '  switch (message) {';
  if (!source.contains(marker)) {
    throw StateError('Could not locate the Windows message switch.');
  }
  source = source.replaceFirst(marker, '''  // LEXORA_MINIMUM_WINDOW_SIZE
  if (message == WM_GETMINMAXINFO) {
    auto* constraints = reinterpret_cast<MINMAXINFO*>(lparam);
    const auto scale = GetDpiForWindow(hwnd) / 96.0;
    constraints->ptMinTrackSize.x =
        static_cast<LONG>($minimumWidth * scale);
    constraints->ptMinTrackSize.y =
        static_cast<LONG>($minimumHeight * scale);
    return 0;
  }

$marker''');
  file.writeAsStringSync(source);
}

void _configureLinux() {
  final file = File('linux/runner/my_application.cc');
  if (!file.existsSync()) return;
  var source = file.readAsStringSync();
  if (source.contains('LEXORA_MINIMUM_WINDOW_SIZE')) return;
  final defaultSize = RegExp(
    r'gtk_window_set_default_size\(window,\s*\d+,\s*\d+\);',
  );
  final match = defaultSize.firstMatch(source);
  if (match == null) {
    throw StateError('Could not locate the Linux default window size.');
  }
  source = source.replaceRange(match.end, match.end, '''
  // LEXORA_MINIMUM_WINDOW_SIZE
  gtk_widget_set_size_request(
      GTK_WIDGET(window), $minimumWidth, $minimumHeight);''');
  file.writeAsStringSync(source);
}
