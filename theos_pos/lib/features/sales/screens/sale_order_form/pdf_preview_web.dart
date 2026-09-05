import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Opens the browser print dialog without injecting inline JavaScript.
///
/// Keeping this implementation CSP-compatible also avoids the Printing
/// package's runtime PDF.js CDN fallback and `eval`-based feature detection.
Future<String?> openPdfForPrint(Uint8List pdfBytes, String filename) async {
  final pdfFile = web.Blob(
    [pdfBytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final pdfUrl = web.URL.createObjectURL(pdfFile);
  final frame = web.document.createElement('iframe') as web.HTMLIFrameElement;
  final completer = Completer<String?>();

  frame.style
    ..visibility = 'hidden'
    ..height = '0'
    ..width = '0'
    ..position = 'absolute';
  frame.src = pdfUrl;

  late final web.EventListener loadListener;
  loadListener = ((web.Event _) {
    frame.removeEventListener('load', loadListener);
    try {
      frame.contentWindow?.focus();
      frame.contentWindow?.print();
      completer.complete(null);
    } catch (error) {
      completer.complete('No se pudo abrir el diálogo de impresión: $error');
    } finally {
      Future<void>.delayed(const Duration(seconds: 1), () {
        frame.remove();
        web.URL.revokeObjectURL(pdfUrl);
      });
    }
  }).toJS;
  frame.addEventListener('load', loadListener);
  web.document.body!.appendChild(frame);

  return completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      frame.removeEventListener('load', loadListener);
      frame.remove();
      web.URL.revokeObjectURL(pdfUrl);
      return 'El navegador no pudo cargar el PDF para imprimir.';
    },
  );
}

/// On web, trigger a browser download for the PDF.
Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
  final base64Data = base64Encode(pdfBytes);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = 'data:application/pdf;base64,$base64Data';
  anchor.download = filename;
  anchor.style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
