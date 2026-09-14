// El nombre público del parámetro (`readState`, `writeState`) documenta
// mejor la intención en el sitio de la llamada que el nombre privado del
// campo (`_readState`, `_writeState`) — mismo patrón que `SessionRuntime`.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';

import 'package:odoo_sdk/odoo_sdk.dart';

import '../session/session_runtime.dart';

/// Modelo y método de `l10n_ec_app_sync` 19.1.5 que Orbi lee para saber la
/// hora del servidor y los dos límites de sesión offline —
/// `app.sync.client.policy.client_policy()`
/// (`dev_odoo20_app_sync_policy/addons/l10n_ec_app_sync/models/app_sync_client_policy.py`).
/// Todavía NO está desplegado en ningún servidor (14-sep-2026): mientras no
/// exista, cualquier Odoo responde con "el modelo ... no existe" y este
/// servicio cae a la hora del equipo — ver [ClientPolicyService.sync].
const clientPolicyModel = 'app.sync.client.policy';
const clientPolicyMethod = 'client_policy';

/// Valores de respaldo cuando el servidor todavía no tiene el modelo, o
/// nunca se pudo sincronizar — los mismos por omisión que trae el propio
/// método Python (`DEFAULT_OFFLINE_MAX_DAYS`, `DEFAULT_INACTIVITY_LOCK_MINUTES`).
const kDefaultOfflineMaxDays = 3;
const kDefaultInactivityLockMinutes = 15;

/// Etiqueta de log compartida por todos los avisos de este archivo.
const _logTag = '[ClientPolicyService]';

/// De dónde sale el desfase que usa [ClientPolicyService.nowServer].
enum ClientPolicyTimeSource {
  /// El desfase viene de una respuesta real de `client_policy()`.
  server,

  /// El servidor no tiene el modelo todavía, o nunca hubo una sincronización
  /// que confirmara lo contrario: el reloj del equipo manda, sin desfase.
  device,
}

/// Snapshot inmutable de lo último que sabe el servicio — lo que pinta el
/// armazón (`ServerClockStatus`, `theos_panel/lib/ui/layouts/operational_shell.dart`).
final class ClientPolicySnapshot {
  const ClientPolicySnapshot({
    required this.offset,
    required this.source,
    required this.offlineMaxDays,
    required this.inactivityLockMinutes,
    required this.isEstimated,
    this.rtt,
    this.lastSyncAt,
    this.lastOnlineAt,
    this.clockRollbackSuspected = false,
    this.userTzOffset,
  });

  /// `serverUtc - deviceUtc`, para sumarlo a la hora del equipo y estimar la
  /// del servidor. `Duration.zero` mientras no haya ninguna medida real.
  final Duration offset;
  final ClientPolicyTimeSource source;

  /// Ida y vuelta de la última sincronización real. `null` cuando nunca
  /// hubo una.
  final Duration? rtt;

  /// UTC. Momento del último `sync()` que llegó a una conclusión (real o
  /// "el modelo no existe") — no se actualiza en un error de red o de
  /// autenticación, porque esos no son una conclusión, son un reintento
  /// pendiente.
  final DateTime? lastSyncAt;

  /// UTC. Último momento en que `source` fue [ClientPolicyTimeSource.server]
  /// de verdad — `null` si esta instalación nunca lo logró.
  final DateTime? lastOnlineAt;

  final int offlineMaxDays;
  final int inactivityLockMinutes;

  /// Sin conexión, o sin haber sincronizado todavía en ESTA sesión — un
  /// desfase persistido de una sesión anterior sigue siendo una ESTIMACIÓN
  /// mientras no se confirme de nuevo.
  final bool isEstimated;

  final bool clockRollbackSuspected;

  /// `user_tz_offset_minutes` de la última respuesta real del servidor —
  /// el desfase de la zona horaria DEL USUARIO respecto a UTC, en el
  /// instante de `server_time_utc` (con signo: -300 en Guayaquil). `null`
  /// cuando el servidor nunca lo trajo (módulo viejo sin este campo, o
  /// "el modelo no existe"): en ese caso quien pinte la hora debe usar la
  /// zona del EQUIPO, nunca inventar un desfase.
  final Duration? userTzOffset;
}

