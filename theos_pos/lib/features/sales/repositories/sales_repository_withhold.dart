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

    // 2. Delete locally
    try {
      if (lineOdooId != null) {
        await (appDb.delete(
          appDb.saleOrderWithholdLine,
        )..where((t) => t.odooId.equals(lineOdooId))).go();
      } else if (lineUuid != null) {
        await (appDb.delete(
          appDb.saleOrderWithholdLine,
        )..where((t) => t.lineUuid.equals(lineUuid))).go();
      }
      logger.d(
        '[SalesRepository] 🗑️ Withhold line deleted locally: odooId=$lineOdooId, uuid=$lineUuid',
      );
    } catch (e) {
      logger.e('[SalesRepository]', 'Error deleting withhold line locally: $e');
      return false;
    }

    // 3. If line was never synced to Odoo (local-only), we're done
    if (lineOdooId == null || !wasSynced) {
      if (_offlineQueue != null && lineUuid != null) {
        await _offlineQueue.removeOperationsForUuid(lineUuid);
        logger.d(
          '[SalesRepository] 🗑️ Removed queued ops for withhold UUID: $lineUuid',
        );
      }
      return true;
    }

    // 4. If online, sync deletion immediately
    if (isOnline) {
      try {
        final success = await _odooClient!.unlink(
          model: 'sale.order.withhold.line',
          ids: [lineOdooId],
        );
        if (success) {
          logger.i(
            '[SalesRepository] ✅ Withhold line $lineOdooId deleted from server',
          );
          return true;
        }
      } catch (e) {
        logger.w('[SalesRepository] ⚠️ Withhold delete sync failed: $e');
      }
    }

    // 5. Queue deletion for later if offline or sync failed
    if (_offlineQueue != null) {
      await _offlineQueue.queueOperation(
        model: 'sale.order.withhold.line',
        method: 'unlink',
        recordId: lineOdooId,
        values: {'uuid': lineUuid},
        parentOrderId: orderId,
      );
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

      // Queue deletions for lines that were synced to Odoo
      for (final line in existingLines) {
        if (line.odooId != null && line.odooId! > 0) {
          // Queue deletion for Odoo
          if (_offlineQueue != null) {
            await _offlineQueue.queueOperation(
              model: 'sale.order.withhold.line',
              method: 'unlink',
              recordId: line.odooId!,
              values: {'uuid': line.lineUuid},
              parentOrderId: orderId,
            );
          }
        }
      }

      // Delete all locally
      await (appDb.delete(
        appDb.saleOrderWithholdLine,
      )..where((t) => t.orderId.equals(orderId))).go();

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

      final localId = await appDb
          .into(appDb.saleOrderWithholdLine)
          .insert(companion);
      logger.d(
        '[SalesRepository] 💾 Withhold line saved locally: ID=$localId, UUID=$lineUuid',
      );

      // 2. If online, sync immediately
      if (isOnline) {
        try {
          final result = await _odooClient!.create(
            model: 'sale.order.withhold.line',
            values: {
              'sale_id': orderId,
              'tax_id': values['tax_id'],
              'base': values['base'],
              'amount': values['amount'],
              if (values['taxsupport_code'] != null)
                'taxsupport_code': values['taxsupport_code'],
              if (values['notes'] != null) 'notes': values['notes'],
            },
          );

          if (result != null) {
            // Update local record with Odoo ID
            await (appDb.update(
              appDb.saleOrderWithholdLine,
            )..where((t) => t.id.equals(localId))).write(
              SaleOrderWithholdLineCompanion(
                odooId: drift.Value(result),
                isSynced: const drift.Value(true),
                lastSyncDate: drift.Value(DateTime.now()),
              ),
            );
            logger.i(
              '[SalesRepository] ✅ Withhold line synced: local=$localId, odoo=$result',
            );
            return result;
          }
        } catch (e) {
          logger.w('[SalesRepository] ⚠️ Withhold create sync failed: $e');
        }
      }

      // 3. Queue for later if offline or sync failed
      if (_offlineQueue != null) {
        await _offlineQueue.queueOperation(
          model: 'sale.order.withhold.line',
          method: 'create',
          values: {
            'uuid': lineUuid,
            'local_id': localId,
            'sale_id': orderId,
            'tax_id': values['tax_id'],
            'base': values['base'],
            'amount': values['amount'],
            if (values['taxsupport_code'] != null)
              'taxsupport_code': values['taxsupport_code'],
            if (values['notes'] != null) 'notes': values['notes'],
          },
          parentOrderId: orderId,
        );
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

    // 2. Delete locally
    try {
      if (lineOdooId != null) {
        await (appDb.delete(
          appDb.saleOrderPaymentLine,
        )..where((t) => t.odooId.equals(lineOdooId))).go();
      } else if (lineUuid != null) {
        await (appDb.delete(
          appDb.saleOrderPaymentLine,
        )..where((t) => t.lineUuid.equals(lineUuid))).go();
      }
      logger.d(
        '[SalesRepository] 🗑️ Payment line deleted locally: odooId=$lineOdooId, uuid=$lineUuid',
      );
    } catch (e) {
      logger.e('[SalesRepository]', 'Error deleting payment line locally: $e');
      return false;
    }

    // 3. If line was never synced to Odoo (local-only), we're done
    if (lineOdooId == null || !wasSynced) {
      if (_offlineQueue != null && lineUuid != null) {
        await _offlineQueue.removeOperationsForUuid(lineUuid);
        logger.d(
          '[SalesRepository] 🗑️ Removed queued ops for payment UUID: $lineUuid',
        );
      }
      return true;
    }

    // 4. If online, sync deletion immediately
    if (isOnline) {
      try {
        final success = await _odooClient!.unlink(
          model: 'l10n_ec_collection_box.sale.order.payment',
          ids: [lineOdooId],
        );
        if (success) {
          logger.i(
            '[SalesRepository] ✅ Payment line $lineOdooId deleted from server',
          );
          return true;
        }
      } catch (e) {
        logger.w('[SalesRepository] ⚠️ Payment delete sync failed: $e');
      }
    }

    // 5. Queue deletion for later if offline or sync failed
    if (_offlineQueue != null) {
      await _offlineQueue.queueOperation(
        model: 'l10n_ec_collection_box.sale.order.payment',
        method: 'unlink',
        recordId: lineOdooId,
        values: {'uuid': lineUuid},
        parentOrderId: orderId,
      );
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

      final localId = await appDb
          .into(appDb.saleOrderPaymentLine)
          .insert(companion);
      logger.d(
        '[SalesRepository] 💾 Payment line saved locally: ID=$localId, UUID=$lineUuid',
      );

      // 2. If online, sync immediately
      if (isOnline) {
        try {
          // Prepare Odoo values
          final odooValues = <String, dynamic>{
            'sale_id': orderId,
            'amount': values['amount'],
            'date': values['date'] != null
                ? (values['date'] as DateTime).toIso8601String().split('T')[0]
                : DateTime.now().toIso8601String().split('T')[0],
          };

          // Add optional fields
          if (values['journal_id'] != null) {
            odooValues['journal_id'] = values['journal_id'];
          }
          if (values['payment_method_line_id'] != null) {
            odooValues['payment_method_line_id'] =
                values['payment_method_line_id'];
          }
          if (values['payment_reference'] != null) {
            odooValues['payment_reference'] = values['payment_reference'];
          }
          if (values['credit_note_id'] != null) {
            odooValues['credit_note_id'] = values['credit_note_id'];
          }
          if (values['advance_id'] != null) {
            odooValues['advance_id'] = values['advance_id'];
          }
          if (values['card_type'] != null) {
            odooValues['card_type'] = values['card_type'];
          }
          if (values['card_brand_id'] != null) {
            odooValues['card_brand_id'] = values['card_brand_id'];
          }
          if (values['card_deadline_id'] != null) {
            odooValues['card_deadline_id'] = values['card_deadline_id'];
          }
          if (values['lote_id'] != null) {
            odooValues['lote_id'] = values['lote_id'];
          }
          if (values['bank_id'] != null) {
            odooValues['bank_id'] = values['bank_id'];
          }
          if (values['partner_bank_id'] != null) {
            odooValues['partner_bank_id'] = values['partner_bank_id'];
          }
          if (values['effective_date'] != null) {
            odooValues['effective_date'] =
                (values['effective_date'] as DateTime).toIso8601String().split(
                  'T',
                )[0];
          }
          if (values['collection_session_id'] != null) {
            odooValues['collection_session_id'] =
                values['collection_session_id'];
          }

          final result = await _odooClient!.create(
            model: 'l10n_ec_collection_box.sale.order.payment',
            values: odooValues,
          );

          if (result != null) {
            // Update local record with Odoo ID
            await (appDb.update(
              appDb.saleOrderPaymentLine,
            )..where((t) => t.id.equals(localId))).write(
              SaleOrderPaymentLineCompanion(
                odooId: drift.Value(result),
                isSynced: const drift.Value(true),
                lastSyncDate: drift.Value(DateTime.now()),
              ),
            );
            logger.i(
              '[SalesRepository] ✅ Payment line synced: local=$localId, odoo=$result',
            );
            return result;
          }
        } catch (e) {
          logger.w('[SalesRepository] ⚠️ Payment create sync failed: $e');
        }
      }

      // 3. Queue for later if offline or sync failed
      if (_offlineQueue != null) {
        await _offlineQueue.queueOperation(
          model: 'l10n_ec_collection_box.sale.order.payment',
          method: 'create',
          values: {
            'uuid': lineUuid,
            'local_id': localId,
            'sale_id': orderId,
            'amount': values['amount'],
            'date': values['date'] != null
                ? (values['date'] as DateTime).toIso8601String().split('T')[0]
                : DateTime.now().toIso8601String().split('T')[0],
            if (values['journal_id'] != null)
              'journal_id': values['journal_id'],
            if (values['payment_method_line_id'] != null)
              'payment_method_line_id': values['payment_method_line_id'],
            if (values['payment_reference'] != null)
              'payment_reference': values['payment_reference'],
            if (values['credit_note_id'] != null)
              'credit_note_id': values['credit_note_id'],
            if (values['advance_id'] != null)
              'advance_id': values['advance_id'],
            if (values['card_type'] != null) 'card_type': values['card_type'],
            if (values['card_brand_id'] != null)
              'card_brand_id': values['card_brand_id'],
            if (values['card_deadline_id'] != null)
              'card_deadline_id': values['card_deadline_id'],
            if (values['lote_id'] != null) 'lote_id': values['lote_id'],
            if (values['collection_session_id'] != null)
              'collection_session_id': values['collection_session_id'],
          },
          parentOrderId: orderId,
        );
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
