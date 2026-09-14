import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Límite de sesión sin conexión (decisión del dueño, 14-sep-2026): máximo
/// 3 días sin hablar con Odoo, parametrizable por servidor
/// (`offline_max_days`, el mismo campo que ya trae `client_policy()` —
/// `orbi_runtime/lib/src/clock/client_policy_service.dart`). Pasado el
/// plazo, `NativeAuthService.restore(offline: true)` deja de activar la
/// sesión sola hasta que el operador entre en línea una vez — nunca se
/// borran datos locales ni la cola offline, ver esa clase.
const kDefaultOfflineAllowanceDays = 3;

/// Qué dijo la última evaluación de [OfflineAllowanceStore.evaluate].
enum OfflineAllowanceStatus {
  /// La sesión sin conexión sigue dentro del plazo.
  allowed,

  /// Pasó `offlineMaxDays` desde la última conexión buena.
  expired,

  /// El reloj del equipo quedó más de 5 minutos POR DETRÁS de la última
  /// lectura vista — un reloj atrasado no puede servir para estirar el
  /// plazo, así que esto se rechaza con un mensaje propio, distinto de
  /// [expired].
  clockRollback,
}

/// Resultado inmutable de [OfflineAllowanceStore.evaluate].
final class OfflineAllowance {
  const OfflineAllowance({
    required this.status,
    this.daysOffline,
    this.maxDays,
  });

  final OfflineAllowanceStatus status;

  /// Días completos transcurridos desde la última conexión buena — sólo
  /// tiene un valor cuando [status] es [OfflineAllowanceStatus.expired].
  final int? daysOffline;

  /// El límite vigente para esta credencial en el momento de evaluar. `null`
  /// sólo en el caso migración (nunca hubo registro previo) antes de que se
  /// conozca ninguno.
  final int? maxDays;

  bool get isAllowed => status == OfflineAllowanceStatus.allowed;
}

/// Guarda, por credencial (servidor + base + usuario), cuándo fue la última
/// conexión buena con Odoo — para que `NativeAuthService.restore(offline:
/// true)` pueda decidir, ANTES de abrir la base del scope, si la sesión sin
/// conexión sigue dentro del plazo.
///
/// Sobre `SharedPreferences` a propósito, no `RuntimeMetadataStore`: esa
/// clase vive DENTRO de la base del scope
/// (`orbi_runtime/lib/src/read/runtime_metadata_store.dart`), y
/// `restore(offline: true)` tiene que decidir si activa la sesión ANTES de
/// que esa base se abra — decidirlo primero es justo lo que evita abrir una
/// base cuyo acceso ya no debería concederse.
final class OfflineAllowanceStore {
  OfflineAllowanceStore(this._preferences);

  final SharedPreferences _preferences;

  String _keyFor(String serverUrl, String database, int userId) {
    final normalized = serverUrl.trim().toLowerCase();
    final encoded = base64Url
        .encode(utf8.encode('$normalized|$database|$userId'))
        .replaceAll('=', '');
    return 'orbi/auth/offline_allowance/$encoded';
  }

  Map<String, dynamic>? _read(String key) {
    final raw = _preferences.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, Map<String, dynamic> data) =>
      _preferences.setString(key, jsonEncode(data));

  /// Se llama al completar con éxito `login`, `loginWithApiKey` o `restore`
  /// EN LÍNEA (ver `NativeAuthService`). Marca "hoy hablé con Odoo de
  /// verdad" — el punto de partida del plazo sin conexión.
  Future<void> recordOnline({
    required String serverUrl,
    required String database,
    required int userId,
    required DateTime nowUtc,
  }) async {
    final key = _keyFor(serverUrl, database, userId);
    final data = _read(key) ?? <String, dynamic>{};
    data['lastOnlineAtUtc'] = nowUtc.toIso8601String();
    data['lastSeenDeviceUtc'] = nowUtc.toIso8601String();
    await _write(key, data);
  }

