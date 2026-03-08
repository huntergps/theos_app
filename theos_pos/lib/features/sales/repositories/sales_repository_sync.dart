part of 'sales_repository.dart';

/// Sync operations: syncing withhold lines, payment lines, and
/// fetching local payment lines from Odoo for Ecuador collection box.
extension SalesRepositorySync on SalesRepository {
  /// Sync withhold lines from Odoo for a specific order (Ecuador)
  ///
  /// This fetches the withhold lines from Odoo and saves them to the local DB.
  /// Called during forceRefresh to ensure withhold data is up to date.
  /// Sync withhold lines from Odoo - PUBLIC for use by providers
  Future<void> syncWithholdLinesFromOdoo(int orderId) async {
    if (_odooClient == null) return;

    // Skip sync for offline orders (negative ID)
    if (orderId < 0) {
      logger.d(
        '[SalesRepository] Skipping withhold sync for offline order $orderId',
      );
      return;
    }

    try {
      final response = await _odooClient.searchRead(
        model: 'sale.order.withhold.line',
        domain: [
          ['sale_id', '=', orderId],
        ],
        fields: [
          'id',
          'sale_id',
          'sequence',
          'tax_id',
          'taxsupport_code',
          'base',
          'amount',
          'notes',
          'write_date',
        ],
        order: 'sequence asc',
      );

      final appDb = _db;

      // Check for local unsynced withholds before any deletion
      final localUnsyncedWithholds = await (appDb.select(appDb.saleOrderWithholdLine)
            ..where((t) => t.orderId.equals(orderId))
            ..where((t) => t.isSynced.equals(false)))
          .get();

      if (response.isEmpty) {
        // No withhold lines in Odoo
        if (localUnsyncedWithholds.isNotEmpty) {
          // Preserve local unsynced withholds - they haven't been sent to Odoo yet
          logger.d(
            '[SalesRepository] No withholds in Odoo for order $orderId, '
            'but preserving ${localUnsyncedWithholds.length} local unsynced withholds',
          );
          return;
        }
        // No local unsynced withholds either - safe to clear
        await (appDb.delete(
          appDb.saleOrderWithholdLine,
        )..where((t) => t.orderId.equals(orderId))).go();
        logger.d(
          '[SalesRepository] No withhold lines in Odoo for order $orderId, cleared local',
        );
        return;
      }

      // Delete only SYNCED local lines for this order (preserve unsynced)
      await (appDb.delete(
        appDb.saleOrderWithholdLine,
      )..where((t) => t.orderId.equals(orderId) & t.isSynced.equals(true))).go();

      // Insert new lines from Odoo
      for (final lineData in response) {
        final lineId = lineData['id'] as int;

        // Extract tax info (tax_id is [id, name] tuple in Odoo)
        final taxId = odoo.extractMany2oneId(lineData['tax_id']);
        final taxName = odoo.extractMany2oneName(lineData['tax_id']) ?? '';

        // Determine withhold type and percentage from tax name
        String withholdType = 'withhold_income_sale';
        double taxPercent = 0.0;

        if (taxName.toLowerCase().contains('iva') ||
            taxName.toLowerCase().contains('vat')) {
          withholdType = 'withhold_vat_sale';
        }
        // Extract percentage from tax name if present (e.g., "10% WTH" -> 0.10)
        final percentMatch = RegExp(
          r'(\d+(?:[.,]\d+)?)\s*%',
        ).firstMatch(taxName);
        if (percentMatch != null) {
          taxPercent =
              (double.tryParse(percentMatch.group(1)!.replaceAll(',', '.')) ??
                  0) /
              100;
        }

        final companion = SaleOrderWithholdLineCompanion(
          odooId: drift.Value(lineId),
          orderId: drift.Value(orderId),
          sequence: drift.Value(lineData['sequence'] as int? ?? 10),
          taxId: drift.Value(taxId ?? 0),
          taxName: drift.Value(taxName),
          taxPercent: drift.Value(taxPercent),
          withholdType: drift.Value(withholdType),
          taxsupportCode: drift.Value(
            lineData['taxsupport_code'] is String
                ? lineData['taxsupport_code']
                : null,
          ),
          base: drift.Value((lineData['base'] as num?)?.toDouble() ?? 0.0),
          amount: drift.Value((lineData['amount'] as num?)?.toDouble() ?? 0.0),
          notes: drift.Value(
            lineData['notes'] is String ? lineData['notes'] : null,
          ),
          isSynced: const drift.Value(true),
          lastSyncDate: drift.Value(DateTime.now()),
        );

        await appDb.into(appDb.saleOrderWithholdLine).insert(companion);
      }

      logger.i(
        '[SalesRepository] Synced ${response.length} withhold lines for order $orderId',
      );
    } catch (e) {
      logger.w(
        '[SalesRepository] Error syncing withhold lines for order $orderId: $e',
      );
      // Don't throw - withhold sync failure shouldn't break order loading
    }
  }

