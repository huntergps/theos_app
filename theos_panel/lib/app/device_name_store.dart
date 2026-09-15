// Nombre del equipo para el pie del armazón (`OperationalContext.deviceName`,
// `operational_shell.dart`) — señal nueva pedida por el dueño, 14-sep-2026:
// «sale del nombre del equipo en el sistema operativo y se puede modificar».
//
// Deliberadamente POR INSTALACIÓN, no por usuario: `orbi/device/name` es una
// sola clave de `SharedPreferences`, la misma para cualquiera que use este
// navegador o este escritorio — el mismo criterio que ya aplica
// `LastLocationStore` para separar estado de identidad de estado de sesión,
// pero al revés: aquí el estado es del APARATO, no de quién entró en él.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_name_factory.dart';
import 'preferences/app_preferences.dart' show sharedPreferencesProvider;

final class DeviceNameStore {
  DeviceNameStore(this.preferences);

  static const key = 'orbi/device/name';

  final SharedPreferences preferences;

  /// Nunca vacío: cae al nombre por omisión de la plataforma
  /// ([defaultDeviceName]) cuando no se guardó nada, o cuando lo guardado es
  /// sólo espacios.
  String read() {
    final raw = preferences.getString(key)?.trim();
    return (raw == null || raw.isEmpty) ? defaultDeviceName() : raw;
  }

  /// Vacío borra la preferencia — vuelve al valor por omisión, tal como pide
  /// el dueño («Vacío vuelve al valor por omisión»), en vez de guardar una
  /// cadena vacía que [read] tendría que seguir tratando como caso especial.
  Future<void> write(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await preferences.remove(key);
      return;
    }
    if (!await preferences.setString(key, trimmed)) {
      throw StateError('El nombre del equipo no se pudo guardar');
    }
  }
}

/// Mismo patrón que `AppPreferencesController` (`app_preferences.dart`): un
/// `ChangeNotifier` sostenido por un `Provider` simple, no reconstruido solo
/// por Riverpod — quien lo use lo escucha con `AnimatedBuilder`.
final class DeviceNameController extends ChangeNotifier {
  DeviceNameController(this.store) : _name = store.read();

  final DeviceNameStore store;
  String _name;

  String get name => _name;

  Future<void> setName(String value) async {
    await store.write(value);
    _name = store.read();
    notifyListeners();
  }
}

final deviceNameStoreProvider = Provider<DeviceNameStore>(
  (ref) => DeviceNameStore(ref.watch(sharedPreferencesProvider)),
);

final deviceNameControllerProvider = Provider<DeviceNameController>((ref) {
  final controller = DeviceNameController(ref.watch(deviceNameStoreProvider));
  ref.onDispose(controller.dispose);
  return controller;
});
