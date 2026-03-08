import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:odoo_sdk/odoo_sdk.dart' as core;

import '../database.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show logger;

export 'package:odoo_sdk/odoo_sdk.dart'
    show OfflinePriority, RetryBackoff, OfflineOperation, OfflineQueueStore;

typedef OfflineOperation = core.OfflineOperation;

/// DataSource for offline operation queue
///
/// Handles queuing operations when offline and retrieving
/// them for sync when connection is restored.
class OfflineQueueDataSource implements core.OfflineQueueStore {
  final AppDatabase _db;

  OfflineQueueDataSource(this._db);

  /// Queue an operation for offline sync
  ///
  /// [baseWriteDate] - write_date del registro al momento de encolar
  /// [parentOrderId] - ID de la orden padre (para líneas)
  /// [priority] - Priority level (0=critical, 1=high, 2=normal, 3=low)
  /// [deviceId] - Device ID that created this operation (for multi-device tracking)
  @override
  Future<int> queueOperation({
    required String model,
    required String method,
    int? recordId,
    required Map<String, dynamic> values,
    DateTime? baseWriteDate,
    int? parentOrderId,
    int priority = core.OfflinePriority.normal,
    String? deviceId,
  }) async {
    final now = DateTime.now().toUtc();
    final valuesJson = jsonEncode(values);

    final id = await _db.into(_db.offlineQueue).insert(
          OfflineQueueCompanion.insert(
            model: model,
            values: valuesJson,
            createdAt: now,
            operation: drift.Value(method),
            method: drift.Value(method),
            recordId: drift.Value(recordId),
            baseWriteDate: drift.Value(baseWriteDate),
            parentOrderId: drift.Value(parentOrderId),
            priority: drift.Value(priority),
            deviceId: drift.Value(deviceId),
          ),
        );

    logger.d(
      '[OfflineQueue]',
      '📥 Queued $method $model (id=$id, recordId=$recordId, priority=$priority)',
    );
    return id;
  }

  /// Get all pending operations ordered by priority (asc), then createdAt (asc)
  /// Priority 0 (critical) is processed first, then 1 (high), etc.
  /// Only returns operations that are ready for retry (nextRetryAt <= now or null)
  @override
  Future<List<OfflineOperation>> getPendingOperations({
    bool includeNotReady = false,
  }) async {
    final now = DateTime.now().toUtc();
    final query = _db.select(_db.offlineQueue);

    if (!includeNotReady) {
      // Only return operations ready for retry
      query.where(
        (tbl) =>
            tbl.nextRetryAt.isNull() | tbl.nextRetryAt.isSmallerOrEqualValue(now),
      );
    }

    query.orderBy([
      (tbl) => drift.OrderingTerm.asc(tbl.priority),
      (tbl) => drift.OrderingTerm.asc(tbl.createdAt),
    ]);

    final results = await query.get();
    return results.map((r) => _operationFromRow(r)).toList();
  }

  /// Convert database row to OfflineOperation
  OfflineOperation _operationFromRow(OfflineQueueData r) {
    final valuesStr = r.values;

    return OfflineOperation(
      id: r.id,
      model: r.model,
      method: r.method ?? r.operation,
      recordId: r.recordId,
      values: jsonDecode(valuesStr) as Map<String, dynamic>,
      createdAt: r.createdAt,
      baseWriteDate: r.baseWriteDate,
      parentOrderId: r.parentOrderId,
      priority: r.priority,
      deviceId: r.deviceId,
      retryCount: r.retryCount,
      lastRetryAt: r.lastRetryAt,
      nextRetryAt: r.nextRetryAt,
      lastError: r.lastError,
    );
  }

  /// Get pending operations as raw maps (for backwards compatibility)
  Future<List<Map<String, dynamic>>> getPendingOperationMaps() async {
    final ops = await getPendingOperations();
    return ops.map((op) => op.toMap()).toList();
  }

  /// Get pending operation count
  @override
  Future<int> getPendingCount() async {
    final now = DateTime.now().toUtc();
    final count = await (_db.select(_db.offlineQueue)
          ..where(
            (tbl) =>
                tbl.nextRetryAt.isNull() | tbl.nextRetryAt.isSmallerOrEqualValue(now),
          ))
        .get();
    return count.length;
  }

  /// Get pending operations for a specific model
  @override
  Future<List<OfflineOperation>> getOperationsForModel(String model) async {
    final now = DateTime.now().toUtc();
    final results =
        await (_db.select(_db.offlineQueue)
              ..where((tbl) => tbl.model.equals(model) &
                  (tbl.nextRetryAt.isNull() | tbl.nextRetryAt.isSmallerOrEqualValue(now)))
              ..orderBy([
                (tbl) => drift.OrderingTerm.asc(tbl.priority),
                (tbl) => drift.OrderingTerm.asc(tbl.createdAt),
              ]))
            .get();

    return results.map((r) => _operationFromRow(r)).toList();
  }

