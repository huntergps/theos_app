/// Stub for web — no file system access for database files.

Future<List<Map<String, dynamic>>> listDbFiles() async => [];

Future<bool> deleteFileAt(String path) async => false;

Future<bool> deleteDbFile(String databaseName) async => false;
