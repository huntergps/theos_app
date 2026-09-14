// Private fields select the injected ports without exposing implementation
// details as public constructor parameters.
// ignore_for_file: prefer_initializing_formals
import '../contracts.dart';
import 'sync_job.dart';

/// Stable local identity and dependency edges are kept by the catalog owner;
/// the runtime only transports them through the generic sync boundary.
final class CatalogRecord<T> {
  const CatalogRecord({
    required this.uuid,
    required this.value,
    this.dependencies = const <String>[],
  });

  final String uuid;
  final T value;
  final List<String> dependencies;
}

final class CatalogBatch<T> {
  const CatalogBatch({
    required this.records,
    required this.cursor,
    this.deletedIds = const <int>[],
    this.remoteActiveIds,
    this.moreInInitialLoad = false,
  });

  final List<CatalogRecord<T>> records;
  final String? cursor;

  /// Ids explicitly reported as removed upstream (Odoo `sync.deleted.record`,
  /// when that module is installed). The store must remove them locally,
  /// unless a pending offline-queue operation still targets that id — see
  /// [LocalCatalogStore.commit].
  final List<int> deletedIds;

  /// The COMPLETE set of ids currently active on the server for this
  /// catalog's domain. Populated only during a periodic reconciliation pass
  /// (used when the server has no `sync.deleted.record`, e.g. Mepriga): the
  /// store diffs it against its own local ids and removes whatever is local
  /// but no longer in this set. `null` means "this batch is not a
  /// reconciliation pass" — the store must not delete anything beyond
  /// [deletedIds] in that case.
  final Set<int>? remoteActiveIds;

  /// `true` cuando esta página vino de una carga INICIAL (el cursor todavía
  /// estaba en modo "carga completa", no en modo incremental) y hace falta
  /// al menos una página más para terminarla — ver
  /// `RuntimeCatalogLoader._runFullPage`, que es quien la enciende
  /// exactamente en el mismo caso en que ya sabe que `rows.length >=
  /// pageSize`.
  ///
  /// [CatalogSyncJob] usa esta señal para seguir pidiendo páginas DENTRO del
  /// mismo ciclo mientras dure la carga inicial (con un tope, ver
  /// `catalogSyncMaxPagesPerCycle`), sin necesitar saber nada del formato
  /// del cursor — es una señal genérica, no un detalle de
  /// `json2_read_adapters.dart`. `false` por defecto: una carga incremental
  /// (o cualquier `CatalogLoader` que no pagine, como los de "usuario/
  /// partner de la sesión activa") nunca la enciende, y sigue siendo una
  /// sola página por ciclo, como siempre.
  ///
  /// Antes de esto (14-sep-2026, hueco 4 de la auditoría de tiempo real), un
  /// catálogo con más de una página de datos nuevos tardaba tantos CICLOS de
  /// sincronización como páginas tuviera, uno por vez — `CatalogSyncJob.run`
  /// sólo llamaba al cargador una vez por invocación.
  final bool moreInInitialLoad;
}

/// A committed local catalog projection. Implementations must publish this
/// state only after records and cursor are durable in one local transaction.
final class CatalogState<T> {
  CatalogState({
    List<CatalogRecord<T>>? records,
    this.cursor,
    this.error,
    this.lastSyncedAt,
  }) : records = List.unmodifiable(records ?? const []);

  final List<CatalogRecord<T>> records;
  final String? cursor;
  final Object? error;

  /// Cuándo se confirmó (UTC) el último lote de este catálogo — éxito o
  /// "no soportado en este servidor", ambos pasan por
  /// [LocalCatalogStore.commit]. `null` cuando nunca se sincronizó. A
  /// diferencia de un contador en memoria de quien use este store, ESTA
  /// marca vive donde vive el [cursor]: sobrevive a cerrar y reabrir la app
  /// (ver `DriftCatalogStore`, hueco 3 de la auditoría de tiempo real del
  /// 14-sep-2026). Un [recordError] nunca la toca — un fallo no borra la
  /// última vez que sí funcionó.
  final DateTime? lastSyncedAt;

  int get count => records.length;
}

abstract interface class LocalCatalogStore<T> {
  Stream<CatalogState<T>> watch(AppScope scope);

  Future<CatalogState<T>> read(AppScope scope);

  /// Must atomically persist records and cursor, then publish the new state.
  ///
  /// Implementations that support deletions must honor
  /// [CatalogBatch.deletedIds] and [CatalogBatch.remoteActiveIds], and must
  /// never delete or overwrite a local row that still has an unresolved
  /// offline-queue operation against it (status other than `completed`) —
  /// that row is left untouched as a conflict for a later cycle instead.
  Future<void> commit(AppScope scope, CatalogBatch<T> batch);

  /// Publishes an observable error while leaving records and cursor unchanged.
  Future<void> recordError(AppScope scope, Object error);
}

typedef CatalogLoader<T> = Future<CatalogBatch<T>> Function(
  AppScope scope,
  String? cursor,
);

/// Tope de páginas que [CatalogSyncJob.run] agota DENTRO de un mismo ciclo
/// mientras dure la carga inicial de un catálogo (ver
/// [CatalogBatch.moreInInitialLoad]). Una sola constante, para que ningún
/// catálogo se quede acaparando el ciclo entero: uno con más páginas que
/// esto simplemente retoma en el ciclo siguiente, donde el coordinador ya
/// deja correr al resto de trabajos.
const catalogSyncMaxPagesPerCycle = 50;

/// Generic adapter for concrete catalogs. No model, schema or timer is owned
/// here; concrete stores decide how to persist and expose their records.
final class CatalogSyncJob<T> implements SyncJob {
  CatalogSyncJob({
    required this.id,
    required LocalCatalogStore<T> store,
    required CatalogLoader<T> load,
    this.maxPagesPerCycle = catalogSyncMaxPagesPerCycle,
  }) : _store = store,
       _load = load;

  @override
  final String id;
  final LocalCatalogStore<T> _store;
  final CatalogLoader<T> _load;

  /// Ver [catalogSyncMaxPagesPerCycle]. Parametrizable sólo para pruebas —
  /// en producción todos los catálogos comparten la misma constante.
  final int maxPagesPerCycle;

  @override
  Future<SyncJobResult> run(AppScope scope) async {
    try {
      final current = await _store.read(scope);
      String? cursor = current.cursor;
      String? lastCommittedCursor = cursor;
      var pages = 0;
      // Mientras la página que acaba de llegar diga que la carga INICIAL
      // sigue incompleta, se pide la siguiente en el mismo ciclo — hasta el
      // tope, para no acaparar el drenaje del coordinador. Una carga
      // incremental nunca enciende `moreInInitialLoad`, así que este bucle
      // corre exactamente una vez para ella, igual que siempre.
      while (true) {
        final batch = await _load(scope, cursor);
        await _store.commit(scope, batch);
        lastCommittedCursor = batch.cursor;
        pages++;
        if (!batch.moreInInitialLoad || pages >= maxPagesPerCycle) break;
        cursor = batch.cursor;
      }
      return SyncJobResult.committed(cursor: lastCommittedCursor);
    } catch (error) {
      await _store.recordError(scope, error);
      return SyncJobResult.failed(error);
    }
  }
}
