import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/auth/auth_controller.dart';
import '../features/collection/collection_contracts.dart';
import '../features/collection/collection_composition.dart';
import '../features/collection/collection_session_hub_screen.dart'
    show CollectionPointContext, CollectionSessionRecordCounts;
import '../features/collection/runtime_collection_actions.dart';
import 'notification_scope_adapter.dart';

final scopeCollectionShiftProvider = Provider<CollectionShiftSnapshot>((ref) {
  final runtime = ref.watch(runtimeSessionProvider);
  final capabilities = ref.watch(capabilitySnapshotProvider);
  final profile = ref.watch(authControllerProvider).profile;
  if (runtime == null || capabilities == null || profile == null) {
    return const CollectionShiftSnapshot(
      id: 'unconfigured',
      state: CollectionShiftState.conflict,
      expectedVersion: 0,
    );
  }
  final active = runtime.active;
  if (active == null) {
    return const CollectionShiftSnapshot(
      id: 'inactive',
      state: CollectionShiftState.conflict,
      expectedVersion: 0,
    );
  }
  // The local table is authoritative while offline; no point/turn is
  // fabricated when there is no matching active session.
  return const CollectionShiftSnapshot(
    id: 'loading',
    state: CollectionShiftState.opening,
    expectedVersion: 0,
  );
});

final scopeCollectionShiftFutureProvider =
    FutureProvider<CollectionShiftSnapshot>((ref) async {
      final runtime = ref.watch(runtimeSessionProvider);
      final active = runtime?.active;
      if (runtime == null || active == null) {
        throw StateError('No hay turno de caja activo');
      }
      // The collection.session catalog is the durable source of truth for a
      // cashier turn. Runtime metadata is retained only as a migration
      // fallback for installs created before the catalog was wired; an empty
      // metadata key must never make up an active turn.
      final local = await _readLocalShift(active, ref);
      if (local != null) return local;
      final raw = await RuntimeMetadataStore(
        runtime,
      ).read('collection/shift/${active.scope.scopeKey}', lease: active.lease);
      if (raw == null) throw StateError('No hay turno de caja recuperado');
      final value = jsonDecode(raw);
      if (value is! Map) throw const FormatException('turno local inválido');
      final id = value['id'];
      final state = value['state'];
      if (id is! String || state is! String) {
        throw const FormatException('turno local incompleto');
      }
      return CollectionShiftSnapshot(
        id: id,
        state: CollectionShiftState.values.byName(state),
        expectedVersion: value['expectedVersion'] as int? ?? 0,
        expectedBalanceMinor: value['expectedBalanceMinor'] as int?,
        differenceMinor: value['differenceMinor'] as int?,
      );
    });

final scopeCollectionPendingFutureProvider =
    FutureProvider<List<CollectionPendingSale>>((ref) async {
      final runtime = ref.watch(runtimeSessionProvider);
      final active = runtime?.active;
      if (runtime == null || active == null) {
        throw StateError('No hay sesión para pendientes de caja');
      }
      final local = await _readLocalPending(
        active,
        ref.read(capabilitySnapshotProvider)?.companyId,
      );
      final raw = await RuntimeMetadataStore(runtime).read(
        'collection/pending/${active.scope.scopeKey}',
        lease: active.lease,
      );
      if (raw == null) return local;
      final value = jsonDecode(raw);
      if (value is! List) {
        // A malformed optional cache should not hide the durable local queue.
        return local;
      }
      final metadata = value
          .whereType<Map>()
          .map(_pendingFromJson)
          .whereType<CollectionPendingSale>()
          .toList(growable: false);
      if (local.isEmpty) return metadata;
      // Metadata can contain wizard IDs that are not part of sale.order. Keep
      // it, then append only local orders not already represented by identity.
      final known = metadata.map((sale) => sale.id).toSet();
      return List.unmodifiable([
        ...metadata,
        ...local.where((sale) => !known.contains(sale.id)),
      ]);
    });

