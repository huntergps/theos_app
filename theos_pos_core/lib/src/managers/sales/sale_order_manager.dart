/// SaleOrderManager extensions - Business methods beyond generated CRUD
///
/// The base SaleOrderManager is generated in sale_order.model.g.dart.
/// This file adds business-specific query methods, POS screen queries,
/// state management, and sync-related operations.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/sales/sale_order.model.dart';

/// Extension methods for SaleOrderManager
extension SaleOrderManagerBusiness on SaleOrderManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  // ═══════════════════════════════════════════════════════════════════════════
  // Convenience Methods (Replaces SaleOrderDatasource)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get sale order by Odoo ID (alias for readLocal)
  Future<SaleOrder?> getSaleOrder(int odooId) => readLocal(odooId);

  /// Get sale order by UUID (alias for readLocalByUuid)
  Future<SaleOrder?> getSaleOrderByUuid(String uuid) => readLocalByUuid(uuid);

  /// Get sale orders with optional filters
  Future<List<SaleOrder>> getSaleOrders({
    String? state,
    int? partnerId,
    int? userId,
    int? limit,
    int? offset,
  }) async {
    final domain = <List<dynamic>>[];
    if (state != null) domain.add(['state', '=', state]);
    if (partnerId != null) domain.add(['partner_id', '=', partnerId]);
    if (userId != null) domain.add(['user_id', '=', userId]);
    return searchLocal(domain: domain, limit: limit, offset: offset);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POS Screen Queries
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get sale orders for POS screen (seller workflow)
  Future<List<SaleOrder>> getSaleOrdersForPOS({
    required int userId,
    int limit = 10,
    int offset = 0,
  }) async {
    const allowedStates = ['draft', 'sent', 'waiting_approval', 'approved', 'sale'];

    final query = _db.select(_db.saleOrder)
      ..where((t) => t.userId.equals(userId))
      ..where((t) => t.invoiceStatus.isNotValue('invoiced'))
      ..where((t) => t.state.isIn(allowedStates))
      ..orderBy([(t) => drift.OrderingTerm.desc(t.dateOrder)])
      ..limit(limit, offset: offset);

    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Count total sale orders for POS
  Future<int> countSaleOrdersForPOS({required int userId}) async {
    const allowedStates = ['draft', 'sent', 'waiting_approval', 'approved', 'sale'];

    final query = _db.selectOnly(_db.saleOrder)
      ..addColumns([_db.saleOrder.id.count()])
      ..where(_db.saleOrder.userId.equals(userId))
      ..where(_db.saleOrder.invoiceStatus.isNotValue('invoiced'))
      ..where(_db.saleOrder.state.isIn(allowedStates));

    final result = await query.getSingle();
    return result.read(_db.saleOrder.id.count()) ?? 0;
  }

  /// Search sale orders for POS by query
  Future<List<Map<String, dynamic>>> searchSaleOrdersForPOS({
    required int userId,
    required String query,
    int limit = 20,
  }) async {
    const allowedStates = ['draft', 'sent', 'waiting_approval', 'approved', 'sale'];
    final searchPattern = '%$query%';

    final selectQuery = _db.select(_db.saleOrder)
      ..where((t) => t.userId.equals(userId))
      ..where((t) => t.invoiceStatus.isNotValue('invoiced'))
      ..where((t) => t.state.isIn(allowedStates))
      ..where(
        (t) =>
            t.name.like(searchPattern) |
            t.partnerName.like(searchPattern) |
            t.partnerVat.like(searchPattern) |
            t.partnerPhone.like(searchPattern),
      )
      ..orderBy([(t) => drift.OrderingTerm.desc(t.dateOrder)])
      ..limit(limit);

    final results = await selectQuery.get();
    return results
        .map((row) => {
              'id': row.odooId,
              'name': row.name,
              'partner_name': row.partnerName,
              'partner_vat': row.partnerVat,
              'state': row.state,
              'amount_total': row.amountTotal,
              'date_order': row.dateOrder?.toIso8601String(),
            })
        .toList();
  }

  /// Get editable orders for POS search dialog
  Future<List<Map<String, dynamic>>> getEditableOrdersForPOS({
    required int userId,
    String? query,
    int limit = 20,
    bool includeInvoiced = false,
    bool includeConfirmed = false,
    bool includeCancelled = false,
    bool allUsers = false,
  }) async {
    final states = <String>['draft', 'sent', 'waiting_approval', 'approved'];
    if (includeConfirmed || includeInvoiced) states.add('sale');
    if (includeCancelled) states.add('cancel');

    var selectQuery = _db.select(_db.saleOrder)
      ..where((t) => t.state.isIn(states));

    if (!allUsers) {
      selectQuery = selectQuery..where((t) => t.userId.equals(userId));
    }

    if (!includeInvoiced && !includeConfirmed) {
      selectQuery = selectQuery
        ..where((t) => t.invoiceStatus.isNotValue('invoiced'));
    } else if (includeInvoiced && !includeConfirmed) {
      selectQuery = selectQuery
        ..where((t) => t.invoiceStatus.equals('invoiced'));
    }

    if (query != null && query.isNotEmpty) {
      final searchPattern = '%$query%';
      selectQuery = selectQuery
        ..where(
          (t) =>
              t.name.like(searchPattern) |
              t.partnerName.like(searchPattern) |
              t.partnerVat.like(searchPattern) |
              t.partnerPhone.like(searchPattern),
        );
    }

    selectQuery = selectQuery
      ..orderBy([(t) => drift.OrderingTerm.desc(t.dateOrder)])
      ..limit(limit);

    final results = await selectQuery.get();
    return results
        .map((row) => {
              'id': row.odooId,
              'name': row.name,
              'partner_name': row.partnerName,
              'partner_vat': row.partnerVat,
              'state': row.state,
              'invoice_status': row.invoiceStatus,
              'amount_total': row.amountTotal,
              'date_order': row.dateOrder?.toIso8601String(),
            })
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // State Management
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update sale order state and pendingConfirm flag
  Future<void> updateSaleOrderState(
    int orderId, {
    required String state,
    bool? pendingConfirm,
  }) async {
    await (_db.update(_db.saleOrder)
          ..where((t) => t.odooId.equals(orderId)))
        .write(
      SaleOrderCompanion(
        state: drift.Value(state),
        pendingConfirm: pendingConfirm != null
            ? drift.Value(pendingConfirm)
            : const drift.Value.absent(),
      ),
    );
  }

  /// Clear pendingConfirm flag after successful sync
  Future<void> clearSaleOrderPendingConfirm(int orderId) async {
    await (_db.update(_db.saleOrder)
          ..where((t) => t.odooId.equals(orderId)))
        .write(const SaleOrderCompanion(pendingConfirm: drift.Value(false)));
  }

  /// Update sale order locked status
  Future<void> updateSaleOrderLocked(
    int orderId, {
    required bool locked,
    bool isSynced = false,
  }) async {
    await (_db.update(_db.saleOrder)
          ..where((t) => t.odooId.equals(orderId)))
        .write(
      SaleOrderCompanion(
        locked: drift.Value(locked),
        isSynced: drift.Value(isSynced),
      ),
    );
  }

  /// Update local sale order with remote Odoo ID after successful sync
  Future<void> updateSaleOrderRemoteId(int localId, int remoteId) async {
    final existingOrder = await readLocal(localId);
    if (existingOrder == null) return;

    await deleteLocal(localId);

    final updatedOrder = existingOrder.copyWith(
      id: remoteId,
      isSynced: true,
      lastSyncDate: DateTime.now().toUtc(),
    );
    await upsertLocal(updatedOrder);

    // Update order_id in pending lines
    await (_db.update(_db.saleOrderLine)
          ..where((t) => t.orderId.equals(localId)))
        .write(SaleOrderLineCompanion(orderId: drift.Value(remoteId)));
  }

  /// Delete a sale order and its lines
  Future<void> deleteSaleOrderWithLines(int odooId) async {
    // Delete lines first
    await (_db.delete(_db.saleOrderLine)
          ..where((t) => t.orderId.equals(odooId)))
        .go();
    // Then delete order
    await deleteLocal(odooId);
  }
}
