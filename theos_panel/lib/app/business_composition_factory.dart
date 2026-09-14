import 'dart:async';
import 'dart:convert';

import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/approvals/approval_contracts.dart';
import '../features/approvals/approval_runtime_adapter.dart';

typedef SaleCommandsBuilder = RuntimeSaleCommandPort Function(
  SessionActivation activation,
  CapabilitySnapshot capabilities,
);

typedef ApprovalBuilder = ApprovalPort Function(
  SessionRuntime runtime,
  SessionActivation activation,
  CapabilitySnapshot capabilities,
);

typedef CatalogsBuilder = RuntimeCatalogComposition Function(
  SessionActivation activation,
  RuntimeDatabaseOwner owner,
);

/// Owns the app-level graph for one authenticated runtime lease. Builders are
/// injected at this boundary because the concrete sale/approval stores belong
/// to runtime and may differ between native, tests and offline restore.
final class OrbiBusinessComposition {
  const OrbiBusinessComposition({
    required this.lease,
    required this.capabilities,
    this.saleCommands,
    this.approvals,
    this.catalogs,
    this.collectionOperations,
    this.onClose,
  });

  final SessionLease lease;
  final CapabilitySnapshot capabilities;
  final RuntimeSaleCommandPort? saleCommands;
  final ApprovalPort? approvals;
  final RuntimeCatalogComposition? catalogs;
  final RuntimeCollectionOperationPort? collectionOperations;
  final Future<void> Function()? onClose;

  Future<void> close() => onClose?.call() ?? Future<void>.value();
}

final class OrbiBusinessCompositionFactory {
  OrbiBusinessCompositionFactory({
    this.saleCommandsBuilder,
    this.approvalBuilder,
    this.catalogsBuilder,
  });

  final SaleCommandsBuilder? saleCommandsBuilder;
  final ApprovalBuilder? approvalBuilder;
  final CatalogsBuilder? catalogsBuilder;
  OrbiBusinessComposition? _current;

  OrbiBusinessComposition? get current => _current;

  /// Synchronous provider-facing composition. Runtime activation is already
  /// complete when this is called; stale graphs are closed asynchronously.
  OrbiBusinessComposition? composeSync({
    required SessionRuntime runtime,
    required CapabilitySnapshot capabilities,
  }) {
    final activation = runtime.active;
    if (activation == null ||
        activation.scope.scopeKey != capabilities.scopeKey ||
        !runtime.databaseOwner.accepts(activation.lease)) {
      unawaited(close());
      return null;
    }
    if (_current?.lease == activation.lease &&
        _current?.capabilities.scopeKey == capabilities.scopeKey) {
      return _current;
    }
    unawaited(close());
    final composition = _build(runtime, activation, capabilities);
    _current = composition;
    return composition;
  }

  Future<OrbiBusinessComposition?> compose({
    required SessionRuntime runtime,
    required CapabilitySnapshot capabilities,
  }) async {
    final activation = runtime.active;
    if (activation == null ||
        activation.scope.scopeKey != capabilities.scopeKey ||
        !runtime.databaseOwner.accepts(activation.lease)) {
      await close();
      return null;
    }
    await close();
    final composition = _build(runtime, activation, capabilities);
    _current = composition;
    return composition;
  }

  OrbiBusinessComposition _build(
    SessionRuntime runtime,
    SessionActivation activation,
    CapabilitySnapshot capabilities,
  ) {
    return OrbiBusinessComposition(
      lease: activation.lease,
      capabilities: capabilities,
      saleCommands: (saleCommandsBuilder ?? _defaultSaleCommands).call(
        activation,
        capabilities,
      ),
      approvals: (approvalBuilder ?? _defaultApprovals).call(
        runtime,
        activation,
        capabilities,
      ),
      catalogs: _catalogs(runtime, activation),
      collectionOperations: RuntimeCollectionOperationPort(
        runtime: runtime,
        capabilities: capabilities,
        actions: activation.client == null
            ? _UnavailableCollectionSaleActions()
            : OdooClientSaleActions(activation.client!),
        producer: DurableCollectionProducer(
          activation.database.database,
          OfflineQueueDataSource(activation.database.database),
        ),
      ),
    );
  }

  RuntimeSaleCommandPort _defaultSaleCommands(
    SessionActivation activation,
    CapabilitySnapshot capabilities,
  ) {
    final resolver = _DriftSaleLocalOrderResolver(activation.database.database);
    return RuntimeSaleCommandPort(
      SaleOperationOrchestrator(
        commands: DriftSaleCommandStore(activation.database.database, resolver),
        reconciliation: _UnavailableReconciliation(),
        collection: _UnavailableCollection(),
        shifts: _UnavailableShifts(),
      ),
    );
  }

