/// Interface for the Odoo Offline Database
///
/// This abstract class defines the contract that the host application's
/// database must implement to support the Offline Core functionality.
///
/// It allows the package to perform operations like queuing offline actions
/// without knowing the concrete implementation of the database (Drift, Hive, etc).
///
/// ## Implementation Notes
///
/// When implementing this interface, consider:
/// - Using database transactions for atomicity
/// - Implementing proper indexing for efficient queries
/// - Handling concurrent access (multiple isolates)
///
/// ## Minimum Implementation
///
/// For basic functionality, implement:
/// - [queueOfflineOperation]
/// - [getPendingOperations]
/// - [removeOperation]
///
/// ## Extended Implementation
///
/// For full functionality including retry tracking and auditing, also implement:
/// - [logSyncOperation]
/// - [getRetryStats]
/// - [getDeadLetterOperations]
/// - [getOperationsWithRetries]
abstract class IOdooDatabase {
  // ═══════════════════════════════════════════════════════════════════════════
  // CORE QUEUE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Queue an operation for offline synchronization.
  ///
  /// [model] The Odoo model name (e.g., 'sale.order')
  /// [method] The method to call (e.g., 'write', 'create', 'unlink')
  /// [recordId] The record ID (0 or negative for create operations)
  /// [values] The values to send to Odoo
  ///
  /// Returns the queue operation ID.
  Future<int> queueOfflineOperation(
    String model,
    String method,
    int recordId,
    Map<String, dynamic> values,
  );

  /// Queues an operation with extended options for advanced use cases.
  ///
  /// This method extends [queueOfflineOperation] with additional parameters
  /// for priority ordering, parent-child relationships, and conflict detection.
  ///
  /// [model] The Odoo model name (e.g., 'sale.order').
  /// [method] The method to call ('write', 'create', 'unlink').
  /// [recordId] The record ID (null or 0 for create operations).
  /// [values] The values to send to Odoo.
  /// [baseWriteDate] The record's write_date at the time of local modification,
  ///   used for conflict detection during sync.
  /// [parentOrderId] Optional parent order ID for operations that depend on
  ///   a parent record (e.g., order lines depending on orders).
  /// [priority] Operation priority (0=critical, 1=high, 2=normal, 3=low).
  ///   Lower numbers are processed first. Defaults to 2 (normal).
  /// [deviceId] Optional device identifier for multi-device tracking.
  ///
  /// Returns the queue operation ID.
  ///
  /// Example:
  /// ```dart
  /// await db.queueOfflineOperationExtended(
  ///   model: 'sale.order.line',
  ///   method: 'write',
  ///   recordId: 123,
  ///   values: {'qty': 5},
  ///   baseWriteDate: DateTime.now(),
  ///   parentOrderId: 456,
  ///   priority: 1, // High priority
  /// );
  /// ```
  Future<int> queueOfflineOperationExtended({
    required String model,
    required String method,
    int? recordId,
    required Map<String, dynamic> values,
    DateTime? baseWriteDate,
    int? parentOrderId,
    int priority = 2, // Normal priority
    String? deviceId,
  }) async {
    // Default implementation falls back to basic method
    return queueOfflineOperation(model, method, recordId ?? 0, values);
  }

  /// Get pending operations for a specific model.
  ///
  /// [model] If provided, only return operations for this model.
  /// Returns a list of operation maps with keys: id, model, method, record_id, values, etc.
  Future<List<Map<String, dynamic>>> getPendingOperations({String? model});

  /// Gets pending operations that are ready for synchronization.
  ///
  /// Unlike [getPendingOperations], this method respects retry backoff delays
  /// and only returns operations whose next retry time has passed.
  ///
  /// Use this method when processing the queue to avoid hammering the server
  /// with operations that recently failed.
  ///
  /// [model] If provided, only returns operations for this model.
  ///
  /// Returns a list of operation maps ready for immediate sync.
  ///
  /// The default implementation returns all pending operations for backwards
  /// compatibility. Override this to implement proper retry timing.
  Future<List<Map<String, dynamic>>> getPendingOperationsReady({
    String? model,
  }) async {
    // Default implementation returns all pending (for backwards compatibility)
    return getPendingOperations(model: model);
  }

  /// Removes an operation from the queue after successful sync.
  ///
  /// [operationId] The ID of the operation to remove.
  Future<void> removeOperation(int operationId);

  /// Removes multiple operations from the queue atomically.
  ///
  /// This is more efficient than calling [removeOperation] multiple times
  /// when you have several operations to remove.
  ///
  /// [operationIds] List of operation IDs to remove.
  ///
  /// The default implementation calls [removeOperation] for each ID.
  /// Override this to implement batch deletion for better performance.
  Future<void> removeOperations(List<int> operationIds) async {
    for (final id in operationIds) {
      await removeOperation(id);
    }
  }

