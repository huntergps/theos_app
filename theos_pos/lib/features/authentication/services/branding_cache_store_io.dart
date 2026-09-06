import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'branding_cache_store.dart';

BrandingCacheStore createBrandingCacheStore() => _FileBrandingCacheStore();

final class _FileBrandingCacheStore implements BrandingCacheStore {
  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'branding_cache'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _file(String key) async {
    final directory = await _directory();
    return File(p.join(directory.path, key));
  }

  @override
  Future<Uint8List?> readBytes(String key) async {
    try {
      final file = await _file(key);
      return await file.exists() ? await file.readAsBytes() : null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<String?> readText(String key) async {
    try {
      final file = await _file(key);
      return await file.exists() ? await file.readAsString() : null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> writeBytes(String key, Uint8List value) async {
    final file = await _file(key);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(value, flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> writeText(String key, String value) async {
    final file = await _file(key);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(value, flush: true);
    await temporary.rename(file.path);
  }
}
