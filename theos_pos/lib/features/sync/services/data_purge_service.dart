import 'package:drift/drift.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import '../../users/repositories/user_repository.dart';

/// Result of a purge operation
class PurgeResult {
  final bool success;
  final int ordersDeleted;
  final int linesDeleted;
  final int operationsCleared;
  final String? error;

  const PurgeResult({
    required this.success,
    this.ordersDeleted = 0,
    this.linesDeleted = 0,
    this.operationsCleared = 0,
    this.error,
  });

  factory PurgeResult.success({
    int ordersDeleted = 0,
    int linesDeleted = 0,
    int operationsCleared = 0,
  }) =>
      PurgeResult(
        success: true,
        ordersDeleted: ordersDeleted,
        linesDeleted: linesDeleted,
        operationsCleared: operationsCleared,
      );

  factory PurgeResult.error(String message) => PurgeResult(
        success: false,
        error: message,
      );

  factory PurgeResult.permissionDenied() => const PurgeResult(
        success: false,
        error: 'No tiene permisos para eliminar registros',
      );

  @override
  String toString() => success
      ? 'Eliminados: $ordersDeleted órdenes, $linesDeleted líneas, $operationsCleared operaciones'
      : 'Error: $error';
}

/// Service for purging local data and pending sync operations
///
/// Requires permission: l10n_ec_base.group_allow_delete_records
class DataPurgeService {
  static const _tag = '[DataPurge]';
  static const _requiredPermission = 'l10n_ec_base.group_allow_delete_records';

  final AppDatabase _db;
  final OfflineQueueDataSource _offlineQueue;
  final UserRepository? _userRepository;

  DataPurgeService(this._db, this._offlineQueue, this._userRepository);

  /// Check if current user has permission to purge data
  Future<bool> hasPermission() async {
    if (_userRepository == null) return false;
    return await _userRepository.hasGroup(_requiredPermission);
  }

  /// Get count of local (unsync) orders
  Future<int> getLocalOrdersCount() async {
    // Count unsynced orders (covers both negative IDs and is_synced = false)
    return await saleOrderManager.countLocal(
      domain: [['is_synced', '=', false]],
    );
  }

  /// Get count of pending sync operations (including those waiting for retry)
  Future<int> getPendingOperationsCount() async {
    // Use includeNotReady: true to count ALL pending operations
    // including those waiting for retry after failures
    final ops = await _offlineQueue.getPendingOperations(includeNotReady: true);
    return ops.length;
  }

  /// Get count of failed operations (dead letter - exceeded max retries)
  Future<int> getFailedOperationsCount() async {
    final ops = await _offlineQueue.getDeadLetterOperations();
    return ops.length;
  }

  /// Get count of operations waiting for retry (failed but not yet dead letter)
  Future<int> getRetryWaitingCount() async {
    final allOps = await _offlineQueue.getPendingOperations(includeNotReady: true);
    return allOps.where((op) => !op.isReadyForRetry && !op.hasExceededMaxRetries).length;
  }

  /// Purge all local (unsync) orders and their lines
  ///
  /// Only deletes orders with:
  /// - Negative ID (never synced to Odoo)
  /// - is_synced = false
  ///
  /// Returns [PurgeResult] with counts or error
  Future<PurgeResult> purgeLocalOrders() async {
    if (!await hasPermission()) {
      return PurgeResult.permissionDenied();
    }

    try {
      logger.i(_tag, 'Purging local orders...');

      // Get local orders (not synced)
      final localOrders = await (_db.select(_db.saleOrder)
            ..where((t) => t.id.isSmallerThanValue(0) | t.isSynced.equals(false)))
          .get();

      if (localOrders.isEmpty) {
        logger.i(_tag, 'No local orders to purge');
        return PurgeResult.success();
      }

      int ordersDeleted = 0;
      int linesDeleted = 0;

      for (final order in localOrders) {
        // Delete lines first
        final deletedLines = await (_db.delete(_db.saleOrderLine)
              ..where((t) => t.orderId.equals(order.id)))
            .go();
        linesDeleted += deletedLines;

        // Delete order
        await (_db.delete(_db.saleOrder)..where((t) => t.id.equals(order.id)))
            .go();
        ordersDeleted++;

        logger.d(_tag, 'Deleted order ${order.id} (${order.name}) with $deletedLines lines');
      }

      logger.i(_tag, 'Purged $ordersDeleted orders, $linesDeleted lines');
      return PurgeResult.success(
        ordersDeleted: ordersDeleted,
        linesDeleted: linesDeleted,
      );
    } catch (e, stack) {
      logger.e(_tag, 'Error purging local orders', e, stack);
      return PurgeResult.error('Error al eliminar órdenes: $e');
    }
  }

