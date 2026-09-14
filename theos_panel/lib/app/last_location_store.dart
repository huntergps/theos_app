// Recuerda la última pantalla de cada identidad para que reabrir Orbi
// (pestaña cerrada, acceso directo, pestaña anclada) no caiga siempre en
// Inicio (auditoría de "se pierde todo lo que estaba haciendo", 14-sep-2026,
// bloque A).
//
// Deliberadamente en `theos_panel`, no en `orbi_runtime`: esto es estado de
// NAVEGACIÓN, y `orbi_runtime` no importa rutas (ADR-01,
// docs/orbi_panel/ARCHITECTURE.md).
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile;
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda y lee la última ubicación (path + query) por identidad autenticada.
///
/// La clave nunca lleva el servidor, la base o el usuario en claro: un hash
/// corto de sha256 sobre esos tres — la misma receta que
/// `RuntimeDatabaseOwner.databaseNameFor` usa para nombrar la base local de
/// cada ámbito. Así dos identidades jamás comparten fila, sin importar qué
/// caracteres traiga la URL del servidor.
final class LastLocationStore {
  const LastLocationStore(this._prefs);

  final SharedPreferences _prefs;

  static String _scopeHash(AuthProfile profile) {
    final raw = '${profile.serverUrl}|${profile.database}|${profile.userId}';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 32);
  }

  static String _keyFor(AuthProfile profile) =>
      'orbi/last_location/${_scopeHash(profile)}';

  /// `null` si nunca se guardó nada para esta identidad.
  String? read(AuthProfile profile) => _prefs.getString(_keyFor(profile));

  /// Sin esperar la escritura: quien navega nunca debe quedar bloqueado por
  /// esto.
  void save(AuthProfile profile, String location) {
    unawaited(_prefs.setString(_keyFor(profile), location));
  }
}
