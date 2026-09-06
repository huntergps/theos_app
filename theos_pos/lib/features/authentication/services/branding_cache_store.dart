import 'dart:typed_data';

import 'branding_cache_store_stub.dart'
    if (dart.library.io) 'branding_cache_store_io.dart'
    as platform;

abstract interface class BrandingCacheStore {
  Future<Uint8List?> readBytes(String key);

  Future<String?> readText(String key);

  Future<void> writeBytes(String key, Uint8List value);

  Future<void> writeText(String key, String value);
}

BrandingCacheStore createPlatformBrandingCacheStore() =>
    platform.createBrandingCacheStore();
