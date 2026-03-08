/// HTTP Cache Interceptor for Dio
///
/// Provides configurable response caching with:
/// - In-memory LRU cache
/// - Per-route TTL configuration
/// - ETag/Last-Modified support
/// - Manual cache invalidation
library;

import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Configuration for a cacheable route pattern.
class CacheRule {
  /// Pattern to match against request path (supports wildcards: * and **).
  ///
  /// Examples:
  /// - `/res.partner/search_read` - exact match
  /// - `/res.partner/*` - matches any method on res.partner
  /// - `/**/search_read` - matches search_read on any model
  final String pattern;

  /// Time-to-live for cached responses.
  final Duration ttl;

  /// HTTP methods to cache (default: only GET-like operations).
  final Set<String> methods;

  /// Whether to cache responses with errors.
  final bool cacheErrors;

  /// Custom key generator (default: uses URL + method + body hash).
  final String Function(RequestOptions)? keyGenerator;

  const CacheRule({
    required this.pattern,
    this.ttl = const Duration(minutes: 5),
    this.methods = const {'GET', 'POST'},
    this.cacheErrors = false,
    this.keyGenerator,
  });

  /// Check if this rule matches a request path.
  bool matches(String path) {
    final regex = _patternToRegex(pattern);
    return regex.hasMatch(path);
  }

  RegExp _patternToRegex(String pattern) {
    var regexPattern = pattern
        .replaceAll('.', r'\.')
        .replaceAll('**', '{{DOUBLE_STAR}}')
        .replaceAll('*', r'[^/]+')
        .replaceAll('{{DOUBLE_STAR}}', r'.*');
    return RegExp('^$regexPattern\$');
  }

  @override
  String toString() => 'CacheRule($pattern, ttl: ${ttl.inSeconds}s)';
}

/// A cached response entry.
class HttpCacheEntry {
  /// The cached response data.
  final dynamic data;

  /// Response headers.
  final Map<String, List<String>> headers;

  /// HTTP status code.
  final int statusCode;

  /// When this entry was created.
  final DateTime createdAt;

  /// When this entry expires.
  final DateTime expiresAt;

  /// ETag from server (for conditional requests).
  final String? etag;

  /// Last-Modified from server (for conditional requests).
  final String? lastModified;

  const HttpCacheEntry({
    required this.data,
    required this.headers,
    required this.statusCode,
    required this.createdAt,
    required this.expiresAt,
    this.etag,
    this.lastModified,
  });

  /// Check if this entry has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Time remaining until expiration.
  Duration get timeToLive => expiresAt.difference(DateTime.now());

  /// Age of this cache entry.
  Duration get age => DateTime.now().difference(createdAt);
}

/// Statistics about cache performance.
class CacheStats {
  /// Total number of cache hits.
  final int hits;

  /// Total number of cache misses.
  final int misses;

  /// Current number of entries in cache.
  final int entries;

  /// Total size estimate in bytes.
  final int estimatedSizeBytes;

  /// Number of entries evicted due to capacity.
  final int evictions;

  /// Number of entries expired.
  final int expirations;

  const CacheStats({
    required this.hits,
    required this.misses,
    required this.entries,
    required this.estimatedSizeBytes,
    required this.evictions,
    required this.expirations,
  });

  /// Hit rate as a percentage (0-100).
  double get hitRate {
    final total = hits + misses;
    return total > 0 ? (hits / total) * 100 : 0;
  }

  @override
  String toString() =>
      'CacheStats(hits: $hits, misses: $misses, hitRate: ${hitRate.toStringAsFixed(1)}%, '
      'entries: $entries, size: ${(estimatedSizeBytes / 1024).toStringAsFixed(1)}KB)';
}

/// In-memory HTTP response cache with LRU eviction.
///
/// Uses a [LinkedHashMap] for O(1) access-order tracking instead of
/// a separate List, giving O(1) get/put/evict operations.
class ResponseCache {
  /// LinkedHashMap maintains insertion order; we remove-and-reinsert
  /// on access to move entries to the end (most recently used).
  final LinkedHashMap<String, HttpCacheEntry> _cache = LinkedHashMap();
  final int _maxEntries;

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _expirations = 0;
  int _estimatedSize = 0;