  /// Get a single operation by ID
  @override
  Future<OfflineOperation?> getOperationById(int id) async {
    final result = await (_db.select(_db.offlineQueue)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();

    return result != null ? _operationFromRow(result) : null;
  }

  /// Update operation after a failed retry attempt
  /// Calculates next retry time using exponential backoff
  @override
  Future<void> markOperationFailed(int id, String errorMessage) async {
    final op = await (_db.select(_db.offlineQueue)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();

    if (op == null) return;

    final newRetryCount = op.retryCount + 1;
    final now = DateTime.now().toUtc();
    final nextDelay = core.RetryBackoff.getNextRetryDelay(newRetryCount);
    final nextRetry = now.add(nextDelay);

    await (_db.update(_db.offlineQueue)
          ..where((tbl) => tbl.id.equals(id)))
        .write(OfflineQueueCompanion(
      retryCount: drift.Value(newRetryCount),
      lastRetryAt: drift.Value(now),
      nextRetryAt: drift.Value(nextRetry),
      lastError: drift.Value(errorMessage),
    ));
  }

  /// Reset retry count for an operation (e.g., after manual intervention)
  @override
  Future<void> resetOperationRetry(int id) async {
    await (_db.update(_db.offlineQueue)
          ..where((tbl) => tbl.id.equals(id)))
        .write(const OfflineQueueCompanion(
      retryCount: drift.Value(0),
      lastRetryAt: drift.Value(null),
      nextRetryAt: drift.Value(null),
      lastError: drift.Value(null),
    ));
  }

  /// Get operations that have exceeded max retries (dead letter queue)
  @override
  Future<List<OfflineOperation>> getDeadLetterOperations() async {
    final results = await (_db.select(_db.offlineQueue)
          ..where((tbl) =>
              tbl.retryCount.isBiggerOrEqualValue(core.RetryBackoff.maxRetries))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.lastRetryAt)]))
        .get();

