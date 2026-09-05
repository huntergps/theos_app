import 'dart:convert';
import 'dart:io';

import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

void main() {
  test(
    'JSON-2 sends Bearer/database headers without a session cookie',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final requestReceived = server.first.then((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/json/2/res.partner/search_read');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer test-api-key',
        );
        expect(request.headers.value('x-odoo-database'), 'erp_test');
        expect(request.headers.value(HttpHeaders.cookieHeader), isNull);

        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write('[]');
        await request.response.close();
      });

      final client = OdooClient(
        config: OdooClientConfig(
          baseUrl: 'http://${server.address.host}:${server.port}',
          apiKey: 'test-api-key',
          database: 'erp_test',
          allowInsecure: true,
          enableRetry: false,
        ),
      );

      final records = await client.searchRead(
        model: 'res.partner',
        fields: const ['name'],
      );
      await requestReceived;

      expect(records, isEmpty);
    },
  );
}