  /// Se llama cada vez que `ClientPolicyService.sync()` sincroniza con
  /// éxito — trae el límite real que configuró el servidor
  /// (`offline_max_days`, `app.sync.client.policy.client_policy()`) y, de
  /// paso, confirma otra conexión buena.
  Future<void> recordServerSync({
    required String serverUrl,
    required String database,
    required int userId,
    required int offlineMaxDays,
    required DateTime nowUtc,
  }) async {
    final key = _keyFor(serverUrl, database, userId);
    final data = _read(key) ?? <String, dynamic>{};
    data['lastOnlineAtUtc'] = nowUtc.toIso8601String();
    data['lastSeenDeviceUtc'] = nowUtc.toIso8601String();
    data['offlineMaxDays'] = offlineMaxDays;
    await _write(key, data);
  }

  /// Decide si una sesión sin conexión para esta credencial sigue dentro
  /// del plazo. Nunca lanza — un fallo de lectura/escritura de
  /// `SharedPreferences` se trata como si nunca hubiera habido registro
  /// (ver más abajo), nunca como un vencimiento.
  ///
  /// * Sin ningún registro previo para esta credencial (instalación vieja,
  ///   de antes de que existiera este mecanismo): `allowed`, y se registra
  ///   `lastOnlineAtUtc = deviceNowUtc` como punto de partida — es la
  ///   migración, nunca un vencimiento retroactivo por algo que esta
  ///   instalación no tenía forma de saber.
  /// * [OfflineAllowanceStatus.clockRollback] cuando [deviceNowUtc] queda
  ///   más de 5 minutos POR DETRÁS de la última vez que se vio el reloj del
  ///   equipo.
  /// * [OfflineAllowanceStatus.expired] cuando ya pasó `offlineMaxDays`
  ///   desde `lastOnlineAtUtc`.
  /// * [OfflineAllowanceStatus.allowed] en cualquier otro caso — y de paso
  ///   adelanta `lastSeenDeviceUtc` al máximo visto, para que un retroceso
  ///   futuro se note incluso entre dos evaluaciones seguidas "allowed".
  Future<OfflineAllowance> evaluate({
    required String serverUrl,
    required String database,
    required int userId,
    required DateTime deviceNowUtc,
  }) async {
    final key = _keyFor(serverUrl, database, userId);
    Map<String, dynamic>? data;
    try {
      data = _read(key);
    } catch (_) {
      data = null;
    }
    final lastOnline = data == null ? null : _parseUtc(data['lastOnlineAtUtc']);
    if (data == null || lastOnline == null) {
      try {
        await recordOnline(
          serverUrl: serverUrl,
          database: database,
          userId: userId,
          nowUtc: deviceNowUtc,
        );
      } catch (_) {
        // Best effort: si no se pudo guardar el punto de partida, la
        // próxima evaluación simplemente lo vuelve a intentar — nunca debe
        // impedir que esta primera pase como `allowed`.
      }
      return const OfflineAllowance(status: OfflineAllowanceStatus.allowed);
    }
    final maxDays =
        (data['offlineMaxDays'] as num?)?.toInt() ??
        kDefaultOfflineAllowanceDays;
    final lastSeenDevice = _parseUtc(data['lastSeenDeviceUtc']);
    if (lastSeenDevice != null &&
        deviceNowUtc.isBefore(
          lastSeenDevice.subtract(const Duration(minutes: 5)),
        )) {
      return OfflineAllowance(
        status: OfflineAllowanceStatus.clockRollback,
        maxDays: maxDays,
      );
    }
    final elapsed = deviceNowUtc.difference(lastOnline);
    if (elapsed > Duration(days: maxDays)) {
      return OfflineAllowance(
        status: OfflineAllowanceStatus.expired,
        daysOffline: elapsed.inDays,
        maxDays: maxDays,
      );
    }
    final newestSeen =
        lastSeenDevice == null || deviceNowUtc.isAfter(lastSeenDevice)
        ? deviceNowUtc
        : lastSeenDevice;
    try {
      data['lastSeenDeviceUtc'] = newestSeen.toIso8601String();
      await _write(key, data);
    } catch (_) {
      // No perder la sesión sin conexión sólo porque no se pudo persistir
      // este avance del reloj visto — la próxima evaluación lo reintenta.
    }
    return OfflineAllowance(status: OfflineAllowanceStatus.allowed, maxDays: maxDays);
  }
}

DateTime? _parseUtc(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}
