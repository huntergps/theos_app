import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

void main() {
  const resolver = ConnectionStatusResolver();

  NetworkSignal signal(NetworkTransport transport) =>
      NetworkSignal(transports: [transport]);

  group('ConnectionStatusResolver', () {
    test('nothing measured yet stays unknown, never an optimistic guess', () {
      expect(
        resolver.resolve(network: null, backendProbe: null),
        ConnectionStatus.unknown,
      );
    });

    test('device reports no transport at all: offline, regardless of any '
        'stale backend probe', () {
      expect(
        resolver.resolve(
          network: signal(NetworkTransport.none),
          backendProbe: BackendProbeResult.reachable(),
        ),
        ConnectionStatus.offline,
      );
    });

    test('network present but the backend was never probed: still unknown, '
        'not "connected"', () {
      expect(
        resolver.resolve(network: signal(NetworkTransport.wifi), backendProbe: null),
        ConnectionStatus.unknown,
      );
    });

    test('network present and the backend answered: backend unreachable — '
        'this is the "server down, wifi fine" case, distinct from offline', () {
      expect(
        resolver.resolve(
          network: signal(NetworkTransport.wifi),
          backendProbe: BackendProbeResult.unreachable(),
        ),
        ConnectionStatus.backendUnreachable,
      );
    });

    test('network present and the backend rejected the credentials', () {
      expect(
        resolver.resolve(
          network: signal(NetworkTransport.wifi),
          backendProbe: BackendProbeResult.unauthorized(),
        ),
        ConnectionStatus.backendUnauthorized,
      );
    });

    test('network present and the backend answered normally: online', () {
      expect(
        resolver.resolve(
          network: signal(NetworkTransport.wifi),
          backendProbe: BackendProbeResult.reachable(),
        ),
        ConnectionStatus.online,
      );
    });
  });

  group('connectionStatusLabel', () {
    test('every status has a Spanish label, and unknown never claims health', () {
      expect(connectionStatusLabel(ConnectionStatus.unknown), 'Red sin verificar');
      expect(connectionStatusLabel(ConnectionStatus.offline), 'Sin red');
      expect(
        connectionStatusLabel(ConnectionStatus.backendUnreachable),
        'Red sin servidor',
      );
      expect(
        connectionStatusLabel(ConnectionStatus.backendUnauthorized),
        'Servidor sin autorizar',
      );
      expect(connectionStatusLabel(ConnectionStatus.online), 'Conectado');
    });
  });
}
