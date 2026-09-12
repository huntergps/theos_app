import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Guarda el Excel y devuelve **dónde quedó**, para poder decírselo a quien lo
/// pidió.
///
/// Un botón de exportar que no dice dónde dejó el fichero obliga a buscarlo, y
/// en un mostrador eso significa no encontrarlo.
Future<String> saveExport(List<int> bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/$fileName.xlsx';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}
