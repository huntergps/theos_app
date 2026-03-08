/// SEC-06: Abstract interface for secure credential storage.
///
/// Applications should implement this using platform-specific secure storage:
/// - iOS: Keychain Services
/// - Android: EncryptedSharedPreferences / Keystore
/// - Desktop: OS keychain (libsecret, Windows Credential Manager)
/// - Web: encrypted localStorage with Web Crypto API
///
/// The SDK never stores credentials persistently -- this is the app's
/// responsibility.
///
/// Example implementation:
/// ```dart
/// class FlutterSecureStore implements SecureCredentialStore {
///   final FlutterSecureStorage _storage = const FlutterSecureStorage();
///
///   @override
///   Future<void> store(String key, String value) =>
///       _storage.write(key: key, value: value);
///
///   @override
///   Future<String?> retrieve(String key) =>
///       _storage.read(key: key);
///
///   @override
///   Future<void> delete(String key) =>
///       _storage.delete(key: key);
///
///   @override
///   Future<void> deleteAll() => _storage.deleteAll();
///
///   @override
///   Future<bool> containsKey(String key) =>
///       _storage.containsKey(key: key);
/// }
/// ```
library;

/// Abstract interface for secure credential storage.
///
/// Implement this with platform-specific secure storage backends.
/// The SDK uses this interface to read/write credentials without
/// knowing how they are persisted.
abstract class SecureCredentialStore {
  /// Store a credential securely.
  ///
  /// Overwrites any existing value for [key].
  Future<void> store(String key, String value);

  /// Retrieve a stored credential.
  ///
  /// Returns `null` if the [key] doesn't exist.
  Future<String?> retrieve(String key);

  /// Delete a stored credential.
  ///
  /// No-op if the [key] doesn't exist.
  Future<void> delete(String key);

  /// Delete all stored credentials.
  Future<void> deleteAll();

  /// Check if a credential exists for the given [key].
  Future<bool> containsKey(String key);
}

/// Well-known credential keys used by the SDK.
///
/// Use these constants when storing/retrieving SDK-managed credentials
/// to ensure consistency across the application.
abstract class CredentialKeys {
  /// API key for Odoo JSON-2 authentication.
  static const String apiKey = 'odoo_api_key';

  /// Session ID from authentication.
  static const String sessionId = 'odoo_session_id';

  /// Session token for WebSocket authentication.
  static const String sessionToken = 'odoo_session_token';

  /// Refresh token (if token refresh is configured).
  static const String refreshToken = 'odoo_refresh_token';

  /// Generate a context-scoped key.
  ///
  /// Prefixes the [key] with the [contextId] for multi-context isolation.
  ///
  /// Example:
  /// ```dart
  /// final scoped = CredentialKeys.scoped('pos-store-1', CredentialKeys.apiKey);
  /// // Result: 'pos-store-1:odoo_api_key'
  /// ```
  static String scoped(String contextId, String key) => '$contextId:$key';
}
