/// Advanced Record Cache with TTL (Time To Live) and reactive streams.
///
/// This cache is optimized for Odoo model records and provides:
/// - Time-to-live (TTL) expiration for entries
/// - Reactive streams for cache change notifications
/// - Statistics and metrics tracking
/// - Automatic cleanup of expired entries
///
/// ## Features
/// - O(1) get/put operations with LRU eviction
/// - Automatic expiration based on configurable TTL
/// - [RecordCache.changes] stream for reactive UI updates
/// - [RecordCache.valuesStream] for observing all cached values
/// - [RecordCacheStats] for monitoring cache performance
///
/// ## When to use this vs LRUCache:
/// - Use [RecordCache] for Odoo model records that need TTL and change streams
/// - Use [LRUCache] from `package:odoo_offline_core` for simple caching without expiration
///
/// ## Example
/// ```dart
/// final cache = RecordCache<int, Product>(
///   config: RecordCacheConfig(maxSize: 500, ttl: Duration(minutes: 10)),
/// );
///
/// cache.put(1, product);
/// final product = cache.get(1); // null if expired
///
/// cache.changes.listen((event) => print('Cache ${event.type}'));
/// ```
library;

import 'dart:async';
import 'dart:collection';

import 'cache_constants.dart';
import 'value_stream.dart';

/// Configuration for the LRU cache.
class RecordCacheConfig {
  /// Maximum number of entries in the cache.
  /// When exceeded, least recently used entries are evicted.
  final int maxSize;

  /// Time-to-live for cache entries.
  /// Entries older than this are considered expired.
  final Duration ttl;

  /// Whether to automatically clean expired entries periodically.
  final bool autoCleanup;

  /// Interval for automatic cleanup (if enabled).
  final Duration cleanupInterval;

  const RecordCacheConfig({
    this.maxSize = CacheConstants.defaultMaxSize,
    this.ttl = CacheConstants.defaultTtl,
    this.autoCleanup = true,
    this.cleanupInterval = CacheConstants.defaultCleanupInterval,
  });

  /// Default configuration: 1000 entries, 5 min TTL, auto cleanup every minute.
  static const RecordCacheConfig defaultConfig = RecordCacheConfig();

  /// Configuration for large datasets: 5000 entries, 10 min TTL.
  static const RecordCacheConfig largeDataset = RecordCacheConfig(
    maxSize: CacheConstants.largeDatasetMaxSize,
    ttl: CacheConstants.largeDatasetTtl,
  );

  /// Configuration for small, frequently accessed data: 100 entries, 1 min TTL.
  static const RecordCacheConfig smallFrequent = RecordCacheConfig(
    maxSize: CacheConstants.smallFrequentMaxSize,
    ttl: CacheConstants.smallFrequentTtl,
  );

  /// Configuration with no TTL (entries don't expire, only evicted by LRU).
  static const RecordCacheConfig noExpiry = RecordCacheConfig(
    ttl: CacheConstants.noExpiryTtl,
    autoCleanup: false,
  );

  RecordCacheConfig copyWith({
    int? maxSize,
    Duration? ttl,
    bool? autoCleanup,
    Duration? cleanupInterval,
  }) {
    return RecordCacheConfig(
      maxSize: maxSize ?? this.maxSize,
      ttl: ttl ?? this.ttl,
      autoCleanup: autoCleanup ?? this.autoCleanup,
      cleanupInterval: cleanupInterval ?? this.cleanupInterval,
    );
  }
}

/// A cache entry with value and metadata.
class CacheEntry<T> {
  /// The cached value.
  final T value;

  /// When this entry was created.
  final DateTime createdAt;

  /// When this entry was last accessed.
  DateTime lastAccessedAt;

