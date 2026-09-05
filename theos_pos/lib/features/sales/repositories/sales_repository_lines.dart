part of 'sales_repository.dart';

/// Extension for sale order line CRUD operations (add, update, delete, sync).
extension SalesRepositoryLines on SalesRepository {
  /// Add line to order - OFFLINE-FIRST
  ///
  /// 1. Generates UUID for tracking across local/remote
  /// 2. Saves to local DB immediately
  /// 3. If online, attempts sync; if fails, queues for later
  /// 4. Returns local ID (may be negative/temporary until synced)
  Future<int?> addLine(int orderId, SaleOrderLine line) async {
    // 1. Generate UUID for offline tracking
    final lineUuid = _uuid.v4();
    final lineWithUuid = line.copyWith(
      lineUuid: lineUuid,
      orderId: orderId,
      isSynced: false,
    );

    // 2. Persist the line and its outbox intent as one durable unit. The
    // intent is written before the best-effort online dispatch so a process
    // exit between the local commit and the HTTP response cannot orphan the
    // edit. The UUID makes replay/reconciliation of creates idempotent.
    Future<int> persistLineAndIntent() async {
      final localId = await _lineManager.insertSaleOrderLineOffline(
        lineWithUuid,
      );
      await _offlineQueue?.queueOperation(
        model: 'sale.order.line',
        method: 'create',
        values: {
          'uuid': lineUuid,
          'local_id': localId,
          ..._saleLineWritableValues(lineWithUuid),
          'order_id': orderId,
        },
        parentOrderId: orderId,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      return localId;
    }

    final localId = _offlineQueue == null
        ? await persistLineAndIntent()
        : await _db.transaction(persistLineAndIntent);
    logger.d(
      '[SalesRepository] 📝 Line saved locally: ID=$localId, UUID=$lineUuid',
    );

    // 3. If online, try to sync immediately
    if (isOnline) {
      try {
        final remoteId = await _lineManager.client.create(
          model: 'sale.order.line',
          values: _saleLineCreateValues(
            lineWithUuid,
            orderId: orderId,
            uuid: lineUuid,
          ),
        );

        if (remoteId != null) {
          // Update local record with remote ID
          await _updateLineRemoteIdByUuid(lineUuid, remoteId);
          await _offlineQueue?.removeOperationsForUuid(lineUuid);
          logger.i(
            '[SalesRepository] ✅ Line synced: uuid $lineUuid -> remote $remoteId',
          );

          // Refresh lines from server to get computed values
          await getWithLines(orderId, forceRefresh: true);
          return remoteId;
        }
      } catch (e) {
        logger.w('[SalesRepository] ⚠️ Sync failed, queuing: $e');
      }
    }

    // 4. The durable intent already exists if the immediate dispatch could
    // not complete.
    if (_offlineQueue != null) {
      logger.i('[SalesRepository] 📥 Line queued for sync: UUID=$lineUuid');
    }

    return localId; // Return local ID
  }

  /// Sync all unsynced lines for an order to Odoo
  ///
  /// This method is called before confirming an order to ensure all lines
  /// exist in Odoo. Lines with negative IDs (local-only) are created in Odoo.
  ///
  /// Returns true if all lines were synced successfully, false otherwise.
  /// If offline, returns false (lines cannot be synced).
  Future<bool> syncOrderLinesToOdoo(
    int orderId,
    List<SaleOrderLine> lines,
  ) async {
    if (!isOnline) {
      logger.w('[SalesRepository]', 'Cannot sync lines: offline');
      return false;
    }

    logger.d(
      '[SalesRepository]',
      '=== syncOrderLinesToOdoo START: orderId=$orderId, lines=${lines.length} ===',
    );

    // Positive lines can also be dirty after a failed write. Ignoring them
    // allowed confirmation to race ahead with stale quantities/prices.
    final unsyncedLines = lines.where((line) => !line.isSynced).toList();
    logger.d('[SalesRepository]', 'Unsynced lines: ${unsyncedLines.length}');

    if (unsyncedLines.isEmpty) {
      logger.d('[SalesRepository]', 'All lines already synced');
      return true;
    }

    var successCount = 0;
    for (final line in unsyncedLines) {
      try {
        logger.d(
          '[SalesRepository]',
          'Syncing line ${line.id}: product=${line.productId}, qty=${line.productUomQty}',
        );

        if (line.id < 0) {
          final lineUuid = line.lineUuid?.isNotEmpty == true
              ? line.lineUuid!
              : _uuid.v4();
          if (line.lineUuid == null || line.lineUuid!.isEmpty) {
            // Persist the generated UUID before the request. If the response is
            // lost, the retry can still reconcile the same remote line.
            await _lineManager.upsertLocal(
              line.copyWith(lineUuid: lineUuid, isSynced: false),
            );
          }

          final remoteId = await _lineManager.client.create(
            model: 'sale.order.line',
            values: _saleLineCreateValues(
              line,
              orderId: orderId,
              uuid: lineUuid,
            ),
          );

          if (remoteId == null) {
            logger.e(
              '[SalesRepository]',
              '❌ Line sync failed: no remoteId returned',
            );
            continue;
          }
          await _updateLineRemoteIdByUuid(lineUuid, remoteId);
          await _offlineQueue?.removeOperationsForUuid(lineUuid);
          logger.i(
            '[SalesRepository]',
            '✅ Line synced: uuid $lineUuid -> remote $remoteId',
          );
          successCount++;
        } else {
          final success = await _lineManager.client.write(
            model: 'sale.order.line',
            ids: [line.id],
            values: _saleLineWritableValues(line)..remove('order_id'),
          );
          if (!success) {
            logger.e(
              '[SalesRepository]',
              '❌ Line ${line.id} update returned false',
            );
            continue;
          }
          final current = await _lineManager.readLocal(line.id) ?? line;
          await _lineManager.upsertLocal(
            current.copyWith(
              isSynced: true,
              lastSyncDate: DateTime.now().toUtc(),
            ),
          );
          await _offlineQueue?.removeOperationsForRecord(
            'sale.order.line',
            line.id,
          );
          successCount++;
        }
      } catch (e, st) {
        logger.e(
          '[SalesRepository]',
          'Error syncing line ${line.id}: $e',
          e,
          st,
        );
        // Continue with other lines
      }
    }

    logger.d(
      '[SalesRepository]',
      '=== syncOrderLinesToOdoo END: synced $successCount/${unsyncedLines.length} ===',
    );

    // Return true only if ALL lines were synced
    return successCount == unsyncedLines.length;
  }

  /// Update line - OFFLINE-FIRST
  ///
  /// Updates locally first, then syncs or queues for later.
  /// [values] should include calculated fields (price_subtotal, price_tax, price_total)
  /// for local persistence. These will be excluded when syncing to Odoo.
  Future<bool> updateLine(
    int lineId,
    Map<String, dynamic> values, {
    SaleOrderLine? localLine,
  }) async {
    // 1. Get existing line for UUID
    final existingLine = await _lineManager.readLocal(lineId);
    if (existingLine == null) {
      logger.w('[SalesRepository]', 'updateLine: line $lineId not found');
      return false;
    }

    // 2. Prepare values for Odoo (exclude calculated fields).
    final odooValues = _writableSaleLineMap(values)..remove('order_id');

    // 3. Persist the edited snapshot and write intent atomically before any
    // online attempt. If the outbox write fails, Drift rolls the local edit
    // back instead of leaving an unreplayable dirty row.
    Future<void> persistUpdateAndIntent() async {
      if (localLine != null) {
        await _lineManager.upsertLocal(
          localLine.copyWith(
            id: lineId,
            orderId: existingLine.orderId,
            lineUuid: existingLine.lineUuid ?? localLine.lineUuid,
            isSynced: false,
          ),
        );
      } else {
        await _lineManager.updateSaleOrderLineValues(lineId, values);
      }
      await _offlineQueue?.queueOperation(
        model: 'sale.order.line',
        method: 'write',
        recordId: lineId > 0 ? lineId : null,
        values: {'uuid': existingLine.lineUuid, ...odooValues},
        baseWriteDate: existingLine.writeDate,
        parentOrderId: existingLine.orderId,
      );
    }

    if (_offlineQueue == null) {
      await persistUpdateAndIntent();
    } else {
      await _db.transaction(persistUpdateAndIntent);
    }
    logger.d(
      '[SalesRepository] 📝 Line $lineId updated locally: ${values.keys}',
    );

    // 4. If online and has remote ID, sync immediately
    if (isOnline && lineId > 0) {
      try {
        final success = await _lineManager.client.write(
          model: 'sale.order.line',
          ids: [lineId],
          values: odooValues,
        );
        if (success) {
          // Mark the freshly edited row as synced. Using [existingLine] here
          // used to restore the pre-edit snapshot and silently lose changes.
          final currentLine = await _lineManager.readLocal(lineId);
          if (currentLine != null) {
            await _lineManager.upsertLocal(
              currentLine.copyWith(
                isSynced: true,
                lastSyncDate: DateTime.now().toUtc(),
              ),
            );
          }
          await _offlineQueue?.removeOperationsForRecord(
            'sale.order.line',
            lineId,
          );
          logger.i('[SalesRepository] ✅ Line $lineId synced update');
          return true;
        }
      } catch (e) {
        logger.w('[SalesRepository] ⚠️ Update sync failed: $e');
      }
    }

    // 5. The durable write intent remains queued after an offline/failed
    // immediate dispatch.
    if (_offlineQueue != null) {
      logger.i('[SalesRepository] 📥 Line update queued: ID=$lineId');
    }

    return true; // Local success
  }

  /// Sync a single line to Odoo (remote only, no local DB changes).
  ///
  /// Called by FastSale notifier after local upsert is already done.
  /// - If `line.id < 0` (new line) and `orderId > 0` (order exists in Odoo):
  ///   creates the line in Odoo and updates local record with remote ID.
  /// - If `line.id > 0` (existing line): writes changes to Odoo.
  /// - If offline or sync fails, queues the operation for later.
  ///
  /// This method is fire-and-forget — it never throws.
  Future<void> syncLineToOdoo(SaleOrderLine line) async {
    final orderId = line.orderId;
    if (orderId <= 0) return; // Order not in Odoo yet

    final lineUuid = line.lineUuid;
    if (lineUuid == null || lineUuid.isEmpty) {
      logger.w(
        '[SalesRepository]',
        'syncLineToOdoo: line has no UUID, skipping',
      );
      return;
    }

    try {
      if (line.id < 0) {
        // === CREATE: new local line → Odoo ===
        if (isOnline) {
          try {
            final remoteId = await _lineManager.client.create(
              model: 'sale.order.line',
              values: _saleLineCreateValues(
                line,
                orderId: orderId,
                uuid: lineUuid,
              ),
            );

            if (remoteId != null) {
              await _updateLineRemoteIdByUuid(lineUuid, remoteId);
              await _offlineQueue?.removeOperationsForUuid(lineUuid);
              logger.i(
                '[SalesRepository] syncLineToOdoo: created remote $remoteId for UUID $lineUuid',
              );
              return;
            }
          } catch (e) {
            logger.w(
              '[SalesRepository] syncLineToOdoo: create failed, queuing: $e',
            );
          }
        }

        // Queue create for later
        if (_offlineQueue != null) {
          await _offlineQueue.queueOperation(
            model: 'sale.order.line',
            method: 'create',
            values: {
              'uuid': lineUuid,
              'local_id': line.id,
              ..._saleLineWritableValues(line),
              'order_id': orderId,
            },
            parentOrderId: orderId,
          );
          logger.i(
            '[SalesRepository] syncLineToOdoo: create queued for UUID=$lineUuid',
          );
        }
      } else {
        // === UPDATE: existing line → Odoo ===
        final odooValues = _saleLineWritableValues(line)..remove('order_id');

        if (isOnline) {
          try {
            final success = await _lineManager.client.write(
              model: 'sale.order.line',
              ids: [line.id],
              values: odooValues,
            );
            if (success) {
              await _lineManager.upsertLocal(line.copyWith(isSynced: true));
              await _offlineQueue?.removeOperationsForRecord(
                'sale.order.line',
                line.id,
              );
              logger.i(
                '[SalesRepository] syncLineToOdoo: updated remote ${line.id}',
              );
              return;
            }
          } catch (e) {
            logger.w(
              '[SalesRepository] syncLineToOdoo: update failed, queuing: $e',
            );
          }
        }

        // Queue update for later
        if (_offlineQueue != null) {
          await _offlineQueue.queueOperation(
            model: 'sale.order.line',
            method: 'write',
            recordId: line.id,
            values: {'uuid': lineUuid, ...odooValues},
            baseWriteDate: line.writeDate,
            parentOrderId: orderId,
          );
          logger.i(
            '[SalesRepository] syncLineToOdoo: update queued for ID=${line.id}',
          );
        }
      }
    } catch (e, st) {
      logger.e(
        '[SalesRepository]',
        'syncLineToOdoo unexpected error: $e',
        e,
        st,
      );
    }
  }

  /// Delete line - OFFLINE-FIRST
  ///
  /// Deletes locally, then syncs or queues deletion for remote.
  Future<bool> deleteLine(int lineId) async {
    // 1. Get line info before deletion
    final existingLine = await _lineManager.readLocal(lineId);
    final lineUuid = existingLine?.lineUuid;
    final wasSynced = existingLine?.isSynced ?? false;

    // 2. If line was never synced (local-only), delete the row and its create
    // intent in the same transaction. Otherwise persist the unlink intent
    // alongside the local deletion before attempting the network call.
    if (lineId < 0 || !wasSynced) {
      Future<void> deleteLocalOnly() async {
        await _lineManager.deleteLocal(lineId);
        if (_offlineQueue != null && lineUuid != null) {
          await _offlineQueue.removeOperationsForUuid(lineUuid);
        }
      }

      if (_offlineQueue == null) {
        await deleteLocalOnly();
      } else {
        await _db.transaction(deleteLocalOnly);
      }
      logger.d('[SalesRepository] 🗑️ Line $lineId deleted locally');
      if (_offlineQueue != null && lineUuid != null) {
        logger.d(
          '[SalesRepository] 🗑️ Removed queued ops for UUID: $lineUuid',
        );
      }
      return true;
    }

    Future<void> persistDeleteAndIntent() async {
      await _lineManager.deleteLocal(lineId);
      await _offlineQueue?.queueOperation(
        model: 'sale.order.line',
        method: 'unlink',
        recordId: lineId,
        values: {'uuid': lineUuid},
        parentOrderId: existingLine?.orderId,
      );
    }

    if (_offlineQueue == null) {
      await persistDeleteAndIntent();
    } else {
      await _db.transaction(persistDeleteAndIntent);
    }
    logger.d('[SalesRepository] 🗑️ Line $lineId deleted locally');

    // 3. If online, sync deletion immediately and retire its outbox entry.
    if (isOnline) {
      try {
        final success = await _lineManager.client.unlink(
          model: 'sale.order.line',
          ids: [lineId],
        );
        if (success) {
          await _offlineQueue?.removeOperationsForRecord(
            'sale.order.line',
            lineId,
          );
          logger.i('[SalesRepository] ✅ Line $lineId deleted from server');
          return true;
        }
      } catch (e) {
        logger.w('[SalesRepository] ⚠️ Delete sync failed: $e');
      }
    }

    // 4. The durable unlink intent remains queued for later.
    if (_offlineQueue != null) {
      logger.i('[SalesRepository] 📥 Line deletion queued: ID=$lineId');
    }

    return true;
  }
}

const _saleLineWritableFields = <String>{
  'order_id',
  'sequence',
  'display_type',
  'product_id',
  'name',
  'product_uom_qty',
  'product_uom_id',
  'price_unit',
  'discount',
  'tax_ids',
  'collapse_prices',
  'collapse_composition',
  'is_optional',
};

Map<String, dynamic> _writableSaleLineMap(Map<String, dynamic> values) {
  return {
    for (final entry in values.entries)
      if (_saleLineWritableFields.contains(entry.key)) entry.key: entry.value,
  };
}

Map<String, dynamic> _saleLineWritableValues(SaleOrderLine line) {
  return _writableSaleLineMap(line.toOdoo());
}

Map<String, dynamic> _saleLineCreateValues(
  SaleOrderLine line, {
  required int orderId,
  required String uuid,
}) {
  return {
    ..._saleLineWritableValues(line),
    'order_id': orderId,
    'x_uuid': uuid,
  };
}
