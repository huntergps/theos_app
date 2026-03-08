/// Generic sync types for offline-first applications
///
/// These types are framework-agnostic and can be used across any
/// Flutter/Dart application that needs offline synchronization.
library;

// ============================================================================
// SYNC OPERATION STATUS
// ============================================================================

/// Status of a sync operation
enum SyncOperationStatus {
  /// Operation is pending (not yet started)
  pending,

  /// Operation is currently being processed
  processing,

  /// Operation completed successfully
  success,

  /// Operation was skipped intentionally
  skipped,

  /// Operation failed
  failed,

  /// Operation has conflict with server data
  conflict,
}

// ============================================================================
// SYNC PROGRESS EVENT
// ============================================================================

/// Progress update for a single sync operation
///
/// Used to track and report progress during queue processing.
class SyncProgressEvent {
  /// ID of the operation being processed
  final int operationId;

  /// Current operation number (1-based)
  final int current;

  /// Total operations to process
  final int total;

  /// Current status of the operation
  final SyncOperationStatus status;

  /// Error message if status is failed
  final String? error;

  const SyncProgressEvent({
    required this.operationId,
    required this.current,
    required this.total,
    required this.status,
    this.error,
  });

  /// Progress percentage (0.0 to 1.0)
  double get progress => total > 0 ? current / total : 0;

  @override
  String toString() =>
      'SyncProgressEvent($current/$total, status: $status${error != null ? ", error: $error" : ""})';
}

// ============================================================================
// QUEUE PROCESS RESULT
// ============================================================================

/// Result of processing queue operations.
///
/// Used specifically for offline queue processing results.
/// For model-level sync results, use [SyncResult] instead.
class QueueProcessResult {
  /// Number of operations successfully synced
  final int synced;

  /// Number of operations that failed
  final int failed;

  /// Number of operations that were skipped (e.g., unlink for non-existent records)
  final int skipped;

  /// Error messages from failed operations
  final List<String> errors;

  /// Operations that have conflicts with server (need user resolution)
  final List<ConflictInfo> conflicts;

  /// Extra data from sync (model-specific, e.g., created invoice ID)
  final Map<String, dynamic> extra;

  const QueueProcessResult({
    required this.synced,
    required this.failed,
    this.skipped = 0,
    this.errors = const [],
    this.conflicts = const [],
    this.extra = const {},
  });

  /// Result indicating no connection was available
  static const noConnection = QueueProcessResult(synced: 0, failed: 0);

  /// Empty result (nothing to sync)
  static const empty = QueueProcessResult(synced: 0, failed: 0);

  /// Whether any errors occurred
  bool get hasErrors => failed > 0;

  /// Whether there are conflicts needing resolution
  bool get hasConflicts => conflicts.isNotEmpty;

  /// Whether the result is empty (nothing happened)
  bool get isEmpty =>
      synced == 0 && failed == 0 && skipped == 0 && conflicts.isEmpty;

  /// Total operations processed
  int get total => synced + failed + skipped;

  /// Create a new result with additional extra data
  QueueProcessResult copyWithExtra(Map<String, dynamic> newExtra) {
    return QueueProcessResult(
      synced: synced,
      failed: failed,
      skipped: skipped,
      errors: errors,
      conflicts: conflicts,
      extra: {...extra, ...newExtra},
    );
  }

  /// Merge with another result
  QueueProcessResult merge(QueueProcessResult other) {
    return QueueProcessResult(
      synced: synced + other.synced,
      failed: failed + other.failed,
      skipped: skipped + other.skipped,
      errors: [...errors, ...other.errors],
      conflicts: [...conflicts, ...other.conflicts],
      extra: {...extra, ...other.extra},
    );
  }

  @override
  String toString() =>
      'QueueProcessResult(synced: $synced, failed: $failed, skipped: $skipped, conflicts: ${conflicts.length}, errors: ${errors.length}${extra.isNotEmpty ? ", extra: $extra" : ""})';
}

// ============================================================================
// SYNC RESULT (Model-level)
// ============================================================================

