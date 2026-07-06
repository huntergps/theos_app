import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// No-op on native — use shareFile instead.
void downloadBytes(List<int> bytes, String filename) {
  // No-op on native
}

/// Save bytes to temp file and share via system share sheet.
Future<void> shareFile(List<int> bytes, String filename, {String? text}) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/$filename';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], text: text ?? filename),
  );
}
