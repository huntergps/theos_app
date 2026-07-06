part of '../notification_provider.dart';

// ============================================================
// CARD PAYMENT TABLES - WebSocket Sync Handlers
// ============================================================
//
// Extraído de notification_provider.dart (refactor de descomposición,
// plan aprobado por software-architect). Cero cambio de comportamiento:
// los métodos se movieron tal cual, solo cambia su ubicación física.

mixin _CardPaymentNotificationHandlers {
  /// Provisto por [NotificationCounterNotifier] (via `Notifier<T>`).
  Ref get ref;

  /// Provisto por [NotificationCounterNotifier].
  AppDatabase get _db;

  /// Handle card brand update notification from Odoo WebSocket
  /// Updates card brand in local database
  Future<void> _handleCardBrandUpdated(
    int brandId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete card brand from local DB
        await (db.delete(db.accountCreditCardBrand)
              ..where((t) => t.odooId.equals(brandId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Card brand $brandId deleted locally');
        return;
      }

      if (values == null) return;

      // Upsert card brand
      final name = values['name'] as String? ?? '';
      final code = values['code'] as String?;
      final active = values['active'] as bool? ?? true;

      final companion = AccountCreditCardBrandCompanion.insert(
        odooId: brandId,
        name: name,
        code: Value(code),
        active: Value(active),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.accountCreditCardBrand).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.accountCreditCardBrand.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ Card brand $brandId upserted: $name');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling card brand update: $e');
    }
  }

  /// Handle card deadline update notification from Odoo WebSocket
  /// Updates card deadline in local database
  Future<void> _handleCardDeadlineUpdated(
    int deadlineId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete card deadline from local DB
        await (db.delete(db.accountCreditCardDeadline)
              ..where((t) => t.odooId.equals(deadlineId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Card deadline $deadlineId deleted locally');
        return;
      }

      if (values == null) return;

      // Upsert card deadline
      final name = values['name'] as String? ?? '';
      final meses = values['meses'] as int? ?? 0;
      final active = values['active'] as bool? ?? true;

      final companion = AccountCreditCardDeadlineCompanion.insert(
        odooId: deadlineId,
        name: name,
        deadlineDays: meses, // Map meses to deadlineDays
        percentage: const Value(0.0), // Default percentage
        active: Value(active),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.accountCreditCardDeadline).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.accountCreditCardDeadline.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ Card deadline $deadlineId upserted: $name ($meses meses)');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling card deadline update: $e');
    }
  }

  /// Handle card lote update notification from Odoo WebSocket
  /// Updates card lote in local database
  Future<void> _handleCardLoteUpdated(
    int loteId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete card lote from local DB
        await (db.delete(db.accountCardLote)
              ..where((t) => t.odooId.equals(loteId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Card lote $loteId deleted locally');
        return;
      }

      if (values == null) return;

      // Check if this lote exists locally (may have been created offline)
      final existingLote = await (db.select(db.accountCardLote)
            ..where((t) => t.odooId.equals(loteId)))
          .getSingleOrNull();

      final name = values['name'] as String? ?? '';
      final numeroLote = values['numero_lote'] as String?;
      final state = values['state'] as String? ?? 'open';
      final amountTotal = (values['amount_total'] as num?)?.toDouble() ?? 0.0;
      final paymentCount = values['payment_count'] as int? ?? 0;

      // Extract journal_id
      int journalId;
      String? journalName;
      if (values['journal_id'] is List) {
        journalId = (values['journal_id'] as List).first as int;
        journalName = (values['journal_id'] as List).length > 1
            ? (values['journal_id'] as List)[1] as String
            : null;
      } else {
        journalId = values['journal_id'] as int? ?? 0;
      }

      // Parse date
      DateTime date = DateTime.now();
      if (values['date'] != null && values['date'] != false) {
        date = DateTime.tryParse(values['date'] as String) ?? DateTime.now();
      }

      if (existingLote != null) {
        // Update existing lote
        await (db.update(db.accountCardLote)
              ..where((t) => t.odooId.equals(loteId)))
            .write(AccountCardLoteCompanion(
          name: Value(name),
          code: Value(numeroLote ?? ''),
          state: Value(state),
          // isPosLote field doesn't exist in table
          // isPosLote: Value(isPosLote),
          totalAmount: Value(amountTotal),
          // amountBalance field doesn't exist in table
          // amountBalance: Value(amountBalance),
          transactionCount: Value(paymentCount),
          journalName: Value(journalName),
          // isSynced field doesn't exist in table
          // isSynced: const Value(true),
          writeDate: Value(DateTime.now()),
        ));
      } else {
        // Insert new lote
        await db.into(db.accountCardLote).insert(
          AccountCardLoteCompanion.insert(
            odooId: loteId,
            name: name,
            code: Value(numeroLote ?? ''),
            dateFrom: Value(date),
            dateTo: Value(date), // Using same date for both
            journalId: journalId,
            journalName: Value(journalName),
            state: Value(state),
            // isPosLote: Value(isPosLote), // Field doesn't exist
            totalAmount: Value(amountTotal),
            // amountBalance: Value(amountBalance), // Field doesn't exist
            transactionCount: Value(paymentCount),
            // isSynced: const Value(true), // Field doesn't exist
            writeDate: Value(DateTime.now()),
          ),
        );
      }

      logger.d('[NotificationProvider] ✅ Card lote $loteId upserted: $name (state: $state)');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling card lote update: $e');
    }
  }

  /// Handle journal update notification from Odoo WebSocket
  /// Updates journal card configuration in local database
  Future<void> _handleJournalUpdated(
    int journalId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete journal from local DB
        await (db.delete(db.accountJournal)
              ..where((t) => t.odooId.equals(journalId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Journal $journalId deleted locally');
        // Invalidate providers so UI refreshes
        ref.invalidate(posAvailableJournalsProvider);
        return;
      }

      if (values == null) return;

      // Check if journal exists locally
      final existingJournal = await (db.select(db.accountJournal)
            ..where((t) => t.odooId.equals(journalId)))
          .getSingleOrNull();

      if (existingJournal == null) {
        // Journal doesn't exist locally - trigger full sync
        logger.d('[NotificationProvider] Journal $journalId not found locally, skipping WebSocket update');
        return;
      }

      // Helper to extract M2O ID from Odoo value (handles [id, name] or false/null)
      int? extractM2OId(dynamic value) {
        if (value == null || value == false) return null;
        if (value is List && value.isNotEmpty) return value.first as int?;
        if (value is int) return value;
        return null;
      }

      // Only update card-related fields from WebSocket
      final isCardJournal = values['is_card_journal'] as bool?;
      final disponibleVentas = values['disponible_ventas'] as bool?;
      final disponiblePagos = values['disponible_pagos'] as bool?;

      // Extract M2O fields - handle both [id, name] tuples and false/null
      final hasDefaultCardBrandId = values.containsKey('default_card_brand_id');
      final defaultCardBrandId = extractM2OId(values['default_card_brand_id']);
      final hasDefaultDeadlineCreditId = values.containsKey('default_card_deadline_credit_id');
      final defaultDeadlineCreditId = extractM2OId(values['default_card_deadline_credit_id']);
      final hasDefaultDeadlineDebitId = values.containsKey('default_card_deadline_debit_id');
      final defaultDeadlineDebitId = extractM2OId(values['default_card_deadline_debit_id']);

      // Encode M2M fields as JSON
      final hasCardBrandIds = values.containsKey('card_brand_ids');
      String? cardBrandIds;
      final hasCardDeadlineCreditIds = values.containsKey('card_deadline_credit_ids');
      String? cardDeadlineCreditIds;
      final hasCardDeadlineDebitIds = values.containsKey('card_deadline_debit_ids');
      String? cardDeadlineDebitIds;

      if (values['card_brand_ids'] is List) {
        cardBrandIds = jsonEncode(values['card_brand_ids']);
      }
      if (values['card_deadline_credit_ids'] is List) {
        cardDeadlineCreditIds = jsonEncode(values['card_deadline_credit_ids']);
      }
      if (values['card_deadline_debit_ids'] is List) {
        cardDeadlineDebitIds = jsonEncode(values['card_deadline_debit_ids']);
      }

      // Update journal with card fields
      // Use Value(null) to clear a field, Value.absent() to leave unchanged
      await (db.update(db.accountJournal)
            ..where((t) => t.odooId.equals(journalId)))
          .write(AccountJournalCompanion(
        isCardJournal: isCardJournal != null ? Value(isCardJournal) : const Value.absent(),
        disponibleVentas: disponibleVentas != null ? Value(disponibleVentas) : const Value.absent(),
        disponiblePagos: disponiblePagos != null ? Value(disponiblePagos) : const Value.absent(),
        defaultCardBrandId: hasDefaultCardBrandId ? Value(defaultCardBrandId) : const Value.absent(),
        defaultCardDeadlineCreditId: hasDefaultDeadlineCreditId ? Value(defaultDeadlineCreditId) : const Value.absent(),
        defaultCardDeadlineDebitId: hasDefaultDeadlineDebitId ? Value(defaultDeadlineDebitId) : const Value.absent(),
        cardBrandIds: hasCardBrandIds ? Value(cardBrandIds ?? '[]') : const Value.absent(),
        cardDeadlineCreditIds: hasCardDeadlineCreditIds ? Value(cardDeadlineCreditIds ?? '[]') : const Value.absent(),
        cardDeadlineDebitIds: hasCardDeadlineDebitIds ? Value(cardDeadlineDebitIds ?? '[]') : const Value.absent(),
        writeDate: Value(DateTime.now()),
      ));

      logger.d('[NotificationProvider] ✅ Journal $journalId card config updated');
      logger.d('[NotificationProvider] Updated fields: cardBrandIds=$cardBrandIds, defaultBrand=$defaultCardBrandId');

      // Invalidate providers so UI refreshes with new card config
      ref.invalidate(posAvailableJournalsProvider);
      ref.invalidate(posCardBrandsByJournalProvider(journalId));
      // Invalidate deadlines for both card types
      ref.invalidate(posCardDeadlinesProvider((journalId: journalId, cardType: CardType.credit)));
      ref.invalidate(posCardDeadlinesProvider((journalId: journalId, cardType: CardType.debit)));
      logger.d('[NotificationProvider] 🔄 Journal card providers invalidated');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling journal update: $e');
    }
  }

  /// Handle payment method line update notification from Odoo WebSocket
  /// Updates payment method line in local database
  Future<void> _handlePaymentMethodLineUpdated(
    int lineId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete payment method line from local DB
        await (db.delete(db.accountPaymentMethodLine)
              ..where((t) => t.odooId.equals(lineId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ PaymentMethodLine $lineId deleted locally');
        // Invalidate journals provider so UI refreshes with updated payment methods
        ref.invalidate(posAvailableJournalsProvider);
        logger.d('[NotificationProvider] 🔄 posAvailableJournalsProvider invalidated');
        return;
      }

      if (values == null) return;

      // Upsert payment method line
      // Note: Odoo sends `false` (not `null`) for empty Many2one fields.
      final name = values['name'] is String ? values['name'] as String : '';
      final paymentMethodId = values['payment_method_id'] is List
          ? (values['payment_method_id'] as List).first as int
          : values['payment_method_id'] is int ? values['payment_method_id'] as int : 0;
      final paymentMethodName = values['payment_method_id'] is List && (values['payment_method_id'] as List).length > 1
          ? (values['payment_method_id'] as List)[1] as String?
          : null;
      final paymentMethodCode = values['payment_method_code'] is String ? values['payment_method_code'] as String : null;
      final paymentType = values['payment_type'] is String ? values['payment_type'] as String : null;
      final journalId = values['journal_id'] is List
          ? (values['journal_id'] as List).first as int
          : values['journal_id'] is int ? values['journal_id'] as int : 0;
      final active = values['active'] as bool? ?? true;

      final companion = AccountPaymentMethodLineCompanion.insert(
        odooId: lineId,
        name: name,
        code: Value(paymentMethodCode),
        paymentMethodId: paymentMethodId,
        paymentMethodName: Value(paymentMethodName),
        journalId: journalId,
        journalName: Value(null), // Add journalName field
        paymentType: paymentType ?? 'inbound',
        active: Value(active),
        writeDate: Value(DateTime.now()),
      );
      // Use DoUpdate with target on odoo_id (not primary key id)
      await db.into(db.accountPaymentMethodLine).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.accountPaymentMethodLine.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ PaymentMethodLine $lineId upserted: $name');
      // Invalidate journals provider so UI refreshes with updated payment methods
      ref.invalidate(posAvailableJournalsProvider);
      logger.d('[NotificationProvider] 🔄 posAvailableJournalsProvider invalidated');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling payment method line update: $e');
    }
  }
}
