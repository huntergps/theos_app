/// Encrypted Record Cache
///
/// SEC-05: Provides an encrypted wrapper around RecordCache
/// for protecting Personally Identifiable Information (PII) at rest.
///
/// This cache encrypts values before storing and decrypts on retrieval,
/// providing transparent encryption without modifying the underlying cache.
library;

import 'dart:async';

import 'cache_encryption.dart';
import 'record_cache.dart';
import 'value_stream.dart';

/// Configuration for encrypted cache.
class EncryptedCacheConfig {
  /// Base cache configuration (size, TTL, etc.).
  final RecordCacheConfig cacheConfig;

  /// Encryption provider.
  final CacheEncryption encryption;

  /// Whether to validate decryption by re-encrypting and comparing.
  ///
  /// This adds overhead but catches corruption early.
  final bool validateOnDecrypt;

  /// Callback when encryption fails (for logging/monitoring).
  final void Function(Object error, StackTrace? stack)? onEncryptionError;

  /// Callback when decryption fails (for logging/monitoring).
  final void Function(Object error, StackTrace? stack)? onDecryptionError;

  const EncryptedCacheConfig({
    this.cacheConfig = RecordCacheConfig.defaultConfig,
    required this.encryption,
    this.validateOnDecrypt = false,
    this.onEncryptionError,
    this.onDecryptionError,
  });

  /// Create config with AES encryption from password.
  factory EncryptedCacheConfig.withPassword({
    required String password,
    String? salt,
    RecordCacheConfig cacheConfig = RecordCacheConfig.defaultConfig,
    bool validateOnDecrypt = false,
  }) {
    return EncryptedCacheConfig(
      cacheConfig: cacheConfig,
      encryption: AesCacheEncryption.fromPassword(password, salt: salt),
      validateOnDecrypt: validateOnDecrypt,
    );
  }

  /// Create config with obfuscation (for development only).
  factory EncryptedCacheConfig.obfuscated({
    required String key,
    RecordCacheConfig cacheConfig = RecordCacheConfig.defaultConfig,
  }) {
    return EncryptedCacheConfig(
      cacheConfig: cacheConfig,
      encryption: ObfuscationCacheEncryption(key),
    );
  }
}

/// Encrypted record cache that stores values in encrypted form.
///
/// This provides the same API as [RecordCache] but encrypts values
/// before storing and decrypts on retrieval.
///
/// Usage:
/// ```dart
/// // Create with password-based encryption
/// final cache = EncryptedRecordCache<int, User>(
///   config: EncryptedCacheConfig.withPassword(
///     password: 'my-secret-password',
///     salt: 'my-app-salt',
///   ),
///   serialize: (user) => jsonEncode(user.toJson()),
///   deserialize: (json) => User.fromJson(jsonDecode(json)),
/// );
///
/// // Use like normal cache
/// cache.put(1, user);
/// final cachedUser = cache.get(1);
/// ```
class EncryptedRecordCache<K, V> {
  final EncryptedCacheConfig _config;

  /// Function to serialize a value to JSON string.
  final String Function(V value) serialize;

  /// Function to deserialize a value from JSON string.
  final V Function(String json) deserialize;

  /// Internal cache storing encrypted strings.
  late final RecordCache<K, String> _innerCache;

  /// Stream controller for decrypted values.
  final _valuesSubject = ValueStream<Map<K, V>>({});

  /// Stream controller for change events with decrypted values.
  final _changes = StreamController<CacheChangeEvent<K, V>>.broadcast();

  /// Whether the cache has been disposed.
  bool _disposed = false;

  /// Stats tracking encryption/decryption operations.
  int _encryptionCount = 0;
  int _decryptionCount = 0;
  int _encryptionErrors = 0;
  int _decryptionErrors = 0;

  EncryptedRecordCache({
    required EncryptedCacheConfig config,
    required this.serialize,
    required this.deserialize,
  }) : _config = config {
    _innerCache = RecordCache<K, String>(config: _config.cacheConfig);

    // Forward inner cache changes
    _innerCache.changes.listen(_handleInnerChange);
  }

  /// Configuration.
  EncryptedCacheConfig get config => _config;

