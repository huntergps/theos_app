/// Sync-related constants.
///
/// Centralizes magic numbers used in sync operations for easy configuration
/// and maintenance.
library;

/// Constants for sync operations.
abstract class SyncConstants {
  // ═══════════════════════════════════════════════════════════════════════════
  // Batch Sizes
  // ═══════════════════════════════════════════════════════════════════════════

  /// Default batch size for sync operations.
  static const int defaultBatchSize = 100;

  /// Batch size for realtime sync (smaller for faster updates).
  static const int realtimeBatchSize = 50;

  /// Batch size for catalog/large dataset sync.
  static const int catalogBatchSize = 200;

  // ═══════════════════════════════════════════════════════════════════════════
  // Progress & Intervals
  // ═══════════════════════════════════════════════════════════════════════════

  /// Default interval for progress callbacks (every N records).
  static const int defaultProgressInterval = 50;

  /// Background sync interval in seconds.
  static const int backgroundIntervalSeconds = 300;

  /// Catalog sync interval in seconds (hourly).
  static const int catalogIntervalSeconds = 3600;

  // ═══════════════════════════════════════════════════════════════════════════
  // Retry Configuration
  // ═══════════════════════════════════════════════════════════════════════════

  /// Maximum number of retry attempts.
  static const int maxRetries = 3;

  /// Base retry delay in milliseconds.
  static const int retryDelayMs = 1000;

  /// Base retry delay for queue operations in milliseconds.
  static const int baseRetryDelayMs = 1000;

  /// Maximum retry delay in milliseconds (1 minute).
  static const int maxRetryDelayMs = 60000;

  // ═══════════════════════════════════════════════════════════════════════════
  // Data Age Limits
  // ═══════════════════════════════════════════════════════════════════════════

  /// Maximum data age in hours before refresh required.
  static const int maxDataAgeHours = 24;

  /// Maximum data age for catalog data in hours.
  static const int catalogMaxDataAgeHours = 48;

  // ═══════════════════════════════════════════════════════════════════════════
  // ID Generation
  // ═══════════════════════════════════════════════════════════════════════════

  /// Modulo for generating temporary local IDs.
  ///
  /// Temporary IDs are negative to distinguish from server IDs.
  /// Formula: `-(DateTime.now().millisecondsSinceEpoch % tempIdModulo)`
  static const int tempIdModulo = 1000000000;

  // ═══════════════════════════════════════════════════════════════════════════
  // WebSocket
  // ═══════════════════════════════════════════════════════════════════════════

  /// WebSocket reconnect delay in milliseconds.
  static const int websocketReconnectDelayMs = 5000;

  /// WebSocket ping timeout in seconds.
  static const int websocketPingTimeoutSeconds = 30;

  // ═══════════════════════════════════════════════════════════════════════════
  // Parallel Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Default number of parallel operations for queue processing.
  static const int defaultParallelOperations = 1;
}
