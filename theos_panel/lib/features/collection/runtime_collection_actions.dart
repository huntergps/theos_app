import 'package:orbi_runtime/orbi_runtime.dart';

import 'collection_contracts.dart';

/// Composition bridge: all remote behavior remains in orbi_runtime adapters.
final class RuntimeCollectionActions
    implements CollectionActions, CollectionShiftCountActions {
  final OdooSaleCollectionPort? sales;
  final OdooCollectionSessionStore sessions;
  final OfflineQueueStore? queue;
  final DurableCollectionProducer? producer;
  final String scopeKey;

  /// `l10n_ec_collection_box.group_collection_manager` ("Supervisor de
  /// Caja") en el dispositivo autenticado — ver el docstring de
  /// `DurableCollectionProducer.closeWithCount` para por qué el cierre
  /// necesita saberlo antes de encolar nada.
  final bool hasCollectionSupervisor;
  const RuntimeCollectionActions({
    required this.sales,
    required this.sessions,
    required this.scopeKey,
    this.queue,
    this.producer,
    this.hasCollectionSupervisor = false,
  });

  @override
  Future<CollectionShiftSnapshot> open(CollectionShiftSnapshot shift) =>
      _shift(shift, SaleShiftState.open);
  @override
  Future<CollectionShiftSnapshot> close(CollectionShiftSnapshot shift) =>
      _shift(shift, SaleShiftState.closed);

  @override
  Future<CollectionShiftCloseResult> closeWithCount(
    CollectionShiftSnapshot shift,
    CollectionCashCount count,
  ) async {
    final durable = producer;
    if (durable == null || !count.isValid) {
      return CollectionShiftCloseResult(
        shift: shift,
        result: CollectionResultState.conflict,
        message: 'El conteo requiere la cola durable del punto de cobro.',
      );
    }
    final sessionId = int.tryParse(shift.id);
    if (sessionId == null || sessionId <= 0) {
      return CollectionShiftCloseResult(
        shift: shift,
        result: CollectionResultState.conflict,
        message: 'El turno local aún no tiene un ID remoto.',
      );
    }
    final result = await durable.closeWithCount(
      commandId: 'shift-close-$scopeKey-$sessionId',
      sessionId: sessionId,
      hasCollectionSupervisor: hasCollectionSupervisor,
      count: DurableCashCount(
        bills100: count.bills100,
        bills50: count.bills50,
        bills20: count.bills20,
        bills10: count.bills10,
        bills5: count.bills5,
        bills1: count.bills1,
        coins1: count.coins1,
        coins50: count.coins50,
        coins25: count.coins25,
        coins10: count.coins10,
        coins5: count.coins5,
        coins1Cent: count.coins1Cent,
        notes: count.notes,
        expectedBalanceMinor: count.expectedBalanceMinor,
      ),
    );
    final next = CollectionShiftSnapshot(
      id: shift.id,
      state: result.state == DurableCollectionState.queued
          ? CollectionShiftState.closing
          : CollectionShiftState.conflict,
      expectedVersion: shift.expectedVersion,
      expectedBalanceMinor: shift.expectedBalanceMinor,
      differenceMinor: result.differenceMinor,
    );
    return CollectionShiftCloseResult(
      shift: next,
      result: result.state == DurableCollectionState.queued
          ? CollectionResultState.queued
          : CollectionResultState.conflict,
      message: result.message,
    );
  }

  Future<CollectionShiftSnapshot> _shift(
    CollectionShiftSnapshot shift,
    SaleShiftState state,
  ) async {
    final outcome = await sessions.apply(
      commandId: 'shift-${shift.id}-${state.name}',
      shift: EntityReference(
        localId: shift.id,
        remoteId: int.tryParse(shift.id),
      ),
      expectedVersion: shift.expectedVersion,
      state: state,
    );
    final queued = outcome.syncState == OperationSyncState.queued;
    return CollectionShiftSnapshot(
      id: shift.id,
      state: outcome.syncState == OperationSyncState.conflict
          ? CollectionShiftState.conflict
          : queued && state == SaleShiftState.closed
          ? CollectionShiftState.closing
          : state == SaleShiftState.open
          ? CollectionShiftState.opened
          : CollectionShiftState.closed,
      expectedVersion: shift.expectedVersion,
      expectedBalanceMinor: shift.expectedBalanceMinor,
    );
  }

  @override
  Future<CollectionResultState> collect(
    CollectionPendingSale sale,
    List<CollectionPaymentDraft> payments,
  ) async {
    final remoteId = sale.remoteId;
    final commandId = sale.commandId;
    if (remoteId == null || commandId == null) {
      return CollectionResultState.conflict;
    }
    final remoteSales = sales;
    if (remoteSales == null) {
      return _enqueue(sale, payments, commandId, remoteId);
    }
    final order = EntityReference(localId: sale.id, remoteId: remoteId);
    final result = sale.route == CollectionSaleRoute.existingInvoice
        ? (sale.wizardId == null
              ? null
              : await remoteSales.collectExistingInvoice(
                  order: order,
                  commandId: commandId,
                  wizardId: sale.wizardId!,
                  paymentLines: payments
                      .map(
                        (p) => SalePaymentLinePayload(
                          journalId: p.journalId,
                          amountMinor: p.amountMinor,
                          type: switch (p.kind) {
                            CollectionPaymentLineKind.payment => 'payment',
                            CollectionPaymentLineKind.advance => 'advance',
                            CollectionPaymentLineKind.creditNote =>
                              'credit_note',
                          },
                          advanceId: p.advanceId,
                          creditNoteId: p.creditNoteId,
                          paymentMethodLineId: p.paymentMethodLineId,
                        ),
                      )
                      .toList(),
                ))
        : await remoteSales.confirmAndInvoice(
            order: order,
            commandId: commandId,
            collectionSessionId: sale.collectionSessionId,
            numberedByClient: sale.numberedByClient,
            sequential: sale.numberedByClient ? sale.sequential : null,
            emissionDate: sale.numberedByClient ? sale.emissionDate : null,
            accessKey: sale.numberedByClient ? sale.accessKey : null,
            paymentLines: payments
                .map(
                  (p) => SalePaymentLinePayload(
                    journalId: p.journalId,
                    amountMinor: p.amountMinor,
                    type: switch (p.kind) {
                      CollectionPaymentLineKind.payment => 'payment',
                      CollectionPaymentLineKind.advance => 'advance',
                      CollectionPaymentLineKind.creditNote => 'credit_note',
                    },
                    advanceId: p.advanceId,
                    creditNoteId: p.creditNoteId,
                    paymentMethodLineId: p.paymentMethodLineId,
                  ),
                )
                .toList(),
          );
    if (result == null) return CollectionResultState.conflict;
    return switch (result.syncState) {
      OperationSyncState.synced => CollectionResultState.synced,
      OperationSyncState.queued => CollectionResultState.queued,
      OperationSyncState.conflict => CollectionResultState.ambiguous,
      _ => CollectionResultState.conflict,
    };
  }

  Future<CollectionResultState> _enqueue(
    CollectionPendingSale sale,
    List<CollectionPaymentDraft> payments,
    String commandId,
    int remoteId,
  ) async {
    final store = queue;
    if (store == null || remoteId <= 0) return CollectionResultState.conflict;
    if (sale.route == CollectionSaleRoute.existingInvoice) {
      final wizardId = sale.wizardId;
      if (payments.isEmpty ||
          payments.any((payment) {
            if (payment.amountMinor <= 0) return true;
            if (payment.kind == CollectionPaymentLineKind.payment) {
              return payment.journalId <= 0;
            }
            return payment.kind == CollectionPaymentLineKind.advance
                ? payment.advanceId == null || payment.advanceId! <= 0
                : payment.creditNoteId == null || payment.creditNoteId! <= 0;
          })) {
        return CollectionResultState.conflict;
      }
      final durable = producer;
      if (durable != null) {
        final result = await durable.enqueueCollectionIntent(
          commandId: commandId,
          saleOrderId: remoteId,
          method: 'existingInvoice',
          amountMinor: sale.amountMinor,
          wizardId: wizardId,
          collectionSessionId: sale.collectionSessionId,
          scopeKey: scopeKey,
          paymentLines: _durablePayments(payments),
          withholdLines: _durableWithholds(sale.cachedWithholds),
        );
        return result.state == DurableCollectionState.queued
            ? CollectionResultState.queued
            : CollectionResultState.conflict;
      }
      await store.queueOperation(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'existingInvoice',
        recordId: wizardId ?? remoteId,
        values: {
          'commandId': commandId,
          'scopeKey': scopeKey,
          'saleOrderRemoteId': remoteId,
          if (sale.collectionSessionId != null)
            'collectionSessionId': sale.collectionSessionId,
          ...?_presentValue('wizardId', wizardId),
          'paymentLines': [
            for (final payment in payments)
              {
                'journalId': payment.journalId,
                'amountMinor': payment.amountMinor,
                'type': switch (payment.kind) {
                  CollectionPaymentLineKind.payment => 'payment',
                  CollectionPaymentLineKind.advance => 'advance',
                  CollectionPaymentLineKind.creditNote => 'credit_note',
                },
                if (payment.advanceId != null) 'advanceId': payment.advanceId,
                if (payment.creditNoteId != null)
                  'creditNoteId': payment.creditNoteId,
                if (payment.paymentMethodLineId != null)
                  'paymentMethodLineId': payment.paymentMethodLineId,
              },
          ],
          if (sale.cachedWithholds.isNotEmpty)
            'withholdLines': [
              for (final line in sale.cachedWithholds)
                {
                  'uuid': line.uuid,
                  'tax_id': line.taxId,
                  'baseMinor': line.baseMinor,
                  'amountMinor': line.amountMinor,
                  if (line.taxsupportCode != null)
                    'taxsupport_code': line.taxsupportCode,
                  if (line.notes != null) 'notes': line.notes,
                },
            ],
          'amountMinor': sale.amountMinor,
        },
        operationKey: commandId,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      return CollectionResultState.queued;
    }
    if (payments.isEmpty ||
        payments.any((payment) {
          if (payment.amountMinor <= 0) return true;
          if (payment.kind == CollectionPaymentLineKind.payment) {
            return payment.journalId <= 0;
          }
          return payment.kind == CollectionPaymentLineKind.advance
              ? payment.advanceId == null || payment.advanceId! <= 0
              : payment.creditNoteId == null || payment.creditNoteId! <= 0;
        })) {
      return CollectionResultState.conflict;
    }
    if (sale.numberedByClient) {
      final fiscal = OfflineFiscalInvoicePayload(
        sequential: sale.sequential,
        emissionDate: sale.emissionDate,
        accessKey: sale.accessKey,
      );
      if (!fiscal.isComplete) return CollectionResultState.conflict;
    }
    final durable = producer;
    if (durable != null) {
      final result = await durable.enqueueCollectionIntent(
        commandId: commandId,
        saleOrderId: remoteId,
        method: 'cashInvoice',
        amountMinor: sale.amountMinor,
        collectionSessionId: sale.collectionSessionId,
        numberedByClient: sale.numberedByClient,
        sequential: sale.sequential,
        emissionDate: sale.emissionDate,
        accessKey: sale.accessKey,
        scopeKey: scopeKey,
        paymentLines: _durablePayments(payments),
        withholdLines: _durableWithholds(sale.cachedWithholds),
      );
      return result.state == DurableCollectionState.queued
          ? CollectionResultState.queued
          : CollectionResultState.conflict;
    }
    await store.queueOperation(
      model: 'sale.order',
      method: 'cashInvoice',
      recordId: remoteId,
      values: {
        'commandId': commandId,
        'scopeKey': scopeKey,
        'saleOrderRemoteId': remoteId,
        if (sale.collectionSessionId != null)
          'collectionSessionId': sale.collectionSessionId,
        'numberedByClient': sale.numberedByClient,
        if (sale.numberedByClient) ...{
          'sequential': sale.sequential,
          'emissionDate': sale.emissionDate,
          'accessKey': sale.accessKey,
        },
        'paymentLines': [
          for (final payment in payments)
            {
              'journalId': payment.journalId,
              'amountMinor': payment.amountMinor,
              'type': switch (payment.kind) {
                CollectionPaymentLineKind.payment => 'payment',
                CollectionPaymentLineKind.advance => 'advance',
                CollectionPaymentLineKind.creditNote => 'credit_note',
              },
              if (payment.advanceId != null) 'advanceId': payment.advanceId,
              if (payment.creditNoteId != null)
                'creditNoteId': payment.creditNoteId,
              if (payment.paymentMethodLineId != null)
                'paymentMethodLineId': payment.paymentMethodLineId,
            },
        ],
        if (sale.cachedWithholds.isNotEmpty)
          'withholdLines': [
            for (final line in sale.cachedWithholds)
              {
                'uuid': line.uuid,
                'tax_id': line.taxId,
                'baseMinor': line.baseMinor,
                'amountMinor': line.amountMinor,
                if (line.taxsupportCode != null)
                  'taxsupport_code': line.taxsupportCode,
                if (line.notes != null) 'notes': line.notes,
              },
          ],
      },
      operationKey: commandId,
      replayPolicy: OfflineReplayPolicy.retrySafe,
    );
    return CollectionResultState.queued;
  }
}

List<DurablePaymentLineDraft> _durablePayments(
  List<CollectionPaymentDraft> payments,
) => [
  for (final payment in payments)
    DurablePaymentLineDraft(
      type: switch (payment.kind) {
        CollectionPaymentLineKind.payment => 'payment',
        CollectionPaymentLineKind.advance => 'advance',
        CollectionPaymentLineKind.creditNote => 'credit_note',
      },
      amountMinor: payment.amountMinor,
      journalId: payment.journalId > 0 ? payment.journalId : null,
      paymentMethodLineId: payment.paymentMethodLineId,
      advanceId: payment.advanceId,
      creditNoteId: payment.creditNoteId,
    ),
];

List<DurableWithholdLineDraft> _durableWithholds(
  List<CollectionWithholdDraft> withholds,
) => [
  for (final line in withholds)
    DurableWithholdLineDraft(
      uuid: line.uuid,
      taxId: line.taxId,
      baseMinor: line.baseMinor,
      amountMinor: line.amountMinor,
      taxsupportCode: line.taxsupportCode,
      notes: line.notes,
    ),
];

Map<String, dynamic>? _presentValue(String key, dynamic value) =>
    value == null ? null : {key: value};
