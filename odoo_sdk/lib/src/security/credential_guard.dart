/// SEC-06: Guard that manages credential lifecycle in memory.
///
/// Provides:
/// - Lazy loading from [SecureCredentialStore] (credentials not kept in memory)
/// - Auto-clear after configurable idle timeout
/// - Explicit clear method for logout flows
///
/// Usage:
/// ```dart
/// final guard = CredentialGuard(
///   store: mySecureStore,
///   contextId: 'pos-store-1',
/// );
///
/// // Lazy-loads from store on first access
/// final apiKey = await guard.getApiKey();
///
/// // Clear from memory (e.g., on app pause/logout)
/// guard.clearMemoryCache();
/// ```
library;

import 'dart:async';

import 'secure_credential_store.dart';

/// Guard that manages credential lifecycle in memory.
///
/// Wraps a [SecureCredentialStore] and adds an in-memory cache layer
/// with automatic timeout clearing. Credentials are loaded lazily from
/// the store on first access and can be explicitly cleared when the
/// app pauses, locks, or the user logs out.
class CredentialGuard {
  final SecureCredentialStore _store;
  final String _contextId;

  /// Cached credentials (cleared on [clearMemoryCache] or timeout).
  final Map<String, String> _cache = {};

  /// Auto-clear timer.
  Timer? _clearTimer;

  /// Duration after which cached credentials are cleared from memory.
  ///
  /// Set to `null` to disable auto-clear (credentials stay in memory
  /// until explicitly cleared or the guard is disposed).
  final Duration? autoClearAfter;

  /// Creates a [CredentialGuard] backed by the given [store].
  ///
  /// The [contextId] scopes all keys to avoid collisions when multiple
  /// Odoo contexts are used simultaneously (e.g., POS + BackOffice).
  ///
  /// By default, cached credentials are auto-cleared after 5 minutes
  /// of inactivity. Pass `autoClearAfter: null` to disable this.
  CredentialGuard({
    required SecureCredentialStore store,
    required String contextId,
    this.autoClearAfter = const Duration(minutes: 5),
  })  : _store = store,
        _contextId = contextId;

  /// The context ID this guard is scoped to.
  String get contextId => _contextId;

  /// Retrieve a credential, loading from secure store if not cached.
  ///
  /// Returns `null` if the credential is not found in either the
  /// cache or the underlying store.
  Future<String?> get(String key) async {
    final scopedKey = CredentialKeys.scoped(_contextId, key);

    // Check memory cache first
    if (_cache.containsKey(scopedKey)) {
      _resetTimer();
      return _cache[scopedKey];
    }

    // Load from secure store
    final value = await _store.retrieve(scopedKey);
    if (value != null) {
      _cache[scopedKey] = value;
      _resetTimer();
    }
    return value;
  }

  /// Store a credential in both secure store and memory cache.
  Future<void> set(String key, String value) async {
    final scopedKey = CredentialKeys.scoped(_contextId, key);
    await _store.store(scopedKey, value);
    _cache[scopedKey] = value;
    _resetTimer();
  }

  /// Delete a credential from both secure store and memory cache.
  Future<void> remove(String key) async {
    final scopedKey = CredentialKeys.scoped(_contextId, key);
    await _store.delete(scopedKey);
    _cache.remove(scopedKey);
  }

  /// Convenience: get API key for this context.
  Future<String?> getApiKey() => get(CredentialKeys.apiKey);

  /// Convenience: store API key for this context.
  Future<void> setApiKey(String value) => set(CredentialKeys.apiKey, value);

  /// Clear all cached credentials from memory.
  ///
  /// Does NOT delete from secure store -- only clears the in-memory
  /// cache. Call this on app pause, screen lock, or logout.
  void clearMemoryCache() {
    _cache.clear();
    _clearTimer?.cancel();
    _clearTimer = null;
  }

  /// Delete all credentials for this context from both memory and store.
  ///
  /// Iterates over all cached keys and removes them from the underlying
  /// store, then clears the in-memory cache.
  Future<void> deleteAll() async {
    // Delete each cached key from store
    for (final key in _cache.keys.toList()) {
      await _store.delete(key);
    }
    _cache.clear();
    _clearTimer?.cancel();
    _clearTimer = null;
  }

  /// Whether there are credentials in the memory cache.
  bool get hasCachedCredentials => _cache.isNotEmpty;

  /// Dispose the guard, clearing memory and cancelling timers.
  ///
  /// After calling [dispose], the guard should not be used again.
  void dispose() {
    clearMemoryCache();
  }

  void _resetTimer() {
    _clearTimer?.cancel();
    if (autoClearAfter != null) {
      _clearTimer = Timer(autoClearAfter!, clearMemoryCache);
    }
  }
}
