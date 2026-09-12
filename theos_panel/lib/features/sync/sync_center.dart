import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/copyable_message.dart';
import '../../ui/state_labels.dart';

enum SyncCatalogState { idle, syncing, succeeded, failed, conflict }

enum SyncCenterLoadState { initial, loading, data, empty, error }

final class SyncCatalogStatus {
  const SyncCatalogStatus({
    required this.id,
    required this.label,
    required this.state,
    this.completed = 0,
    this.total,
    this.message,
  });

  final String id;
  final String label;
  final SyncCatalogState state;
  final int completed;
  final int? total;
  final String? message;

  double? get progress => total == null || total! <= 0
      ? null
      : (completed / total!).clamp(0, 1).toDouble();
}

final class SyncCenterSnapshot {
  const SyncCenterSnapshot({
    required this.sync,
    this.catalogs = const [],
    this.offline = false,
    this.state = SyncCenterLoadState.data,
    this.message,
  });

  final SyncSnapshot sync;
  final List<SyncCatalogStatus> catalogs;
  final bool offline;
  final SyncCenterLoadState state;
  final String? message;
}

abstract interface class SyncCenterPort {
  SyncCenterSnapshot get snapshot;
  Stream<SyncCenterSnapshot> get snapshots;
  Future<void> retry();
}

final class CoordinatorSyncCenterPort implements SyncCenterPort {
  CoordinatorSyncCenterPort(this.coordinator, {this.operations}) {
    unawaited(_loadOperations());
  }
  final SyncCoordinatorImpl coordinator;
  final OperationsSyncJob? operations;
  SyncCatalogStatus? _operationStatus;

  @override
  SyncCenterSnapshot get snapshot => SyncCenterSnapshot(
    sync: coordinator.snapshot,
    catalogs: [?_operationStatus],
  );

  @override
  Stream<SyncCenterSnapshot> get snapshots async* {
    await for (final sync in coordinator.snapshots) {
      await _loadOperations();
      yield SyncCenterSnapshot(sync: sync, catalogs: [?_operationStatus]);
    }
  }

  Future<void> _loadOperations() async {
    final job = operations;
    if (job == null) return;
    final state = await job.queueSnapshot();
    _operationStatus = SyncCatalogStatus(
      id: 'operations',
      label: 'Operaciones pendientes',
      state: state.conflict > 0 || state.deadLetter > 0
          ? SyncCatalogState.failed
          : state.pending > 0
          ? SyncCatalogState.idle
          : SyncCatalogState.succeeded,
      completed: 0,
      total: state.pending + state.deadLetter + state.conflict,
      message: state.deadLetter > 0
          ? '${state.deadLetter} en revisión manual; ${state.scheduled} con backoff'
          : state.conflict > 0
          ? '${state.conflict} conflictos requieren resolución'
          : state.pending > 0
          ? '${state.pending} en cola'
          : 'Sin operaciones pendientes',
    );
  }

  @override
  Future<void> retry() => coordinator.requestSync(SyncReason('manual_retry'));
}

final syncJobsProvider = Provider<List<SyncJob>>((ref) => const []);

final syncCoordinatorProvider = Provider<SyncCoordinatorImpl>(
  (ref) => SyncCoordinatorImpl(jobs: ref.watch(syncJobsProvider)),
);

final syncCenterPortProvider = Provider<SyncCenterPort>(
  (ref) => CoordinatorSyncCenterPort(ref.watch(syncCoordinatorProvider)),
);

class SyncCenterView extends ConsumerWidget {
  const SyncCenterView({this.onOpenConflicts, super.key});

  final VoidCallback? onOpenConflicts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final port = ref.watch(syncCenterPortProvider);
    return StreamBuilder<SyncCenterSnapshot>(
      stream: port.snapshots,
      initialData: port.snapshot,
      builder: (context, state) {
        final snapshot = state.data ?? port.snapshot;
        if (snapshot.state == SyncCenterLoadState.initial ||
            snapshot.state == SyncCenterLoadState.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.state == SyncCenterLoadState.error) {
          return Center(
            child: Text(
              snapshot.message ?? 'No se pudo consultar la sincronización',
            ),
          );
        }
        if (snapshot.state == SyncCenterLoadState.empty) {
          return const Center(child: Text('Sin trabajo pendiente'));
        }
        return _body(context, ref, port, snapshot);
      },
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    SyncCenterPort port,
    SyncCenterSnapshot snapshot,
  ) {
    final status = snapshot.offline
        ? 'Sin conexión; se conserva el trabajo local.'
        : snapshot.sync.active
        ? 'Sincronizando…'
        : snapshot.sync.failedCount > 0
        ? 'Hay catálogos que requieren reintento.'
        : 'Sincronización al día.';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          liveRegion: true,
          label: status,
          child: Text(status, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        if (snapshot.sync.active) const LinearProgressIndicator(),
        if (snapshot.sync.queuedCount > 0)
          Text('En cola: ${snapshot.sync.queuedCount}'),
        // El número solo no sirve: «5 con error» no le dice a nadie qué
        // reintentar ni a quién llamar. El detalle ya viajaba en el resultado
        // del trabajo y se descartaba al contarlo.
        if (snapshot.sync.failures.isNotEmpty) ...[
          Text('Fallidos: ${snapshot.sync.failedCount}'),
          const SizedBox(height: 4),
          for (final failure in snapshot.sync.failures)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: CopyableMessagePanel(
                message: CopyableMessage(
                  title: syncJobLabel(failure.jobId),
                  body: failure.message,
                  severity: OrbiMessageSeverity.error,
                ),
              ),
            ),
        ],
        // Mismo patrón que los fallos: el número solo no dice contra qué
        // documento hay que resolver nada.
        if (snapshot.sync.conflicts.isNotEmpty) ...[
          Text('Conflictos: ${snapshot.sync.conflictCount}'),
          const SizedBox(height: 4),
          for (final conflict in snapshot.sync.conflicts)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: CopyableMessagePanel(
                message: CopyableMessage(
                  title: conflict.documentLabel,
                  body: conflict.message,
                  severity: OrbiMessageSeverity.warning,
                ),
              ),
            ),
        ],
        if (snapshot.sync.conflictCount > 0 && onOpenConflicts != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onOpenConflicts,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir conflictos'),
            ),
          ),
        const SizedBox(height: 12),
        for (final catalog in snapshot.catalogs) _catalog(context, catalog),
        if (snapshot.sync.failedCount > 0 || snapshot.offline)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: snapshot.offline
                  ? null
                  : () => unawaited(port.retry()),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar sincronización'),
            ),
          ),
      ],
    );
  }

  Widget _catalog(BuildContext context, SyncCatalogStatus catalog) {
    final detail =
        catalog.message ??
        switch (catalog.state) {
          SyncCatalogState.idle => 'En espera',
          SyncCatalogState.syncing => 'Procesando',
          SyncCatalogState.succeeded => 'Completado',
          SyncCatalogState.failed => 'Requiere reintento',
          SyncCatalogState.conflict => 'Requiere resolución',
        };
    return Card(
      child: ListTile(
        title: Text(catalog.label),
        subtitle: Text(detail),
        trailing: catalog.progress == null
            ? null
            : SizedBox(
                width: 96,
                child: LinearProgressIndicator(value: catalog.progress),
              ),
      ),
    );
  }
}
