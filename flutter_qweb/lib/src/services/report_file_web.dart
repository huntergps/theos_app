import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Download PDF in the browser.
Future<bool> saveAndOpen(Uint8List pdfBytes, String filename) async {
  final base64Data = base64Encode(pdfBytes);
  final anchor = html.AnchorElement()
    ..href = 'data:application/pdf;base64,$base64Data'
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return true;
}
