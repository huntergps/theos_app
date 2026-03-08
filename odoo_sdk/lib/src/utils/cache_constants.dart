/// Cache-related constants.
///
/// Centralizes magic numbers used in cache configuration for easy
/// configuration and maintenance.
library;

/// Constants for cache operations.
abstract class CacheConstants {
  // ═══════════════════════════════════════════════════════════════════════════
  // Default Configuration
  // ═══════════════════════════════════════════════════════════════════════════

  /// Default maximum cache size (number of entries).
  static const int defaultMaxSize = 1000;

  /// Default time-to-live for cache entries.
  static const Duration defaultTtl = Duration(minutes: 5);

  /// Default cleanup interval for expired entries.
  static const Duration defaultCleanupInterval = Duration(minutes: 1);

  // ═══════════════════════════════════════════════════════════════════════════
  // Large Dataset Configuration
  // ═══════════════════════════════════════════════════════════════════════════

  /// Maximum cache size for large datasets.
  static const int largeDatasetMaxSize = 5000;

  /// TTL for large dataset caches.
  static const Duration largeDatasetTtl = Duration(minutes: 10);

  // ═══════════════════════════════════════════════════════════════════════════
  // Small/Frequent Configuration
  // ═══════════════════════════════════════════════════════════════════════════

  /// Maximum cache size for small, frequently accessed data.
  static const int smallFrequentMaxSize = 100;

  /// TTL for small, frequently accessed data.
  static const Duration smallFrequentTtl = Duration(minutes: 1);

  // ═══════════════════════════════════════════════════════════════════════════
  // No-Expiry Configuration
  // ═══════════════════════════════════════════════════════════════════════════

  /// TTL for caches that should not expire (effectively permanent).
  static const Duration noExpiryTtl = Duration(days: 365);

  // ═══════════════════════════════════════════════════════════════════════════
  // Preheat Configuration
  // ═══════════════════════════════════════════════════════════════════════════

  /// Default limit for cache preheat operations.
  static const int defaultPreheatLimit = 100;
}
