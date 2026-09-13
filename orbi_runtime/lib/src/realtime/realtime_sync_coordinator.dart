/// Único dueño del ciclo de vida del socket de tiempo real para el scope
/// activo — mismo patrón que `SyncCoordinator`: `start`/`stop`, y un scope
/// nuevo siempre cierra al anterior antes de abrir el suyo.
///
/// Diseño (decidido, ver el encargo de la tarea): el aviso `app_sync/changed`
/// es una PISTA, nunca la verdad — la sincronización incremental por cursor
/// que ya existe (`CatalogSyncJob`, con bajas) sigue siendo la única que
/// escribe en Drift. Este coordinador sólo decide CUÁNDO pedirle al
/// [SyncCoordinator] inyectado que corra, y de qué catálogos exactamente,
/// pasando siempre por su drenaje único (nunca en paralelo con otro).
// Private fields select the injected ports without exposing implementation
// details as public constructor parameters.
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:async';

// `odoo_sdk` also declares its own `SyncCoordinator` (a different, older
// abstraction) — hidden here so `contracts.dart`'s is the one in scope.
import 'package:odoo_sdk/odoo_sdk.dart' hide SyncCoordinator;

import '../contracts.dart';
import '../sync/sync_coordinator_impl.dart' show ApiKeyRenewalTrigger;
import 'realtime_change_debouncer.dart';
import 'realtime_session_client.dart';
import 'realtime_status.dart';

typedef RealtimeSessionClientFactory =
    RealtimeSessionClient Function(AppScope scope);
typedef RealtimeLastReader = Future<int?> Function(AppScope scope);
typedef RealtimeLastWriter = Future<void> Function(AppScope scope, int last);
typedef RealtimeWebSocketServiceFactory = OdooWebSocketService Function();

final class RealtimeSyncCoordinator {
  RealtimeSyncCoordinator({
    required SyncCoordinator syncCoordinator,
    required Map<String, Set<String>> modelJobIds,
    required RealtimeSessionClientFactory sessionClientFor,
    required RealtimeLastReader readLastNotificationId,
    required RealtimeLastWriter writeLastNotificationId,
    required Stream<bool> online,
    int? Function()? activeCompanyId,
    this.apiKeyRenewal,
    RealtimeWebSocketServiceFactory? createService,
    this.debounce = const Duration(milliseconds: 400),
    this.allowInsecure = false,
  }) : _syncCoordinator = syncCoordinator,
       _modelJobIds = modelJobIds,
       _sessionClientFor = sessionClientFor,
       _readLast = readLastNotificationId,
       _writeLast = writeLastNotificationId,
       _activeCompanyId = activeCompanyId ?? (() => null),
       _createService = createService ?? OdooWebSocketService.new {
    _onlineSubscription = online.listen(_onOnlineChanged);
  }

  final SyncCoordinator _syncCoordinator;
  final Map<String, Set<String>> _modelJobIds;
  final RealtimeSessionClientFactory _sessionClientFor;
  final RealtimeLastReader _readLast;
  final RealtimeLastWriter _writeLast;
  final int? Function() _activeCompanyId;

  /// Ver `ApiKeyRenewalTrigger` en `sync_coordinator_impl.dart`: el mismo
  /// mecanismo que ya usa la sincronización periódica, nunca uno nuevo.
  /// `null` cuando este runtime no compone autenticación nativa (arnés de
  /// pruebas) — en ese caso un 401 simplemente no dispara renovación.
  final ApiKeyRenewalTrigger? apiKeyRenewal;

  final RealtimeWebSocketServiceFactory _createService;
  final Duration debounce;
  final bool allowInsecure;

  late final StreamSubscription<bool> _onlineSubscription;
  final _statusController = StreamController<RealtimeStatus>.broadcast();

  AppScope? _scope;
  OdooWebSocketService? _service;
  OdooWebSocketConnectionInfo? _connectionInfo;
  StreamSubscription<OdooWebSocketEvent>? _eventSubscription;
  StreamSubscription<int>? _lastIdSubscription;
  RealtimeChangeDebouncer? _debouncer;

  /// Asumido en línea hasta que la señal de red diga lo contrario — igual
  /// que el resto del runtime nunca empieza pesimista sin haber medido nada.
  bool _online = true;
  bool _disabled = false;
  RealtimeStatus _status = RealtimeStatus.offline;

  Stream<RealtimeStatus> get status => _statusController.stream;
  RealtimeStatus get currentStatus => _status;

  /// Avisos `app_sync/changed` (y cualquier otro tipo no mapeado) tal como
  /// los entrega el socket, ANTES del filtro por modelo/empresa de
  /// [RealtimeChangeDebouncer] — nunca los usa el flujo normal (ese sólo le
  /// importa a `_debouncer`, que ya escucha su propia copia de este mismo
  /// stream). Expuesto para depuración y para las pruebas de extremo a
  /// extremo contra un Odoo real, donde hace falta ver el modelo/ids
  /// crudos de un aviso concreto. `null` mientras no hay scope activo.
  Stream<OdooRawNotificationEvent>? get rawNotifications =>
      _service?.eventsOfType<OdooRawNotificationEvent>();