  ApprovalPort _defaultApprovals(
    SessionRuntime runtime,
    SessionActivation activation,
    CapabilitySnapshot capabilities,
  ) => SessionApprovalPort(
    runtime: runtime,
    capabilities: capabilities,
    offlineQueue: DriftApprovalOfflineQueue(activation.database.database),
  );

  RuntimeCatalogComposition? _catalogs(
    SessionRuntime runtime,
    SessionActivation activation,
  ) {
    if (activation.client == null) return null;
    final queue = OfflineQueueDataSource(activation.database.database);
    final actions = OdooClientSaleActions(activation.client!);
    final operationsJob = OperationsSyncJob(
      queue: queue,
      // Envases (envío/recepción/dar por perdido) and every other durable
      // command share one queue but not one dispatcher: `OperationsSyncJob`
      // only accepts a single `OfflineOperationAdapter`, so this router
      // decides by (model, method) which of the two real adapters actually
      // handles each operation — see `EnvasesRoutingOfflineOperationAdapter`.
      adapter: EnvasesRoutingOfflineOperationAdapter(
        envases: EnvasesOfflineOperationAdapter(
          actions: actions,
          database: activation.database.database,
          scope: activation.scope,
        ),
        general: OdooOfflineOperationAdapter(
          actions: actions,
          database: activation.database.database,
          scope: activation.scope,
          queue: queue,
        ),
      ),
      sessions: runtime,
    );
    final catalogs =
        catalogsBuilder?.call(activation, runtime.databaseOwner) ??
        RuntimeCatalogComposition(
          activation: activation,
          owner: runtime.databaseOwner,
          operationsJob: operationsJob,
        );
    if (catalogsBuilder != null) catalogs.registerJob(operationsJob);
    return catalogs;
  }

  Future<void> close() async {
    final previous = _current;
    _current = null;
    await previous?.close();
  }
}

final class _UnavailableCollectionSaleActions implements SaleOdooActions {
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) => Future.error(StateError('acciones Odoo no disponibles sin conexión'));
}

final class _DriftSaleLocalOrderResolver implements SaleLocalOrderResolver {
  _DriftSaleLocalOrderResolver(this.database);
  final AppDatabase database;

  @override
  Future<SaleLocalOrderResolution> resolve(EntityReference reference) async {
    final remote = reference.remoteId;
    final row = remote == null
        ? await _byLocalReference(reference.localId)
        : await (database.select(
            database.saleOrder,
          )..where((table) => table.odooId.equals(remote))).getSingle();
    return SaleLocalOrderResolution(localId: row.id, version: 0);
  }

  Future<dynamic> _byLocalReference(String value) async {
    final localId = int.tryParse(value);
    if (localId != null) {
      return (database.select(
        database.saleOrder,
      )..where((table) => table.id.equals(localId))).getSingle();
    }
    return (database.select(
      database.saleOrder,
    )..where((table) => table.uuid.equals(value))).getSingle();
  }
}

/// Durable approval queue bridge consumed by the operations sync job. It is
/// public for composition tests and runtime wiring, but owns no business rule.
final class DriftApprovalOfflineQueue implements ApprovalOfflineQueue {
  DriftApprovalOfflineQueue(this.database);
  final AppDatabase database;

  @override
  Future<void> enqueue({
    required String commandId,
    required ApprovalRequest request,
    required ApprovalAction action,
    required String scopeKey,
    ApprovalDecision? decision,
  }) async {
    await database
        .into(database.offlineQueue)
        .insert(
          OfflineQueueCompanion.insert(
            model: 'approval.request',
            method: Value(action.name),
            recordId: Value(request.approvalRequestRemoteId),
            values: jsonEncode({
              'commandId': commandId,
              'scopeKey': scopeKey,
              'saleOrderRemoteId': request.saleOrderRemoteId,
              'approvalRequestRemoteId': request.approvalRequestRemoteId,
              if (decision != null) 'decision': decision.name,
            }),
            createdAt: DateTime.now().toUtc(),
            operationKey: Value(commandId),
            // approval.request decisions are reconciled by request status
            // before replay, so a crash/restart can safely dispatch once.
            replayPolicy: Value('retry_safe'),
          ),
        );
  }
}

final class _UnavailableReconciliation implements CollectionReconciliationPort {
  @override
  Future<OperationOutcome<SaleOrderState>?> findByCommandOrReference({
    required String commandId,
    required EntityReference order,
    int? expectedAmountMinor,
  }) async => null;
}

final class _UnavailableCollection implements SaleCollectionPort {
  @override
  Future<OperationOutcome<SaleOrderState>> collect({
    required String commandId,
    required EntityReference order,
    required int expectedVersion,
  }) => Future.error(StateError('collection port not configured'));
}

final class _UnavailableShifts implements SaleShiftStore {
  @override
  Future<OperationOutcome<SaleShiftState>> apply({
    required String commandId,
    required EntityReference shift,
    required int expectedVersion,
    required SaleShiftState state,
  }) => Future.error(StateError('shift port not configured'));
}
