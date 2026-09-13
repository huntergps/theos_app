@TestOn('vm')
library;

// Medición/verificación OPT-IN del tiempo real (`RealtimeSyncCoordinator`,
// `orbi_runtime`) contra un ERP2 real — nunca simulado.
//
// Se salta sola cuando faltan sus variables (la misma convención que el
// resto del repo usa para un Odoo real: `ORBI_ERP2_SERVER_URL`,
// `ORBI_ERP2_DATABASE`, `ORBI_ERP2_SELLER_LOGIN`, `ORBI_ERP2_SELLER_PASSWORD`
// — las mismas claves que `Erp2HarnessConfig.fromEnvironment` y las que ya
// trae `~/.config/tecnosmart/orbi_erp2_actors.env`). Usa el vendedor REAL ya
// configurado para las auditorías de Orbi — nunca se crea un usuario de
// prueba nuevo.
//
// Además se salta en TIEMPO DE EJECUCIÓN (no con el `skip:` del group, que
// sólo conoce las variables de entorno) si `/app_sync/realtime/session`
// responde 404: el módulo `l10n_ec_app_sync` todavía no está desplegado en
// ERP2. Eso es un `markTestSkipped`, nunca un fallo.
//
// Nunca imprime el secreto de la llave ni el ticket, sólo longitudes,
// estados y la latencia medida — igual que el resto de mediciones de
// auditoría.
//
// No crea datos: el propio vendedor reescribe un campo propio de su
// `res.users` (`tz`) con el MISMO valor que ya tiene. `l10n_ec_app_sync`
// avisa igual en una escritura sin cambio real (ver `models/app_sync.py`:
// `write()` sólo mira que `vals` no esté vacío), y el canal del propio
// usuario ya está concedido por `_app_sync_subscription_channels`.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart' hide SyncCoordinator;
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/auth/web_credential_store.dart'
    show WebAuthCredential;
import 'package:theos_panel/features/auth/web_token_auth.dart';

/// El coordinador de sincronización real no importa a esta prueba — sólo el
/// transporte de tiempo real. Un catálogo vacío (`modelJobIds: const {}`)
/// ya asegura que ningún `SyncJob` real se dispare por accidente.
final class _NoopSyncCoordinator implements SyncCoordinator {
  @override
  Future<void> start(AppScope scope) async {}

  @override
  Future<void> requestSync(SyncReason reason) async {}

  @override
  Future<void> pause(PauseReason reason) async {}

  @override
  Future<void> stop(AppScope scope) async {}
}

