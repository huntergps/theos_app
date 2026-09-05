/// Route Mode Provider
///
/// "Modo Ruta" es un modo especial para vendedores rurales que trabajan
/// sin conexion por horas. Cuando está activo:
///
/// - La OfflineQueue NO intenta enviar operaciones al servidor
/// - Se muestra un banner azul "Modo Ruta" en la barra superior
///
/// Al desactivar Modo Ruta:
/// - Se dispara sync incremental de catalogos (productos, precios, clientes)
/// - La OfflineQueue empieza a procesar pendientes
///
/// El modo persiste entre reinicios via SharedPreferences.
/// Si hay internet disponible pero el modo esta activo, NO reconecta
/// automaticamente — respeta la decision del usuario.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show logger;

// ============================================================================
// ESTADO
// ============================================================================

/// Estado del Modo Ruta
class RouteModeState {
  /// Si el modo ruta esta activo
  final bool isActive;

  /// Cuando se activo (null si no esta activo)
  final DateTime? activatedAt;

  const RouteModeState({this.isActive = false, this.activatedAt});

  RouteModeState copyWith({bool? isActive, DateTime? activatedAt}) {
    return RouteModeState(
      isActive: isActive ?? this.isActive,
      activatedAt: activatedAt ?? this.activatedAt,
    );
  }

  /// Duracion activa desde que se activo el modo ruta
  Duration? get activeDuration {
    if (!isActive || activatedAt == null) return null;
    return DateTime.now().difference(activatedAt!);
  }

  /// Texto de duracion legible (ej: "3h 45m")
  String? get activeDurationText {
    final d = activeDuration;
    if (d == null) return null;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }

  static const initial = RouteModeState();
}

// ============================================================================
// NOTIFIER
// ============================================================================

class RouteModeNotifier extends AsyncNotifier<RouteModeState> {
  static const String _keyActive = 'route_mode_active';
  static const String _keyActivatedAt = 'route_mode_activated_at';

  @override
  Future<RouteModeState> build() async {
    return await _loadFromPrefs();
  }

  /// Activar Modo Ruta
  ///
  /// Suspende la reconciliacion remota y los reintentos de OfflineQueue.
  Future<void> activate() async {
    logger.i('[RouteModeProvider] Activando Modo Ruta');
    final newState = RouteModeState(
      isActive: true,
      activatedAt: DateTime.now(),
    );
    state = AsyncData(newState);
    await _saveToPrefs(newState);
  }

  /// Desactivar Modo Ruta
  ///
  /// El llamador es responsable de disparar el sync incremental.
  Future<void> deactivate() async {
    logger.i('[RouteModeProvider] Desactivando Modo Ruta');
    const newState = RouteModeState(isActive: false);
    state = AsyncData(newState);
    await _saveToPrefs(newState);
  }

  /// Toggle: activa si esta inactivo, desactiva si esta activo.
  /// Devuelve true si quedo activo, false si quedo inactivo.
  Future<bool> toggle() async {
    final current = state.value ?? RouteModeState.initial;
    if (current.isActive) {
      await deactivate();
      return false;
    } else {
      await activate();
      return true;
    }
  }

  // ============ Persistencia ============

  Future<RouteModeState> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(_keyActive) ?? false;
      final activatedAtStr = prefs.getString(_keyActivatedAt);
      final activatedAt = activatedAtStr != null
          ? DateTime.tryParse(activatedAtStr)
          : null;

      return RouteModeState(isActive: isActive, activatedAt: activatedAt);
    } catch (e) {
      logger.e('[RouteModeProvider] Error cargando config: $e');
      return RouteModeState.initial;
    }
  }

  Future<void> _saveToPrefs(RouteModeState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyActive, state.isActive);
      if (state.activatedAt != null) {
        await prefs.setString(
          _keyActivatedAt,
          state.activatedAt!.toIso8601String(),
        );
      } else {
        await prefs.remove(_keyActivatedAt);
      }
    } catch (e) {
      logger.e('[RouteModeProvider] Error guardando config: $e');
    }
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider principal del Modo Ruta.
///
/// Persiste en SharedPreferences entre reinicios de la app.
/// Estado inicial cargado desde disco — usa AsyncValue.
final routeModeProvider =
    AsyncNotifierProvider<RouteModeNotifier, RouteModeState>(
      RouteModeNotifier.new,
    );

/// Provider booleano derivado — true si el modo ruta esta activo.
///
/// Nunca bloquea: devuelve false mientras carga.
final isRouteModeActiveProvider = Provider<bool>((ref) {
  final state = ref.watch(routeModeProvider);
  return state.maybeWhen(data: (s) => s.isActive, orElse: () => false);
});

/// Estado completo del modo ruta (para mostrar duracion, etc.)
final routeModeStateProvider = Provider<RouteModeState>((ref) {
  final state = ref.watch(routeModeProvider);
  return state.maybeWhen(data: (s) => s, orElse: () => RouteModeState.initial);
});
