import 'dart:async';

import '../connectivity/connectivity_monitor.dart';
import '../contracts.dart';
import 'sync_job.dart';

final class SyncCoordinatorImpl implements SyncCoordinator {
  SyncCoordinatorImpl({required Iterable<SyncJob> jobs, this.backendProbe})
    : _jobs = _validateJobs(jobs);

  final List<SyncJob> _jobs;
  final BackendProbe? backendProbe;
  final StreamController<SyncSnapshot> _snapshots =
      StreamController<SyncSnapshot>.broadcast();
  SyncSnapshot _snapshot = SyncSnapshot();
  AppScope? _scope;
  int _epoch = 0;
  bool _paused = false;
  bool _pending = false;
  Future<void>? _drain;
  BackendProbeResult? lastProbe;

  SyncSnapshot get snapshot => _snapshot;
  Stream<SyncSnapshot> get snapshots => _snapshots.stream;
  bool get isPaused => _paused;

  @override
  Future<void> start(AppScope scope) async {
    _epoch++;
    _scope = scope;
    _paused = false;
    _pending = true;
    _publish(_snapshotFor(active: false));
    await _drainUntilIdle();
  }

  @override
  Future<void> requestSync(SyncReason reason) async {
    if (_scope == null) return;
    if (_paused || _drain != null) {
      _pending = true;
      return;
    }
    _pending = true;
    await _drainUntilIdle();
  }

  @override
  Future<void> pause(PauseReason reason) async {
    _paused = true;
    _publish(_snapshotFor(active: false));
  }

  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    if (_scope != null) {
      _pending = true;
      await _drainUntilIdle();
    }
  }

  @override
  Future<void> stop(AppScope scope) async {
    if (_scope != scope) return;
    _epoch++;
    _scope = null;
    _pending = false;
    _paused = false;
    _publish(_snapshotFor(active: false));
  }

  Future<void> _ensureDrain() {
    final current = _drain;
    if (current != null) return current;
    final future = _drainOnce();
    late final Future<void> queued;
    queued = future.whenComplete(() {
      if (identical(_drain, queued)) _drain = null;
    });
    _drain = queued;
    return queued;
  }

  Future<void> _drainOnce() async {
    if (_paused || !_pending || _scope == null) return;
    _pending = false;
    final scope = _scope!;
    final epoch = _epoch;
    _publish(_snapshotFor(active: true));

    if (backendProbe != null) {
      lastProbe = await backendProbe!.probe(scope);
      if (!_isCurrent(scope, epoch)) return;
      if (lastProbe!.state != BackendProbeState.reachable) {
        _publish(_snapshotFor(active: false, failedCount: 1, completed: true));
        return;
      }
    }

    var failed = 0;
    _publish(_snapshotFor(active: true));
    for (final job in _jobs) {
      if (!_isCurrent(scope, epoch)) return;
      try {
        final result = await job.run(scope);
        if (!_isCurrent(scope, epoch)) return;
        if (!result.cursorConfirmed) failed++;
      } catch (_) {
        if (!_isCurrent(scope, epoch)) return;
        failed++;
      }
    }
    if (_isCurrent(scope, epoch)) {
      _publish(
        _snapshotFor(active: false, failedCount: failed, completed: true),
      );
    }
  }

  Future<void> _drainUntilIdle() async {
    while (true) {
      final current = _drain;
      if (current != null) {
        await current;
        continue;
      }
      if (!_pending || _paused || _scope == null) return;
      await _ensureDrain();
    }
  }

  bool _isCurrent(AppScope scope, int epoch) =>
      _scope == scope && _epoch == epoch;

  SyncSnapshot _snapshotFor({
    required bool active,
    int? failedCount,
    bool completed = false,
  }) {
    return SyncSnapshot(
      active: active,
      queuedCount: _pending ? _jobs.length : 0,
      failedCount: failedCount ?? _snapshot.failedCount,
      conflictCount: _snapshot.conflictCount,
      lastCompletedAt: completed
          ? DateTime.now().toUtc()
          : _snapshot.lastCompletedAt,
    );
  }

  void _publish(SyncSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_snapshots.isClosed) _snapshots.add(snapshot);
  }

  Future<void> dispose() async {
    _epoch++;
    _scope = null;
    _pending = false;
    _paused = true;
    _publish(_snapshotFor(active: false));
    final drain = _drain;
    if (drain != null) await drain;
    await _snapshots.close();
  }

  static List<SyncJob> _validateJobs(Iterable<SyncJob> jobs) {
    final result = List<SyncJob>.from(jobs);
    final ids = <String>{};
    for (final job in result) {
      final id = job.id.trim();
      if (id.isEmpty || !ids.add(id)) {
        throw ArgumentError.value(
          job.id,
          'jobs',
          'Job IDs must be non-empty and unique',
        );
      }
    }
    return List.unmodifiable(result);
  }
}
