/// SaleOrderLineManager extensions - Business methods beyond generated CRUD
///
/// The base SaleOrderLineManager is generated in sale_order_line.model.g.dart.
/// This file adds business-specific query methods, offline-first line operations,
/// and WebSocket upsert support.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/sales/sale_order_line.model.dart';

/// Extension methods for SaleOrderLineManager
extension SaleOrderLineManagerBusiness on SaleOrderLineManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  // ═══════════════════════════════════════════════════════════════════════════
  // Local Database Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all lines for a specific order
  Future<List<SaleOrderLine>> getByOrderId(int orderId) async {
    final query = _db.select(_db.saleOrderLine)
      ..where((t) => t.orderId.equals(orderId))
      ..orderBy([(t) => drift.OrderingTerm.asc(t.sequence)]);

    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Delete all lines for a specific order
  Future<void> deleteByOrderId(int orderId) async {
    await (_db.delete(_db.saleOrderLine)
          ..where((t) => t.orderId.equals(orderId)))
        .go();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Convenience Methods (Replaces SaleOrderLineDatasource)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get line by Odoo ID (alias for readLocal)
  Future<SaleOrderLine?> getSaleOrderLine(int odooId) => readLocal(odooId);

  /// Get line by UUID (alias for readLocalByUuid)
  Future<SaleOrderLine?> getSaleOrderLineByUuid(String uuid) =>
      readLocalByUuid(uuid);

  /// Get all lines for an order (alias for getByOrderId)
  Future<List<SaleOrderLine>> getSaleOrderLines(int orderId) =>
      getByOrderId(orderId);

  /// Check if a line exists by ID
  Future<bool> saleOrderLineExists(int lineId) async {
    final count = await (_db.selectOnly(_db.saleOrderLine)
          ..addColumns([_db.saleOrderLine.odooId.count()])
          ..where(_db.saleOrderLine.odooId.equals(lineId)))
        .map((row) => row.read(_db.saleOrderLine.odooId.count()))
        .getSingle();
    return (count ?? 0) > 0;
  }

  /// Insert a line for offline-first sync
  /// Returns the local ID
  Future<int> insertSaleOrderLineOffline(SaleOrderLine line) async {
    final localId = line.id <= 0 ? await _getNextTempLineId() : line.id;
    final lineWithId = line.copyWith(id: localId, isSynced: false);
    await upsertLocal(lineWithId);
    return localId;
  }

  /// Update local line with remote Odoo ID after sync
  Future<void> updateSaleOrderLineRemoteId(int localId, int remoteId) async {
    final existingLine = await readLocal(localId);
    if (existingLine == null) return;

    await deleteLocal(localId);

    final updatedLine = existingLine.copyWith(
      id: remoteId,
      isSynced: true,
    );
    await upsertLocal(updatedLine);
  }

  /// Update specific fields of a line
  Future<void> updateSaleOrderLineValues(
    int lineId,
    Map<String, dynamic> values,
  ) async {
    final existingLine = await readLocal(lineId);
    if (existingLine == null) return;

    var updatedLine = existingLine;
    if (values.containsKey('product_uom_qty')) {
      updatedLine = updatedLine.copyWith(
        productUomQty: (values['product_uom_qty'] as num).toDouble(),
      );
    }
    if (values.containsKey('price_unit')) {
      updatedLine = updatedLine.copyWith(
        priceUnit: (values['price_unit'] as num).toDouble(),
      );
    }
    if (values.containsKey('discount')) {
      updatedLine = updatedLine.copyWith(
        discount: (values['discount'] as num).toDouble(),
      );
    }
    if (values.containsKey('name')) {
      updatedLine = updatedLine.copyWith(name: values['name'] as String);
    }
    if (values.containsKey('price_subtotal')) {
      updatedLine = updatedLine.copyWith(
        priceSubtotal: (values['price_subtotal'] as num).toDouble(),
      );
    }
    if (values.containsKey('price_tax')) {
      updatedLine = updatedLine.copyWith(
        priceTax: (values['price_tax'] as num).toDouble(),
      );
    }
    if (values.containsKey('price_total')) {
      updatedLine = updatedLine.copyWith(
        priceTotal: (values['price_total'] as num).toDouble(),
      );
    }

    updatedLine = updatedLine.copyWith(isSynced: false);
    await upsertLocal(updatedLine);
  }

  /// Get next temporary negative ID for offline lines
  Future<int> _getNextTempLineId() async {
    final result = await _db
        .customSelect(
          'SELECT MIN(odoo_id) as min_id FROM sale_order_line',
          readsFrom: {_db.saleOrderLine},
        )
        .getSingleOrNull();

    final currentMin = result?.read<int?>('min_id') ?? 0;
    return currentMin < 0 ? currentMin - 1 : -1;
  }

  /// Upsert a sale order line directly from WebSocket payload
  Future<void> upsertSaleOrderLineFromWebSocket({
    required int odooId,
    required int orderId,
    String? lineUuid,
    int sequence = 10,
    int? productId,
    String? productName,
    required String name,
    double productUomQty = 1.0,
    int? productUomId,
    String? productUomName,
    double priceUnit = 0.0,
    double discount = 0.0,
    double priceSubtotal = 0.0,
    double priceTax = 0.0,
    double priceTotal = 0.0,
    double qtyDelivered = 0.0,
    double qtyInvoiced = 0.0,
    String? orderState,
    String? displayType,
    DateTime? writeDate,
  }) async {
    await _db.into(_db.saleOrderLine).insert(
          SaleOrderLineCompanion.insert(
            odooId: drift.Value(odooId),
            lineUuid: drift.Value(lineUuid),
            orderId: orderId,
            sequence: drift.Value(sequence),
            displayType: drift.Value(displayType ?? ''),
            productId: drift.Value(productId),
            productName: drift.Value(productName),
            name: name,
            productUomQty: drift.Value(productUomQty),
            productUomId: drift.Value(productUomId),
            productUomName: drift.Value(productUomName),
            priceUnit: drift.Value(priceUnit),
            discount: drift.Value(discount),
            priceSubtotal: drift.Value(priceSubtotal),
            priceTax: drift.Value(priceTax),
            priceTotal: drift.Value(priceTotal),
            qtyDelivered: drift.Value(qtyDelivered),
            qtyInvoiced: drift.Value(qtyInvoiced),
            orderState: drift.Value(orderState),
            isSynced: const drift.Value(true), // From Odoo, so it's synced
            writeDate: drift.Value(writeDate),
          ),
          onConflict: drift.DoUpdate(
            (_) => SaleOrderLineCompanion(
              lineUuid: drift.Value(lineUuid),
              orderId: drift.Value(orderId),
              sequence: drift.Value(sequence),
              displayType: drift.Value(displayType ?? ''),
              productId: drift.Value(productId),
              productName: drift.Value(productName),
              name: drift.Value(name),
              productUomQty: drift.Value(productUomQty),
              productUomId: drift.Value(productUomId),
              productUomName: drift.Value(productUomName),
              priceUnit: drift.Value(priceUnit),
              discount: drift.Value(discount),
              priceSubtotal: drift.Value(priceSubtotal),
              priceTax: drift.Value(priceTax),
              priceTotal: drift.Value(priceTotal),
              qtyDelivered: drift.Value(qtyDelivered),
              qtyInvoiced: drift.Value(qtyInvoiced),
              orderState: drift.Value(orderState),
              isSynced: const drift.Value(true),
              writeDate: drift.Value(writeDate),
            ),
            target: [_db.saleOrderLine.odooId],
          ),
        );
  }
}
