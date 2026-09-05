import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/e2e_configuration.dart';

void main() {
  test('production newerp is rejected even for explicit read-only runs', () {
    for (final server in [
      'https://newerp.tecnosmart.com.ec',
      'https://NEWERP.TECNOSMART.COM.EC./',
    ]) {
      final configuration = E2eConfiguration.resolve(
        processEnvironment: {
          'THEOS_E2E_ENABLED': 'true',
          'THEOS_E2E_READ_ONLY': 'true',
          'THEOS_E2E_API_KEY': 'configuration-test-value',
          'THEOS_E2E_SERVER_URL': server,
        },
      );
      expect(configuration.canRun, isFalse);
      expect(configuration.skipReason, contains('Production newerp'));
    }
  });

  test('live E2E stays opt-in and never renders the credential', () {
    final configuration = E2eConfiguration.resolve(
      processEnvironment: const {'THEOS_E2E_API_KEY': 'redaction-test-value'},
    );

    expect(configuration.canRun, isFalse);
    expect(configuration.skipReason, contains('THEOS_E2E_ENABLED'));
    expect(configuration.toString(), isNot(contains('redaction-test-value')));
    expect(configuration.toString(), contains('[REDACTED]'));
  });

  test('native debug run requires the explicit read-only gate', () {
    final configuration = E2eConfiguration.resolve(
      processEnvironment: const {
        'THEOS_E2E_ENABLED': 'true',
        'THEOS_E2E_API_KEY': 'configuration-test-value',
      },
    );

    expect(configuration.canRun, isFalse);
    expect(configuration.skipReason, contains('THEOS_E2E_READ_ONLY'));
  });

  test('native environment takes precedence and enables HTTPS run', () {
    final configuration = E2eConfiguration.resolve(
      dartDefines: const {
        'THEOS_E2E_ENABLED': 'false',
        'THEOS_E2E_READ_ONLY': 'false',
        'THEOS_E2E_API_KEY': 'define-placeholder',
      },
      processEnvironment: const {
        'THEOS_E2E_ENABLED': 'true',
        'THEOS_E2E_READ_ONLY': 'true',
        'THEOS_E2E_API_KEY': 'environment-placeholder',
      },
    );

    expect(configuration.canRun, isTrue);
    expect(configuration.apiKey, 'environment-placeholder');
    expect(configuration.serverUrl, 'https://erp2.tecnosmart.com.ec');
  });

  test('credentialed Web and release journeys are rejected', () {
    const values = {
      'THEOS_E2E_ENABLED': 'true',
      'THEOS_E2E_READ_ONLY': 'true',
      'THEOS_E2E_API_KEY': 'configuration-test-value',
    };

    expect(
      E2eConfiguration.resolve(processEnvironment: values, isWeb: true).canRun,
      isFalse,
    );
    expect(
      E2eConfiguration.resolve(
        processEnvironment: values,
        isRelease: true,
      ).canRun,
      isFalse,
    );
  });

  test('HTTP is accepted only for loopback targets', () {
    const base = {
      'THEOS_E2E_ENABLED': 'true',
      'THEOS_E2E_READ_ONLY': 'true',
      'THEOS_E2E_API_KEY': 'configuration-test-value',
    };

    expect(
      E2eConfiguration.resolve(
        processEnvironment: {
          ...base,
          'THEOS_E2E_SERVER_URL': 'http://127.0.0.1:8069',
        },
      ).canRun,
      isTrue,
    );
    expect(
      E2eConfiguration.resolve(
        processEnvironment: {
          ...base,
          'THEOS_E2E_SERVER_URL': 'http://erp.example.com',
        },
      ).canRun,
      isFalse,
    );
  });

  test('valid expected UID is parsed without exposing credentials', () {
    final configuration = E2eConfiguration.resolve(
      processEnvironment: const {
        'THEOS_E2E_ENABLED': 'true',
        'THEOS_E2E_READ_ONLY': 'true',
        'THEOS_E2E_API_KEY': 'configuration-test-value',
        'THEOS_E2E_EXPECTED_UID': '43',
      },
    );

    expect(configuration.canRun, isTrue);
    expect(configuration.expectedUserId, 43);
    expect(
      configuration.toString(),
      isNot(contains('configuration-test-value')),
    );
  });

  test('invalid expected UID rejects the run', () {
    final configuration = E2eConfiguration.resolve(
      processEnvironment: const {
        'THEOS_E2E_ENABLED': 'true',
        'THEOS_E2E_READ_ONLY': 'true',
        'THEOS_E2E_API_KEY': 'configuration-test-value',
        'THEOS_E2E_EXPECTED_UID': 'not-a-uid',
      },
    );

    expect(configuration.canRun, isFalse);
    expect(configuration.expectedUserId, isNull);
    expect(configuration.skipReason, contains('THEOS_E2E_EXPECTED_UID'));
  });

  test(
    'business journey accepts only the explicit write-enabled ERP2 target',
    () {
      final configuration = E2eConfiguration.resolve(
        processEnvironment: const {
          'THEOS_E2E_ENABLED': 'true',
          'THEOS_E2E_READ_ONLY': 'false',
          'THEOS_E2E_ALLOW_WRITES': 'true',
          'THEOS_E2E_API_KEY': 'configuration-test-value',
          'THEOS_E2E_EXPECTED_UID': '43',
        },
        businessJourney: true,
      );

      expect(configuration.canRun, isTrue);
      expect(configuration.allowWrites, isTrue);
      expect(configuration.serverUrl, 'https://erp2.tecnosmart.com.ec');
      expect(configuration.database, 'erp2_tecnosmart_com_ec');
    },
  );

  test('business journey fails closed for unsafe target or missing gates', () {
    const base = {
      'THEOS_E2E_ENABLED': 'true',
      'THEOS_E2E_READ_ONLY': 'false',
      'THEOS_E2E_ALLOW_WRITES': 'true',
      'THEOS_E2E_API_KEY': 'configuration-test-value',
      'THEOS_E2E_EXPECTED_UID': '43',
    };
    for (final entry in <Map<String, String>>[
      {...base, 'THEOS_E2E_SERVER_URL': 'https://newerp.tecnosmart.com.ec'},
      {...base, 'THEOS_E2E_SERVER_URL': 'https://epr2.tecnosmart.com.ec'},
      {...base, 'THEOS_E2E_DATABASE': 'another_database'},
      {...base, 'THEOS_E2E_READ_ONLY': 'true'},
      {...base, 'THEOS_E2E_ALLOW_WRITES': 'false'},
      {...base}..remove('THEOS_E2E_EXPECTED_UID'),
    ]) {
      final configuration = E2eConfiguration.resolve(
        processEnvironment: entry,
        businessJourney: true,
      );
      expect(configuration.canRun, isFalse, reason: '$entry');
      expect(configuration.skipReason, isNotNull);
    }
  });

  test('read-only defaults ignore write opt-in and remain read-only', () {
    final configuration = E2eConfiguration.resolve(
      processEnvironment: const {
        'THEOS_E2E_ENABLED': 'true',
        'THEOS_E2E_READ_ONLY': 'true',
        'THEOS_E2E_ALLOW_WRITES': 'true',
        'THEOS_E2E_API_KEY': 'configuration-test-value',
      },
    );

    expect(configuration.canRun, isTrue);
    expect(configuration.readOnly, isTrue);
    expect(configuration.allowWrites, isFalse);
  });
}
