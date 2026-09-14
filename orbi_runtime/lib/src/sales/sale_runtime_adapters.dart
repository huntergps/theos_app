import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:odoo_sdk/odoo_sdk.dart'
    show ConflictInfo, OdooMethodNotFoundException, RetryableOfflineOperationException;
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
  final String? collectionLineUuid;

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
    this.collectionLineUuid,
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
    ...?_present('pos_collection_line_uuid', collectionLineUuid),
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
      if (paymentLines.any((line) => line.collectionLineUuid == null)) {
        return OperationOutcome(
          commandId: commandId,
          entity: order,
          businessState: SaleOrderState.sale,
          syncState: OperationSyncState.conflict,
          issues: [
            OperationIssue(
              code: 'invoice_collection_line_identity_missing',
              messageKey: 'sale.invoice_collection_line_identity_missing',
              retryable: false,
            ),
          ],
        );
      }
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
    if (!explicitInvoice &&
        !await _existingPaymentApplied(
          commandId,
          saleId: order.remoteId,
          expectedAmountMinor: _paymentLinesExpectedMinor(paymentLines),
          currencyDigits: _uniformCurrencyDigits(paymentLines),
        )) {
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

  Future<bool> _existingPaymentApplied(
    String commandId, {
    int? saleId,
    int? expectedAmountMinor,
    int? currencyDigits,
  }) async {
    if (saleId == null || saleId <= 0) return false;
    final rows = await actions.call(
      model: 'l10n_ec_collection_box.sale.order.payment',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['sale_id', '=', saleId],
          ['pos_collection_op_uuid', '=', commandId],
        ],
        'fields': [
          'id',
          'sale_id',
          'state',
          'move_id',
          'amount',
          'pos_collection_op_uuid',
        ],
        'limit': 100,
      },
    );
    if (rows is! List || rows.isEmpty || rows.any((row) => row is! Map)) {
      return false;
    }
    if (!rows.every((row) {
      final value = Map<String, dynamic>.from(row as Map);
      final move = value['move_id'];
      final remoteSale = _relationIdValue(value['sale_id']);
      return value['state'] == 'posted' &&
          value['pos_collection_op_uuid'] == commandId &&
          remoteSale == saleId &&
          move is List &&
          move.isNotEmpty &&
          _positiveIntValue(move.first) != null;
    })) {
      return false;
    }
    if (expectedAmountMinor == null) return true;
    // Mixed currency scales cannot be compared safely against one minor-unit
    // total. Treat that as incomplete evidence instead of guessing 2 digits.
    if (currencyDigits == null) return false;
    final digits = currencyDigits;
    var actualMinor = 0;
    for (final row in rows.cast<Map>()) {
      final amount = row['amount'];
      if (amount is! num || !amount.isFinite || amount <= 0) return false;
      actualMinor += _toMinor(amount, digits);
    }
    return actualMinor == expectedAmountMinor;
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
    if (typed && !numberedByClient) {
      // The native wizard has no operation UUID field outside its fiscal
      // identity path. A mixed/server-numbered call would therefore be
      // non-replayable after an ambiguous response; fail before creating it.
      return OperationOutcome(
        commandId: commandId,
        entity: order,
        businessState: SaleOrderState.sale,
        syncState: OperationSyncState.failed,
        issues: [
          OperationIssue(
            code: 'mixed_requires_numbered_identity',
            messageKey: 'sale.mixed_requires_numbered_identity',
            retryable: false,
          ),
        ],
      );
    }
    final result = typed
        ? await _applyNativePaymentWizard(
            saleId: id,
            commandId: commandId,
            paymentLines: paymentLines,
            collectionSessionId: collectionSessionId,
            numberedByClient: numberedByClient,
            sequential: sequential,
            emissionDate: emissionDate,
            accessKey: accessKey,
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
              if (numberedByClient) ...{
                'sequential': sequential,
                'emission_date': emissionDate,
                'access_key': accessKey,
              },
              'client_op_uuid': commandId,
            },
          );
    if (_rejected(result)) {
      final approval = _approvalPending(result);
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
    required bool numberedByClient,
    int? sequential,
    String? emissionDate,
    String? accessKey,
  }) async {
    // `pos_client_op_uuid` is part of the POS fiscal identity contract in
    // Odoo, not a generic transient-wizard idempotency field. Sending it for
    // a journal that is not numbered by the client makes the native wizard
    // enter its offline-number validation path and fail closed.
    if (numberedByClient &&
        !OfflineFiscalInvoicePayload(
          sequential: sequential,
          emissionDate: emissionDate,
          accessKey: accessKey,
        ).isComplete) {
      throw StateError('numbered payment wizard requires fiscal identity');
    }
    final wizard = await actions.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'sale_id': saleId,
            ...?_present('collection_session_id', collectionSessionId),
            if (numberedByClient) ...{
              'pos_client_sequential': sequential,
              'pos_emission_date': emissionDate,
              'pos_access_key': accessKey,
              'pos_client_op_uuid': commandId,
            },
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
          'amount_residual',
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
          !_amountMatches(row['amount_total'], expectedAmountMinor) ||
          !_isCurrencyZeroValue(row['amount_residual'], 2)) {
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

bool _isCurrencyZeroValue(dynamic raw, int digits) {
  if (raw is! num || !raw.isFinite) return false;
  return _toMinor(raw, digits) == 0;
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

/// JSON-2 serializes Many2one values as `[id, display_name]` while small
/// fakes/older adapters may expose the bare integer. Accept both shapes, but
/// never coerce arbitrary strings or names into an id.
int? _relationIdValue(dynamic value) {
  final direct = _positiveIntValue(value);
  if (direct != null) return direct;
  if (value is List && value.isNotEmpty) {
    return _positiveIntValue(value.first);
  }
  return null;
}

int? _paymentLinesExpectedMinor(List<SalePaymentLinePayload> lines) {
  if (lines.isEmpty) return null;
  var total = 0;
  for (final line in lines) {
    if (line.amountMinor <= 0) return null;
    total += line.amountMinor;
  }
  return total > 0 ? total : null;
}

int? _uniformCurrencyDigits(List<SalePaymentLinePayload> lines) {
  if (lines.isEmpty) return null;
  final digits = lines.first.currencyDigits;
  return lines.every((line) => line.currencyDigits == digits) ? digits : null;
}

int _toMinor(num amount, int currencyDigits) {
  return (amount * math.pow(10, currencyDigits)).round();
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

/// Perfil de ventas del servidor Odoo conectado: si trae o no
/// `l10n_ec_collection_box_pos` (el módulo propio de POS). Decisión del
/// dueño (14-sep-2026): sin ese módulo, Orbi ofrece ventas estándar —
/// `create` sin `x_uuid` y confirmación con `action_confirm`; con el
/// módulo, el camino de siempre.
final class SaleServerProfile {
  const SaleServerProfile({required this.hasPosExtension});

  /// `true` sólo cuando TANTO `sale.order` COMO `sale.order.line` exponen
  /// `x_uuid`. Un servidor a medio migrar (uno de los dos modelos sin el
  /// campo) no cuenta como servidor con la extensión: mandar `x_uuid` sólo
  /// a uno de los dos `create` dejaría el pedido y sus líneas en contratos
  /// distintos.
  final bool hasPosExtension;
}

/// Sondea, con evidencia (`fields_get`), si el servidor tiene la extensión
/// de POS de ventas — nunca lo asume de un hint de versión, igual que
/// `odoo_capabilities_detector.dart` para capacidades por versión. Memoriza
/// el resultado en memoria mientras esta instancia viva (una por
/// cliente/sesión en la composición real); un fallo de red NUNCA se
/// memoriza, así que la siguiente operación vuelve a sondear — mismo
/// principio que `EnvasesOperationsDurable._resolveWizardReplayPolicy` en
/// `envases_operations_durable.dart`, sólo que aquí un sondeo fallido no
/// tiene un valor por omisión seguro: mientras no se sepa, no se manda
/// nada.
final class SaleServerProfileResolver {
  SaleServerProfileResolver(this._actions);
  final SaleOdooActions _actions;
  SaleServerProfile? _cached;

  Future<SaleServerProfile> resolve() async {
    final cached = _cached;
    if (cached != null) return cached;
    final orderHasUuid = await _probeHasUuid('sale.order');
    final lineHasUuid = await _probeHasUuid('sale.order.line');
    final profile = SaleServerProfile(
      hasPosExtension: orderHasUuid && lineHasUuid,
    );
    _cached = profile;
    return profile;
  }

  Future<bool> _probeHasUuid(String model) async {
    final metadata = await _actions.call(
      model: model,
      method: 'fields_get',
      kwargs: const {
        'attributes': ['type'],
      },
    );
    return metadata is Map && metadata.containsKey('x_uuid');
  }
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
    SaleServerProfileResolver? profileResolver,
  }) : _profile = profileResolver ?? SaleServerProfileResolver(actions);

  final SaleOdooActions actions;
  final AppDatabase database;
  final AppScope scope;
  final OfflineQueueDataSource queue;
  final SaleServerProfileResolver _profile;

  /// Sondea el perfil del servidor y, si el sondeo mismo falla (sin red),
  /// lo trata exactamente como cualquier otra falla transitoria de la cola:
  /// la operación queda pendiente de reintento sin haberse enviado, nunca
  /// en revisión manual por una ambigüedad que no ocurrió.
  Future<SaleServerProfile> _resolveProfile() async {
    try {
      return await _profile.resolve();
    } catch (error) {
      throw RetryableOfflineOperationException(
        'No se pudo determinar si el servidor tiene la extensión de POS '
        'de ventas: $error',
      );
    }
  }

  @override
  Future<OperationReconciliation> reconcile(OfflineOperation operation) async {
    _checkScope(operation);
    // `res.users`/`res.partner` `write` (preferencias personales del
    // usuario) y `res.users.mobile_set_im_status` (presencia) son
    // idempotentes: repetir la misma escritura de campos, o el mismo
    // estado manual, es inofensivo. No hay un marcador de servidor que
    // consultar antes de reintentar, a diferencia de un pago o el cierre de
    // una sesión de caja.
    if ((operation.model == 'res.users' || operation.model == 'res.partner') &&
        operation.method == 'write') {
      return const OperationNotApplied();
    }
    if (operation.model == 'res.users' &&
        operation.method == 'mobile_set_im_status') {
      return const OperationNotApplied();
    }
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
    if (operation.model == 'collection.session.deposit' &&
        operation.method == 'action_create_accounting_entry') {
      final id = await _remoteId(operation);
      if (id == null) return const OperationNotApplied();
      final moveId = await _depositMoveId(id);
      if (moveId == null) return const OperationNotApplied();
      await _persistDepositAccounting(operation, moveId);
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
    // Preferencias personales (`res.users`/`res.partner` `write`): el diff
    // ya viene limpio de marcadores internos (`user_preferences.dart` nunca
    // los mete en `values`), así que se manda tal cual como `vals`.
    if ((operation.model == 'res.users' || operation.model == 'res.partner') &&
        operation.method == 'write') {
      final recordId = operation.recordId;
      if (recordId == null) {
        throw StateError('${operation.model}.write requiere recordId');
      }
      final result = await actions.call(
        model: operation.model,
        method: 'write',
        ids: [recordId],
        kwargs: {'vals': values},
      );
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
      return null;
    }
    // Presencia (`mobile_set_im_status`): sin `ids` — es `@api.model`,
    // opera sobre `self.env.user` (igual que en `UserPresencePort` antes de
    // que este cambio la moviera a la cola).
    if (operation.model == 'res.users' &&
        operation.method == 'mobile_set_im_status') {
      final status = values['status'];
      if (status is! String) {
        throw StateError('mobile_set_im_status requiere un status string');
      }
      await actions.call(
        model: 'res.users',
        method: 'mobile_set_im_status',
        kwargs: {'status': status},
      );
      return null;
    }
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
    if (operation.model == 'collection.session.deposit' &&
        operation.method == 'action_create_accounting_entry') {
      if (id == null) {
        throw StateError('deposit remote id unavailable');
      }
      result = await actions.call(
        model: operation.model,
        method: operation.method,
        ids: [id],
      );
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
      final moveId = await _depositMoveId(id);
      // Odoo may acknowledge the action before the move is visible. Keep the
      // action pending and the local deposit unaccounted until move_id exists.
      if (moveId == null) {
        return ConflictInfo(
          operationId: operation.id,
          model: operation.model,
          recordId: operation.recordId,
          localWriteDate: operation.createdAt,
          serverWriteDate: DateTime.now().toUtc(),
          localValues: Map<String, dynamic>.from(values),
        );
      }
      await _persistDepositAccounting(operation, moveId);
      return null;
    } else if (operation.model == 'collection.session' &&
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
      final numberedMarker = values['numberedByClient'];
      if (numberedMarker is! bool) {
        throw StateError(
          'cashInvoice requires an explicit numberedByClient contract flag',
        );
      }
      final numberedByClient = numberedMarker;
      // Fiscal identity belongs to the numbered-by-client contract. A stale
      // identity in an older queue row must not accidentally switch a normal
      // journal into the POS fiscal path.
      if (numberedByClient) {
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
        if (!numberedByClient) {
          // The POS wizard treats pos_client_op_uuid as fiscal identity. A
          // server-numbered mixed operation has no native UUID marker that
          // this durable adapter can reconcile after a timeout; do not create
          // a payment that cannot be replayed safely.
          throw StateError(
            'durable mixed payment requires numberedByClient for replay',
          );
        }
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
                if (numberedByClient) ...{
                  // This is the native fiscal identity consumed by the
                  // existing payment wizard, not a second payment record.
                  'pos_client_sequential': fiscal.sequential,
                  'pos_emission_date': fiscal.emissionDate,
                  'pos_access_key': fiscal.accessKey,
                  'pos_client_op_uuid': values['commandId'],
                },
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
      final profile = await _resolveProfile();
      result = await actions.call(
        model: 'sale.order',
        // La cola siempre guarda 'action_pos_confirm' como marcador de
        // intención de confirmar (ver `DriftSaleCommandStore`); el método
        // real que viaja a Odoo lo decide el perfil del servidor, no el
        // texto guardado.
        method: profile.hasPosExtension ? 'action_pos_confirm' : 'action_confirm',
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
      if (lines.any(
        (line) =>
            line['pos_collection_line_uuid'] is! String ||
            (line['pos_collection_line_uuid'] as String).isEmpty,
      )) {
        throw StateError(
          'existing invoice collection requires native line UUIDs',
        );
      }
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
    if (operation.method == 'cashInvoice' &&
        !await _cashInvoiceApplied(operation)) {
      // The action response is not proof of accounting completion. Do not
      // mark local payment lines applied until the posted, fully reconciled
      // native invoice is visible server-side.
      throw const AmbiguousOperationException(
        'cash invoice response lacked posted, zero-residual evidence',
      );
    }
    if (operation.method == 'existingInvoice' &&
        !await _existingInvoiceApplied(operation)) {
      throw const AmbiguousOperationException(
        'collection response lacked native posted-payment evidence',
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
    var result = await actions.call(
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
          'amount_residual',
          'l10n_ec_pos_collection_completed',
        ],
        'limit': 1,
      },
    );
    // Classic (server-numbered) POS invoices intentionally do not persist the
    // client UUID on account.move. Reconcile those through the sale's native
    // invoice relation instead of inventing a second marker or declaring the
    // already-paid sale ambiguous forever.
    if ((result is! List || result.isEmpty) &&
        operation.values['numberedByClient'] != true) {
      final saleId = _positiveInt(operation.values['saleOrderRemoteId']);
      if (saleId != null) {
        final saleRows = await actions.call(
          model: 'sale.order',
          method: 'search_read',
          kwargs: {
            'domain': [
              ['id', '=', saleId],
            ],
            'fields': ['id', 'invoice_ids'],
            'limit': 1,
          },
        );
        final invoiceIds = <int>[];
        if (saleRows is List && saleRows.length == 1 && saleRows.first is Map) {
          final rawIds = (saleRows.first as Map)['invoice_ids'];
          if (rawIds is List) {
            for (final rawId in rawIds) {
              final invoiceId = _positiveInt(rawId);
              if (invoiceId != null) invoiceIds.add(invoiceId);
            }
          }
        }
        if (invoiceIds.length == 1) {
          result = await actions.call(
            model: 'account.move',
            method: 'search_read',
            kwargs: {
              'domain': [
                ['id', '=', invoiceIds.single],
                ['move_type', '=', 'out_invoice'],
                ['state', '=', 'posted'],
              ],
              'fields': [
                'id',
                'state',
                'payment_state',
                'amount_total',
                'amount_residual',
                'l10n_ec_pos_collection_completed',
              ],
              'limit': 1,
            },
          );
        }
      }
    }
    if (result is! List || result.length != 1 || result.first is! Map) {
      return false;
    }
    final row = Map<String, dynamic>.from(result.first as Map);
    final requiresFiscalMarker = operation.values['numberedByClient'] == true;
    final completed =
        !requiresFiscalMarker ||
        row['l10n_ec_pos_collection_completed'] == true;
    final paymentState = row['payment_state'];
    final paid = paymentState == 'paid';
    final total = row['amount_total'];
    final residual = row['amount_residual'];
    final actualMinor = total is num
        ? _toMinor(total, _currencyDigits(operation.values))
        : null;
    return completed &&
        paid &&
        actualMinor == expectedMinor &&
        _isCurrencyZero(residual, _currencyDigits(operation.values));
  }

  Future<bool> _existingInvoiceApplied(OfflineOperation operation) async {
    final commandId = operation.values['commandId'];
    if (commandId is! String || commandId.isEmpty) return false;
    final result = await actions.call(
      model: 'l10n_ec_collection_box.sale.order.payment',
      method: 'search_read',
      kwargs: {
        'domain': [
          if (_positiveInt(operation.values['saleOrderRemoteId']) != null)
            [
              'sale_id',
              '=',
              _positiveInt(operation.values['saleOrderRemoteId']),
            ],
          ['pos_collection_op_uuid', '=', commandId],
        ],
        'fields': [
          'id',
          'sale_id',
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
          _positiveInt(move.first) == null ||
          line['pos_collection_op_uuid'] != commandId;
    })) {
      return false;
    }
    final saleId = _positiveInt(operation.values['saleOrderRemoteId']);
    if (saleId != null &&
        lines.any((line) => _relationIdValue(line['sale_id']) != saleId)) {
      return false;
    }
    final lineUuids = lines
        .map((line) => line['pos_collection_line_uuid'])
        .whereType<String>()
        .where((uuid) => uuid.isNotEmpty)
        .toSet();
    if (lineUuids.length != lines.length) return false;
    final expectedLineUuids = await _operationPaymentLineUuids(operation);
    if (expectedLineUuids != null &&
        (lineUuids.length != expectedLineUuids.length ||
            !lineUuids.containsAll(expectedLineUuids))) {
      return false;
    }
    final expectedMinor = await _operationPaymentLinesExpectedMinor(operation);
    if (expectedMinor == null) return true;
    var actualMinor = 0;
    for (final line in lines) {
      final amount = line['amount'];
      if (amount is! num || !amount.isFinite || amount <= 0) return false;
      actualMinor += _toMinor(amount, _currencyDigits(operation.values));
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
      total += _toMinor(row.amount, _currencyDigits(operation.values));
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

  static int _currencyDigits(Map<String, dynamic> values) {
    final raw = values['currencyDigits'];
    return raw is num && raw.toInt() >= 0 && raw.toInt() <= 6 ? raw.toInt() : 2;
  }

  static bool _isCurrencyZero(dynamic raw, int digits) {
    if (raw is! num || !raw.isFinite) return false;
    return _toMinor(raw, digits) == 0;
  }

  Future<Set<String>?> _operationPaymentLineUuids(
    OfflineOperation operation,
  ) async {
    final ids = operation.values['paymentLineIds'];
    if (ids is! List || ids.isEmpty) return null;
    final result = <String>{};
    for (final rawId in ids) {
      final localId = _positiveInt(rawId);
      if (localId == null) return null;
      final row = await (database.select(
        database.saleOrderPaymentLine,
      )..where((table) => table.id.equals(localId))).getSingleOrNull();
      final uuid = row?.lineUuid;
      if (uuid == null || uuid.isEmpty) return null;
      result.add(uuid);
    }
    return result.length == ids.length ? result : null;
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
          final digits = entry['currencyDigits'];
          final currencyDigits = digits is num && digits.toInt() >= 0
              ? digits.toInt()
              : 2;
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
            'amount': amountMinor / math.pow(10, currencyDigits),
            if (_positiveInt(entry['advanceId']) != null)
              'advance_id': _positiveInt(entry['advanceId']),
            if (_positiveInt(entry['creditNoteId']) != null)
              'credit_note_id': _positiveInt(entry['creditNoteId']),
            if (_positiveInt(entry['paymentMethodLineId']) != null)
              'payment_method_line_id': _positiveInt(
                entry['paymentMethodLineId'],
              ),
            if (entry['collectionLineUuid'] is String &&
                (entry['collectionLineUuid'] as String).isNotEmpty)
              'pos_collection_line_uuid': entry['collectionLineUuid'],
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
          'amountMinor': _toMinor(row.amount, _currencyDigits(operation.values)),
          'advanceId': row.advanceId,
          'creditNoteId': row.creditNoteId,
          'paymentMethodLineId': row.paymentMethodLineId,
          'currencyDigits': _currencyDigits(operation.values),
          'collectionLineUuid': row.lineUuid,
        },
    ]);
  }

  Future<void> _ensureOperationWithholdLines(
    int saleId,
    OfflineOperation operation,
  ) async {
    final ids = operation.values['withholdLineIds'];
    if (ids is List) {
      // Native rows already have one official create intent each. Require
      // every line to have completed that intent before applying the parent
      // wizard; otherwise a payment could commit without its retention.
      for (final rawId in ids) {
        final localId = _positiveInt(rawId);
        if (localId == null) {
          throw StateError('withhold line id missing before payment apply');
        }
        final row = await (database.select(
          database.saleOrderWithholdLine,
        )..where((table) => table.id.equals(localId))).getSingleOrNull();
        if (row == null || !row.isSynced || (row.odooId ?? 0) <= 0) {
          throw StateError(
            'withhold line $localId is not synchronized before payment apply',
          );
        }
      }
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
    final profile = await _resolveProfile();
    final fields = <String, dynamic>{
      'name': row.name,
      // Decisión del dueño (14-sep-2026): sin `l10n_ec_collection_box_pos`
      // el modelo no tiene `x_uuid` y Odoo rechaza el `create` entero con
      // «Invalid field» si se manda. Sin esa clave idempotente, un create
      // ambiguo en un servidor estándar queda para revisión manual — ver
      // `_findCreatedId`, que no sondea `x_uuid` cuando falta la extensión.
      if (profile.hasPosExtension) 'x_uuid': row.xUuid ?? row.orderUuid,
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
    // Decisión del dueño (14-sep-2026): Odoo fija precio e impuestos. En Odoo
    // 19.5, `price_unit`, `discount`, `product_uom_id` y `tax_ids` de la línea
    // son campos calculados, guardados y editables (`sale_order_line.py`), así
    // que lo que no se manda lo calcula Odoo al crear con la tarifa y la
    // posición fiscal del pedido — incluidas las posiciones automáticas, que
    // la app no replica. Por eso no viajan ni el precio ni los impuestos que
    // estimó el equipo, y el descuento sólo si el vendedor puso uno.
    // Los nombres son los de 19.5: `product_uom` y `tax_id` ya no existen, y
    // Odoo rechaza la línea entera con «Invalid field» si llegan.
    final profile = await _resolveProfile();
    return {
      'order_id': orderId,
      if (profile.hasPosExtension) 'x_uuid': line.xUuid ?? line.lineUuid,
      'name': line.name,
      if (line.productId != null && line.productId! > 0)
        'product_id': line.productId,
      if (line.productUomId != null && line.productUomId! > 0)
        'product_uom_id': line.productUomId,
      'product_uom_qty': line.productUomQty,
      if (line.discount > 0) 'discount': line.discount,
    };
  }

  Future<int?> _findCreatedId(OfflineOperation operation) async {
    final marked = _positiveInt(operation.values['_remote_create_id']);
    if (marked != null) return marked;
    final profile = await _resolveProfile();
    // Sin `l10n_ec_collection_box_pos` no hay `x_uuid` que sondear: un
    // create ambiguo en un servidor estándar no tiene clave idempotente
    // verificable, así que se declara no aplicada y la ambigüedad queda
    // para revisión manual en vez de reintentarse sola.
    if (!profile.hasPosExtension) return null;
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

  Future<int?> _depositMoveId(int remoteId) async {
    final result = await actions.call(
      model: 'collection.session.deposit',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['id', '=', remoteId],
        ],
        'fields': ['id', 'move_id'],
        'limit': 1,
      },
    );
    if (result is! List || result.length != 1 || result.first is! Map) {
      return null;
    }
    final move = (result.first as Map)['move_id'];
    if (move is List && move.isNotEmpty) return _positiveInt(move.first);
    return _positiveInt(move);
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

  Future<void> _persistDepositAccounting(
    OfflineOperation operation,
    int moveId,
  ) async {
    // Deposits are created with a negative local id until Odoo assigns the
    // durable record id. Keep that local identity while recording the move.
    final localId = operation.values['local_id'];
    if (localId is! int || localId == 0 || moveId <= 0) return;
    await (database.update(
      database.collectionSessionDeposit,
    )..where((table) => table.id.equals(localId))).write(
      CollectionSessionDepositCompanion(
        moveId: drift.Value(moveId),
        state: const drift.Value('posted'),
        isSynced: const drift.Value(true),
        lastSyncDate: drift.Value(DateTime.now().toUtc()),
      ),
    );
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

bool _approvalPending(dynamic result) {
  if (result is! Map || result['approval_required'] != true) return false;
  final status =
      result['approval_status'] ?? result['request_status'] ?? result['status'];
  return status != 'refused' &&
      status != 'rejected' &&
      result['approval_rejected'] != true &&
      result['rejected'] != true;
}

Map<String, dynamic>? _present(String key, dynamic value) =>
    value == null ? null : {key: value};

/// Maps the existing POS facade response without claiming that the remote
/// transaction is complete when the server asks for approval or is ambiguous.
final class OdooSaleConfirmationAdapter {
  OdooSaleConfirmationAdapter(
    this.actions,
    this.versions, {
    this.states,
    SaleServerProfileResolver? profileResolver,
  }) : _profile = profileResolver ?? SaleServerProfileResolver(actions);

  final SaleOdooActions actions;
  final SaleRemoteVersionReader versions;
  final SaleRemoteConfirmationReader? states;
  final SaleServerProfileResolver _profile;

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
    // El sondeo del perfil va en SU PROPIO `try`, separado del de la
    // confirmación real: si `fields_get` falla, no se mandó nada a Odoo —
    // decir "ambiguo" (que implica "no sabemos si llegó a mutar el pedido")
    // mandaría a revisión manual algo que ni siquiera salió del equipo.
    final SaleServerProfile profile;
    try {
      profile = await _profile.resolve();
    } catch (_) {
      return OperationOutcome(
        commandId: commandId,
        entity: order,
        businessState: SaleOrderState.approved,
        syncState: OperationSyncState.failed,
        issues: [
          OperationIssue(
            code: 'server_profile_unknown',
            messageKey: 'sale.server_profile_unknown',
            retryable: true,
          ),
        ],
      );
    }
    dynamic result;
    try {
      result = await actions.call(
        model: 'sale.order',
        method: profile.hasPosExtension ? 'action_pos_confirm' : 'action_confirm',
        ids: [remoteId],
      );
    } on OdooMethodNotFoundException {
      if (profile.hasPosExtension) {
        // La extensión dijo estar (el sondeo encontró `x_uuid` en los dos
        // modelos) pero el método propio de POS no existe: es una
        // inconsistencia permanente del servidor, no una confirmación
        // ambigua — no se reintenta sola ni se cae en silencio a
        // `action_confirm`.
        return OperationOutcome(
          commandId: commandId,
          entity: order,
          businessState: SaleOrderState.approved,
          syncState: OperationSyncState.failed,
          issues: [
            OperationIssue(
              code: 'pos_confirmation_unsupported',
              messageKey: 'sale.pos_confirmation_unsupported',
              retryable: false,
            ),
          ],
        );
      }
      return _ambiguousConfirmation(order: order, commandId: commandId);
    } catch (_) {
      return _ambiguousConfirmation(order: order, commandId: commandId);
    }
    if (_rejected(result)) {
      final approval = _approvalPending(result);
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

  Future<OperationOutcome<SaleOrderState>> _ambiguousConfirmation({
    required EntityReference order,
    required String commandId,
  }) async {
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
}

abstract interface class SaleRemoteVersionReader {
  Future<int> read(EntityReference order);
}

abstract interface class SaleRemoteConfirmationReader {
  Future<SaleOrderState?> read(EntityReference order);
}
