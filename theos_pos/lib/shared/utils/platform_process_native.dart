import 'dart:io';

/// Open a directory in the system file manager (native platforms).
Future<void> openDirectory(String path) async {
  await Process.run('open', [path]);
}