final scopeCollectionJournalsFutureProvider =
    FutureProvider<List<CollectionJournalOption>>((ref) async {
      final runtime = ref.watch(runtimeSessionProvider);
      final active = runtime?.active;
      if (runtime == null || active == null) {
        throw StateError('No hay punto de cobro activo');
      }
      final raw = await RuntimeMetadataStore(runtime).read(
        'collection/journals/${active.scope.scopeKey}',
        lease: active.lease,
      );
      if (raw == null) {
        throw StateError('No hay diarios permitidos para el punto');
      }
      final value = jsonDecode(raw);
      if (value is! List) throw const FormatException('diarios inválidos');
      return value
          .whereType<Map>()
          .map(
            (item) => CollectionJournalOption(
              id: item['id'] as int,
              name: item['name'] as String,
            ),
          )
          .toList(growable: false);
    });

final scopeCollectionCashOutTypesFutureProvider =
    FutureProvider<List<CollectionCashOutTypeOption>>((ref) async {
      final active = ref.watch(runtimeSessionProvider)?.active;
      if (active == null) return const [];
      final rows = await (active.database.database.select(
        active.database.database.cashOutType,
      )..where((table) => table.active.equals(true))).get();
      return rows
          .map(
            (row) =>
                CollectionCashOutTypeOption(id: row.odooId, name: row.name),
          )
          .where((type) => type.id > 0)
          .toList(growable: false);
    });

final scopeCollectionPendingProvider = Provider<List<CollectionPendingSale>>((
  ref,
) {
  // Legacy synchronous consumers receive data only after the durable reader
  // completes. During loading/error this remains an explicit empty *view*;
  // the route uses the AsyncValue provider and renders those states instead
  // of treating them as a successfully empty queue.
  return ref.watch(scopeCollectionPendingFutureProvider).asData?.value ??
      const [];
});

Future<CollectionShiftSnapshot?> _readLocalShift(
  SessionActivation active,
  Ref ref,
) async {
  final profile = ref.read(authControllerProvider).profile;
  final capabilities = ref.read(capabilitySnapshotProvider);
  if (profile == null || capabilities == null) return null;
  final rows =
      await (active.database.database.select(
            active.database.database.collectionSession,
          )..where(
            (table) =>
                table.userId.equals(profile.userId) &
                table.companyId.equals(capabilities.companyId) &
                table.state.isNotIn(const ['closed']),
          ))
          .get();
  if (rows.isEmpty) return null;
  rows.sort((a, b) => (b.startAt).compareTo(a.startAt));
  final row = rows.first;
  if (row.odooId == 0) return null;
  return CollectionShiftSnapshot(
    id: row.odooId.toString(),
    state: _shiftState(row.state),
    // The current SaleShiftVersionReader has no remote version field. Keep the
    // neutral token until that shared contract is extended; a write_date
    // timestamp is not a valid Odoo optimistic-lock version.
    expectedVersion: 0,
    expectedBalanceMinor: (row.cashRegisterBalanceEnd * 100).round(),
    differenceMinor: (row.cashRegisterDifference * 100).round(),
  );
}

