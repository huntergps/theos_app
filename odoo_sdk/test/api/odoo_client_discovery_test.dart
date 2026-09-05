import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

void main() {
  late OdooClient client;
  late DioAdapter adapter;

  setUp(() {
    client = OdooClient(
      config: const OdooClientConfig(
        baseUrl: 'https://odoo.example.com',
        apiKey: 'key',
        enableRetry: false,
      ),
    );
    adapter = DioAdapter(
      dio: client.http.dio,
      matcher: const UrlRequestMatcher(),
    );
  });

  test('concurrent field probes share one request and hasField distinguishes absence', () async {
    var requests = 0;
    adapter.onPost('/res.partner/fields_get', (server) {
      requests++;
      server.reply(200, {
        'name': {'type': 'char'},
      });
    }, data: Matchers.any);

    final results = await Future.wait([
      client.getModelFields('res.partner'),
      client.getModelFields('res.partner'),
      client.hasField('res.partner', 'missing'),
    ]);

    expect(requests, 1);
    expect(results[0], {
      'name': {'type': 'char'},
    });
    expect(results[2], isFalse);
  });

  test('does not cache HTTP failures', () async {
    adapter.onPost('/res.partner/fields_get', (server) {
      server.reply(500, {
        'error': {'message': 'temporary'},
      });
    }, data: Matchers.any);

    await expectLater(
      client.getModelFields('res.partner'),
      throwsA(isA<OdooException>()),
    );
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      client.getModelFields('res.partner'),
      throwsA(isA<OdooException>()),
    );
  });

  test(
    'invalid fields_get response is a failure, not an empty schema',
    () async {
      adapter.onPost('/res.partner/fields_get', (server) {
        server.reply(200, ['not', 'metadata']);
      }, data: Matchers.any);

      await expectLater(
        client.hasField('res.partner', 'name'),
        throwsA(isA<OdooException>()),
      );
    },
  );

  test('credentials invalidate model metadata cache', () async {
    adapter.onPost('/res.partner/fields_get', (server) {
      server.reply(200, {
        'name': {'type': 'char'},
      });
    }, data: Matchers.any);

    expect(await client.hasField('res.partner', 'name'), isTrue);
    client.setCredentials('https://other.example.com', 'new-key', 'new-db');
    await Future<void>.delayed(Duration.zero);
    expect(await client.hasField('res.partner', 'name'), isTrue);
  });

  test('credentials reset a detected version', () async {
    adapter.onPost('/ir.module.module/search_read', (server) {
      server.reply(200, [
        {'latest_version': '19.5.0'},
      ]);
    }, data: Matchers.any);

    expect((await client.fetchVersion(maxAttempts: 1)).toString(), '19.5');
    client.setCredentials('https://other.example.com', 'new-key', 'new-db');
    expect(client.version.isUnknown, isTrue);
  });
}
