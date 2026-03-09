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
  final _controller = StreamController<bool>.broadcast();
  final _dio = Dio();

  PollingConnectivityMonitor({
    this.checkUrl = 'https://clients3.google.com/generate_204',
    this.checkInterval = const Duration(seconds: 30),
    this.timeout = const Duration(seconds: 5),
  });

  @override
  Future<bool> checkConnectivity() async {
    try {
      final response = await _dio.head<void>(
        checkUrl,
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );
      final connected =
          response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 400;
      _emitIfChanged(connected);
      return connected;
    } on DioException {
      _emitIfChanged(false);
      return false;
    } on TimeoutException {
      _emitIfChanged(false);
      return false;
    } catch (_) {
      _emitIfChanged(false);
      return false;
    }
  }

  @override
  Stream<bool> get connectivityStream => _controller.stream;

  /// Start periodic connectivity checking.
  void start() {
    stop();
    _timer = Timer.periodic(checkInterval, (_) => checkConnectivity());
  }

  /// Stop periodic connectivity checking.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Release resources. The monitor cannot be reused after this call.
  void dispose() {
    stop();
    _controller.close();
    _dio.close();
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
