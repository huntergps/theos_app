import 'dart:async';

import 'package:odoo_sdk/odoo_sdk.dart' show OdooAuthenticationException;

import '../connectivity/connectivity_monitor.dart';
import '../contracts.dart';
import 'sync_job.dart';

/// «La app en línea» para efectos de la renovación proactiva de la clave API
/// (auditoría de sesión, 13-sep-2026): se invoca al principio de cada ciclo
/// de sincronización, antes del sondeo del backend. Cualquier excepción se
/// traga en silencio aquí mismo — ver `NativeAuthService.renewApiKeyIfNeeded`,
/// que ya es tolerante a fallos por su cuenta; este tipo sólo define el punto
/// de enganche para que `SyncCoordinatorImpl` no tenga que conocer
/// `NativeAuthService` ni ningún otro detalle de autenticación.
typedef ApiKeyRenewalTrigger = Future<void> Function(AppScope scope);

final class SyncCoordinatorImpl implements SyncCoordinator {
  SyncCoordinatorImpl({
    required Iterable<SyncJob> jobs,
    this.backendProbe,
    this.apiKeyRenewal,
  }) : _jobs = _validateJobs(jobs);

  final List<SyncJob> _jobs;
  final BackendProbe? backendProbe;

  /// Ver [ApiKeyRenewalTrigger]. `null` cuando este runtime no compone
  /// autenticación nativa (p. ej. un arnés de pruebas) — en ese caso
  /// simplemente no hay renovación proactiva, igual que hoy.
  final ApiKeyRenewalTrigger? apiKeyRenewal;
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

    // «La app en línea» — el momento de intentar renovar la clave ANTES de
    // que el sondeo pueda encontrarla ya vencida. Cualquier fallo aquí es
    // silencioso a propósito (ver ApiKeyRenewalTrigger): nunca debe impedir
    // que el resto de este ciclo corra con normalidad.
    final renew = apiKeyRenewal;
    if (renew != null) {
      try {
        await renew(scope);
      } catch (_) {
        // NativeAuthService.renewApiKeyIfNeeded ya es tolerante a fallos por
        // su cuenta; esto es sólo un cinturón adicional para un trigger que
        // no lo sea.
      }
      if (!_isCurrent(scope, epoch)) return;
    }

    if (backendProbe != null) {
      lastProbe = await backendProbe!.probe(scope);
      if (!_isCurrent(scope, epoch)) return;
      if (lastProbe!.state != BackendProbeState.reachable) {
        final expired = lastProbe!.state == BackendProbeState.unauthorized;
        _publish(
          _snapshotFor(
            active: false,
            completed: true,
            failures: [
              SyncFailure(
                jobId: 'backend-probe',
                message: expired
                    ? 'La sesión caducó: vuelve a ingresar.'
                    : 'El servidor no respondió a la comprobación previa.',
                authStatus: expired ? AuthStatus.expired : null,
              ),
            ],
          ),
        );
        return;
      }
    }

    // El error del trabajo se conserva entero. Contarlo y tirarlo era lo que
    // dejaba a la pantalla sin poder decir qué había fallado.
    final failures = <SyncFailure>[];
    // Igual con los conflictos: antes de esto, `result.conflicts` existía en
    // el trabajo pero nada del coordinador lo leía, así que
    // `SyncSnapshot.conflictCount` nunca se movía del cero inicial.
    final conflicts = <SyncConflict>[];
    _publish(_snapshotFor(active: true));
    for (final job in _jobs) {
      if (!_isCurrent(scope, epoch)) return;
      try {
        final result = await job.run(scope);
        if (!_isCurrent(scope, epoch)) return;
        conflicts.addAll(result.conflicts);
        if (!result.cursorConfirmed) {
          final error = result.error;
          failures.add(
            SyncFailure(
              jobId: job.id,
              message: '${error ?? 'No se pudo confirmar el avance.'}',
              authStatus: error is OdooAuthenticationException
                  ? AuthStatus.expired
                  : null,
            ),
          );
        }
      } catch (error) {
        if (!_isCurrent(scope, epoch)) return;
        failures.add(
          SyncFailure(
            jobId: job.id,
            message: '$error',
            authStatus: error is OdooAuthenticationException
                ? AuthStatus.expired
                : null,
          ),
        );
      }
    }
    if (_isCurrent(scope, epoch)) {
      _publish(
        _snapshotFor(
          active: false,
          failures: failures,
          conflicts: conflicts,
          completed: true,
        ),
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
    List<SyncFailure>? failures,
    List<SyncConflict>? conflicts,
    bool completed = false,
  }) {
    return SyncSnapshot(
      active: active,
      queuedCount: _pending ? _jobs.length : 0,
      failures: failures ?? _snapshot.failures,
      conflicts: conflicts ?? _snapshot.conflicts,
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
