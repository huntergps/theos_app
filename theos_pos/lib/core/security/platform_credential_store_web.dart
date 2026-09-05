import 'package:odoo_sdk/odoo_sdk.dart' show SecureCredentialStore;

import 'ephemeral_credential_store.dart';

const isPlatformCredentialStoreDurable = false;

SecureCredentialStore createPlatformCredentialStore() {
  return EphemeralCredentialStore();
}
