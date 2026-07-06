part of '../notification_provider.dart';

// ============================================================
// CASH OUT / DEPOSIT / SESSION CASH — WebSocket Sync Handlers
// ============================================================
//
// Extraído de notification_provider.dart (refactor de descomposición,
// plan aprobado por software-architect). Cero cambio de comportamiento:
// los métodos se movieron tal cual, solo cambia su ubicación física.

mixin _CashNotificationHandlers {
  /// Provisto por [NotificationCounterNotifier].
  AppDatabase get _db;

  /// Handle cash out update notification from Odoo WebSocket
  /// Updates cash out in local database
  Future<void> _handleCashOutUpdated(
    int cashOutId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete cash out from local DB
        await (db.delete(db.cashOut)
              ..where((t) => t.odooId.equals(cashOutId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ CashOut $cashOutId deleted locally');
        return;
      }

      if (values == null) return;

      // Extract values from payload
      // Note: Odoo sends `false` (not `null`) for empty Many2one fields,
      // so we use `is Type` checks instead of direct `as Type?` casts.
      final sessionId = values['session_id'] is List
          ? (values['session_id'] as List).first as int
          : values['session_id'] is int ? values['session_id'] as int : 0;
      final cashOutType = values['cash_out_type'] is String ? values['cash_out_type'] as String : 'other';
      final cashFlow = values['cash_flow'] is String ? values['cash_flow'] as String : 'out';
      final journalId = values['journal_id'] is List
          ? (values['journal_id'] as List).first as int? ?? 0
          : values['journal_id'] is int ? values['journal_id'] as int : 0;
      final journalName = values['journal_id'] is List && (values['journal_id'] as List).length > 1
          ? (values['journal_id'] as List)[1] as String?
          : values['journal_name'] is String ? values['journal_name'] as String : null;
      final partnerId = values['partner_id'] is List
          ? (values['partner_id'] as List).first as int?
          : values['partner_id'] is int ? values['partner_id'] as int : null;
      final partnerName = values['partner_id'] is List && (values['partner_id'] as List).length > 1
          ? (values['partner_id'] as List)[1] as String?
          : values['partner_name'] is String ? values['partner_name'] as String : null;
      final amount = (values['amount'] as num?)?.toDouble() ?? 0.0;
      final description = values['description'] is String ? values['description'] as String : null;
      final name = values['name'] is String ? values['name'] as String : null;
      final note = values['note'] is String ? values['note'] as String : null;
      final uuid = values['uuid'] is String ? values['uuid'] as String : null;
      final state = values['state'] is String ? values['state'] as String : 'draft';
      final cashOutTypeId = values['cash_out_type_id'] is List
          ? (values['cash_out_type_id'] as List).first as int?
          : values['cash_out_type_id'] is int ? values['cash_out_type_id'] as int : null;
      final typeName = values['cash_out_type_id'] is List && (values['cash_out_type_id'] as List).length > 1
          ? (values['cash_out_type_id'] as List)[1] as String?
          : values['type_name'] is String ? values['type_name'] as String : null;
      final moveId = values['move_id'] is List
          ? (values['move_id'] as List).first as int?
          : values['move_id'] is int ? values['move_id'] as int : null;
      final approvedById = values['approved_by_id'] is List
          ? (values['approved_by_id'] as List).first as int?
          : values['approved_by_id'] is int ? values['approved_by_id'] as int : null;
      final approvedByName = values['approved_by_id'] is List && (values['approved_by_id'] as List).length > 1
          ? (values['approved_by_id'] as List)[1] as String?
          : values['approved_by_name'] is String ? values['approved_by_name'] as String : null;

      // Parse dates
      DateTime? date;
      if (values['date'] is String) {
        date = DateTime.tryParse(values['date'] as String);
      }
      DateTime? approvedAt;
      if (values['approved_at'] is String) {
        approvedAt = DateTime.tryParse(values['approved_at'] as String);
      }

      final companion = CashOutCompanion.insert(
        odooId: Value(cashOutId),
        collectionSessionId: sessionId,
        cashOutType: cashOutType,
        type: Value(cashOutType),
        cashFlow: Value(cashFlow),
        journalId: Value(journalId),
        journalName: Value(journalName),
        partnerId: Value(partnerId),
        partnerName: Value(partnerName),
        amount: Value(amount),
        description: Value(description),
        name: Value(name),
        note: Value(note),
        date: Value(date),
        uuid: Value(uuid),
        approvedById: Value(approvedById),
        approvedByName: Value(approvedByName),
        approvedAt: Value(approvedAt),
        moveId: Value(moveId),
        cashOutTypeId: Value(cashOutTypeId),
        typeName: Value(typeName),
        state: Value(state),
        isSynced: const Value(true),
        lastSyncDate: Value(DateTime.now()),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.cashOut).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.cashOut.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ CashOut $cashOutId upserted: $name (amount=$amount, state=$state)');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling cash out update: $e');
    }
  }

  /// Handle deposit update notification from Odoo WebSocket
  /// Updates deposit in local database
  Future<void> _handleDepositUpdated(
    int depositId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete deposit from local DB
        await (db.delete(db.collectionSessionDeposit)
              ..where((t) => t.odooId.equals(depositId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Deposit $depositId deleted locally');
        return;
      }

      if (values == null) return;

      // Extract values from payload
      // Note: Odoo sends `false` (not `null`) for empty Many2one fields,
      // so we use `is Type` checks instead of direct `as Type?` casts.
      final sessionId = values['session_id'] is List
          ? (values['session_id'] as List).first as int
          : values['session_id'] is int ? values['session_id'] as int : 0;
      final depositName = values['name'] is String ? values['name'] as String : null;
      final depositType = values['deposit_type'] is String ? values['deposit_type'] as String : 'bank';
      final amount = (values['amount'] as num?)?.toDouble() ?? 0.0;
      final reference = values['reference'] is String ? values['reference'] as String : null;
      final sessionUuid = values['session_uuid'] is String ? values['session_uuid'] as String : null;
      final userId = values['user_id'] is List
          ? (values['user_id'] as List).first as int?
          : values['user_id'] is int ? values['user_id'] as int : null;
      final userName = values['user_id'] is List && (values['user_id'] as List).length > 1
          ? (values['user_id'] as List)[1] as String?
          : values['user_name'] is String ? values['user_name'] as String : null;
      final cashAmount = (values['cash_amount'] as num?)?.toDouble() ?? 0.0;
      final checkAmount = (values['check_amount'] as num?)?.toDouble() ?? 0.0;
      final checkCount = values['check_count'] as int? ?? 0;
      final bankJournalId = values['bank_journal_id'] is List
          ? (values['bank_journal_id'] as List).first as int?
          : values['bank_journal_id'] is int ? values['bank_journal_id'] as int : null;
      final bankJournalName = values['bank_journal_id'] is List && (values['bank_journal_id'] as List).length > 1
          ? (values['bank_journal_id'] as List)[1] as String?
          : values['bank_journal_name'] is String ? values['bank_journal_name'] as String : null;
      final bankId = values['bank_id'] is List
          ? (values['bank_id'] as List).first as int?
          : values['bank_id'] is int ? values['bank_id'] as int : null;
      final bankName = values['bank_id'] is List && (values['bank_id'] as List).length > 1
          ? (values['bank_id'] as List)[1] as String?
          : values['bank_name'] is String ? values['bank_name'] as String : null;
      final state = values['state'] is String ? values['state'] as String : 'draft';
      final depositSlipNumber = values['deposit_slip_number'] is String ? values['deposit_slip_number'] as String : null;
      final bankReference = values['bank_reference'] is String ? values['bank_reference'] as String : null;
      final depositMoveId = values['move_id'] is List
          ? (values['move_id'] as List).first as int?
          : values['move_id'] is int ? values['move_id'] as int : null;
      final depositorName = values['depositor_name'] is String ? values['depositor_name'] as String : null;
      final notes = values['notes'] is String ? values['notes'] as String : null;
      final depositUuid = values['uuid'] is String ? values['uuid'] as String : null;

      // Parse dates
      DateTime depositDate = DateTime.now();
      if (values['deposit_date'] is String) {
        depositDate = DateTime.tryParse(values['deposit_date'] as String) ?? DateTime.now();
      } else if (values['date'] is String) {
        depositDate = DateTime.tryParse(values['date'] as String) ?? DateTime.now();
      }
      DateTime? accountingDate;
      if (values['accounting_date'] is String) {
        accountingDate = DateTime.tryParse(values['accounting_date'] as String);
      }

      final companion = CollectionSessionDepositCompanion.insert(
        odooId: Value(depositId),
        uuid: Value(depositUuid),
        collectionSessionId: sessionId,
        name: Value(depositName),
        depositType: depositType,
        type: Value(depositType),
        amount: Value(amount),
        reference: Value(reference),
        number: Value(reference),
        sessionUuid: Value(sessionUuid),
        userId: Value(userId),
        userName: Value(userName),
        depositDate: depositDate,
        date: Value(depositDate),
        accountingDate: Value(accountingDate),
        cashAmount: Value(cashAmount),
        checkAmount: Value(checkAmount),
        checkCount: Value(checkCount),
        bankJournalId: Value(bankJournalId),
        bankJournalName: Value(bankJournalName),
        bankId: Value(bankId),
        bankName: Value(bankName),
        state: Value(state),
        depositSlipNumber: Value(depositSlipNumber),
        bankReference: Value(bankReference),
        moveId: Value(depositMoveId),
        depositorName: Value(depositorName),
        notes: Value(notes),
        isSynced: const Value(true),
        lastSyncDate: Value(DateTime.now()),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.collectionSessionDeposit).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.collectionSessionDeposit.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ Deposit $depositId upserted: $depositName (amount=$amount, state=$state)');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling deposit update: $e');
    }
  }

  /// Handle session cash update notification from Odoo WebSocket
  /// Updates session cash record in local database
  Future<void> _handleSessionCashUpdated(
    int cashId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete session cash from local DB
        await (db.delete(db.collectionSessionCash)
              ..where((t) => t.odooId.equals(cashId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ SessionCash $cashId deleted locally');
        return;
      }

      if (values == null) return;

      // Extract values from payload
      // Note: Odoo sends `false` (not `null`) for empty Many2one fields,
      // so we use `is Type` checks instead of direct `as Type?` casts.
      final sessionId = values['session_id'] is List
          ? (values['session_id'] as List).first as int
          : values['session_id'] is int ? values['session_id'] as int : 0;
      final denomination = values['denomination'] is String ? values['denomination'] as String : null;
      final cashType = values['cash_type'] is String ? values['cash_type'] as String : null;
      final count = values['count'] as int? ?? 0;
      final amount = (values['amount'] as num?)?.toDouble() ?? 0.0;

      // Individual denomination fields (legacy)
      final bills100 = values['bills_100'] as int? ?? 0;
      final bills50 = values['bills_50'] as int? ?? 0;
      final bills20 = values['bills_20'] as int? ?? 0;
      final bills10 = values['bills_10'] as int? ?? 0;
      final bills5 = values['bills_5'] as int? ?? 0;
      final bills1 = values['bills_1'] as int? ?? 0;
      final coins1 = values['coins_1'] as int? ?? 0;
      final coins50 = values['coins_50'] as int? ?? 0;
      final coins25 = values['coins_25'] as int? ?? 0;
      final coins10 = values['coins_10'] as int? ?? 0;
      final coins5 = values['coins_5'] as int? ?? 0;
      final coins1Cent = values['coins_1_cent'] as int? ?? 0;
      final notes = values['notes'] is String ? values['notes'] as String : null;

      final companion = CollectionSessionCashCompanion.insert(
        odooId: cashId,
        collectionSessionId: sessionId,
        denomination: Value(denomination),
        cashType: Value(cashType),
        count: Value(count),
        amount: Value(amount),
        bills100: Value(bills100),
        bills50: Value(bills50),
        bills20: Value(bills20),
        bills10: Value(bills10),
        bills5: Value(bills5),
        bills1: Value(bills1),
        coins1: Value(coins1),
        coins50: Value(coins50),
        coins25: Value(coins25),
        coins10: Value(coins10),
        coins5: Value(coins5),
        coins1Cent: Value(coins1Cent),
        notes: Value(notes),
        isSynced: const Value(true),
        lastSyncDate: Value(DateTime.now()),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.collectionSessionCash).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.collectionSessionCash.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ SessionCash $cashId upserted: type=$cashType, amount=$amount');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling session cash update: $e');
    }
  }
}
