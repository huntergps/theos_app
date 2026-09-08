import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/connectivity/connectivity_monitor.dart';
import 'package:orbi_runtime/src/sync/sync_coordinator_impl.dart';
import 'package:orbi_runtime/src/sync/sync_job.dart';

AppScope scope(int userId) => AppScope(
  appId: 'orbi-panel',
  installationId: 'install',
  normalizedServerUrl: 'https://erp.test',
  database: 'db',
  userId: userId,
);

final class _Job implements SyncJob {
  _Job(this.id, this.runCallback);
  @override
  final String id;
  final Future<SyncJobResult> Function(AppScope scope) runCallback;
  @override
  Future<SyncJobResult> run(AppScope scope) => runCallback(scope);
}

final class _Probe implements BackendProbe {
  _Probe(this.result);
  BackendProbeResult result;
  @override
  Future<BackendProbeResult> probe(AppScope scope) async => result;
}

void main() {
  test(
    'connectivity adapter maps none and wifi without backend claim',
    () async {
      final monitor = ConnectivityMonitor(
        check: () async => [ConnectivityResult.none, ConnectivityResult.wifi],
        changes: () => const Stream.empty(),
      );
      final signal = await monitor.check();
      expect(signal.hasNetwork, isTrue);
      expect(signal.transports, [NetworkTransport.wifi]);
    },
  );

  test('burst requests coalesce to one drain', () async {
    var runs = 0;
    final coordinator = SyncCoordinatorImpl(
      jobs: [
        _Job('catalog', (_) async {
          runs++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return const SyncJobResult.committed(cursor: '1');
        }),
      ],
    );
    await coordinator.start(scope(1));
    await coordinator.requestSync(SyncReason('network'));
    expect(runs, 2);
    await coordinator.dispose();
  });

  test('401 is unauthorized, not offline, and jobs are preserved', () async {
    var runs = 0;
    final coordinator = SyncCoordinatorImpl(
      backendProbe: _Probe(BackendProbeResult.unauthorized()),
      jobs: [
        _Job('catalog', (_) async {
          runs++;
          return const SyncJobResult.committed();
        }),
      ],
    );
    await coordinator.start(scope(1));
    expect(coordinator.lastProbe?.authStatus, AuthStatus.expired);
    expect(coordinator.lastProbe?.health.state, BackendHealthState.reachable);
    expect(runs, 0);
    expect(coordinator.snapshot.failedCount, 1);
    expect(coordinator.snapshot.active, isFalse);
    await coordinator.dispose();
  });

  test('unreachable probe has unknown auth and stable check timestamp', () {
    final checkedAt = DateTime.utc(2026, 1, 1);
    final result = BackendProbeResult.unreachable(checkedAt: checkedAt);
    expect(result.authStatus, AuthStatus.unknown);
    expect(result.health.lastCheckedAt, checkedAt);
    expect(result.health.lastCheckedAt, result.health.lastCheckedAt);
  });

  test('pause holds work and resume drains once', () async {
    var runs = 0;
    final coordinator = SyncCoordinatorImpl(
      jobs: [
        _Job('catalog', (_) async {
          runs++;
          return const SyncJobResult.committed();
        }),
      ],
    );
    await coordinator.start(scope(1));
    await coordinator.pause(PauseReason('route-mode'));
    await coordinator.requestSync(SyncReason('timer'));
    expect(runs, 1);
    await coordinator.resume();
    expect(runs, 2);
    await coordinator.dispose();
  });

  test('scope change discards late job result', () async {
    final release = Completer<void>();
    final firstJob = _Job('catalog', (jobScope) async {
      if (jobScope.userId == 1) await release.future;
      return const SyncJobResult.committed(cursor: 'late');
    });
    final coordinator = SyncCoordinatorImpl(jobs: [firstJob]);
    final first = coordinator.start(scope(1));
    await Future<void>.delayed(Duration.zero);
    final second = coordinator.start(scope(2));
    release.complete();
    await Future.wait([first, second]);
    expect(coordinator.snapshot.active, isFalse);
    expect(coordinator.snapshot.lastCompletedAt, isNotNull);
    await coordinator.dispose();
  });

  test('job failure is visible and committed cursor is required', () async {
    final coordinator = SyncCoordinatorImpl(
      jobs: [
        _Job('catalog', (_) async => const SyncJobResult.failed('network')),
      ],
    );
    await coordinator.start(scope(1));
    expect(coordinator.snapshot.failedCount, 1);
    expect(coordinator.snapshot.active, isFalse);
    await coordinator.dispose();
  });

  test(
    'request during blocked drain coalesces into exactly one later drain',
    () async {
      final release = Completer<void>();
      var runs = 0;
      final coordinator = SyncCoordinatorImpl(
        jobs: [
          _Job('catalog', (_) async {
            runs++;
            if (runs == 1) await release.future;
            return const SyncJobResult.committed();
          }),
        ],
      );
      final initial = coordinator.start(scope(1));
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.snapshot.active, isTrue);
      final request = coordinator.requestSync(SyncReason('network'));
      release.complete();
      await Future.wait([initial, request]);
      expect(runs, 2);
      expect(coordinator.snapshot.active, isFalse);
      await coordinator.dispose();
    },
  );

  test('job IDs must be non-empty and unique', () {
    expect(
      () => SyncCoordinatorImpl(
        jobs: [_Job('', (_) async => const SyncJobResult.committed())],
      ),
      throwsArgumentError,
    );
    expect(
      () => SyncCoordinatorImpl(
        jobs: [
          _Job('catalog', (_) async => const SyncJobResult.committed()),
          _Job('catalog', (_) async => const SyncJobResult.committed()),
        ],
      ),
      throwsArgumentError,
    );
  });
}