  /// Get all local payment lines for an order
  ///
  /// Returns PaymentLine objects from local DB (used for offline invoice queuing)
  Future<List<PaymentLine>> getLocalPaymentLinesForOrder(int orderId) async {
    final appDb = _db;
    final rows = await (appDb.select(
      appDb.saleOrderPaymentLine,
    )..where((t) => t.orderId.equals(orderId))).get();

    return rows.map((row) {
      // Determine payment line type based on what's present
      PaymentLineType type;
      if (row.advanceId != null) {
        type = PaymentLineType.advance;
      } else if (row.creditNoteId != null) {
        type = PaymentLineType.creditNote;
      } else {
        type = PaymentLineType.payment;
      }

      // Map cardType string to enum
      CardType? cardType;
      if (row.cardType == 'credit') {
        cardType = CardType.credit;
      } else if (row.cardType == 'debit') {
        cardType = CardType.debit;
      }

      return PaymentLine(
        id: row.odooId ?? row.id,
        lineUuid: row.lineUuid,
        type: type,
        date: row.date ?? DateTime.now(),
        amount: row.amount,
        reference: row.paymentReference,
        journalId: row.journalId,
        paymentMethodLineId: row.paymentMethodLineId,
        creditNoteId: row.creditNoteId,
        advanceId: row.advanceId,
        cardType: cardType,
        cardBrandId: row.cardBrandId,
        cardDeadlineId: row.cardDeadlineId,
        loteId: row.loteId,
      );
    }).toList();
  }

