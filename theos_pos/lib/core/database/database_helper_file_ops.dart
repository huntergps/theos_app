import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// List database files in the app documents directory (native platforms).
Future<List<Map<String, dynamic>>> listDbFiles() async {
  final dbDir = await getApplicationDocumentsDirectory();
  final files = dbDir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('.db') || f.path.endsWith('.sqlite'),
  );

  final results = <Map<String, dynamic>>[];
  for (final file in files) {
    final stat = await file.stat();
    results.add({
      'path': file.path,
      'name': file.path.split('/').last,
      'sizeBytes': stat.size,
      'lastModified': stat.modified,
    });
  }
  return results;
}

/// Delete a file at the given path.
Future<bool> deleteFileAt(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
    return true;
  }
  return false;
}

/// Delete a database file by name in the app documents directory.
Future<bool> deleteDbFile(String databaseName) async {
  final dbDir = await getApplicationDocumentsDirectory();
  final file = File('${dbDir.path}/$databaseName');
  if (await file.exists()) {
    await file.delete();
    return true;
  }
  return false;
}