/// Status of a sync operation.
enum SyncStatus {
  /// Sync completed successfully.
  success,
  /// Sync was cancelled by user.
  cancelled,
  /// Device is offline, sync not possible.
  offline,
  /// Sync already in progress.
  alreadyInProgress,
  /// Sync failed with error.
  error,
  /// Partial success (some records synced, some failed).
  partial,
}

/// Result of a model sync operation.
///
/// Provides comprehensive information about what happened during sync
/// including status, timing, and error details.
class SyncResult {
  /// The model that was synced.
  final String model;

  /// Status of the sync operation.
  final SyncStatus status;

  /// Number of records successfully synced.
  final int synced;

  /// Number of records that failed to sync.
  final int failed;

  /// Error message if status is error.
  final String? error;

  /// Time when sync completed.
  final DateTime timestamp;

  /// Duration of the sync operation.
  final Duration? duration;

  /// Operations that have conflicts with server (need user resolution)
  final List<ConflictInfo> conflicts;

  /// Extra data from sync (model-specific, e.g., created invoice ID)
  final Map<String, dynamic> extra;

  const SyncResult({
    required this.model,
    required this.status,
    this.synced = 0,
    this.failed = 0,
    this.error,
    required this.timestamp,
    this.duration,
    this.conflicts = const [],
    this.extra = const {},
  });

  /// Create a success result.
  factory SyncResult.success({
    required String model,
    required int synced,
    int failed = 0,
  }) {
    return SyncResult(
      model: model,
      status: failed > 0 ? SyncStatus.partial : SyncStatus.success,
      synced: synced,
      failed: failed,
      timestamp: DateTime.now(),
    );
  }

  /// Create a cancelled result.
  factory SyncResult.cancelled({
    required String model,
    int synced = 0,
  }) {
    return SyncResult(
      model: model,
      status: SyncStatus.cancelled,
      synced: synced,
      timestamp: DateTime.now(),
    );
  }

  /// Create an offline result.
  factory SyncResult.offline({required String model}) {
    return SyncResult(
      model: model,
      status: SyncStatus.offline,
      timestamp: DateTime.now(),
    );
  }

  /// Create an already in progress result.
  factory SyncResult.alreadyInProgress({required String model}) {
    return SyncResult(
      model: model,
      status: SyncStatus.alreadyInProgress,
      timestamp: DateTime.now(),
    );
  }

  /// Create an error result.
  factory SyncResult.error({
    required String model,
    required String error,
  }) {
    return SyncResult(
      model: model,
      status: SyncStatus.error,
      error: error,
      timestamp: DateTime.now(),
    );
  }

  /// Result indicating no connection was available.
  static SyncResult get noConnection => SyncResult(
        model: 'queue',
        status: SyncStatus.offline,
        timestamp: DateTime.now(),
      );

  /// Empty result (nothing to sync).
  static SyncResult get empty => SyncResult(
        model: 'queue',
        status: SyncStatus.success,
        synced: 0,
        failed: 0,
        timestamp: DateTime.now(),
      );

  /// Create SyncResult from QueueProcessResult.
  factory SyncResult.fromQueueResult(QueueProcessResult qr, {String model = 'queue'}) {
    SyncStatus status;
    if (qr.failed > 0) {
      status = qr.synced > 0 ? SyncStatus.partial : SyncStatus.error;
    } else {
      status = SyncStatus.success;
    }

    return SyncResult(
      model: model,
      status: status,
      synced: qr.synced,
      failed: qr.failed,
      error: qr.errors.isNotEmpty ? qr.errors.join('; ') : null,
      timestamp: DateTime.now(),
      conflicts: qr.conflicts,
      extra: qr.extra,
    );
  }

