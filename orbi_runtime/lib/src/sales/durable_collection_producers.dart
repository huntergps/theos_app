import 'package:drift/drift.dart' as drift;
import 'package:odoo_sdk/odoo_sdk.dart'
    show OfflinePriority, OfflineReplayPolicy;
import 'package:theos_pos_core/theos_pos_core.dart';

/// Durable producer extracted from the POS collection repositories.
///
/// It only commits local snapshots and generic outbox intents. Replay remains
/// the responsibility of the existing `OfflineQueueDataSource`; no Odoo rule
/// or second schema is introduced here.
final class DurableCollectionProducer {
  const DurableCollectionProducer(this.database, this.queue);

  final AppDatabase database;
  final OfflineQueueDataSource queue;

  Future<DurableCollectionResult> cashOut({
    required String commandId,
    required int sessionId,
    required int journalId,
    required int cashOutTypeId,
    required int amountMinor,
    required String note,
  }) async {
    if (sessionId <= 0 ||
        journalId <= 0 ||
        cashOutTypeId <= 0 ||
        amountMinor <= 0) {
      return const DurableCollectionResult.rejected(
        'Datos de salida inválidos.',
      );
    }
    final uuid = commandId.trim();
    final amount = amountMinor / 100;
    final operationKey = 'l10n_ec.cash.out:create:$uuid';
    final existing = await queue.getOperationsForModel('l10n_ec.cash.out');
    for (final operation in existing) {
      if (operation.operationKey == operationKey) {
        return DurableCollectionResult.queued(operation.recordId ?? 0);
      }
    }
    late final int localId;
    await database.transaction(() async {
      localId = await _nextCashOutId();
      final values = <String, dynamic>{
        'collection_session_id': sessionId,
        // Odoo requires the Many2one. `cash_out_type` is a related readonly
        // selection and must never be used as the create authority.
        'cash_out_type_id': cashOutTypeId,
        'cash_flow': 'out',
        'journal_id': journalId,
        'amount': amount,
        'note': note,
        'uuid': uuid,
        'local_id': localId,
        '_operation_key': operationKey,
      };
      await database
          .into(database.cashOut)
          .insert(
            CashOutCompanion.insert(
              id: drift.Value(localId),
              collectionSessionId: sessionId,
              cashOutType: '',
              cashFlow: const drift.Value('out'),
              journalId: drift.Value(journalId),
              amount: drift.Value(amount),
              note: drift.Value(note),
              cashOutTypeId: drift.Value(cashOutTypeId),
              uuid: drift.Value(uuid),
              state: const drift.Value('draft'),
              isSynced: const drift.Value(false),
            ),
          );
      await queue.queueOperation(
        model: 'l10n_ec.cash.out',
        method: 'create',
        recordId: localId,
        values: values,
        operationKey: values['_operation_key'] as String,
        priority: OfflinePriority.high,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      await queue.queueOperation(
        model: 'l10n_ec.cash.out',
        method: 'action_confirm',
        recordId: localId,
        values: {
          'uuid': uuid,
          'local_id': localId,
          '_operation_key': 'l10n_ec.cash.out:action_confirm:$uuid',
        },
        operationKey: 'l10n_ec.cash.out:action_confirm:$uuid',
        priority: OfflinePriority.high,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
    });
    return DurableCollectionResult.queued(localId);
  }

  Future<DurableCollectionResult> deposit({
    required String commandId,
    required int sessionId,
    required int bankJournalId,
    required String depositType,
    required int amountMinor,
    required String accountingDate,
    required int cashAmountMinor,
    required int checkAmountMinor,
    int checkCount = 0,
  }) async {
    const validDepositTypes = {'cash', 'check', 'mixed'};
    final componentsMatch =
        cashAmountMinor >= 0 &&
        checkAmountMinor >= 0 &&
        cashAmountMinor + checkAmountMinor == amountMinor;
    final typeComponentsMatch = switch (depositType) {
      'cash' => cashAmountMinor == amountMinor && checkAmountMinor == 0,
      'check' => cashAmountMinor == 0 && checkAmountMinor == amountMinor,
      'mixed' => cashAmountMinor > 0 && checkAmountMinor > 0,
      _ => false,
    };
    if (sessionId <= 0 ||
        bankJournalId <= 0 ||
        amountMinor <= 0 ||
        !componentsMatch ||
        !typeComponentsMatch ||
        !validDepositTypes.contains(depositType) ||
        checkCount < 0 ||
        ((checkAmountMinor > 0) && checkCount <= 0) ||
        (checkAmountMinor == 0 && checkCount != 0)) {
      return const DurableCollectionResult.rejected(
        'Datos de depósito inválidos.',
      );
    }
    final uuid = commandId.trim();
    final amount = amountMinor / 100;
    final operationKey = 'collection.session.deposit:create:$uuid';
    final existing = await queue.getOperationsForModel(
      'collection.session.deposit',
    );
    for (final operation in existing) {
      if (operation.operationKey == operationKey) {
        return DurableCollectionResult.queued(operation.recordId ?? 0);
      }
    }
    late final int localId;
    await database.transaction(() async {
      localId = await _nextDepositId();
      final values = <String, dynamic>{
        'collection_session_id': sessionId,
        'deposit_type': depositType,
        'amount': amount,
        'cash_amount': cashAmountMinor / 100,
        'check_amount': checkAmountMinor / 100,
        // Odoo constrains check_amount > 0 to check_count > 0.
        'check_count': checkCount,
        'bank_journal_id': bankJournalId,
        'accounting_date': accountingDate,
        'deposit_uuid': uuid,
        'local_id': localId,
        '_operation_key': operationKey,
      };
      await database
          .into(database.collectionSessionDeposit)
          .insert(
            CollectionSessionDepositCompanion.insert(
              id: drift.Value(localId),
              uuid: drift.Value(uuid),
              collectionSessionId: sessionId,
              depositType: depositType,
              amount: drift.Value(amount),
              depositDate:
                  DateTime.tryParse(accountingDate) ?? DateTime.now().toUtc(),
              accountingDate: drift.Value(DateTime.tryParse(accountingDate)),
              cashAmount: drift.Value(
                (values['cash_amount'] as num).toDouble(),
              ),
              checkAmount: drift.Value(
                (values['check_amount'] as num).toDouble(),
              ),
              checkCount: drift.Value(checkCount),
              bankJournalId: drift.Value(bankJournalId),
              state: const drift.Value('draft'),
              isSynced: const drift.Value(false),
            ),
          );
      await queue.queueOperation(
        model: 'collection.session.deposit',
        method: 'create',
        recordId: localId,
        values: values,
        operationKey: values['_operation_key'] as String,
        priority: OfflinePriority.high,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      final accountingKey =
          'collection.session.deposit:action_create_accounting_entry:$uuid';
      await queue.queueOperation(
        model: 'collection.session.deposit',
        method: 'action_create_accounting_entry',
        recordId: localId,
        values: {
          'deposit_uuid': uuid,
          'local_id': localId,
          'dependsOn': [operationKey],
          '_operation_key': accountingKey,
        },
        operationKey: accountingKey,
        priority: OfflinePriority.high,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
    });
    return DurableCollectionResult.queued(localId);
  }

  /// Creates and posts a customer advance using the native account.advance
  /// contract already used by the POS.  The header, official advance lines,
  /// create intent and action_post intent are committed atomically so a
  /// process restart cannot expose a local advance without replay metadata.
  Future<DurableCollectionResult> createAndPostAdvance({
    required String commandId,
    required int partnerId,
    required String reference,
    required int journalId,
    required int amountMinor,
    int? collectionSessionId,
  }) async {
    final uuid = commandId.trim();
    if (uuid.isEmpty ||
        partnerId <= 0 ||
        journalId <= 0 ||
        amountMinor <= 0 ||
        reference.trim().length < 30) {
      return const DurableCollectionResult.rejected(
        'Los datos del anticipo no cumplen el contrato de Odoo.',
      );
    }
    final createKey = 'account.advance:create:$uuid';
    final postKey = 'account.advance:action_post:$uuid';
    final existing = await queue.getOperationsForModel('account.advance');
    if (existing.any(
      (op) => op.operationKey == createKey || op.operationKey == postKey,
    )) {
      final prior = existing.firstWhere(
        (op) => op.operationKey == createKey || op.operationKey == postKey,
      );
      return DurableCollectionResult.queued(prior.recordId ?? 0);
    }
    late final int localId;
    final amount = amountMinor / 100;
    await database.transaction(() async {
      localId = await _nextAdvanceId();
      final lineOdooId = await _nextAdvanceLineOdooId();
      final date = DateTime.now().toUtc();
      final lineValues = <String, dynamic>{
        'journal_id': journalId,
        'amount': amount,
      };
      final values = <String, dynamic>{
        'date': date.toIso8601String().split('T').first,
        'advance_type': 'inbound',
        'partner_id': partnerId,
        'reference': reference.trim(),
        'amount': amount,
        'amount_available': amount,
        'collection_session_id': collectionSessionId,
        'external_id': uuid,
        'advance_line_ids': <dynamic>[
          [0, 0, lineValues],
        ],
        'local_id': localId,
        '_operation_key': createKey,
      };
      await database
          .into(database.accountAdvance)
          .insert(
            AccountAdvanceCompanion.insert(
              odooId: localId,
              state: const drift.Value('draft'),
              advanceType: 'inbound',
              partnerId: partnerId,
              reference: drift.Value(reference.trim()),
              date: date,
              amount: drift.Value(amount),
              amountAvailable: drift.Value(amount),
              advanceUuid: drift.Value(uuid),
              collectionSessionId: drift.Value(collectionSessionId),
            ),
          );
      await database
          .into(database.advanceLinesTable)
          .insert(
            AdvanceLinesTableCompanion.insert(
              odooId: lineOdooId,
              advanceId: drift.Value(localId),
              lineUuid: drift.Value('$uuid:line'),
              journalId: journalId,
              amount: drift.Value(amount),
            ),
          );
      await queue.queueOperation(
        model: 'account.advance',
        method: 'create',
        recordId: localId,
        values: values,
        operationKey: createKey,
        priority: OfflinePriority.high,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      await queue.queueOperation(
        model: 'account.advance',
        method: 'action_post',
        recordId: localId,
        values: {
          'external_id': uuid,
          'local_id': localId,
          'dependsOn': [createKey],
          '_operation_key': postKey,
        },
        operationKey: postKey,
        priority: OfflinePriority.high,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      await (database.update(database.accountAdvance)
            ..where((table) => table.odooId.equals(localId)))
          .write(const AccountAdvanceCompanion(state: drift.Value('posted')));
    });
    return DurableCollectionResult.queued(localId);
  }

  /// Persists the exact payment/withhold rows used by the cashier and queues
  /// only their local IDs. The financial facts therefore have one local home
  /// (`sale_order_payment_line` / `sale_order_withhold_line`) while the
  /// outbox remains a replay intent, not a second ledger.
  Future<DurableCollectionResult> enqueueCollectionIntent({
    required String commandId,
    required int saleOrderId,
    required String method,
    required int amountMinor,
    required List<DurablePaymentLineDraft> paymentLines,
    List<DurableWithholdLineDraft> withholdLines = const [],
    int? wizardId,
    int? collectionSessionId,
    bool numberedByClient = false,
    int? sequential,
    String? emissionDate,
    String? accessKey,
    String? scopeKey,
  }) async {
    final uuid = commandId.trim();
    if (uuid.isEmpty ||
        saleOrderId <= 0 ||
        amountMinor <= 0 ||
        (method != 'cashInvoice' && method != 'existingInvoice') ||
        paymentLines.isEmpty ||
        paymentLines.any((line) => !line.isValid) ||
        withholdLines.any((line) => !line.isValid)) {
      return const DurableCollectionResult.rejected(
        'Las líneas del cobro no cumplen el contrato local.',
      );
    }
    final operationKey = uuid;
    final existing = await queue.getOperationsForModel(
      method == 'cashInvoice'
          ? 'sale.order'
          : 'l10n_ec_collection_box.sale.order.payment.wizard',
    );
    final prior = existing.where((op) => op.operationKey == operationKey);
    if (prior.isNotEmpty) {
      return DurableCollectionResult.queued(
        prior.first.recordId ?? saleOrderId,
      );
    }
    // The outbox row is removed after a successful replay. The native line
    // UUID remains the durable idempotency marker for a later double tap.
    final priorLines = await (database.select(
      database.saleOrderPaymentLine,
    )..where((table) => table.lineUuid.like('$uuid:payment:%'))).get();
    if (priorLines.isNotEmpty) {
      if (priorLines.length != paymentLines.length) {
        return const DurableCollectionResult.rejected(
          'El comando de cobro ya existe con líneas distintas.',
        );
      }
      return DurableCollectionResult.queued(priorLines.first.id);
    }
    late final int operationId;
    await database.transaction(() async {
      final paymentIds = <int>[];
      for (var index = 0; index < paymentLines.length; index++) {
        final line = paymentLines[index];
        final journalId = line.journalId;
        final lineUuid = '$uuid:payment:$index';
        final id = await database
            .into(database.saleOrderPaymentLine)
            .insert(
              SaleOrderPaymentLineCompanion.insert(
                lineUuid: drift.Value(lineUuid),
                uuid: drift.Value(lineUuid),
                type: drift.Value(line.type),
                orderId: saleOrderId,
                journalId: drift.Value(
                  journalId != null && journalId > 0 ? journalId : null,
                ),
                paymentMethodLineId: drift.Value(line.paymentMethodLineId),
                amount: drift.Value(line.amountMinor / 100),
                paymentReference: drift.Value(line.paymentReference),
                date: drift.Value(
                  line.date == null
                      ? DateTime.now().toUtc()
                      : DateTime.tryParse(line.date!) ?? DateTime.now().toUtc(),
                ),
                creditNoteId: drift.Value(line.creditNoteId),
                advanceId: drift.Value(line.advanceId),
                state: const drift.Value('draft'),
                isSynced: const drift.Value(false),
              ),
            );
        paymentIds.add(id);
      }
      final withholdIds = <int>[];
      final withholdOperationKeys = <String>[];
      for (final line in withholdLines) {
        final id = await database
            .into(database.saleOrderWithholdLine)
            .insert(
              SaleOrderWithholdLineCompanion.insert(
                lineUuid: drift.Value(line.uuid),
                orderId: saleOrderId,
                taxId: line.taxId,
                taxName: line.taxName ?? '',
                withholdType: line.withholdType ?? 'withhold_income_sale',
                base: drift.Value(line.baseMinor / 100),
                amount: drift.Value(line.amountMinor / 100),
                taxsupportCode: drift.Value(line.taxsupportCode),
                notes: drift.Value(line.notes),
                isSynced: const drift.Value(false),
              ),
            );
        withholdIds.add(id);
        final withholdOperationKey = '$uuid:withhold:${line.uuid}';
        withholdOperationKeys.add(withholdOperationKey);
        await queue.queueOperation(
          model: 'sale.order.withhold.line',
          method: 'create',
          recordId: id,
          parentOrderId: saleOrderId,
          values: {
            'withholdLineId': id,
            'local_id': id,
            'sale_id': saleOrderId,
            'uuid': line.uuid,
            '_operation_key': withholdOperationKey,
          },
          operationKey: withholdOperationKey,
          // The parent wizard is high priority. Critical lines must replay
          // first; the adapter still checks their local synced/remote IDs
          // before it can apply the wizard.
          priority: OfflinePriority.critical,
          replayPolicy: OfflineReplayPolicy.retrySafe,
        );
      }
      final values = <String, dynamic>{
        'commandId': uuid,
        'scopeKey': scopeKey,
        'saleOrderRemoteId': saleOrderId,
        'amountMinor': amountMinor,
        'paymentLineIds': paymentIds,
        'withholdLineIds': withholdIds,
        'dependsOn': withholdOperationKeys,
        ...?_presentValue('wizardId', wizardId),
        ...?_presentValue('collectionSessionId', collectionSessionId),
        if (method == 'cashInvoice') ...{
          'numberedByClient': numberedByClient,
          if (numberedByClient) ...{
            'sequential': sequential,
            'emissionDate': emissionDate,
            'accessKey': accessKey,
          },
        },
        '_operation_key': operationKey,
      };
      operationId = await queue.queueOperation(
        model: method == 'cashInvoice'
            ? 'sale.order'
            : 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: method,
        recordId: wizardId ?? saleOrderId,
        values: values,
        operationKey: operationKey,
        priority: OfflinePriority.high,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
    });
    return DurableCollectionResult.queued(operationId);
  }

  /// Persists the existing POS closing-count record and the two native
  /// session transitions in one transaction. The outbox dependencies enforce
  /// count → closing-control → close on replay; no parallel financial table or
  /// synthetic session state is introduced.
  ///
  /// `hasCollectionSupervisor` gates the THIRD step. `action_session_close`
  /// (`l10n_ec_collection_box/models/collection_session.py:3211-3219`) raises
  /// `UserError('Solo los supervisores pueden cerrar sesiones.')` for anyone
  /// outside `group_collection_manager` — even the cashier closing HER OWN
  /// turn. Before this gate, a plain cashier's device queued `session_close`
  /// unconditionally with `OfflineReplayPolicy.retrySafe`
  /// (`_dispatch`, below): it retried against that same rejection on every
  /// sync pass until `OfflineQueueDataSource.markOperationFailed` exhausted
  /// its 10 attempts and the operation died in `dead_letter`, never having
  /// done anything. A cashier without the permission now queues only the
  /// count and `session_closing_control` — which Odoo lets her run on her
  /// own turn — and the turn stops there, in `closing_control`, exactly
  /// where the real workflow expects a supervisor to pick it up (validate it
  /// from the turn's own screen, `collection.session.py:2613-2658`).
  Future<DurableCollectionShiftResult> closeWithCount({
    required String commandId,
    required int sessionId,
    required DurableCashCount count,
    required bool hasCollectionSupervisor,
  }) async {
    final uuid = commandId.trim();
    if (uuid.isEmpty || sessionId <= 0 || !count.isValid) {
      return const DurableCollectionShiftResult.rejected(
        'El conteo de cierre no es válido.',
      );
    }
    final cashCreateKey = 'collection.session.cash:create:$uuid';
    final closingKey = 'collection.session:closing_control:$uuid';
    final closeKey = 'collection.session:close:$uuid';
    final existing = await queue.getOperationsForModel(
      'collection.session.cash',
    );
    final prior = existing.where(
      (operation) => operation.operationKey == cashCreateKey,
    );
    if (prior.isNotEmpty) {
      return DurableCollectionShiftResult.queued(
        count.cashTotalMinor,
        count.expectedDifferenceMinor,
        message: _closeQueuedMessage(hasCollectionSupervisor),
      );
    }
    final localCounts =
        await (database.select(database.collectionSessionCash)..where(
              (table) =>
                  table.collectionSessionId.equals(sessionId) &
                  table.cashType.equals('closing'),
            ))
            .get();
    if (localCounts.isNotEmpty) {
      final local = localCounts.last;
      if (_cashCountMatches(local, count)) {
        return DurableCollectionShiftResult.queued(
          count.cashTotalMinor,
          count.expectedDifferenceMinor,
          message: _closeQueuedMessage(hasCollectionSupervisor),
        );
      }
      return const DurableCollectionShiftResult.rejected(
        'Ya existe un conteo de cierre distinto para este turno.',
      );
    }
    final amount = count.cashTotalMinor / 100;
    late final int localCashId;
    await database.transaction(() async {
      localCashId = await _nextSessionCashId();
      final values = <String, dynamic>{
        'collection_session_id': sessionId,
        'cash_type': 'closing',
        'bills_100': count.bills100,
        'bills_50': count.bills50,
        'bills_20': count.bills20,
        'bills_10': count.bills10,
        'bills_5': count.bills5,
        'bills_1': count.bills1,
        'coins_1': count.coins1,
        'coins_50': count.coins50,
        'coins_25': count.coins25,
        'coins_10': count.coins10,
        'coins_5': count.coins5,
        'coins_1_cent': count.coins1Cent,
        if (count.notes != null) 'notes': count.notes,
        'local_id': localCashId,
        'command_id': uuid,
        '_operation_key': cashCreateKey,
      };
      await database
          .into(database.collectionSessionCash)
          .insert(
            CollectionSessionCashCompanion.insert(
              id: drift.Value(localCashId),
              odooId: localCashId,
              collectionSessionId: sessionId,
              cashType: 'closing',
              bills100: drift.Value(count.bills100),
              bills50: drift.Value(count.bills50),
              bills20: drift.Value(count.bills20),
              bills10: drift.Value(count.bills10),
              bills5: drift.Value(count.bills5),
              bills1: drift.Value(count.bills1),
              coins1: drift.Value(count.coins1),
              coins50: drift.Value(count.coins50),
              coins25: drift.Value(count.coins25),
              coins10: drift.Value(count.coins10),
              coins5: drift.Value(count.coins5),
              coins1Cent: drift.Value(count.coins1Cent),
              notes: drift.Value(count.notes),
              isSynced: const drift.Value(false),
            ),
          );
      await queue.queueOperation(
        model: 'collection.session.cash',
        method: 'create',
        recordId: localCashId,
        values: values,
        operationKey: cashCreateKey,
        priority: OfflinePriority.critical,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      final closeValues = <String, dynamic>{
        'session_id': sessionId,
        'cash_register_balance_end_real': amount,
        'command_id': uuid,
        'dependsOn': [cashCreateKey],
      };
      await queue.queueOperation(
        model: 'collection.session',
        method: 'session_closing_control',
        recordId: sessionId,
        values: closeValues,
        operationKey: closingKey,
        priority: OfflinePriority.critical,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      // Sólo se encola el tercer paso — `action_session_close` — cuando ESTE
      // dispositivo se autentica como alguien de `group_collection_manager`.
      // Ver el docstring del método: sin el permiso, Odoo rechaza esta
      // llamada aunque sea el propio turno de quien la hace, y encolarla
      // igual sólo fabrica una operación condenada a `dead_letter`.
      if (hasCollectionSupervisor) {
        await queue.queueOperation(
          model: 'collection.session',
          method: 'session_close',
          recordId: sessionId,
          values: {
            'session_id': sessionId,
            'command_id': uuid,
            'dependsOn': [closingKey],
          },
          operationKey: closeKey,
          priority: OfflinePriority.critical,
          replayPolicy: OfflineReplayPolicy.retrySafe,
        );
      }
      await (database.update(
        database.collectionSession,
      )..where((table) => table.odooId.equals(sessionId))).write(
        CollectionSessionCompanion(
          state: const drift.Value('closing_control'),
          cashRegisterBalanceEndReal: drift.Value(amount),
          cashRegisterDifference: drift.Value(
            count.expectedDifferenceMinor / 100,
          ),
          isSynced: const drift.Value(false),
        ),
      );
    });
    return DurableCollectionShiftResult.queued(
      count.cashTotalMinor,
      count.expectedDifferenceMinor,
      message: _closeQueuedMessage(hasCollectionSupervisor),
    );
  }

  static String _closeQueuedMessage(bool hasCollectionSupervisor) =>
      hasCollectionSupervisor
      ? 'Conteo guardado; cierre pendiente de sincronización.'
      : 'Conteo guardado. El turno queda en Control de Cierre: un '
            'supervisor debe validarlo para cerrarlo.';

  Future<int> _nextCashOutId() async {
    final rows = await database.select(database.cashOut).get();
    final minimum = rows.fold<int>(
      0,
      (value, row) => row.id < value ? row.id : value,
    );
    return minimum < 0 ? minimum - 1 : -1;
  }

  Future<int> _nextDepositId() async {
    final rows = await database.select(database.collectionSessionDeposit).get();
    final minimum = rows.fold<int>(
      0,
      (value, row) => row.id < value ? row.id : value,
    );
    return minimum < 0 ? minimum - 1 : -1;
  }

  Future<int> _nextSessionCashId() async {
    final rows = await database.select(database.collectionSessionCash).get();
    final minimum = rows.fold<int>(
      0,
      (value, row) => row.id < value ? row.id : value,
    );
    return minimum < 0 ? minimum - 1 : -1;
  }

  Future<int> _nextAdvanceId() async {
    final rows = await database.select(database.accountAdvance).get();
    final minimum = rows.fold<int>(
      0,
      (value, row) => row.odooId < value ? row.odooId : value,
    );
    return minimum < 0 ? minimum - 1 : -1;
  }

  Future<int> _nextAdvanceLineOdooId() async {
    final rows = await database.select(database.advanceLinesTable).get();
    final minimum = rows.fold<int>(
      0,
      (value, row) => row.odooId < value ? row.odooId : value,
    );
    return minimum < 0 ? minimum - 1 : -1;
  }

  static bool _cashCountMatches(
    CollectionSessionCashData row,
    DurableCashCount count,
  ) =>
      row.bills100 == count.bills100 &&
      row.bills50 == count.bills50 &&
      row.bills20 == count.bills20 &&
      row.bills10 == count.bills10 &&
      row.bills5 == count.bills5 &&
      row.bills1 == count.bills1 &&
      row.coins1 == count.coins1 &&
      row.coins50 == count.coins50 &&
      row.coins25 == count.coins25 &&
      row.coins10 == count.coins10 &&
      row.coins5 == count.coins5 &&
      row.coins1Cent == count.coins1Cent &&
      row.notes == count.notes;
}

/// Denomination counts from the existing collection.session.cash model.
/// Amounts are derived, never entered independently, so replay cannot carry
/// an inconsistent total.
final class DurableCashCount {
  const DurableCashCount({
    this.bills100 = 0,
    this.bills50 = 0,
    this.bills20 = 0,
    this.bills10 = 0,
    this.bills5 = 0,
    this.bills1 = 0,
    this.coins1 = 0,
    this.coins50 = 0,
    this.coins25 = 0,
    this.coins10 = 0,
    this.coins5 = 0,
    this.coins1Cent = 0,
    this.notes,
    this.expectedBalanceMinor = 0,
  });
  final int bills100;
  final int bills50;
  final int bills20;
  final int bills10;
  final int bills5;
  final int bills1;
  final int coins1;
  final int coins50;
  final int coins25;
  final int coins10;
  final int coins5;
  final int coins1Cent;
  final String? notes;
  final int expectedBalanceMinor;

  bool get isValid => [
    bills100,
    bills50,
    bills20,
    bills10,
    bills5,
    bills1,
    coins1,
    coins50,
    coins25,
    coins10,
    coins5,
    coins1Cent,
    expectedBalanceMinor,
  ].every((value) => value >= 0);

  int get cashTotalMinor =>
      bills100 * 10000 +
      bills50 * 5000 +
      bills20 * 2000 +
      bills10 * 1000 +
      bills5 * 500 +
      bills1 * 100 +
      coins1 * 100 +
      coins50 * 50 +
      coins25 * 25 +
      coins10 * 10 +
      coins5 * 5 +
      coins1Cent;

  int get expectedDifferenceMinor => cashTotalMinor - expectedBalanceMinor;
}

final class DurableCollectionShiftResult {
  const DurableCollectionShiftResult._(
    this.state,
    this.cashTotalMinor,
    this.differenceMinor,
    this.message,
  );
  const DurableCollectionShiftResult.queued(
    int cashTotalMinor,
    int differenceMinor, {
    String message = 'Conteo guardado; cierre pendiente de sincronización.',
  }) : this._(DurableCollectionState.queued, cashTotalMinor, differenceMinor, message);
  const DurableCollectionShiftResult.rejected(String message)
    : this._(DurableCollectionState.rejected, null, null, message);
  final DurableCollectionState state;
  final int? cashTotalMinor;
  final int? differenceMinor;
  final String message;
}

final class DurableCollectionResult {
  const DurableCollectionResult._(this.state, this.localId, this.message);
  const DurableCollectionResult.queued(int id)
    : this._(
        DurableCollectionState.queued,
        id,
        'Operación guardada para sincronización.',
      );
  const DurableCollectionResult.rejected(String message)
    : this._(DurableCollectionState.rejected, null, message);
  final DurableCollectionState state;
  final int? localId;
  final String message;
}

enum DurableCollectionState { queued, rejected }

final class DurablePaymentLineDraft {
  const DurablePaymentLineDraft({
    required this.type,
    required this.amountMinor,
    this.journalId,
    this.paymentMethodLineId,
    this.advanceId,
    this.creditNoteId,
    this.date,
    this.paymentReference,
  });
  final String type;
  final int amountMinor;
  final int? journalId;
  final int? paymentMethodLineId;
  final int? advanceId;
  final int? creditNoteId;
  final String? date;
  final String? paymentReference;

  bool get isValid {
    if (amountMinor <= 0) return false;
    if (type == 'payment') return (journalId ?? 0) > 0;
    if (type == 'advance') return (advanceId ?? 0) > 0;
    if (type == 'credit_note') return (creditNoteId ?? 0) > 0;
    return false;
  }
}

final class DurableWithholdLineDraft {
  const DurableWithholdLineDraft({
    required this.uuid,
    required this.taxId,
    required this.baseMinor,
    required this.amountMinor,
    this.taxName,
    this.withholdType,
    this.taxsupportCode,
    this.notes,
  });
  final String uuid;
  final int taxId;
  final int baseMinor;
  final int amountMinor;
  final String? taxName;
  final String? withholdType;
  final String? taxsupportCode;
  final String? notes;

  bool get isValid =>
      uuid.trim().isNotEmpty && taxId > 0 && baseMinor > 0 && amountMinor > 0;
}

Map<String, dynamic>? _presentValue(String key, dynamic value) =>
    value == null ? null : {key: value};