Future<List<CollectionPendingSale>> _readLocalPending(
  SessionActivation active,
  int? companyId,
) async {
  if (companyId == null || companyId <= 0) return const [];
  // Read only the capability-bound company partition, then require a positive
  // remote ID before presenting a remotely actionable operation.
  final rows =
      await (active.database.database.select(active.database.database.saleOrder)
            ..where(
              (table) =>
                  table.companyId.equals(companyId) &
                  table.odooId.isBiggerThanValue(0) &
                  table.state.equals('sale') &
                  ((table.amountUnpaid.isBiggerThanValue(0)) |
                      (table.amountToInvoice.isBiggerThanValue(0)) |
                      table.hasQueuedInvoice.equals(true)),
            ))
          .get();
  final pending = await Future.wait(
    rows.map((row) async {
      final advances = row.partnerId == null
          ? const <CollectionCachedReference>[]
          : await (active.database.database.select(
                  active.database.database.accountAdvance,
                )..where(
                  (table) =>
                      table.partnerId.equals(row.partnerId!) &
                      table.odooId.isBiggerThanValue(0) &
                      table.amountAvailable.isBiggerThanValue(0) &
                      table.state.isIn(const ['posted', 'in_use']),
                ))
                .get()
                .then(
                  (items) => items
                      .map(
                        (item) => CollectionCachedReference(
                          id: item.odooId,
                          label: item.name ?? item.reference ?? 'Anticipo',
                          amountMinor: (item.amountAvailable * 100).round(),
                        ),
                      )
                      .toList(growable: false),
                );
      final creditNotes = row.partnerId == null
          ? const <CollectionCachedReference>[]
          : await (active.database.database.select(
                  active.database.database.accountCreditNote,
                )..where(
                  (table) =>
                      table.partnerId.equals(row.partnerId!) &
                      table.odooId.isBiggerThanValue(0) &
                      table.active.equals(true) &
                      table.state.isIn(const ['posted', 'open']),
                ))
                .get()
                .then(
                  (items) => items
                      .map(
                        (item) => CollectionCachedReference(
                          id: item.odooId,
                          label: item.name,
                          amountMinor: (item.amount * 100).round(),
                        ),
                      )
                      .toList(growable: false),
                );
      final withholds = await (active.database.database.select(
        active.database.database.saleOrderWithholdLine,
      )..where((table) => table.orderId.equals(row.odooId))).get();
      return CollectionPendingSale(
        id: row.odooId.toString(),
        label: row.clientOrderRef ?? row.name,
        amountMinor:
            ((row.amountUnpaid > 0 ? row.amountUnpaid : row.amountToInvoice) *
                    100)
                .round(),
        partnerId: row.partnerId,
        route: row.amountToInvoice > 0 || row.hasQueuedInvoice
            ? CollectionSaleRoute.cashInvoice
            : CollectionSaleRoute.existingInvoice,
        remoteId: row.odooId,
        // The payment wizard ID is supplied by the server metadata when
        // required. Never infer one from sale.order or local row IDs.
        commandId: 'collect-${active.scope.scopeKey}-${row.odooId}',
        collectionSessionId: row.collectionSessionId,
        requiresDueConfirmation: row.isCash && row.isCredit,
        calculatedDueMinor: row.isCash && row.isCredit
            ? ((row.amountUnpaid > 0 ? row.amountUnpaid : row.amountToInvoice) *
                      100)
                  .round()
            : null,
        cachedAdvances: advances,
        cachedCreditNotes: creditNotes,
        cachedWithholds: withholds
            .map(
              (item) => CollectionWithholdDraft(
                uuid: item.lineUuid ?? 'withhold-${item.id}',
                taxId: item.taxId,
                baseMinor: (item.base * 100).round(),
                amountMinor: (item.amount * 100).round(),
                taxsupportCode: item.taxsupportCode,
                notes: item.notes,
              ),
            )
            .toList(growable: false),
      );
    }),
  );
  return pending.where((sale) => sale.amountMinor > 0).toList(growable: false);
}

CollectionPendingSale? _pendingFromJson(Map item) {
  final id = item['id'];
  final label = item['label'];
  final amount = item['amountMinor'];
  if (id is! String || label is! String || amount is! int || amount <= 0) {
    return null;
  }
  final routeName = item['route'] as String? ?? 'existingInvoice';
  final route = CollectionSaleRoute.values.where(
    (candidate) => candidate.name == routeName,
  );
  if (route.isEmpty) return null;
  return CollectionPendingSale(
    id: id,
    label: label,
    amountMinor: amount,
    partnerId: item['partnerId'] as int?,
    route: route.first,
    wizardId: item['wizardId'] as int?,
    remoteId: item['remoteId'] as int?,
    commandId: item['commandId'] as String?,
    collectionSessionId: item['collectionSessionId'] as int?,
    numberedByClient: item['numberedByClient'] as bool? ?? false,
    sequential: item['sequential'] as int?,
    emissionDate: item['emissionDate'] as String?,
    accessKey: item['accessKey'] as String?,
    cachedAdvances: _cachedReferences(item['cachedAdvances']),
    cachedCreditNotes: _cachedReferences(item['cachedCreditNotes']),
    cachedWithholds: _cachedWithholds(item['cachedWithholds']),
  );
}

List<CollectionCachedReference> _cachedReferences(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .where((item) => item['id'] is int && item['label'] is String)
      .map(
        (item) => CollectionCachedReference(
          id: item['id'] as int,
          label: item['label'] as String,
          amountMinor: item['amountMinor'] as int? ?? 0,
        ),
      )
      .where((item) => item.id > 0 && item.amountMinor > 0)
      .toList(growable: false);
}

