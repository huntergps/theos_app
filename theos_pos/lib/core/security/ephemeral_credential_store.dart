import 'package:odoo_sdk/odoo_sdk.dart' show SecureCredentialStore;

/// Process-local credential storage for platforms that must not persist secrets.
///
/// Every instance owns an independent in-memory map. Creating a new instance,
/// such as after a web page refresh, starts with no credentials.
final class EphemeralCredentialStore implements SecureCredentialStore {
  final Map<String, String> _credentials = <String, String>{};

  @override
  Future<void> store(String key, String value) async {
    _credentials[key] = value;
  }

  @override
  Future<String?> retrieve(String key) async => _credentials[key];

  @override
  Future<void> delete(String key) async {
    _credentials.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _credentials.clear();
  }

  @override
  Future<bool> containsKey(String key) async => _credentials.containsKey(key);
}