  Future<void> start(AppScope scope) async {
    await _teardown();
    _scope = scope;
    _disabled = false;

    final sessionClient = _sessionClientFor(scope);
    final initialLast = await _readLast(scope) ?? 0;

    final service = _createService();
    _service = service;
    _eventSubscription = service.eventStream.listen(_onEvent);
    _lastIdSubscription = service.lastNotificationIdStream.listen(
      (value) => unawaited(_writeLast(scope, value)),
    );
    _debouncer = RealtimeChangeDebouncer(
      notifications: service.eventsOfType<OdooRawNotificationEvent>(),
      modelJobIds: _modelJobIds,
      activeCompanyId: _activeCompanyId,
      debounce: debounce,
      onDebounced: (jobIds) => unawaited(
        _syncCoordinator.requestSync(
          SyncReason('realtime:changed', onlyJobIds: jobIds),
        ),
      ),
    );
    service.addChannels(const ['app_sync']);

    _connectionInfo = OdooWebSocketConnectionInfo(
      baseUrl: scope.normalizedServerUrl,
      database: scope.database,
      realtimeCredentialProvider: sessionClient.createSession,
      initialLast: initialLast,
      allowInsecure: allowInsecure,
    );

    if (!_online) {
      _publish(RealtimeStatus.offline);
      return;
    }
    _publish(RealtimeStatus.connecting);
    await service.connect(_connectionInfo!);
  }

  Future<void> stop(AppScope scope) async {
    if (_scope != scope) return;
    await _teardown();
  }

  void _onEvent(OdooWebSocketEvent event) {
    final scope = _scope;
    if (scope == null) return;
    switch (event) {
      case OdooConnectionEvent e:
        if (e.isConnected) {
          _publish(RealtimeStatus.live);
          if (e.isReconnection) {
            // Se pudo perder avisos mientras estuvo cortado: una pasada de
            // TODOS los catálogos, no sólo del que hubiera avisado antes de
            // caerse — a diferencia de `RealtimeChangeDebouncer`, que sólo
            // corre el catálogo señalado por un aviso puntual.
            unawaited(
              _syncCoordinator.requestSync(
                SyncReason('realtime:reconnect'),
              ),
            );
          }
        } else if (!_disabled) {
          _publish(_online ? RealtimeStatus.retrying : RealtimeStatus.offline);
        }
      case OdooSubscriptionOutdatedEvent _:
        // El `last` que mandamos en `subscribe` ya no existe en `bus.bus`
        // (server-side, `ir_websocket.py: _subscribe`): pudimos perder
        // avisos. Misma receta que tras una reconexión — TODOS los
        // catálogos, no sólo el que hubiera avisado.
        unawaited(
          _syncCoordinator.requestSync(
            SyncReason('realtime:subscription_outdated'),
          ),
        );
      case OdooErrorEvent e:
        final error = e.error;
        if (error is RealtimeUnsupportedException) {
          // El servidor no tiene el módulo: cortar aquí mismo el reintento
          // que `OdooWebSocketService` ya programó al emitir este mismo
          // error, para que nunca vuelva a llamar al proveedor de sesión.
          _disabled = true;
          _service?.disconnect();
          _publish(RealtimeStatus.disabled);
        } else if (error is RealtimeUnauthorizedException) {
          final renew = apiKeyRenewal;
          if (renew != null) unawaited(renew(scope));
          // Sin forzar una reconexión inmediata: el reintento que
          // `OdooWebSocketService` ya programó volverá a llamar al
          // proveedor, y para entonces la llave puede ya estar renovada.
        }
      default:
        break;
    }
  }

  void _onOnlineChanged(bool online) {
    _online = online;
    final service = _service;
    final info = _connectionInfo;
    if (service == null || info == null || _disabled) return;
    if (!online) {
      // Cortar el socket (y cualquier reintento que tuviera programado) en
      // vez de dejar que `OdooWebSocketService` siga reintentando en bucle
      // contra una red que no existe.
      service.disconnect();
      _publish(RealtimeStatus.offline);
    } else {
      _publish(RealtimeStatus.connecting);
      unawaited(service.connect(info));
    }
  }

  void _publish(RealtimeStatus value) {
    _status = value;
    if (!_statusController.isClosed) _statusController.add(value);
  }

  /// No espera a que las cancelaciones de suscripción terminen de verdad
  /// (`unawaited`): lo único que importa antes de seguir es que dejen de
  /// invocar sus callbacks — Dart lo garantiza en cuanto se llama `cancel()`
  /// — nunca que su `Future` se resuelva. Esperarlo aquí (con `await`) deja
  /// el `start()` de un scope nuevo pendiente de un vaciado de microtareas
  /// extra e impredecible del stream `broadcast` subyacente, que en algunos
  /// casos no ocurre dentro del mismo tramo síncrono.
  Future<void> _teardown() async {
    _disabled = false;

    final eventSub = _eventSubscription;
    _eventSubscription = null;
    if (eventSub != null) unawaited(eventSub.cancel());

    final lastIdSub = _lastIdSubscription;
    _lastIdSubscription = null;
    if (lastIdSub != null) unawaited(lastIdSub.cancel());

    final debouncer = _debouncer;
    _debouncer = null;
    if (debouncer != null) unawaited(debouncer.dispose());

    _service?.dispose();
    _service = null;
    _connectionInfo = null;
    _scope = null;
  }

  Future<void> dispose() async {
    await _teardown();
    await _onlineSubscription.cancel();
    if (!_statusController.isClosed) await _statusController.close();
  }
}
