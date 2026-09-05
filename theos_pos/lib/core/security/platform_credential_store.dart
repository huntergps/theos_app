import 'package:odoo_sdk/odoo_sdk.dart' show SecureCredentialStore;

import 'platform_credential_store_web.dart'
    if (dart.library.io) 'platform_credential_store_native.dart'
    as implementation;

enum PlatformCredentialStorePersistence { ephemeral, durable }

/// Creates the credential backend selected at compile time for this platform.
///
/// Web deliberately resolves to a process-local store and never imports the
/// flutter_secure_storage adapter. Native platforms resolve to durable OS
/// storage.
SecureCredentialStore createPlatformCredentialStore() {
  return implementation.createPlatformCredentialStore();
}

PlatformCredentialStorePersistence get platformCredentialStorePersistence =>
    implementation.isPlatformCredentialStoreDurable
    ? PlatformCredentialStorePersistence.durable
    : PlatformCredentialStorePersistence.ephemeral;
