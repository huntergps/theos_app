import 'package:connectivity_plus/connectivity_plus.dart';

import '../contracts.dart';

typedef ConnectivityValues = Future<List<ConnectivityResult>> Function();
typedef ConnectivityChanges = Stream<List<ConnectivityResult>> Function();

/// Adapter boundary: connectivity is only a network hint, never backend health.
final class ConnectivityMonitor {
  ConnectivityMonitor({ConnectivityValues? check, ConnectivityChanges? changes})
    : _check = check ?? Connectivity().checkConnectivity,
      _changes = changes ?? (() => Connectivity().onConnectivityChanged);

  final ConnectivityValues _check;
  final ConnectivityChanges _changes;

  Future<NetworkSignal> check() async => _map(await _check());

  Stream<NetworkSignal> watch() async* {
    yield await check();
    await for (final values in _changes()) {
      yield _map(values);
    }
  }

  static NetworkSignal _map(List<ConnectivityResult> values) {
    return NetworkSignal(transports: values.map(_mapTransport));
  }

  static NetworkTransport _mapTransport(ConnectivityResult value) {
    return switch (value) {
      ConnectivityResult.none => NetworkTransport.none,
      ConnectivityResult.wifi => NetworkTransport.wifi,
      ConnectivityResult.mobile => NetworkTransport.mobile,
      ConnectivityResult.ethernet => NetworkTransport.ethernet,
      ConnectivityResult.vpn => NetworkTransport.vpn,
      _ => NetworkTransport.other,
    };
  }
}

enum BackendProbeState { reachable, unreachable, unauthorized }

final class BackendProbeResult {
  BackendProbeResult._({
    required this.state,
    this.errorCode,
    DateTime? checkedAt,
  }) : checkedAt = (checkedAt ?? DateTime.now()).toUtc();

  BackendProbeResult.reachable({DateTime? checkedAt})
    : this._(state: BackendProbeState.reachable, checkedAt: checkedAt);

  BackendProbeResult.unreachable({String? errorCode, DateTime? checkedAt})
    : this._(
        state: BackendProbeState.unreachable,
        errorCode: errorCode,
        checkedAt: checkedAt,
      );

  BackendProbeResult.unauthorized({String? errorCode, DateTime? checkedAt})
    : this._(
        state: BackendProbeState.unauthorized,
        errorCode: errorCode,
        checkedAt: checkedAt,
      );

  final BackendProbeState state;
  final String? errorCode;
  final DateTime checkedAt;

  BackendHealth get health => BackendHealth(
    state: state == BackendProbeState.reachable
        ? BackendHealthState.reachable
        : state == BackendProbeState.unreachable
        ? BackendHealthState.unreachable
        : BackendHealthState.reachable,
    lastCheckedAt: checkedAt,
  );

  AuthStatus get authStatus => switch (state) {
    BackendProbeState.unauthorized => AuthStatus.expired,
    BackendProbeState.unreachable => AuthStatus.unknown,
    BackendProbeState.reachable => AuthStatus.authenticated,
  };
}

abstract interface class BackendProbe {
  Future<BackendProbeResult> probe(AppScope scope);
}