  /// Sync payment lines from Odoo for a specific order (Ecuador collection box)
  ///
  /// This fetches the payment lines from Odoo and saves them to the local DB.
  /// Called during forceRefresh to ensure payment data is up to date.
  /// Sync payment lines from Odoo - PUBLIC for use by providers
  Future<void> syncPaymentLinesFromOdoo(int orderId) async {
    if (_odooClient == null) return;

    // Skip sync for offline orders (negative ID)
    if (orderId < 0) {
      logger.d(
        '[SalesRepository] Skipping payment sync for offline order $orderId',
      );
      return;
    }

    try {
      final response = await _odooClient.searchRead(
        model: 'l10n_ec_collection_box.sale.order.payment',
        domain: [
          ['sale_id', '=', orderId],
        ],
        fields: [
          'id',
          'sale_id',
          'name',
          'payment_type',
          'date',
          'amount',
          'journal_id',
          'payment_method_line_id',
          'payment_reference',
          'credit_note_id',
          'advance_id',
          'card_type',
          'card_brand_id',
          'card_deadline_id',
          'lote_id',
          'bank_id',
          'partner_bank_id',
          'effective_date',
          'bank_reference_date',
          'collection_session_id',
          'state',
          'write_date',
        ],
        order: 'id asc',
      );

      final appDb = _db;

      // Check for local unsynced payments before any deletion
      final localUnsyncedPayments = await (appDb.select(appDb.saleOrderPaymentLine)
            ..where((t) => t.orderId.equals(orderId))
            ..where((t) => t.isSynced.equals(false)))
          .get();

      if (response.isEmpty) {
        // No payment lines in Odoo
        if (localUnsyncedPayments.isNotEmpty) {
          // Preserve local unsynced payments - they haven't been sent to Odoo yet
          logger.d(
            '[SalesRepository] No payments in Odoo for order $orderId, '
            'but preserving ${localUnsyncedPayments.length} local unsynced payments',
          );
          return;
        }
        // No local unsynced payments either - safe to clear
        await (appDb.delete(
          appDb.saleOrderPaymentLine,
        )..where((t) => t.orderId.equals(orderId))).go();
        logger.d(
          '[SalesRepository] No payment lines in Odoo for order $orderId, cleared local',
        );
        return;
      }

      // Delete only SYNCED local lines for this order (preserve unsynced)
      await (appDb.delete(
        appDb.saleOrderPaymentLine,
      )..where((t) => t.orderId.equals(orderId) & t.isSynced.equals(true))).go();

      // Insert new lines from Odoo
      for (final lineData in response) {
        final lineId = lineData['id'] as int;

        // Extract related fields (many2one are [id, name] tuples in Odoo)
        final journalId = odoo.extractMany2oneId(lineData['journal_id']);
        final journalName = odoo.extractMany2oneName(lineData['journal_id']);
        final paymentMethodLineId = odoo.extractMany2oneId(
          lineData['payment_method_line_id'],
        );
        final paymentMethodName = odoo.extractMany2oneName(
          lineData['payment_method_line_id'],
        );
        final creditNoteId = odoo.extractMany2oneId(lineData['credit_note_id']);
        final creditNoteName = odoo.extractMany2oneName(
          lineData['credit_note_id'],
        );
        final advanceId = odoo.extractMany2oneId(lineData['advance_id']);
        final advanceName = odoo.extractMany2oneName(lineData['advance_id']);
        final cardBrandId = odoo.extractMany2oneId(lineData['card_brand_id']);
        final cardBrandName = odoo.extractMany2oneName(
          lineData['card_brand_id'],
        );
        final cardDeadlineId = odoo.extractMany2oneId(
          lineData['card_deadline_id'],
        );
        final cardDeadlineName = odoo.extractMany2oneName(
          lineData['card_deadline_id'],
        );
        final loteId = odoo.extractMany2oneId(lineData['lote_id']);
        final loteName = odoo.extractMany2oneName(lineData['lote_id']);
        final bankId = odoo.extractMany2oneId(lineData['bank_id']);
        final bankName = odoo.extractMany2oneName(lineData['bank_id']);
        final partnerBankId = odoo.extractMany2oneId(
          lineData['partner_bank_id'],
        );
        final partnerBankName = odoo.extractMany2oneName(
          lineData['partner_bank_id'],
        );
        // Parse dates
        DateTime? date;
        if (lineData['date'] is String) {
          date = DateTime.tryParse(lineData['date']);
        }
        DateTime? effectiveDate;
        if (lineData['effective_date'] is String) {
          effectiveDate = DateTime.tryParse(lineData['effective_date']);
        }
        DateTime? bankReferenceDate;
        if (lineData['bank_reference_date'] is String) {
          bankReferenceDate = DateTime.tryParse(
            lineData['bank_reference_date'],
          );
        }

        // Infer journal type from journal name (cash/bank)
        String? journalType;
        if (journalName != null) {
          final lowerName = journalName.toLowerCase();
          if (lowerName.contains('efectivo') ||
              lowerName.contains('cash') ||
              lowerName.contains('caja')) {
            journalType = 'cash';
          } else if (lowerName.contains('banco') ||
              lowerName.contains('bank')) {
            journalType = 'bank';
          }
        }

        final companion = SaleOrderPaymentLineCompanion(
          odooId: drift.Value(lineId),
          lineUuid: drift.Value(
            _uuid.v4(),
          ), // Generate UUID for lines synced from Odoo
          orderId: drift.Value(orderId),
          paymentType: drift.Value(
            lineData['payment_type'] is String
                ? lineData['payment_type']
                : 'inbound',
          ),
          journalId: drift.Value(journalId),
          journalName: drift.Value(journalName),
          journalType: drift.Value(journalType),
          paymentMethodLineId: drift.Value(paymentMethodLineId),
          paymentMethodName: drift.Value(paymentMethodName),
          amount: drift.Value((lineData['amount'] as num?)?.toDouble() ?? 0.0),
          date: drift.Value(date),
          paymentReference: drift.Value(
            lineData['payment_reference'] is String
                ? lineData['payment_reference']
                : null,
          ),
          creditNoteId: drift.Value(creditNoteId),
          creditNoteName: drift.Value(creditNoteName),
          advanceId: drift.Value(advanceId),
          advanceName: drift.Value(advanceName),
          cardType: drift.Value(
            lineData['card_type'] is String ? lineData['card_type'] : null,
          ),
          cardBrandId: drift.Value(cardBrandId),
          cardBrandName: drift.Value(cardBrandName),
          cardDeadlineId: drift.Value(cardDeadlineId),
          cardDeadlineName: drift.Value(cardDeadlineName),
          loteId: drift.Value(loteId),
          loteName: drift.Value(loteName),
          bankId: drift.Value(bankId),
          bankName: drift.Value(bankName),
          partnerBankId: drift.Value(partnerBankId),
          partnerBankName: drift.Value(partnerBankName),
          effectiveDate: drift.Value(effectiveDate),
          bankReferenceDate: drift.Value(bankReferenceDate),
          state: drift.Value(
            lineData['state'] is String ? lineData['state'] : 'draft',
          ),
          isSynced: const drift.Value(true),
          lastSyncDate: drift.Value(DateTime.now()),
        );

        await appDb.into(appDb.saleOrderPaymentLine).insert(companion);
      }

      logger.i(
        '[SalesRepository] Synced ${response.length} payment lines for order $orderId',
      );
    } catch (e) {
      logger.w(
        '[SalesRepository] Error syncing payment lines for order $orderId: $e',
      );
      // Don't throw - payment sync failure shouldn't break order loading
    }
  }
}
