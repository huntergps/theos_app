/// Polling-based connectivity monitor (no Flutter dependency).
///
/// Checks connectivity by attempting HTTP HEAD requests to the configured URL.
/// For Flutter apps, prefer using `connectivity_plus` package instead.
library;

import 'dart:async';

import 'package:dio/dio.dart';

import 'server_connectivity_service.dart';

/// A pure-Dart [NetworkConnectivityMonitor] that periodically polls a URL
/// with HTTP HEAD requests to determine network availability.
class PollingConnectivityMonitor implements NetworkConnectivityMonitor {
  /// URL to probe for connectivity checks.
  final String checkUrl;

  /// How often to poll when [start] has been called.
  final Duration checkInterval;

  /// Timeout for each individual HTTP request.
  final Duration timeout;

  bool _lastKnownState = true;
  Timer? _timer;
  CancelToken? _cancelToken;

  /// Contador de generación: cada [start] y cada [stop] lo incrementan, y
  /// sirve para invalidar un sondeo periódico que sigue en vuelo. Así, si el
  /// sondeo termina después de un stop()/start() posterior, su resultado se
  /// descarta en vez de emitirse o reprogramar otro sondeo.
  int _generation = 0;

  final _controller = StreamController<bool>.broadcast();
  final _dio = Dio();

  PollingConnectivityMonitor({
    this.checkUrl = 'https://clients3.google.com/generate_204',
    this.checkInterval = const Duration(seconds: 30),
    this.timeout = const Duration(seconds: 5),
  });

  @override
  Future<bool> checkConnectivity() async {
    final connected = await _probe() ?? false;
    _emitIfChanged(connected);
    return connected;
  }

  /// Ejecuta un único sondeo HTTP HEAD contra [checkUrl].
  ///
  /// Devuelve `null` cuando el sondeo fue cancelado (vía [cancelToken], por
  /// un [stop] en curso) — eso NO es una desconexión real y nunca debe
  /// interpretarse ni emitirse como tal.
  Future<bool?> _probe({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.head<void>(
        checkUrl,
        cancelToken: cancelToken,
        options: Options(sendTimeout: timeout, receiveTimeout: timeout),
      );
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 400;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return null;
      }
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get connectivityStream => _controller.stream;

  /// Inicia el sondeo periódico.
  ///
  /// Los sondeos corren EN SERIE: el siguiente sólo se programa cuando el
  /// anterior terminó (éxito, error o timeout), nunca solapados. El primer
  /// sondeo sigue ocurriendo tras [checkInterval], igual que antes.
  void start() {
    stop();
    _scheduleNextProbe(_generation);
  }

  /// Detiene el sondeo periódico y cancela el sondeo en vuelo, si lo hay.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _cancelToken?.cancel();
    _cancelToken = null;
    // Invalida la generación vigente: un sondeo que ya estaba en vuelo y
    // termina después de este stop() se descarta en _runPeriodicProbe.
    _generation++;
  }

  /// Release resources. The monitor cannot be reused after this call.
  void dispose() {
    stop();
    _controller.close();
    _dio.close();
  }

  void _scheduleNextProbe(int generation) {
    _timer = Timer(checkInterval, () => _runPeriodicProbe(generation));
  }

  Future<void> _runPeriodicProbe(int generation) async {
    // stop() ya invalidó esta cadena de sondeos antes de que corriera este.
    if (generation != _generation) return;

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final connected = await _probe(cancelToken: cancelToken);

    // Si stop()/start() invalidó esta generación mientras el sondeo estaba
    // en vuelo, el resultado es viejo: no se emite y no se reprograma.
    if (generation != _generation) return;

    if (connected != null) {
      _emitIfChanged(connected);
    }
    _scheduleNextProbe(generation);
  }

  void _emitIfChanged(bool connected) {
    if (connected != _lastKnownState) {
      _lastKnownState = connected;
      if (!_controller.isClosed) {
        _controller.add(connected);
      }
    }
  }
}
