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

/// Durable state of an offline operation.
enum OfflineOperationStatus {
  pending('pending'),
  processing('processing'),
  recoveryPending('recovery_pending'),
  completed('completed'),
  conflict('conflict'),
  deadLetter('dead_letter');

  const OfflineOperationStatus(this.storageValue);

  final String storageValue;

  static OfflineOperationStatus fromStorage(String? value) {
    return OfflineOperationStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => OfflineOperationStatus.pending,
    );
  }
}

/// Retry policy used after a request may have reached the server.
///
/// [retrySafe] must only be used when the handler can reconcile the operation
/// with a durable server-side marker before creating anything again. Unknown
/// or synthetic commands default to [manualAfterAmbiguous] so a timeout cannot
/// silently duplicate a financial document.
enum OfflineReplayPolicy {
  retrySafe('retry_safe'),
  manualAfterAmbiguous('manual_after_ambiguous');

  const OfflineReplayPolicy(this.storageValue);

  final String storageValue;

  static OfflineReplayPolicy fromStorage(String? value) {
    return OfflineReplayPolicy.values.firstWhere(
      (policy) => policy.storageValue == value,
      orElse: () => OfflineReplayPolicy.manualAfterAmbiguous,
    );
  }
}

/// Versioned local commands understood by the offline dispatcher.
///
/// These names are queue commands, not Odoo method names. Keeping them typed
/// prevents producers and handlers from silently drifting apart.
enum OfflineLocalCommand {
  sessionCreateAndOpen('session_create_and_open', version: 1),
  sessionOpen('session_open', version: 1),
  sessionClosingControl('session_closing_control', version: 1),
  sessionClose('session_close', version: 1),
  paymentCreate('payment_create', version: 1),
  paymentWizardApply('payment_wizard_apply', version: 1),
  partnerCreate('partner_create', version: 1),
  orderConfirm('order_confirm', version: 1),
  invoiceCreateWithPayments('invoice_create_with_payments', version: 1),
  invoiceCollectExisting('invoice_collect_existing', version: 1);

  const OfflineLocalCommand(this.storageName, {required this.version});

  final String storageName;
  final int version;

  static OfflineLocalCommand? tryParse(String value) {
    for (final command in values) {
      if (command.storageName == value) return command;
    }
    return null;
  }
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

  /// Stable local key used to collapse duplicate enqueue attempts.
  final String? operationKey;

  /// Version of the local command payload contract.
  final int commandVersion;

  /// Current durable queue state.
  final OfflineOperationStatus status;

