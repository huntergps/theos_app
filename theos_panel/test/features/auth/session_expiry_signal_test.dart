// Contrato (auditoría de sesión, 13-sep-2026): cuando el servidor rechaza la
// clave API — el sondeo del backend contesta 401, o un trabajo de
// sincronización se topa con la misma `OdooAuthenticationException` — el
// coordinador debe publicar una señal ESTRUCTURADA y distinguible de
// cualquier otro fallo de red, nunca sólo un mensaje de texto libre.
//
// Antes de este arreglo (ver `AuthStatus.expired` en
// orbi_runtime/lib/src/contracts.dart:162 y `BackendProbeResult.authStatus`
// en connectivity_monitor.dart:81-85), el coordinador SÍ detectaba el 401
// pero sólo publicaba el mensaje genérico "El servidor no respondió a la
// comprobación previa" — engañoso para un 401, porque el servidor SÍ
// respondió, sólo que rechazó la credencial — y nada aguas arriba podía
// distinguirlo de una caída de wifi cualquiera.
//
// Medido ahora: `SyncFailure.authStatus` lleva `AuthStatus.expired` en ese
// caso concreto (sync_coordinator_impl.dart), y `SyncSnapshot.sessionExpired`
// lo expone como un booleano derivado que el router puede consumir sin
// adivinar nada de un mensaje de texto.
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

class _FakeUnauthorizedProbe implements BackendProbe {
  int calls = 0;
  @override
  Future<BackendProbeResult> probe(AppScope scope) async {
    calls++;
    return BackendProbeResult.unauthorized(errorCode: 'invalid_apikey');
  }
}

class _NoopJob implements SyncJob {
  @override
  String get id => 'noop';
  @override
  Future<SyncJobResult> run(AppScope scope) async =>
      const SyncJobResult.committed();
}

/// Simula un trabajo de sincronización real (p. ej. drenar la cola offline)
/// que se topa con el 401 directamente en su propia llamada RPC, no sólo en
/// el sondeo dedicado.
class _RejectedJob implements SyncJob {
  @override
  String get id => 'offline-queue';
  @override
  Future<SyncJobResult> run(AppScope scope) async {
    throw const OdooSessionExpiredException();
  }
}

AppScope _scope() => AppScope(
  appId: 'theos_panel',
  installationId: 'audit-install',
  normalizedServerUrl: 'https://erp2.tecnosmart.com.ec',
  database: 'erp2_tecnosmart_com_ec',
  userId: 9,
);

void main() {
  group('señal de sesión expirada (sync_coordinator_impl)', () {
    test(
      'el sondeo con 401 produce un SyncFailure con authStatus=expired y '
      'SyncSnapshot.sessionExpired en true',
      () async {
        final probe = _FakeUnauthorizedProbe();
        final coordinator = SyncCoordinatorImpl(
          jobs: [_NoopJob()],
          backendProbe: probe,
        );
        await coordinator.start(_scope());

        expect(probe.calls, greaterThan(0));
        expect(coordinator.lastProbe?.state, BackendProbeState.unauthorized);
        final failure = coordinator.snapshot.failures.single;
        expect(failure.jobId, 'backend-probe');
        expect(failure.authStatus, AuthStatus.expired);
        expect(
          failure.message,
          'La sesión caducó: vuelve a ingresar.',
          reason:
              'ya no dice "no respondió": el servidor SÍ respondió y '
              'rechazó la clave — decirlo distinto es justo el punto.',
        );
        expect(coordinator.snapshot.sessionExpired, isTrue);
      },
    );

    test(
      'un trabajo que se topa con OdooSessionExpiredException marca la '
      'misma señal estructurada, no sólo el sondeo dedicado',
      () async {
        final coordinator = SyncCoordinatorImpl(jobs: [_RejectedJob()]);
        await coordinator.start(_scope());

        final failure = coordinator.snapshot.failures.single;
        expect(failure.jobId, 'offline-queue');
        expect(failure.authStatus, AuthStatus.expired);
        expect(coordinator.snapshot.sessionExpired, isTrue);
      },
    );

    test(
      'un fallo de red ordinario (sin sondeo) NO se confunde con sesión '
      'expirada: authStatus queda null y sessionExpired en false',
      () async {
        final coordinator = SyncCoordinatorImpl(
          jobs: [
            _FailingJob(StateError('timeout de red, nada que ver con auth')),
          ],
        );
        await coordinator.start(_scope());

        final failure = coordinator.snapshot.failures.single;
        expect(failure.authStatus, isNull);
        expect(coordinator.snapshot.sessionExpired, isFalse);
      },
    );
  });
}

class _FailingJob implements SyncJob {
  _FailingJob(this.error);
  final Object error;
  @override
  String get id => 'failing';
  @override
  Future<SyncJobResult> run(AppScope scope) async => throw error;
}
