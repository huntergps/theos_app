import 'dart:async';

import '../contracts.dart';

/// Retoma la sincronización sola cuando volver a intentarlo tiene sentido,
/// sin que la persona tenga que abrir «Sincronización» y pulsar
/// «Reintentar» a mano (prioridad del dueño, 13-sep-2026: shell, sync y
/// offline-first primero). Medido en la auditoría del 13-sep-2026: antes de
/// esto, `requestSync` sólo corría una vez al abrir el scope y bajo ese
/// botón manual — recuperar la red o volver a la app no revivía nada.
///
/// Reacciona a filos de falso a verdadero de las señales que le pasen. Esta
/// clase en sí NUNCA sondea por su cuenta: sin `Timer.periodic` propio —el
/// único `Timer` que usa es el `debounce` para fundir filos pegados, y se
/// cancela sin disparar nada si no vuelve a hacer falta.
///
/// 🔴 Actualizado 14-sep-2026: "sin sondeo de servidor periódico" ya NO es
/// cierto para Orbi en conjunto — `SyncPeriodicBackupTrigger`
/// (`sync_periodic_backup_trigger.dart`) sí sondea cada 5 minutos, pero
/// SÓLO mientras el tiempo real no esté conectado, y es una clase aparte con
/// su propio temporizador: esta clase sigue sin tener ninguno.
///
/// Un filo inicial (la señal ya nace en verdadero) nunca cuenta — describe
/// el estado de arranque, no una recuperación.
///
/// Tres señales, sólo `online` obligatoria:
///  - `online`: el aparato pasó de sin red a con red
///    (`networkSignalProvider`, mapeado a `NetworkSignal.hasNetwork`).
///  - `foreground`: la app volvió a primer plano (en la web, a la pestaña
///    visible).
///  - `backendReachable`: el último sondeo del servidor pasó de
///    caído/401 a disponible por una vía distinta de las dos anteriores.
///    Hoy sólo se puede alimentar de lo que ya haya corrido un `drain` del
///    coordinador (un reintento manual, por ejemplo): no hay sondeo propio
///    aquí tampoco.
///
/// Los filos que llegan pegados se funden en un solo ciclo: cada uno
/// reprograma el mismo temporizador de espera, así que un parpadeo de red
/// dispara como mucho una sincronización adicional, nunca una por filo.
final class SyncAutoResyncTrigger {
  SyncAutoResyncTrigger({
    required this._coordinator,
    required Stream<bool> online,
    Stream<bool>? foreground,
    Stream<bool>? backendReachable,
    this.debounce = const Duration(milliseconds: 250),
  }) {
    _subscriptions.add(online.listen((value) => _onSignal('online', value)));
    final fg = foreground;
    if (fg != null) {
      _subscriptions.add(fg.listen((value) => _onSignal('foreground', value)));
    }
    final backend = backendReachable;
    if (backend != null) {
      _subscriptions.add(
        backend.listen((value) => _onSignal('backend', value)),
      );
    }
  }

  final SyncCoordinator _coordinator;
  final Duration debounce;
  final List<StreamSubscription<bool>> _subscriptions = [];
  final Map<String, bool> _lastValue = {};
  Timer? _pendingTimer;

  void _onSignal(String source, bool value) {
    final previous = _lastValue[source];
    _lastValue[source] = value;
    if (previous != false || value != true) return;
    _pendingTimer?.cancel();
    _pendingTimer = Timer(debounce, () {
      unawaited(_coordinator.requestSync(SyncReason('auto_resync:$source')));
    });
  }

  Future<void> dispose() async {
    _pendingTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
