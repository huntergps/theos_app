import 'package:odoo_sdk/src/utils/security_utils.dart';
import 'package:test/test.dart';

void main() {
  group('DomainValidator', () {
    group('validate - valid domains', () {
      test('accepts empty domain', () {
        expect(() => DomainValidator.validate([]), returnsNormally);
        expect(() => DomainValidator.validate(null), returnsNormally);
      });

      test('accepts simple equality clause', () {
        expect(
          () => DomainValidator.validate([
            ['name', '=', 'Test'],
          ]),
          returnsNormally,
        );
      });

      test('accepts multiple clauses', () {
        expect(
          () => DomainValidator.validate([
            ['name', 'ilike', 'test'],
            ['active', '=', true],
            ['id', '>', 0],
          ]),
          returnsNormally,
        );
      });

      test('accepts all valid operators', () {
        final validOperators = [
          '=',
          '!=',
          '>',
          '>=',
          '<',
          '<=',
          'like',
          'ilike',
          'not like',
          'not ilike',
          '=like',
          '=ilike',
          'in',
          'not in',
          'child_of',
          'parent_of',
          '=?',
        ];

        for (final op in validOperators) {
          expect(
            () => DomainValidator.validate([
              ['field', op, 'value'],
            ]),
            returnsNormally,
            reason: 'Operator "$op" should be valid',
          );
        }
      });

      test('accepts logical operators', () {
        expect(
          () => DomainValidator.validate([
            '|',
            ['name', '=', 'A'],
            ['name', '=', 'B'],
          ]),
          returnsNormally,
        );

        expect(
          () => DomainValidator.validate([
            '&',
            ['active', '=', true],
            ['state', '=', 'draft'],
          ]),
          returnsNormally,
        );

        expect(
          () => DomainValidator.validate([
            '!',
            ['active', '=', false],
          ]),
          returnsNormally,
        );
      });

      test('accepts dotted field names (related fields)', () {
        expect(
          () => DomainValidator.validate([
            ['partner_id.name', 'ilike', 'test'],
            ['product_id.categ_id.name', '=', 'Category'],
          ]),
          returnsNormally,
        );
      });

      test('accepts in operator with list values', () {
        expect(
          () => DomainValidator.validate([
            [
              'id',
              'in',
              [1, 2, 3, 4, 5],
            ],
          ]),
          returnsNormally,
        );

        expect(
          () => DomainValidator.validate([
            [
              'state',
              'in',
              ['draft', 'confirmed', 'done'],
            ],
          ]),
          returnsNormally,
        );
      });

      test('accepts numeric values', () {
        expect(
          () => DomainValidator.validate([
            ['quantity', '>', 10],
            ['price', '>=', 99.99],
            ['id', '=', 42],
          ]),
          returnsNormally,
        );
      });

      test('accepts boolean values', () {
        expect(
          () => DomainValidator.validate([
            ['active', '=', true],
            ['archived', '=', false],
          ]),
          returnsNormally,
        );
      });

      test('accepts null values', () {
        expect(
          () => DomainValidator.validate([
            ['parent_id', '=', null],
          ]),
          returnsNormally,
        );
      });
    });

    group('validate - invalid domains', () {
      test('rejects invalid logical operator', () {
        expect(
          () => DomainValidator.validate(['invalid_op']),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Invalid logical operator'),
            ),
          ),
        );
      });

      test('rejects non-list clause', () {
        expect(
          () => DomainValidator.validate([
            {'field': 'name', 'op': '=', 'value': 'test'},
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('must be a list'),
            ),
          ),
        );
      });

      test('rejects clause with wrong number of elements', () {
        expect(
          () => DomainValidator.validate([
            ['name', '='],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('must have 3 elements'),
            ),
          ),
        );

        expect(
          () => DomainValidator.validate([
            ['name', '=', 'value', 'extra'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('must have 3 elements'),
            ),
          ),
        );
      });

      test('rejects non-string field name', () {
        expect(
          () => DomainValidator.validate([
            [123, '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('must be a string'),
            ),
          ),
        );
      });

      test('rejects empty field name', () {
        expect(
          () => DomainValidator.validate([
            ['', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('cannot be empty'),
            ),
          ),
        );
      });

      test('rejects invalid operator', () {
        expect(
          () => DomainValidator.validate([
            ['name', 'INVALID', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Invalid operator'),
            ),
          ),
        );
      });

      test('rejects non-string operator', () {
        expect(
          () => DomainValidator.validate([
            ['name', 123, 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Operator must be a string'),
            ),
          ),
        );
      });

      test('rejects invalid field name format', () {
        expect(
          () => DomainValidator.validate([
            ['123invalid', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Invalid field name format'),
            ),
          ),
        );

        expect(
          () => DomainValidator.validate([
            ['field with spaces', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Invalid field name format'),
            ),
          ),
        );
      });
    });

    group('validate - SQL injection prevention', () {
      test('rejects SQL comment injection in field', () {
        expect(
          () => DomainValidator.validate([
            ['name; --', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Potential injection'),
            ),
          ),
        );
      });

      test('rejects DROP statement in field', () {
        expect(
          () => DomainValidator.validate([
            ['name; DROP TABLE users', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Potential injection'),
            ),
          ),
        );
      });

      test('rejects UNION SELECT in value', () {
        expect(
          () => DomainValidator.validate([
            ['name', '=', 'value UNION SELECT * FROM users'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Potential injection'),
            ),
          ),
        );
      });

      test('rejects OR injection in value', () {
        expect(
          () => DomainValidator.validate([
            ['name', '=', "' OR '1'='1"],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Potential injection'),
            ),
          ),
        );
      });

      test('rejects DELETE statement in value', () {
        expect(
          () => DomainValidator.validate([
            ['name', '=', 'test; DELETE FROM users'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Potential injection'),
            ),
          ),
        );
      });

      test('rejects injection in list values', () {
        expect(
          () => DomainValidator.validate([
            [
              'id',
              'in',
              ['safe', 'UNION SELECT password FROM users'],
            ],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('Potential injection'),
            ),
          ),
        );
      });
    });

    group('validate - sensitive field protection', () {
      test('rejects query on password field', () {
        expect(
          () => DomainValidator.validate([
            ['password', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('sensitive field'),
            ),
          ),
        );
      });

      test('rejects query on password_crypt field', () {
        expect(
          () => DomainValidator.validate([
            ['password_crypt', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('sensitive field'),
            ),
          ),
        );
      });

      test('rejects query on api_key field', () {
        expect(
          () => DomainValidator.validate([
            ['api_key', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('sensitive field'),
            ),
          ),
        );
      });

      test('rejects query on token field', () {
        expect(
          () => DomainValidator.validate([
            ['auth_token', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('sensitive field'),
            ),
          ),
        );
      });

      test('rejects query on secret field', () {
        expect(
          () => DomainValidator.validate([
            ['client_secret', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('sensitive field'),
            ),
          ),
        );
      });

      test('rejects query on credit_card field', () {
        expect(
          () => DomainValidator.validate([
            ['credit_card_number', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('sensitive field'),
            ),
          ),
        );
      });

      test('rejects query on ssn field', () {
        expect(
          () => DomainValidator.validate([
            ['user_ssn', '=', 'value'],
          ]),
          throwsA(
            isA<OdooDomainSecurityException>().having(
              (e) => e.message,
              'message',
              contains('sensitive field'),
            ),
          ),
        );
      });
    });

    group('isSafe', () {
      test('returns true for valid domain', () {
        expect(
          DomainValidator.isSafe([
            ['name', '=', 'test'],
          ]),
          true,
        );
      });

      test('returns true for empty domain', () {
        expect(DomainValidator.isSafe([]), true);
        expect(DomainValidator.isSafe(null), true);
      });

      test('returns false for invalid domain', () {
        expect(
          DomainValidator.isSafe([
            ['password', '=', 'value'],
          ]),
          false,
        );
      });

      test('returns false for injection attempt', () {
        expect(
          DomainValidator.isSafe([
            ['name', '=', 'UNION SELECT * FROM users'],
          ]),
          false,
        );
      });
    });
  });

  group('ErrorSanitizer', () {
    group('sanitize - email redaction', () {
      test('redacts simple email', () {
        final result = ErrorSanitizer.sanitize('User john@example.com failed');
        expect(result, 'User [REDACTED] failed');
      });

      test('redacts multiple emails', () {
        final result = ErrorSanitizer.sanitize(
          'From: admin@test.org To: user@company.com',
        );
        expect(result, 'From: [REDACTED] To: [REDACTED]');
      });

      test('redacts complex email domains', () {
        final result = ErrorSanitizer.sanitize(
          'Contact support@sub.domain.example.co.uk',
        );
        expect(result, 'Contact [REDACTED]');
      });
    });

    group('sanitize - phone number redaction', () {
      test('does NOT redact bare numbers like port 8069', () {
        final result = ErrorSanitizer.sanitize('localhost:8069');
        expect(result, 'localhost:8069');
      });

      test('does NOT redact US phone without country code', () {
        // Without international prefix, we intentionally skip to avoid
        // matching port numbers and other numeric identifiers
        final result = ErrorSanitizer.sanitize('Call 555-123-4567');
        expect(result, 'Call 555-123-4567');
      });

      test('redacts international phone format', () {
        final result = ErrorSanitizer.sanitize('Phone: +1-555-123-4567');
        expect(result, 'Phone: [REDACTED]');
      });

      test('redacts Ecuador phone format', () {
        final result = ErrorSanitizer.sanitize('Tel: +593 99 123 4567');
        expect(result, 'Tel: [REDACTED]');
      });

      test('does NOT redact phone without plus prefix', () {
        final result = ErrorSanitizer.sanitize('Number: 555 123 4567');
        expect(result, 'Number: 555 123 4567');
      });
    });

    group('sanitize - credit card redaction', () {
      test('redacts credit card with dashes', () {
        final result = ErrorSanitizer.sanitize(
          'Card: 1234-5678-9012-3456 invalid',
        );
        // Multiple patterns may match, verify no numbers remain
        expect(result, isNot(contains('1234')));
        expect(result, isNot(contains('5678')));
        expect(result, contains('[REDACTED]'));
      });

      test('redacts credit card with spaces', () {
        final result = ErrorSanitizer.sanitize(
          'Card: 1234 5678 9012 3456 declined',
        );
        // Phone pattern and CC pattern may overlap
        expect(result, isNot(contains('1234')));
        expect(result, contains('[REDACTED]'));
      });

      test('redacts credit card without separators', () {
        final result = ErrorSanitizer.sanitize(
          'CC: 1234567890123456 processing',
        );
        expect(result, 'CC: [REDACTED] processing');
      });
    });

    group('sanitize - SSN redaction', () {
      test('redacts SSN with dashes', () {
        final result = ErrorSanitizer.sanitize('SSN: 123-45-6789 on file');
        expect(result, 'SSN: [REDACTED] on file');
      });

      test('redacts SSN with spaces', () {
        final result = ErrorSanitizer.sanitize('ID: 123 45 6789');
        expect(result, 'ID: [REDACTED]');
      });
    });

    group('sanitize - API key/token redaction', () {
      test('redacts long alphanumeric tokens', () {
        final result = ErrorSanitizer.sanitize(
          'Key: abcdef1234567890abcdef1234567890 expired',
        );
        // Long alphanumeric strings (32+ chars) are redacted
        expect(result, isNot(contains('abcdef1234567890abcdef1234567890')));
        expect(result, contains('[REDACTED]'));
      });

      test('redacts UUID format', () {
        final result = ErrorSanitizer.sanitize(
          'ID: 550e8400-e29b-41d4-a716-446655440000 not found',
        );
        // UUID pattern is redacted
        expect(result, isNot(contains('550e8400-e29b-41d4-a716-446655440000')));
        expect(result, contains('[REDACTED]'));
      });
    });

    group('sanitize - IP address redaction', () {
      test('redacts IPv4 address', () {
        final result = ErrorSanitizer.sanitize(
          'Connection from 192.168.1.100 blocked',
        );
        expect(result, 'Connection from [REDACTED] blocked');
      });

      test('redacts multiple IPs', () {
        final result = ErrorSanitizer.sanitize('Route: 10.0.0.1 -> 172.16.0.1');
        expect(result, 'Route: [REDACTED] -> [REDACTED]');
      });
    });

    group('sanitize - password pattern redaction', () {
      test('redacts password= pattern', () {
        final result = ErrorSanitizer.sanitize('password=secretpass123');
        expect(result, '[REDACTED]');
      });

      test('redacts password: pattern', () {
        final result = ErrorSanitizer.sanitize('password: mysecret');
        expect(result, '[REDACTED]');
      });

      test('redacts pwd= pattern', () {
        final result = ErrorSanitizer.sanitize('pwd=pass123');
        expect(result, '[REDACTED]');
      });

      test('redacts secret= pattern', () {
        final result = ErrorSanitizer.sanitize('secret=abcdef123456 in config');
        expect(result, '[REDACTED] in config');
      });

      test('redacts client_secret with long token', () {
        // The secret= pattern matches from "secret=" onwards, combined with
        // long alphanumeric token detection
        final result = ErrorSanitizer.sanitize(
          'client_secret=abcdef12345678901234567890abcdef in config',
        );
        expect(result, isNot(contains('abcdef12345678901234567890abcdef')));
        expect(result, contains('[REDACTED]'));
      });

      test('redacts token= pattern', () {
        final result = ErrorSanitizer.sanitize('token=xyz789abc');
        expect(result, '[REDACTED]');
      });

      test('redacts api_key= pattern', () {
        final result = ErrorSanitizer.sanitize('api_key=key123456');
        expect(result, '[REDACTED]');
      });
    });

    group('sanitize - preserves safe content', () {
      test('preserves normal error messages', () {
        const message = 'Database connection failed: timeout after 30s';
        expect(ErrorSanitizer.sanitize(message), message);
      });

      test('preserves error codes', () {
        const message = 'Error code: E001 - Invalid operation';
        expect(ErrorSanitizer.sanitize(message), message);
      });

      test('preserves stack trace structure', () {
        const message = 'at Function.main (lib/main.dart:42:15)';
        expect(ErrorSanitizer.sanitize(message), message);
      });
    });

    group('sanitizeException', () {
      test('creates sanitized exception', () {
        final original = Exception('User john@example.com not found');
        final sanitized = ErrorSanitizer.sanitizeException(original);

        expect(sanitized, isA<SanitizedException>());
        expect(sanitized.toString(), contains('[REDACTED]'));
        expect(sanitized.toString(), isNot(contains('john@example.com')));
      });

      test('preserves original exception reference', () {
        final original = Exception('Error with 192.168.1.1');
        final sanitized =
            ErrorSanitizer.sanitizeException(original) as SanitizedException;

        expect(sanitized.original, original);
      });
    });

    group('sanitizeStackTrace', () {
      test('redacts /Users/ paths', () {
        final trace = StackTrace.fromString('''
#0      main (file:///Users/johndoe/projects/app/lib/main.dart:10:3)
#1      _startIsolate (dart:isolate-patch/isolate_patch.dart:123:45)
''');

        final sanitized = ErrorSanitizer.sanitizeStackTrace(trace);

        expect(sanitized, isNot(contains('johndoe')));
        expect(sanitized, contains('[PATH]'));
      });

      test('redacts /home/ paths', () {
        final trace = StackTrace.fromString('''
#0      main (file:///home/developer/app/lib/main.dart:10:3)
''');

        final sanitized = ErrorSanitizer.sanitizeStackTrace(trace);

        expect(sanitized, isNot(contains('developer')));
        expect(sanitized, contains('[PATH]'));
      });
    });
  });

  group('OdooDomainSecurityException', () {
    test('stores message', () {
      const exception = OdooDomainSecurityException('Test error');
      expect(exception.message, 'Test error');
    });

    test('stores optional field', () {
      const exception = OdooDomainSecurityException(
        'Test error',
        field: 'test_field',
      );
      expect(exception.field, 'test_field');
    });

    test('toString includes class name and message', () {
      const exception = OdooDomainSecurityException('Test error');
      expect(exception.toString(), 'OdooDomainSecurityException: Test error');
    });
  });

  group('OdooPiiExposureException', () {
    test('stores message', () {
      const exception = OdooPiiExposureException('PII exposed');
      expect(exception.message, 'PII exposed');
    });

    test('toString includes class name and message', () {
      const exception = OdooPiiExposureException('PII exposed');
      expect(exception.toString(), 'OdooPiiExposureException: PII exposed');
    });
  });

  group('SanitizedException', () {
    test('stores sanitized message', () {
      const exception = SanitizedException('Sanitized message');
      expect(exception.message, 'Sanitized message');
    });

    test('stores optional original exception', () {
      final original = Exception('Original');
      final sanitized = SanitizedException('Sanitized', original: original);
      expect(sanitized.original, original);
    });

    test('toString returns sanitized message', () {
      const exception = SanitizedException('Safe message');
      expect(exception.toString(), 'Safe message');
    });
  });

  group('CredentialMasker (SEC-01)', () {
    group('mask', () {
      test('returns empty string for empty input', () {
        expect(CredentialMasker.mask(''), '');
      });

      test('fully masks short strings (≤4 chars)', () {
        expect(CredentialMasker.mask('a'), '*');
        expect(CredentialMasker.mask('ab'), '**');
        expect(CredentialMasker.mask('abc'), '***');
        expect(CredentialMasker.mask('abcd'), '****');
      });

      test('shows first 2 and last 2 chars for longer strings', () {
        expect(CredentialMasker.mask('abcde'), 'ab*de');
        expect(CredentialMasker.mask('secret'), 'se**et');
        expect(CredentialMasker.mask('my-api-key-12345'), 'my************45');
      });

      test('masks real-world API key', () {
        const apiKey = 'sk_test_4eC39HqLyjWDarjtT1zdp7dc';
        final masked = CredentialMasker.mask(apiKey);

        expect(masked, startsWith('sk'));
        expect(masked, endsWith('dc'));
        expect(masked, contains('*'));
        expect(masked.length, apiKey.length);
        expect(masked, isNot(contains('test')));
        expect(masked, isNot(contains('4eC39')));
      });
    });

    group('maskNullable', () {
      test('returns "null" for null input', () {
        expect(CredentialMasker.maskNullable(null), 'null');
      });

      test('masks non-null values', () {
        expect(CredentialMasker.maskNullable('secret'), 'se**et');
      });
    });

    group('hide', () {
      test('returns empty string for empty input', () {
        expect(CredentialMasker.hide(''), '');
      });

      test('completely hides any non-empty string', () {
        expect(CredentialMasker.hide('a'), '********');
        expect(CredentialMasker.hide('password'), '********');
        expect(CredentialMasker.hide('very-long-password-12345'), '********');
      });
    });

    group('hideNullable', () {
      test('returns "null" for null input', () {
        expect(CredentialMasker.hideNullable(null), 'null');
      });

      test('completely hides non-null values', () {
        expect(CredentialMasker.hideNullable('password'), '********');
      });
    });

    group('maskWithPrefix', () {
      test('returns empty string for empty input', () {
        expect(CredentialMasker.maskWithPrefix(''), '');
      });

      test('fully masks strings shorter than prefix length', () {
        expect(CredentialMasker.maskWithPrefix('abc', prefixLength: 4), '***');
        expect(
          CredentialMasker.maskWithPrefix('abcd', prefixLength: 4),
          '****',
        );
      });

      test('shows prefix and masks rest', () {
        expect(
          CredentialMasker.maskWithPrefix('my-secret-key', prefixLength: 4),
          'my-s*********',
        );
      });

      test('uses default prefix length of 4', () {
        expect(CredentialMasker.maskWithPrefix('abcdefgh'), 'abcd****');
      });
    });

    group('maskUrl', () {
      test('returns URL unchanged if no credentials', () {
        const url = 'https://example.com/path';
        expect(CredentialMasker.maskUrl(url), url);
      });

      test('masks username in URL', () {
        const url = 'https://user@example.com/path';
        final masked = CredentialMasker.maskUrl(url);

        expect(masked, contains('****'));
        expect(masked, isNot(contains('user@')));
        expect(masked, contains('example.com/path'));
      });

      test('masks username and password in URL', () {
        const url = 'https://user:password@example.com/path';
        final masked = CredentialMasker.maskUrl(url);

        expect(masked, isNot(contains('user')));
        expect(masked, isNot(contains('password')));
        expect(masked, contains('****:****'));
        expect(masked, contains('example.com/path'));
      });
    });

    group('maskMap', () {
      test('masks apiKey field', () {
        final map = {'apiKey': 'secret-api-key', 'name': 'Test'};
        final result = CredentialMasker.maskMap(map);

        expect(result, contains('apiKey: se**********ey'));
        expect(result, contains('name: Test'));
      });

      test('masks password field', () {
        final map = {'password': 'mypassword', 'username': 'john'};
        final result = CredentialMasker.maskMap(map);

        expect(result, contains('password: my******rd'));
        expect(result, contains('username: john'));
      });

      test('masks session_token field', () {
        final map = {'session_token': 'abc123xyz789', 'id': 42};
        final result = CredentialMasker.maskMap(map);

        // 'abc123xyz789' is 12 chars, so 12-4=8 asterisks
        expect(result, contains('session_token: ab********89'));
        expect(result, contains('id: 42'));
      });

      test('masks nested maps', () {
        final map = {
          'config': {'apiKey': 'nested-secret', 'name': 'Nested'},
          'enabled': true,
        };
        final result = CredentialMasker.maskMap(map);

        expect(result, isNot(contains('nested-secret')));
        expect(result, contains('Nested'));
        expect(result, contains('enabled: true'));
      });

      test('respects additional sensitive keys', () {
        final map = {'customSecret': 'my-custom-secret', 'public': 'visible'};
        final result = CredentialMasker.maskMap(
          map,
          additionalSensitiveKeys: {'customSecret'},
        );

        expect(result, isNot(contains('my-custom-secret')));
        expect(result, contains('public: visible'));
      });

      test('handles empty map', () {
        expect(CredentialMasker.maskMap({}), '{}');
      });

      test('preserves non-sensitive fields', () {
        final map = {
          'name': 'John Doe',
          'email': 'john@example.com',
          'age': 30,
          'active': true,
        };
        final result = CredentialMasker.maskMap(map);

        expect(result, contains('name: John Doe'));
        expect(result, contains('email: john@example.com'));
        expect(result, contains('age: 30'));
        expect(result, contains('active: true'));
      });
    });
  });
}
