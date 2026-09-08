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

  test('webSession uses cookie JSON-RPC without Bearer credentials', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final requestReceived = server.first.then((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/web/dataset/call_kw/res.partner.search_read');
      expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
      expect(request.headers.value('x-csrftoken'), 'csrf-test');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body['jsonrpc'], '2.0');
      expect(body['params']['model'], 'res.partner');
      expect(body['params']['method'], 'search_read');
      expect(body['params']['kwargs']['fields'], ['name']);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write('{"jsonrpc":"2.0","id":1,"result":[]}');
      await request.response.close();
    });

    final client = OdooClient(
      config: OdooClientConfig(
        baseUrl: 'http://${server.address.host}:${server.port}',
        apiKey: '',
        transportMode: OdooTransportMode.webSession,
        csrfToken: 'csrf-test',
        allowInsecure: true,
        enableRetry: false,
      ),
    );
    expect(client.isConfigured, isTrue);
    expect(
      await client.searchRead(model: 'res.partner', fields: ['name']),
      isEmpty,
    );
    await requestReceived;
  });
}
