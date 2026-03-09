import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Download bytes as a file in the browser.
void downloadBytes(List<int> bytes, String filename) {
  final base64Data = base64Encode(bytes);
  final mimeType = filename.endsWith('.xlsx')
      ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      : 'application/octet-stream';
  final anchor = html.AnchorElement()
    ..href = 'data:$mimeType;base64,$base64Data'
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

/// On web, "sharing" is just downloading.
Future<void> shareFile(List<int> bytes, String filename, {String? text}) async {
  downloadBytes(bytes, filename);
}
