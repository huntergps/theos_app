import 'package:odoo_sdk/src/services/logger_service.dart';
import 'package:odoo_sdk/src/api/odoo_exception.dart';
import 'package:odoo_sdk/src/session/data_session.dart';
import 'package:odoo_sdk/src/api/interceptors/log_sanitizer_interceptor.dart';
import 'package:odoo_sdk/src/utils/security_utils.dart';
import 'package:test/test.dart';

void main() {
  group('SEC-03: AppLogger log sanitization', () {
    late AppLogger testLogger;
    late List<String> logOutput;

    setUp(() {
      testLogger = AppLogger();
      testLogger.minLevel = LogLevel.debug;
      // Reset sanitization to enabled (default) since AppLogger is a singleton
      testLogger.setSanitization(true);
      logOutput = <String>[];
      testLogger.logOutput = (message) => logOutput.add(message.toString());
    });

    test('masks emails in log messages when sanitization is enabled', () {
      testLogger.setSanitization(true);
      testLogger.i('[Auth]', 'User john@example.com logged in');

      expect(logOutput.length, 1);
      expect(logOutput.first, isNot(contains('john@example.com')));
      expect(logOutput.first, contains('[REDACTED]'));
      expect(logOutput.first, contains('[Auth]'));
    });

    test('masks API keys in log messages when sanitization is enabled', () {
      testLogger.setSanitization(true);
      testLogger.d('[Config]', 'api_key=sk_test_abcdef1234567890');

      expect(logOutput.length, 1);
      expect(logOutput.first, isNot(contains('sk_test_abcdef1234567890')));
      expect(logOutput.first, contains('[REDACTED]'));
    });

    test('masks passwords in log messages when sanitization is enabled', () {
      testLogger.setSanitization(true);
      testLogger.w('[Security]', 'password=mysecretpassword detected');

      expect(logOutput.length, 1);
      expect(logOutput.first, isNot(contains('mysecretpassword')));
      expect(logOutput.first, contains('[REDACTED]'));
    });

    test('passes messages through unchanged when sanitization is disabled', () {
      testLogger.setSanitization(false);
      testLogger.i('[Test]', 'User john@example.com logged in');

      expect(logOutput.length, 1);
      expect(logOutput.first, contains('john@example.com'));
    });

    test('sanitizes error objects when sanitization is enabled', () {
      testLogger.setSanitization(true);
      testLogger.e(
        '[Auth]',
        'Login failed',
        Exception('Invalid credentials for user@test.com'),
      );

      // First line is the message, second line is the error
      expect(logOutput.length, greaterThanOrEqualTo(2));
      final errorLine = logOutput[1];
      expect(errorLine, isNot(contains('user@test.com')));
      expect(errorLine, contains('[REDACTED]'));
    });

    test('sanitizes stack traces when sanitization is enabled', () {
      testLogger.setSanitization(true);
      final trace = StackTrace.fromString(
        '#0 main (file:///Users/johndoe/projects/app/lib/main.dart:10:3)',
      );
      testLogger.e('[Error]', 'Something failed', null, trace);

      // First line is the message, second is the stack
      expect(logOutput.length, greaterThanOrEqualTo(2));
      final stackLine = logOutput[1];
      expect(stackLine, isNot(contains('johndoe')));
      expect(stackLine, contains('[PATH]'));
    });

    test('does not sanitize stack traces when sanitization is disabled', () {
      testLogger.setSanitization(false);
      final trace = StackTrace.fromString(
        '#0 main (file:///Users/johndoe/projects/app/lib/main.dart:10:3)',
      );
      testLogger.e('[Error]', 'Something failed', null, trace);

      expect(logOutput.length, greaterThanOrEqualTo(2));
      final stackLine = logOutput[1];
      expect(stackLine, contains('johndoe'));
    });

    test('setSanitization() toggle works', () {
      // Start enabled (default)
      expect(testLogger.isSanitizationEnabled, isTrue);

      // Disable
      testLogger.setSanitization(false);
      expect(testLogger.isSanitizationEnabled, isFalse);

      // Re-enable
      testLogger.setSanitization(true);
      expect(testLogger.isSanitizationEnabled, isTrue);
    });

    test('sanitization is enabled after reset', () {
      // AppLogger is a singleton, so we verify the default-like state
      // after setUp resets it to true
      expect(testLogger.isSanitizationEnabled, isTrue);
    });
  });

  group('SEC-03: OdooException.toString() sanitization', () {
    test('masks sensitive data keys in the data map', () {
      const exception = OdooException(
        message: 'Server error',
        statusCode: 500,
        data: {
          'apiKey': 'sk_test_4eC39HqLyjWDarjtT1zdp7dc',
          'model': 'sale.order',
        },
      );

      final str = exception.toString();
      expect(str, isNot(contains('sk_test_4eC39HqLyjWDarjtT1zdp7dc')));
      expect(str, contains('model: sale.order'));
      expect(str, contains('*'));
    });

    test('masks password in the data map', () {
      const exception = OdooException(
        message: 'Auth failed',
        statusCode: 401,
        data: {'password': 'supersecret', 'username': 'admin'},
      );

      final str = exception.toString();
      expect(str, isNot(contains('supersecret')));
      expect(str, contains('username: admin'));
    });

    test('masks token in the data map', () {
      const exception = OdooException(
        message: 'Token issue',
        data: {'session_token': 'abc123def456ghi789', 'status': 'expired'},
      );

      final str = exception.toString();
      expect(str, isNot(contains('abc123def456ghi789')));
      expect(str, contains('status: expired'));
    });

    test('toString works without data', () {
      const exception = OdooException(message: 'Simple error');
      final str = exception.toString();
      expect(str, 'OdooException: Simple error');
    });
  });

  group('SEC-03: DataSession.toString() masking', () {
    test('shows masked API key in toString', () {
      const session = DataSession(
        id: 'pos-1',
        label: 'POS Store',
        baseUrl: 'https://odoo.example.com',
        database: 'production',
        apiKey: 'key_abc123xyz789',
      );

      final str = session.toString();
      expect(str, contains('pos-1'));
      expect(str, contains('POS Store'));
      expect(str, contains('odoo.example.com'));
      expect(str, contains('production'));
      // API key should be masked: shows first 2 and last 2
      expect(str, contains('key:'));
      expect(str, isNot(contains('key_abc123xyz789')));
      expect(str, contains('ke************89'));
    });

    test('masks short API key completely', () {
      const session = DataSession(
        id: 'test',
        label: 'Test',
        baseUrl: 'https://odoo.example.com',
        database: 'db',
        apiKey: 'abc',
      );

      final str = session.toString();
      expect(str, isNot(contains('apiKey')));
      // Short key (3 chars) is fully masked
      expect(str, contains('***'));
    });
  });

  group('SEC-03: LogSanitizerInterceptor.sanitizeHeaders()', () {
    test('masks Authorization header', () {
      final headers = {
        'Authorization': 'Bearer sk_test_4eC39HqLyjWDarjtT1zdp7dc',
        'Content-Type': 'application/json',
      };

      final sanitized = LogSanitizerInterceptor.sanitizeHeaders(headers);

      expect(
        sanitized['Authorization'],
        isNot(equals('Bearer sk_test_4eC39HqLyjWDarjtT1zdp7dc')),
      );
      expect(sanitized['Authorization'], contains('*'));
      expect(sanitized['Content-Type'], 'application/json');
    });

    test('masks Cookie header', () {
      final headers = {'Cookie': 'session_id=abc123def456', 'Accept': '*/*'};

      final sanitized = LogSanitizerInterceptor.sanitizeHeaders(headers);

      expect(sanitized['Cookie'], isNot(contains('abc123def456')));
      expect(sanitized['Cookie'], contains('*'));
      expect(sanitized['Accept'], '*/*');
    });

    test('masks Set-Cookie header', () {
      final headers = {'Set-Cookie': 'session_id=xyz789; Path=/; HttpOnly'};

      final sanitized = LogSanitizerInterceptor.sanitizeHeaders(headers);

      expect(sanitized['Set-Cookie'], isNot(contains('xyz789')));
      expect(sanitized['Set-Cookie'], contains('*'));
    });

    test('masks X-API-Key header', () {
      final headers = {'X-API-Key': 'my-secret-api-key-12345'};

      final sanitized = LogSanitizerInterceptor.sanitizeHeaders(headers);

      expect(
        sanitized['X-API-Key'],
        isNot(contains('my-secret-api-key-12345')),
      );
      expect(sanitized['X-API-Key'], contains('*'));
    });

    test('masks Proxy-Authorization header', () {
      final headers = {'Proxy-Authorization': 'Basic dXNlcjpwYXNz'};

      final sanitized = LogSanitizerInterceptor.sanitizeHeaders(headers);

      expect(sanitized['Proxy-Authorization'], isNot(contains('dXNlcjpwYXNz')));
      expect(sanitized['Proxy-Authorization'], contains('*'));
    });

    test('preserves non-sensitive headers', () {
      final headers = {
        'Content-Type': 'application/json',
        'Accept-Language': 'en-US',
        'User-Agent': 'OdooSDK/1.0',
        'X-Request-Id': 'req-123',
      };

      final sanitized = LogSanitizerInterceptor.sanitizeHeaders(headers);

      expect(sanitized['Content-Type'], 'application/json');
      expect(sanitized['Accept-Language'], 'en-US');
      expect(sanitized['User-Agent'], 'OdooSDK/1.0');
      expect(sanitized['X-Request-Id'], 'req-123');
    });

    test('handles case-insensitive header names', () {
      final headers = {
        'authorization': 'Bearer token123456',
        'COOKIE': 'session=abc',
      };

      final sanitized = LogSanitizerInterceptor.sanitizeHeaders(headers);

      expect(sanitized['authorization'], contains('*'));
      // COOKIE is case-insensitive match
      expect(sanitized['COOKIE'], contains('*'));
    });

    test('handles empty headers map', () {
      final sanitized = LogSanitizerInterceptor.sanitizeHeaders({});
      expect(sanitized, isEmpty);
    });

    test('does not modify non-string header values', () {
      final headers = <String, dynamic>{
        'Authorization': 42, // Non-string value (unusual but possible)
        'Content-Length': '1024',
      };

      final sanitized = LogSanitizerInterceptor.sanitizeHeaders(headers);

      // Non-string value should pass through
      expect(sanitized['Authorization'], 42);
      expect(sanitized['Content-Length'], '1024');
    });
  });

  group('SEC-03: LogSanitizerInterceptor.sanitizeUrl()', () {
    test('masks api_key query parameter', () {
      const url = 'https://api.example.com/data?api_key=secret123&page=1';
      final sanitized = LogSanitizerInterceptor.sanitizeUrl(url);

      expect(sanitized, isNot(contains('secret123')));
      expect(sanitized, contains('api_key='));
      expect(sanitized, contains('page=1'));
    });

    test('masks token query parameter', () {
      const url = 'https://api.example.com/data?token=mytoken789&format=json';
      final sanitized = LogSanitizerInterceptor.sanitizeUrl(url);

      expect(sanitized, isNot(contains('mytoken789')));
      expect(sanitized, contains('format=json'));
    });

    test('masks secret query parameter', () {
      const url = 'https://api.example.com/callback?client_secret=abcdef12345';
      final sanitized = LogSanitizerInterceptor.sanitizeUrl(url);

      expect(sanitized, isNot(contains('abcdef12345')));
    });

    test('masks password query parameter', () {
      const url = 'https://api.example.com/login?password=pass123&user=admin';
      final sanitized = LogSanitizerInterceptor.sanitizeUrl(url);

      expect(sanitized, isNot(contains('pass123')));
      expect(sanitized, contains('user=admin'));
    });

    test('masks auth query parameter', () {
      const url = 'https://api.example.com/data?auth=bearer_xyz';
      final sanitized = LogSanitizerInterceptor.sanitizeUrl(url);

      expect(sanitized, isNot(contains('bearer_xyz')));
    });

    test('preserves URLs without query parameters', () {
      const url = 'https://api.example.com/data/items';
      final sanitized = LogSanitizerInterceptor.sanitizeUrl(url);

      expect(sanitized, url);
    });

    test('preserves non-sensitive query parameters', () {
      const url = 'https://api.example.com/data?page=1&limit=50&sort=name';
      final sanitized = LogSanitizerInterceptor.sanitizeUrl(url);

      expect(sanitized, contains('page=1'));
      expect(sanitized, contains('limit=50'));
      expect(sanitized, contains('sort=name'));
    });

    test('handles malformed URL gracefully', () {
      const url = 'not a valid url :::';
      final sanitized = LogSanitizerInterceptor.sanitizeUrl(url);

      // Should return original URL on parse failure
      expect(sanitized, url);
    });
  });

  group('SEC-03: ErrorSanitizer integration with real PII patterns', () {
    test('redacts email in error message', () {
      const msg = 'Authentication failed for user admin@company.org';
      final result = ErrorSanitizer.sanitize(msg);
      expect(result, isNot(contains('admin@company.org')));
      expect(result, contains('[REDACTED]'));
    });

    test('redacts API key pattern', () {
      const msg = 'api_key=abcdef1234567890abcdef1234567890 expired';
      final result = ErrorSanitizer.sanitize(msg);
      expect(result, isNot(contains('abcdef1234567890abcdef1234567890')));
      expect(result, contains('[REDACTED]'));
    });

    test('redacts IP address in connection error', () {
      const msg = 'Cannot connect to server at 192.168.1.100:8069';
      final result = ErrorSanitizer.sanitize(msg);
      expect(result, isNot(contains('192.168.1.100')));
      expect(result, contains('[REDACTED]'));
    });

    test('redacts password pattern in config dump', () {
      const msg = 'Config: password=super_secret_123 database=mydb';
      final result = ErrorSanitizer.sanitize(msg);
      expect(result, isNot(contains('super_secret_123')));
      expect(result, contains('[REDACTED]'));
    });

    test('redacts token in response error', () {
      const msg = 'token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9 is invalid';
      final result = ErrorSanitizer.sanitize(msg);
      expect(result, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      expect(result, contains('[REDACTED]'));
    });

    test('preserves normal error messages without PII', () {
      const msg = 'Record sale.order(42) not found in local database';
      final result = ErrorSanitizer.sanitize(msg);
      expect(result, msg);
    });

    test('handles multiple PII types in single message', () {
      const msg = 'User admin@corp.com from 10.0.0.1 used password=bad123';
      final result = ErrorSanitizer.sanitize(msg);
      expect(result, isNot(contains('admin@corp.com')));
      expect(result, isNot(contains('10.0.0.1')));
      expect(result, isNot(contains('bad123')));
    });
  });
}
