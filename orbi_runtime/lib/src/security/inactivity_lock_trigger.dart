// El nombre público de los parámetros (`lockAfter`, `now`, `onLock`)
// documenta mejor la intención en el sitio de la llamada que el nombre
// privado del campo — mismo patrón que `ClientPolicySyncTrigger`.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

/// Cada cuánto se revisa si ya pasó el plazo de inactividad — decisión del
/// dueño, 14-sep-2026 ("Bloqueo automático por inactividad: tras N minutos
/// sin uso, Orbi se bloquea"). Deliberadamente mucho más corto que el propio
/// plazo (15 minutos por omisión): el reloj de pared no debe notar más que
/// este margen entre que se cumple el plazo y que la pantalla se bloquea.
const inactivityCheckInterval = Duration(seconds: 15);

/// Tolerancia que usa [shouldStartLocked] para sospechar que el reloj del
/// equipo retrocedió: la última interacción persistida no puede quedar por
/// delante de "ahora" más que esto sin ser sospechosa.
const inactivityClockRollbackTolerance = Duration(minutes: 5);

/// Arma un `Timer.periodic` de [checkInterval] que, mientras haya sesión y
/// no esté ya bloqueado, compara la hora actual contra la última
/// interacción real conocida ([recordInteraction]) y llama a [onLock] en
/// cuanto pasan [lockAfter] minutos sin ninguna.
///
/// Deliberadamente no sabe nada de punteros, teclado ni Riverpod: quien lo
/// compone (`InactivityLockController`, en `theos_panel`) es quien engancha
/// la interacción real de la plataforma y decide cuándo construir o
/// destruir esto según haya sesión autenticada. Esta clase sólo hace la
/// cuenta — el mismo reparto de responsabilidades que ya separa
/// `ClientPolicySyncTrigger` (sólo la cuenta de la sincronización periódica)
/// de quien lo dispara.
///
/// [lockAfter] es una función, no una `Duration` fija, porque N viene del
/// servidor (`ClientPolicyService.snapshot.inactivityLockMinutes`) y puede
/// cambiar durante la sesión sin que haga falta reconstruir este disparador.
final class InactivityLockTrigger {
  InactivityLockTrigger({
    required Duration Function() lockAfter,
    required DateTime Function() now,
    required void Function() onLock,
    this.checkInterval = inactivityCheckInterval,
    DateTime? initialLastInteraction,
  }) : _lockAfter = lockAfter,
       _now = now,
       _onLock = onLock,
       _lastInteraction = initialLastInteraction ?? now() {
    _timer = Timer.periodic(checkInterval, (_) => checkNow());
  }

  final Duration Function() _lockAfter;
  final DateTime Function() _now;
  final void Function() _onLock;
  final Duration checkInterval;

  DateTime _lastInteraction;
  bool _alreadyLocked = false;
  Timer? _timer;

  /// Última interacción que este disparador conoce — sólo para pruebas e
  /// inspección; quien compone esto es dueño de persistirla si hace falta.
  DateTime get lastInteraction => _lastInteraction;

  /// Registra actividad real (puntero o teclado) y reinicia la cuenta.
  void recordInteraction([DateTime? at]) {
    _lastInteraction = at ?? _now();
    _alreadyLocked = false;
  }

  /// Deja de considerar que ya se bloqueó, SIN tocar la última interacción —
  /// para cuando quien compone esto ya sabe que la pantalla se desbloqueó
  /// (por ejemplo, con el PIN del vendedor) pero eso todavía no cuenta como
  /// una interacción real de vuelta a cero.
  void markUnlocked() => _alreadyLocked = false;

  /// Fuerza la comprobación ahora mismo, sin esperar al siguiente tic de
  /// [checkInterval] — usado al volver a primer plano.
  void checkNow() {
    if (_alreadyLocked) return;
    final elapsed = _now().difference(_lastInteraction);
    if (elapsed >= _lockAfter()) {
      _alreadyLocked = true;
      _onLock();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Si, al arrancar o restaurar sesión, ya se debería mostrar bloqueado ANTES
/// de pintar nada — decisión del dueño, 14-sep-2026: "la sesión web
/// sobrevive a cerrar la pestaña hasta que salta el bloqueo por
/// inactividad. Así que si reabres pasado el plazo, debe aparecer
/// bloqueado."
///
/// `persistedLastInteraction == null` (nunca se registró nada para este
/// scope — el primer login en este dispositivo) nunca bloquea: no hay nada
/// sospechoso que comparar todavía, y bloquear ahí inventaría un candado el
/// primer día.
bool shouldStartLocked({
  required DateTime? persistedLastInteraction,
  required DateTime deviceNow,
  required Duration lockAfter,
  Duration clockRollbackTolerance = inactivityClockRollbackTolerance,
}) {
  if (persistedLastInteraction == null) return false;
  final elapsed = deviceNow.difference(persistedLastInteraction);
  if (elapsed >= lockAfter) return true;
  // Reloj del equipo atrasado respecto a la última interacción conocida: la
  // propia interacción persistida queda "en el futuro" de `deviceNow` más
  // allá de la tolerancia.
  return persistedLastInteraction.difference(deviceNow) >
      clockRollbackTolerance;
}
