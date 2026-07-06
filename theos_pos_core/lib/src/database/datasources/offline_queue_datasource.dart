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
  ///
  /// CRÍTICO: siempre excluye filas en status='processing', sin importar
  /// [includeNotReady]. Esas filas ya fueron tomadas por otra llamada a
  /// processQueue() (ver markOperationProcessing) y están en vuelo hacia
  /// Odoo — devolverlas de nuevo aquí permitiría que una segunda llamada
  /// concurrente (ej. tras invalidar offlineSyncServiceProvider mientras la
  /// primera sigue en curso) reenvíe el mismo create/write dos veces →
  /// registros duplicados en Odoo. Este filtro es lo que hace que
  /// markOperationProcessing() realmente sirva de algo.
  @override
  Future<List<OfflineOperation>> getPendingOperations({
    bool includeNotReady = false,
  }) async {
    final now = DateTime.now().toUtc();
    final query = _db.select(_db.offlineQueue)
      ..where((tbl) => tbl.status.equals('pending') | tbl.status.isNull());

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
  ///
  /// Excluye filas 'processing' (ver nota en [getPendingOperations]).
  @override
  Future<List<OfflineOperation>> getOperationsForModel(String model) async {
    final now = DateTime.now().toUtc();
    final results =
        await (_db.select(_db.offlineQueue)
              ..where((tbl) => tbl.model.equals(model) &
                  (tbl.status.equals('pending') | tbl.status.isNull()) &
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
  ///
  /// También revierte status a 'pending': la operación llegó aquí después de
  /// haber sido marcada 'processing' (ver [markOperationProcessing]) por
  /// OfflineQueueProcessor. Si no se revirtiera, quedaría escondida para
  /// siempre de [getPendingOperations] y nunca se reintentaría, aunque
  /// nextRetryAt indique que ya está lista.
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
      status: const drift.Value('pending'),
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
  ///
  /// OJO: este método NO es solo para mostrar estado en la UI — también es
  /// la fuente de despacho de [OfflineSyncService._processSaleOrderQueueInternal]
  /// (el "sync ahora" de una orden puntual, que corre en paralelo al
  /// processQueue() genérico). Por eso hereda el filtro de status='pending'
  /// de [getPendingOperations] (incluye no-listas-para-retry pero excluye
  /// 'processing') — sin esto, ambos caminos de despacho podrían tomar la
  /// misma operación al mismo tiempo y enviarla dos veces a Odoo.
  Future<List<OfflineOperation>> getOperationsForSaleOrder(int orderId) async {
    // Include ALL operations (even those waiting for retry, but NOT those
    // already 'processing') so user can see pending sync status.
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

  /// Update partner_id in pending queue operations when a partner gets synced
  ///
  /// Mirror de [updateOrderIdInPendingOperations] pero para clientes creados
  /// offline: cuando un `res.partner` con ID negativo local se sincroniza y
  /// obtiene su ID real de Odoo, cualquier operación YA encolada (ej. un
  /// `sale.order create` o `account.payment create`) que todavía tenga el ID
  /// negativo en su payload JSON debe reescribirse — de lo contrario, al
  /// procesarse, esa operación envía `partner_id` inválido a Odoo y falla
  /// permanentemente (dead-letter).
  ///
  /// Revisa TODAS las filas de la cola (sin importar status/modelo) porque
  /// `partner_id` puede aparecer en distintos métodos (create de orden,
  /// create de pago, etc.). Retorna la cantidad de operaciones actualizadas.
  Future<int> updatePartnerIdInPendingOperations(
    int oldPartnerId,
    int newPartnerId,
  ) async {
    if (oldPartnerId == newPartnerId) return 0;

    final allOps = await _db.select(_db.offlineQueue).get();
    var updated = 0;

    for (final row in allOps) {
      final values = _parseJsonValues(row.values);
      if (values['partner_id'] == oldPartnerId) {
        values['partner_id'] = newPartnerId;
        await (_db.update(_db.offlineQueue)
              ..where((tbl) => tbl.id.equals(row.id)))
            .write(
          OfflineQueueCompanion(values: drift.Value(jsonEncode(values))),
        );
        updated++;
      }
    }

    return updated;
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

  /// Reactive stream: emite el conteo de operaciones pendientes para una orden.
  ///
  /// Utiliza Drift `.watch()` para que la UI se actualice automáticamente
  /// cuando se encolan o eliminan operaciones de la cola, sin necesidad de
  /// invalidar manualmente el provider consumidor.
  ///
  /// La lógica de filtro es idéntica a [getOperationsForSaleOrder]: incluye
  /// sale.order, sale.order.line (por parentOrderId) y cualquier operación con
  /// sale_id/order_id en los valores que coincida con [orderId].
  ///
  /// NOTA: la consulta usa `.watch()` directamente en la tabla para que Drift
  /// emita en cada cambio. El filtrado adicional (parentOrderId, valores JSON)
  /// se hace en Dart sobre el stream resultante.
  Stream<int> watchPendingCountForSaleOrder(int orderId) {
    final query = _db.select(_db.offlineQueue);
    return query.watch().map((rows) {
      return rows.where((r) {
        // Operaciones directas de la orden
        if (r.model == 'sale.order' && r.recordId == orderId) return true;
        // Líneas u operaciones con parentOrderId
        if (r.parentOrderId == orderId) return true;
        // Operaciones con sale_id / order_id en el payload JSON
        try {
          final vals = _parseJsonValues(r.values);
          if (vals['sale_id'] == orderId) return true;
          if (vals['order_id'] == orderId) return true;
        } catch (_) {}
        return false;
      }).length;
    });
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

  /// Mark an operation as 'processing' to prevent double-execution.
  ///
  /// Called by OfflineQueueProcessor (y por el despacho puntual de
  /// [getOperationsForSaleOrder] en OfflineSyncService) antes de enviar la
  /// operación a Odoo.
  ///
  /// Recovery de huérfanos: si la app crashea con filas en 'processing', NO
  /// hace falta ningún reset aquí — `AppDatabase`'s `beforeOpen` callback
  /// (theos_pos_core/lib/src/database/database.dart) ya ejecuta
  /// `UPDATE offline_queue SET status='pending' WHERE status='processing'`
  /// en CADA apertura de la base de datos (no solo en upgrades de esquema),
  /// así que las filas huérfanas se auto-sanan al siguiente arranque de la
  /// app sin necesidad de duplicar esa lógica acá.
  @override
  Future<void> markOperationProcessing(int id) async {
    await (_db.update(_db.offlineQueue)..where((tbl) => tbl.id.equals(id)))
        .write(const OfflineQueueCompanion(
      status: drift.Value('processing'),
    ));
  }

  /// Revierte una operación de 'processing' a 'pending' sin tocar retry/backoff.
  ///
  /// Ver doc en [core.OfflineQueueStore.markOperationPending].
  @override
  Future<void> markOperationPending(int id) async {
    await (_db.update(_db.offlineQueue)..where((tbl) => tbl.id.equals(id)))
        .write(const OfflineQueueCompanion(
      status: drift.Value('pending'),
    ));
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
  ///
  /// Excluye filas 'processing' (ver nota en [getPendingOperations]).
  @override
  Future<List<OfflineOperation>> getOperationsForRecord(
    String model,
    int recordId,
  ) async {
    final results = await (_db.select(_db.offlineQueue)
          ..where((tbl) =>
              tbl.model.equals(model) &
              tbl.recordId.equals(recordId) &
              (tbl.status.equals('pending') | tbl.status.isNull()))
          ..orderBy([
            (tbl) => drift.OrderingTerm.asc(tbl.priority),
            (tbl) => drift.OrderingTerm.asc(tbl.createdAt),
          ]))
        .get();

    return results.map((r) => _operationFromRow(r)).toList();
  }
}
