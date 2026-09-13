/// Contrato del ciclo de vida del socket de tiempo real (`RealtimeSyncCoordinator`).
/// Cubre, del encargo de la tarea:
///
///   C. 404 en `/app_sync/realtime/session` → estado `disabled`, sin
///      reintentos nunca más (aunque pase mucho tiempo).
///   D. cierre 4001 → pide una sesión nueva y reconecta con el `last`
///      persistido.
///   E. reconexión tras un corte → dispara una pasada incremental de TODOS
///      los catálogos (nunca sólo uno).
///   F. cambio de ámbito → el socket anterior se cierra y el `last` de la
///      nueva sesión NO hereda el de la anterior.
///   G. `bus/subscription_outdated` (el servidor dice que el `last` que
///      mandamos en `subscribe` ya no existe en `bus.bus`) → pasada
///      incremental de TODOS los catálogos, igual que tras un corte;
///      `bus/last_id_reset` (el servidor corrigió el `last`) → se persiste
///      el valor corregido a través del mismo `writeLastNotificationId` de
///      siempre.
///
/// (Las pistas A/B — antirrebote y filtro por modelo/empresa — viven en
/// `realtime_change_debouncer_test.dart`, que sólo necesita el debouncer.)
library;

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart' hide SyncCoordinator;
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/realtime/realtime_session_client.dart';
import 'package:orbi_runtime/src/realtime/realtime_status.dart';
import 'package:orbi_runtime/src/realtime/realtime_sync_coordinator.dart';

import 'support/fake_websocket_channel.dart';

AppScope _scope(int userId) => AppScope(
  appId: 'orbi-panel',
  installationId: 'install',
  normalizedServerUrl: 'https://erp.test',
  database: 'db',
  userId: userId,
);

final class _RecordingSyncCoordinator implements SyncCoordinator {
  final List<SyncReason> reasons = [];

  @override
  Future<void> start(AppScope scope) async {}

  @override
  Future<void> requestSync(SyncReason reason) async {
    reasons.add(reason);
  }

  @override
  Future<void> pause(PauseReason reason) async {}

  @override
  Future<void> stop(AppScope scope) async {}
}

final class _ScriptedSessionClient implements RealtimeSessionClient {
  _ScriptedSessionClient(this._script);
  final Future<RealtimeCredential> Function() _script;
  int calls = 0;

  @override
  Future<RealtimeCredential> createSession() {
    calls++;
    return _script();
  }
}

RealtimeCredential _credential(int n) => RealtimeCredential(
  ticket: 'ticket-$n',
  expiresAt: DateTime.now().add(const Duration(seconds: 30)),
  sessionExpiresAt: DateTime.now().add(const Duration(hours: 1)),
);

OdooWebSocketService _serviceFactory(List<FakeWebSocketChannel> channels) =>
    OdooWebSocketService(
      connectionManager: WebSocketConnectionManager(
        channelFactory: (uri, baseUrl, {database}) async {
          final channel = FakeWebSocketChannel();
          channels.add(channel);
          return channel;
        },
      ),
    );

Map<String, dynamic> _incoming(int id) => {
  'id': id,
  'message': {'type': 'unmapped_type', 'payload': <String, dynamic>{}},
};