    return results.map((r) => _operationFromRow(r)).toList();
  }

  /// Get count of operations waiting for retry (scheduled for future)
  Future<int> getScheduledRetryCount() async {
    final now = DateTime.now().toUtc();
    final results = await (_db.select(_db.offlineQueue)
          ..where((tbl) => tbl.nextRetryAt.isBiggerThanValue(now)))
        .get();
    return results.length;
  }

  /// Get retry statistics
  @override
  Future<Map<String, dynamic>> getRetryStats() async {
    final all = await getPendingOperations(includeNotReady: true);
    final ready = all.where((op) => op.isReadyForRetry).length;
    final scheduled = all.where((op) => !op.isReadyForRetry && !op.hasExceededMaxRetries).length;
    final deadLetter = all.where((op) => op.hasExceededMaxRetries).length;

    final avgRetries = all.isNotEmpty
        ? all.map((op) => op.retryCount).reduce((a, b) => a + b) / all.length
        : 0.0;

    return {
      'total': all.length,
      'ready': ready,
      'scheduled': scheduled,
      'dead_letter': deadLetter,
      'avg_retries': avgRetries,
    };
  }

  /// Remove an operation after successful sync
  @override
  Future<void> removeOperation(int id) async {
    await (_db.delete(
      _db.offlineQueue,
    )..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Remove multiple operations
  Future<void> removeOperations(List<int> ids) async {
    await (_db.delete(_db.offlineQueue)..where((tbl) => tbl.id.isIn(ids))).go();
  }

  /// Clear all pending operations (use with caution)
  Future<void> clearAll() async {
    await _db.delete(_db.offlineQueue).go();
  }

  /// Remove all operations related to a specific UUID
  /// Used when deleting an offline-created record before sync
  Future<int> removeOperationsForUuid(String? uuid) async {
    if (uuid == null || uuid.isEmpty) return 0;

    // Get all operations that contain this UUID in their values
    final operations = await getPendingOperations();
    var removedCount = 0;

    for (final op in operations) {
      if (op.values['uuid'] == uuid) {
        await removeOperation(op.id);
        removedCount++;
      }
    }

    return removedCount;
  }

  /// Get pending operations for a specific sale order (order + its lines)
  ///
  /// Returns operations in FIFO order where:
  /// - model='sale.order' AND record_id=orderId
  /// - model='sale.order.line' AND (parentOrderId=orderId OR values contains order_id=orderId)
  Future<List<OfflineOperation>> getOperationsForSaleOrder(int orderId) async {
    // Include ALL operations (even those waiting for retry) so user can see pending sync status
    final allOps = await getPendingOperations(includeNotReady: true);

    final result = allOps.where((op) {
      // Direct sale.order operations
      if (op.model == 'sale.order' && op.recordId == orderId) {
        return true;
      }

      // Any operation with parentOrderId matching
      if (op.parentOrderId == orderId) {
        return true;
      }

      // Check for sale_id in values (for payment wizards, withhold lines, etc.)
      final saleIdInValues = op.values['sale_id'];
      if (saleIdInValues == orderId) {
        return true;
      }

      // Check for order_id in values (legacy compatibility)
      final orderIdInValues = op.values['order_id'];
      if (orderIdInValues == orderId) {
        return true;
      }

      return false;
    }).toList();

    return result;
  }

  /// Remove all pending operations for a specific model and record ID
  Future<int> removeOperationsForRecord(String model, int recordId) async {
    final operations =
        await (_db.select(_db.offlineQueue)
              ..where(
                (tbl) =>
                    tbl.model.equals(model) & tbl.recordId.equals(recordId),
              ))
            .get();

    for (final op in operations) {
      await removeOperation(op.id);
    }

    return operations.length;
  }

  /// Update order_id in pending line operations when order gets synced
  ///
  /// When a sale.order is synced and gets a new Odoo ID, we need to update
  /// the order_id in all pending sale.order.line operations that reference
  /// the old local ID.
  Future<void> updateOrderIdInPendingOperations(
    int oldOrderId,
    int newOrderId,
  ) async {
    // Update parent_order_id column
    await (_db.update(_db.offlineQueue)
          ..where((tbl) => tbl.parentOrderId.equals(oldOrderId)))
        .write(OfflineQueueCompanion(parentOrderId: drift.Value(newOrderId)));

    // Also update order_id inside the JSON values for line operations
    final lineOps = await (_db.select(_db.offlineQueue)
          ..where(
            (tbl) =>
                tbl.model.equals('sale.order.line') &
                tbl.parentOrderId.equals(newOrderId),
          ))
        .get();

    for (final op in lineOps) {
      final currentValues = _parseJsonValues(op.values);
      if (currentValues['order_id'] == oldOrderId) {
        currentValues['order_id'] = newOrderId;
        await (_db.update(_db.offlineQueue)
              ..where((tbl) => tbl.id.equals(op.id)))
            .write(OfflineQueueCompanion(values: drift.Value(jsonEncode(currentValues))));
      }
    }
  }

  /// Parse JSON values from string
  Map<String, dynamic> _parseJsonValues(String jsonStr) {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
    } catch (e) {
      return {};
    }
  }

  /// Remove all pending WRITE operations for a sale.order
  ///
  /// Called after successful create to avoid duplicate field updates.
  /// We already sent all current values in the create, so subsequent
  /// writes for the same fields are redundant.
  Future<int> removePendingWritesForOrder(int orderId) async {

    final writeOps = await (_db.select(_db.offlineQueue)
          ..where(
            (tbl) =>
                tbl.model.equals('sale.order') &
                tbl.method.equals('write') &
                tbl.recordId.equals(orderId),
          ))
        .get();

    for (final op in writeOps) {
      await removeOperation(op.id);
    }

    return writeOps.length;
  }

  /// Update values in a pending CREATE operation for a sale.order
  ///
  /// When updating local order fields, this also updates the queued
  /// create operation values so they're not stale when syncing.
  ///
  /// Returns true if the operation was found and updated.
  Future<bool> updatePendingCreateValues(
    int orderId,
    Map<String, dynamic> newValues,
  ) async {

    // Find the pending create operation for this order
    final createOps = await (_db.select(_db.offlineQueue)
          ..where(
            (tbl) =>
                tbl.model.equals('sale.order') &
                tbl.method.equals('create') &
                tbl.recordId.equals(orderId),
          ))
        .get();

    if (createOps.isEmpty) {
      return false;
    }

    final createOp = createOps.first;
    final currentValues = _parseJsonValues(createOp.values);

    // Merge new values into existing values
    currentValues.addAll(newValues);

    // Update the operation with merged values
    await (_db.update(_db.offlineQueue)
          ..where((tbl) => tbl.id.equals(createOp.id)))
        .write(OfflineQueueCompanion(values: drift.Value(jsonEncode(currentValues))));

    // Also remove any redundant write operations for the same fields
    // since they're now in the create operation
    final writeOps = await (_db.select(_db.offlineQueue)
          ..where(
            (tbl) =>
                tbl.model.equals('sale.order') &
                tbl.method.equals('write') &
                tbl.recordId.equals(orderId),
          ))
        .get();

    for (final writeOp in writeOps) {
      await removeOperation(writeOp.id);
    }

    return true;
  }

  /// Remove operations created before the given date
  @override
  Future<int> removeOperationsBefore(DateTime date) async {
    final count = await (_db.delete(_db.offlineQueue)
          ..where((tbl) => tbl.createdAt.isSmallerThanValue(date)))
        .go();
    return count;
  }

  /// Remove all dead letter operations (exceeded max retries)
  @override
  Future<int> removeDeadLetterOperations() async {
    final count = await (_db.delete(_db.offlineQueue)
          ..where((tbl) =>
              tbl.retryCount.isBiggerOrEqualValue(core.RetryBackoff.maxRetries)))
        .go();
    return count;
  }

  /// Get operations for a specific model and record
  @override
  Future<List<OfflineOperation>> getOperationsForRecord(
    String model,
    int recordId,
  ) async {
    final results = await (_db.select(_db.offlineQueue)
          ..where((tbl) =>
              tbl.model.equals(model) & tbl.recordId.equals(recordId))
          ..orderBy([
            (tbl) => drift.OrderingTerm.asc(tbl.priority),
            (tbl) => drift.OrderingTerm.asc(tbl.createdAt),
          ]))
        .get();

    return results.map((r) => _operationFromRow(r)).toList();
  }
}