/// Ya invoca `client_policy()` sobre el cliente activo y decodifica la
/// respuesta — lo único que varía entre producción (`fromSession`) y las
/// pruebas (una función de mentira). `null` significa "sin cliente": la
/// sesión está sin conexión, y [ClientPolicyService.sync] no debe llamar a
/// nada.
typedef ClientPolicyRpc = Future<Map<String, dynamic>> Function();

/// Hora del servidor y política de sesión offline, sincronizadas sin pedirle
/// nada al servidor más de lo necesario.
///
/// Disparadores (orden del dueño, 14-sep-2026): al entrar o restaurar sesión
/// en línea, al volver a primer plano y cada 15 minutos — todos afuera de
/// esta clase, en `ClientPolicySyncTrigger` y en quien componga la sesión
/// (`theos_panel/lib/app/router.dart`). Esta clase sólo sabe sincronizar UNA
/// vez quien se lo pida, y leer localmente lo último que sincronizó.
///
/// 🔴 `sync()` NUNCA lanza — ni por el RPC (ver el `catch` de abajo) ni por
/// la propia persistencia (`restore()`/`_persist()` capturan lo suyo y lo
/// dejan en el registro con `logger.w`). Revisión del dueño, 14-sep-2026:
/// un `metadata.read`/`write` puede lanzar `StateError` si la sesión ya
/// cerró (lease vencido) mientras un `sync()` seguía en vuelo, y eso NO
/// debe tumbar el `unawaited(service.sync())` de quien lo dispara.
final class ClientPolicyService {
  ClientPolicyService({
    required ClientPolicyRpc? Function() rpc,
    required Future<String?> Function() readState,
    required Future<void> Function(String json) writeState,
    DateTime Function()? deviceNow,
    Duration Function()? monotonicElapsed,
    this.onServerSynced,
  }) : _rpcOf = rpc,
       _readState = readState,
       _writeState = writeState,
       _deviceNow = deviceNow ?? DateTime.now,
       _monotonicElapsed = monotonicElapsed ?? _defaultMonotonicElapsed;

  /// Construye el servicio contra una sesión real: `sessions.active?.client`
  /// decide si hay con qué sincronizar, y el estado pequeño se guarda en la
  /// base del propio scope (`RuntimeMetadataStore`) — el mismo lugar que ya
  /// usa el resto del runtime para datos así de chicos por scope (ver
  /// `read/runtime_metadata_store.dart`).
  factory ClientPolicyService.fromSession({
    required SessionRuntime sessions,
    required Future<String?> Function() readState,
    required Future<void> Function(String json) writeState,
    DateTime Function()? deviceNow,
    Duration Function()? monotonicElapsed,
    void Function(ClientPolicySnapshot snapshot)? onServerSynced,
  }) => ClientPolicyService(
    rpc: () {
      final client = sessions.active?.client;
      if (client == null) return null;
      return () async {
        final result = await client.call(
          model: clientPolicyModel,
          method: clientPolicyMethod,
          kwargs: const {},
        );
        if (result is! Map) {
          throw const FormatException('Invalid client_policy response');
        }
        return Map<String, dynamic>.from(result);
      };
    },
    readState: readState,
    writeState: writeState,
    deviceNow: deviceNow,
    monotonicElapsed: monotonicElapsed,
    onServerSynced: onServerSynced,
  );

  final ClientPolicyRpc? Function() _rpcOf;
  final Future<String?> Function() _readState;
  final Future<void> Function(String) _writeState;
  final DateTime Function() _deviceNow;
  final Duration Function() _monotonicElapsed;

  /// Límite de sesión sin conexión (14-sep-2026): se llama tras cada
  /// sincronización real con el servidor (nunca en la rama "el modelo no
  /// existe" ni en un fallo), con el snapshot recién actualizado — quien
  /// compone la sesión (`router.dart`) lo cablea a
  /// `OfflineAllowanceStore.recordServerSync` para que el plazo sin conexión
  /// use el `offline_max_days` real del servidor en vez del valor por
  /// omisión. `null` no hace nada — nunca obligatorio.
  final void Function(ClientPolicySnapshot snapshot)? onServerSynced;

