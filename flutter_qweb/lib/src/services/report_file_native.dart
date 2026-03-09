import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Save PDF to temp file and open with system viewer (native platforms).
Future<bool> saveAndOpen(Uint8List pdfBytes, String filename) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$filename');
  await file.writeAsBytes(pdfBytes);

  final result = await OpenFile.open(file.path);
  return result.type == ResultType.done;
}