void main() {
  final serverUrl = Platform.environment['ORBI_ERP2_SERVER_URL'];
  final database = Platform.environment['ORBI_ERP2_DATABASE'];
  final login = Platform.environment['ORBI_ERP2_SELLER_LOGIN'];
  final password = Platform.environment['ORBI_ERP2_SELLER_PASSWORD'];
  final missing =
      serverUrl == null ||
      serverUrl.isEmpty ||
      database == null ||
      database.isEmpty ||
      login == null ||
      login.isEmpty ||
      password == null ||
      password.isEmpty;

  group(
    'tiempo real contra ERP2 real (opt-in)',
    skip: missing
        ? 'set ORBI_ERP2_SERVER_URL/DATABASE/SELLER_LOGIN/SELLER_PASSWORD '
              '(p. ej. desde ~/.config/tecnosmart/orbi_erp2_actors.env) para '
              'correr esta medición'
        : null,
    () {
      // UNA sola llave para todo el group (setUpAll/tearDownAll, no
      // setUp/tearDown): emitir una por prueba encadena altas y bajas de
      // API key sin necesidad — con dos pruebas, dos de más. Ambas pruebas
      // sólo LEEN (o reescriben con el mismo valor) el mismo `res.users`,
      // así que compartir sesión entre ellas no arriesga nada.
      late WebAuthCredential issued;
      late OdooClient client;
      late String? originalTz;

      setUpAll(() async {
        final tokenClient = OrbiWebTokenAuthClient(
          transport: odooSdkTokenTransport(),
        );
        issued = await tokenClient.issue(
          serverUrl: serverUrl!,
          login: login!,
          password: password!,
          database: database,
        );
        client = OdooClient(
          config: OdooClientConfig(
            baseUrl: serverUrl,
            database: issued.database,
            apiKey: issued.apiKey,
          ),
        );
        final rows = await client.searchRead(
          model: 'res.users',
          fields: const ['tz'],
          domain: [
            ['id', '=', issued.uid],
          ],
          limit: 1,
        );
        originalTz = rows.single['tz'] as String?;
      });

      tearDownAll(() async {
        // Best-effort: nunca dejar la llave emitida por esta prueba viva.
        try {
          await NativeAuthBootstrapAdapter().revokeOwnApiKey(
            baseUrl: serverUrl!,
            database: issued.database,
            apiKey: issued.apiKey,
          );
        } catch (_) {
          // Igual que el resto de las mediciones: revocar es aseo, nunca
          // debe tumbar la prueba que ya corrió.
        }
      });

      /// Reescribe `tz` con su propio valor y espera el aviso `app_sync/changed`
      /// de `res.users` en el [stream] dado, con un tope de 10s. Devuelve el
      /// evento y su latencia medida desde el `write` hasta que llegó.
      Future<(OdooRawNotificationEvent, Duration)> rewriteTzAndAwait(
        Stream<OdooRawNotificationEvent> stream,
      ) async {
        final notification = stream
            .where(
              (event) =>
                  event.type == 'app_sync/changed' &&
                  event.payload['model'] == 'res.users',
            )
            .first;

        final before = DateTime.now();
        await client.call(
          model: 'res.users',
          method: 'write',
          ids: [issued.uid],
          kwargs: {
            'vals': {'tz': originalTz},
          },
        );

        final event = await notification.timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
            'no llegó app_sync/changed de res.users en 10s',
          ),
        );
        return (event, DateTime.now().difference(before));
      }

      test(
        'app_sync/changed llega con model: res.users e ids con el propio uid, en <=10s',
        () async {
          final sessionClient = OdooRealtimeSessionClient(client);

          // Probe explícito ANTES de construir nada más: si el servidor no
          // tiene el módulo, esto es "todavía no desplegado", nunca un fallo.
          try {
            await sessionClient.createSession();
          } on RealtimeUnsupportedException {
            markTestSkipped('l10n_ec_app_sync no desplegado');
            return;
          }

          final scope = AppScope(
            appId: 'orbi-panel-e2e',
            installationId: 'erp2-realtime-e2e',
            normalizedServerUrl: serverUrl!,
            database: issued.database,
            userId: issued.uid,
          );

          final coordinator = RealtimeSyncCoordinator(
            syncCoordinator: _NoopSyncCoordinator(),
            modelJobIds: const {},
            sessionClientFor: (_) => sessionClient,
            readLastNotificationId: (_) async => null,
            writeLastNotificationId: (_, _) async {},
            online: const Stream<bool>.empty(),
          );
          addTearDown(coordinator.dispose);

          final reachedLive = coordinator.status.firstWhere(
            (status) => status == RealtimeStatus.live,
          );
          await coordinator.start(scope);
          await reachedLive.timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'RealtimeSyncCoordinator nunca llegó a RealtimeStatus.live',
            ),
          );

          final (event, latency) = await rewriteTzAndAwait(
            coordinator.rawNotifications!,
          );
          // ignore: avoid_print
          print('[ERP2 realtime] latencia app_sync/changed: $latency');

          final ids = (event.payload['ids'] as List?)
              ?.cast<num>()
              .map((n) => n.toInt());
          expect(
            ids,
            contains(issued.uid),
            reason: 'el aviso de res.users debe traer el propio uid',
          );
          expect(latency, lessThanOrEqualTo(const Duration(seconds: 10)));
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test(
        'un canal de texto equivocado nunca recibe el aviso (negativa)',
        () async {
          final sessionClient = OdooRealtimeSessionClient(client);

          try {
            await sessionClient.createSession();
          } on RealtimeUnsupportedException {
            markTestSkipped('l10n_ec_app_sync no desplegado');
            return;
          }

          // Deliberadamente por debajo de RealtimeSyncCoordinator, que
          // siempre pide el canal correcto ('app_sync'): esta prueba
          // necesita pedir uno DISTINTO para comprobar que el bus nunca lo
          // traduce a nada.
          final service = OdooWebSocketService();
          addTearDown(service.dispose);
          service.addChannels(const ['wrong_channel_never_granted']);

          final connected = service.eventsOfType<OdooConnectionEvent>().first;
          await service.connect(
            OdooWebSocketConnectionInfo(
              baseUrl: serverUrl!,
              database: issued.database,
              realtimeCredentialProvider: sessionClient.createSession,
            ),
          );
          await connected.timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'el socket nunca conectó contra ERP2',
            ),
          );

          final received = <OdooRawNotificationEvent>[];
          final subscription = service
              .eventsOfType<OdooRawNotificationEvent>()
              .where(
                (event) =>
                    event.type == 'app_sync/changed' &&
                    event.payload['model'] == 'res.users',
              )
              .listen(received.add);
          addTearDown(subscription.cancel);

          await client.call(
            model: 'res.users',
            method: 'write',
            ids: [issued.uid],
            kwargs: {
              'vals': {'tz': originalTz},
            },
          );

          // Ventana generosa: la prueba positiva ya demuestra que, por el
          // canal correcto, el aviso llega sobradamente dentro de 10s.
          await Future<void>.delayed(const Duration(seconds: 8));

          expect(
            received,
            isEmpty,
            reason:
                'un canal de texto distinto de "app_sync" nunca debe '
                'recibir el aviso: el servidor sólo traduce ese string '
                'exacto a los destinos que el usuario ya tiene concedidos '
                '(ver _build_bus_channel_list en ir_websocket.py)',
          );
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    },
  );
}