  ResponseCache({int maxEntries = 100}) : _maxEntries = maxEntries;

  /// Get a cached entry by key.
  HttpCacheEntry? get(String key) {
    final entry = _cache[key];

    if (entry == null) {
      _misses++;
      return null;
    }

    if (entry.isExpired) {
      _remove(key);
      _expirations++;
      _misses++;
      return null;
    }

    // Move to end of access order (most recently used) — O(1)
    _cache.remove(key);
    _cache[key] = entry;

    _hits++;
    return entry;
  }

  /// Store an entry in the cache.
  void put(String key, HttpCacheEntry entry) {
    // Remove existing entry if present
    if (_cache.containsKey(key)) {
      _remove(key);
    }

    // Evict oldest entries if at capacity
    while (_cache.length >= _maxEntries && _cache.isNotEmpty) {
      final oldest = _cache.keys.first;
      _remove(oldest);
      _evictions++;
    }

    // Add new entry
    _cache[key] = entry;
    _estimatedSize += _estimateEntrySize(entry);
  }

  /// Remove an entry from the cache.
  void _remove(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _estimatedSize -= _estimateEntrySize(entry);
    }
  }

  /// Invalidate a specific cache key.
  void invalidate(String key) {
    _remove(key);
  }

  /// Invalidate all entries matching a pattern.
  void invalidatePattern(String pattern) {
    final regex = RegExp(pattern);
    final keysToRemove = _cache.keys.where((k) => regex.hasMatch(k)).toList();
    for (final key in keysToRemove) {
      _remove(key);
    }
  }

  /// Clear all entries from the cache.
  void clear() {
    _cache.clear();
    _estimatedSize = 0;
  }

  /// Get cache statistics.
  CacheStats get stats => CacheStats(
        hits: _hits,
        misses: _misses,
        entries: _cache.length,
        estimatedSizeBytes: _estimatedSize,
        evictions: _evictions,
        expirations: _expirations,
      );

  /// Reset statistics counters.
  void resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _expirations = 0;
  }

  /// Estimates the memory size of a cache entry in bytes.
  ///
  /// Attempts to JSON encode the entry data and measure its length.
  /// Falls back to a default estimate of 1024 bytes if encoding fails.
  int _estimateEntrySize(HttpCacheEntry entry) {
    // Rough estimate: JSON encode data and measure length
    try {
      final jsonStr = jsonEncode(entry.data);
      return jsonStr.length;
    } catch (_) {
      return 1024; // Default estimate for non-JSON data
    }
  }
}

/// Configuration for the cache interceptor.
class CacheConfig {
  /// Cache rules ordered by specificity (most specific first).
  final List<CacheRule> rules;

  /// Maximum number of entries to keep in memory.
  final int maxEntries;

  /// Whether to use conditional requests (If-None-Match, If-Modified-Since).
  final bool useConditionalRequests;

  /// Default TTL for responses without a matching rule.
  final Duration? defaultTtl;

  /// Callback when cache is hit.
  final void Function(String key, HttpCacheEntry entry)? onCacheHit;

  /// Callback when cache is missed.
  final void Function(String key)? onCacheMiss;

  const CacheConfig({
    this.rules = const [],
    this.maxEntries = 100,
    this.useConditionalRequests = true,
    this.defaultTtl,
    this.onCacheHit,
    this.onCacheMiss,
  });

