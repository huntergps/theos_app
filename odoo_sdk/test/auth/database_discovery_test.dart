import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late OdooDatabaseDiscovery discovery;
  const baseUrl = 'https://odoo.example.com';

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: baseUrl));
    adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
    discovery = OdooDatabaseDiscovery(httpClient: dio);
  });

  test('returns the databases the server discloses', () async {
    adapter.onPost(
      '$baseUrl/web/database/list',
      (server) => server.reply(200, {
        'jsonrpc': '2.0',
        'id': 1,
        'result': ['erp2_tecnosmart_com_ec', 'staging'],
      }),
      data: Matchers.any,
    );

    final result = await discovery.listDatabases(baseUrl);

    expect(result, ['erp2_tecnosmart_com_ec', 'staging']);
  });

  test('an empty server list is not treated as a failure', () async {
    adapter.onPost(
      '$baseUrl/web/database/list',
      (server) =>
          server.reply(200, {'jsonrpc': '2.0', 'id': 1, 'result': <String>[]}),
      data: Matchers.any,
    );

    final result = await discovery.listDatabases(baseUrl);

    expect(result, isEmpty);
  });

  test(
    'a deployment that disabled listing raises disabled, not a generic error',
    () async {
      // Real shape measured against erp2.tecnosmart.com.ec, which runs with
      // --no-database-list: HTTP 200 carrying a JSON-RPC AccessDenied error.
      adapter.onPost(
        '$baseUrl/web/database/list',
        (server) => server.reply(200, {
          'jsonrpc': '2.0',
          'id': null,
          'error': {
            'code': 0,
            'message': 'Odoo Server Error',
            'data': {
              'name': 'odoo.exceptions.AccessDenied',
              'message':
                  'Database management functions blocked, admin disabled '
                  'database listing.',
            },
          },
        }),
        data: Matchers.any,
      );

      await expectLater(
        discovery.listDatabases(baseUrl),
        throwsA(
          isA<DatabaseDiscoveryException>().having(
            (e) => e.kind,
            'kind',
            DatabaseDiscoveryFailureKind.disabled,
          ),
        ),
      );
    },
  );

  test('an unreachable server raises connection, not disabled', () async {
    adapter.onPost(
      '$baseUrl/web/database/list',
      (server) => server.throws(
        0,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/web/database/list'),
          reason: 'Failed host lookup',
        ),
      ),
      data: Matchers.any,
    );

    await expectLater(
      discovery.listDatabases(baseUrl),
      throwsA(
        isA<DatabaseDiscoveryException>().having(
          (e) => e.kind,
          'kind',
          DatabaseDiscoveryFailureKind.connection,
        ),
      ),
    );
  });

  test('an unexpected response shape raises protocol', () async {
    adapter.onPost(
      '$baseUrl/web/database/list',
      (server) =>
          server.reply(200, {'jsonrpc': '2.0', 'id': 1, 'result': 'not-a-list'}),
      data: Matchers.any,
    );

    await expectLater(
      discovery.listDatabases(baseUrl),
      throwsA(
        isA<DatabaseDiscoveryException>().having(
          (e) => e.kind,
          'kind',
          DatabaseDiscoveryFailureKind.protocol,
        ),
      ),
    );
  });

  test('rejects a malformed base URL before any request', () async {
    await expectLater(
      discovery.listDatabases('not a url'),
      throwsA(
        isA<DatabaseDiscoveryException>().having(
          (e) => e.kind,
          'kind',
          DatabaseDiscoveryFailureKind.protocol,
        ),
      ),
    );
  });
}
