import '../contracts.dart';

enum SyncJobStatus { committed, failed }

final class SyncJobResult {
  const SyncJobResult._({required this.status, this.cursor, this.error});

  const SyncJobResult.committed({String? cursor})
    : this._(status: SyncJobStatus.committed, cursor: cursor);

  const SyncJobResult.failed(Object error)
    : this._(status: SyncJobStatus.failed, error: error);

  final SyncJobStatus status;
  final String? cursor;
  final Object? error;

  bool get cursorConfirmed => status == SyncJobStatus.committed;
}

/// A real catalog/business sync operation supplied by the runtime integrator.
/// The job must return committed only after local data and cursor are durable.
abstract interface class SyncJob {
  String get id;

  Future<SyncJobResult> run(AppScope scope);
}
