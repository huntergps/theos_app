import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/src/clock/client_policy_service.dart';

/// Estado persistido de mentira: un `Map` en memoria, compartido entre dos
/// instancias del servicio cuando la prueba lo pasa a ambas — así se
/// comprueba "misma preferencia o base" sin montar una base Drift real.
final class _FakeState {
  String? value;

  Future<String?> read() async => value;
  Future<void> write(String json) async => value = json;
}

/// Reloj monotónico de mentira: una cola de lecturas fijas, consumida en
/// orden — `sync()` lo llama exactamente dos veces por intento (antes y
/// después del RPC), así que una cola de `[antes, después]` fija el `rtt`
/// exacto que verá la prueba.
Duration Function() _tickQueue(List<Duration> ticks) {
  var index = 0;
  return () => ticks[index++];
}

void main() {
  group('offset compensates half the round trip', () {
    test('90 s de adelanto del servidor con 200 ms de ida y vuelta', () async {
      final sentAt = DateTime.utc(2026, 1, 1, 0, 0, 0);
      final state = _FakeState();
      var rpcCalls = 0;
      final service = ClientPolicyService(
        rpc: () => () async {
          rpcCalls++;
          return {
            'server_time_utc': '2026-01-01T00:01:30.000Z',
            'offline_max_days': 3,
            'inactivity_lock_minutes': 15,
          };
        },
        readState: state.read,
        writeState: state.write,
        deviceNow: () => sentAt,
        monotonicElapsed: _tickQueue([
          Duration.zero,
          const Duration(milliseconds: 200),
        ]),
      );

      await service.sync();

      expect(rpcCalls, 1);
      expect(service.snapshot.source, ClientPolicyTimeSource.server);
      expect(service.snapshot.rtt, const Duration(milliseconds: 200));
      // offset = 90s (adelanto real) - 100ms (mitad del rtt) = 89.9s.
      expect(
        service.snapshot.offset,
        const Duration(seconds: 89, milliseconds: 900),
      );
      expect(service.nowServer(), sentAt.add(service.snapshot.offset));
    });
  });

  test(
    'missing model falls back to device time once per session',
    () async {
      final state = _FakeState();
      var rpcCalls = 0;
      final service = ClientPolicyService(
        rpc: () => () async {
          rpcCalls++;
          throw const OdooNotFoundException("the model 'x' does not exist");
        },
        readState: state.read,
        writeState: state.write,
        deviceNow: () => DateTime.utc(2026, 1, 1),
      );

      await service.sync();
      expect(rpcCalls, 1);
      expect(service.snapshot.source, ClientPolicyTimeSource.device);
      expect(service.snapshot.offset, Duration.zero);
      expect(service.snapshot.rtt, isNull);
      expect(service.snapshot.offlineMaxDays, kDefaultOfflineMaxDays);
      expect(
        service.snapshot.inactivityLockMinutes,
        kDefaultInactivityLockMinutes,
      );

      // Segundo sync() en la MISMA sesión: no vuelve a llamar al RPC.
      await service.sync();
      expect(rpcCalls, 1);
    },
  );

  test(
    'network error keeps last known offset and retries next time',
    () async {
      final state = _FakeState();
      var rpcCalls = 0;
      var shouldFail = false;
      final service = ClientPolicyService(
        rpc: () => () async {
          rpcCalls++;
          if (shouldFail) {
            throw const OdooConnectionException('sin red');
          }
          return {
            'server_time_utc': '2026-01-01T00:00:10.000Z',
            'offline_max_days': 3,
            'inactivity_lock_minutes': 15,
          };
        },
        readState: state.read,
        writeState: state.write,
        deviceNow: () => DateTime.utc(2026, 1, 1),
        monotonicElapsed: () => Duration.zero,
      );

      await service.sync();
      expect(rpcCalls, 1);
      final offsetAfterSuccess = service.snapshot.offset;
      expect(service.snapshot.source, ClientPolicyTimeSource.server);

      shouldFail = true;
      await service.sync();
      expect(rpcCalls, 2);
      expect(service.snapshot.offset, offsetAfterSuccess);
      expect(service.snapshot.source, ClientPolicyTimeSource.server);

      // El memo de "modelo ausente" nunca se puso: el próximo sync() SÍ
      // vuelve a llamar al RPC.
      shouldFail = false;
      await service.sync();
      expect(rpcCalls, 3);
    },
  );

  test('offline estimate uses persisted offset', () async {
    final state = _FakeState();
    final first = ClientPolicyService(
      rpc: () => () async => {
        'server_time_utc': '2026-01-01T00:02:00.000Z',
        'offline_max_days': 3,
        'inactivity_lock_minutes': 15,
      },
      readState: state.read,
      writeState: state.write,
      deviceNow: () => DateTime.utc(2026, 1, 1),
      monotonicElapsed: () => Duration.zero,
    );
    await first.sync();
    final persistedOffset = first.snapshot.offset;
    expect(persistedOffset, isNot(Duration.zero));

    // Instancia nueva, MISMO estado persistido, sin cliente (offline).
    var rpcCalls = 0;
    final second = ClientPolicyService(
      rpc: () {
        rpcCalls++;
        return null;
      },
      readState: state.read,
      writeState: state.write,
      deviceNow: () => DateTime.utc(2026, 1, 1, 0, 5),
    );

    await second.restore();
    expect(rpcCalls, 0);
    expect(second.isEstimated, isTrue);
    expect(
      second.nowServer(),
      DateTime.utc(2026, 1, 1, 0, 5).add(persistedOffset),
    );
  });

  test('no client means no rpc', () async {
    final state = _FakeState();
    // `rpc` es la comprobación de "¿hay cliente?" — al devolver `null`
    // (sesión sin conexión), `sync()` no tiene ninguna función de
    // transporte que invocar: no existe otro sitio en esta prueba donde un
    // RPC pudiera ocurrir. Lo único que un `sync()` real haría además de
    // llamar al RPC es persistir el resultado, así que confirmar que
    // `writeState` nunca corrió es la misma comprobación desde el otro
    // lado.
    var persistCalls = 0;
    final service = ClientPolicyService(
      rpc: () => null,
      readState: state.read,
      writeState: (_) async => persistCalls++,
    );

    await service.sync();

    expect(persistCalls, 0);
    expect(service.snapshot.source, ClientPolicyTimeSource.device);
    expect(service.isEstimated, isTrue);
  });

  test('detects device clock rollback', () async {
    final state = _FakeState();
    var deviceNow = DateTime.utc(2026, 1, 1, 12, 0, 0);
    final service = ClientPolicyService(
      rpc: () => null,
      readState: state.read,
      writeState: state.write,
      deviceNow: () => deviceNow,
    );

    service.nowServer();
    expect(service.snapshot.clockRollbackSuspected, isFalse);

    // El reloj del equipo retrocede 10 minutos.
    deviceNow = deviceNow.subtract(const Duration(minutes: 10));
    service.nowServer();

    expect(service.snapshot.clockRollbackSuspected, isTrue);
  });

  // Corrección del dueño, 14-sep-2026: el caso que importa es cerrar la
  // app, atrasar el reloj del equipo y reabrir — `_lastSeenDeviceUtc` vivía
  // sólo en memoria y ese caso nunca se detectaba. Ahora se persiste igual
  // que el resto del estado, y una instancia NUEVA (que simula reabrir la
  // app) lo restaura antes de su primera lectura.
  test('persists the device clock marker across sessions', () async {
    final state = _FakeState();
    var deviceNow = DateTime.utc(2026, 1, 1, 12, 0, 0);
    final first = ClientPolicyService(
      rpc: () => null,
      readState: state.read,
      writeState: state.write,
      deviceNow: () => deviceNow,
    );
    // `nowServer()` no persiste hasta que `restore()` corrió una vez.
    await first.restore();
    first.nowServer();
    expect(state.value, isNotNull);

    // "Reabrir la app": una instancia nueva, mismo estado persistido, con
    // el reloj del equipo ya atrasado 10 minutos respecto al cierre.
    final rolledBackNow = deviceNow.subtract(const Duration(minutes: 10));
    final second = ClientPolicyService(
      rpc: () => null,
      readState: state.read,
      writeState: state.write,
      deviceNow: () => rolledBackNow,
    );
    await second.restore();

    second.nowServer();

    expect(second.snapshot.clockRollbackSuspected, isTrue);
  });

  test(
    'does not persist the device clock marker again inside one minute',
    () async {
      final state = _FakeState();
      var deviceNow = DateTime.utc(2026, 1, 1, 12, 0, 0);
      var writes = 0;
      final service = ClientPolicyService(
        rpc: () => null,
        readState: state.read,
        writeState: (json) async {
          writes++;
          await state.write(json);
        },
        deviceNow: () => deviceNow,
      );
      await service.restore();

      service.nowServer();
      expect(writes, 1);

      deviceNow = deviceNow.add(const Duration(seconds: 30));
      service.nowServer();
      expect(writes, 1, reason: 'menos de un minuto desde la última escritura');

      deviceNow = deviceNow.add(const Duration(seconds: 31));
      service.nowServer();
      expect(writes, 2, reason: 'ya pasó un minuto desde la última escritura');
    },
  );

  // Corrección del dueño, 14-sep-2026: un `readState`/`writeState` que
  // lance (lease vencido al cerrar sesión, por ejemplo) no debe escapar de
  // `sync()` — quien lo dispara lo hace con `unawaited(...)`, y una
  // excepción sin manejar ahí es un crash silencioso. Contra el commit
  // 823a2b9 esta prueba falla: `restore()`/`_persist()` llamaban a
  // `_readState`/`_writeState` fuera de cualquier `try`.
  test('sync never throws when state storage fails', () async {
    final service = ClientPolicyService(
      rpc: () => () async => {
        'server_time_utc': '2026-01-01T00:00:10.000Z',
        'offline_max_days': 3,
        'inactivity_lock_minutes': 15,
      },
      readState: () async => throw StateError('Session lease is no longer active'),
      writeState: (_) async => throw StateError('Session lease is no longer active'),
      deviceNow: () => DateTime.utc(2026, 1, 1),
      monotonicElapsed: () => Duration.zero,
    );

    await expectLater(service.sync(), completes);

    // Con el estado inaccesible, el servicio sigue funcionando con lo que
    // pudo calcular en memoria durante ESTE `sync()` — nunca revienta.
    expect(service.snapshot.source, ClientPolicyTimeSource.server);
  });

  group('user tz offset', () {
    test('reads and exposes user_tz_offset_minutes from the server', () async {
      final state = _FakeState();
      final service = ClientPolicyService(
        rpc: () => () async => {
          'server_time_utc': '2026-01-01T00:00:10.000Z',
          'offline_max_days': 3,
          'inactivity_lock_minutes': 15,
          'user_tz_offset_minutes': -240,
        },
        readState: state.read,
        writeState: state.write,
        deviceNow: () => DateTime.utc(2026, 1, 1),
        monotonicElapsed: () => Duration.zero,
      );

      await service.sync();

      expect(service.snapshot.userTzOffset, const Duration(minutes: -240));

      // Se persiste: una instancia nueva con el mismo estado lo restaura.
      final second = ClientPolicyService(
        rpc: () => null,
        readState: state.read,
        writeState: state.write,
      );
      await second.restore();
      expect(second.snapshot.userTzOffset, const Duration(minutes: -240));
    });

    test(
      'is null when the server omits user_tz_offset_minutes (old module)',
      () async {
        final state = _FakeState();
        final service = ClientPolicyService(
          rpc: () => () async => {
            'server_time_utc': '2026-01-01T00:00:10.000Z',
            'offline_max_days': 3,
            'inactivity_lock_minutes': 15,
            // Sin `user_tz_offset_minutes`: módulo viejo.
          },
          readState: state.read,
          writeState: state.write,
          deviceNow: () => DateTime.utc(2026, 1, 1),
          monotonicElapsed: () => Duration.zero,
        );

        await service.sync();

        expect(service.snapshot.userTzOffset, isNull);
      },
    );

    test('is null when the model does not exist', () async {
      final state = _FakeState();
      final service = ClientPolicyService(
        rpc: () => () async {
          throw const OdooNotFoundException("the model 'x' does not exist");
        },
        readState: state.read,
        writeState: state.write,
        deviceNow: () => DateTime.utc(2026, 1, 1),
      );

      await service.sync();

      expect(service.snapshot.userTzOffset, isNull);
    });
  });
}
