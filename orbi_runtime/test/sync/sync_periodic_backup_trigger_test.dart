import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/realtime/realtime_status.dart';
import 'package:orbi_runtime/src/sync/sync_periodic_backup_trigger.dart';

/// Hueco 2 del encargo del 14-sep-2026: sin este disparador, si el tiempo
/// real se cae nada vuelve a sincronizar solo hasta que cambie la red o la
/// app vuelva al frente (`SyncAutoResyncTrigger` sólo reacciona a FILOS, no
/// sondea con un `Timer.periodic` propio). `theos_pos` sí sondea cada 5 min
/// (`connectivity_sync_orchestrator.dart:63,105-108`); Orbi no tenía nada
/// equivalente.
final class _CountingCoordinator implements SyncCoordinator {
  int runs = 0;
  final List<String> reasons = [];

  @override
  Future<void> start(AppScope scope) async {}

  @override
  Future<void> requestSync(SyncReason reason) async {
    runs++;
    reasons.add(reason.code);
  }

  @override
  Future<void> pause(PauseReason reason) async {}

  @override
  Future<void> stop(AppScope scope) async {}
}

void main() {
  test(
    'tiempo real caído + red + primer plano: a los 5 minutos se pide '
    'exactamente UNA sincronización por el coordinador',
    () {
      fakeAsync((async) {
        final coordinator = _CountingCoordinator();
        final online = StreamController<bool>();
        final foreground = StreamController<bool>();
        final realtime = StreamController<RealtimeStatus>();
        final trigger = SyncPeriodicBackupTrigger(
          coordinator: coordinator,
          online: online.stream,
          foreground: foreground.stream,
          realtimeStatus: realtime.stream,
        );
        addTearDown(trigger.dispose);

        online.add(true);
        foreground.add(true);
        realtime.add(RealtimeStatus.retrying);
        async.flushMicrotasks();

        expect(coordinator.runs, 0);
        async.elapse(syncPeriodicBackupInterval);
        expect(coordinator.runs, 1);
        expect(coordinator.reasons.single, contains('periodic_backup'));

        unawaited(online.close());
        unawaited(foreground.close());
        unawaited(realtime.close());
      });
    },
  );

  test(
    'tiempo real conectado (live): no se pide ninguna sincronización aunque '
    'pase de sobra el intervalo',
    () {
      fakeAsync((async) {
        final coordinator = _CountingCoordinator();
        final online = StreamController<bool>();
        final foreground = StreamController<bool>();
        final realtime = StreamController<RealtimeStatus>();
        final trigger = SyncPeriodicBackupTrigger(
          coordinator: coordinator,
          online: online.stream,
          foreground: foreground.stream,
          realtimeStatus: realtime.stream,
        );
        addTearDown(trigger.dispose);

        online.add(true);
        foreground.add(true);
        realtime.add(RealtimeStatus.live);
        async.flushMicrotasks();

        async.elapse(syncPeriodicBackupInterval * 2);
        expect(coordinator.runs, 0);

        unawaited(online.close());
        unawaited(foreground.close());
        unawaited(realtime.close());
      });
    },
  );

  test(
    'al pasar a segundo plano el temporizador se detiene: aunque pase mucho '
    'más de 5 minutos, no se pide sincronización',
    () {
      fakeAsync((async) {
        final coordinator = _CountingCoordinator();
        final online = StreamController<bool>();
        final foreground = StreamController<bool>();
        final realtime = StreamController<RealtimeStatus>();
        final trigger = SyncPeriodicBackupTrigger(
          coordinator: coordinator,
          online: online.stream,
          foreground: foreground.stream,
          realtimeStatus: realtime.stream,
        );
        addTearDown(trigger.dispose);

        online.add(true);
        foreground.add(true);
        realtime.add(RealtimeStatus.offline);
        async.flushMicrotasks();

        async.elapse(syncPeriodicBackupInterval - const Duration(minutes: 1));
        foreground.add(false);
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 30));

        expect(coordinator.runs, 0);

        unawaited(online.close());
        unawaited(foreground.close());
        unawaited(realtime.close());
      });
    },
  );

  test(
    'al conectarse el tiempo real a mitad de cuenta, el temporizador se '
    'detiene; si vuelve a caer, arranca una cuenta NUEVA de 5 minutos, no '
    'retoma la anterior',
    () {
      fakeAsync((async) {
        final coordinator = _CountingCoordinator();
        final online = StreamController<bool>();
        final foreground = StreamController<bool>();
        final realtime = StreamController<RealtimeStatus>();
        final trigger = SyncPeriodicBackupTrigger(
          coordinator: coordinator,
          online: online.stream,
          foreground: foreground.stream,
          realtimeStatus: realtime.stream,
        );
        addTearDown(trigger.dispose);

        online.add(true);
        foreground.add(true);
        realtime.add(RealtimeStatus.retrying);
        async.flushMicrotasks();

        // Se conecta a los 4 minutos: nunca llega a disparar en esta cuenta.
        async.elapse(const Duration(minutes: 4));
        realtime.add(RealtimeStatus.live);
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 2));
        expect(coordinator.runs, 0);

        // Vuelve a caer: la cuenta arranca DESDE CERO, no desde los 4
        // minutos que ya habían pasado antes de conectarse.
        realtime.add(RealtimeStatus.retrying);
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 4));
        expect(coordinator.runs, 0);
        async.elapse(const Duration(minutes: 1));
        expect(coordinator.runs, 1);

        unawaited(online.close());
        unawaited(foreground.close());
        unawaited(realtime.close());
      });
    },
  );

  test('sin red: no se pide ninguna sincronización', () {
    fakeAsync((async) {
      final coordinator = _CountingCoordinator();
      final online = StreamController<bool>();
      final foreground = StreamController<bool>();
      final realtime = StreamController<RealtimeStatus>();
      final trigger = SyncPeriodicBackupTrigger(
        coordinator: coordinator,
        online: online.stream,
        foreground: foreground.stream,
        realtimeStatus: realtime.stream,
      );
      addTearDown(trigger.dispose);

      online.add(false);
      foreground.add(true);
      realtime.add(RealtimeStatus.offline);
      async.flushMicrotasks();

      async.elapse(const Duration(minutes: 30));
      expect(coordinator.runs, 0);

      unawaited(online.close());
      unawaited(foreground.close());
      unawaited(realtime.close());
    });
  });
}
