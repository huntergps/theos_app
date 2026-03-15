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

    // 2. Save locally first (always succeeds)
    final localId = await _lineManager.insertSaleOrderLineOffline(lineWithUuid);
    logger.d(
      '[SalesRepository] 📝 Line saved locally: ID=$localId, UUID=$lineUuid',
    );

    // 3. If online, try to sync immediately
    if (isOnline) {
      try {
        final remoteId = await _odooClient!.create(
          model: 'sale.order.line',
          values: {
            'order_id': orderId,
            'product_id': line.productId,
            'name': line.name,
            'product_uom_qty': line.productUomQty,
            'price_unit': line.priceUnit,
            'discount': line.discount,
            if (line.productUomId != null) 'product_uom_id': line.productUomId,
            'x_uuid': lineUuid, // Store UUID in Odoo for reconciliation
          },
        );

        if (remoteId != null) {
          // Update local record with remote ID
          await _updateLineRemoteIdByUuid(lineUuid, remoteId);
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

    // 4. Queue for later sync if offline or sync failed
    if (_offlineQueue != null) {
      await _offlineQueue.queueOperation(
        model: 'sale.order.line',
        method: 'create',
        values: {
          'uuid': lineUuid,
          'local_id': localId,
          'order_id': orderId,
          'product_id': line.productId,
          'name': line.name,
          'product_uom_qty': line.productUomQty,
          'price_unit': line.priceUnit,
          'discount': line.discount,
          if (line.productUomId != null) 'product_uom_id': line.productUomId,
        },
        // No baseWriteDate for create (record doesn't exist yet)
        parentOrderId: orderId, // Para filtrar operaciones por orden
      );
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
  Future<bool> syncOrderLinesToOdoo(int orderId, List<SaleOrderLine> lines) async {
    if (!isOnline || _odooClient == null) {
      logger.w('[SalesRepository]', 'Cannot sync lines: offline');
      return false;
    }

    logger.d('[SalesRepository]', '=== syncOrderLinesToOdoo START: orderId=$orderId, lines=${lines.length} ===');

    // Find lines that need to be synced (local-only with negative IDs)
    final unsyncedLines = lines.where((l) => l.id < 0).toList();
    logger.d('[SalesRepository]', 'Unsynced lines (id < 0): ${unsyncedLines.length}');

    if (unsyncedLines.isEmpty) {
      logger.d('[SalesRepository]', 'All lines already synced');
      return true;
    }

    var successCount = 0;
    for (final line in unsyncedLines) {
      try {
        logger.d('[SalesRepository]', 'Syncing line ${line.id}: product=${line.productId}, qty=${line.productUomQty}');

        // Generate UUID if missing
        final lineUuid = line.lineUuid ?? _uuid.v4();

        // Create line in Odoo
        final remoteId = await _odooClient.create(
          model: 'sale.order.line',
          values: {
            'order_id': orderId,
            'product_id': line.productId,
            'name': line.name,
            'product_uom_qty': line.productUomQty,
            'price_unit': line.priceUnit,
            'discount': line.discount,
            if (line.productUomId != null) 'product_uom_id': line.productUomId,
            'x_uuid': lineUuid,
          },
        );

        if (remoteId != null && line.lineUuid != null) {
          // Update local record with remote ID
          await _updateLineRemoteIdByUuid(line.lineUuid!, remoteId);
          logger.i('[SalesRepository]', '✅ Line synced: local ${line.lineUuid} -> remote $remoteId');
          successCount++;
        } else {
          logger.e('[SalesRepository]', '❌ Line sync failed: no remoteId returned');
        }
      } catch (e, st) {
        logger.e('[SalesRepository]', 'Error syncing line ${line.id}: $e', e, st);
        // Continue with other lines
      }
    }

    logger.d('[SalesRepository]', '=== syncOrderLinesToOdoo END: synced $successCount/${unsyncedLines.length} ===');

    // Return true only if ALL lines were synced
    return successCount == unsyncedLines.length;
  }

  /// Update line - OFFLINE-FIRST
  ///
  /// Updates locally first, then syncs or queues for later.
  /// [values] should include calculated fields (price_subtotal, price_tax, price_total)
  /// for local persistence. These will be excluded when syncing to Odoo.
  Future<bool> updateLine(int lineId, Map<String, dynamic> values) async {
    // 1. Get existing line for UUID
    final existingLine = await _lineManager.readLocal(lineId);
    if (existingLine == null) {
      logger.w('[SalesRepository]', 'updateLine: line $lineId not found');
      return false;
    }

    // 2. Update locally first (includes calculated fields)
    await _lineManager.updateSaleOrderLineValues(lineId, values);
    logger.d(
      '[SalesRepository] 📝 Line $lineId updated locally: ${values.keys}',
    );

    // 3. Prepare values for Odoo (exclude calculated fields)
    final odooValues = Map<String, dynamic>.from(values)
      ..remove('price_subtotal')
      ..remove('price_tax')
      ..remove('price_total');

    // 4. If online and has remote ID, sync immediately
    if (isOnline && lineId > 0) {
      try {
        final success = await _odooClient!.write(
          model: 'sale.order.line',
          ids: [lineId],
          values: odooValues,
        );
        if (success) {
          // Mark as synced
          await _lineManager.upsertLocal(existingLine.copyWith(isSynced: true));
          logger.i('[SalesRepository] ✅ Line $lineId synced update');
          return true;
        }
      } catch (e) {
        logger.w('[SalesRepository] ⚠️ Update sync failed: $e');
      }
    }

    // 5. Queue for later sync (without calculated fields)
    if (_offlineQueue != null) {
      await _offlineQueue.queueOperation(
        model: 'sale.order.line',
        method: 'write',
        recordId: lineId > 0 ? lineId : null,
        values: {'uuid': existingLine.lineUuid, ...odooValues},
        baseWriteDate: existingLine.writeDate, // Para detección de conflictos
        parentOrderId:
            existingLine.orderId, // Para filtrar operaciones por orden
      );
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
      logger.w('[SalesRepository]', 'syncLineToOdoo: line has no UUID, skipping');
      return;
    }

    try {
      if (line.id < 0) {
        // === CREATE: new local line → Odoo ===
        if (isOnline) {
          try {
            final remoteId = await _odooClient!.create(
              model: 'sale.order.line',
              values: {
                'order_id': orderId,
                'product_id': line.productId,
                'name': line.name,
                'product_uom_qty': line.productUomQty,
                'price_unit': line.priceUnit,
                'discount': line.discount,
                if (line.productUomId != null) 'product_uom_id': line.productUomId,
                'x_uuid': lineUuid,
              },
            );

            if (remoteId != null) {
              await _updateLineRemoteIdByUuid(lineUuid, remoteId);
              logger.i(
                '[SalesRepository] syncLineToOdoo: created remote $remoteId for UUID $lineUuid',
              );
              return;
            }
          } catch (e) {
            logger.w('[SalesRepository] syncLineToOdoo: create failed, queuing: $e');
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
              'order_id': orderId,
              'product_id': line.productId,
              'name': line.name,
              'product_uom_qty': line.productUomQty,
              'price_unit': line.priceUnit,
              'discount': line.discount,
              if (line.productUomId != null) 'product_uom_id': line.productUomId,
            },
            parentOrderId: orderId,
          );
          logger.i('[SalesRepository] syncLineToOdoo: create queued for UUID=$lineUuid');
        }
      } else {
        // === UPDATE: existing line → Odoo ===
        final odooValues = <String, dynamic>{
          'product_uom_qty': line.productUomQty,
          'price_unit': line.priceUnit,
          'discount': line.discount,
          'name': line.name,
          if (line.productUomId != null) 'product_uom_id': line.productUomId,
        };

        if (isOnline) {
          try {
            final success = await _odooClient!.write(
              model: 'sale.order.line',
              ids: [line.id],
              values: odooValues,
            );
            if (success) {
              await _lineManager.upsertLocal(line.copyWith(isSynced: true));
              logger.i('[SalesRepository] syncLineToOdoo: updated remote ${line.id}');
              return;
            }
          } catch (e) {
            logger.w('[SalesRepository] syncLineToOdoo: update failed, queuing: $e');
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
          logger.i('[SalesRepository] syncLineToOdoo: update queued for ID=${line.id}');
        }
      }
    } catch (e, st) {
      logger.e('[SalesRepository]', 'syncLineToOdoo unexpected error: $e', e, st);
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

    // 2. Delete locally
    await _lineManager.deleteLocal(lineId);
    logger.d('[SalesRepository] 🗑️ Line $lineId deleted locally');

    // 3. If line was never synced (local-only), just remove from queue
    if (lineId < 0 || !wasSynced) {
      if (_offlineQueue != null && lineUuid != null) {
        await _offlineQueue.removeOperationsForUuid(lineUuid);
        logger.d(
          '[SalesRepository] 🗑️ Removed queued ops for UUID: $lineUuid',
        );
      }
      return true;
    }

    // 4. If online, sync deletion immediately
    if (isOnline) {
      try {
        final success = await _odooClient!.unlink(
          model: 'sale.order.line',
          ids: [lineId],
        );
        if (success) {
          logger.i('[SalesRepository] ✅ Line $lineId deleted from server');
          return true;
        }
      } catch (e) {
        logger.w('[SalesRepository] ⚠️ Delete sync failed: $e');
      }
    }

    // 5. Queue deletion for later
    if (_offlineQueue != null) {
      await _offlineQueue.queueOperation(
        model: 'sale.order.line',
        method: 'unlink',
        recordId: lineId,
        values: {'uuid': lineUuid},
        // No baseWriteDate for delete (not needed for conflict detection)
        parentOrderId:
            existingLine?.orderId, // Para filtrar operaciones por orden
      );
      logger.i('[SalesRepository] 📥 Line deletion queued: ID=$lineId');
    }

    return true;
  }
}
