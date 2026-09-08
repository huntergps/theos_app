import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:theos_pos_core/theos_pos_core.dart';

/// Persists a new sale and its replay graph as one local transaction.
/// The temporary negative Odoo id is replaced by replay when create succeeds;
/// no remote id is required to work offline.
final class DriftSaleDraftRepository implements SaleDraftRepository {
  DriftSaleDraftRepository(this.db);
  final AppDatabase db;

  @override
  Future<int> save(SaleDraftRecord draft) => db.transaction(() async {
    final existing = await (db.select(
      db.saleOrder,
    )..where((row) => row.orderUuid.equals(draft.commandId))).getSingleOrNull();
    if (existing != null) return existing.id;
    if (draft.lines.isEmpty) throw ArgumentError('sale requires a line');

    final now = DateTime.now().toUtc();
    final temporaryOdooId = -now.microsecondsSinceEpoch;
    final total = draft.lines.fold<double>(
      0,
      (sum, line) =>
          sum + (line.unitPrice ?? line.product.price) * line.quantity,
    );
    final orderId = await db
        .into(db.saleOrder)
        .insert(
          SaleOrderCompanion.insert(
            odooId: temporaryOdooId,
            name: draft.name,
            state: const drift.Value('draft'),
            dateOrder: drift.Value(now),
            partnerId: drift.Value(draft.partnerId),
            partnerName: drift.Value(draft.partnerName),
            paymentTermId: drift.Value(draft.paymentTermId),
            amountUntaxed: drift.Value(total),
            amountTotal: drift.Value(total),
            note: drift.Value(draft.note),
            orderUuid: drift.Value(draft.commandId),
            xUuid: drift.Value(draft.commandId),
            isSynced: const drift.Value(false),
            pendingConfirm: const drift.Value(true),
          ),
        );
    final lineKeys = <String>[];
    for (var index = 0; index < draft.lines.length; index++) {
      final line = draft.lines[index];
      final price = line.unitPrice ?? line.product.price;
      final subtotal = price * line.quantity;
      await db
          .into(db.saleOrderLine)
          .insert(
            SaleOrderLineCompanion.insert(
              orderId: temporaryOdooId,
              name: line.product.name,
              lineUuid: drift.Value(line.lineUuid),
              productId: drift.Value(line.product.remoteId),
              productName: drift.Value(line.product.name),
              productUomId: drift.Value(line.product.uomId),
              productUomName: drift.Value(line.product.uomName),
              productUomQty: drift.Value(line.quantity),
              priceUnit: drift.Value(price),
              discount: drift.Value(line.discount),
              priceSubtotal: drift.Value(subtotal),
              priceTax: drift.Value(line.tax),
              priceTotal: drift.Value(subtotal + line.tax),
              taxIds: drift.Value(jsonEncode(line.product.taxIds)),
              xUuid: drift.Value(line.lineUuid),
              isSynced: const drift.Value(false),
            ),
          );
      lineKeys.add(line.lineUuid);
    }

    final createKey = '${draft.commandId}:create';
    await _enqueue(
      operationKey: createKey,
      model: 'sale.order',
      method: 'create',
      recordId: orderId,
      values: {
        'commandId': draft.commandId,
        'orderUuid': draft.commandId,
        'name': draft.name,
        'lineUuids': lineKeys,
      },
      createdAt: now,
    );
    for (final line in draft.lines) {
      await _enqueue(
        operationKey: '${draft.commandId}:line:${line.lineUuid}',
        model: 'sale.order.line',
        method: 'create',
        recordId: null,
        parentOrderId: orderId,
        values: {
          'commandId': draft.commandId,
          'lineUuid': line.lineUuid,
          'dependsOn': [createKey],
        },
        createdAt: now,
      );
    }
    return orderId;
  });

  Future<void> _enqueue({
    required String operationKey,
    required String model,
    required String method,
    required int? recordId,
    required Map<String, dynamic> values,
    required DateTime createdAt,
    int? parentOrderId,
  }) async {
    await db
        .into(db.offlineQueue)
        .insert(
          OfflineQueueCompanion.insert(
            model: model,
            values: jsonEncode(values),
            createdAt: createdAt,
            operation: drift.Value(method),
            method: drift.Value(method),
            recordId: drift.Value(recordId),
            parentOrderId: drift.Value(parentOrderId),
            operationKey: drift.Value(operationKey),
            replayPolicy: const drift.Value('manual_after_ambiguous'),
          ),
        );
  }
}
