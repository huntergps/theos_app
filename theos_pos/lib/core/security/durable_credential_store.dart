import 'package:odoo_sdk/odoo_sdk.dart' show SecureCredentialStore;

/// Marker for platform stores whose values survive an application restart.
///
/// Clean installs write credentials directly to this store; plaintext
/// credential storage is not supported.
abstract interface class DurableSecureCredentialStore
    implements SecureCredentialStore {}
