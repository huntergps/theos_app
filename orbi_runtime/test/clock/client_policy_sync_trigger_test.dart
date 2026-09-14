import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/clock/client_policy_sync_trigger.dart';

void main() {
  test(
    'periodic sync every 15 minutes only while online and foreground',
    () {
      fakeAsync((async) {
        var runs = 0;
        final online = StreamController<bool>();
        final foreground = StreamController<bool>();
        final trigger = ClientPolicySyncTrigger(
          sync: () async => runs++,
          online: online.stream,
          foreground: foreground.stream,
        );
        addTearDown(trigger.dispose);

        online.add(true);
        foreground.add(true);
        async.flushMicrotasks();
        expect(runs, 0);

        async.elapse(clientPolicySyncInterval);
        expect(runs, 1);

        async.elapse(clientPolicySyncInterval);
        expect(runs, 2);

        // Pasa a segundo plano: el temporizador se detiene, aunque pase de
        // sobra el intervalo.
        foreground.add(false);
        async.flushMicrotasks();
        async.elapse(clientPolicySyncInterval * 3);
        expect(runs, 2);

        // Vuelve al frente: filo de primer plano dispara una sincronización
        // inmediata, y la cuenta periódica arranca de nuevo desde cero.
        foreground.add(true);
        async.flushMicrotasks();
        expect(runs, 3);
        async.elapse(clientPolicySyncInterval - const Duration(minutes: 1));
        expect(runs, 3);
        async.elapse(const Duration(minutes: 1));
        expect(runs, 4);

        // Sin red: tampoco corre, aunque siga en primer plano.
        online.add(false);
        async.flushMicrotasks();
        async.elapse(clientPolicySyncInterval * 2);
        expect(runs, 4);

        unawaited(online.close());
        unawaited(foreground.close());
      });
    },
  );

  test('el filo inicial no cuenta: nace ya online y en primer plano', () {
    fakeAsync((async) {
      var runs = 0;
      final online = StreamController<bool>();
      final foreground = StreamController<bool>();
      final trigger = ClientPolicySyncTrigger(
        sync: () async => runs++,
        online: online.stream,
        foreground: foreground.stream,
      );
      addTearDown(trigger.dispose);

      online.add(true);
      foreground.add(true);
      async.flushMicrotasks();

      // El primer valor de cada stream (true) no es un filo: nunca dispara
      // una sincronización inmediata por su cuenta, sólo la cuenta
      // periódica normal.
      expect(runs, 0);

      unawaited(online.close());
      unawaited(foreground.close());
    });
  });
}
