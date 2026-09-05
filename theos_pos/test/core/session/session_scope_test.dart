import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/session/session_scope.dart';

void main() {
  group('SessionScope', () {
    test('normalizes equivalent server URLs', () {
      final first = SessionScope(
        serverUrl: ' HTTPS://ERP.EXAMPLE.COM:443/odoo/ ',
        database: ' main ',
        userId: 7,
      );
      final second = SessionScope(
        serverUrl: 'https://erp.example.com/odoo',
        database: 'main',
        userId: 7,
      );

      expect(first, second);
      expect(first.key, second.key);
      expect(first.storageIdentifier, second.storageIdentifier);
      expect(first.driftDatabaseName, second.driftDatabaseName);
    });

    test('isolates users on the same server and database', () {
      final first = SessionScope(
        serverUrl: 'https://erp.example.com',
        database: 'main',
        userId: 7,
      );
      final second = SessionScope(
        serverUrl: 'https://erp.example.com',
        database: 'main',
        userId: 8,
      );

      expect(first.key, isNot(second.key));
      expect(first.storageIdentifier, isNot(second.storageIdentifier));
      expect(first.driftDatabaseName, isNot(second.driftDatabaseName));
    });

    test('isolates databases and non-standard ports', () {
      final first = SessionScope(
        serverUrl: 'http://localhost:8069',
        database: 'company_a',
        userId: 7,
      );
      final second = SessionScope(
        serverUrl: 'http://localhost:8070',
        database: 'company_b',
        userId: 7,
      );

      expect(first.storageIdentifier, contains('localhost_8069_company_a_u7'));
      expect(second.storageIdentifier, contains('localhost_8070_company_b_u7'));
      expect(first.storageIdentifier, isNot(second.storageIdentifier));
    });

    test('storage identifier is filesystem-safe and bounded', () {
      final scope = SessionScope(
        serverUrl: 'https://very-long-host-name.example.com/custom/path',
        database: 'A database with spaces and / punctuation' * 4,
        userId: 99,
      );

      expect(scope.storageIdentifier, matches(RegExp(r'^[a-z0-9_]+$')));
      expect(scope.storageIdentifier.length, lessThanOrEqualTo(89));
      expect(
        scope.driftDatabaseName,
        matches(RegExp(r'^theos_pos_[a-z0-9_]+$')),
      );
      expect(scope.driftDatabaseName.length, lessThanOrEqualTo(99));
    });

    test('drift database name is derived only from non-secret scope data', () {
      const apiKey = 'api-key-that-must-never-appear';
      const sessionId = 'session-that-must-never-appear';
      final scope = SessionScope(
        serverUrl: 'https://erp.example.com',
        database: 'main',
        userId: 7,
      );

      expect(scope.driftDatabaseName, 'theos_pos_${scope.storageIdentifier}');
      expect(scope.driftDatabaseName, isNot(contains(apiKey)));
      expect(scope.driftDatabaseName, isNot(contains(sessionId)));
    });

    test('never includes credentials and rejects secret-bearing URLs', () {
      expect(
        () => SessionScope(
          serverUrl: ['https://user', 'password@erp.example.com'].join(':'),
          database: 'main',
          userId: 7,
        ),
        throwsArgumentError,
      );
      expect(
        () => SessionScope(
          serverUrl: 'https://erp.example.com?api_key=secret',
          database: 'main',
          userId: 7,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid identity components', () {
      expect(
        () => SessionScope(
          serverUrl: 'erp.example.com',
          database: 'main',
          userId: 7,
        ),
        throwsArgumentError,
      );
      expect(
        () => SessionScope(
          serverUrl: 'https://erp.example.com',
          database: ' ',
          userId: 7,
        ),
        throwsArgumentError,
      );
      expect(
        () => SessionScope(
          serverUrl: 'https://erp.example.com',
          database: 'main',
          userId: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
