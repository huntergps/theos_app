// Part of odoo_model_manager library
// ignore_for_file: library_private_types_in_public_api
part of 'odoo_model_manager.dart';

/// Cache management mixin for OdooModelManager.
///
/// Provides LRU cache with TTL for records, including:
/// - [getFromCache] / [invalidateCache] / [clearCache] for cache manipulation
/// - [cacheStats] for monitoring cache performance
/// - [cachedRecords] stream for reactive UI bindings
mixin _ManagerCacheMixin<T> on _OdooModelManagerBase<T> {
  // LRU cache with TTL for records
  // Initialized lazily with configuration from ModelManagerConfig
  RecordCache<int, T>? _recordCache;

  /// Get or create the record cache with current configuration.
  RecordCache<int, T> get _cache {
    _recordCache ??= RecordCache<int, T>(config: _config.cacheConfig);
    return _recordCache!;
  }

  /// Stream that emits the current cached records.
  ///
  /// Useful for reactive UIs that need to display a list of records.
  /// The cache uses LRU eviction and TTL expiration to manage memory.
  ///
  /// Configure cache behavior via [ModelManagerConfig.cacheConfig]:
  /// ```dart
  /// manager.initialize(
  ///   client: client,
  ///   db: db,
  ///   queue: queue,
  ///   config: ModelManagerConfig(
  ///     cacheConfig: RecordCacheConfig(
  ///       maxSize: 500,
  ///       ttl: Duration(minutes: 10),
  ///     ),
  ///   ),
  /// );
  /// ```
  Stream<Map<int, T>> get cachedRecords => _cache.valuesStream;

  /// Current cache statistics.
  ///
  /// Use this to monitor cache performance:
  /// ```dart
  /// final stats = manager.cacheStats;
  /// print('Hit ratio: ${stats.hitRatio}');
  /// print('Size: ${stats.size}/${stats.maxSize}');
  /// ```
  RecordCacheStats get cacheStats => _cache.stats;

  /// Get a record from cache without triggering database read.
  ///
  /// Returns null if not in cache or expired.
  T? getFromCache(int id) => _cache.get(id);

  /// Manually invalidate a cache entry.
  void invalidateCache(int id) => _cache.remove(id);

  /// Clear all cached records.
  ///
  /// Use sparingly - records will need to be reloaded from database.
  void clearCache() => _cache.clear();
}