  /// Combine two sync results (upload + download).
  factory SyncResult.combined(SyncResult upload, SyncResult download) {
    final combinedSynced = upload.synced + download.synced;
    final combinedFailed = upload.failed + download.failed;

    SyncStatus combinedStatus;
    String? combinedError;

    if (upload.status == SyncStatus.error ||
        download.status == SyncStatus.error) {
      combinedStatus = SyncStatus.error;
      combinedError = [
        if (upload.error != null) 'Upload: ${upload.error}',
        if (download.error != null) 'Download: ${download.error}',
      ].join('; ');
    } else if (upload.status == SyncStatus.cancelled ||
        download.status == SyncStatus.cancelled) {
      combinedStatus = SyncStatus.cancelled;
    } else if (combinedFailed > 0) {
      combinedStatus = SyncStatus.partial;
    } else {
      combinedStatus = SyncStatus.success;
    }

    return SyncResult(
      model: '${upload.model}+${download.model}',
      status: combinedStatus,
      synced: combinedSynced,
      failed: combinedFailed,
      error: combinedError,
      timestamp: DateTime.now(),
    );
  }

  /// Whether the sync was successful (fully or partially).
  bool get isSuccess =>
      status == SyncStatus.success || status == SyncStatus.partial;

  /// Whether the sync had any failures.
  bool get hasFailures => failed > 0 || status == SyncStatus.error;

  /// Alias for hasFailures for API consistency with QueueProcessResult.
  bool get hasErrors => hasFailures;

  /// List of error messages (wraps single error for API consistency).
  List<String> get errors => error != null ? [error!] : const [];

  /// Whether the result is empty (nothing synced or failed).
  bool get isEmpty => synced == 0 && failed == 0 && conflicts.isEmpty;

  /// Whether there are conflicts needing resolution.
  bool get hasConflicts => conflicts.isNotEmpty;

  /// Merge with another result.
  SyncResult merge(SyncResult other) {
    final combinedSynced = synced + other.synced;
    final combinedFailed = failed + other.failed;

    SyncStatus combinedStatus;
    String? combinedError;

    if (status == SyncStatus.error || other.status == SyncStatus.error) {
      combinedStatus = SyncStatus.error;
      combinedError = [
        if (error != null) error,
        if (other.error != null) other.error,
      ].join('; ');
    } else if (status == SyncStatus.cancelled ||
        other.status == SyncStatus.cancelled) {
      combinedStatus = SyncStatus.cancelled;
    } else if (combinedFailed > 0) {
      combinedStatus = SyncStatus.partial;
    } else {
      combinedStatus = SyncStatus.success;
    }

    return SyncResult(
      model: '$model+${other.model}',
      status: combinedStatus,
      synced: combinedSynced,
      failed: combinedFailed,
      error: combinedError,
      timestamp: DateTime.now(),
      conflicts: [...conflicts, ...other.conflicts],
      extra: {...extra, ...other.extra},
    );
  }

  /// Create a new result with additional extra data.
  SyncResult copyWithExtra(Map<String, dynamic> newExtra) {
    return SyncResult(
      model: model,
      status: status,
      synced: synced,
      failed: failed,
      error: error,
      timestamp: timestamp,
      duration: duration,
      conflicts: conflicts,
      extra: {...extra, ...newExtra},
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('SyncResult($model: $status');
    if (synced > 0) buffer.write(', synced: $synced');
    if (failed > 0) buffer.write(', failed: $failed');
    if (error != null) buffer.write(', error: $error');
    buffer.write(')');
    return buffer.toString();
  }
}

/// Aggregated sync results for multiple models.
class SyncReport {
  final List<SyncResult> results;
  final DateTime startTime;
  final DateTime endTime;

  SyncReport({
    required this.results,
    required this.startTime,
    required this.endTime,
  });

  /// Total records synced across all models.
  int get totalSynced => results.fold(0, (sum, r) => sum + r.synced);

  /// Total failures across all models.
  int get totalFailed => results.fold(0, (sum, r) => sum + r.failed);

  /// Duration of the entire sync operation.
  Duration get duration => endTime.difference(startTime);

  /// Whether all models synced successfully.
  bool get allSuccess => results.every((r) => r.isSuccess);