  /// Whether a failed/ambiguous dispatch can be reconciled and retried safely.
  final OfflineReplayPolicy replayPolicy;

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
    this.operationKey,
    this.commandVersion = 1,
    this.status = OfflineOperationStatus.pending,
    this.replayPolicy = OfflineReplayPolicy.manualAfterAmbiguous,
  });

  /// Check if this operation is ready for retry
  bool get isReadyForRetry {
    if (status == OfflineOperationStatus.processing ||
        status == OfflineOperationStatus.completed ||
        status == OfflineOperationStatus.deadLetter ||
        status == OfflineOperationStatus.conflict ||
        hasExceededMaxRetries) {
      return false;
    }
    if (nextRetryAt == null) return true;
    return !DateTime.now().toUtc().isBefore(nextRetryAt!.toUtc());
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
    'operation_key': operationKey,
    'command_version': commandVersion,
    'status': status.storageValue,
    'replay_policy': replayPolicy.storageValue,
  };

  OfflineOperation copyWith({
    int? id,
    String? model,
    String? method,
    int? recordId,
    Map<String, dynamic>? values,
    DateTime? createdAt,
    DateTime? baseWriteDate,
    int? parentOrderId,
    int? priority,
    String? deviceId,
    int? retryCount,
    DateTime? lastRetryAt,
    DateTime? nextRetryAt,
    String? lastError,
    String? operationKey,
    int? commandVersion,
    OfflineOperationStatus? status,
    OfflineReplayPolicy? replayPolicy,
    bool clearLastRetryAt = false,
    bool clearNextRetryAt = false,
    bool clearLastError = false,
  }) {
    return OfflineOperation(
      id: id ?? this.id,
      model: model ?? this.model,
      method: method ?? this.method,
      recordId: recordId ?? this.recordId,
      values: values ?? this.values,
      createdAt: createdAt ?? this.createdAt,
      baseWriteDate: baseWriteDate ?? this.baseWriteDate,
      parentOrderId: parentOrderId ?? this.parentOrderId,
      priority: priority ?? this.priority,
      deviceId: deviceId ?? this.deviceId,
      retryCount: retryCount ?? this.retryCount,
      lastRetryAt: clearLastRetryAt ? null : lastRetryAt ?? this.lastRetryAt,
      nextRetryAt: clearNextRetryAt ? null : nextRetryAt ?? this.nextRetryAt,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      operationKey: operationKey ?? this.operationKey,
      commandVersion: commandVersion ?? this.commandVersion,
      status: status ?? this.status,
      replayPolicy: replayPolicy ?? this.replayPolicy,
    );
  }
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
    String? operationKey,
    int commandVersion = 1,
    OfflineReplayPolicy? replayPolicy,
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

  /// Mark an operation as 'processing' to prevent double-execution.
  ///
  /// Call this BEFORE dispatching the operation to the handler. The startup
  /// recovery in database.dart resets any 'processing' rows back to 'pending'
  /// on app start, so orphaned rows self-heal after a crash or force-quit.
  ///
  /// IMPORTANTE: para que esta marca realmente prevenga doble-ejecución, los
  /// métodos de lectura (getPendingOperations, getOperationsForModel, etc.)
  /// DEBEN excluir las filas en estado 'processing'. Ver implementación en
  /// theos_pos_core/lib/src/database/datasources/offline_queue_datasource.dart.
  Future<void> markOperationProcessing(int id);

  /// Revierte una operación de 'processing' de vuelta a 'pending' SIN tocar
  /// retryCount/nextRetryAt/lastError.
  ///
  /// Se usa cuando una operación termina en un estado que la mantiene en la
  /// cola pero que NO debe contar como un intento fallido (conflicto sin
  /// remover, skip sin remover). A diferencia de [markOperationFailed], esto
  /// no programa backoff ni incrementa el contador de reintentos — la
  /// operación vuelve a estar disponible de inmediato para
  /// [getPendingOperations] en el siguiente ciclo.
  Future<void> markOperationPending(int id);

  /// Retains a successful/terminal operation as immutable audit evidence.
  Future<void> markOperationCompleted(int id);

  /// Holds an operation outside the automatic queue until a user resolves it.
  Future<void> markOperationConflict(int id);

  /// Moves an operation to dead letter without deleting its payload/audit trail.
  Future<void> markOperationDeadLetter(int id, String errorMessage);

  /// Replaces the payload while preserving identity/retry metadata.
  ///
  /// Used by queue compaction to merge consecutive writes without losing
  /// fields from earlier patches.
  Future<void> replaceOperationValues(int id, Map<String, dynamic> values);
}

/// Typed convenience API for local composite commands.
extension OfflineQueueCommandStore on OfflineQueueStore {
  Future<int> queueCommand({
    required String model,
    required OfflineLocalCommand command,
    int? recordId,
    required Map<String, dynamic> values,
    DateTime? baseWriteDate,
    int? parentOrderId,
    int priority = OfflinePriority.normal,
    String? deviceId,
    String? operationKey,
    OfflineReplayPolicy? replayPolicy,
  }) {
    return queueOperation(
      model: model,
      method: command.storageName,
      recordId: recordId,
      values: values,
      baseWriteDate: baseWriteDate,
      parentOrderId: parentOrderId,
      priority: priority,
      deviceId: deviceId,
      operationKey: operationKey,
      commandVersion: command.version,
      replayPolicy: replayPolicy,
    );
  }
}