List<CollectionWithholdDraft> _cachedWithholds(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .where(
        (item) =>
            item['uuid'] is String &&
            item['taxId'] is int &&
            item['baseMinor'] is int &&
            item['amountMinor'] is int,
      )
      .map(
        (item) => CollectionWithholdDraft(
          uuid: item['uuid'] as String,
          taxId: item['taxId'] as int,
          baseMinor: item['baseMinor'] as int,
          amountMinor: item['amountMinor'] as int,
          taxsupportCode: item['taxsupportCode'] as String?,
          notes: item['notes'] as String?,
        ),
      )
      .where((item) => item.taxId > 0 && item.amountMinor > 0)
      .toList(growable: false);
}

/// A `collection.session` read by id, independent of the viewer's own active
/// shift — the supervisor-overview counterpart of [_readLocalShift].
/// Local-only by construction: nothing in this type's construction path
/// takes an `OdooClient`/RPC port, so it can never ask Odoo for a payments
/// read the viewer is not authorized for ("un 403 es un defecto", per the
/// supervisor-overview spec). The local catalog is already scoped by
/// whatever rule let THIS device sync a given `collection.session` row in
/// the first place — `collection_session_user_rule` restricts a cashier's
/// own sync to `config_id.user_ids` containing them,
/// `collection_session_manager_rule` gives a supervisor every row
/// (`l10n_ec_collection_box/security/collection_box_rules.xml:17-31`) — so a
/// plain cashier's device never even receives another cashier's session.
final class CollectionSessionLookup {
  const CollectionSessionLookup({
    required this.shift,
    required this.point,
    required this.ownerUserId,
    required this.rawState,
    required this.counts,
  });
  final CollectionShiftSnapshot shift;
  final CollectionPointContext point;

  /// `collection.session.user_id` — the cashier who owns this turn, never
  /// the viewer's own id.
  final int ownerUserId;

  /// The raw `collection.session.state` value ('opened', 'paused',
  /// 'closing_control', 'closed', 'opening_control'). [shift]'s
  /// [CollectionShiftState] deliberately collapses 'opened' and 'paused'
  /// into the same coarse bucket for display; supervision gating
  /// (`availableSupervisionActions`) needs the real value to tell a pausable
  /// turn from a resumable one.
  final String rawState;
  final CollectionSessionRecordCounts counts;
}

/// Defense in depth for [scopeCollectionSessionByIdFutureProvider]: the real
/// guard belongs here, not only in whether Inicio drew the row as tappable —
/// same principle Odoo itself applies before letting a supervisor reopen a
/// closed turn: "la guarda de verdad va aquí, no en el invisible de la
/// vista: un botón oculto se sigue pudiendo llamar por RPC"
/// (`l10n_ec_collection_box/models/collection_session.py:2510-2513`,
/// `action_session_reabrir_cerrada`). A row a plain cashier could reach by
/// typing the URL directly stays blocked here even though in practice their
/// local table never holds a foreign session to begin with.
bool canOpenCollectionSessionById({
  required int ownerUserId,
  required int viewerUserId,
  required Set<String> permissions,
}) =>
    ownerUserId == viewerUserId ||
    permissions.contains('collection_supervisor');

/// Supervisor-overview counterpart of [scopeCollectionShiftFutureProvider]:
/// reads ONE `collection.session` by id, for a cashier other than the
/// viewer. Throws (never returns a partial/fabricated view) when the turn is
/// not in the local catalog or the viewer is neither its owner nor a
/// supervisor — see [canOpenCollectionSessionById].
final scopeCollectionSessionByIdFutureProvider = FutureProvider.family<
    CollectionSessionLookup, int>((ref, sessionId) async {
  final runtime = ref.watch(runtimeSessionProvider);
  final active = runtime?.active;
  if (runtime == null || active == null) {
    throw StateError('No hay sesión para leer el turno');
  }
  final profile = ref.watch(authControllerProvider).profile;
  final capabilities = ref.watch(capabilitySnapshotProvider);
  if (profile == null || capabilities == null) {
    throw StateError('No hay identidad para autorizar el turno');
  }
  final view = await _readLocalShiftById(active, sessionId);
  if (view == null) {
    throw StateError('Turno $sessionId no encontrado.');
  }
  if (!canOpenCollectionSessionById(
    ownerUserId: view.ownerUserId,
    viewerUserId: profile.userId,
    permissions: capabilities.permissions,
  )) {
    throw StateError('No tienes autorización para ver este turno.');
  }
  return view;
});

