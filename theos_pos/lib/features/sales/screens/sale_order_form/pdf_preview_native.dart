import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Open PDF in system viewer for printing (native platforms).
/// Returns an error message string if failed, or null on success.
Future<String?> openPdfForPrint(Uint8List pdfBytes, String filename) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$filename');
  await file.writeAsBytes(pdfBytes);

  final result = await OpenFile.open(file.path);
  if (result.type != ResultType.done) {
    return 'No se pudo abrir el PDF: ${result.message}';
  }
  return null;
}

/// Share PDF using system share sheet (native platforms).
Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$filename');
  await file.writeAsBytes(pdfBytes);

  // ignore: deprecated_member_use
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: filename,
  );
}
