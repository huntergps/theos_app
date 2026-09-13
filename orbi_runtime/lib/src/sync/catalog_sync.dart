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
}

/// A committed local catalog projection. Implementations must publish this
/// state only after records and cursor are durable in one local transaction.
final class CatalogState<T> {
  CatalogState({List<CatalogRecord<T>>? records, this.cursor, this.error})
    : records = List.unmodifiable(records ?? const []);

  final List<CatalogRecord<T>> records;
  final String? cursor;
  final Object? error;

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

/// Generic adapter for concrete catalogs. No model, schema or timer is owned
/// here; concrete stores decide how to persist and expose their records.
final class CatalogSyncJob<T> implements SyncJob {
  CatalogSyncJob({
    required this.id,
    required LocalCatalogStore<T> store,
    required CatalogLoader<T> load,
  }) : _store = store,
       _load = load;

  @override
  final String id;
  final LocalCatalogStore<T> _store;
  final CatalogLoader<T> _load;

  @override
  Future<SyncJobResult> run(AppScope scope) async {
    try {
      final current = await _store.read(scope);
      final batch = await _load(scope, current.cursor);
      await _store.commit(scope, batch);
      return SyncJobResult.committed(cursor: batch.cursor);
    } catch (error) {
      await _store.recordError(scope, error);
      return SyncJobResult.failed(error);
    }
  }
}