  Duration _offset = Duration.zero;
  ClientPolicyTimeSource _source = ClientPolicyTimeSource.device;
  Duration? _rtt;
  DateTime? _lastSyncAt;
  DateTime? _lastOnlineAt;
  int _offlineMaxDays = kDefaultOfflineMaxDays;
  int _inactivityLockMinutes = kDefaultInactivityLockMinutes;
  Duration? _userTzOffset;

  bool _restored = false;

  /// Memoria de "este servidor no tiene el modelo" — SÓLO por sesión (vive
  /// en memoria, nunca se persiste): un servidor puede ganar el módulo entre
  /// una sesión y la siguiente, y esta app no tiene forma de enterarse si
  /// nunca vuelve a preguntar.
  bool _modelKnownMissingThisSession = false;

  /// Si YA hubo una sincronización real con el servidor en esta sesión —
  /// distinto de [_lastOnlineAt], que sobrevive entre sesiones: esto decide
  /// [isEstimated] incluso cuando el desfase restaurado dice `source: server`
  /// de una sesión anterior.
  bool _syncedServerThisSession = false;

  /// Última hora del equipo vista, EN MEMORIA — se actualiza en cada
  /// [nowServer]/`sync()` y decide [_clockRollbackSuspected] dentro de la
  /// misma sesión.
  DateTime? _lastSeenDeviceUtc;
  bool _clockRollbackSuspected = false;

  /// Última vez que [_lastSeenDeviceUtc] se escribió a disco — para no
  /// perseguir el reloj en cada tic de [nowServer]: sólo se repite la
  /// escritura si pasó al menos un minuto desde la anterior. `sync()`
  /// siempre persiste (es un evento raro: login, primer plano, 15 min), así
  /// que esta marca también se actualiza ahí.
  DateTime? _lastPersistedDeviceClockAt;

