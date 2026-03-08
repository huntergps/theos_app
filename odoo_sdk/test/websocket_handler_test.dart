import 'package:odoo_sdk/src/model/odoo_model_manager.dart';
import 'package:odoo_sdk/src/websocket/websocket_handler.dart';
import 'package:test/test.dart';

void main() {
  group('WebSocketConfig', () {
    group('constructor', () {
      test('creates config with required parameters', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );

        expect(config.url, 'wss://example.com/websocket');
        expect(config.database, 'test_db');
        expect(config.userId, 1);
      });

      test('has sensible defaults', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );

        expect(config.sessionToken, null);
        expect(config.subscribedModels, isEmpty);
        expect(config.reconnectDelayMs, 5000);
        expect(config.maxReconnectAttempts, 0);
        expect(config.autoReconnect, true);
        expect(config.allowInsecure, false);
        expect(config.allowedModels, isEmpty);
        expect(config.requireSessionToken, true); // SEC-03: Secure by default
      });

      test('accepts all optional parameters', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: 'abc123',
          subscribedModels: ['res.partner', 'product.product'],
          reconnectDelayMs: 10000,
          maxReconnectAttempts: 5,
          autoReconnect: false,
          allowInsecure: true,
          allowedModels: {'res.partner', 'product.product'},
          requireSessionToken: false,
        );

        expect(config.sessionToken, 'abc123');
        expect(config.subscribedModels, ['res.partner', 'product.product']);
        expect(config.reconnectDelayMs, 10000);
        expect(config.maxReconnectAttempts, 5);
        expect(config.autoReconnect, false);
        expect(config.allowInsecure, true);
        expect(config.allowedModels, {'res.partner', 'product.product'});
        expect(config.requireSessionToken, false);
      });
    });

    group('validateSecureConnection', () {
      test('accepts wss:// URL', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );

        expect(() => config.validateSecureConnection(), returnsNormally);
      });

      test('accepts wss:// URL with port', () {
        const config = WebSocketConfig(
          url: 'wss://example.com:8443/websocket',
          database: 'test_db',
          userId: 1,
        );

        expect(() => config.validateSecureConnection(), returnsNormally);
      });

      test('rejects ws:// URL by default', () {
        const config = WebSocketConfig(
          url: 'ws://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );

        expect(
          () => config.validateSecureConnection(),
          throwsA(
            isA<WebSocketSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Insecure WebSocket'),
            ),
          ),
        );
      });

      test('accepts ws:// when allowInsecure is true', () {
        const config = WebSocketConfig(
          url: 'ws://localhost/websocket',
          database: 'test_db',
          userId: 1,
          allowInsecure: true,
        );

        expect(() => config.validateSecureConnection(), returnsNormally);
      });

      test('rejects invalid URL', () {
        const config = WebSocketConfig(
          url: 'not a valid url',
          database: 'test_db',
          userId: 1,
        );

        expect(
          () => config.validateSecureConnection(),
          throwsA(
            isA<WebSocketSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Invalid WebSocket'),
            ),
          ),
        );
      });

      test('rejects http:// URL', () {
        const config = WebSocketConfig(
          url: 'http://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );

        expect(
          () => config.validateSecureConnection(),
          throwsA(
            isA<WebSocketSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Invalid WebSocket scheme'),
            ),
          ),
        );
      });

      test('rejects https:// URL', () {
        const config = WebSocketConfig(
          url: 'https://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );

        expect(
          () => config.validateSecureConnection(),
          throwsA(
            isA<WebSocketSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Invalid WebSocket scheme'),
            ),
          ),
        );
      });
    });

    group('validateModels', () {
      test('allows any models when whitelist is empty', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          allowedModels: {},
        );

        expect(
          () => config.validateModels(['res.partner', 'custom.model']),
          returnsNormally,
        );
      });

      test('allows models in whitelist', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          allowedModels: {'res.partner', 'product.product'},
        );

        expect(
          () => config.validateModels(['res.partner', 'product.product']),
          returnsNormally,
        );
      });

      test('allows single model in whitelist', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          allowedModels: {'res.partner', 'product.product'},
        );

        expect(() => config.validateModels(['res.partner']), returnsNormally);
      });

      test('rejects models not in whitelist', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          allowedModels: {'res.partner'},
        );

        expect(
          () => config.validateModels(['product.product']),
          throwsA(
            isA<WebSocketSecurityException>().having(
              (e) => e.message,
              'message',
              allOf(contains('not in whitelist'), contains('product.product')),
            ),
          ),
        );
      });

      test('lists disallowed models in error', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          allowedModels: {'res.partner'},
        );

        expect(
          () => config.validateModels(['product.product', 'sale.order']),
          throwsA(
            isA<WebSocketSecurityException>().having(
              (e) => e.message,
              'message',
              allOf(contains('product.product'), contains('sale.order')),
            ),
          ),
        );
      });

      test('lists allowed models in error', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          allowedModels: {'res.partner', 'product.product'},
        );

        expect(
          () => config.validateModels(['sale.order']),
          throwsA(
            isA<WebSocketSecurityException>().having(
              (e) => e.message,
              'message',
              allOf(contains('Allowed:'), contains('res.partner')),
            ),
          ),
        );
      });
    });

    group('validateSessionToken (SEC-03)', () {
      test(
        'throws when sessionToken is null and requireSessionToken is true',
        () {
          const config = WebSocketConfig(
            url: 'wss://example.com/websocket',
            database: 'test_db',
            userId: 1,
            sessionToken: null,
            requireSessionToken: true,
          );

          expect(
            () => config.validateSessionToken(),
            throwsA(isA<SessionTokenRequiredException>()),
          );
        },
      );

      test(
        'throws when sessionToken is empty and requireSessionToken is true',
        () {
          const config = WebSocketConfig(
            url: 'wss://example.com/websocket',
            database: 'test_db',
            userId: 1,
            sessionToken: '',
            requireSessionToken: true,
          );

          expect(
            () => config.validateSessionToken(),
            throwsA(isA<SessionTokenRequiredException>()),
          );
        },
      );

      test('passes when sessionToken is provided', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: 'valid-session-token',
          requireSessionToken: true,
        );

        expect(() => config.validateSessionToken(), returnsNormally);
      });

      test('passes when requireSessionToken is false and token is null', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: null,
          requireSessionToken: false,
        );

        expect(() => config.validateSessionToken(), returnsNormally);
      });

      test('passes when requireSessionToken is false and token is empty', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: '',
          requireSessionToken: false,
        );

        expect(() => config.validateSessionToken(), returnsNormally);
      });

      test('error message provides helpful information', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: null,
          requireSessionToken: true,
        );

        expect(
          () => config.validateSessionToken(),
          throwsA(
            isA<SessionTokenRequiredException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Session token is required'),
                contains('requireSessionToken=false'),
              ),
            ),
          ),
        );
      });
    });

    group('validateSecurity', () {
      test('validates both connection and session token', () {
        // Both validations pass
        const validConfig = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: 'valid-token',
          requireSessionToken: true,
          allowInsecure: false,
        );

        expect(() => validConfig.validateSecurity(), returnsNormally);
      });

      test('throws WebSocketSecurityException for insecure URL', () {
        const insecureConfig = WebSocketConfig(
          url: 'ws://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: 'valid-token',
          requireSessionToken: true,
          allowInsecure: false,
        );

        expect(
          () => insecureConfig.validateSecurity(),
          throwsA(isA<WebSocketSecurityException>()),
        );
      });

      test('throws SessionTokenRequiredException for missing token', () {
        const noTokenConfig = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: null,
          requireSessionToken: true,
          allowInsecure: false,
        );

        expect(
          () => noTokenConfig.validateSecurity(),
          throwsA(isA<SessionTokenRequiredException>()),
        );
      });

      test('URL validation runs before token validation', () {
        // Both are invalid, but URL validation runs first
        const bothInvalid = WebSocketConfig(
          url: 'ws://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: null,
          requireSessionToken: true,
          allowInsecure: false,
        );

        // Should throw WebSocketSecurityException (URL error), not SessionTokenRequiredException
        expect(
          () => bothInvalid.validateSecurity(),
          throwsA(isA<WebSocketSecurityException>()),
        );
      });
    });

    group('copyWith', () {
      test('creates a copy with updated sessionToken', () {
        const original = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: 'old-token',
        );

        final updated = original.copyWith(sessionToken: 'new-token');

        expect(updated.sessionToken, 'new-token');
        expect(updated.url, original.url);
        expect(updated.database, original.database);
        expect(updated.userId, original.userId);
      });

      test('creates a copy with updated requireSessionToken', () {
        const original = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          requireSessionToken: true,
        );

        final updated = original.copyWith(requireSessionToken: false);

        expect(updated.requireSessionToken, false);
        expect(original.requireSessionToken, true);
      });

      test('preserves all fields when no updates provided', () {
        const original = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 42,
          sessionToken: 'token',
          subscribedModels: ['res.partner'],
          reconnectDelayMs: 10000,
          maxReconnectAttempts: 5,
          autoReconnect: false,
          allowInsecure: true,
          allowedModels: {'res.partner'},
          requireSessionToken: false,
        );

        final copy = original.copyWith();

        expect(copy.url, original.url);
        expect(copy.database, original.database);
        expect(copy.userId, original.userId);
        expect(copy.sessionToken, original.sessionToken);
        expect(copy.subscribedModels, original.subscribedModels);
        expect(copy.reconnectDelayMs, original.reconnectDelayMs);
        expect(copy.maxReconnectAttempts, original.maxReconnectAttempts);
        expect(copy.autoReconnect, original.autoReconnect);
        expect(copy.allowInsecure, original.allowInsecure);
        expect(copy.allowedModels, original.allowedModels);
        expect(copy.requireSessionToken, original.requireSessionToken);
      });
    });

    group('toString', () {
      test('masks session token', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: 'supersecrettoken123',
        );

        final str = config.toString();

        expect(str, isNot(contains('supersecrettoken123')));
        expect(str, contains('****'));
      });

      test('shows null for missing session token', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );

        final str = config.toString();

        expect(str, contains('sessionToken: null'));
      });

      test('shows secure status', () {
        const secureConfig = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          allowInsecure: false,
        );

        const insecureConfig = WebSocketConfig(
          url: 'ws://localhost/websocket',
          database: 'test_db',
          userId: 1,
          allowInsecure: true,
        );

        expect(secureConfig.toString(), contains('secure: true'));
        expect(insecureConfig.toString(), contains('secure: false'));
      });

      test('includes URL and database', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );

        final str = config.toString();

        expect(str, contains('url: wss://example.com/websocket'));
        expect(str, contains('database: test_db'));
      });

      test('includes user ID', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 42,
        );

        expect(config.toString(), contains('userId: 42'));
      });

      test('includes model count', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          subscribedModels: ['a', 'b', 'c'],
        );

        expect(config.toString(), contains('models: 3'));
      });
    });
  });

  group('WebSocketSecurityException', () {
    test('stores message', () {
      const exception = WebSocketSecurityException('Test error');
      expect(exception.message, 'Test error');
    });

    test('toString includes class name and message', () {
      const exception = WebSocketSecurityException('Security violation');
      expect(
        exception.toString(),
        'WebSocketSecurityException: Security violation',
      );
    });
  });

  group('SessionTokenRequiredException (SEC-03)', () {
    test('stores message', () {
      const exception = SessionTokenRequiredException('Custom message');
      expect(exception.message, 'Custom message');
    });

    test('has default message', () {
      const exception = SessionTokenRequiredException();
      expect(exception.message, contains('Session token is required'));
    });

    test('toString includes class name and message', () {
      const exception = SessionTokenRequiredException('Token missing');
      expect(
        exception.toString(),
        'SessionTokenRequiredException: Token missing',
      );
    });
  });

  group('WebSocketState', () {
    test('has all expected values', () {
      expect(
        WebSocketState.values,
        containsAll([
          WebSocketState.disconnected,
          WebSocketState.connecting,
          WebSocketState.connected,
          WebSocketState.reconnecting,
          WebSocketState.error,
        ]),
      );
    });
  });

  group('ConnectionEventType', () {
    test('has all expected values', () {
      expect(
        ConnectionEventType.values,
        containsAll([
          ConnectionEventType.connected,
          ConnectionEventType.disconnected,
          ConnectionEventType.reconnecting,
          ConnectionEventType.error,
        ]),
      );
    });
  });

  group('WebSocketConnectionEvent', () {
    test('creates event with required parameters', () {
      final timestamp = DateTime.now();
      final event = WebSocketConnectionEvent(
        type: ConnectionEventType.connected,
        timestamp: timestamp,
      );

      expect(event.type, ConnectionEventType.connected);
      expect(event.timestamp, timestamp);
      expect(event.error, null);
    });

    test('includes error when provided', () {
      final event = WebSocketConnectionEvent(
        type: ConnectionEventType.error,
        timestamp: DateTime.now(),
        error: 'Connection refused',
      );

      expect(event.type, ConnectionEventType.error);
      expect(event.error, 'Connection refused');
    });

    test('toString shows type and error', () {
      final event = WebSocketConnectionEvent(
        type: ConnectionEventType.error,
        timestamp: DateTime.now(),
        error: 'Timeout',
      );

      final str = event.toString();

      expect(str, contains('error'));
      expect(str, contains('Timeout'));
    });
  });

  group('OdooWebSocketHandler', () {
    group('initial state', () {
      test('starts disconnected', () async {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );
        final handler = OdooWebSocketHandler(config);

        expect(handler.currentState, WebSocketState.disconnected);
        expect(handler.isConnected, false);

        await handler.dispose();
      });
    });

    group('connect validation', () {
      test('validates secure connection before connecting', () async {
        const config = WebSocketConfig(
          url: 'ws://example.com/websocket',
          database: 'test_db',
          userId: 1,
          allowInsecure: false,
          sessionToken: 'valid-token',
          requireSessionToken: true,
        );
        final handler = OdooWebSocketHandler(config);

        // Security exception is thrown synchronously before connection attempt
        expect(
          () => handler.connect(),
          throwsA(isA<WebSocketSecurityException>()),
        );

        await handler.dispose();
      });

      test(
        'allows insecure connection config when allowInsecure is true',
        () async {
          const config = WebSocketConfig(
            url: 'ws://localhost/websocket',
            database: 'test_db',
            userId: 1,
            allowInsecure: true,
            sessionToken: 'valid-token',
            requireSessionToken: true,
          );
          final handler = OdooWebSocketHandler(config);

          // Handler created successfully with insecure config
          expect(handler.currentState, WebSocketState.disconnected);
          // validateSecureConnection doesn't throw
          expect(() => config.validateSecureConnection(), returnsNormally);

          await handler.dispose();
        },
      );

      test('SEC-03: validates session token before connecting', () async {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          sessionToken: null,
          requireSessionToken: true,
        );
        final handler = OdooWebSocketHandler(config);

        // Session token exception is thrown before connection attempt
        expect(
          () => handler.connect(),
          throwsA(isA<SessionTokenRequiredException>()),
        );

        await handler.dispose();
      });

      test(
        'SEC-03: allows connection without token when requireSessionToken is false',
        () async {
          const config = WebSocketConfig(
            url: 'wss://example.com/websocket',
            database: 'test_db',
            userId: 1,
            sessionToken: null,
            requireSessionToken: false,
          );
          final handler = OdooWebSocketHandler(config);

          // Handler created successfully without token
          expect(handler.currentState, WebSocketState.disconnected);
          // validateSessionToken doesn't throw when disabled
          expect(() => config.validateSessionToken(), returnsNormally);

          await handler.dispose();
        },
      );

      test(
        'SEC-03: validates both URL and token in validateSecurity',
        () async {
          const config = WebSocketConfig(
            url: 'wss://example.com/websocket',
            database: 'test_db',
            userId: 1,
            sessionToken: 'valid-token',
            requireSessionToken: true,
            allowInsecure: false,
          );

          // Both validations pass
          expect(() => config.validateSecurity(), returnsNormally);
        },
      );
    });

    group('subscribe validation', () {
      test('subscribe returns early when not connected', () async {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          allowedModels: {'res.partner'},
        );
        final handler = OdooWebSocketHandler(config);

        // Not connected, so subscribe does nothing (no exception from validation)
        // This is the expected behavior - subscribe returns early if not connected
        expect(() => handler.subscribe(['product.product']), returnsNormally);

        await handler.dispose();
      });

      test('config validates models against whitelist', () {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
          allowedModels: {'res.partner'},
        );

        // Direct config validation works
        expect(
          () => config.validateModels(['product.product']),
          throwsA(isA<WebSocketSecurityException>()),
        );
      });
    });

    group('dispose', () {
      test('can be disposed safely', () async {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );
        final handler = OdooWebSocketHandler(config);

        expect(handler.isDisposed, false);

        await handler.dispose();

        expect(handler.isDisposed, true);
      });

      test('double dispose is safe', () async {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );
        final handler = OdooWebSocketHandler(config);

        await handler.dispose();
        // Second dispose should not throw
        await expectLater(handler.dispose(), completes);
      });

      test('isDisposed reflects disposal state', () async {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );
        final handler = OdooWebSocketHandler(config);

        expect(handler.isDisposed, false);
        await handler.dispose();
        expect(handler.isDisposed, true);
      });
    });

    group('streams', () {
      test('state stream emits initial disconnected state', () async {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );
        final handler = OdooWebSocketHandler(config);

        // BehaviorSubject emits current value immediately
        // Take first value synchronously
        final firstState = await handler.state.first;
        expect(firstState, WebSocketState.disconnected);

        await handler.dispose();
      });

      test('provides recordEvents stream', () async {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );
        final handler = OdooWebSocketHandler(config);

        expect(handler.recordEvents, isA<Stream>());

        await handler.dispose();
      });

      test('provides connectionEvents stream', () async {
        const config = WebSocketConfig(
          url: 'wss://example.com/websocket',
          database: 'test_db',
          userId: 1,
        );
        final handler = OdooWebSocketHandler(config);

        expect(handler.connectionEvents, isA<Stream>());

        await handler.dispose();
      });
    });
  });

  group('RecordOperation', () {
    test('has all expected values', () {
      expect(
        RecordOperation.values,
        containsAll([
          RecordOperation.create,
          RecordOperation.write,
          RecordOperation.unlink,
        ]),
      );
    });
  });

  group('ModelRecordEvent', () {
    test('creates event with required parameters', () {
      final timestamp = DateTime.now();
      final event = ModelRecordEvent(
        model: 'res.partner',
        recordId: 42,
        operation: RecordOperation.create,
        timestamp: timestamp,
      );

      expect(event.model, 'res.partner');
      expect(event.recordId, 42);
      expect(event.operation, RecordOperation.create);
      expect(event.timestamp, timestamp);
      expect(event.data, null);
    });

    test('includes optional data', () {
      final event = ModelRecordEvent(
        model: 'res.partner',
        recordId: 42,
        operation: RecordOperation.write,
        timestamp: DateTime.now(),
        data: {'name': 'Updated Name', 'email': 'test@example.com'},
      );

      expect(event.data, isNotNull);
      expect(event.data!['name'], 'Updated Name');
      expect(event.data!['email'], 'test@example.com');
    });

    test('supports all operation types', () {
      for (final op in RecordOperation.values) {
        final event = ModelRecordEvent(
          model: 'res.partner',
          recordId: 1,
          operation: op,
          timestamp: DateTime.now(),
        );
        expect(event.operation, op);
      }
    });
  });
}
