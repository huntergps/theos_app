// El nombre público del parámetro (`sync`) documenta mejor la intención en
// el sitio de la llamada que el nombre privado del campo (`_sync`).
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

/// Cada cuánto se sincroniza sola la hora del servidor
/// (`ClientPolicyService.sync`) mientras la sesión está en línea y la app en
/// primer plano — orden del dueño, 14-sep-2026: "sin consultar a Odoo a cada
/// rato", cada 15 minutos.
const clientPolicySyncInterval = Duration(minutes: 15);

/// Arma o desarma un `Timer.periodic` de [interval] según dos señales — igual
/// que `SyncPeriodicBackupTrigger` (`sync/sync_periodic_backup_trigger.dart`),
/// pero sin la tercera condición de tiempo real: aquí sólo importan red y
/// primer plano.
///
/// Además de la cuenta periódica, un filo de falso a verdadero en
/// cualquiera de las dos señales dispara una sincronización inmediata — eso
/// cubre "volver a primer plano" y "recuperar la red" sin esperar a que se
/// cumpla el intervalo completo. Un filo inicial (la señal ya nace en
/// verdadero, el valor por omisión de ambas) nunca cuenta como filo: quien
/// compone este disparador es responsable de sincronizar una vez a mano
/// justo al entrar o restaurar sesión en línea (ver `router.dart`), que es
/// un caso distinto de "recuperar" algo que ya estaba activo.
final class ClientPolicySyncTrigger {
  ClientPolicySyncTrigger({
    required Future<void> Function() sync,
    required Stream<bool> online,
    required Stream<bool> foreground,
    this.interval = clientPolicySyncInterval,
  }) : _sync = sync {
    _subscriptions.add(
      online.listen((value) {
        final rising = _online == false && value == true;
        _online = value;
        _reconcile();
        if (rising) _runNow();
      }),
    );
    _subscriptions.add(
      foreground.listen((value) {
        final rising = _foreground == false && value == true;
        _foreground = value;
        _reconcile();
        if (rising) _runNow();
      }),
    );
  }

  final Future<void> Function() _sync;
  final Duration interval;
  final List<StreamSubscription<bool>> _subscriptions = [];
  Timer? _timer;

  /// Optimista hasta que la señal real diga lo contrario, igual que el
  /// resto del runtime (`SyncPeriodicBackupTrigger._online`/`_foreground`).
  bool _online = true;
  bool _foreground = true;

  void _reconcile() {
    final shouldRun = _online && _foreground;
    if (shouldRun) {
      _timer ??= Timer.periodic(interval, (_) => _runNow());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _runNow() {
    unawaited(_sync());
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
