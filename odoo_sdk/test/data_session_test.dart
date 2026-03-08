import 'package:odoo_sdk/src/session/data_session.dart';
import 'package:test/test.dart';

void main() {
  group('DataSession', () {
    DataSession validSession() => const DataSession(
          id: 'test-session',
          label: 'Test Session',
          baseUrl: 'https://odoo.example.com',
          database: 'testdb',
          apiKey: 'key_abc123',
        );

    test('creates with required fields', () {
      final s = validSession();
      expect(s.id, 'test-session');
      expect(s.label, 'Test Session');
      expect(s.baseUrl, 'https://odoo.example.com');
      expect(s.database, 'testdb');
      expect(s.apiKey, 'key_abc123');
      expect(s.defaultLanguage, 'en_US');
      expect(s.allowInsecure, false);
      expect(s.metadata, isEmpty);
    });

    group('validate', () {
      test('returns empty list for valid session', () {
        expect(validSession().validate(), isEmpty);
      });

      test('detects empty id', () {
        final errors =
            validSession().copyWith(id: '').validate();
        expect(errors, contains(contains('id')));
      });

      test('detects empty baseUrl', () {
        final errors =
            validSession().copyWith(baseUrl: '').validate();
        expect(errors, contains(contains('baseUrl')));
      });

      test('detects invalid baseUrl scheme', () {
        final errors =
            validSession().copyWith(baseUrl: 'ftp://bad').validate();
        expect(errors, contains(contains('http')));
      });

      test('detects insecure http without allowInsecure', () {
        final errors = validSession()
            .copyWith(baseUrl: 'http://local', allowInsecure: false)
            .validate();
        expect(errors, contains(contains('Insecure')));
      });

      test('allows http with allowInsecure', () {
        final errors = validSession()
            .copyWith(baseUrl: 'http://local', allowInsecure: true)
            .validate();
        expect(errors, isEmpty);
      });

      test('detects empty database', () {
        final errors =
            validSession().copyWith(database: '').validate();
        expect(errors, contains(contains('database')));
      });

      test('detects empty apiKey', () {
        final errors =
            validSession().copyWith(apiKey: '').validate();
        expect(errors, contains(contains('apiKey')));
      });

      test('reports multiple errors at once', () {
        const s = DataSession(
          id: '',
          label: '',
          baseUrl: '',
          database: '',
          apiKey: '',
        );
        expect(s.validate().length, greaterThanOrEqualTo(3));
      });
    });

    group('toClientConfig', () {
      test('maps fields correctly', () {
        final config = validSession().toClientConfig();
        expect(config.baseUrl, 'https://odoo.example.com');
        expect(config.apiKey, 'key_abc123');
        expect(config.database, 'testdb');
        expect(config.defaultLanguage, 'en_US');
        expect(config.allowInsecure, false);
      });

      test('maps custom language and insecure flag', () {
        final s = validSession().copyWith(
          defaultLanguage: 'es_EC',
          allowInsecure: true,
          baseUrl: 'http://local',
        );
        final config = s.toClientConfig();
        expect(config.defaultLanguage, 'es_EC');
        expect(config.allowInsecure, true);
      });
    });

    group('copyWith', () {
      test('copies with no changes produces equal session', () {
        final s = validSession();
        final copy = s.copyWith();
        expect(copy.id, s.id);
        expect(copy.label, s.label);
        expect(copy.baseUrl, s.baseUrl);
        expect(copy.database, s.database);
        expect(copy.apiKey, s.apiKey);
      });

      test('overrides specified fields', () {
        final copy = validSession().copyWith(
          id: 'new-id',
          label: 'New Label',
          metadata: {'key': 'value'},
        );
        expect(copy.id, 'new-id');
        expect(copy.label, 'New Label');
        expect(copy.metadata, {'key': 'value'});
        // unchanged
        expect(copy.baseUrl, 'https://odoo.example.com');
      });
    });

    group('equality', () {
      test('equal when same id', () {
        final a = validSession();
        final b = validSession().copyWith(label: 'Different');
        expect(a, equals(b));
      });

      test('not equal when different id', () {
        final a = validSession();
        final b = validSession().copyWith(id: 'other');
        expect(a, isNot(equals(b)));
      });
    });

    test('toString includes id, label, baseUrl/database', () {
      final s = validSession();
      final str = s.toString();
      expect(str, contains('test-session'));
      expect(str, contains('Test Session'));
      expect(str, contains('odoo.example.com'));
    });
  });
}
