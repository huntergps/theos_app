import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/datasources/datasources.dart';
import 'package:theos_pos/features/sync/services/connectivity_sync_orchestrator.dart';
import 'package:theos_pos/features/sync/services/offline_sync_service.dart';

class _MockOfflineQueueDataSource extends Mock
    implements OfflineQueueDataSource {}

class _MockOfflineSyncService extends Mock implements OfflineSyncService {}

void main() {
  late ServerHealthService healthService;
  late _ControlledPeriodicTimer periodicTimer;
  late bool authenticated;
  late bool manualOffline;
  late bool routeMode;
  late int syncCalls;

  ConnectivitySyncOrchestrator buildOrchestrator({
    Future<void> Function()? syncCriticalData,
    OfflineSyncService? offlineSyncService,
    OfflineQueueDataSource? offlineQueue,
  }) {
    return ConnectivitySyncOrchestrator(
      healthService: healthService,
      isAuthenticated: () => authenticated,
      isOfflineModeEnabled: () => manualOffline,
      isRouteModeActive: () => routeMode,
      getOfflineSyncService: () => offlineSyncService,
      getOfflineQueue: () => offlineQueue,
      syncCriticalData:
          syncCriticalData ??
          () async {
            syncCalls++;
          },
      pollingInterval: const Duration(minutes: 1),
      periodicTimerFactory: (interval, callback) {
        expect(interval, const Duration(minutes: 1));
        periodicTimer = _ControlledPeriodicTimer(callback);
        return periodicTimer;
      },
    );
  }

  setUp(() {
    healthService = ServerHealthService();
    healthService.recordSuccess();
    authenticated = true;
    manualOffline = false;
    routeMode = false;
    syncCalls = 0;
  });

  tearDown(() => healthService.dispose());

  test('reconciles immediately, then on the injected interval', () async {
    final orchestrator = buildOrchestrator()..initialize();
    addTearDown(orchestrator.dispose);

    await _flushAsync();
    expect(syncCalls, 1);

    periodicTimer.fire();
    await _flushAsync();

    expect(syncCalls, 2);
  });

  test('periodic poll drains the durable queue before catalogs without a connectivity change', () async {
    final queue = _MockOfflineQueueDataSource();
    final syncService = _MockOfflineSyncService();
    final order = <String>[];
    when(queue.getPendingOperations).thenAnswer(
      (_) async => [
        OfflineOperation(
          id: 1,
          model: 'sale.order',
          method: 'write',
          recordId: 42,
          values: const {'name': 'SO42'},
          createdAt: DateTime(2026, 8, 26),
          replayPolicy: OfflineReplayPolicy.retrySafe,
        ),
      ],
    );
    when(syncService.processQueue).thenAnswer((_) async {
      order.add('queue');
      return SyncResult.success(model: 'queue', synced: 1);
    });
    final orchestrator = buildOrchestrator(
      offlineSyncService: syncService,
      offlineQueue: queue,
      syncCriticalData: () async {
        order.add('catalog');
      },
    )..initialize();
    addTearDown(orchestrator.dispose);

    // The health state was online before initialize and never changes. The
    // initial reconciliation must still run exactly once.
    await _flushAsync();
    await _flushAsync();

    expect(order, ['queue', 'catalog']);
    verify(syncService.processQueue).called(1);
  });

  test(
    'contains an initial queue failure and retries on the next tick',
    () async {
      final queue = _MockOfflineQueueDataSource();
      final syncService = _MockOfflineSyncService();
      var attempts = 0;
      when(queue.getPendingOperations).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 1,
            model: 'sale.order',
            method: 'write',
            recordId: 42,
            values: const {},
            createdAt: DateTime(2026, 8, 26),
            replayPolicy: OfflineReplayPolicy.retrySafe,
          ),
        ],
      );
      when(syncService.processQueue).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw StateError('temporary database error');
        return SyncResult.success(model: 'queue', synced: 1);
      });
      final orchestrator = buildOrchestrator(
        offlineSyncService: syncService,
        offlineQueue: queue,
      )..initialize();
      addTearDown(orchestrator.dispose);

      await _flushAsync();
      await _flushAsync();
      expect(syncCalls, 0);

      periodicTimer.fire();
      await _flushAsync();
      await _flushAsync();

      expect(attempts, 2);
      expect(syncCalls, 1);
    },
  );

  test(
    'queue inspection failure blocks catalogs and retries on the next tick',
    () async {
      final queue = _MockOfflineQueueDataSource();
      final syncService = _MockOfflineSyncService();
      var inspections = 0;
      when(queue.getPendingOperations).thenAnswer((_) async {
        inspections++;
        if (inspections == 1) {
          throw StateError('temporary queue read error');
        }
        return const <OfflineOperation>[];
      });
      final orchestrator = buildOrchestrator(
        offlineQueue: queue,
        offlineSyncService: syncService,
      )..initialize();
      addTearDown(orchestrator.dispose);

      await _flushAsync();
      await _flushAsync();
      expect(syncCalls, 0);

      periodicTimer.fire();
      await _flushAsync();
      await _flushAsync();

      expect(inspections, 2);
      expect(syncCalls, 1);
    },
  );

  test('requires authentication and a fully online session', () async {
    authenticated = false;
    final orchestrator = buildOrchestrator()..initialize();
    addTearDown(orchestrator.dispose);

    await _flushAsync();
    expect(syncCalls, 0);

    authenticated = true;
    healthService.recordSessionExpired();
    periodicTimer.fire();
    await _flushAsync();
    expect(syncCalls, 0);
  });

  test('skips manual offline and route modes on every tick', () async {
    manualOffline = true;
    final orchestrator = buildOrchestrator()..initialize();
    addTearDown(orchestrator.dispose);

    await _flushAsync();
    expect(syncCalls, 0);

    manualOffline = false;
    routeMode = true;
    periodicTimer.fire();
    await _flushAsync();
    expect(syncCalls, 0);

    routeMode = false;
    periodicTimer.fire();
    await _flushAsync();
    expect(syncCalls, 1);
  });

  test('does not overlap periodic sync executions', () async {
    final firstSync = Completer<void>();
    final orchestrator = buildOrchestrator(
      syncCriticalData: () {
        syncCalls++;
        return firstSync.future;
      },
    )..initialize();
    addTearDown(orchestrator.dispose);

    await _flushAsync();
    periodicTimer.fire();
    await _flushAsync();
    expect(syncCalls, 1);

    firstSync.complete();
    await _flushAsync();
  });

  test('dispose cancels the polling timer', () async {
    authenticated = false;
    final orchestrator = buildOrchestrator()..initialize();

    orchestrator.dispose();
    expect(periodicTimer.isActive, isFalse);
    periodicTimer.fire();
    await _flushAsync();

    expect(syncCalls, 0);
  });

  test(
    'dispose during queue drain cannot continue into the old session catalogs',
    () async {
      final queue = _MockOfflineQueueDataSource();
      final syncService = _MockOfflineSyncService();
      final queueStarted = Completer<void>();
      final releaseQueue = Completer<SyncResult>();
      when(queue.getPendingOperations).thenAnswer(
        (_) async => [
          OfflineOperation(
            id: 1,
            model: 'sale.order',
            method: 'write',
            recordId: 42,
            values: const {},
            createdAt: DateTime(2026, 8, 26),
            replayPolicy: OfflineReplayPolicy.retrySafe,
          ),
        ],
      );
      when(syncService.processQueue).thenAnswer((_) {
        if (!queueStarted.isCompleted) queueStarted.complete();
        return releaseQueue.future;
      });

      final orchestrator = buildOrchestrator(
        offlineSyncService: syncService,
        offlineQueue: queue,
      )..initialize();

      await queueStarted.future;
      orchestrator.dispose();
      releaseQueue.complete(SyncResult.success(model: 'queue', synced: 1));
      await _flushAsync();
      await _flushAsync();

      expect(syncCalls, 0);
    },
  );

  test('rejects a zero polling interval', () {
    expect(
      () => ConnectivitySyncOrchestrator(
        healthService: healthService,
        isAuthenticated: () => true,
        isOfflineModeEnabled: () => false,
        getOfflineSyncService: () => null,
        getOfflineQueue: () => null,
        syncCriticalData: () async {},
        pollingInterval: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}

Future<void> _flushAsync() => Future<void>.delayed(Duration.zero);

final class _ControlledPeriodicTimer implements Timer {
  _ControlledPeriodicTimer(this._callback);

  final void Function(Timer timer) _callback;
  bool _active = true;
  int _tick = 0;

  void fire() {
    if (!_active) return;
    _tick++;
    _callback(this);
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  @override
  void cancel() => _active = false;
}
