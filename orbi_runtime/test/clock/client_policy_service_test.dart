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
}
