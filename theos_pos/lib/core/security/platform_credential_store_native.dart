import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show SecureCredentialStore;

import 'durable_credential_store.dart';

const isPlatformCredentialStoreDurable = true;

const nativeFlutterSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    resetOnError: false,
    migrateOnAlgorithmChange: true,
    migrateWithBackup: true,
    storageNamespace: 'theos_pos_credentials',
  ),
  iOptions: IOSOptions(
    accountName: 'tech.galapagos.theos_pos.credentials',
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  ),
  mOptions: MacOsOptions(
    accountName: 'tech.galapagos.theos_pos.credentials',
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
    usesDataProtectionKeychain: true,
  ),
  wOptions: WindowsOptions(useBackwardCompatibility: false),
);

final class FlutterSecureStorageCredentialStore
    implements DurableSecureCredentialStore {
  const FlutterSecureStorageCredentialStore({
    this._storage = nativeFlutterSecureStorage,
  });

  final FlutterSecureStorage _storage;

  @override
  Future<void> store(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> retrieve(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() {
    return _storage.deleteAll();
  }

  @override
  Future<bool> containsKey(String key) {
    return _storage.containsKey(key: key);
  }
}

SecureCredentialStore createPlatformCredentialStore() {
  return const FlutterSecureStorageCredentialStore();
}