  /// Preset for caching Odoo search/read operations.
  static const CacheConfig odooDefault = CacheConfig(
    rules: [
      // Cache model metadata for longer
      CacheRule(
        pattern: '/**/fields_get',
        ttl: Duration(hours: 1),
      ),
      // Cache user/company info
      CacheRule(
        pattern: '/res.users/*',
        ttl: Duration(minutes: 15),
      ),
      CacheRule(
        pattern: '/res.company/*',
        ttl: Duration(minutes: 30),
      ),
      // Cache product catalogs
      CacheRule(
        pattern: '/product.product/search_read',
        ttl: Duration(minutes: 10),
      ),
      CacheRule(
        pattern: '/product.template/search_read',
        ttl: Duration(minutes: 10),
      ),
      // Short cache for other search operations
      CacheRule(
        pattern: '/**/search_read',
        ttl: Duration(minutes: 2),
      ),
      CacheRule(
        pattern: '/**/search_count',
        ttl: Duration(minutes: 2),
      ),
    ],
    maxEntries: 200,
  );

  /// Preset for aggressive caching (offline-first).
  static const CacheConfig aggressive = CacheConfig(
    rules: [
      CacheRule(
        pattern: '/**/fields_get',
        ttl: Duration(hours: 24),
      ),
      CacheRule(
        pattern: '/**',
        ttl: Duration(minutes: 30),
      ),
    ],
    maxEntries: 500,
  );

  /// Preset for minimal caching.
  static const CacheConfig minimal = CacheConfig(
    rules: [
      CacheRule(
        pattern: '/**/fields_get',
        ttl: Duration(minutes: 30),
      ),
    ],
    maxEntries: 50,
  );
}

/// Dio interceptor that caches HTTP responses.
///
/// Usage:
/// ```dart
/// final cache = ResponseCache();
/// final dio = Dio();
/// dio.interceptors.add(CacheInterceptor(
///   cache: cache,
///   config: CacheConfig.odooDefault,
/// ));
///
/// // Later: check cache stats
/// print(cache.stats);
///
/// // Invalidate cache for a model
/// cache.invalidatePattern(r'/sale\.order/');
/// ```
class CacheInterceptor extends Interceptor {
  final ResponseCache cache;
  final CacheConfig config;