  /// Clear all pending sync operations (offline queue)
  Future<PurgeResult> clearPendingOperations() async {
    if (!await hasPermission()) {
      return PurgeResult.permissionDenied();
    }

    try {
      logger.i(_tag, 'Clearing pending operations...');

      final pendingCount = await getPendingOperationsCount();
      await _offlineQueue.clearAll();

      logger.i(_tag, 'Cleared $pendingCount pending operations');
      return PurgeResult.success(operationsCleared: pendingCount);
    } catch (e, stack) {
      logger.e(_tag, 'Error clearing pending operations', e, stack);
      return PurgeResult.error('Error al limpiar operaciones: $e');
    }
  }

  /// Clear only failed operations (dead letter queue)
  Future<PurgeResult> clearFailedOperations() async {
    if (!await hasPermission()) {
      return PurgeResult.permissionDenied();
    }

    try {
      logger.i(_tag, 'Clearing failed operations...');

      final deadLetters = await _offlineQueue.getDeadLetterOperations();
      for (final op in deadLetters) {
        await _offlineQueue.removeOperation(op.id);
      }

      logger.i(_tag, 'Cleared ${deadLetters.length} failed operations');
      return PurgeResult.success(operationsCleared: deadLetters.length);
    } catch (e, stack) {
      logger.e(_tag, 'Error clearing failed operations', e, stack);
      return PurgeResult.error('Error al limpiar operaciones fallidas: $e');
    }
  }

  /// Purge everything: local orders AND pending operations
  ///
  /// This is a complete reset of local sales data
  Future<PurgeResult> purgeAll() async {
    if (!await hasPermission()) {
      return PurgeResult.permissionDenied();
    }

    try {
      logger.w(_tag, 'PURGING ALL LOCAL DATA...');

      // First clear pending operations
      final pendingCount = await getPendingOperationsCount();
      await _offlineQueue.clearAll();

      // Then delete local orders and lines
      final localOrders = await (_db.select(_db.saleOrder)
            ..where((t) => t.id.isSmallerThanValue(0) | t.isSynced.equals(false)))
          .get();

      int ordersDeleted = 0;
      int linesDeleted = 0;

      for (final order in localOrders) {
        final deletedLines = await (_db.delete(_db.saleOrderLine)
              ..where((t) => t.orderId.equals(order.id)))
            .go();
        linesDeleted += deletedLines;

        await (_db.delete(_db.saleOrder)..where((t) => t.id.equals(order.id)))
            .go();
        ordersDeleted++;
      }

      logger.w(
        _tag,
        'PURGE COMPLETE: $ordersDeleted orders, $linesDeleted lines, $pendingCount operations',
      );

      return PurgeResult.success(
        ordersDeleted: ordersDeleted,
        linesDeleted: linesDeleted,
        operationsCleared: pendingCount,
      );
    } catch (e, stack) {
      logger.e(_tag, 'Error purging all data', e, stack);
      return PurgeResult.error('Error al purgar datos: $e');
    }
  }

  /// Delete a specific order and its pending operations
  Future<PurgeResult> deleteOrder(int orderId) async {
    if (!await hasPermission()) {
      return PurgeResult.permissionDenied();
    }

    try {
      logger.i(_tag, 'Deleting order $orderId...');

      // Clear pending operations for this order
      final opsCleared = await _offlineQueue.removeOperationsForRecord('sale.order', orderId);

      // Also clear line operations
      await _db.customStatement(
        'DELETE FROM offline_queue WHERE parent_order_id = ?',
        [orderId],
      );

      // Delete lines
      final linesDeleted = await (_db.delete(_db.saleOrderLine)
            ..where((t) => t.orderId.equals(orderId)))
          .go();

      // Delete order
      await (_db.delete(_db.saleOrder)..where((t) => t.id.equals(orderId)))
          .go();

      logger.i(_tag, 'Deleted order $orderId with $linesDeleted lines, $opsCleared operations');

      return PurgeResult.success(
        ordersDeleted: 1,
        linesDeleted: linesDeleted,
        operationsCleared: opsCleared,
      );
    } catch (e, stack) {
      logger.e(_tag, 'Error deleting order $orderId', e, stack);
      return PurgeResult.error('Error al eliminar orden: $e');
    }
  }
}

// Provider moved to providers/sync_service_providers.dart
