// El nombre público del parámetro (`persistThrottle`) documenta mejor la
// intención en el sitio de la llamada que el nombre privado del campo — mismo
// patrón que `ClientPolicySyncTrigger` (`orbi_runtime`).
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Como mucho cada cuánto se persiste la última interacción real — decisión
/// del dueño, 14-sep-2026: "como mucho cada 30 s". Escribir en cada toque o
/// tecla sería ruido en `SharedPreferences` sin ganar nada: el
/// [InactivityLockTrigger] sólo necesita conocer, con esta resolución,
/// cuándo fue la última vez que alguien tocó algo.
const kInactivityPersistThrottle = Duration(seconds: 30);

/// Dónde vive, por ámbito de usuario, la última interacción real —
/// UTC del equipo, ISO-8601. `scopeKey` sigue la misma idea que
/// `workspaceUnlockScopeKeyFor` (`features/auth/workspace_unlock_store.dart`):
/// servidor + base + login + userId, nunca compartida entre identidades en
/// el mismo aparato.
String inactivityLastInteractionKey(String scopeKey) =>
    'orbi/security/inactivity/last_interaction/$scopeKey';

/// Última cifra de `inactivity_lock_minutes` que trajo el servidor, cacheada
/// aparte en `SharedPreferences` — la única pieza de `ClientPolicySnapshot`
/// que hace falta poder leer de forma SÍNCRONA, antes de que la sesión de
/// runtime (Drift, `RuntimeMetadataStore`) esté lista para restaurar nada.
/// Ver el comentario de `WorkspaceLockNotifier.build()` en `router.dart`.
String inactivityLockMinutesKey(String scopeKey) =>
    'orbi/security/inactivity/lock_minutes/$scopeKey';

/// Escucha punteros y teclado a NIVEL GLOBAL (`GestureBinding`,
/// `HardwareKeyboard`) sin consumirlos — Orbi no es dueño de esos eventos,
/// sólo necesita enterarse de que alguien sigue ahí — y con eso alimenta un
/// [InactivityLockTrigger]. Ver la decisión del dueño, 14-sep-2026,
/// "Bloqueo automático por inactividad".
///
/// Quien compone esto (`router.dart`) decide cuándo construirlo y
/// destruirlo: sólo debe existir mientras haya sesión autenticada. En la
/// pantalla de acceso no debe existir instancia alguna, así que ahí no corre
/// ningún temporizador — punto 5 del diseño.
final class InactivityLockController {
  InactivityLockController({
    required this.scopeKey,
    required this.preferences,
    required Duration Function() lockAfter,
    required void Function() onLock,
    DateTime Function()? now,
    Duration persistThrottle = kInactivityPersistThrottle,
  }) : _now = now ?? DateTime.now,
       _persistThrottle = persistThrottle {
    _trigger = InactivityLockTrigger(
      lockAfter: lockAfter,
      now: _now,
      onLock: onLock,
      initialLastInteraction: _readPersistedLastInteraction(),
    );
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  final String scopeKey;
  final SharedPreferences preferences;
  final DateTime Function() _now;
  final Duration _persistThrottle;
  late final InactivityLockTrigger _trigger;
  DateTime? _lastPersistedAt;

  void _onPointerEvent(PointerEvent event) => _recordInteraction();

  // Nunca consume el evento: Orbi observa, no compite por el foco ni el
  // gesto con quien lo esté usando de verdad.
  bool _onKeyEvent(KeyEvent event) {
    _recordInteraction();
    return false;
  }

  void _recordInteraction() {
    final at = _now();
    _trigger.recordInteraction(at);
    if (_lastPersistedAt != null &&
        at.difference(_lastPersistedAt!) < _persistThrottle) {
      return;
    }
    _lastPersistedAt = at;
    unawaited(_persist(at));
  }

  Future<void> _persist(DateTime at) => preferences.setString(
    inactivityLastInteractionKey(scopeKey),
    at.toUtc().toIso8601String(),
  );

  DateTime? _readPersistedLastInteraction() {
    final raw = preferences.getString(inactivityLastInteractionKey(scopeKey));
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// Vuelve a comprobar el plazo ahora mismo, sin esperar al siguiente tic —
  /// para "al volver a primer plano" (punto 2 del diseño).
  void checkNow() => _trigger.checkNow();

  /// El desbloqueo (con clave o con PIN) no es, por sí mismo, la prueba de
  /// que alguien sigue trabajando — sólo evita que el disparador vuelva a
  /// llamar a `onLock` en el siguiente tic mientras la persona ya está
  /// mirando la pantalla recién desbloqueada y todavía no tocó nada.
  void markUnlocked() => _trigger.markUnlocked();

  /// Persiste ahora mismo, sin esperar el margen de 30 s — para cuando este
  /// controlador se va a destruir (cambio de usuario, cierre de sesión) y no
  /// conviene perder hasta 30 s de la última interacción real.
  Future<void> flush() => _persist(_trigger.lastInteraction);

  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _trigger.dispose();
  }
}