  /// Carga lo último persistido, sin llamar al RPC. Idempotente — una
  /// segunda llamada no vuelve a leer. `sync()` ya la invoca por su cuenta,
  /// así que sólo hace falta llamarla a mano cuando se necesita leer
  /// [nowServer] SIN sincronizar (la estimación sin conexión).
  ///
  /// Nunca lanza: un `readState` que falle (por ejemplo, la sesión ya cerró
  /// y el lease del scope ya no es válido) se registra con `logger.w` y se
  /// trata como "nada que restaurar".
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    String? raw;
    try {
      raw = await _readState();
    } catch (error) {
      logger.w(_logTag, 'No se pudo leer el estado guardado: $error');
      return;
    }
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      final offsetMs = map['offset_ms'];
      if (offsetMs is int) _offset = Duration(milliseconds: offsetMs);
      final rttMs = map['rtt_ms'];
      _rtt = rttMs is int ? Duration(milliseconds: rttMs) : null;
      _source = map['source'] == 'server'
          ? ClientPolicyTimeSource.server
          : ClientPolicyTimeSource.device;
      _lastSyncAt = _parseIsoUtc(map['last_sync_at']);
      _lastOnlineAt = _parseIsoUtc(map['last_online_at']);
      _lastSeenDeviceUtc = _parseIsoUtc(map['last_seen_device_utc']);
      _lastPersistedDeviceClockAt = _lastSeenDeviceUtc;
      final tzOffsetMinutes = map['user_tz_offset_minutes'];
      _userTzOffset = tzOffsetMinutes is int
          ? Duration(minutes: tzOffsetMinutes)
          : null;
      final maxDays = map['offline_max_days'];
      if (maxDays is int && maxDays >= 1) _offlineMaxDays = maxDays;
      final lockMinutes = map['inactivity_lock_minutes'];
      if (lockMinutes is int && lockMinutes >= 1) {
        _inactivityLockMinutes = lockMinutes;
      }
    } catch (error) {
      // Estado corrupto o de un formato viejo (no sólo `FormatException`:
      // un valor con el tipo equivocado puede lanzar al hacer cast). Se
      // registra y se ignora — nunca revienta el arranque por un JSON
      // inválido, el servicio sigue con los valores por omisión.
      logger.w(_logTag, 'Estado de hora del servidor inválido: $error');
    }
  }

  /// Un ciclo de sincronización. Nunca lanza: cualquier fallo — del RPC, o
  /// de leer/guardar el estado local — deja el servicio en un estado
  /// consistente y lo registra con `logger.w` en vez de propagarlo, para
  /// que quien lo dispare con `unawaited(...)` nunca reciba un error sin
  /// manejar.
  Future<void> sync() async {
    await restore();
    final rpc = _rpcOf();
    if (rpc == null) return; // Sin cliente: sesión sin conexión, sin RPC.
    if (_modelKnownMissingThisSession) return;

    final sentAtDevice = _deviceNow().toUtc();
    _observeDeviceClock(sentAtDevice);
    final startTick = _monotonicElapsed();
    try {
      final response = await rpc();
      final rtt = _monotonicElapsed() - startTick;
      final serverUtc = _parseServerTimeUtc(response['server_time_utc']);
      final halfRtt = Duration(microseconds: rtt.inMicroseconds ~/ 2);
      _offset = serverUtc.difference(sentAtDevice.add(halfRtt));
      _rtt = rtt;
      _source = ClientPolicyTimeSource.server;
      _offlineMaxDays = _positiveIntOr(
        response['offline_max_days'],
        _offlineMaxDays,
      );
      _inactivityLockMinutes = _positiveIntOr(
        response['inactivity_lock_minutes'],
        _inactivityLockMinutes,
      );
      final tzOffsetMinutes = _intOrNull(response['user_tz_offset_minutes']);
      _userTzOffset = tzOffsetMinutes == null
          ? null
          : Duration(minutes: tzOffsetMinutes);
      _lastSyncAt = sentAtDevice;
      _lastOnlineAt = sentAtDevice;
      _syncedServerThisSession = true;
      await _persistAndTrackClock(sentAtDevice);
      onServerSynced?.call(snapshot);
    } on OdooNotFoundException {
      await _fallBackToDeviceForMissingModel(sentAtDevice);
    } on OdooMethodNotFoundException {
      await _fallBackToDeviceForMissingModel(sentAtDevice);
    } catch (_) {
      // Cualquier otro fallo (401, sin red, timeout, 500 del servidor): NO
      // es ausencia del modelo — orden del dueño: "un 401 o un error de red
      // NO es ausencia". Se conserva lo último tal cual, y el próximo
      // `sync()` vuelve a intentar el RPC porque el memo de "no existe"
      // nunca se puso.
    }
  }

  Future<void> _fallBackToDeviceForMissingModel(DateTime sentAtDevice) async {
    _modelKnownMissingThisSession = true;
    _source = ClientPolicyTimeSource.device;
    _offset = Duration.zero;
    _rtt = null;
    _userTzOffset = null;
    _lastSyncAt = sentAtDevice;
    // `_offlineMaxDays`/`_inactivityLockMinutes` se quedan en lo último que
    // ya tenían (persistido o el valor por omisión con el que arrancó el
    // servicio) — nunca se pisan con otra cosa en esta rama.
    await _persistAndTrackClock(sentAtDevice);
  }

  Future<void> _persistAndTrackClock(DateTime sentAtDevice) async {
    await _persist();
    _lastPersistedDeviceClockAt = sentAtDevice;
  }

  /// Nunca lanza: un `writeState` que falle (lease vencido al cerrar
  /// sesión, disco lleno, lo que sea) se registra con `logger.w` en vez de
  /// propagarse — de lo contrario `sync()` heredaría esa excepción y
  /// terminaría rompiendo un `unawaited(...)` que nadie espera.
  Future<void> _persist() async {
    final json = jsonEncode({
      'offset_ms': _offset.inMilliseconds,
      'rtt_ms': _rtt?.inMilliseconds,
      'source': _source == ClientPolicyTimeSource.server ? 'server' : 'device',
      'last_sync_at': _lastSyncAt?.toIso8601String(),
      'last_online_at': _lastOnlineAt?.toIso8601String(),
      'last_seen_device_utc': _lastSeenDeviceUtc?.toIso8601String(),
      'user_tz_offset_minutes': _userTzOffset?.inMinutes,
      'offline_max_days': _offlineMaxDays,
      'inactivity_lock_minutes': _inactivityLockMinutes,
    });
    try {
      await _writeState(json);
    } catch (error) {
      logger.w(
        _logTag,
        'No se pudo guardar el estado de hora del servidor: $error',
      );
    }
  }

  /// Hora estimada del servidor: la del equipo más el desfase guardado.
  /// Nunca hace RPC — lectura local pura, apta para un tic de UI de 1
  /// segundo.
  DateTime nowServer() {
    final now = _deviceNow().toUtc();
    _observeDeviceClock(now);
    _maybePersistDeviceClockMarker(now);
    return now.add(_offset);
  }

  /// Guarda la última hora del equipo vista y, si la lectura actual queda
  /// más de 5 minutos POR DETRÁS de la última vista, sospecha un retroceso
  /// del reloj. Compara contra lo que haya en memoria — que en el primer
  /// tic de una sesión nueva viene de [restore] si había algo persistido,
  /// así que cerrar la app, atrasar el reloj y reabrir SÍ se detecta.
  void _observeDeviceClock(DateTime current) {
    final last = _lastSeenDeviceUtc;
    if (last != null && last.difference(current) > const Duration(minutes: 5)) {
      _clockRollbackSuspected = true;
    }
    if (last == null || current.isAfter(last)) {
      _lastSeenDeviceUtc = current;
    }
  }

  /// Escribe [_lastSeenDeviceUtc] a disco cuando pasó al menos un minuto
  /// desde la última escritura — nunca en cada tic. Se queda callado
  /// mientras [restore] no haya corrido todavía: el resto del estado en
  /// memoria (offset, límites) aún no es de fiar, y escribir ahora pisaría
  /// un estado persistido más completo con los valores por omisión.
  void _maybePersistDeviceClockMarker(DateTime current) {
    if (!_restored) return;
    final lastPersisted = _lastPersistedDeviceClockAt;
    if (lastPersisted != null &&
        current.difference(lastPersisted) < const Duration(minutes: 1)) {
      return;
    }
    _lastPersistedDeviceClockAt = current;
    unawaited(_persist());
  }

  /// Sin conexión, o sin haber sincronizado todavía en ESTA sesión.
  bool get isEstimated => _rpcOf() == null || !_syncedServerThisSession;

  ClientPolicySnapshot get snapshot => ClientPolicySnapshot(
    offset: _offset,
    source: _source,
    rtt: _rtt,
    lastSyncAt: _lastSyncAt,
    lastOnlineAt: _lastOnlineAt,
    offlineMaxDays: _offlineMaxDays,
    inactivityLockMinutes: _inactivityLockMinutes,
    isEstimated: isEstimated,
    clockRollbackSuspected: _clockRollbackSuspected,
    userTzOffset: _userTzOffset,
  );
}

DateTime _parseServerTimeUtc(dynamic value) {
  if (value is! String) {
    throw const FormatException('Invalid client_policy server_time_utc');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const FormatException('Invalid client_policy server_time_utc');
  }
  return parsed.toUtc();
}

int _positiveIntOr(dynamic value, int fallback) =>
    value is int && value >= 1 ? value : fallback;

/// `user_tz_offset_minutes` puede venir ausente, `null`, o `false` (el
/// `False` de Python que Odoo manda para "sin valor") en un módulo viejo
/// que todavía no tiene este campo — cualquiera de los tres significa
/// "el servidor no lo trae", nunca un desfase de cero minutos inventado.
int? _intOrNull(dynamic value) => value is int ? value : null;

DateTime? _parseIsoUtc(dynamic value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}

/// Reloj monotónico por omisión: un único `Stopwatch` de vida entera del
/// proceso, nunca reiniciado — sólo importa la DIFERENCIA entre dos lecturas
/// que rodean un mismo RPC, nunca su valor absoluto.
final _sharedStopwatch = Stopwatch()..start();

Duration _defaultMonotonicElapsed() => _sharedStopwatch.elapsed;
