/// Offline Queue Types (Generic)
///
/// Shared models and interfaces for offline operation queues.
library;

/// Priority levels for offline operations
/// Lower number = higher priority (processed first)
class OfflinePriority {
  /// Critical: Sessions (opening/closing cash, session state)
  static const int critical = 0;

  /// High: Payments, partner creation
  static const int high = 1;

  /// Normal: Order updates, line changes (default)
  static const int normal = 2;

  /// Low: Non-urgent updates
  static const int low = 3;
}

/// Retry backoff configuration
class RetryBackoff {
  /// Maximum number of retry attempts before giving up
  static const int maxRetries = 10;

  /// Calculate next retry delay based on retry count (exponential backoff)
  /// Returns Duration for next retry
  static Duration getNextRetryDelay(int retryCount) {
    if (retryCount <= 0) return Duration.zero; // Immediate
    if (retryCount == 1) return const Duration(seconds: 30);
    if (retryCount == 2) return const Duration(minutes: 2);
    if (retryCount == 3) return const Duration(minutes: 10);
    if (retryCount == 4) return const Duration(minutes: 30);
    // After 5 retries, cap at 1 hour
    return const Duration(hours: 1);
  }

  /// Check if operation should be retried based on retry count
  static bool shouldRetry(int retryCount) => retryCount < maxRetries;
}

/// Represents an offline operation pending sync
class OfflineOperation {
  final int id;
  final String model;
  final String method;
  final int? recordId;
  final Map<String, dynamic> values;
  final DateTime createdAt;

  /// write_date del registro al momento de encolar (para deteccion de conflictos)
  final DateTime? baseWriteDate;

  /// ID de la orden padre (para sale.order.line -> sale.order)
  final int? parentOrderId;

  /// Priority level for processing order (0=critical, 1=high, 2=normal, 3=low)
  final int priority;

  /// Device ID that created this operation (for multi-device tracking)
  final String? deviceId;

  /// Number of retry attempts
  final int retryCount;

  /// Last retry attempt timestamp
  final DateTime? lastRetryAt;

  /// Next scheduled retry timestamp
  final DateTime? nextRetryAt;

  /// Last error message
  final String? lastError;

  const OfflineOperation({
    required this.id,
    required this.model,
    required this.method,
    this.recordId,
    required this.values,
    required this.createdAt,
    this.baseWriteDate,
    this.parentOrderId,
    this.priority = OfflinePriority.normal,
    this.deviceId,
    this.retryCount = 0,
    this.lastRetryAt,
    this.nextRetryAt,
    this.lastError,
  });

  /// Check if this operation is ready for retry
  bool get isReadyForRetry {
    if (nextRetryAt == null) return true;
    return DateTime.now().isAfter(nextRetryAt!);
  }

  /// Check if this operation has exceeded max retries
  bool get hasExceededMaxRetries => !RetryBackoff.shouldRetry(retryCount);

  Map<String, dynamic> toMap() => {
        'id': id,
        'model': model,
        'method': method,
        'record_id': recordId,
        'values': values,
        'created_at': createdAt,
        'base_write_date': baseWriteDate,
        'parent_order_id': parentOrderId,
        'priority': priority,
        'device_id': deviceId,
        'retry_count': retryCount,
        'last_retry_at': lastRetryAt,
        'next_retry_at': nextRetryAt,
        'last_error': lastError,
      };
}

/// Interface for offline queue data sources.
abstract class OfflineQueueStore {
  Future<int> queueOperation({
    required String model,
    required String method,
    int? recordId,
    required Map<String, dynamic> values,
    DateTime? baseWriteDate,
    int? parentOrderId,
    int priority,
    String? deviceId,
  });

  Future<List<OfflineOperation>> getPendingOperations({
    bool includeNotReady = false,
  });

  Future<int> getPendingCount();

  Future<List<OfflineOperation>> getOperationsForModel(String model);

  Future<OfflineOperation?> getOperationById(int id);

  Future<void> removeOperation(int id);

  Future<void> markOperationFailed(int id, String errorMessage);

  Future<void> resetOperationRetry(int id);

  Future<List<OfflineOperation>> getDeadLetterOperations();

  Future<Map<String, dynamic>> getRetryStats();

  /// Remove operations created before the given date.
  Future<int> removeOperationsBefore(DateTime date);

  /// Remove all dead letter operations.
  Future<int> removeDeadLetterOperations();

  /// Get operations for a specific model and record.
  Future<List<OfflineOperation>> getOperationsForRecord(
    String model,
    int recordId,
  );
}
