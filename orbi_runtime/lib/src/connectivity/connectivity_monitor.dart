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

/// The states the operational shell's footer can honestly show for the
/// connection. Three real cases, plus the honest admission that nothing has
/// been measured yet — never an optimistic default.
enum ConnectionStatus {
  /// Nothing has been measured yet: no [NetworkSignal] has arrived, or one
  /// arrived but the backend has never been probed. This is what "Red sin
  /// verificar" should mean literally — a fact about measurement, not a
  /// permanent placeholder.
  unknown,

  /// The device itself reports no network transport at all. This is the one
  /// case [ConnectivityMonitor] can answer with confidence on every platform
  /// except the web, where it can only ever report "the OS has an
  /// interface" (`navigator.onLine`) — it cannot see a dead Wi-Fi router or a
  /// cut cable behind a live interface.
  offline,

  /// There is a network transport, but the last backend probe did not get a
  /// reachable answer (timeout, connection refused, 5xx, ...). Distinct from
  /// [offline] on purpose: this is "the wifi is fine, the Odoo is down".
  backendUnreachable,

  /// There is a network transport and the backend answered, but rejected the
  /// current credentials.
  backendUnauthorized,

  /// There is a network transport and the backend answered normally.
  online,
}

/// Combines a device [NetworkSignal] with the most recent [BackendProbeResult]
/// into one [ConnectionStatus].
///
/// Deliberately a pure function of its two inputs: it never talks to a
/// plugin or the network itself, so every branch is testable with literal
/// values instead of faking a platform channel or an HTTP call.
final class ConnectionStatusResolver {
  const ConnectionStatusResolver();

  ConnectionStatus resolve({
    required NetworkSignal? network,
    required BackendProbeResult? backendProbe,
  }) {
    if (network == null) return ConnectionStatus.unknown;
    if (!network.hasNetwork) return ConnectionStatus.offline;
    if (backendProbe == null) return ConnectionStatus.unknown;
    return switch (backendProbe.state) {
      BackendProbeState.reachable => ConnectionStatus.online,
      BackendProbeState.unreachable => ConnectionStatus.backendUnreachable,
      BackendProbeState.unauthorized => ConnectionStatus.backendUnauthorized,
    };
  }
}

/// The Spanish label the operational shell's footer renders for [status].
/// Kept next to the enum so the two can never drift apart, and so nothing
/// else in the app has to reinvent this wording.
String connectionStatusLabel(ConnectionStatus status) => switch (status) {
  ConnectionStatus.unknown => 'Red sin verificar',
  ConnectionStatus.offline => 'Sin red',
  ConnectionStatus.backendUnreachable => 'Red sin servidor',
  ConnectionStatus.backendUnauthorized => 'Servidor sin autorizar',
  ConnectionStatus.online => 'Conectado',
};