Future<CollectionSessionLookup?> _readLocalShiftById(
  SessionActivation active,
  int sessionId,
) async {
  final rows =
      await (active.database.database.select(
            active.database.database.collectionSession,
          )..where((table) => table.odooId.equals(sessionId)))
          .get();
  if (rows.isEmpty) return null;
  final row = rows.first;
  return CollectionSessionLookup(
    shift: CollectionShiftSnapshot(
      id: row.odooId.toString(),
      state: _shiftState(row.state),
      // Same neutral token as `_readLocalShift`: no remote version field
      // exists yet for optimistic locking.
      expectedVersion: 0,
      expectedBalanceMinor: (row.cashRegisterBalanceEnd * 100).round(),
      differenceMinor: (row.cashRegisterDifference * 100).round(),
    ),
    point: CollectionPointContext(
      pointLabel: row.configName ?? 'Punto de cobro',
      cashierLabel: row.userName,
    ),
    ownerUserId: row.userId,
    rawState: row.state,
    counts: CollectionSessionRecordCounts(
      orderCount: row.orderCount,
      invoiceCount: row.invoiceCount,
      paymentCount: row.paymentCount,
    ),
  );
}

CollectionShiftState _shiftState(String state) => switch (state) {
  'opened' || 'paused' => CollectionShiftState.opened,
  'closing_control' => CollectionShiftState.closing,
  'closed' => CollectionShiftState.closed,
  _ => CollectionShiftState.opening,
};

final scopeCollectionCapabilitiesProvider =
    Provider<CollectionCapabilitySnapshot>((ref) {
      final snapshot = ref.watch(capabilitySnapshotProvider);
      if (snapshot == null) return const CollectionCapabilitySnapshot();
      final values = <CollectionCapability>{
        if (snapshot.permissions.contains(
          RuntimeCollectionOperationPort.advancePermission,
        ))
          CollectionCapability.advances,
        if (snapshot.permissions.contains(
          RuntimeCollectionOperationPort.withholdingPermission,
        ))
          CollectionCapability.withholdings,
        if (snapshot.permissions.contains(
          RuntimeCollectionOperationPort.creditNotePermission,
        ))
          CollectionCapability.creditNotes,
        if (snapshot.permissions.contains(
          RuntimeCollectionOperationPort.cashOutPermission,
        ))
          CollectionCapability.cashOuts,
        if (snapshot.permissions.contains(
          RuntimeCollectionOperationPort.depositPermission,
        ))
          CollectionCapability.deposits,
      };
      return CollectionCapabilitySnapshot(available: values);
    });

/// Null when offline (`active.client == null`): the supervision screen must
/// refuse and never queue, not silently degrade — see
/// `CollectionSessionSupervisionPort`'s docstring.
final scopeCollectionSessionSupervisionActionsProvider =
    Provider<CollectionSessionSupervisionPort?>((ref) {
      final client = ref.watch(runtimeSessionProvider)?.active?.client;
      if (client == null) return null;
      return CollectionSessionSupervisionPort(OdooClientSaleActions(client));
    });

final scopeCollectionActionsProvider = Provider<CollectionActions>((ref) {
  final runtime = ref.watch(runtimeSessionProvider);
  final active = runtime?.active;
  if (active == null) return const UnconfiguredCollectionActions();
  final actions = active.client == null
      ? null
      : OdooClientSaleActions(active.client!);
  final queue = OfflineQueueDataSource(active.database.database);
  final capabilities = ref.watch(capabilitySnapshotProvider);
  return RuntimeCollectionActions(
    sales: actions == null ? null : OdooSaleCollectionPort(actions),
    sessions: OdooCollectionSessionStore(
      actions ?? _UnavailableSaleActions(),
      const _ZeroVersionReader(),
    ),
    queue: queue,
    producer: DurableCollectionProducer(active.database.database, queue),
    scopeKey: active.scope.scopeKey,
    hasCollectionSupervisor:
        capabilities?.permissions.contains('collection_supervisor') ?? false,
  );
});

final class _UnavailableSaleActions implements SaleOdooActions {
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) => Future.error(StateError('offline sale actions unavailable'));
}

final class _ZeroVersionReader implements SaleShiftVersionReader {
  const _ZeroVersionReader();
  @override
  Future<int> read(EntityReference shift) async => 0;
}
