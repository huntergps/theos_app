import 'dart:async';

import '../contracts.dart';
import '../realtime/realtime_status.dart';

/// Cada cuánto se pide una sincronización de respaldo mientras el tiempo
/// real NO esté conectado. Constante única (14-sep-2026, hueco 2 de la
/// auditoría de tiempo real): antes de este archivo no había NINGÚN
/// `Timer.periodic` en Orbi — `SyncAutoResyncTrigger` sólo reacciona a
/// filos (red que vuelve, app que vuelve al frente), así que si el socket
/// de tiempo real se caía sin que ninguna de esas dos señales cambiara,
/// nada volvía a sincronizar solo. `theos_pos` ya sondea cada 5 minutos
/// (`theos_pos/lib/features/sync/connectivity_sync_orchestrator.dart:63,
/// 105-108`); este es el equivalente de Orbi.
const syncPeriodicBackupInterval = Duration(minutes: 5);

/// Respaldo periódico: pide una sincronización de catálogos por el MISMO
/// [SyncCoordinator] (nunca en paralelo) cada [interval], pero SÓLO mientras
/// se cumplen las tres condiciones a la vez:
///  - hay red (`online`);
///  - la app está en primer plano (`foreground`);
///  - el tiempo real NO está conectado (`realtimeStatus` distinto de
///    [RealtimeStatus.live]).
///
/// El temporizador se detiene en cuanto el tiempo real conecta (ya no hace
/// falta respaldo: los avisos `app_sync/changed` cubren los cambios) y
/// arranca una cuenta NUEVA de [interval] si vuelve a caerse — nunca retoma
/// una cuenta a medias, porque el tiempo que ya pasó conectado no cuenta
/// como progreso hacia el próximo respaldo.
///
/// Deliberadamente sin debounce ni coalescencia de filos como
/// `SyncAutoResyncTrigger`: aquí no hay filos que puedan llegar pegados, sólo
/// un temporizador que se arma o se desarma según el estado vigente de las
/// tres señales.
final class SyncPeriodicBackupTrigger {
  SyncPeriodicBackupTrigger({
    required this._coordinator,
    required Stream<bool> online,
    required Stream<bool> foreground,
    required Stream<RealtimeStatus> realtimeStatus,
    this.interval = syncPeriodicBackupInterval,
  }) {
    _subscriptions.add(
      online.listen((value) {
        _online = value;
        _reconcile();
      }),
    );
    _subscriptions.add(
      foreground.listen((value) {
        _foreground = value;
        _reconcile();
      }),
    );
    _subscriptions.add(
      realtimeStatus.listen((value) {
        _realtimeLive = value == RealtimeStatus.live;
        _reconcile();
      }),
    );
  }

  final SyncCoordinator _coordinator;
  final Duration interval;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _timer;

  /// Optimista hasta que la señal real diga lo contrario, igual que el resto
  /// del runtime (ver `RealtimeSyncCoordinator._online`): nunca arranca
  /// pesimista sin haber medido nada.
  bool _online = true;
  bool _foreground = true;

  /// El tiempo real nace `connecting`/`offline`, nunca `live` de entrada —
  /// arrancar en `false` (no conectado) es lo correcto: sin evidencia de
  /// conexión, el respaldo debe poder armarse.
  bool _realtimeLive = false;

  /// Arma o desarma el temporizador según el estado vigente. Nunca reinicia
  /// un temporizador que ya está corriendo con la cuenta correcta — sólo
  /// crea uno nuevo cuando hacía falta y no había, o cancela el que sobra.
  void _reconcile() {
    final shouldRun = _online && _foreground && !_realtimeLive;
    if (shouldRun) {
      _timer ??= Timer.periodic(interval, (_) {
        unawaited(_coordinator.requestSync(SyncReason('periodic_backup')));
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
