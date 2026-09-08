import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:odoo_sdk/odoo_sdk.dart' show ConflictInfo;
import 'package:theos_pos_core/theos_pos_core.dart';

import '../contracts.dart';
import '../sync/operations_sync_job.dart';

/// Local transaction boundary for confirmation. The unique offline_queue
/// operationKey is checked and written in the same Drift transaction as the
/// local order state update; a crash rolls both back.
final class DriftSaleCommandStore implements SaleCommandStore {
  final AppDatabase db;
  final SaleLocalOrderResolver resolver;
  const DriftSaleCommandStore(this.db, this.resolver);

  @override
  Future<OperationOutcome<SaleOrderState>> commitAndEnqueueIfAbsent({
    required String commandId,
    required EntityReference entity,
    required int expectedVersion,
    required OperationOutcome<SaleOrderState> outcome,
  }) async {
    return db.transaction(() async {
      final resolved = await resolver.resolve(entity);
      if (resolved.version != expectedVersion) {
        throw StateError(
          'sale version conflict: expected $expectedVersion, got ${resolved.version}',
        );
      }
      final prior = await (db.select(
        db.offlineQueue,
      )..where((t) => t.operationKey.equals(commandId))).getSingleOrNull();
      if (prior != null) {
        final values = jsonDecode(prior.values);
        if (prior.model != 'sale.order' ||
            prior.method != 'action_pos_confirm' ||
            prior.recordId != resolved.localId ||
            values is! Map ||
            values['expectedVersion'] != expectedVersion) {
          throw StateError('commandId collision with different sale operation');
        }
        return OperationOutcome(
          commandId: commandId,
          entity: entity,
          businessState: SaleOrderState.sale,
          syncState: prior.status == 'completed'
              ? OperationSyncState.synced
              : OperationSyncState.queued,
        );
      }
      final localId = resolved.localId;
      {
        final changed =
            await (db.update(db.saleOrder)..where((t) => t.id.equals(localId)))
                .write(const SaleOrderCompanion(state: drift.Value('sale')));
        if (changed == 0) {
          throw StateError('sale order not found: ${entity.localId}');
        }
      }
      final create =
          await (db.select(db.offlineQueue)..where(
                (t) =>
                    t.model.equals('sale.order') &
                    t.recordId.equals(localId) &
                    t.method.equals('create'),
              ))
              .getSingleOrNull();
      final dependencies = <String>[];
      if (create != null) {
        dependencies.add(create.operationKey ?? '$commandId:create');
        final createValues = jsonDecode(create.values);
        final lineUuids = createValues is Map
            ? createValues['lineUuids']
            : null;
        if (lineUuids is List) {
          for (final lineUuid in lineUuids.whereType<String>()) {
            dependencies.add('${createValues['orderUuid']}:line:$lineUuid');
          }
        }
      }
      if (dependencies.isEmpty && entity.remoteId == null) {
        dependencies.add('$commandId:create');
      }
      await db
          .into(db.offlineQueue)
          .insert(
            OfflineQueueCompanion.insert(
              operation: const drift.Value('write'),
              model: 'sale.order',
              method: const drift.Value('action_pos_confirm'),
              recordId: drift.Value(localId),
              values: jsonEncode({
                'commandId': commandId,
                'expectedVersion': expectedVersion,
                if (dependencies.isNotEmpty) 'dependsOn': dependencies,
              }),
              createdAt: DateTime.now().toUtc(),
              operationKey: drift.Value(commandId),
              replayPolicy: const drift.Value('manual_after_ambiguous'),
            ),
          );
      return outcome;
    });
  }
}

final class SaleLocalOrderResolution {
  final int localId;
  final int version;
  const SaleLocalOrderResolution({
    required this.localId,
    required this.version,
  });
}

abstract interface class SaleLocalOrderResolver {
  Future<SaleLocalOrderResolution> resolve(EntityReference reference);
}

/// Exact Odoo JSON-2 boundary for the existing custom actions. The caller
/// supplies ids and kwargs; no addon endpoint or duplicate payment model is
/// introduced here.
abstract interface class SaleOdooActions {
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  });
}

abstract interface class ContextualSaleOdooActions implements SaleOdooActions {
  Future<dynamic> callWithContext({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
  });
}

/// Payment payload deliberately uses minor units; no binary floating point is
/// transported across the runtime/Odoo boundary.
final class SalePaymentLinePayload {
  final int journalId;
  final int amountMinor;
  final int currencyDigits;
  final String? date;
  final String? paymentReference;
  final int? cardBrandId;
  final int? cardDeadlineId;
  final int? loteId;

  /// Official wizard discriminator.  `payment` is retained for the existing
  /// direct POS action; advance/creditNote are sent through the native wizard.
  final String type;
  final int? advanceId;
  final int? creditNoteId;
  final int? paymentMethodLineId;
  const SalePaymentLinePayload({
    required this.journalId,
    required this.amountMinor,
    this.currencyDigits = 2,
    this.date,
    this.paymentReference,
    this.cardBrandId,
    this.cardDeadlineId,
    this.loteId,
    this.type = 'payment',
    this.advanceId,
    this.creditNoteId,
    this.paymentMethodLineId,
  });
  Map<String, dynamic> toOdoo() => {
    'line_type': type,
    if (type == 'payment' && journalId > 0) 'journal_id': journalId,
    'amount': amountMinor / math.pow(10, currencyDigits),
    ...?_present('advance_id', advanceId),
    ...?_present('credit_note_id', creditNoteId),
    ...?_present('payment_method_line_id', paymentMethodLineId),
    ...?_present('date', date),
    ...?_present('payment_reference', paymentReference),
    ...?_present('card_brand_id', cardBrandId),
    ...?_present('card_deadline_id', cardDeadlineId),
    ...?_present('lote_id', loteId),
  };
}

final class OdooSaleCollectionPort {
  final SaleOdooActions actions;
  const OdooSaleCollectionPort(this.actions);