void main() {
  group('C — 404 en la sesión de tiempo real', () {
    test('estado disabled, y nunca vuelve a llamar al servidor', () {
      fakeAsync((async) {
        final channels = <FakeWebSocketChannel>[];
        final sessionClient = _ScriptedSessionClient(
          () async => throw const RealtimeUnsupportedException(),
        );
        final syncCoordinator = _RecordingSyncCoordinator();
        final coordinator = RealtimeSyncCoordinator(
          syncCoordinator: syncCoordinator,
          modelJobIds: const {},
          sessionClientFor: (_) => sessionClient,
          readLastNotificationId: (_) async => null,
          writeLastNotificationId: (_, _) async {},
          online: const Stream<bool>.empty(),
          createService: () => _serviceFactory(channels),
        );

        unawaited(coordinator.start(_scope(1)));
        async.flushMicrotasks();

        expect(sessionClient.calls, 1);
        expect(coordinator.currentStatus, RealtimeStatus.disabled);
        expect(channels, isEmpty, reason: 'nunca debe abrir el socket');

        async.elapse(const Duration(minutes: 30));
        async.flushMicrotasks();

        expect(
          sessionClient.calls,
          1,
          reason: 'un 404 no se reintenta nunca, ni con backoff',
        );
        expect(coordinator.currentStatus, RealtimeStatus.disabled);

        unawaited(coordinator.dispose());
      });
    });
  });

  group('D — cierre 4001', () {
    test('pide una sesión nueva y reconecta con el last persistido', () {
      fakeAsync((async) {
        final channels = <FakeWebSocketChannel>[];
        final sessionClient = _ScriptedSessionClient(
          () async => _credential(1),
        );
        final syncCoordinator = _RecordingSyncCoordinator();
        final coordinator = RealtimeSyncCoordinator(
          syncCoordinator: syncCoordinator,
          modelJobIds: const {},
          sessionClientFor: (_) => sessionClient,
          readLastNotificationId: (_) async => 0,
          writeLastNotificationId: (_, _) async {},
          online: const Stream<bool>.empty(),
          createService: () => _serviceFactory(channels),
        );

        unawaited(coordinator.start(_scope(1)));
        async.flushMicrotasks();
        expect(channels, hasLength(1));

        // Un aviso llega antes del corte: avanza el `last` que se debe
        // reenviar al reconectar.
        channels.single.addIncoming(jsonEncode(_incoming(55)));
        async.flushMicrotasks();

        channels.single.simulateClose(4001, 'SESSION_EXPIRED');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 6)); // backoff inicial (~4s ±20%)
        async.flushMicrotasks();

        expect(
          sessionClient.calls,
          2,
          reason: 'debe pedir una sesión nueva al reconectar',
        );
        expect(channels, hasLength(2));
        final resubscribe = channels[1].sentMessages
            .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
            .firstWhere((m) => m['event_name'] == 'subscribe');
        expect((resubscribe['data'] as Map)['last'], 55);

        unawaited(coordinator.dispose());
      });
    });
  });

  group('E — reconexión tras un corte', () {
    test('dispara una pasada incremental de TODOS los catálogos', () {
      fakeAsync((async) {
        final channels = <FakeWebSocketChannel>[];
        final sessionClient = _ScriptedSessionClient(
          () async => _credential(1),
        );
        final syncCoordinator = _RecordingSyncCoordinator();
        final coordinator = RealtimeSyncCoordinator(
          syncCoordinator: syncCoordinator,
          modelJobIds: const {
            'product.product': {'products'},
          },
          sessionClientFor: (_) => sessionClient,
          readLastNotificationId: (_) async => 0,
          writeLastNotificationId: (_, _) async {},
          online: const Stream<bool>.empty(),
          createService: () => _serviceFactory(channels),
        );

        unawaited(coordinator.start(_scope(1)));
        async.flushMicrotasks();
        expect(coordinator.currentStatus, RealtimeStatus.live);

        // Corte abrupto (sin código de cierre explícito del servidor).
        channels.single.simulateClose();
        async.flushMicrotasks();
        expect(coordinator.currentStatus, RealtimeStatus.retrying);
        expect(
          syncCoordinator.reasons.where((r) => r.code == 'realtime:reconnect'),
          isEmpty,
          reason: 'todavía no reconectó, no debe disparar nada aún',
        );

        async.elapse(const Duration(seconds: 6)); // backoff inicial (~4s ±20%)
        async.flushMicrotasks();

        expect(coordinator.currentStatus, RealtimeStatus.live);
        final reconnectReasons = syncCoordinator.reasons.where(
          (r) => r.code == 'realtime:reconnect',
        );
        expect(reconnectReasons, hasLength(1));
        expect(
          reconnectReasons.single.onlyJobIds,
          isNull,
          reason: 'TODOS los catálogos, no restringido a uno solo',
        );

        unawaited(coordinator.dispose());
      });
    });

    test('una reconexión planificada por renovación de credencial (isReconnection=false) no dispara nada', () {
      fakeAsync((async) {
        final channels = <FakeWebSocketChannel>[];
        var credentialCalls = 0;
        final sessionClient = _ScriptedSessionClient(() async {
          credentialCalls++;
          return RealtimeCredential(
            ticket: 'ticket-$credentialCalls',
            expiresAt: DateTime.now().add(const Duration(seconds: 30)),
            sessionExpiresAt: DateTime.now().add(const Duration(seconds: 5)),
          );
        });
        final syncCoordinator = _RecordingSyncCoordinator();
        final coordinator = RealtimeSyncCoordinator(
          syncCoordinator: syncCoordinator,
          modelJobIds: const {},
          sessionClientFor: (_) => sessionClient,
          readLastNotificationId: (_) async => 0,
          writeLastNotificationId: (_, _) async {},
          online: const Stream<bool>.empty(),
          createService: () => _serviceFactory(channels),
        );

        unawaited(coordinator.start(_scope(1)));
        async.flushMicrotasks();
        expect(coordinator.currentStatus, RealtimeStatus.live);

        // Pasa la caducidad de la credencial: renovación proactiva, sana.
        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();

        expect(credentialCalls, 2);
        expect(coordinator.currentStatus, RealtimeStatus.live);
        expect(
          syncCoordinator.reasons.where((r) => r.code == 'realtime:reconnect'),
          isEmpty,
          reason: 'una renovación planificada no es "tras un corte"',
        );

        unawaited(coordinator.dispose());
      });
    });
  });

  group('F — cambio de ámbito', () {
    test('el socket anterior se cierra y el last no se reutiliza', () {
      fakeAsync((async) {
        final channels = <FakeWebSocketChannel>[];
        final lastByScope = <String, int>{};
        final sessionClient = _ScriptedSessionClient(
          () async => _credential(1),
        );
        final syncCoordinator = _RecordingSyncCoordinator();
        final coordinator = RealtimeSyncCoordinator(
          syncCoordinator: syncCoordinator,
          modelJobIds: const {},
          sessionClientFor: (_) => sessionClient,
          readLastNotificationId: (scope) async => lastByScope[scope.scopeKey],
          writeLastNotificationId: (scope, value) async {
            lastByScope[scope.scopeKey] = value;
          },
          online: const Stream<bool>.empty(),
          createService: () => _serviceFactory(channels),
        );

        final scopeA = _scope(1);
        final scopeB = _scope(2);

        unawaited(coordinator.start(scopeA));
        async.flushMicrotasks();
        expect(channels, hasLength(1));
        expect(channels.single.isClosed, isFalse);

        channels.single.addIncoming(jsonEncode(_incoming(42)));
        async.flushMicrotasks();
        expect(lastByScope[scopeA.scopeKey], 42);

        unawaited(coordinator.start(scopeB));
        async.flushMicrotasks();

        expect(
          channels.first.isClosed,
          isTrue,
          reason: 'el socket del ámbito anterior debe cerrarse',
        );
        expect(channels, hasLength(2));

        final subscribeB = channels[1].sentMessages
            .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
            .firstWhere((m) => m['event_name'] == 'subscribe');
        expect(
          (subscribeB['data'] as Map)['last'],
          0,
          reason: 'B no hereda el last de A',
        );
        expect(lastByScope.containsKey(scopeB.scopeKey), isFalse);

        unawaited(coordinator.dispose());
      });
    });
  });

  group('G — mensajes internos del bus (bookkeeping de subscribe)', () {
    test(
      'bus/subscription_outdated dispara una pasada incremental de TODOS los catálogos',
      () {
        fakeAsync((async) {
          final channels = <FakeWebSocketChannel>[];
          final sessionClient = _ScriptedSessionClient(
            () async => _credential(1),
          );
          final syncCoordinator = _RecordingSyncCoordinator();
          final coordinator = RealtimeSyncCoordinator(
            syncCoordinator: syncCoordinator,
            modelJobIds: const {},
            sessionClientFor: (_) => sessionClient,
            readLastNotificationId: (_) async => 0,
            writeLastNotificationId: (_, _) async {},
            online: const Stream<bool>.empty(),
            createService: () => _serviceFactory(channels),
          );

          unawaited(coordinator.start(_scope(1)));
          async.flushMicrotasks();
          expect(coordinator.currentStatus, RealtimeStatus.live);

          channels.single.addIncoming(
            jsonEncode([
              {
                'type': 'bus/subscription_outdated',
                'internal': true,
                'payload': null,
              },
            ]),
          );
          async.flushMicrotasks();

          final reasons = syncCoordinator.reasons.where(
            (r) => r.code == 'realtime:subscription_outdated',
          );
          expect(reasons, hasLength(1));
          expect(reasons.single.onlyJobIds, isNull);

          unawaited(coordinator.dispose());
        });
      },
    );

    test('bus/last_id_reset persiste el last corregido por el servidor', () {
      fakeAsync((async) {
        final channels = <FakeWebSocketChannel>[];
        final persisted = <int>[];
        final sessionClient = _ScriptedSessionClient(
          () async => _credential(1),
        );
        final syncCoordinator = _RecordingSyncCoordinator();
        final coordinator = RealtimeSyncCoordinator(
          syncCoordinator: syncCoordinator,
          modelJobIds: const {},
          sessionClientFor: (_) => sessionClient,
          readLastNotificationId: (_) async => 0,
          writeLastNotificationId: (_, value) async {
            persisted.add(value);
          },
          online: const Stream<bool>.empty(),
          createService: () => _serviceFactory(channels),
        );

        unawaited(coordinator.start(_scope(1)));
        async.flushMicrotasks();

        channels.single.addIncoming(
          jsonEncode([
            {'type': 'bus/last_id_reset', 'internal': true, 'payload': 777},
          ]),
        );
        async.flushMicrotasks();

        expect(persisted, contains(777));

        unawaited(coordinator.dispose());
      });
    });
  });
}
