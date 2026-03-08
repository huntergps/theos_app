import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('ServerConnectionState', () {
    test('all states are defined', () {
      expect(ServerConnectionState.values, hasLength(6));
      expect(ServerConnectionState.values, contains(ServerConnectionState.online));
      expect(ServerConnectionState.values, contains(ServerConnectionState.degraded));
      expect(ServerConnectionState.values, contains(ServerConnectionState.unreachable));
      expect(ServerConnectionState.values, contains(ServerConnectionState.maintenance));
      expect(ServerConnectionState.values, contains(ServerConnectionState.sessionExpired));
      expect(ServerConnectionState.values, contains(ServerConnectionState.unknown));
    });
  });

  group('ConnectivityStatus', () {
    test('default constructor has correct defaults', () {
      const status = ConnectivityStatus();
      expect(status.hasNetwork, true);
      expect(status.serverState, ServerConnectionState.unknown);
      expect(status.webSocketConnected, false);
      expect(status.sessionValid, true);
      expect(status.consecutiveFailures, 0);
      expect(status.lastOnlineAt, null);
      expect(status.lastCheckedAt, null);
      expect(status.lastError, null);
      expect(status.latencyMs, null);
    });

    group('canAttemptRemote', () {
      test('returns true when network and server online', () {
        const status = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.online,
        );
        expect(status.canAttemptRemote, true);
      });

      test('returns true when network and server degraded', () {
        const status = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.degraded,
        );
        expect(status.canAttemptRemote, true);
      });

      test('returns true when network and server unknown', () {
        const status = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.unknown,
        );
        expect(status.canAttemptRemote, true);
      });

      test('returns false when no network', () {
        const status = ConnectivityStatus(
          hasNetwork: false,
          serverState: ServerConnectionState.online,
        );
        expect(status.canAttemptRemote, false);
      });

      test('returns false when server unreachable', () {
        const status = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.unreachable,
        );
        expect(status.canAttemptRemote, false);
      });
    });

    group('shouldSkipRemote', () {
      test('returns true when no network', () {
        const status = ConnectivityStatus(
          hasNetwork: false,
        );
        expect(status.shouldSkipRemote, true);
      });

      test('returns true when server unreachable', () {
        const status = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.unreachable,
        );
        expect(status.shouldSkipRemote, true);
      });

      test('returns true when server in maintenance', () {
        const status = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.maintenance,
        );
        expect(status.shouldSkipRemote, true);
      });

      test('returns false when server online', () {
        const status = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.online,
        );
        expect(status.shouldSkipRemote, false);
      });
    });

    group('isFullyOnline', () {
      test('returns true when network, server online, and session valid', () {
        const status = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.online,
          sessionValid: true,
        );
        expect(status.isFullyOnline, true);
      });

      test('returns false when session invalid', () {
        const status = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.online,
          sessionValid: false,
        );
        expect(status.isFullyOnline, false);
      });

      test('returns false when server degraded', () {
        const status = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.degraded,
          sessionValid: true,
        );
        expect(status.isFullyOnline, false);
      });
    });

    group('needsReauth', () {
      test('returns true when session expired', () {
        const status = ConnectivityStatus(
          serverState: ServerConnectionState.sessionExpired,
        );
        expect(status.needsReauth, true);
      });

      test('returns false for other states', () {
        const status = ConnectivityStatus(
          serverState: ServerConnectionState.online,
        );
        expect(status.needsReauth, false);
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        const original = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.online,
          consecutiveFailures: 0,
        );

        final modified = original.copyWith(
          hasNetwork: false,
          consecutiveFailures: 5,
        );

        expect(modified.hasNetwork, false);
        expect(modified.serverState, ServerConnectionState.online);
        expect(modified.consecutiveFailures, 5);
      });

      test('preserves unmodified values', () {
        final now = DateTime.now();
        final status = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.online,
          webSocketConnected: true,
          sessionValid: true,
          lastOnlineAt: now,
          lastCheckedAt: now,
          consecutiveFailures: 2,
          latencyMs: 150,
        );

        final copied = status.copyWith(hasNetwork: false);

        expect(copied.serverState, ServerConnectionState.online);
        expect(copied.webSocketConnected, true);
        expect(copied.sessionValid, true);
        expect(copied.lastOnlineAt, now);
        expect(copied.consecutiveFailures, 2);
        expect(copied.latencyMs, 150);
      });
    });

    group('equality', () {
      test('equal when all compared fields match', () {
        const status1 = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.online,
          webSocketConnected: true,
          sessionValid: true,
          consecutiveFailures: 0,
        );
        const status2 = ConnectivityStatus(
          hasNetwork: true,
          serverState: ServerConnectionState.online,
          webSocketConnected: true,
          sessionValid: true,
          consecutiveFailures: 0,
        );

        expect(status1 == status2, true);
        expect(status1.hashCode, status2.hashCode);
      });

      test('not equal when fields differ', () {
        const status1 = ConnectivityStatus(
          serverState: ServerConnectionState.online,
        );
        const status2 = ConnectivityStatus(
          serverState: ServerConnectionState.degraded,
        );

        expect(status1 == status2, false);
      });
    });

    test('toString includes key fields', () {
      const status = ConnectivityStatus(
        hasNetwork: true,
        serverState: ServerConnectionState.online,
        webSocketConnected: true,
        sessionValid: true,
        consecutiveFailures: 2,
      );

      final str = status.toString();
      expect(str, contains('network: true'));
      expect(str, contains('online'));
      expect(str, contains('ws: true'));
      expect(str, contains('session: true'));
      expect(str, contains('failures: 2'));
    });
  });

  group('ServerHealthConfig', () {
    test('default values are sensible', () {
      const config = ServerHealthConfig();
      expect(config.normalCheckInterval, const Duration(seconds: 120));
      expect(config.recoveryCheckInterval, const Duration(seconds: 30));
      expect(config.activityThreshold, const Duration(seconds: 30));
      expect(config.failureThreshold, 3);
      expect(config.maxCacheAge, const Duration(minutes: 5));
    });

    test('custom values are accepted', () {
      const config = ServerHealthConfig(
        normalCheckInterval: Duration(seconds: 60),
        recoveryCheckInterval: Duration(seconds: 10),
        activityThreshold: Duration(seconds: 15),
        failureThreshold: 5,
        maxCacheAge: Duration(minutes: 10),
      );

      expect(config.normalCheckInterval, const Duration(seconds: 60));
      expect(config.recoveryCheckInterval, const Duration(seconds: 10));
      expect(config.failureThreshold, 5);
    });
  });

  group('ServerHealthService.classifyError', () {
    test('classifies 401 as sessionExpired', () {
      expect(
        ServerHealthService.classifyError('error', 401),
        ServerConnectionState.sessionExpired,
      );
    });

    test('classifies 403 as sessionExpired', () {
      expect(
        ServerHealthService.classifyError('error', 403),
        ServerConnectionState.sessionExpired,
      );
    });

    test('classifies 502 as maintenance', () {
      expect(
        ServerHealthService.classifyError('error', 502),
        ServerConnectionState.maintenance,
      );
    });

    test('classifies 503 as maintenance', () {
      expect(
        ServerHealthService.classifyError('error', 503),
        ServerConnectionState.maintenance,
      );
    });

    test('classifies 504 as maintenance', () {
      expect(
        ServerHealthService.classifyError('error', 504),
        ServerConnectionState.maintenance,
      );
    });

    test('classifies 429 as degraded', () {
      expect(
        ServerHealthService.classifyError('error', 429),
        ServerConnectionState.degraded,
      );
    });

    test('classifies timeout error as unreachable', () {
      expect(
        ServerHealthService.classifyError('Connection timeout', null),
        ServerConnectionState.unreachable,
      );
      expect(
        ServerHealthService.classifyError('Request timed out', null),
        ServerConnectionState.unreachable,
      );
    });

    test('classifies connection refused as unreachable', () {
      expect(
        ServerHealthService.classifyError('Connection refused', null),
        ServerConnectionState.unreachable,
      );
    });

    test('classifies socket error as unreachable', () {
      expect(
        ServerHealthService.classifyError('SocketException', null),
        ServerConnectionState.unreachable,
      );
    });

    test('classifies host lookup error as unreachable', () {
      expect(
        ServerHealthService.classifyError('Host lookup failed', null),
        ServerConnectionState.unreachable,
      );
    });

    test('classifies unauthorized in message as sessionExpired', () {
      expect(
        ServerHealthService.classifyError('Error: Unauthorized access', null),
        ServerConnectionState.sessionExpired,
      );
    });

    test('classifies bad gateway in message as maintenance', () {
      expect(
        ServerHealthService.classifyError('502 Bad Gateway', null),
        ServerConnectionState.maintenance,
      );
    });

    test('classifies unknown errors as degraded', () {
      expect(
        ServerHealthService.classifyError('Some random error', null),
        ServerConnectionState.degraded,
      );
    });
  });
}
