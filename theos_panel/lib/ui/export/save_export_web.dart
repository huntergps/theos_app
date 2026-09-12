import 'dart:convert';

import 'package:web/web.dart' as web;

const _xlsx =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// En el navegador guardar es descargar: el fichero va a donde el navegador
/// deje las descargas, que no podemos saber desde aquí. Por eso se devuelve el
/// nombre y no una ruta inventada.
Future<String> saveExport(List<int> bytes, String fileName) async {
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = 'data:$_xlsx;base64,${base64Encode(bytes)}';
  anchor.download = '$fileName.xlsx';
  anchor.style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  return '$fileName.xlsx';
}
