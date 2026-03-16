import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Download PDF in the browser.
Future<bool> saveAndOpen(Uint8List pdfBytes, String filename) async {
  final base64Data = base64Encode(pdfBytes);
  final anchor =
      web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = 'data:application/pdf;base64,$base64Data';
  anchor.download = filename;
  anchor.style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  return true;
}