  /// Gets the count of pending operations in the queue.
  ///
  /// This is more efficient than fetching all operations when you only
  /// need the count (e.g., for displaying a badge).
  ///
  /// [model] If provided, only counts operations for this model.
  ///
  /// Returns the number of pending operations.
  ///
  /// The default implementation fetches all operations and returns the length.
  /// Override this to implement a more efficient COUNT query.
  Future<int> getPendingOperationCount({String? model}) async {
    final ops = await getPendingOperations(model: model);
    return ops.length;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RETRY MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mark an operation as failed and schedule retry.
  ///
  /// Increments retry count and calculates next retry time based on backoff.
  Future<void> markOperationFailed(
    int operationId,
    String errorMessage,
  ) async {
    // Default implementation: do nothing (operation stays in queue)
  }

  /// Reset an operation's retry count and error state.
  ///
  /// Use this when manually triggering a retry.
  Future<void> resetOperationRetry(int operationId) async {
    // Default implementation: no-op
  }

  /// Get operations that have exceeded max retries (dead letter queue).
  ///
  /// These operations need manual intervention.
  Future<List<Map<String, dynamic>>> getDeadLetterOperations() async {
    return [];
  }

  /// Moves an operation to dead letter status.
  ///
  /// Dead letter operations are those that have exceeded the maximum retry
  /// count and require manual intervention. They are excluded from normal
  /// queue processing.
  ///
  /// Use [getDeadLetterOperations] to retrieve these for manual review.
  ///
  /// [operationId] The ID of the operation to move to dead letter.
  ///
  /// Example:
  /// ```dart
  /// // After max retries exceeded
  /// if (operation.retryCount >= maxRetries) {
  ///   await db.moveToDeadLetter(operation.id);
  ///   notifyAdmin('Operation ${operation.id} needs attention');
  /// }
  /// ```
  Future<void> moveToDeadLetter(int operationId) async {
    // Default implementation: no-op
  }

  /// Gets operations that have been retried at least once.
  ///
  /// Useful for monitoring and debugging sync issues. Operations with
  /// retries indicate potential problems that may need investigation.
  ///
  /// Returns a list of operation maps where retry_count > 0.
  ///
  /// Example:
  /// ```dart
  /// final problematic = await db.getOperationsWithRetries();
  /// for (final op in problematic) {
  ///   print('${op['model']}.${op['method']} failed ${op['retry_count']} times');
  /// }
  /// ```
  Future<List<Map<String, dynamic>>> getOperationsWithRetries() async {
    return [];
  }

  /// Get retry statistics for operations.
  ///
  /// Returns a map with keys:
  /// - totalOperations: Total pending operations
  /// - withRetries: Operations that have been retried
  /// - deadLetter: Operations that exceeded max retries
  /// - averageRetries: Average retry count
  /// - byModel: Map of model -> count
  Future<Map<String, dynamic>> getRetryStats() async {
    final pending = await getPendingOperations();
    final withRetries = await getOperationsWithRetries();
    final deadLetter = await getDeadLetterOperations();

    final byModel = <String, int>{};
    for (final op in pending) {
      final model = op['model'] as String? ?? 'unknown';
      byModel[model] = (byModel[model] ?? 0) + 1;
    }

    return {
      'totalOperations': pending.length,
      'withRetries': withRetries.length,
      'deadLetter': deadLetter.length,
      'averageRetries': _calculateAverageRetries(pending),
      'byModel': byModel,
    };
  }

  double _calculateAverageRetries(List<Map<String, dynamic>> operations) {
    if (operations.isEmpty) return 0;
    final total = operations.fold<int>(
      0,
      (sum, op) => sum + (op['retry_count'] as int? ?? 0),
    );
    return total / operations.length;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUDIT LOGGING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Log a sync operation result for auditing.
  ///
  /// [result] Should be one of: 'success', 'conflict', 'error', 'skipped'
  Future<void> logSyncOperation({
    required String model,
    required String method,
    required int? odooId,
    required int? localId,
    required String result,
    String? errorMessage,
    String? recordUuid,
    DateTime? createdOfflineAt,
  });

  /// Get sync audit logs with optional filters.
  ///
  /// [model] Filter by model
  /// [result] Filter by result type
  /// [since] Only logs after this time
  /// [limit] Maximum number of logs to return
  Future<List<Map<String, dynamic>>> getSyncAuditLogs({
    String? model,
    String? result,
    DateTime? since,
    int? limit,
  }) async {
    return [];
  }

  /// Get sync statistics from audit logs.
  ///
  /// Returns aggregated stats like success rate, common errors, etc.
  Future<Map<String, dynamic>> getSyncStats({
    DateTime? since,
    String? model,
  }) async {
    return {
      'totalOperations': 0,
      'successful': 0,
      'failed': 0,
      'conflicts': 0,
      'successRate': 0.0,
    };
  }

  /// Clear old audit logs.
  ///
  /// [olderThan] Delete logs older than this date
  Future<int> clearOldAuditLogs(DateTime olderThan) async {
    return 0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFLICT MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Store a conflict for later resolution.
  Future<void> storeConflict({
    required int operationId,
    required String model,
    required int recordId,
    required Map<String, dynamic> localValues,
    required Map<String, dynamic> serverValues,
    required DateTime localWriteDate,
    required DateTime serverWriteDate,
  }) async {
    // Default implementation: no-op
  }

  /// Get unresolved conflicts.
  Future<List<Map<String, dynamic>>> getUnresolvedConflicts() async {
    return [];
  }

  /// Mark a conflict as resolved.
  Future<void> resolveConflict(
    int conflictId, {
    required String resolution, // 'local', 'server', 'merged', 'skipped'
  }) async {
    // Default implementation: no-op
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BATCH OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Queue multiple operations atomically.
  ///
  /// All operations are queued in a single transaction.
  Future<List<int>> queueBatchOperations(
    List<({
      String model,
      String method,
      int recordId,
      Map<String, dynamic> values,
    })> operations,
  ) async {
    final ids = <int>[];
    for (final op in operations) {
      final id = await queueOfflineOperation(
        op.model,
        op.method,
        op.recordId,
        op.values,
      );
      ids.add(id);
    }
    return ids;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAINTENANCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Clear all pending operations.
  ///
  /// Use with caution - this deletes unsynced data!
  Future<int> clearAllPendingOperations() async {
    final ops = await getPendingOperations();
    for (final op in ops) {
      await removeOperation(op['id'] as int);
    }
    return ops.length;
  }

  /// Compact/vacuum the database.
  Future<void> compact() async {
    // Default implementation: no-op
  }
}