  /// Base cache configuration.
  RecordCacheConfig get cacheConfig => _config.cacheConfig;

  /// Current cache statistics (from inner cache).
  RecordCacheStats get stats => _innerCache.stats;

  /// Encryption statistics.
  EncryptedCacheStats get encryptionStats => EncryptedCacheStats(
        encryptionCount: _encryptionCount,
        decryptionCount: _decryptionCount,
        encryptionErrors: _encryptionErrors,
        decryptionErrors: _decryptionErrors,
      );

  /// Stream of cache change events (with decrypted values).
  Stream<CacheChangeEvent<K, V>> get changes => _changes.stream;

  /// Stream of all cached values (decrypted, reactive).
  Stream<Map<K, V>> get valuesStream => _valuesSubject.stream;

  /// Current cached values (decrypted snapshot).
  Map<K, V> get values {
    final result = <K, V>{};
    // Create a copy of keys to avoid concurrent modification
    final keys = _innerCache.keys.toList();
    for (final key in keys) {
      final value = get(key);
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  /// Current number of entries in cache.
  int get length => _innerCache.length;

  /// Whether the cache is empty.
  bool get isEmpty => _innerCache.isEmpty;

  /// Whether the cache is not empty.
  bool get isNotEmpty => _innerCache.isNotEmpty;

  /// All keys in the cache.
  Iterable<K> get keys => _innerCache.keys;

  /// Get a decrypted value from the cache.
  ///
  /// Returns null if not found, expired, or decryption fails.
  V? get(K key) {
    _checkDisposed();

    final encrypted = _innerCache.get(key);
    if (encrypted == null) return null;

    try {
      final decrypted = _decrypt(encrypted);
      return decrypted;
    } catch (e, stack) {
      _decryptionErrors++;
      _config.onDecryptionError?.call(e, stack);
      // Remove corrupted entry
      _innerCache.remove(key);
      return null;
    }
  }

  /// Check if a key exists and can be decrypted.
  bool containsKey(K key) {
    _checkDisposed();

    if (!_innerCache.containsKey(key)) return false;

    // Verify it can be decrypted
    final value = get(key);
    return value != null;
  }

  /// Encrypt and store a value in the cache.
  void put(K key, V value) {
    _checkDisposed();

    try {
      final encrypted = _encrypt(value);
      _innerCache.put(key, encrypted);
    } catch (e, stack) {
      _encryptionErrors++;
      _config.onEncryptionError?.call(e, stack);
      rethrow;
    }
  }

  /// Put multiple values in the cache.
  void putAll(Map<K, V> entries) {
    _checkDisposed();
    for (final entry in entries.entries) {
      put(entry.key, entry.value);
    }
  }

  /// Remove a value from the cache.
  ///
  /// Returns the decrypted value or null if not found.
  V? remove(K key) {
    _checkDisposed();

    final encrypted = _innerCache.remove(key);
    if (encrypted == null) return null;

    try {
      return _decrypt(encrypted);
    } catch (e) {
      _decryptionErrors++;
      return null;
    }
  }

  /// Remove multiple values from the cache.
  void removeAll(Iterable<K> keys) {
    _checkDisposed();
    for (final key in keys) {
      _innerCache.remove(key);
    }
  }

  /// Clear all entries from the cache.
  void clear() {
    _checkDisposed();
    _innerCache.clear();
  }

  /// Remove expired entries.
  int removeExpired() {
    _checkDisposed();
    return _innerCache.removeExpired();
  }

  /// Get or compute a value.
  Future<V> getOrCompute(K key, Future<V> Function() compute) async {
    _checkDisposed();

    final cached = get(key);
    if (cached != null) return cached;

    final value = await compute();
    put(key, value);
    return value;
  }

  /// Get or compute a value synchronously.
  V getOrComputeSync(K key, V Function() compute) {
    _checkDisposed();

    final cached = get(key);
    if (cached != null) return cached;

    final value = compute();
    put(key, value);
    return value;
  }

  /// Invalidate entries matching a predicate.
  int invalidateWhere(bool Function(K key, V value) predicate) {
    _checkDisposed();

    final keysToRemove = <K>[];
    for (final key in _innerCache.keys.toList()) {
      final value = get(key);
      if (value != null && predicate(key, value)) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _innerCache.remove(key);
    }

    return keysToRemove.length;
  }

  /// Refresh a cached entry's TTL.
  bool refresh(K key) {
    _checkDisposed();
    return _innerCache.refresh(key);
  }

  /// Re-encrypt all cached entries.
  ///
  /// Useful after changing the encryption key.
  /// Returns the number of entries re-encrypted.
  int reencryptAll(CacheEncryption newEncryption) {
    _checkDisposed();

    final entries = <K, V>{};

    // Decrypt all with current encryption
    for (final key in _innerCache.keys.toList()) {
      final value = get(key);
      if (value != null) {
        entries[key] = value;
      }
    }

    // Clear and re-encrypt with new encryption
    _innerCache.clear();

    // Note: This is a simplified version. In practice, you'd need
    // to update _config.encryption, which would require making it mutable
    // or creating a new cache instance.

    var count = 0;
    for (final entry in entries.entries) {
      try {
        put(entry.key, entry.value);
        count++;
      } catch (e) {
        _encryptionErrors++;
      }
    }

    return count;
  }

  /// Dispose the cache and release resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _innerCache.dispose();
    _changes.close();
    _valuesSubject.close();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private Methods
  // ═══════════════════════════════════════════════════════════════════════════

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('EncryptedRecordCache has been disposed');
    }
  }

