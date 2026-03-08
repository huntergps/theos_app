/// Basic LRU Cache implementation for general-purpose caching.
///
/// This file provides simple, lightweight cache implementations:
/// - [LRUCache] - Generic key-value cache with size limit
/// - [BinaryLRUCache] - Specialized cache for binary data (images, files)
///
/// For record-specific caching with TTL (time-to-live) and reactive streams,
/// use [RecordCache] from `package:odoo_model_manager/odoo_model_manager.dart` instead.
///
/// ## When to use this vs RecordCache:
/// - Use [LRUCache]/[BinaryLRUCache] for simple caching without expiration
/// - Use [RecordCache] for Odoo model records that need TTL and change streams
library;

import 'dart:collection';
import 'dart:typed_data';

/// Generic LRU (Least Recently Used) cache implementation
///
/// Automatically evicts the least recently used items when the cache
/// exceeds its maximum size.
///
/// Usage:
/// ```dart
/// final cache = LRUCache<String, MyObject>(maxSize: 100);
/// cache.put('key', myObject);
/// final value = cache.get('key');
/// ```
class LRUCache<K, V> {
  /// Maximum number of items to store
  final int maxSize;

  /// Internal linked hash map (maintains insertion order)
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  /// Optional callback when an item is evicted
  final void Function(K key, V value)? onEvict;

  LRUCache({
    required this.maxSize,
    this.onEvict,
  }) : assert(maxSize > 0, 'maxSize must be positive');

  /// Number of items currently in cache
  int get size => _cache.length;

  /// Whether the cache is empty
  bool get isEmpty => _cache.isEmpty;

  /// Whether the cache is full
  bool get isFull => _cache.length >= maxSize;

  /// Get a value from the cache
  ///
  /// Returns null if not found. Updates access order if found.
  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      // Re-insert to move to end (most recently used)
      _cache[key] = value;
    }
    return value;
  }

  /// Check if key exists in cache
  bool containsKey(K key) => _cache.containsKey(key);

  /// Put a value in the cache
  ///
  /// If key exists, updates the value and moves to most recently used.
  /// If cache is full, evicts the least recently used item.
  void put(K key, V value) {
    // Remove existing to update order
    _cache.remove(key);

    // Evict if necessary
    while (_cache.length >= maxSize) {
      _evictOldest();
    }

    // Insert at end (most recently used)
    _cache[key] = value;
  }

  /// Remove a specific key from cache
  V? remove(K key) {
    return _cache.remove(key);
  }

  /// Clear all items from cache
  void clear() {
    if (onEvict != null) {
      for (final entry in _cache.entries) {
        onEvict!(entry.key, entry.value);
      }
    }
    _cache.clear();
  }

  /// Get all keys in cache (oldest to newest)
  Iterable<K> get keys => _cache.keys;

  /// Get all values in cache (oldest to newest)
  Iterable<V> get values => _cache.values;

  /// Evict the oldest (least recently used) item
  void _evictOldest() {
    if (_cache.isEmpty) return;
    final oldestKey = _cache.keys.first;
    final oldestValue = _cache.remove(oldestKey);
    if (onEvict != null && oldestValue != null) {
      onEvict!(oldestKey, oldestValue);
    }
  }

  /// Get or compute a value
  ///
  /// If key exists, returns cached value.
  /// If not, computes value using [ifAbsent], caches it, and returns it.
  Future<V> getOrCompute(K key, Future<V> Function() ifAbsent) async {
    final cached = get(key);
    if (cached != null) return cached;

    final computed = await ifAbsent();
    put(key, computed);
    return computed;
  }

  /// Synchronous version of getOrCompute
  V getOrComputeSync(K key, V Function() ifAbsent) {
    final cached = get(key);
    if (cached != null) return cached;

    final computed = ifAbsent();
    put(key, computed);
    return computed;
  }
}

/// Specialized LRU cache for binary data (Uint8List) like images
///
/// Tracks memory usage in addition to item count.
/// Evicts based on both count and memory limits.
class BinaryLRUCache {
  /// Maximum number of items to cache
  final int maxCount;

  /// Maximum memory usage in bytes (default: 50MB)
  final int maxMemoryBytes;

  /// Internal cache
  final LRUCache<String, _CachedBinary> _cache;

  /// Current memory usage
  int _currentMemoryBytes = 0;

  BinaryLRUCache({
    this.maxCount = 100,
    this.maxMemoryBytes = 50 * 1024 * 1024, // 50MB default
  }) : _cache = LRUCache<String, _CachedBinary>(
          maxSize: maxCount,
          onEvict: null,
        );

  /// Number of items currently cached
  int get count => _cache.size;

  /// Current memory usage in bytes
  int get memoryUsage => _currentMemoryBytes;

  /// Memory usage as percentage of max
  double get memoryUsagePercent => _currentMemoryBytes / maxMemoryBytes * 100;

  /// Get binary data from cache
  Uint8List? get(String key) {
    final cached = _cache.get(key);
    return cached?.data;
  }

  /// Put binary data in the cache
  void put(String key, Uint8List data) {
    final dataSize = data.lengthInBytes;

    // Remove existing entry if present
    final existing = _cache.remove(key);
    if (existing != null) {
      _currentMemoryBytes -= existing.sizeBytes;
    }

    // Evict until we have room for the new data
    while (_currentMemoryBytes + dataSize > maxMemoryBytes && !_cache.isEmpty) {
      _evictOldest();
    }

    // Don't cache if single item exceeds memory limit
    if (dataSize > maxMemoryBytes) {
      return;
    }

    // Cache the data
    _cache.put(key, _CachedBinary(data: data, sizeBytes: dataSize));
    _currentMemoryBytes += dataSize;
  }

  /// Remove data from cache
  void remove(String key) {
    final removed = _cache.remove(key);
    if (removed != null) {
      _currentMemoryBytes -= removed.sizeBytes;
    }
  }

  /// Clear all cached data
  void clear() {
    _cache.clear();
    _currentMemoryBytes = 0;
  }

  /// Check if key is cached
  bool containsKey(String key) => _cache.containsKey(key);

  /// Evict the oldest item
  void _evictOldest() {
    if (_cache.isEmpty) return;
    final oldestKey = _cache.keys.first;
    final removed = _cache.remove(oldestKey);
    if (removed != null) {
      _currentMemoryBytes -= removed.sizeBytes;
    }
  }

  /// Get cache statistics
  Map<String, dynamic> get stats => {
        'count': count,
        'maxCount': maxCount,
        'memoryUsageMB': (_currentMemoryBytes / (1024 * 1024)).toStringAsFixed(2),
        'maxMemoryMB': (maxMemoryBytes / (1024 * 1024)).toStringAsFixed(2),
        'memoryUsagePercent': memoryUsagePercent.toStringAsFixed(1),
      };
}

/// Internal class to track cached binary data with size
class _CachedBinary {
  final Uint8List data;
  final int sizeBytes;

  const _CachedBinary({required this.data, required this.sizeBytes});
}
