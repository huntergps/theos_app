part of 'sales_repository.dart';

/// Extension for withhold line and payment line operations.
extension SalesRepositoryWithhold on SalesRepository {
  /// Delete withhold line - OFFLINE-FIRST
  ///
  /// Deletes locally first, then syncs or queues for later.
  /// Follows the same pattern as deleteLine for sale.order.line.
  Future<bool> deleteWithholdLine(
    int orderId, {
    int? odooId,
    String? uuid,
  }) async {
    if (odooId == null && uuid == null) {
      logger.w('[SalesRepository]', 'deleteWithholdLine: need odooId or uuid');
      return false;
    }

    final appDb = _db;

    // 1. Get line info before deletion (to check if it was synced)
    SaleOrderWithholdLineData? existingLine;
    try {
      if (odooId != null) {
        existingLine = await (appDb.select(
          appDb.saleOrderWithholdLine,
        )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();
      } else if (uuid != null) {
        existingLine = await (appDb.select(
          appDb.saleOrderWithholdLine,
        )..where((t) => t.lineUuid.equals(uuid))).getSingleOrNull();
      }
    } catch (e) {
      logger.w('[SalesRepository]', 'Error getting withhold line: $e');
    }

    final lineOdooId = odooId ?? existingLine?.odooId;
    final lineUuid = uuid ?? existingLine?.lineUuid;
    final wasSynced = existingLine?.isSynced ?? (lineOdooId != null);

    Future<int?> deleteSnapshotAndPersistIntent() async {
      if (lineOdooId != null) {
        await (appDb.delete(
          appDb.saleOrderWithholdLine,
        )..where((t) => t.odooId.equals(lineOdooId))).go();
      } else if (lineUuid != null) {
        await (appDb.delete(
          appDb.saleOrderWithholdLine,
        )..where((t) => t.lineUuid.equals(lineUuid))).go();
      }

      if (lineOdooId == null || !wasSynced) {
        if (_offlineQueue != null && lineUuid != null) {
          await _offlineQueue.removeOperationsForUuid(lineUuid);
        }
        return null;
      }

      return _offlineQueue?.queueOperation(
        model: 'sale.order.withhold.line',
        method: 'unlink',
        recordId: lineOdooId,
        values: {'uuid': lineUuid},
        parentOrderId: orderId,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
    }

    final int? operationId;
    try {
      operationId = _offlineQueue == null
          ? await deleteSnapshotAndPersistIntent()
          : await appDb.transaction(deleteSnapshotAndPersistIntent);
      logger.d(
        '[SalesRepository] 🗑️ Withhold line deleted locally: odooId=$lineOdooId, uuid=$lineUuid',
      );
    } catch (e) {
      logger.e(
        '[SalesRepository]',
        'Withhold delete snapshot/outbox transaction failed: $e',
      );
      return false;
    }

    // A local-only row and its pending create were retired atomically.
    if (lineOdooId == null || !wasSynced) {
      return true;
    }

    // 4. If online, sync deletion immediately
    if (isOnline) {
      try {
        // F6: @OdooModel de WithholdLine ya corregido — usa
        // withholdLineManager.odooModel directamente.
        final success = await withholdLineManager.client.unlink(
          model: withholdLineManager.odooModel,
          ids: [lineOdooId],
        );
        if (success) {
          if (operationId != null) {
            await _offlineQueue?.removeOperation(operationId);
          }
          logger.i(
            '[SalesRepository] ✅ Withhold line $lineOdooId deleted from server',
          );
          return true;
        }
      } catch (e) {
        logger.w('[SalesRepository] ⚠️ Withhold delete sync failed: $e');
      }
    }

    // The unlink intent was committed with the local deletion.
    if (operationId != null) {
      logger.i(
        '[SalesRepository] 📥 Withhold line deletion queued: ID=$lineOdooId',
      );
    }

    return true;
  }

  /// Delete ALL withhold lines for an order - OFFLINE-FIRST
  ///
  /// Deletes locally first, then queues Odoo deletions.
  Future<void> deleteAllWithholdLinesForOrder(int orderId) async {
    final appDb = _db;

    try {
      // Get all existing lines first (to queue deletions for synced ones)
      final existingLines = await (appDb.select(
        appDb.saleOrderWithholdLine,
      )..where((t) => t.orderId.equals(orderId))).get();

      Future<void> deleteSnapshotsAndPersistIntents() async {
        for (final line in existingLines) {
          if (line.odooId != null && line.odooId! > 0) {
            await _offlineQueue!.queueOperation(
              model: 'sale.order.withhold.line',
              method: 'unlink',
              recordId: line.odooId!,
              values: {'uuid': line.lineUuid},
              parentOrderId: orderId,
              replayPolicy: OfflineReplayPolicy.retrySafe,
            );
          } else if (line.lineUuid != null) {
            await _offlineQueue!.removeOperationsForUuid(line.lineUuid);
          }
        }

        await (appDb.delete(
          appDb.saleOrderWithholdLine,
        )..where((t) => t.orderId.equals(orderId))).go();
      }

      if (_offlineQueue == null) {
        await (appDb.delete(
          appDb.saleOrderWithholdLine,
        )..where((t) => t.orderId.equals(orderId))).go();
      } else {
        await appDb.transaction(deleteSnapshotsAndPersistIntents);
      }

      logger.d(
        '[SalesRepository] 🗑️ Deleted ${existingLines.length} withhold lines for order $orderId',
      );
    } catch (e) {
      logger.e('[SalesRepository]', 'Error deleting all withhold lines: $e');
    }
  }

  /// Create withhold line - OFFLINE-FIRST
  ///
  /// Creates locally first, then syncs or queues for later.
  Future<int?> createWithholdLine(
    int orderId,
    Map<String, dynamic> values,
  ) async {
    final appDb = _db;
    final lineUuid = values['uuid'] as String? ?? _uuid.v4();

    // 1. Save locally first
    try {
      final taxName = values['tax_name'] as String? ?? '';
      String withholdType = 'withhold_income_sale';
      if (taxName.toLowerCase().contains('iva') ||
          taxName.toLowerCase().contains('vat')) {
        withholdType = 'withhold_vat_sale';
      }

      final companion = SaleOrderWithholdLineCompanion.insert(
        lineUuid: drift.Value(lineUuid),
        orderId: orderId,
        taxId: values['tax_id'] as int? ?? 0,
        taxName: taxName,
        taxPercent: drift.Value(
          (values['tax_percent'] as num?)?.toDouble() ?? 0.0,
        ),
        withholdType: withholdType,
        taxsupportCode: drift.Value(values['taxsupport_code'] as String?),
        base: drift.Value((values['base'] as num?)?.toDouble() ?? 0.0),
        amount: drift.Value((values['amount'] as num?)?.toDouble() ?? 0.0),
        notes: drift.Value(values['notes'] as String?),
        isSynced: const drift.Value(false),
      );

      final odooValues = <String, dynamic>{
        'sale_id': orderId,
        'tax_id': values['tax_id'],
        'base': values['base'],
        'amount': values['amount'],
        if (values['taxsupport_code'] != null)
          'taxsupport_code': values['taxsupport_code'],
        if (values['notes'] != null) 'notes': values['notes'],
      };

      var operationId = 0;
      Future<int> persistSnapshotAndIntent() async {
        final localId = await appDb
            .into(appDb.saleOrderWithholdLine)
            .insert(companion);
        if (_offlineQueue != null) {
          operationId = await _offlineQueue.queueOperation(
            model: 'sale.order.withhold.line',
            method: 'create',
            values: {'uuid': lineUuid, 'local_id': localId, ...odooValues},
            parentOrderId: orderId,
            replayPolicy: OfflineReplayPolicy.retrySafe,
          );
        }
        return localId;
      }

      final localId = _offlineQueue == null
          ? await persistSnapshotAndIntent()
          : await appDb.transaction(persistSnapshotAndIntent);
      logger.d(
        '[SalesRepository] 💾 Withhold line saved locally: ID=$localId, UUID=$lineUuid',
      );

      // 2. If online, sync immediately
      if (isOnline) {
        try {
          final result = await withholdLineManager.client.create(
            model: withholdLineManager.odooModel,
            values: odooValues,
          );

          if (result != null) {
            await appDb.transaction(() async {
              await (appDb.update(
                appDb.saleOrderWithholdLine,
              )..where((t) => t.id.equals(localId))).write(
                SaleOrderWithholdLineCompanion(
                  odooId: drift.Value(result),
                  isSynced: const drift.Value(true),
                  lastSyncDate: drift.Value(DateTime.now()),
                ),
              );
              if (operationId > 0) {
                await _offlineQueue?.removeOperation(operationId);
              }
            });
            logger.i(
              '[SalesRepository] ✅ Withhold line synced: local=$localId, odoo=$result',
            );
            return result;
          }
        } catch (e) {
          logger.w('[SalesRepository] ⚠️ Withhold create sync failed: $e');
        }
      }

      // The durable create intent already exists if immediate dispatch failed.
      if (operationId > 0) {
        logger.i(
          '[SalesRepository] 📥 Withhold line queued for sync: UUID=$lineUuid',
        );
      }

      return localId;
    } catch (e) {
      logger.e('[SalesRepository]', 'Error creating withhold line: $e');
      return null;
    }
  }

  /// Delete payment line - OFFLINE-FIRST
  ///
  /// Deletes locally first, then syncs or queues for later.
  /// Follows the same pattern as deleteLine for sale.order.line.
  Future<bool> deletePaymentLine(
    int orderId, {
    int? odooId,
    String? uuid,
  }) async {
    if (odooId == null && uuid == null) {
      logger.w('[SalesRepository]', 'deletePaymentLine: need odooId or uuid');
      return false;
    }

    final appDb = _db;

    // 1. Get line info before deletion (to check if it was synced)
    SaleOrderPaymentLineData? existingLine;
    try {
      if (odooId != null) {
        existingLine = await (appDb.select(
          appDb.saleOrderPaymentLine,
        )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();
      } else if (uuid != null) {
        existingLine = await (appDb.select(
          appDb.saleOrderPaymentLine,
        )..where((t) => t.lineUuid.equals(uuid))).getSingleOrNull();
      }
    } catch (e) {
      logger.w('[SalesRepository]', 'Error getting payment line: $e');
    }

    final lineOdooId = odooId ?? existingLine?.odooId;
    final lineUuid = uuid ?? existingLine?.lineUuid;
    final wasSynced = existingLine?.isSynced ?? (lineOdooId != null);

    Future<int?> deleteSnapshotAndPersistIntent() async {
      if (lineOdooId != null) {
        await (appDb.delete(
          appDb.saleOrderPaymentLine,
        )..where((t) => t.odooId.equals(lineOdooId))).go();
      } else if (lineUuid != null) {
        await (appDb.delete(
          appDb.saleOrderPaymentLine,
        )..where((t) => t.lineUuid.equals(lineUuid))).go();
      }

      if (lineOdooId == null || !wasSynced) {
        if (_offlineQueue != null && lineUuid != null) {
          await _offlineQueue.removeOperationsForUuid(lineUuid);
        }
        return null;
      }

      return _offlineQueue?.queueOperation(
        model: 'l10n_ec_collection_box.sale.order.payment',
        method: 'unlink',
        recordId: lineOdooId,
        values: {'uuid': lineUuid},
        parentOrderId: orderId,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
    }

    final int? operationId;
    try {
      operationId = _offlineQueue == null
          ? await deleteSnapshotAndPersistIntent()
          : await appDb.transaction(deleteSnapshotAndPersistIntent);
      logger.d(
        '[SalesRepository] 🗑️ Payment line deleted locally: odooId=$lineOdooId, uuid=$lineUuid',
      );
    } catch (e) {
      logger.e(
        '[SalesRepository]',
        'Payment delete snapshot/outbox transaction failed: $e',
      );
      return false;
    }

    if (lineOdooId == null || !wasSynced) {
      return true;
    }

    // 4. If online, sync deletion immediately
    if (isOnline) {
      try {
        // F6: @OdooModel de PaymentLine ya corregido — usa
        // paymentLineManager.odooModel directamente.
        final success = await paymentLineManager.client.unlink(
          model: paymentLineManager.odooModel,
          ids: [lineOdooId],
        );
        if (success) {
          if (operationId != null) {
            await _offlineQueue?.removeOperation(operationId);
          }
          logger.i(
            '[SalesRepository] ✅ Payment line $lineOdooId deleted from server',
          );
          return true;
        }
      } catch (e) {
        logger.w('[SalesRepository] ⚠️ Payment delete sync failed: $e');
      }
    }

    if (operationId != null) {
      logger.i(
        '[SalesRepository] 📥 Payment line deletion queued: ID=$lineOdooId',
      );
    }

    return true;
  }

  /// Create payment line - OFFLINE-FIRST
  ///
  /// Creates locally first, then syncs or queues for later.
  /// Uses ID as primary identifier (like SaleOrderLine):
  /// - Positive ID = from Odoo
  /// - Negative ID = local-only (temporary)
  Future<int?> createPaymentLine(
    int orderId,
    Map<String, dynamic> values,
  ) async {
    final appDb = _db;
    final lineId =
        values['id'] as int?; // Can be null or negative for local lines
    final lineUuid = values['line_uuid'] as String? ?? _uuid.v4();

    // 1. Save locally first
    try {
      final companion = SaleOrderPaymentLineCompanion.insert(
        odooId: drift.Value(
          lineId,
        ), // ID from model (can be negative for local)
        lineUuid: drift.Value(lineUuid),
        orderId: orderId,
        paymentType: drift.Value(
          values['payment_type'] as String? ?? 'inbound',
        ),
        journalId: drift.Value(values['journal_id'] as int?),
        journalName: drift.Value(values['journal_name'] as String?),
        journalType: drift.Value(values['journal_type'] as String?),
        paymentMethodLineId: drift.Value(
          values['payment_method_line_id'] as int?,
        ),
        paymentMethodCode: drift.Value(
          values['payment_method_code'] as String?,
        ),
        paymentMethodName: drift.Value(
          values['payment_method_name'] as String?,
        ),
        amount: drift.Value((values['amount'] as num?)?.toDouble() ?? 0.0),
        date: drift.Value(values['date'] as DateTime?),
        paymentReference: drift.Value(values['payment_reference'] as String?),
        creditNoteId: drift.Value(values['credit_note_id'] as int?),
        creditNoteName: drift.Value(values['credit_note_name'] as String?),
        advanceId: drift.Value(values['advance_id'] as int?),
        advanceName: drift.Value(values['advance_name'] as String?),
        cardType: drift.Value(values['card_type'] as String?),
        cardBrandId: drift.Value(values['card_brand_id'] as int?),
        cardBrandName: drift.Value(values['card_brand_name'] as String?),
        cardDeadlineId: drift.Value(values['card_deadline_id'] as int?),
        cardDeadlineName: drift.Value(values['card_deadline_name'] as String?),
        loteId: drift.Value(values['lote_id'] as int?),
        loteName: drift.Value(values['lote_name'] as String?),
        bankId: drift.Value(values['bank_id'] as int?),
        bankName: drift.Value(values['bank_name'] as String?),
        partnerBankId: drift.Value(values['partner_bank_id'] as int?),
        partnerBankName: drift.Value(values['partner_bank_name'] as String?),
        effectiveDate: drift.Value(values['effective_date'] as DateTime?),
        bankReferenceDate: drift.Value(
          values['bank_reference_date'] as DateTime?,
        ),
        isSynced: const drift.Value(false),
      );

      final odooValues = <String, dynamic>{
        'sale_id': orderId,
        'amount': values['amount'],
        'date': values['date'] != null
            ? (values['date'] as DateTime).toIso8601String().split('T')[0]
            : DateTime.now().toIso8601String().split('T')[0],
        if (values['journal_id'] != null) 'journal_id': values['journal_id'],
        if (values['payment_method_line_id'] != null)
          'payment_method_line_id': values['payment_method_line_id'],
        if (values['payment_reference'] != null)
          'payment_reference': values['payment_reference'],
        if (values['credit_note_id'] != null)
          'credit_note_id': values['credit_note_id'],
        if (values['advance_id'] != null) 'advance_id': values['advance_id'],
        if (values['card_type'] != null) 'card_type': values['card_type'],
        if (values['card_brand_id'] != null)
          'card_brand_id': values['card_brand_id'],
        if (values['card_deadline_id'] != null)
          'card_deadline_id': values['card_deadline_id'],
        if (values['lote_id'] != null) 'lote_id': values['lote_id'],
        if (values['partner_bank_id'] != null)
          'partner_bank_id': values['partner_bank_id'],
        if (values['effective_date'] != null)
          'effective_date': (values['effective_date'] as DateTime)
              .toIso8601String()
              .split('T')[0],
        if (values['collection_session_id'] != null)
          'collection_session_id': values['collection_session_id'],
      };
      // The UI's bank_id is a local DTO key for the custom bank catalog.
      // Preserve it in the durable payload even when the client is offline.
      if (values['bank_id'] != null) {
        odooValues['l10n_ec_bank_id'] = values['bank_id'];
      }
      if (values['bank_name'] != null) {
        odooValues['bank_name_ec'] = values['bank_name'];
      }

      var operationId = 0;
      Future<int> persistSnapshotAndIntent() async {
        final localId = await appDb
            .into(appDb.saleOrderPaymentLine)
            .insert(companion);
        if (_offlineQueue != null) {
          operationId = await _offlineQueue.queueOperation(
            model: 'l10n_ec_collection_box.sale.order.payment',
            method: 'create',
            values: {'uuid': lineUuid, 'local_id': localId, ...odooValues},
            parentOrderId: orderId,
            replayPolicy: OfflineReplayPolicy.retrySafe,
          );
        }
        return localId;
      }

      final localId = _offlineQueue == null
          ? await persistSnapshotAndIntent()
          : await appDb.transaction(persistSnapshotAndIntent);
      logger.d(
        '[SalesRepository] 💾 Payment line saved locally: ID=$localId, UUID=$lineUuid',
      );

      // 2. If online, sync immediately
      if (isOnline) {
        try {
          // F6: @OdooModel de PaymentLine ya corregido — usa
          // paymentLineManager.odooModel directamente.
          final result = await paymentLineManager.client.create(
            model: paymentLineManager.odooModel,
            values: odooValues,
          );

          if (result != null) {
            await appDb.transaction(() async {
              await (appDb.update(
                appDb.saleOrderPaymentLine,
              )..where((t) => t.id.equals(localId))).write(
                SaleOrderPaymentLineCompanion(
                  odooId: drift.Value(result),
                  isSynced: const drift.Value(true),
                  lastSyncDate: drift.Value(DateTime.now()),
                ),
              );
              if (operationId > 0) {
                await _offlineQueue?.removeOperation(operationId);
              }
            });
            logger.i(
              '[SalesRepository] ✅ Payment line synced: local=$localId, odoo=$result',
            );
            return result;
          }
        } catch (e) {
          logger.w('[SalesRepository] ⚠️ Payment create sync failed: $e');
        }
      }

      if (operationId > 0) {
        logger.i(
          '[SalesRepository] 📥 Payment line queued for sync: UUID=$lineUuid',
        );
      }

      return localId;
    } catch (e) {
      logger.e('[SalesRepository]', 'Error creating payment line: $e');
      return null;
    }
  }

  /// Get unsynced lines count (for UI indicators)
  Future<int> getUnsyncedLinesCount() async {
    final lines = await _lineManager.getUnsyncedRecords();
    return lines.length;
  }
}
