// El nombre público de los parámetros documenta mejor la intención en el
// sitio de la llamada que el nombre privado del campo — mismo motivo que
// `orbi_runtime/lib/src/clock/client_policy_sync_trigger.dart`.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:odoo_sdk/odoo_sdk.dart'
    show OdooAccessDeniedException, OdooClient;
import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/layouts/operational_shell.dart' show SriPendingStatus;

/// Cada cuánto se cuentan de nuevo los comprobantes SRI pendientes mientras
/// la sesión está en línea y estable — el contrato de la señal es "como
/// mucho cada 5 minutos".
const sriPendingPollInterval = Duration(minutes: 5);

/// Sondea `account.move` en busca de comprobantes electrónicos pendientes
/// ante el SRI (`edi_state in ['to_send', 'to_cancel']`) mientras hay un
/// cliente Odoo activo: como mucho cada [interval], y también al volver a
/// primer plano si ya pasó ese intervalo desde el último sondeo real.
///
/// Deliberadamente sin Riverpod: `_SriPendingNotifier` (`router.dart`) es la
/// única glue que la conecta al armazón — un `Timer.periodic` real, dentro
/// de un `Notifier`, no se puede probar sin esperar 5 minutos de verdad ni
/// montar un `ProviderContainer` con `fakeAsync` alrededor de Riverpod. Como
/// clase Dart simple, `sri_pending_poller_test.dart` la prueba con
/// `package:fake_async` y un `OdooClient` falso, sin ninguna de las dos
/// cosas.
///
/// Corrección del dueño, 14-sep-2026: antes el sondeo sólo se disparaba
/// cuando el propio `Notifier` se RECONSTRUÍA (cambio de
/// `authControllerProvider`/`runtimeSessionProvider`), así que con una
/// sesión estable la cifra quedaba congelada desde que se entró a la app.
///
/// Mismo patrón que `_PresenceSupportedNotifier`: primero se sonda si el
/// campo existe (`OdooClient.hasField`, que cachea por modelo) y se guarda
/// la respuesta en [supportedKey]; si no existe, la señal queda apagada
/// para siempre en esa sesión. Si existe, se cuenta con `searchCount` y el
/// último valor se guarda en [countKey] para mostrarlo sin conexión como
/// «(última lectura)».
///
/// Un `OdooAccessDeniedException` (el usuario no tiene permiso sobre
/// `account.move`) apaga la señal para esta instancia y cancela el
/// temporizador — no tiene sentido reintentar cada 5 minutos un RPC que el
/// servidor ya rechazó por permisos, y cada intento es un RPC gastado que
/// además ensucia el log. Cualquier otro error (sin red, timeout, el
/// servidor cayó a mitad del conteo) sólo se reporta con [onWarning] y
/// conserva la última lectura guardada — nunca un error visible en la
/// barra superior.
final class SriPendingPoller {
  SriPendingPoller({
    required OdooClient client,
    required SharedPreferences prefs,
    required String supportedKey,
    required String countKey,
    required Stream<bool> foreground,
    required void Function(SriPendingStatus? status) onStatusChanged,
    void Function(String message)? onWarning,
    this.interval = sriPendingPollInterval,
  }) : _client = client,
       _prefs = prefs,
       _supportedKey = supportedKey,
       _countKey = countKey,
       _onStatusChanged = onStatusChanged,
       _onWarning = onWarning {
    _timer = Timer.periodic(interval, (_) => unawaited(_runProbe()));
    _foregroundSubscription = foreground.listen((isForeground) {
      if (isForeground) _probeIfDue();
    });
    // Sondeo inmediato al construirse (entrar o restaurar sesión en línea),
    // sin esperar al primer tic del temporizador.
    unawaited(_runProbe());
  }

  final OdooClient _client;
  final SharedPreferences _prefs;
  final String _supportedKey;
  final String _countKey;
  final void Function(SriPendingStatus? status) _onStatusChanged;
  final void Function(String message)? _onWarning;
  final Duration interval;

  Timer? _timer;
  StreamSubscription<bool>? _foregroundSubscription;
  DateTime? _lastProbe;
  bool _probing = false;
  bool _accessDenied = false;

  void _probeIfDue() {
    final now = DateTime.now();
    if (_lastProbe != null && now.difference(_lastProbe!) < interval) return;
    unawaited(_runProbe());
  }

  /// Fija `_lastProbe` al INICIO del sondeo (no al programarlo) y evita dos
  /// sondeos en vuelo a la vez — el temporizador y "volver a primer plano"
  /// pueden coincidir casi al mismo instante.
  Future<void> _runProbe() async {
    if (_probing || _accessDenied) return;
    _probing = true;
    _lastProbe = DateTime.now();
    try {
      await _probe();
    } finally {
      _probing = false;
    }
  }

  Future<void> _probe() async {
    try {
      final hasField = await _client.hasField('account.move', 'edi_state');
      await _prefs.setBool(_supportedKey, hasField);
      if (!hasField) {
        await _prefs.remove(_countKey);
        _onStatusChanged(null);
        return;
      }
      final count = await _client.searchCount(
        model: 'account.move',
        domain: const [
          [
            'edi_state',
            'in',
            ['to_send', 'to_cancel'],
          ],
        ],
      );
      final resolved = count ?? 0;
      await _prefs.setInt(_countKey, resolved);
      _onStatusChanged(
        resolved <= 0
            ? null
            : SriPendingStatus(count: resolved, isLastReading: false),
      );
    } on OdooAccessDeniedException catch (error) {
      _accessDenied = true;
      _timer?.cancel();
      _timer = null;
      _onWarning?.call(
        'Sin permiso sobre account.move ($error). '
        'Señal de pendientes SRI apagada para esta sesión.',
      );
      _onStatusChanged(null);
    } catch (error) {
      _onWarning?.call(
        'Sondeo de comprobantes SRI pendientes falló ($error). '
        'Se conserva la última lectura guardada.',
      );
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    unawaited(_foregroundSubscription?.cancel());
  }
}