  /// Whether any model had errors.
  bool get hasErrors => results.any((r) => r.status == SyncStatus.error);

  /// Get results for a specific model.
  SyncResult? forModel(String model) {
    return results.where((r) => r.model == model).firstOrNull;
  }

  @override
  String toString() {
    return 'SyncReport(models: ${results.length}, synced: $totalSynced, '
        'failed: $totalFailed, duration: ${duration.inSeconds}s)';
  }
}

// ============================================================================
// CONFLICT INFO
// ============================================================================

/// Information about a sync conflict between local and server data
///
/// Used when local changes conflict with server changes (based on write_date).
class ConflictInfo {
  /// ID of the queue operation that caused the conflict
  final int operationId;

  /// Odoo model name (e.g., 'sale.order')
  final String model;

  /// Record ID (null for create operations)
  final int? recordId;

  /// When the local change was made
  final DateTime localWriteDate;

  /// When the server record was last modified
  final DateTime serverWriteDate;

  /// Local values that were attempted to sync
  final Map<String, dynamic> localValues;

  /// Server values at time of conflict detection (optional)
  final Map<String, dynamic>? serverValues;

  const ConflictInfo({
    required this.operationId,
    required this.model,
    this.recordId,
    required this.localWriteDate,
    required this.serverWriteDate,
    required this.localValues,
    this.serverValues,
  });

  /// Time difference between local and server changes
  Duration get timeDifference => serverWriteDate.difference(localWriteDate);

  @override
  String toString() =>
      'ConflictInfo($model[$recordId]: local=${localWriteDate.toIso8601String()}, server=${serverWriteDate.toIso8601String()})';
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

/// Exception thrown when an operation is intentionally skipped (not an error)
///
/// Examples:
/// - Unlink for a record that doesn't exist on server
/// - Update for a deleted record
class OperationSkippedException implements Exception {
  /// Reason the operation was skipped
  final String reason;

  const OperationSkippedException(this.reason);

  @override
  String toString() => 'OperationSkipped: $reason';
}

/// Exception thrown when a sync conflict is detected
class SyncConflictException implements Exception {
  final ConflictInfo conflict;

  const SyncConflictException(this.conflict);

  @override
  String toString() =>
      'SyncConflict: ${conflict.model}[${conflict.recordId}] - local: ${conflict.localWriteDate}, server: ${conflict.serverWriteDate}';
}

// ============================================================================
// FIELD-LEVEL SYNC TYPES
// ============================================================================

/// Result of applying a single field change
enum SyncFieldResult {
  /// Field was updated successfully
  updated,

  /// Field was skipped (no change needed)
  skipped,

  /// Field update failed
  failed,
}

/// Change to a single field
class FieldChange {
  final String fieldName;
  final dynamic oldValue;
  final dynamic newValue;

  const FieldChange({
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
  });

  bool get hasChanged => oldValue != newValue;

  @override
  String toString() => 'FieldChange($fieldName: $oldValue -> $newValue)';
}

// ============================================================================
// SYNC STRATEGY INTERFACE
// ============================================================================

/// Strategy for resolving sync conflicts
enum ConflictResolutionStrategy {
  /// Keep local changes, overwrite server
  keepLocal,

  /// Accept server changes, discard local
  keepServer,

  /// Merge changes field by field (where possible)
  merge,

  /// Skip this operation, keep in queue for later
  skip,
}

/// Interface for model-specific sync handlers
///
/// Implement this to handle sync operations for a specific Odoo model.
abstract class SyncModelHandler<T> {
  /// Odoo model name (e.g., 'sale.order')
  String get modelName;

  /// Process a create operation
  Future<int> handleCreate(Map<String, dynamic> values);

  /// Process an update operation
  Future<void> handleUpdate(int recordId, Map<String, dynamic> values);

  /// Process a delete operation
  Future<void> handleDelete(int recordId);

  /// Check for conflicts before sync
  Future<ConflictInfo?> checkConflict(
    int recordId,
    DateTime localWriteDate,
    Map<String, dynamic> localValues,
  );
}