  Future<OperationOutcome<SaleOrderState>> collectExistingInvoice({
    required EntityReference order,
    required String commandId,
    required int wizardId,
    List<SalePaymentLinePayload> paymentLines = const [],
  }) async {
    if (paymentLines.isNotEmpty) {
      final writeResult = await actions.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'write',
        ids: [wizardId],
        kwargs: {
          'vals': {
            'pos_client_op_uuid': commandId,
            'line_ids': [
              [5, 0, 0],
              for (final line in paymentLines) [0, 0, line.toOdoo()],
            ],
          },
        },
      );
      if (_rejected(writeResult)) {
        return OperationOutcome(
          commandId: commandId,
          entity: order,
          businessState: SaleOrderState.sale,
          syncState: OperationSyncState.conflict,
          issues: [
            OperationIssue(
              code: 'invoice_collection_rejected',
              messageKey: 'sale.invoice_collection_rejected',
              retryable: true,
            ),
          ],
        );
      }
    }
    final result = await actions.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'action_apply',
      ids: [wizardId],
    );
    if (_rejected(result)) {
      return OperationOutcome(
        commandId: commandId,
        entity: order,
        businessState: SaleOrderState.sale,
        syncState: OperationSyncState.conflict,
        issues: [
          OperationIssue(
            code: 'invoice_collection_rejected',
            messageKey: 'sale.invoice_collection_rejected',
            retryable: true,
          ),
        ],
      );
    }
    final explicitInvoice =
        result is Map &&
        result['res_model'] == 'account.move' &&
        _positiveIntValue(result['res_id']) != null;
    if (!explicitInvoice && !await _existingPaymentApplied(commandId)) {
      return OperationOutcome(
        commandId: commandId,
        entity: order,
        businessState: SaleOrderState.sale,
        syncState: OperationSyncState.conflict,
        issues: [
          OperationIssue(
            code: 'invoice_collection_ambiguous',
            messageKey: 'sale.invoice_collection_ambiguous',
            retryable: true,
          ),
        ],
      );
    }
    return OperationOutcome(
      commandId: commandId,
      entity: order,
      businessState: SaleOrderState.sale,
      syncState: OperationSyncState.synced,
    );
  }

  Future<bool> _existingPaymentApplied(String commandId) async {
    final rows = await actions.call(
      model: 'l10n_ec_collection_box.sale.order.payment',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['pos_collection_op_uuid', '=', commandId],
        ],
        'fields': ['id', 'state', 'move_id'],
        'limit': 100,
      },
    );
    if (rows is! List || rows.isEmpty || rows.any((row) => row is! Map)) {
      return false;
    }
    return rows.every((row) {
      final value = Map<String, dynamic>.from(row as Map);
      final move = value['move_id'];
      return value['state'] == 'posted' && move is List && move.isNotEmpty;
    });
  }

  Future<OperationOutcome<SaleOrderState>> confirmAndInvoice({
    required EntityReference order,
    required String commandId,
    required List<SalePaymentLinePayload> paymentLines,
    int? collectionSessionId,
    int? sequential,
    String? emissionDate,
    String? accessKey,
    bool numberedByClient = false,
  }) async {
    final id = order.remoteId;
    if (id == null) throw ArgumentError('remoteId required');
    if (numberedByClient) {
      final fiscal = OfflineFiscalInvoicePayload(
        sequential: sequential,
        emissionDate: emissionDate,
        accessKey: accessKey,
      );
      if (!fiscal.isComplete) {
        return OperationOutcome(
          commandId: commandId,
          entity: order,
          businessState: SaleOrderState.sale,
          syncState: OperationSyncState.conflict,
          issues: [
            OperationIssue(
              code: 'offline_fiscal_identity_missing',
              messageKey: 'sale.offline_fiscal_identity_missing',
              retryable: false,
            ),
          ],
        );
      }
    }
    final typed = paymentLines.any((line) => line.type != 'payment');
    final result = typed
        ? await _applyNativePaymentWizard(
            saleId: id,
            commandId: commandId,
            paymentLines: paymentLines,
            collectionSessionId: collectionSessionId,
          )
        : await actions.call(
            model: 'sale.order',
            method: 'action_pos_confirm_and_invoice',
            ids: [id],
            kwargs: {
              'payment_lines': paymentLines
                  .map((line) => line.toOdoo())
                  .toList(),
              ...?_present('collection_session_id', collectionSessionId),
              ...?_present('sequential', sequential),
              ...?_present('emission_date', emissionDate),
              ...?_present('access_key', accessKey),
              'client_op_uuid': commandId,
            },
          );
    if (_rejected(result)) {
      final approval = result is Map && result['approval_required'] == true;
      return OperationOutcome(
        commandId: commandId,
        entity: order,
        businessState: SaleOrderState.approved,
        syncState: approval
            ? OperationSyncState.conflict
            : OperationSyncState.failed,
        pendingAction: approval
            ? PendingAction(type: PendingActionType.approval, entity: order)
            : null,
        issues: [
          OperationIssue(
            code: approval ? 'approval_required' : 'collection_rejected',
            messageKey: 'sale.collection.rejected',
            retryable: !approval,
          ),
        ],
      );
    }
    return OperationOutcome(
      commandId: commandId,
      entity: order,
      businessState: SaleOrderState.sale,
      syncState: OperationSyncState.synced,
      // Invoice/payment completion is not SRI authorization. EDI state must
      // be read separately before exposing a fiscal state.
      fiscalState: null,
    );
  }

  Future<dynamic> _applyNativePaymentWizard({
    required int saleId,
    required String commandId,
    required List<SalePaymentLinePayload> paymentLines,
    int? collectionSessionId,
  }) async {
    final wizard = await actions.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'sale_id': saleId,
            ...?_present('collection_session_id', collectionSessionId),
            'pos_client_op_uuid': commandId,
            'line_ids': [
              for (final line in paymentLines) [0, 0, line.toOdoo()],
            ],
          },
        ],
      },
    );
    final wizardId = _createdIdValue(wizard);
    if (wizardId == null) {
      throw StateError('payment wizard create returned no id');
    }
    return actions.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'action_apply_and_create_invoice',
      ids: [wizardId],
    );
  }
}

final class OdooCollectionReconciliationPort
    implements CollectionReconciliationPort {
  final SaleOdooActions actions;
  const OdooCollectionReconciliationPort(this.actions);
  @override
  Future<OperationOutcome<SaleOrderState>?> findByCommandOrReference({
    required EntityReference order,
    required String commandId,
    int? expectedAmountMinor,
  }) async {
    // An existing-invoice collection is a partial payment by design. Its
    // pending invoice amount is not the payment amount. Reconcile it only
    // from the native payment lines created by the wizard, never from the
    // invoice's final residual/total.
    if (expectedAmountMinor == null) return null;
    final result = await actions.call(
      model: 'account.move',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['l10n_ec_pos_client_op_uuid', '=', commandId],
          ['move_type', '=', 'out_invoice'],
          ['state', '!=', 'cancel'],
        ],
        'fields': [
          'id',
          'state',
          'payment_state',
          'amount_total',
          'l10n_ec_pos_collection_completed',
        ],
        'limit': 2,
      },
    );
    if (result is List && result.length == 1 && result.first is Map) {
      final row = Map<String, dynamic>.from(result.first as Map);
      if (row['l10n_ec_pos_collection_completed'] != true ||
          row['payment_state'] != 'paid' ||
          row['state'] != 'posted' ||
          !_amountMatches(row['amount_total'], expectedAmountMinor)) {
        return null;
      }
      return OperationOutcome(
        commandId: commandId,
        entity: order,
        businessState: SaleOrderState.sale,
        syncState: OperationSyncState.synced,
        fiscalState: null,
      );
    }
    return null;
  }

  static bool _amountMatches(dynamic raw, int expectedMinor) {
    if (raw is! num || !raw.isFinite || expectedMinor <= 0) return false;
    return (raw * 100).round() == expectedMinor;
  }
}

int? _createdIdValue(dynamic result) {
  if (result is num && result.toInt() > 0) return result.toInt();
  if (result is List && result.length == 1) {
    return _createdIdValue(result.first);
  }
  if (result is Map) {
    return _createdIdValue(result['id'] ?? result['result']);
  }
  return null;
}

int? _positiveIntValue(dynamic value) {
  return value is num && value.toInt() > 0 ? value.toInt() : null;
}

final class OdooClientSaleActions implements ContextualSaleOdooActions {
  final OdooClient client;
  const OdooClientSaleActions(this.client);
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) => client.call(model: model, method: method, ids: ids, kwargs: kwargs);

  @override
  Future<dynamic> callWithContext({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
  }) => client.call(
    model: model,
    method: method,
    ids: ids,
    kwargs: kwargs,
    context: context,
  );
}

/// Production bridge for the durable commands currently emitted by the panel
/// and core. It deliberately rejects incomplete legacy approval payloads
/// instead of guessing the business action.
final class OdooOfflineOperationAdapter implements OfflineOperationAdapter {
  OdooOfflineOperationAdapter({
    required this.actions,
    required this.database,
    required this.scope,
    required this.queue,
  });

  final SaleOdooActions actions;
  final AppDatabase database;
  final AppScope scope;
  final OfflineQueueDataSource queue;

