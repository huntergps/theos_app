import '../auth/odoo_auth_strategy.dart';

/// Abstract interface for persisting Odoo session data.
///
/// Implement this to provide session storage using SharedPreferences,
/// secure storage, or any other persistence mechanism:
///
/// ```dart
/// class SecureSessionPersistence implements SessionPersistence {
///   final FlutterSecureStorage _storage;
///   SecureSessionPersistence(this._storage);
///
///   @override
///   Future<void> saveSession(OdooSessionResult session) async {
///     await _storage.write(key: 'session', value: jsonEncode(session.toMap()));
///   }
///   // ...
/// }
/// ```
abstract class SessionPersistence {
  /// Save the current session to persistent storage.
  Future<void> saveSession(OdooSessionResult session);

  /// Load a previously saved session, or null if none exists.
  Future<OdooSessionResult?> loadSession();

  /// Clear any persisted session data.
  Future<void> clearSession();
}