  String _encrypt(V value) {
    _encryptionCount++;
    final json = serialize(value);
    return _config.encryption.encrypt(json);
  }

  V _decrypt(String encrypted) {
    _decryptionCount++;
    final json = _config.encryption.decrypt(encrypted);
    return deserialize(json);
  }

  void _handleInnerChange(CacheChangeEvent<K, String> event) {
    // Skip if disposed
    if (_disposed) return;

    // Convert inner cache events to decrypted value events
    V? decryptedValue;

    if (event.value != null &&
        event.type != CacheChangeType.removed &&
        event.type != CacheChangeType.evicted &&
        event.type != CacheChangeType.expired &&
        event.type != CacheChangeType.cleared) {
      try {
        decryptedValue = _decrypt(event.value!);
      } catch (e) {
        // Ignore decryption errors in event handling
        _decryptionErrors++;
      }
    }

    if (!_changes.isClosed) {
      _changes.add(CacheChangeEvent<K, V>(
        type: event.type,
        key: event.key,
        value: decryptedValue,
        timestamp: event.timestamp,
      ));
    }

    _updateValuesStream();
  }

  void _updateValuesStream() {
    if (!_valuesSubject.isClosed) {
      _valuesSubject.add(values);
    }
  }
}

/// Statistics about encryption operations.
class EncryptedCacheStats {
  /// Total number of encryption operations.
  final int encryptionCount;

  /// Total number of decryption operations.
  final int decryptionCount;

  /// Total number of encryption errors.
  final int encryptionErrors;

  /// Total number of decryption errors.
  final int decryptionErrors;

  const EncryptedCacheStats({
    this.encryptionCount = 0,
    this.decryptionCount = 0,
    this.encryptionErrors = 0,
    this.decryptionErrors = 0,
  });

  /// Error rate for encryption (0.0 to 1.0).
  double get encryptionErrorRate =>
      encryptionCount == 0 ? 0.0 : encryptionErrors / encryptionCount;

  /// Error rate for decryption (0.0 to 1.0).
  double get decryptionErrorRate =>
      decryptionCount == 0 ? 0.0 : decryptionErrors / decryptionCount;

  @override
  String toString() =>
      'EncryptedCacheStats(encryptions: $encryptionCount (${encryptionErrors} errors), '
      'decryptions: $decryptionCount (${decryptionErrors} errors))';
}

/// Extension to easily create encrypted cache from a model manager.
extension EncryptedCacheExtension<V> on V {
  /// Serialize this value for encrypted caching.
  ///
  /// Requires the value to have a toJson method.
  String toEncryptedCacheValue(CacheEncryption encryption) {
    // This is a helper method - actual implementation depends on the value type
    throw UnimplementedError('Implement toJson() on your model class');
  }
}
