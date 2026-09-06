import 'dart:typed_data';

import 'branding_cache_store.dart';

BrandingCacheStore createBrandingCacheStore() => _MemoryBrandingCacheStore();

final class _MemoryBrandingCacheStore implements BrandingCacheStore {
  final Map<String, Uint8List> _bytes = {};
  final Map<String, String> _text = {};

  @override
  Future<Uint8List?> readBytes(String key) async => _bytes[key];

  @override
  Future<String?> readText(String key) async => _text[key];

  @override
  Future<void> writeBytes(String key, Uint8List value) async {
    _bytes[key] = Uint8List.fromList(value);
  }

  @override
  Future<void> writeText(String key, String value) async {
    _text[key] = value;
  }
}
