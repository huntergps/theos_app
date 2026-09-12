import '../contracts.dart';

enum SyncJobStatus { committed, failed }

final class SyncJobResult {
  const SyncJobResult._({
    required this.status,
    this.cursor,
    this.error,
    this.conflicts = const [],
  });

  const SyncJobResult.committed({String? cursor})
    : this._(status: SyncJobStatus.committed, cursor: cursor);

  /// [conflicts] carries the detail behind the failure when it is one or more
  /// unresolved data conflicts, not just an opaque error — see
  /// [SyncConflict] for why this exists.
  const SyncJobResult.failed(Object error, {List<SyncConflict> conflicts = const []})
    : this._(status: SyncJobStatus.failed, error: error, conflicts: conflicts);

  final SyncJobStatus status;
  final String? cursor;
  final Object? error;
  final List<SyncConflict> conflicts;

  bool get cursorConfirmed => status == SyncJobStatus.committed;
}

/// A real catalog/business sync operation supplied by the runtime integrator.
/// The job must return committed only after local data and cursor are durable.
abstract interface class SyncJob {
  String get id;

  Future<SyncJobResult> run(AppScope scope);
}