  CacheInterceptor({
    required this.cache,
    this.config = const CacheConfig(),
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Skip caching if explicitly disabled
    if (options.extra['noCache'] == true) {
      handler.next(options);
      return;
    }

    // Find matching cache rule
    final rule = _findMatchingRule(options);
    if (rule == null) {
      handler.next(options);
      return;
    }

    // Check if method is cacheable
    if (!rule.methods.contains(options.method.toUpperCase())) {
      handler.next(options);
      return;
    }

    // Generate cache key
    final key = _generateCacheKey(options, rule);
    options.extra['cacheKey'] = key;
    options.extra['cacheRule'] = rule;

    // Try to get from cache
    final entry = cache.get(key);
    if (entry != null) {
      config.onCacheHit?.call(key, entry);

      // If using conditional requests and entry has ETag/Last-Modified
      if (config.useConditionalRequests) {
        if (entry.etag != null) {
          options.headers['If-None-Match'] = entry.etag;
        }
        if (entry.lastModified != null) {
          options.headers['If-Modified-Since'] = entry.lastModified;
        }
        // Store entry for potential 304 response
        options.extra['cachedEntry'] = entry;
        handler.next(options);
        return;
      }

      // Return cached response directly
      final response = Response(
        requestOptions: options,
        data: entry.data,
        statusCode: entry.statusCode,
        headers: Headers.fromMap(entry.headers),
      );
      response.extra['fromCache'] = true;
      handler.resolve(response);
      return;
    }

    config.onCacheMiss?.call(key);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    final key = options.extra['cacheKey'] as String?;
    final rule = options.extra['cacheRule'] as CacheRule?;

    // Handle 304 Not Modified
    if (response.statusCode == 304) {
      final cachedEntry = options.extra['cachedEntry'] as HttpCacheEntry?;
      if (cachedEntry != null) {
        final newResponse = Response(
          requestOptions: options,
          data: cachedEntry.data,
          statusCode: 200,
          headers: Headers.fromMap(cachedEntry.headers),
        );
        newResponse.extra['fromCache'] = true;
        newResponse.extra['revalidated'] = true;
        handler.resolve(newResponse);
        return;
      }
    }

    // Skip if no cache key or not a successful response
    if (key == null || rule == null) {
      handler.next(response);
      return;
    }

    // Only cache successful responses (or errors if configured)
    final statusCode = response.statusCode ?? 0;
    final isSuccess = statusCode >= 200 && statusCode < 300;
    if (!isSuccess && !rule.cacheErrors) {
      handler.next(response);
      return;
    }

    // Extract caching headers
    final etag = response.headers.value('etag');
    final lastModified = response.headers.value('last-modified');

    // Create cache entry
    final now = DateTime.now();
    final entry = HttpCacheEntry(
      data: response.data,
      headers: response.headers.map,
      statusCode: statusCode,
      createdAt: now,
      expiresAt: now.add(rule.ttl),
      etag: etag,
      lastModified: lastModified,
    );

    cache.put(key, entry);
    response.extra['cached'] = true;
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // On network errors, try to return stale cache entry
    final options = err.requestOptions;
    final key = options.extra['cacheKey'] as String?;

    if (key != null && _isNetworkError(err)) {
      // Try to get even expired entry
      final entry = cache._cache[key];
      if (entry != null) {
        final response = Response(
          requestOptions: options,
          data: entry.data,
          statusCode: entry.statusCode,
          headers: Headers.fromMap(entry.headers),
        );
        response.extra['fromCache'] = true;
        response.extra['stale'] = true;
        handler.resolve(response);
        return;
      }
    }

    handler.next(err);
  }

  CacheRule? _findMatchingRule(RequestOptions options) {
    // First check config rules
    for (final rule in config.rules) {
      if (rule.matches(options.path)) {
        return rule;
      }
    }

    // Fall back to default TTL if configured
    if (config.defaultTtl != null) {
      return CacheRule(
        pattern: options.path,
        ttl: config.defaultTtl!,
      );
    }

    return null;
  }

  /// Generates a unique cache key for the given request.
  ///
  /// Uses the rule's custom key generator if provided, otherwise
  /// constructs a key from: method + path + body hash.
  String _generateCacheKey(RequestOptions options, CacheRule rule) {
    // Use custom key generator if provided
    if (rule.keyGenerator != null) {
      return rule.keyGenerator!(options);
    }

    // Default: method + path + body hash
    final method = options.method;
    final path = options.path;
    final bodyHash = _hashBody(options.data);
    return '$method:$path:$bodyHash';
  }

  /// Hash body using FNV-1a algorithm.
  ///
  /// FNV-1a is a fast, non-cryptographic hash with good distribution.
  /// Much better collision resistance than simple sum of char codes.
  String _hashBody(dynamic data) {
    if (data == null) return 'null';
    try {
      final jsonStr = jsonEncode(data);
      return _fnv1aHash(jsonStr);
    } catch (_) {
      return data.hashCode.toRadixString(16);
    }
  }

  /// FNV-1a 32-bit hash implementation.
  ///
  /// See: http://www.isthe.com/chongo/tech/comp/fnv/
  String _fnv1aHash(String input) {
    // FNV-1a 32-bit constants
    const int fnvPrime = 0x01000193;
    const int fnvOffsetBasis = 0x811c9dc5;

    var hash = fnvOffsetBasis;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Checks if the exception represents a network-related error.
  ///
  /// Returns true for connection errors and timeout exceptions
  /// that may benefit from serving cached responses.
  bool _isNetworkError(DioException err) {
    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout;
  }
}

/// Extension to easily add caching to Dio.
extension DioCacheExtension on Dio {
  /// Add cache interceptor with default configuration.
  ResponseCache enableCache({CacheConfig config = CacheConfig.odooDefault}) {
    final cache = ResponseCache(maxEntries: config.maxEntries);
    interceptors.add(CacheInterceptor(cache: cache, config: config));
    return cache;
  }

  /// Add cache interceptor with an existing cache.
  void enableCacheWithInstance(
    ResponseCache cache, {
    CacheConfig config = const CacheConfig(),
  }) {
    interceptors.add(CacheInterceptor(cache: cache, config: config));
  }
}