  @override
  Future<OperationReconciliation> reconcile(OfflineOperation operation) async {
    _checkScope(operation);
    if (operation.model == 'account.advance' && operation.method == 'create') {
      final id = await _findAdvanceCreatedId(operation);
      if (id == null) return const OperationNotApplied();
      await _persistAdvanceCreate(operation, id);
      return const OperationApplied();
    }
    if (operation.model == 'sale.order.withhold.line' &&
        operation.method == 'create') {
      final id = await _findWithholdCreatedId(operation);
      if (id == null) return const OperationNotApplied();
      await _persistWithholdCreate(operation, id);
      return const OperationApplied();
    }
    if (operation.model == 'account.advance' &&
        operation.method == 'action_post') {
      final id = await _remoteId(operation);
      if (id == null) return const OperationNotApplied();
      final rows = await actions.call(
        model: 'account.advance',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['id', '=', id],
            [
              'state',
              'in',
              ['posted', 'in_use', 'used'],
            ],
          ],
          'fields': ['id', 'state'],
          'limit': 1,
        },
      );
      return rows is List && rows.isNotEmpty
          ? const OperationApplied()
          : const OperationNotApplied();
    }
    if (operation.method == 'cashInvoice' ||
        operation.method == 'existingInvoice') {
      final applied = operation.method == 'existingInvoice'
          ? await _existingInvoiceApplied(operation)
          : await _cashInvoiceApplied(operation);
      return applied ? const OperationApplied() : const OperationNotApplied();
    }
    if (operation.method == 'create' &&
        (operation.model == 'sale.order' ||
            operation.model == 'sale.order.line')) {
      final id = await _findCreatedId(operation);
      if (id == null) return const OperationNotApplied();
      await _persistCreate(operation, id);
      return const OperationApplied();
    }
    if (operation.method == 'create' &&
        (operation.model == 'l10n_ec.cash.out' ||
            operation.model == 'collection.session.deposit' ||
            operation.model == 'collection.session.cash')) {
      final id = await _findCollectionCreatedId(operation);
      if (id == null) return const OperationNotApplied();
      await _persistCollectionCreate(operation, id);
      return const OperationApplied();
    }
    if (operation.model == 'collection.session' &&
        (operation.method == 'session_closing_control' ||
            operation.method == 'session_close')) {
      final id = await _remoteId(operation);
      if (id == null) return const OperationNotApplied();
      final rows = await actions.call(
        model: 'collection.session',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['id', '=', id],
          ],
          'fields': ['state'],
          'limit': 1,
        },
      );
      if (rows is! List || rows.isEmpty || rows.first is! Map) {
        return const OperationNotApplied();
      }
      final state = (rows.first as Map)['state'];
      final applied = operation.method == 'session_close'
          ? state == 'closed'
          : state == 'closing_control' || state == 'closed';
      return applied ? const OperationApplied() : const OperationNotApplied();
    }
    final id = await _remoteId(operation);
    if (id == null) return const OperationNotApplied();
    final isFsc = operation.method == 'fscInvoiceAndDispatch';
    final model = isFsc
        ? 'sale.order'
        : operation.model == 'approval.request'
        ? 'approval.request'
        : operation.model;
    final rows = await actions.call(
      model: model,
      method: 'search_read',
      kwargs: {
        'domain': [
          ['id', '=', id],
        ],
        'fields': model == 'sale.order' || model == 'l10n_ec.cash.out'
            ? ['state']
            : model == 'collection.session.deposit'
            ? ['move_id']
            : ['request_status'],
        'limit': 1,
      },
    );
    if (rows is! List || rows.isEmpty || rows.first is! Map) {
      return const OperationNotApplied();
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    if (model == 'sale.order') {
      final state = row['state'];
      if (state == 'sale' || state == 'done') {
        return const OperationApplied();
      }
    } else if (model == 'l10n_ec.cash.out') {
      if (row['state'] == 'posted') return const OperationApplied();
    } else if (model == 'collection.session.deposit') {
      if (row['move_id'] is List && (row['move_id'] as List).isNotEmpty) {
        return const OperationApplied();
      }
    } else {
      final status = row['request_status'];
      final decision = operation.values['decision'];
      if ((decision == 'approve' && status == 'approved') ||
          (decision == 'reject' && status == 'refused')) {
        return const OperationApplied();
      }
    }
    return const OperationNotApplied();
  }

  @override
  Future<ConflictInfo?> dispatch(OfflineOperation operation) async {
    _checkScope(operation);
    final values = operation.values;
    if (operation.model == 'account.advance' && operation.method == 'create') {
      return _dispatchAdvanceCreate(operation);
    }
    if (operation.model == 'sale.order.withhold.line' &&
        operation.method == 'create') {
      return _dispatchWithholdCreate(operation);
    }
    if (operation.method == 'create' &&
        (operation.model == 'sale.order' ||
            operation.model == 'sale.order.line')) {
      return _dispatchCreate(operation);
    }
    if (operation.method == 'create' &&
        (operation.model == 'l10n_ec.cash.out' ||
            operation.model == 'collection.session.deposit' ||
            operation.model == 'collection.session.cash')) {
      return _dispatchCollectionCreate(operation);
    }
    final id = await _remoteId(operation);
    dynamic result;
    if (operation.model == 'collection.session' &&
        operation.method == 'session_closing_control') {
      if (id == null) throw StateError('collection session id unavailable');
      final amount = values['cash_register_balance_end_real'];
      if (amount is! num || amount < 0) {
        throw StateError('closing control requires a valid cash amount');
      }
      final writeResult = await actions.call(
        model: 'collection.session',
        method: 'write',
        ids: [id],
        kwargs: {
          'vals': {'cash_register_balance_end_real': amount},
        },
      );
      if (_rejected(writeResult)) {
        throw StateError('collection session closing amount was rejected');
      }
      result = await actions.call(
        model: 'collection.session',
        method: 'action_session_closing_control',
        ids: [id],
      );
    } else if (operation.model == 'collection.session' &&
        operation.method == 'session_close') {
      if (id == null) throw StateError('collection session id unavailable');
      result = await actions.call(
        model: 'collection.session',
        method: 'action_session_close',
        ids: [id],
      );
    } else if (operation.model == 'account.advance' &&
        operation.method == 'action_post') {
      if (id == null) throw StateError('account.advance remote id unavailable');
      result = await actions.call(
        model: 'account.advance',
        method: 'action_post',
        ids: [id],
      );
      if (!_rejected(result)) {
        await (database.update(
          database.accountAdvance,
        )..where((table) => table.odooId.equals(id))).write(
          const AccountAdvanceCompanion(
            state: drift.Value('posted'),
            writeDate: drift.Value.absent(),
          ),
        );
      }
    } else if (operation.method == 'cashInvoice') {
      if (id == null) throw StateError('cash invoice order id unavailable');
      final paymentLines = await _operationPaymentLines(operation);
      await _ensureOperationWithholdLines(id, operation);
      final fiscal = OfflineFiscalInvoicePayload(
        sequential: _optionalPositiveInt(values['sequential']),
        emissionDate: values['emissionDate'] as String?,
        accessKey: values['accessKey'] as String?,
      );
      final hasFiscalValue =
          values['sequential'] != null ||
          values['emissionDate'] != null ||
          values['accessKey'] != null;
      final numberedMarker = values['numberedByClient'];
      if (numberedMarker is! bool) {
        throw StateError(
          'cashInvoice requires an explicit numberedByClient contract flag',
        );
      }
      final numberedByClient = numberedMarker;
      if (numberedByClient || hasFiscalValue) {
        if (!fiscal.isComplete) {
          throw StateError(
            'cashInvoice requires server-provisioned sequential, '
            'emissionDate and accessKey for a numbered-by-client journal',
          );
        }
      }
      final typed = paymentLines.any(
        (line) => line['line_type'] != null && line['line_type'] != 'payment',
      );
      if (typed) {
        final wizard = await actions.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'create',
          kwargs: {
            'vals_list': [
              {
                'sale_id': id,
                if (values['collectionSessionId'] is num)
                  'collection_session_id':
                      (values['collectionSessionId'] as num).toInt(),
                // This is the native idempotency marker consumed by the
                // existing payment wizard, not a second payment record.
                'pos_client_op_uuid': values['commandId'],
                'line_ids': [
                  for (final line in paymentLines) [0, 0, line],
                ],
              },
            ],
          },
        );
        final wizardId = _createdId(wizard);
        if (wizardId == null) {
          throw const AmbiguousOperationException(
            'payment wizard create returned no definitive id',
          );
        }
        result = await actions.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'action_apply_and_create_invoice',
          ids: [wizardId],
        );
      } else {
        final kwargs = <String, dynamic>{
          'payment_lines': paymentLines,
          if (values['collectionSessionId'] is num)
            'collection_session_id': (values['collectionSessionId'] as num)
                .toInt(),
          'client_op_uuid': values['commandId'],
          if (fiscal.isComplete) ...fiscal.toOdoo(),
        };
        result = await actions.call(
          model: 'sale.order',
          method: 'action_pos_confirm_and_invoice',
          ids: [id],
          kwargs: kwargs,
        );
      }
    } else if (operation.model == 'sale.order' &&
        operation.method == 'action_pos_confirm') {
      if (id == null) throw StateError('sale.order remote id unavailable');
      result = await actions.call(
        model: 'sale.order',
        method: 'action_pos_confirm',
        ids: [id],
      );
    } else if (operation.model == 'l10n_ec.cash.out' &&
        operation.method == 'action_confirm') {
      if (id == null) throw StateError('cash out remote id unavailable');
      result = await actions.call(
        model: operation.model,
        method: 'action_confirm',
        ids: [id],
      );
    } else if (operation.method == 'fscInvoiceAndDispatch') {
      if (id == null) throw StateError('sale.order remote id unavailable');
      result = await actions.call(
        model: 'sale.order',
        method: 'action_l10n_ec_aprobar_fsc',
        ids: [id],
      );
    } else if (operation.model == 'approval.request') {
      final decision = values['decision'];
      final method = switch (decision) {
        'approve' => 'action_approve',
        'reject' => 'action_refuse',
        _ => throw StateError('approval decision missing from durable payload'),
      };
      if (id == null) {
        throw StateError('approval request remote id unavailable');
      }
      result = await actions.call(
        model: 'approval.request',
        method: method,
        ids: [id],
      );
    } else if (operation.model ==
            'l10n_ec_collection_box.sale.order.payment.wizard' &&
        operation.method == 'existingInvoice') {
      final lines = await _operationPaymentLines(operation);
      await _ensureOperationWithholdLines(
        _positiveInt(values['saleOrderRemoteId']) ?? id ?? 0,
        operation,
      );
      var wizardId = _positiveInt(values['wizardId']);
      if (wizardId != null) {
        final wizardRows = await actions.call(
          model: operation.model,
          method: 'search_read',
          kwargs: {
            'domain': [
              ['id', '=', wizardId],
            ],
            'fields': ['id'],
            'limit': 1,
          },
        );
        // Transient wizard IDs are cache hints only. A definitive empty
        // search means the transient expired; recreate it from the durable
        // sale/session/line snapshot below.
        if (wizardRows is List && wizardRows.isEmpty) wizardId = null;
      }
      if (wizardId == null) {
        final saleId = _positiveInt(values['saleOrderRemoteId']);
        if (saleId == null) {
          throw StateError('existing invoice requires sale order id');
        }
        final created = await actions.call(
          model: operation.model,
          method: 'create',
          kwargs: {
            'vals_list': [
              {
                'sale_id': saleId,
                if (values['collectionSessionId'] is num)
                  'collection_session_id':
                      (values['collectionSessionId'] as num).toInt(),
                'pos_client_op_uuid': values['commandId'],
                'line_ids': [
                  for (final line in lines) [0, 0, line],
                ],
              },
            ],
          },
        );
        wizardId = _createdId(created);
        if (wizardId == null) {
          throw const AmbiguousOperationException(
            'existing invoice wizard create returned no definitive id',
          );
        }
      } else {
        final writeResult = await actions.call(
          model: operation.model,
          method: 'write',
          ids: [wizardId],
          kwargs: {
            'vals': {
              'pos_client_op_uuid': values['commandId'],
              'line_ids': [
                [5, 0, 0],
                for (final line in lines) [0, 0, line],
              ],
            },
          },
        );
        if (_rejected(writeResult)) {
          throw StateError('payment wizard lines were rejected');
        }
      }
      result = await actions.call(
        model: operation.model,
        method: 'action_apply',
        ids: [wizardId],
      );
    } else {
      throw StateError(
        'Unsupported durable operation ${operation.model}.${operation.method}',
      );
    }
    if (_rejected(result)) {
      return ConflictInfo(
        operationId: operation.id,
        model: operation.model,
        recordId: operation.recordId,
        localWriteDate: operation.createdAt,
        serverWriteDate: DateTime.now().toUtc(),
        localValues: Map<String, dynamic>.from(values),
      );
    }
    if ((operation.method == 'cashInvoice' ||
            operation.method == 'existingInvoice') &&
        operation.values['paymentLineIds'] is List) {
      await _markPaymentLinesApplied(operation.values['paymentLineIds']);
    }
    if (operation.model == 'collection.session' && id != null) {
      final state = operation.method == 'session_close'
          ? 'closed'
          : 'closing_control';
      await (database.update(
        database.collectionSession,
      )..where((table) => table.odooId.equals(id))).write(
        CollectionSessionCompanion(
          state: drift.Value(state),
          isSynced: const drift.Value(true),
          lastSyncDate: drift.Value(DateTime.now().toUtc()),
        ),
      );
    }
    if (operation.model == 'l10n_ec.cash.out' &&
        operation.method == 'action_confirm' &&
        operation.values['local_id'] is int) {
      await (database.update(database.cashOut)..where(
            (table) => table.id.equals(operation.values['local_id'] as int),
          ))
          .write(const CashOutCompanion(state: drift.Value('posted')));
    }
    return null;
  }

  Future<bool> _cashInvoiceApplied(OfflineOperation operation) async {
    final commandId = operation.values['commandId'];
    if (commandId is! String || commandId.isEmpty) return false;
    final expectedMinor = _expectedCollectionAmountMinor(operation.values);
    if (expectedMinor == null || expectedMinor <= 0) return false;
    final result = await actions.call(
      model: 'account.move',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['l10n_ec_pos_client_op_uuid', '=', commandId],
          ['move_type', '=', 'out_invoice'],
          ['state', '=', 'posted'],
          ['state', '!=', 'cancel'],
        ],
        'fields': [
          'id',
          'state',
          'payment_state',
          'amount_total',
          'l10n_ec_pos_collection_completed',
        ],
        'limit': 1,
      },
    );
    if (result is! List || result.length != 1 || result.first is! Map) {
      return false;
    }
    final row = Map<String, dynamic>.from(result.first as Map);
    final completed = row['l10n_ec_pos_collection_completed'] == true;
    final paymentState = row['payment_state'];
    final paid = paymentState == 'paid';
    final total = row['amount_total'];
    final actualMinor = total is num ? (total * 100).round() : null;
    return completed && paid && actualMinor == expectedMinor;
  }

  Future<bool> _existingInvoiceApplied(OfflineOperation operation) async {
    final commandId = operation.values['commandId'];
    if (commandId is! String || commandId.isEmpty) return false;
    final result = await actions.call(
      model: 'l10n_ec_collection_box.sale.order.payment',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['pos_collection_op_uuid', '=', commandId],
        ],
        'fields': [
          'id',
          'amount',
          'state',
          'move_id',
          'pos_collection_line_uuid',
        ],
        // A payment operation may contain multiple native lines. Do not
        // truncate the evidence used to decide whether retry is safe.
        'limit': 100,
      },
    );
    if (result is! List || result.isEmpty || result.any((row) => row is! Map)) {
      return false;
    }
    final lines = result
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    if (lines.any((line) {
      final move = line['move_id'];
      return line['state'] != 'posted' ||
          move is! List ||
          move.isEmpty ||
          move.first is! num;
    })) {
      return false;
    }
    final expectedMinor = await _operationPaymentLinesExpectedMinor(operation);
    if (expectedMinor == null) return true;
    var actualMinor = 0;
    for (final line in lines) {
      final amount = line['amount'];
      if (amount is! num || !amount.isFinite || amount <= 0) return false;
      actualMinor += (amount * 100).round();
    }
    return actualMinor == expectedMinor;
  }

  static int? _paymentLinesExpectedMinor(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    var total = 0;
    for (final line in raw) {
      if (line is! Map || line['amountMinor'] is! num) return null;
      final amount = (line['amountMinor'] as num).toInt();
      if (amount <= 0) return null;
      total += amount;
    }
    return total > 0 ? total : null;
  }

  Future<int?> _operationPaymentLinesExpectedMinor(
    OfflineOperation operation,
  ) async {
    final fromPayload = _paymentLinesExpectedMinor(
      operation.values['paymentLines'],
    );
    if (fromPayload != null) return fromPayload;
    final ids = operation.values['paymentLineIds'];
    if (ids is! List || ids.isEmpty) return null;
    var total = 0;
    for (final rawId in ids) {
      final localId = _positiveInt(rawId);
      if (localId == null) return null;
      final row = await (database.select(
        database.saleOrderPaymentLine,
      )..where((table) => table.id.equals(localId))).getSingleOrNull();
      if (row == null || row.amount <= 0) return null;
      total += (row.amount * 100).round();
    }
    return total > 0 ? total : null;
  }

  static int? _expectedCollectionAmountMinor(Map<String, dynamic> values) {
    final explicit = values['amountMinor'];
    if (explicit is num && explicit.toInt() > 0) return explicit.toInt();
    final raw = values['paymentLines'];
    if (raw is! List || raw.isEmpty) return null;
    var total = 0;
    for (final line in raw) {
      if (line is! Map || line['amountMinor'] is! num) return null;
      final amount = (line['amountMinor'] as num).toInt();
      if (amount <= 0) return null;
      total += amount;
    }
    return total > 0 ? total : null;
  }

  static List<Map<String, dynamic>> _paymentLines(dynamic raw) {
    if (raw is! List || raw.isEmpty) {
      throw StateError('cash invoice requires payment lines');
    }
    return raw
        .map((entry) {
          if (entry is! Map) throw StateError('invalid payment line');
          final kind = entry['type'] is String
              ? entry['type'] as String
              : (entry['lineType'] is String
                    ? entry['lineType'] as String
                    : 'payment');
          if (!{'payment', 'advance', 'credit_note'}.contains(kind)) {
            throw StateError('invalid payment line type');
          }
          final journal = _positiveInt(entry['journalId']);
          final amountMinor = entry['amountMinor'];
          if (amountMinor is! num ||
              amountMinor <= 0 ||
              (kind == 'payment' && journal == null) ||
              (kind == 'advance' && _positiveInt(entry['advanceId']) == null) ||
              (kind == 'credit_note' &&
                  _positiveInt(entry['creditNoteId']) == null)) {
            throw StateError('invalid payment line amount or journal');
          }
          return {
            'line_type': kind,
            ...?_present('journal_id', journal),
            'amount': amountMinor / 100,
            if (_positiveInt(entry['advanceId']) != null)
              'advance_id': _positiveInt(entry['advanceId']),
            if (_positiveInt(entry['creditNoteId']) != null)
              'credit_note_id': _positiveInt(entry['creditNoteId']),
            if (_positiveInt(entry['paymentMethodLineId']) != null)
              'payment_method_line_id': _positiveInt(
                entry['paymentMethodLineId'],
              ),
          };
        })
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _operationPaymentLines(
    OfflineOperation operation,
  ) async {
    final ids = operation.values['paymentLineIds'];
    if (ids is! List) return _paymentLines(operation.values['paymentLines']);
    final rows = <SaleOrderPaymentLineData>[];
    for (final rawId in ids) {
      final localId = _positiveInt(rawId);
      if (localId == null) throw StateError('payment line id missing');
      final row = await (database.select(
        database.saleOrderPaymentLine,
      )..where((table) => table.id.equals(localId))).getSingleOrNull();
      if (row == null) throw StateError('local payment line disappeared');
      rows.add(row);
    }
    return _paymentLines([
      for (final row in rows)
        {
          'type': row.type == 'credit_note' ? 'credit_note' : row.type,
          'journalId': row.journalId,
          'amountMinor': (row.amount * 100).round(),
          'advanceId': row.advanceId,
          'creditNoteId': row.creditNoteId,
          'paymentMethodLineId': row.paymentMethodLineId,
        },
    ]);
  }

  Future<void> _ensureOperationWithholdLines(
    int saleId,
    OfflineOperation operation,
  ) async {
    final ids = operation.values['withholdLineIds'];
    if (ids is List) {
      // Native rows already have one official create intent each. The queue
      // orders those intents before the parent payment wizard, so rebuilding
      // them here would duplicate the same financial fact and Odoo rule.
      return;
    }
    await _ensureWithholdLines(saleId, operation.values['withholdLines']);
  }

  Future<void> _markPaymentLinesApplied(dynamic rawIds) async {
    if (rawIds is! List) return;
    for (final rawId in rawIds) {
      final id = _positiveInt(rawId);
      if (id == null) continue;
      await (database.update(
        database.saleOrderPaymentLine,
      )..where((table) => table.id.equals(id))).write(
        SaleOrderPaymentLineCompanion(
          isSynced: const drift.Value(true),
          lastSyncDate: drift.Value(DateTime.now().toUtc()),
        ),
      );
    }
  }

  Future<void> _ensureWithholdLines(int saleId, dynamic raw) async {
    if (raw == null) return;
    if (raw is! List) throw StateError('invalid withhold lines');
    for (final entry in raw) {
      if (entry is! Map) throw StateError('invalid withhold line');
      final taxId = _positiveInt(entry['tax_id']);
      final baseMinor = entry['baseMinor'];
      final amountMinor = entry['amountMinor'];
      if (taxId == null ||
          baseMinor is! num ||
          amountMinor is! num ||
          baseMinor <= 0 ||
          amountMinor <= 0) {
        throw StateError('invalid withhold amount or tax');
      }
      final official = <String, dynamic>{
        'sale_id': saleId,
        'tax_id': taxId,
        'base': baseMinor / 100,
        'amount': amountMinor / 100,
        if (entry['taxsupport_code'] is String)
          'taxsupport_code': entry['taxsupport_code'],
        if (entry['notes'] is String) 'notes': entry['notes'],
      };
      final rows = await actions.call(
        model: 'sale.order.withhold.line',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['sale_id', '=', saleId],
            ['tax_id', '=', taxId],
            ['base', '=', official['base']],
            ['amount', '=', official['amount']],
          ],
          'fields': ['id'],
          'limit': 2,
        },
      );
      if (rows is List && rows.length > 1) {
        throw const AmbiguousOperationException(
          'withhold line natural key matched multiple remote rows',
        );
      }
      if (rows is List && rows.length == 1) continue;
      final created = await actions.call(
        model: 'sale.order.withhold.line',
        method: 'create',
        kwargs: {
          'vals_list': [official],
        },
      );
      if (_createdId(created) == null) {
        throw const AmbiguousOperationException(
          'withhold line create returned no definitive id',
        );
      }
    }
  }

  Future<ConflictInfo?> _dispatchCreate(OfflineOperation operation) async {
    final known = _positiveInt(operation.values['_remote_create_id']);
    if (known != null) return null;

    final fields = operation.model == 'sale.order'
        ? await _orderCreateFields(operation)
        : await _lineCreateFields(operation);
    final result = await _callCreate(operation.model, fields);
    final id = _createdId(result);
    if (id == null) {
      throw const AmbiguousOperationException(
        'create returned no definitive positive remote id',
      );
    }
    await _persistCreate(operation, id);
    return null;
  }

  Future<ConflictInfo?> _dispatchAdvanceCreate(
    OfflineOperation operation,
  ) async {
    final known = _positiveInt(operation.values['_remote_create_id']);
    if (known != null) return null;
    final fields = Map<String, dynamic>.from(operation.values)
      ..remove('local_id')
      ..remove('_operation_key')
      ..remove('_remote_create_id')
      ..remove('dependsOn');
    final result = await actions.call(
      model: 'account.advance',
      method: 'create',
      kwargs: {
        'vals_list': [fields],
      },
    );
    final id = _createdId(result);
    if (id == null) {
      throw const AmbiguousOperationException(
        'account.advance create returned no definitive remote id',
      );
    }
    await _persistAdvanceCreate(operation, id);
    return null;
  }

  Future<ConflictInfo?> _dispatchWithholdCreate(
    OfflineOperation operation,
  ) async {
    final known = _positiveInt(operation.values['_remote_create_id']);
    if (known != null) return null;
    final fields = await _withholdFields(operation);
    fields
      ..remove('uuid')
      ..remove('local_id')
      ..remove('_operation_key')
      ..remove('_remote_create_id')
      ..remove('dependsOn');
    final result = await actions.call(
      model: 'sale.order.withhold.line',
      method: 'create',
      kwargs: {
        'vals_list': [fields],
      },
    );
    final id = _createdId(result);
    if (id == null) {
      throw const AmbiguousOperationException(
        'withhold line create returned no definitive remote id',
      );
    }
    await _persistWithholdCreate(operation, id);
    return null;
  }

  Future<Map<String, dynamic>> _withholdFields(
    OfflineOperation operation,
  ) async {
    final supplied = Map<String, dynamic>.from(operation.values);
    final localId = operation.recordId ?? _positiveInt(supplied['local_id']);
    if (supplied['sale_id'] is num &&
        supplied['tax_id'] is num &&
        supplied['base'] is num &&
        supplied['amount'] is num) {
      return supplied;
    }
    if (localId == null) throw StateError('withhold line local id missing');
    final row = await (database.select(
      database.saleOrderWithholdLine,
    )..where((table) => table.id.equals(localId))).getSingleOrNull();
    if (row == null) throw StateError('local withhold line disappeared');
    return {
      'sale_id': row.orderId,
      'tax_id': row.taxId,
      'base': row.base,
      'amount': row.amount,
      if (row.taxsupportCode != null) 'taxsupport_code': row.taxsupportCode,
      if (row.notes != null) 'notes': row.notes,
    };
  }

  Future<int?> _findAdvanceCreatedId(OfflineOperation operation) async {
    final marked = _positiveInt(operation.values['_remote_create_id']);
    if (marked != null) return marked;
    final externalId = operation.values['external_id'];
    if (externalId is! String || externalId.isEmpty) return null;
    final rows = await actions.call(
      model: 'account.advance',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['external_id', '=', externalId],
        ],
        'fields': ['id'],
        'limit': 1,
      },
    );
    if (rows is List && rows.isNotEmpty && rows.first is Map) {
      return _positiveInt((rows.first as Map)['id']);
    }
    return null;
  }

  Future<int?> _findWithholdCreatedId(OfflineOperation operation) async {
    final marked = _positiveInt(operation.values['_remote_create_id']);
    if (marked != null) return marked;
    final fields = await _withholdFields(operation);
    final saleId = _positiveInt(fields['sale_id']);
    final taxId = _positiveInt(fields['tax_id']);
    final amount = fields['amount'];
    if (saleId == null || taxId == null || amount is! num) return null;
    final rows = await actions.call(
      model: 'sale.order.withhold.line',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['sale_id', '=', saleId],
          ['tax_id', '=', taxId],
          ['amount', '=', amount],
        ],
        'fields': ['id'],
        'limit': 2,
      },
    );
    // Two matches are ambiguous: do not guess a financial line.
    if (rows is List && rows.length == 1 && rows.first is Map) {
      return _positiveInt((rows.first as Map)['id']);
    }
    return null;
  }

  Future<void> _persistAdvanceCreate(
    OfflineOperation operation,
    int remoteId,
  ) async {
    await database.transaction(() async {
      final values = Map<String, dynamic>.from(operation.values)
        ..['_remote_create_id'] = remoteId;
      await (database.update(
        database.offlineQueue,
      )..where((table) => table.id.equals(operation.id))).write(
        OfflineQueueCompanion(values: drift.Value(jsonEncode(values))),
      );
      final localId =
          operation.recordId ?? _positiveInt(operation.values['local_id']);
      if (localId == null) return;
      final local = await (database.select(
        database.accountAdvance,
      )..where((table) => table.odooId.equals(localId))).getSingleOrNull();
      if (local == null) return;
      await (database.update(database.accountAdvance)
            ..where((table) => table.id.equals(local.id)))
          .write(AccountAdvanceCompanion(odooId: drift.Value(remoteId)));
      await (database.update(database.advanceLinesTable)
            ..where((table) => table.advanceId.equals(localId)))
          .write(AdvanceLinesTableCompanion(advanceId: drift.Value(remoteId)));
      await queue.updateRecordIdInPendingOperations(
        'account.advance',
        localId,
        remoteId,
      );
    });
  }

  Future<void> _persistWithholdCreate(
    OfflineOperation operation,
    int remoteId,
  ) async {
    await database.transaction(() async {
      final values = Map<String, dynamic>.from(operation.values)
        ..['_remote_create_id'] = remoteId;
      await (database.update(
        database.offlineQueue,
      )..where((table) => table.id.equals(operation.id))).write(
        OfflineQueueCompanion(values: drift.Value(jsonEncode(values))),
      );
      final localId =
          operation.recordId ?? _positiveInt(operation.values['local_id']);
      if (localId == null) return;
      await (database.update(
        database.saleOrderWithholdLine,
      )..where((table) => table.id.equals(localId))).write(
        SaleOrderWithholdLineCompanion(
          odooId: drift.Value(remoteId),
          isSynced: const drift.Value(true),
          lastSyncDate: drift.Value(DateTime.now().toUtc()),
        ),
      );
      await queue.updateRecordIdInPendingOperations(
        'sale.order.withhold.line',
        localId,
        remoteId,
      );
    });
  }

  Future<ConflictInfo?> _dispatchCollectionCreate(
    OfflineOperation operation,
  ) async {
    final known = _positiveInt(operation.values['_remote_create_id']);
    if (known != null) return null;
    final fields = Map<String, dynamic>.from(operation.values)
      ..remove('local_id')
      ..remove('_operation_key')
      ..remove('_remote_create_id')
      ..remove('command_id');
    if (operation.model == 'l10n_ec.cash.out' && fields['uuid'] is String) {
      fields['cash_out_uuid'] = fields.remove('uuid');
    }
    final result = await actions.call(
      model: operation.model,
      method: 'create',
      kwargs: {
        'vals_list': [fields],
      },
    );
    final id = _createdId(result);
    if (id == null) {
      throw const AmbiguousOperationException(
        'collection create returned no definitive remote id',
      );
    }
    await _persistCollectionCreate(operation, id);
    return null;
  }

  Future<dynamic> _callCreate(String model, Map<String, dynamic> fields) {
    return actions.call(model: model, method: 'create', kwargs: fields);
  }

  Future<Map<String, dynamic>> _orderCreateFields(
    OfflineOperation operation,
  ) async {
    final localId = operation.recordId;
    if (localId == null || localId <= 0) {
      throw StateError('sale.order create requires a positive local id');
    }
    final row = await (database.select(
      database.saleOrder,
    )..where((table) => table.id.equals(localId))).getSingleOrNull();
    if (row == null) throw StateError('local sale order not found');
    final fields = <String, dynamic>{
      'name': row.name,
      'x_uuid': row.xUuid ?? row.orderUuid,
      if (row.partnerId != null && row.partnerId! > 0)
        'partner_id': row.partnerId,
      if (row.paymentTermId != null && row.paymentTermId! > 0)
        'payment_term_id': row.paymentTermId,
      if (row.note != null) 'note': row.note,
    };
    return fields;
  }

  Future<Map<String, dynamic>> _lineCreateFields(
    OfflineOperation operation,
  ) async {
    final lineUuid = operation.values['lineUuid'];
    if (lineUuid is! String || lineUuid.isEmpty) {
      throw StateError('sale.order.line create requires lineUuid');
    }
    final line = await (database.select(
      database.saleOrderLine,
    )..where((table) => table.lineUuid.equals(lineUuid))).getSingleOrNull();
    if (line == null) throw StateError('local sale order line not found');
    final parent =
        await (database.select(
              database.saleOrder,
            )..where((table) => table.id.equals(operation.parentOrderId ?? -1)))
            .getSingleOrNull();
    final orderId = parent?.odooId;
    if (orderId == null || orderId <= 0) {
      throw StateError('sale.order.line create requires synced parent order');
    }
    final taxIds = _taxIds(line.taxIds);
    return {
      'order_id': orderId,
      'x_uuid': line.xUuid ?? line.lineUuid,
      'name': line.name,
      if (line.productId != null && line.productId! > 0)
        'product_id': line.productId,
      if (line.productUomId != null && line.productUomId! > 0)
        'product_uom': line.productUomId,
      'product_uom_qty': line.productUomQty,
      'price_unit': line.priceUnit,
      'discount': line.discount,
      if (taxIds.isNotEmpty)
        'tax_id': [
          [6, 0, taxIds],
        ],
    };
  }

  Future<int?> _findCreatedId(OfflineOperation operation) async {
    final marked = _positiveInt(operation.values['_remote_create_id']);
    if (marked != null) return marked;
    final uuid = operation.model == 'sale.order'
        ? operation.values['orderUuid']
        : operation.values['lineUuid'];
    if (uuid is! String || uuid.isEmpty) return null;
    final result = await actions.call(
      model: operation.model,
      method: 'search_read',
      kwargs: {
        'domain': [
          ['x_uuid', '=', uuid],
        ],
        'fields': ['id'],
        'limit': 1,
      },
    );
    if (result is List && result.isNotEmpty && result.first is Map) {
      return _positiveInt((result.first as Map)['id']);
    }
    return null;
  }

  Future<int?> _findCollectionCreatedId(OfflineOperation operation) async {
    final marked = _positiveInt(operation.values['_remote_create_id']);
    if (marked != null) return marked;
    final key = operation.model == 'l10n_ec.cash.out'
        ? operation.values['cash_out_uuid'] ?? operation.values['uuid']
        : operation.model == 'collection.session.deposit'
        ? operation.values['deposit_uuid']
        : null;
    final session = operation.values['collection_session_id'];
    if (operation.model == 'collection.session.cash' && session is num) {
      final countFields = const [
        'bills_100',
        'bills_50',
        'bills_20',
        'bills_10',
        'bills_5',
        'bills_1',
        'coins_1',
        'coins_50',
        'coins_25',
        'coins_10',
        'coins_5',
        'coins_1_cent',
      ];
      final domain = <dynamic>[
        ['collection_session_id', '=', session.toInt()],
        ['cash_type', '=', 'closing'],
        for (final field in countFields)
          [field, '=', operation.values[field] ?? 0],
      ];
      // Odoo stores an unset Char as false; include it in the marker so a
      // different count in the same session cannot be mistaken for this one.
      domain.add(['notes', '=', operation.values['notes'] ?? false]);
      final result = await actions.call(
        model: operation.model,
        method: 'search_read',
        kwargs: {
          'domain': domain,
          'fields': ['id'],
          'limit': 1,
        },
      );
      if (result is List && result.isNotEmpty && result.first is Map) {
        return _positiveInt((result.first as Map)['id']);
      }
      return null;
    }
    if (key is! String || key.isEmpty) return null;
    final field = operation.model == 'l10n_ec.cash.out'
        ? 'cash_out_uuid'
        : 'deposit_uuid';
    final result = await actions.call(
      model: operation.model,
      method: 'search_read',
      kwargs: {
        'domain': [
          [field, '=', key],
        ],
        'fields': ['id'],
        'limit': 1,
      },
    );
    if (result is List && result.isNotEmpty && result.first is Map) {
      return _positiveInt((result.first as Map)['id']);
    }
    return null;
  }

  Future<void> _persistCreate(OfflineOperation operation, int remoteId) async {
    await database.transaction(() async {
      final values = Map<String, dynamic>.from(operation.values)
        ..['_remote_create_id'] = remoteId;
      await (database.update(
        database.offlineQueue,
      )..where((table) => table.id.equals(operation.id))).write(
        OfflineQueueCompanion(
          values: drift.Value(jsonEncode(values)),
          replayPolicy: const drift.Value('retry_safe'),
        ),
      );
      if (operation.model == 'sale.order') {
        final localId = operation.recordId;
        if (localId == null) throw StateError('order create local id missing');
        final row = await (database.select(
          database.saleOrder,
        )..where((table) => table.id.equals(localId))).getSingleOrNull();
        if (row == null) throw StateError('local sale order disappeared');
        await (database.update(
          database.saleOrder,
        )..where((table) => table.id.equals(localId))).write(
          SaleOrderCompanion(
            odooId: drift.Value(remoteId),
            isSynced: const drift.Value(false),
          ),
        );
        await (database.update(database.saleOrderLine)
              ..where((table) => table.orderId.equals(row.odooId)))
            .write(SaleOrderLineCompanion(orderId: drift.Value(remoteId)));
      } else {
        final lineUuid = operation.values['lineUuid'];
        if (lineUuid is! String) throw StateError('lineUuid missing');
        await (database.update(
          database.saleOrderLine,
        )..where((table) => table.lineUuid.equals(lineUuid))).write(
          SaleOrderLineCompanion(
            odooId: drift.Value(remoteId),
            isSynced: const drift.Value(true),
          ),
        );
      }
    });
  }

  Future<void> _persistCollectionCreate(
    OfflineOperation operation,
    int remoteId,
  ) async {
    await database.transaction(() async {
      final values = Map<String, dynamic>.from(operation.values)
        ..['_remote_create_id'] = remoteId;
      await (database.update(
        database.offlineQueue,
      )..where((table) => table.id.equals(operation.id))).write(
        OfflineQueueCompanion(values: drift.Value(jsonEncode(values))),
      );
      final localId = operation.recordId;
      if (localId == null) return;
      if (operation.model == 'l10n_ec.cash.out') {
        await (database.update(
          database.cashOut,
        )..where((table) => table.id.equals(localId))).write(
          CashOutCompanion(
            odooId: drift.Value(remoteId),
            isSynced: const drift.Value(true),
            state: const drift.Value('draft'),
          ),
        );
      } else if (operation.model == 'collection.session.deposit') {
        await (database.update(
          database.collectionSessionDeposit,
        )..where((table) => table.id.equals(localId))).write(
          CollectionSessionDepositCompanion(
            odooId: drift.Value(remoteId),
            isSynced: const drift.Value(true),
          ),
        );
      } else {
        await (database.update(
          database.collectionSessionCash,
        )..where((table) => table.id.equals(localId))).write(
          CollectionSessionCashCompanion(
            odooId: drift.Value(remoteId),
            isSynced: const drift.Value(true),
            lastSyncDate: drift.Value(DateTime.now().toUtc()),
          ),
        );
      }
      await queue.updateRecordIdInPendingOperations(
        operation.model,
        localId,
        remoteId,
      );
    });
  }

  static List<int> _taxIds(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final value = jsonDecode(encoded);
      if (value is! List) return const [];
      return value
          .whereType<num>()
          .map((id) => id.toInt())
          .where((id) => id > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static int? _createdId(dynamic result) {
    if (result is num) return _positiveInt(result);
    if (result is List && result.length == 1) return _createdId(result.first);
    if (result is Map) {
      return _createdId(result['id'] ?? result['result']);
    }
    return null;
  }

  static int? _positiveInt(dynamic value) {
    return value is num && value.toInt() > 0 ? value.toInt() : null;
  }

  static int? _optionalPositiveInt(dynamic value) {
    if (value == null) return null;
    return _positiveInt(value);
  }

  Future<int?> _remoteId(OfflineOperation operation) async {
    final created = _positiveInt(operation.values['_remote_create_id']);
    if (created != null) return created;
    if (operation.method == 'fscInvoiceAndDispatch' ||
        operation.method == 'cashInvoice') {
      final value = operation.values['saleOrderRemoteId'];
      return value is num && value > 0 ? value.toInt() : null;
    }
    if (operation.model == 'sale.order') {
      final local = operation.recordId;
      if (local == null) return null;
      final row = await (database.select(
        database.saleOrder,
      )..where((table) => table.id.equals(local))).getSingleOrNull();
      return row?.odooId;
    }
    if (operation.model == 'account.advance') {
      final local = operation.recordId;
      if (local == null) return null;
      final row =
          await (database.select(database.accountAdvance)..where(
                (table) => table.id.equals(local) | table.odooId.equals(local),
              ))
              .getSingleOrNull();
      return row?.odooId != null && row!.odooId > 0 ? row.odooId : null;
    }
    final value =
        operation.values['approvalRequestRemoteId'] ??
        operation.values['wizardId'] ??
        operation.recordId;
    return value is num && value > 0 ? value.toInt() : null;
  }

  void _checkScope(OfflineOperation operation) {
    final payloadScope = operation.values['scopeKey'];
    if (payloadScope is String && payloadScope != scope.scopeKey) {
      throw StateError('Operation payload belongs to another scope');
    }
  }
}

final class OdooCollectionSessionStore implements SaleShiftStore {
  final SaleOdooActions actions;
  final SaleShiftVersionReader versions;
  const OdooCollectionSessionStore(this.actions, this.versions);
  @override
  Future<OperationOutcome<SaleShiftState>> apply({
    required String commandId,
    required EntityReference shift,
    required int expectedVersion,
    required SaleShiftState state,
  }) async {
    final id = shift.remoteId;
    if (id == null) throw ArgumentError.value(shift.localId, 'shift');
    final currentVersion = await versions.read(shift);
    if (currentVersion != expectedVersion) {
      return OperationOutcome(
        commandId: commandId,
        entity: shift,
        businessState: state,
        syncState: OperationSyncState.conflict,
        issues: [
          OperationIssue(
            code: 'shift_version_conflict',
            messageKey: 'collection.session.version_conflict',
          ),
        ],
      );
    }
    final method = state == SaleShiftState.open
        ? 'action_session_open'
        : 'close_control_session_pos';
    final result = await actions.call(
      model: 'collection.session',
      method: method,
      ids: [id],
    );
    if (_rejected(result)) {
      return OperationOutcome(
        commandId: commandId,
        entity: shift,
        businessState: state,
        syncState: OperationSyncState.conflict,
        issues: [
          OperationIssue(
            code: '${state.name}_rejected',
            messageKey: 'collection.session.${state.name}.rejected',
          ),
        ],
      );
    }
    return OperationOutcome(
      commandId: commandId,
      entity: shift,
      businessState: state,
      syncState: OperationSyncState.queued,
    );
  }
}

abstract interface class SaleShiftVersionReader {
  Future<int> read(EntityReference shift);
}

bool _rejected(dynamic result) =>
    result == false ||
    (result is Map &&
        (result['success'] == false ||
            result['error'] != null ||
            result['warning'] != null));

Map<String, dynamic>? _present(String key, dynamic value) =>
    value == null ? null : {key: value};

/// Maps the existing POS facade response without claiming that the remote
/// transaction is complete when the server asks for approval or is ambiguous.
final class OdooSaleConfirmationAdapter {
  final SaleOdooActions actions;
  final SaleRemoteVersionReader versions;
  final SaleRemoteConfirmationReader? states;
  const OdooSaleConfirmationAdapter(this.actions, this.versions, {this.states});

  Future<OperationOutcome<SaleOrderState>> confirm({
    required EntityReference order,
    required String commandId,
    required int expectedVersion,
  }) async {
    final remoteId = order.remoteId;
    if (remoteId == null) {
      throw ArgumentError('remoteId required for Odoo confirmation');
    }
    if (await versions.read(order) != expectedVersion) {
      return OperationOutcome(
        commandId: commandId,
        entity: order,
        businessState: SaleOrderState.approved,
        syncState: OperationSyncState.conflict,
        issues: [
          OperationIssue(
            code: 'confirmation_version_conflict',
            messageKey: 'sale.version_conflict',
          ),
        ],
      );
    }
    dynamic result;
    try {
      result = await actions.call(
        model: 'sale.order',
        method: 'action_pos_confirm',
        ids: [remoteId],
      );
    } catch (_) {
      final observed = states == null ? null : await states!.read(order);
      if (observed == SaleOrderState.sale || observed == SaleOrderState.done) {
        return OperationOutcome(
          commandId: commandId,
          entity: order,
          businessState: observed!,
          syncState: OperationSyncState.synced,
        );
      }
      return OperationOutcome(
        commandId: commandId,
        entity: order,
        businessState: SaleOrderState.approved,
        syncState: OperationSyncState.conflict,
        issues: [
          OperationIssue(
            code: 'confirmation_ambiguous',
            messageKey: 'sale.confirmation_ambiguous',
            retryable: true,
          ),
        ],
      );
    }
    if (_rejected(result)) {
      final approval = result is Map && result['approval_required'] == true;
      return OperationOutcome(
        commandId: commandId,
        entity: order,
        businessState: SaleOrderState.approved,
        syncState: approval
            ? OperationSyncState.conflict
            : OperationSyncState.failed,
        pendingAction: approval
            ? PendingAction(type: PendingActionType.approval, entity: order)
            : null,
        issues: [
          OperationIssue(
            code: approval ? 'approval_required' : 'confirmation_rejected',
            messageKey: 'sale.confirmation.rejected',
          ),
        ],
      );
    }
    return OperationOutcome(
      commandId: commandId,
      entity: order,
      businessState: SaleOrderState.sale,
      syncState: OperationSyncState.synced,
    );
  }
}

abstract interface class SaleRemoteVersionReader {
  Future<int> read(EntityReference order);
}

abstract interface class SaleRemoteConfirmationReader {
  Future<SaleOrderState?> read(EntityReference order);
}