  CacheEntry({
    required this.value,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastAccessedAt = createdAt ?? DateTime.now();

  /// Check if entry has expired based on TTL.
  bool isExpired(Duration ttl) {
    return DateTime.now().difference(createdAt) > ttl;
  }

  /// Update last accessed time.
  void touch() {
    lastAccessedAt = DateTime.now();
  }
}

/// Statistics about cache performance.
class RecordCacheStats {
  /// Total number of cache hits.
  final int hits;

  /// Total number of cache misses.
  final int misses;

  /// Total number of evictions due to capacity.
  final int evictions;

  /// Total number of expirations due to TTL.
  final int expirations;

  /// Current number of entries in cache.
  final int size;

  /// Maximum capacity of cache.
  final int maxSize;

  const RecordCacheStats({
    this.hits = 0,
    this.misses = 0,
    this.evictions = 0,
    this.expirations = 0,
    this.size = 0,
    this.maxSize = 0,
  });

  /// Cache hit ratio (0.0 to 1.0).
  double get hitRatio {
    final total = hits + misses;
    return total == 0 ? 0.0 : hits / total;
  }

  /// Percentage of cache capacity used.
  double get usageRatio => maxSize == 0 ? 0.0 : size / maxSize;

  RecordCacheStats copyWith({
    int? hits,
    int? misses,
    int? evictions,
    int? expirations,
    int? size,
    int? maxSize,
  }) {
    return RecordCacheStats(
      hits: hits ?? this.hits,
      misses: misses ?? this.misses,
      evictions: evictions ?? this.evictions,
      expirations: expirations ?? this.expirations,
      size: size ?? this.size,
      maxSize: maxSize ?? this.maxSize,
    );
  }

  @override
  String toString() =>
      'RecordCacheStats(hits: $hits, misses: $misses, hitRatio: ${(hitRatio * 100).toStringAsFixed(1)}%, '
      'size: $size/$maxSize, evictions: $evictions, expirations: $expirations)';
}

/// Event emitted when cache changes.
enum CacheChangeType {
  /// Entry was added.
  added,

  /// Entry was updated.
  updated,

  /// Entry was removed.
  removed,

  /// Entry expired.
  expired,

  /// Entry was evicted (LRU).
  evicted,

  /// Cache was cleared.
  cleared,
}

/// Event emitted when cache changes.
class CacheChangeEvent<K, V> {
  /// Type of change.
  final CacheChangeType type;

  /// Key that changed (null for clear).
  final K? key;

  /// Value (null for remove/clear).
  final V? value;

  /// When the change occurred.
  final DateTime timestamp;

  const CacheChangeEvent({
    required this.type,
    this.key,
    this.value,
    required this.timestamp,
  });

  @override
  String toString() => 'CacheChangeEvent($type, key: $key)';
}

/// LRU Cache with TTL support.
///
/// Provides efficient caching with:
/// - O(1) get and put operations
/// - Automatic eviction of least recently used entries
/// - Automatic expiration based on TTL
/// - Reactive streams for cache changes
/// - Statistics tracking
///
/// Example:
/// ```dart
/// final cache = RecordCache<int, Product>(
///   config: RecordCacheConfig(maxSize: 500, ttl: Duration(minutes: 10)),
/// );
///
/// // Add entries
/// cache.put(1, product1);
/// cache.put(2, product2);
///
/// // Get entries (returns null if expired or not found)
/// final product = cache.get(1);
///
/// // Listen to changes
/// cache.changes.listen((event) {
///   print('Cache ${event.type}: ${event.key}');
/// });
///
/// // Get all cached entries
/// final allProducts = cache.values;
///
/// // Clear when done
/// cache.dispose();
/// ```
class RecordCache<K, V> {
  final RecordCacheConfig _config;

  /// Internal storage using LinkedHashMap for LRU ordering.
  /// LinkedHashMap maintains insertion order, we use access order by
  /// removing and re-inserting on access.
  final LinkedHashMap<K, CacheEntry<V>> _cache = LinkedHashMap();

  /// Stream controller for cache changes.
  final _changes = StreamController<CacheChangeEvent<K, V>>.broadcast();

  /// Stream of all cached values (reactive).
  final _valuesSubject = ValueStream<Map<K, V>>({});

  /// Statistics.
  RecordCacheStats _stats;

  /// Timer for periodic cleanup.
  Timer? _cleanupTimer;

  /// Whether the cache has been disposed.
  bool _disposed = false;

  RecordCache({RecordCacheConfig config = RecordCacheConfig.defaultConfig})
      : _config = config,
        _stats = RecordCacheStats(maxSize: config.maxSize) {
    if (_config.autoCleanup) {
      _startCleanupTimer();
    }
  }

  /// Cache configuration.
  RecordCacheConfig get config => _config;

  /// Current cache statistics.
  RecordCacheStats get stats => _stats.copyWith(size: _cache.length);

  /// Stream of cache change events.
  Stream<CacheChangeEvent<K, V>> get changes => _changes.stream;

  /// Stream of all cached values (reactive, updates on any change).
  Stream<Map<K, V>> get valuesStream => _valuesSubject.stream;

  /// Current cached values (snapshot).
  Map<K, V> get values {
    _removeExpired();
    return Map.fromEntries(
      _cache.entries.map((e) => MapEntry(e.key, e.value.value)),
    );
  }

  /// Current number of entries in cache.
  int get length => _cache.length;

  /// Whether the cache is empty.
  bool get isEmpty => _cache.isEmpty;

  /// Whether the cache is not empty.
  bool get isNotEmpty => _cache.isNotEmpty;

  /// All keys in the cache.
  Iterable<K> get keys => _cache.keys;

  /// Get a value from the cache.
  ///
  /// Returns null if not found or expired.
  /// Updates last accessed time on hit.
  V? get(K key) {
    _checkDisposed();

    final entry = _cache[key];
    if (entry == null) {
      _stats = _stats.copyWith(misses: _stats.misses + 1);
      return null;
    }

    // Check expiration
    if (entry.isExpired(_config.ttl)) {
      _remove(key, CacheChangeType.expired);
      _stats = _stats.copyWith(
        misses: _stats.misses + 1,
        expirations: _stats.expirations + 1,
      );
      return null;
    }

    // Move to end (most recently used) by removing and re-inserting
    _cache.remove(key);
    entry.touch();
    _cache[key] = entry;

    _stats = _stats.copyWith(hits: _stats.hits + 1);
    return entry.value;
  }

  /// Check if a key exists and is not expired.
  bool containsKey(K key) {
    _checkDisposed();

    final entry = _cache[key];
    if (entry == null) return false;

    if (entry.isExpired(_config.ttl)) {
      _remove(key, CacheChangeType.expired);
      return false;
    }

    return true;
  }

  /// Put a value in the cache.
  ///
  /// Evicts least recently used entries if capacity is exceeded.
  void put(K key, V value) {
    _checkDisposed();

    final existing = _cache[key];
    final isUpdate = existing != null;

    // Remove existing to update position
    if (isUpdate) {
      _cache.remove(key);
    }

    // Evict if at capacity
    while (_cache.length >= _config.maxSize) {
      _evictLRU();
    }

    // Add new entry
    _cache[key] = CacheEntry(value: value);

    // Emit change event
    _emitChange(
      isUpdate ? CacheChangeType.updated : CacheChangeType.added,
      key,
      value,
    );
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
  /// Returns the removed value or null if not found.
  V? remove(K key) {
    _checkDisposed();
    return _remove(key, CacheChangeType.removed);
  }

  /// Remove multiple values from the cache.
  void removeAll(Iterable<K> keys) {
    _checkDisposed();
    for (final key in keys) {
      _remove(key, CacheChangeType.removed);
    }
  }

  /// Clear all entries from the cache.
  void clear() {
    _checkDisposed();

    _cache.clear();
    _emitChange(CacheChangeType.cleared, null, null);
  }

  /// Remove expired entries.
  ///
  /// Returns number of entries removed.
  int removeExpired() {
    _checkDisposed();
    return _removeExpired();
  }

  /// Get or compute a value.
  ///
  /// If the key exists and is not expired, returns the cached value.
  /// Otherwise, computes the value using [compute], caches it, and returns it.
  Future<V> getOrCompute(K key, Future<V> Function() compute) async {
    _checkDisposed();

    final cached = get(key);
    if (cached != null) {
      return cached;
    }

    final value = await compute();
    put(key, value);
    return value;
  }

  /// Get or compute a value synchronously.
  V getOrComputeSync(K key, V Function() compute) {
    _checkDisposed();

    final cached = get(key);
    if (cached != null) {
      return cached;
    }

    final value = compute();
    put(key, value);
    return value;
  }

  /// Invalidate entries matching a predicate.
  ///
  /// Returns number of entries invalidated.
  int invalidateWhere(bool Function(K key, V value) predicate) {
    _checkDisposed();

    final keysToRemove = <K>[];
    for (final entry in _cache.entries) {
      if (predicate(entry.key, entry.value.value)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _remove(key, CacheChangeType.removed);
    }

    return keysToRemove.length;
  }

  /// Refresh a cached entry by updating its creation time.
  ///
  /// This extends the TTL without recomputing the value.
  bool refresh(K key) {
    _checkDisposed();

    final entry = _cache[key];
    if (entry == null) return false;

    // Remove and re-insert with new timestamp
    _cache.remove(key);
    _cache[key] = CacheEntry(value: entry.value);
    return true;
  }

  /// Dispose the cache and release resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    _cache.clear();
    _changes.close();
    _valuesSubject.close();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private Methods
  // ═══════════════════════════════════════════════════════════════════════════

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('Cache has been disposed');
    }
  }

  V? _remove(K key, CacheChangeType type) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _emitChange(type, key, entry.value);
      return entry.value;
    }
    return null;
  }

  void _evictLRU() {
    if (_cache.isEmpty) return;

    // First entry is least recently used
    final lruKey = _cache.keys.first;
    final entry = _cache.remove(lruKey);

    if (entry != null) {
      _stats = _stats.copyWith(evictions: _stats.evictions + 1);
      _emitChange(CacheChangeType.evicted, lruKey, entry.value);
    }
  }

  int _removeExpired() {
    final keysToRemove = <K>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired(_config.ttl)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
      _stats = _stats.copyWith(expirations: _stats.expirations + 1);
    }

    if (keysToRemove.isNotEmpty) {
      _updateValuesStream();
    }

    return keysToRemove.length;
  }

  void _emitChange(CacheChangeType type, K? key, V? value) {
    _changes.add(CacheChangeEvent(
      type: type,
      key: key,
      value: value,
      timestamp: DateTime.now(),
    ));

    _updateValuesStream();
  }

  void _updateValuesStream() {
    if (!_valuesSubject.isClosed) {
      _valuesSubject.add(values);
    }
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(_config.cleanupInterval, (_) {
      if (!_disposed) {
        _removeExpired();
      }
    });
  }
}
