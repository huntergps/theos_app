/// SaleOrderManager extensions - Business methods beyond generated CRUD
///
/// The base SaleOrderManager is generated in sale_order.model.g.dart.
/// This file adds business-specific query methods, POS screen queries,
/// state management, and sync-related operations.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/sales/sale_order_enums.dart';
import '../../models/sales/sale_order.model.dart';

/// Aggregated sale-order metrics for a bounded period.
///
/// This value is intentionally independent from presentation concerns so the
/// dashboard can observe a handful of grouped rows instead of materializing
/// every cached sale order on each database update.
class SaleOrderPeriodMetrics {
  final int totalOrders;
  final double totalAmount;
  final int draftCount;
  final int confirmedCount;
  final int doneCount;
  final int cancelledCount;

  const SaleOrderPeriodMetrics({
    this.totalOrders = 0,
    this.totalAmount = 0,
    this.draftCount = 0,
    this.confirmedCount = 0,
    this.doneCount = 0,
    this.cancelledCount = 0,
  });
}

/// One database-backed page for the sales list and its matching facets.
///
/// Rows are bounded by [pageSize]. Counts are calculated by SQLite from the
/// same filter revision, so opening the list never materializes the complete
/// sales history in Dart.
class SaleOrderListPage {
  final List<SaleOrder> rows;
  final Map<String, int> countsByState;
  final int totalCount;
  final int unsyncedCount;
  final int pageIndex;
  final int pageSize;

  const SaleOrderListPage({
    required this.rows,
    required this.countsByState,
    required this.totalCount,
    required this.unsyncedCount,
    required this.pageIndex,
    required this.pageSize,
  });
}

