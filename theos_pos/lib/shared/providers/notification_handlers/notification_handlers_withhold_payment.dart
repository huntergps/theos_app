part of '../notification_provider.dart';

// ============================================================
// SALE ORDER WITHHOLD / PAYMENT LINES — WebSocket Sync Handlers
// ============================================================
//
// Extraído de notification_provider.dart (refactor de descomposición,
// plan aprobado por software-architect). Cero cambio de comportamiento:
// los métodos se movieron tal cual, solo cambia su ubicación física.
//
// NOTA de riesgo (ver plan): esta sección protege cambios locales sin
// sincronizar (`isSynced==false`) contra bulk-replace concurrente del
// servidor. Se movió tal cual, sin tocar ninguna condición.

mixin _WithholdPaymentNotificationHandlers {
  /// Provisto por [NotificationCounterNotifier] (via `Notifier<T>`).
  Ref get ref;

  /// Provisto por [NotificationCounterNotifier].
  AppDatabase get _db;

  /// Handle sale order withhold updated from WebSocket
  Future<void> _handleSaleOrderWithholdUpdated(
      Map<String, dynamic> payload) async {
    try {
      final saleId = payload['sale_id'] as int;
      final action = payload['action'] as String?;
      final withholdLinesData = payload['withhold_lines'] as List<dynamic>?;
      final totalWithhold =
          (payload['total_withhold'] as num?)?.toDouble() ?? 0.0;
      final lineCount = payload['line_count'] as int? ?? 0;

      logger.i(
        '[NotificationProvider]',
        '📋 Withhold update: action=$action, saleId=$saleId, lines=$lineCount, total=$totalWithhold',
      );

      if (action == 'bulk_update' && withholdLinesData != null) {
        // Parse withhold lines from server notification data
        final lines = <WithholdLine>[];
        for (final lineData in withholdLinesData) {
          try {
            final data = lineData as Map<String, dynamic>;
            final taxName = data['tax_name'] as String? ?? 'Retención';

            // Infer withhold type from tax name if not provided
            WithholdType withholdType = WithholdType.incomeSale;
            if (taxName.toLowerCase().contains('iva') ||
                taxName.toLowerCase().contains('vat')) {
              withholdType = WithholdType.vatSale;
            }

            lines.add(WithholdLine(
              id: data['id'] as int? ?? 0,
              lineUuid: const Uuid().v4(),
              taxId: data['tax_id'] as int? ?? 0,
              taxName: taxName,
              taxPercent: (data['tax_amount'] as num?)?.toDouble() ?? 0.0,
              withholdType: withholdType,
              taxSupportCode: TaxSupportCode.fromCode(data['taxsupport_code']),
              base: (data['base'] as num?)?.toDouble() ?? 0.0,
              amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
              notes: data['notes'] as String?,
            ));
          } catch (e) {
            logger.w(
                '[NotificationProvider]', 'Error parsing withhold line: $e');
          }
        }

        // Save to local database for offline-first.
        // Si hay líneas locales sin sincronizar (isSynced==false), el replace
        // se salta (protege cambios locales) y NO tocamos tampoco el estado
        // en memoria — ver [_saveWithholdLinesToDb].
        final wrote = await _saveWithholdLinesToDb(saleId, withholdLinesData);

        if (wrote) {
          // Update the withhold lines provider (in-memory)
          ref
              .read(posWithholdLinesByOrderProvider.notifier)
              .setLinesFromServer(saleId, lines);

          logger.i(
            '[NotificationProvider]',
            '✅ Withhold lines updated for order $saleId: ${lines.length} lines',
          );
        }
      }
    } catch (e) {
      logger.e(
        '[NotificationProvider]',
        '❌ Error handling withhold updated: $e',
      );
    }
  }

  /// Verifica si existen líneas de retención locales SIN sincronizar
  /// (isSynced==false) para una orden.
  ///
  /// NOTA — por qué `isSynced` y no la tabla `dirty_fields`: el único
  /// escritor de `dirty_fields` era `WebSocketSyncService.markFieldDirty()`,
  /// un método que nunca se invocaba en ningún lugar del codebase — su
  /// servicio (`WebSocketSyncService`/`webSocketSyncServiceProvider`) era
  /// código muerto sin consumidores y fue eliminado. Es decir, la protección
  /// "dirty fields" que existía para sale.order/sale.order.line
  /// (`_handleSaleOrderUpdated`/`_handleSaleOrderLineUpdated`, arriba, ya
  /// migradas al mismo criterio `isSynced`) estaba en la práctica INERTE en
  /// producción — la tabla nunca tenía filas. `isSynced` sí se mantiene
  /// correctamente al crear líneas localmente (ver
  /// `PaymentLineLocalService`/`WithholdLineLocalService`), así que es la
  /// señal real y confiable de "hay cambios locales sin sincronizar".
  Future<bool> _hasUnsyncedWithholdLines(int orderId) async {
    final rows = await (_db.select(_db.saleOrderWithholdLine)
          ..where((t) => t.orderId.equals(orderId)))
        .get();
    return rows.any((r) => !r.isSynced);
  }

  /// Save withhold lines to local database.
  ///
  /// Retorna `true` si el reemplazo se realizó, `false` si se saltó (para
  /// que el llamador no sobrescriba tampoco el estado en memoria).
  Future<bool> _saveWithholdLinesToDb(
      int orderId, List<dynamic> linesData) async {
    try {
      // FIX 4: Guard via databaseHelperProvider (reactivo) — ver _processOfflineQueue
      if (ref.read(databaseHelperProvider) == null) return false;

      // Protección de cambios locales sin sincronizar: este método hace un
      // reemplazo COMPLETO (delete-all + insert-all) de las líneas de la
      // orden. Si hay líneas locales agregadas por el usuario que aún no se
      // sincronizaron con Odoo (isSynced==false), un bulk_update concurrente
      // del servidor las borraría para siempre (race condition corregida).
      if (await _hasUnsyncedWithholdLines(orderId)) {
        logger.w(
          '[NotificationProvider]',
          '⚠️ Order $orderId has unsynced local withhold lines — '
          'skipping WS bulk replace to protect local changes',
        );
        return false;
      }

      final db = _db;

      // Delete existing lines for this order
      await (db.delete(db.saleOrderWithholdLine)
            ..where((t) => t.orderId.equals(orderId)))
          .go();

      // Insert new lines
      for (final lineData in linesData) {
        final data = lineData as Map<String, dynamic>;
        final taxName = data['tax_name'] as String? ?? 'Retención';

        // Infer withhold type from tax name if not provided
        String withholdType = 'withhold_income_sale';
        if (taxName.toLowerCase().contains('iva') ||
            taxName.toLowerCase().contains('vat')) {
          withholdType = 'withhold_vat_sale';
        }

        final companion = SaleOrderWithholdLineCompanion.insert(
          odooId: Value(data['id'] as int?),
          orderId: orderId,
          sequence: Value(data['sequence'] as int? ?? 10),
          taxId: data['tax_id'] as int? ?? 0,
          taxName: taxName,
          taxPercent: Value((data['tax_amount'] as num?)?.toDouble() ?? 0.0),
          withholdType: withholdType,
          taxsupportCode: Value(data['taxsupport_code'] as String?),
          base: Value((data['base'] as num?)?.toDouble() ?? 0.0),
          amount: Value((data['amount'] as num?)?.toDouble() ?? 0.0),
          notes: Value(data['notes'] as String?),
          isSynced: const Value(true),
          lastSyncDate: Value(DateTime.now()),
        );
        await db.into(db.saleOrderWithholdLine).insert(companion);
      }

      logger.d(
        '[NotificationProvider]',
        '💾 Saved ${linesData.length} withhold lines to DB for order $orderId',
      );
      return true;
    } catch (e) {
      logger.e(
        '[NotificationProvider]',
        '❌ Error saving withhold lines to DB: $e',
      );
      return false;
    }
  }

  /// Handle payment line updated from WebSocket
  Future<void> _handleSaleOrderPaymentUpdated(
      Map<String, dynamic> payload) async {
    try {
      final saleId = payload['sale_id'] as int;
      final action = payload['action'] as String?;
      final paymentLinesData = payload['payment_lines'] as List<dynamic>?;
      final totalPaid =
          (payload['total_paid'] as num?)?.toDouble() ?? 0.0;
      final lineCount = payload['line_count'] as int? ?? 0;

      logger.i(
        '[NotificationProvider]',
        '💳 Payment update: action=$action, saleId=$saleId, lines=$lineCount, total=$totalPaid',
      );

      if (action == 'bulk_update' && paymentLinesData != null) {
        // Parse payment lines from server notification data
        // Generate UUID once per line and use it for both in-memory and DB (fixes delete bug)
        final lines = <PaymentLine>[];
        final processedLinesData = <Map<String, dynamic>>[];

        for (final lineData in paymentLinesData) {
          try {
            final data = Map<String, dynamic>.from(lineData as Map<String, dynamic>);

            // Generate UUID if not provided by Odoo
            final lineUuid = data['uuid'] as String? ?? const Uuid().v4();
            data['uuid'] = lineUuid; // Ensure UUID is in the data for DB save

            // Determine payment line type
            PaymentLineType type = PaymentLineType.payment;
            if (data['advance_id'] != null) {
              type = PaymentLineType.advance;
            } else if (data['credit_note_id'] != null) {
              type = PaymentLineType.creditNote;
            }

            // Parse card type
            CardType? cardType;
            final cardTypeStr = data['card_type'] as String?;
            if (cardTypeStr == 'credit') {
              cardType = CardType.credit;
            } else if (cardTypeStr == 'debit') {
              cardType = CardType.debit;
            }

            // Parse date
            DateTime date = DateTime.now();
            if (data['date'] is String) {
              date = DateTime.tryParse(data['date']) ?? DateTime.now();
            }

            // Parse optional dates
            DateTime? effectiveDate;
            if (data['effective_date'] is String) {
              effectiveDate = DateTime.tryParse(data['effective_date']);
            }
            DateTime? voucherDate;
            if (data['bank_reference_date'] is String) {
              voucherDate = DateTime.tryParse(data['bank_reference_date']);
            }

            lines.add(PaymentLine(
              id: data['id'] as int? ?? 0, // ID from Odoo (primary identifier)
              lineUuid: lineUuid, // UUID for offline sync tracking
              type: type,
              date: date,
              amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
              reference: data['payment_reference'] as String?,
              journalId: data['journal_id'] as int?,
              journalName: data['journal_name'] as String?,
              journalType: data['journal_type'] as String?,
              paymentMethodLineId: data['payment_method_line_id'] as int?,
              paymentMethodCode: data['payment_method_code'] as String?,
              paymentMethodName: data['payment_method_name'] as String?,
              bankId: data['bank_id'] as int?,
              bankName: data['bank_name'] as String?,
              cardType: cardType,
              cardBrandId: data['card_brand_id'] as int?,
              cardBrandName: data['card_brand_name'] as String?,
              cardDeadlineId: data['card_deadline_id'] as int?,
              cardDeadlineName: data['card_deadline_name'] as String?,
              loteId: data['lote_id'] as int?,
              loteName: data['lote_name'] as String?,
              voucherDate: voucherDate,
              partnerBankId: data['partner_bank_id'] as int?,
              partnerBankName: data['partner_bank_name'] as String?,
              effectiveDate: effectiveDate,
              advanceId: data['advance_id'] as int?,
              advanceName: data['advance_name'] as String?,
              creditNoteId: data['credit_note_id'] as int?,
              creditNoteName: data['credit_note_name'] as String?,
            ));

            processedLinesData.add(data); // Add to processed list with UUID
          } catch (e) {
            logger.w(
                '[NotificationProvider]', 'Error parsing payment line: $e');
          }
        }

        // Save to local database for offline-first (with UUIDs included).
        // Si hay líneas locales sin sincronizar (isSynced==false), el
        // replace se salta y NO tocamos tampoco el estado en memoria — ver
        // [_savePaymentLinesToDb].
        final wrote = await _savePaymentLinesToDb(saleId, processedLinesData);

        if (wrote) {
          // Update the payment lines provider (in-memory)
          ref
              .read(posPaymentLinesByOrderProvider.notifier)
              .setLinesFromServer(saleId, lines);

          logger.i(
            '[NotificationProvider]',
            '✅ Payment lines updated for order $saleId: ${lines.length} lines',
          );
        }
      }
    } catch (e) {
      logger.e(
        '[NotificationProvider]',
        '❌ Error handling payment updated: $e',
      );
    }
  }

  /// Verifica si existen líneas de pago locales SIN sincronizar
  /// (isSynced==false) para una orden.
  ///
  /// Ver la nota completa en [_hasUnsyncedWithholdLines] sobre por qué se usa
  /// `isSynced` en vez de la (inerte en producción) tabla `dirty_fields`.
  Future<bool> _hasUnsyncedPaymentLines(int orderId) async {
    final rows = await (_db.select(_db.saleOrderPaymentLine)
          ..where((t) => t.orderId.equals(orderId)))
        .get();
    return rows.any((r) => !r.isSynced);
  }

  /// Save payment lines to local database.
  ///
  /// Retorna `true` si el reemplazo se realizó, `false` si se saltó (para
  /// que el llamador no sobrescriba tampoco el estado en memoria).
  Future<bool> _savePaymentLinesToDb(
      int orderId, List<dynamic> linesData) async {
    try {
      // FIX 4: Guard via databaseHelperProvider (reactivo) — ver _processOfflineQueue
      if (ref.read(databaseHelperProvider) == null) return false;

      // Protección de cambios locales sin sincronizar: este método hace un
      // reemplazo COMPLETO (delete-all + insert-all) de las líneas de la
      // orden. Si hay líneas locales agregadas por el usuario que aún no se
      // sincronizaron con Odoo (isSynced==false), un bulk_update concurrente
      // del servidor las borraría para siempre (race condition corregida).
      if (await _hasUnsyncedPaymentLines(orderId)) {
        logger.w(
          '[NotificationProvider]',
          '⚠️ Order $orderId has unsynced local payment lines — '
          'skipping WS bulk replace to protect local changes',
        );
        return false;
      }

      final db = _db;

      // Use transaction to avoid race conditions with multiple WebSocket notifications
      await db.transaction(() async {
        // Delete existing lines for this order
        await (db.delete(db.saleOrderPaymentLine)
              ..where((t) => t.orderId.equals(orderId)))
            .go();

        // Insert new lines
        for (final lineData in linesData) {
          final data = lineData as Map<String, dynamic>;

          // Parse dates
          DateTime? date;
          if (data['date'] is String) {
            date = DateTime.tryParse(data['date']);
          }
          DateTime? effectiveDate;
          if (data['effective_date'] is String) {
            effectiveDate = DateTime.tryParse(data['effective_date']);
          }
          DateTime? bankReferenceDate;
          if (data['bank_reference_date'] is String) {
            bankReferenceDate = DateTime.tryParse(data['bank_reference_date']);
          }

          final companion = SaleOrderPaymentLineCompanion.insert(
            odooId: Value(data['id'] as int?),
            lineUuid: Value(data['uuid'] as String?), // UUID is now included in processed data
            orderId: orderId,
            paymentType: Value(data['payment_type'] as String? ?? 'inbound'),
            journalId: Value(data['journal_id'] as int?),
            journalName: Value(data['journal_name'] as String?),
            journalType: Value(data['journal_type'] as String?),
            paymentMethodLineId: Value(data['payment_method_line_id'] as int?),
            paymentMethodCode: Value(data['payment_method_code'] as String?),
            paymentMethodName: Value(data['payment_method_name'] as String?),
            amount: Value((data['amount'] as num?)?.toDouble() ?? 0.0),
            date: Value(date),
            paymentReference: Value(data['payment_reference'] as String?),
            creditNoteId: Value(data['credit_note_id'] as int?),
            creditNoteName: Value(data['credit_note_name'] as String?),
            advanceId: Value(data['advance_id'] as int?),
            advanceName: Value(data['advance_name'] as String?),
            cardType: Value(data['card_type'] as String?),
            cardBrandId: Value(data['card_brand_id'] as int?),
            cardBrandName: Value(data['card_brand_name'] as String?),
            cardDeadlineId: Value(data['card_deadline_id'] as int?),
            cardDeadlineName: Value(data['card_deadline_name'] as String?),
            loteId: Value(data['lote_id'] as int?),
            loteName: Value(data['lote_name'] as String?),
            bankId: Value(data['bank_id'] as int?),
            bankName: Value(data['bank_name'] as String?),
            partnerBankId: Value(data['partner_bank_id'] as int?),
            partnerBankName: Value(data['partner_bank_name'] as String?),
            effectiveDate: Value(effectiveDate),
            bankReferenceDate: Value(bankReferenceDate),
            state: Value(data['state'] as String? ?? 'draft'),
            isSynced: const Value(true),
            lastSyncDate: Value(DateTime.now()),
          );
          await db.into(db.saleOrderPaymentLine).insert(companion);
        }
      });

      logger.d(
        '[NotificationProvider]',
        '💾 Saved ${linesData.length} payment lines to DB for order $orderId',
      );
      return true;
    } catch (e) {
      logger.e(
        '[NotificationProvider]',
        '❌ Error saving payment lines to DB: $e',
      );
      return false;
    }
  }
}
