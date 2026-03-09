import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// On web, printing is handled by the Printing package in the caller.
/// This is a no-op — returns null (no error).
Future<String?> openPdfForPrint(Uint8List pdfBytes, String filename) async {
  return null;
}

/// On web, trigger a browser download for the PDF.
Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
  final base64Data = base64Encode(pdfBytes);
  final anchor = html.AnchorElement()
    ..href = 'data:application/pdf;base64,$base64Data'
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
