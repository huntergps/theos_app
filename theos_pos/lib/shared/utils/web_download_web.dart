import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Download bytes as a file in the browser.
void downloadBytes(List<int> bytes, String filename) {
  final base64Data = base64Encode(bytes);
  final mimeType = filename.endsWith('.xlsx')
      ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      : 'application/octet-stream';
  final anchor =
      web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = 'data:$mimeType;base64,$base64Data';
  anchor.download = filename;
  anchor.style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
}

/// On web, "sharing" is just downloading.
Future<void> shareFile(List<int> bytes, String filename,
    {String? text}) async {
  downloadBytes(bytes, filename);
}
