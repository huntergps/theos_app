/// Interface for cache implementations.
///
/// Provides a generic caching contract for testability and
/// dependency injection of different cache strategies.
library;

/// Interface for a key-value cache.
///
/// Implementations include:
/// - [RecordCache] - LRU cache with TTL support
/// - Mock implementations for testing
abstract class ICache<K, V> {
  /// Get a value from the cache.
  ///
  /// Returns null if the key is not present or has expired.
  V? get(K key);

  /// Store a value in the cache.
  ///
  /// If the cache is at capacity, the least recently used item is evicted.
  void put(K key, V value);

  /// Remove a value from the cache.
  void remove(K key);

  /// Clear all values from the cache.
  void clear();

  /// Check if a key exists in the cache (and hasn't expired).
  bool containsKey(K key);

  /// Current number of items in the cache.
  int get size;

  /// Maximum capacity of the cache.
  int get maxSize;

  /// Get all values currently in the cache.
  ///
  /// Note: This returns a snapshot; the cache may change after this call.
  Iterable<V> get values;

  /// Get all keys currently in the cache.
  ///
  /// Note: This returns a snapshot; the cache may change after this call.
  Iterable<K> get keys;

  /// Stream of cache changes.
  ///
  /// Emits the current cache state as a map whenever items are added,
  /// removed, or the cache is cleared.
  Stream<Map<K, V>> get valuesStream;
}

/// Interface for a cache with time-to-live (TTL) support.
abstract class ITtlCache<K, V> extends ICache<K, V> {
  /// Time-to-live for cache entries.
  Duration get ttl;

  /// Force expire a specific key.
  void expire(K key);

  /// Check if a specific key has expired.
  bool isExpired(K key);

  /// Clean up expired entries.
  ///
  /// Returns the number of entries removed.
  int cleanup();
}

/// Interface for cache statistics.
abstract class ICacheStats {
  /// Total number of cache hits.
  int get hits;

  /// Total number of cache misses.
  int get misses;

  /// Hit rate (hits / total requests).
  double get hitRate;

  /// Number of evictions due to capacity.
  int get evictions;

  /// Reset statistics counters.
  void resetStats();
}
