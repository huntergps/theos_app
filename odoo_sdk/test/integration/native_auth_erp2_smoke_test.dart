import 'dart:io';

import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['THEOS_AUTH_SMOKE'] == '1';

  test(
    'native ERP2 login provisions a bearer key for the expected identity',
    () async {
      final login = Platform.environment['THEOS_AUTH_LOGIN'];
      final password = Platform.environment['THEOS_AUTH_PASSWORD'];
      final expectedUserId = int.tryParse(
        Platform.environment['THEOS_AUTH_EXPECTED_UID'] ?? '',
      );
      if (login == null ||
          login.isEmpty ||
          password == null ||
          password.isEmpty ||
          expectedUserId == null ||
          expectedUserId <= 0) {
        fail('Required native-auth smoke environment is incomplete');
      }

      final bootstrap = await NativeOdooAuthBootstrap()
          .authenticateAndCreateApiKey(
            baseUrl: 'https://erp2.tecnosmart.com.ec',
            database: 'erp2_tecnosmart_com_ec',
            login: login,
            password: password,
            apiKeyName: 'THEOS auth smoke',
          );
      expect(bootstrap.userId, expectedUserId);

      final client = OdooClient(
        config: OdooClientConfig(
          baseUrl: 'https://erp2.tecnosmart.com.ec',
          database: 'erp2_tecnosmart_com_ec',
          apiKey: bootstrap.apiKey,
        ),
      );
      final context = await client.call(
        model: 'res.users',
        method: 'context_get',
      );
      expect((context as Map)['uid'], expectedUserId);
    },
    skip: enabled ? false : 'Set THEOS_AUTH_SMOKE=1 for the opt-in ERP2 smoke',
    tags: const ['integration', 'erp2', 'native-auth'],
  );
}
