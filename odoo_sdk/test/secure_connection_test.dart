import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('SEC-04: Secure Connection Enforcement', () {
    group('OdooClientConfig', () {
      test('allowInsecure defaults to false', () {
        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
        );

        expect(config.allowInsecure, false);
      });

      test('isSecure returns true for https URL', () {
        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
        );

        expect(config.isSecure, true);
      });

      test('isSecure returns false for http URL', () {
        const config = OdooClientConfig(
          baseUrl: 'http://example.com',
          apiKey: 'test-key',
          allowInsecure: true,
        );

        expect(config.isSecure, false);
      });

      test('validateSecureConnection passes for https URL', () {
        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
        );

        expect(() => config.validateSecureConnection(), returnsNormally);
      });

      test('validateSecureConnection throws for http URL when allowInsecure is false', () {
        const config = OdooClientConfig(
          baseUrl: 'http://example.com',
          apiKey: 'test-key',
          allowInsecure: false,
        );

        expect(
          () => config.validateSecureConnection(),
          throwsA(isA<InsecureConnectionException>()),
        );
      });

      test('validateSecureConnection passes for http URL when allowInsecure is true', () {
        const config = OdooClientConfig(
          baseUrl: 'http://localhost:8069',
          apiKey: 'test-key',
          allowInsecure: true,
        );

        expect(() => config.validateSecureConnection(), returnsNormally);
      });

      test('InsecureConnectionException contains URL and message', () {
        const config = OdooClientConfig(
          baseUrl: 'http://example.com',
          apiKey: 'test-key',
          allowInsecure: false,
        );

        expect(
          () => config.validateSecureConnection(),
          throwsA(isA<InsecureConnectionException>().having(
            (e) => e.url,
            'url',
            'http://example.com',
          ).having(
            (e) => e.message,
            'message',
            contains('Insecure HTTP connection'),
          )),
        );
      });

      test('validateSecureConnection throws for invalid scheme', () {
        const config = OdooClientConfig(
          baseUrl: 'ftp://example.com',
          apiKey: 'test-key',
          allowInsecure: false,
        );

        expect(
          () => config.validateSecureConnection(),
          throwsA(isA<InsecureConnectionException>().having(
            (e) => e.message,
            'message',
            contains('Invalid URL scheme'),
          )),
        );
      });

      test('copyWith preserves allowInsecure', () {
        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
          allowInsecure: true,
        );

        final copy = config.copyWith(baseUrl: 'https://other.com');

        expect(copy.allowInsecure, true);
      });

      test('copyWith can change allowInsecure', () {
        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
          allowInsecure: false,
        );

        final copy = config.copyWith(allowInsecure: true);

        expect(copy.allowInsecure, true);
      });

      test('toString includes secure status', () {
        const config = OdooClientConfig(
          baseUrl: 'https://example.com',
          apiKey: 'test-key',
          allowInsecure: false,
        );

        expect(config.toString(), contains('secure: true'));
      });

      test('toString shows insecure when allowInsecure is true', () {
        const config = OdooClientConfig(
          baseUrl: 'http://localhost',
          apiKey: 'test-key',
          allowInsecure: true,
        );

        expect(config.toString(), contains('secure: false'));
      });
    });

    group('OdooWebSocketConnectionInfo', () {
      test('allowInsecure defaults to false', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'https://example.com',
          database: 'test_db',
        );

        expect(info.allowInsecure, false);
      });

      test('isSecure returns true for https URL', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'https://example.com',
          database: 'test_db',
        );

        expect(info.isSecure, true);
      });

      test('isSecure returns false for http URL', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'http://example.com',
          database: 'test_db',
          allowInsecure: true,
        );

        expect(info.isSecure, false);
      });

      test('websocketUrl returns wss:// for https base URL', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'https://example.com',
          database: 'test_db',
        );

        expect(info.websocketUrl, startsWith('wss://'));
        expect(info.websocketUrl, contains('/websocket'));
      });

      test('websocketUrl returns ws:// for http base URL', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'http://localhost:8069',
          database: 'test_db',
          allowInsecure: true,
        );

        expect(info.websocketUrl, startsWith('ws://'));
        expect(info.websocketUrl, contains(':8069'));
        expect(info.websocketUrl, contains('/websocket'));
      });

      test('validateSecureConnection passes for https URL', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'https://example.com',
          database: 'test_db',
        );

        expect(() => info.validateSecureConnection(), returnsNormally);
      });

      test('validateSecureConnection throws for http URL when allowInsecure is false', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'http://example.com',
          database: 'test_db',
          allowInsecure: false,
        );

        expect(
          () => info.validateSecureConnection(),
          throwsA(isA<InsecureWebSocketException>()),
        );
      });

      test('validateSecureConnection passes for http URL when allowInsecure is true', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'http://localhost:8069',
          database: 'test_db',
          allowInsecure: true,
        );

        expect(() => info.validateSecureConnection(), returnsNormally);
      });

      test('InsecureWebSocketException contains URL and message', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'http://example.com',
          database: 'test_db',
          allowInsecure: false,
        );

        expect(
          () => info.validateSecureConnection(),
          throwsA(isA<InsecureWebSocketException>().having(
            (e) => e.url,
            'url',
            'http://example.com',
          ).having(
            (e) => e.message,
            'message',
            contains('Insecure WebSocket connection'),
          )),
        );
      });

      test('validateSecureConnection throws for invalid scheme', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'ftp://example.com',
          database: 'test_db',
          allowInsecure: false,
        );

        expect(
          () => info.validateSecureConnection(),
          throwsA(isA<InsecureWebSocketException>().having(
            (e) => e.message,
            'message',
            contains('Invalid URL scheme'),
          )),
        );
      });

      test('toString includes secure status', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'https://example.com',
          database: 'test_db',
          allowInsecure: false,
        );

        expect(info.toString(), contains('secure: true'));
      });

      test('toString shows insecure when allowInsecure is true', () {
        const info = OdooWebSocketConnectionInfo(
          baseUrl: 'http://localhost',
          database: 'test_db',
          allowInsecure: true,
        );

        expect(info.toString(), contains('secure: false'));
      });
    });

    group('InsecureConnectionException', () {
      test('stores message and url', () {
        const exception = InsecureConnectionException(
          'Test message',
          url: 'http://test.com',
        );

        expect(exception.message, 'Test message');
        expect(exception.url, 'http://test.com');
      });

      test('toString includes class name, message, and url', () {
        const exception = InsecureConnectionException(
          'Connection error',
          url: 'http://insecure.com',
        );

        final str = exception.toString();
        expect(str, contains('InsecureConnectionException'));
        expect(str, contains('Connection error'));
        expect(str, contains('http://insecure.com'));
      });
    });

    group('InsecureWebSocketException', () {
      test('stores message and url', () {
        const exception = InsecureWebSocketException(
          'WebSocket error',
          url: 'http://test.com',
        );

        expect(exception.message, 'WebSocket error');
        expect(exception.url, 'http://test.com');
      });

      test('toString includes class name, message, and url', () {
        const exception = InsecureWebSocketException(
          'WebSocket error',
          url: 'http://insecure.com',
        );

        final str = exception.toString();
        expect(str, contains('InsecureWebSocketException'));
        expect(str, contains('WebSocket error'));
        expect(str, contains('http://insecure.com'));
      });
    });
  });
}