/// Extension methods for SaleOrderManager
extension SaleOrderManagerBusiness on SaleOrderManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  /// Watches a state count without materializing matching orders.
  Stream<int> watchStateCount(String state) {
    final countExpression = _db.saleOrder.id.count();
    final query = _db.selectOnly(_db.saleOrder)
      ..addColumns([countExpression])
      ..where(_db.saleOrder.state.equals(state));
    return query.watchSingle().map((row) => row.read(countExpression) ?? 0);
  }

  /// Watches a bounded page of orders plus SQL aggregate counts.
  Stream<SaleOrderListPage> watchListPage({
    String searchQuery = '',
    String state = 'all',
    int? userId,
    int pageIndex = 0,
    int pageSize = 80,
  }) {
    if (pageIndex < 0) {
      throw ArgumentError.value(pageIndex, 'pageIndex', 'Must not be negative');
    }
    if (pageSize <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be positive');
    }

    // The aggregate is a cheap invalidation signal for any table mutation.
    // Each emission is then projected inside one read transaction.
    final revisionCount = _db.saleOrder.id.count();
    final revision = _db.selectOnly(_db.saleOrder)..addColumns([revisionCount]);

    return revision.watchSingle().asyncMap((_) {
      return _db.transaction(() async {
        final normalizedQuery = searchQuery.trim().toLowerCase();
        final pattern = '%$normalizedQuery%';

        drift.Expression<bool> scopePredicate({required bool includeState}) {
          drift.Expression<bool> predicate = const drift.Constant(true);
          if (normalizedQuery.isNotEmpty) {
            predicate =
                predicate &
                (_db.saleOrder.name.lower().like(pattern) |
                    _db.saleOrder.partnerName.lower().like(pattern) |
                    _db.saleOrder.clientOrderRef.lower().like(pattern));
          }
          if (userId != null) {
            predicate = predicate & _db.saleOrder.userId.equals(userId);
          }
          if (includeState && state != 'all') {
            predicate = predicate & _db.saleOrder.state.equals(state);
          }
          return predicate;
        }

        final rowsQuery = _db.select(_db.saleOrder)
          ..where((_) => scopePredicate(includeState: true));
        rowsQuery
          ..orderBy([(table) => drift.OrderingTerm.desc(table.dateOrder)])
          ..limit(pageSize, offset: pageIndex * pageSize);
        final driftRows = await rowsQuery.get();

        final stateExpression = _db.saleOrder.state;
        final countExpression = _db.saleOrder.id.count();
        final countsQuery = _db.selectOnly(_db.saleOrder)
          ..addColumns([stateExpression, countExpression])
          ..where(scopePredicate(includeState: false));
        countsQuery.groupBy([stateExpression]);
        final groupedRows = await countsQuery.get();

        final counts = <String, int>{
          'all': 0,
          'draft': 0,
          'sent': 0,
          'waiting': 0,
          'approved': 0,
          'rejected': 0,
          'sale': 0,
          'cancel': 0,
        };
        for (final row in groupedRows) {
          final count = row.read(countExpression) ?? 0;
          final rowState = row.read(stateExpression) ?? '';
          counts['all'] = counts['all']! + count;
          counts[rowState] = (counts[rowState] ?? 0) + count;
        }

        final filteredCountExpression = _db.saleOrder.id.count();
        final filteredCountQuery = _db.selectOnly(_db.saleOrder)
          ..addColumns([filteredCountExpression])
          ..where(scopePredicate(includeState: true));
        final filteredCountRow = await filteredCountQuery.getSingle();

        final unsyncedExpression = _db.saleOrder.id.count();
        final unsyncedQuery = _db.selectOnly(_db.saleOrder)
          ..addColumns([unsyncedExpression])
          ..where(_db.saleOrder.isSynced.equals(false));
        final unsyncedRow = await unsyncedQuery.getSingle();

        return SaleOrderListPage(
          rows: driftRows.map(fromDrift).toList(growable: false),
          countsByState: counts,
          totalCount: filteredCountRow.read(filteredCountExpression) ?? 0,
          unsyncedCount: unsyncedRow.read(unsyncedExpression) ?? 0,
          pageIndex: pageIndex,
          pageSize: pageSize,
        );
      });
    });
  }

  /// Watches grouped sales metrics inside the half-open interval
  /// `[startInclusive, endExclusive)`.
  ///
  /// SQLite performs the grouping and aggregation. The stream emits at most
  /// one row per sale-order state, avoiding the previous dashboard path that
  /// loaded and filtered the complete local order catalog in Dart.
  Stream<SaleOrderPeriodMetrics> watchPeriodMetrics({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    if (!startInclusive.isBefore(endExclusive)) {
      return Stream.error(
        ArgumentError.value(
          endExclusive,
          'endExclusive',
          'Must be after startInclusive',
        ),
      );
    }

    final countExpression = _db.saleOrder.id.count();
    final amountExpression = _db.saleOrder.amountTotal.sum();
    final query = _db.selectOnly(_db.saleOrder)
      ..addColumns([_db.saleOrder.state, countExpression, amountExpression])
      ..where(
        _db.saleOrder.dateOrder.isBiggerOrEqualValue(startInclusive) &
            _db.saleOrder.dateOrder.isSmallerThanValue(endExclusive),
      )
      ..groupBy([_db.saleOrder.state]);

    return query.watch().map((rows) {
      var totalOrders = 0;
      var totalAmount = 0.0;
      var draftCount = 0;
      var confirmedCount = 0;
      var doneCount = 0;
      var cancelledCount = 0;

      for (final row in rows) {
        final count = row.read(countExpression) ?? 0;
        final amount = row.read(amountExpression) ?? 0.0;
        final state = SaleOrderStateExtension.fromString(
          row.read(_db.saleOrder.state),
        );

        totalOrders += count;
        switch (state) {
          case SaleOrderState.draft:
          case SaleOrderState.sent:
          case SaleOrderState.waitingApproval:
          case SaleOrderState.approved:
          case SaleOrderState.rejected:
            draftCount += count;
          case SaleOrderState.sale:
            confirmedCount += count;
            totalAmount += amount;
          case SaleOrderState.done:
            doneCount += count;
            totalAmount += amount;
          case SaleOrderState.cancel:
            cancelledCount += count;
        }
      }

      return SaleOrderPeriodMetrics(
        totalOrders: totalOrders,
        totalAmount: totalAmount,
        draftCount: draftCount,
        confirmedCount: confirmedCount,
        doneCount: doneCount,
        cancelledCount: cancelledCount,
      );
    });
  }

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

  /// Get sale orders for the POS using an explicit caller-resolved scope.
  Future<List<SaleOrder>> getSaleOrdersForPOS({
    int? userId,
    List<int>? companyIds,
    List<int>? collectionSessionIds,
    List<String>? states,
    List<String>? invoiceStatuses,
    int limit = 10,
    int offset = 0,
  }) async {
    final allowedStates =
        states ?? const ['draft', 'sent', 'waiting', 'approved', 'sale'];

    final query = _db.select(_db.saleOrder)
      ..where((t) => t.state.isIn(allowedStates))
      ..orderBy([(t) => drift.OrderingTerm.desc(t.dateOrder)])
      ..limit(limit, offset: offset);
    if (userId != null) {
      query.where((t) => t.userId.equals(userId));
    }
    if (companyIds != null) {
      if (companyIds.isEmpty) return const [];
      query.where((t) => t.companyId.isIn(companyIds));
    }
    if (collectionSessionIds != null) {
      query.where(
        (t) =>
            t.collectionSessionId.isNull() |
            t.collectionSessionId.isIn(collectionSessionIds),
      );
    }
    if (invoiceStatuses == null) {
      query.where((t) => t.invoiceStatus.isNotValue('invoiced'));
    } else {
      query.where((t) => t.invoiceStatus.isIn(invoiceStatuses));
    }

    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Count total sale orders for POS
  Future<int> countSaleOrdersForPOS({
    int? userId,
    List<int>? companyIds,
    List<int>? collectionSessionIds,
    List<String>? states,
    List<String>? invoiceStatuses,
  }) async {
    final allowedStates =
        states ?? const ['draft', 'sent', 'waiting', 'approved', 'sale'];

    final query = _db.selectOnly(_db.saleOrder)
      ..addColumns([_db.saleOrder.id.count()])
      ..where(_db.saleOrder.state.isIn(allowedStates));
    if (userId != null) {
      query.where(_db.saleOrder.userId.equals(userId));
    }
    if (companyIds != null) {
      if (companyIds.isEmpty) return 0;
      query.where(_db.saleOrder.companyId.isIn(companyIds));
    }
    if (collectionSessionIds != null) {
      query.where(
        _db.saleOrder.collectionSessionId.isNull() |
            _db.saleOrder.collectionSessionId.isIn(collectionSessionIds),
      );
    }
    if (invoiceStatuses == null) {
      query.where(_db.saleOrder.invoiceStatus.isNotValue('invoiced'));
    } else {
      query.where(_db.saleOrder.invoiceStatus.isIn(invoiceStatuses));
    }

    final result = await query.getSingle();
    return result.read(_db.saleOrder.id.count()) ?? 0;
  }

  /// Search sale orders for POS by query
  Future<List<Map<String, dynamic>>> searchSaleOrdersForPOS({
    required int userId,
    required String query,
    int limit = 20,
  }) async {
    const allowedStates = ['draft', 'sent', 'waiting', 'approved', 'sale'];
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
        .map(
          (row) => {
            'id': row.odooId,
            'name': row.name,
            'partner_name': row.partnerName,
            'partner_vat': row.partnerVat,
            'state': row.state,
            'amount_total': row.amountTotal,
            'date_order': row.dateOrder?.toIso8601String(),
          },
        )
        .toList();
  }

  /// Get editable orders for POS search dialog
  Future<List<Map<String, dynamic>>> getEditableOrdersForPOS({
    int? userId,
    List<int>? companyIds,
    List<int>? collectionSessionIds,
    List<String>? states,
    List<String>? invoiceStatuses,
    String? query,
    int limit = 20,
    bool includeInvoiced = false,
    bool includeConfirmed = false,
    bool includeCancelled = false,
    bool allUsers = false,
  }) async {
    final allowedStates =
        states?.toList() ?? <String>['draft', 'sent', 'waiting', 'approved'];
    if (includeConfirmed || includeInvoiced) allowedStates.add('sale');
    if (includeCancelled) allowedStates.add('cancel');

    var selectQuery = _db.select(_db.saleOrder)
      ..where((t) => t.state.isIn(allowedStates));

    if (!allUsers && userId != null) {
      selectQuery = selectQuery..where((t) => t.userId.equals(userId));
    }
    if (companyIds != null) {
      if (companyIds.isEmpty) return const [];
      selectQuery = selectQuery..where((t) => t.companyId.isIn(companyIds));
    }
    if (collectionSessionIds != null) {
      selectQuery = selectQuery
        ..where(
          (t) =>
              t.collectionSessionId.isNull() |
              t.collectionSessionId.isIn(collectionSessionIds),
        );
    }

    if (invoiceStatuses != null) {
      selectQuery = selectQuery
        ..where((t) => t.invoiceStatus.isIn(invoiceStatuses));
    } else if (!includeInvoiced && !includeConfirmed) {
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
        .map(
          (row) => {
            'id': row.odooId,
            'name': row.name,
            'partner_name': row.partnerName,
            'partner_vat': row.partnerVat,
            'state': row.state,
            'invoice_status': row.invoiceStatus,
            'amount_total': row.amountTotal,
            'date_order': row.dateOrder?.toIso8601String(),
          },
        )
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
    await (_db.update(
      _db.saleOrder,
    )..where((t) => t.odooId.equals(orderId))).write(
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
    await (_db.update(_db.saleOrder)..where((t) => t.odooId.equals(orderId)))
        .write(const SaleOrderCompanion(pendingConfirm: drift.Value(false)));
  }

  /// Update sale order locked status
  Future<void> updateSaleOrderLocked(
    int orderId, {
    required bool locked,
    bool isSynced = false,
  }) async {
    await (_db.update(
      _db.saleOrder,
    )..where((t) => t.odooId.equals(orderId))).write(
      SaleOrderCompanion(
        locked: drift.Value(locked),
        isSynced: drift.Value(isSynced),
      ),
    );
  }

  /// Update local sale order with remote Odoo ID after successful sync
  ///
  /// Wrapped in a transaction: el delete + upsert + actualización de líneas
  /// hijas debe ser atómico. Si algún paso falla, la DB queda en su estado
  /// previo consistente y el caller recibe la excepción sin escrituras
  /// parciales.
  ///
  /// IMPORTANTE: además de `sale_order_line`, hay que actualizar `order_id`
  /// en `sale_order_payment_line` y `sale_order_withhold_line` — ambas tienen
  /// FK a `SaleOrder.odooId` (ver `sales_lines_tables.dart`). Si se omiten,
  /// esas líneas quedan huérfanas apuntando al ID local negativo que
  /// `deleteLocal(localId)` acaba de borrar, y desaparecen de cualquier query
  /// futura sobre la orden ya sincronizada.
  Future<void> updateSaleOrderRemoteId(int localId, int remoteId) async {
    final existingOrder = await readLocal(localId);
    if (existingOrder == null) return;

    await _db.transaction(() async {
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

      // Update order_id in pending payment lines (mismo FK huérfano si se omite)
      await (_db.update(_db.saleOrderPaymentLine)
            ..where((t) => t.orderId.equals(localId)))
          .write(SaleOrderPaymentLineCompanion(orderId: drift.Value(remoteId)));

      // Update order_id in pending withhold lines (mismo FK huérfano si se omite)
      await (_db.update(
        _db.saleOrderWithholdLine,
      )..where((t) => t.orderId.equals(localId))).write(
        SaleOrderWithholdLineCompanion(orderId: drift.Value(remoteId)),
      );
    });
  }

  /// Delete a sale order and its lines atomically
  ///
  /// Wrapped in a transaction: both deletes succeed together or neither does,
  /// avoiding orphaned lines if the order delete were to fail midway.
  Future<void> deleteSaleOrderWithLines(int odooId) async {
    await _db.transaction(() async {
      // Delete lines first (FK dependency)
      await (_db.delete(
        _db.saleOrderLine,
      )..where((t) => t.orderId.equals(odooId))).go();
      // Then delete order
      await deleteLocal(odooId);
    });
  }
}
