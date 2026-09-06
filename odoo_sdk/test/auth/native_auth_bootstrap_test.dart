import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> requests;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://odoo.example.com'));
    requests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.next(options);
        },
      ),
    );
    adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
  });

  test(
    'uses a transient cookie and native wizard, never JSON-2 password',
    () async {
      const baseUrl = 'https://odoo.example.com';
      const password = 'not-persisted-test-password';

      adapter.onPost(
        '$baseUrl/web/session/authenticate',
        (server) => server.reply(
          200,
          {
            'jsonrpc': '2.0',
            'id': 1,
            'result': {'uid': 43},
          },
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': ['session_id=test-session; HttpOnly; Secure'],
          },
        ),
        data: Matchers.any,
      );
      adapter.onPost(
        '$baseUrl/web/session/identity/check',
        (server) =>
            server.reply(200, {'jsonrpc': '2.0', 'id': 2, 'result': null}),
        data: Matchers.any,
      );
      adapter.onPost(
        '$baseUrl/web/dataset/call_kw/res.users.apikeys.description/fields_get',
        (server) => server.reply(200, {
          'jsonrpc': '2.0',
          'id': 3,
          'result': {
            'duration': {
              'selection': [
                ['1', '1 Day'],
                ['30', '1 Month'],
                ['90', '3 Months'],
              ],
            },
          },
        }),
        data: Matchers.any,
      );
      adapter.onPost(
        '$baseUrl/web/dataset/call_kw/res.users.apikeys.description/create',
        (server) =>
            server.reply(200, {'jsonrpc': '2.0', 'id': 4, 'result': 81}),
        data: Matchers.any,
      );
      adapter.onPost(
        '$baseUrl/web/dataset/call_kw/res.users.apikeys.description/make_key',
        (server) => server.reply(200, {
          'jsonrpc': '2.0',
          'id': 5,
          'result': {
            'context': {'default_key': 'generated-test-api-key'},
          },
        }),
        data: Matchers.any,
      );

      final result = await NativeOdooAuthBootstrap(httpClient: dio)
          .authenticateAndCreateApiKey(
            baseUrl: baseUrl,
            database: 'erp2',
            login: 'seller',
            password: password,
          );

      expect(result.userId, 43);
      expect(result.apiKey, 'generated-test-api-key');
      expect(dio.options.headers.toString(), isNot(contains(password)));
      expect(requests, hasLength(5));
      expect(requests.first.headers['Cookie'], isNull);
      for (final request in requests.skip(1)) {
        expect(request.headers['Cookie'], 'session_id=test-session');
        expect(request.uri.path, isNot(startsWith('/json/2')));
      }
      for (final request in requests.skip(2)) {
        expect(request.data.toString(), isNot(contains(password)));
      }
    },
  );

  test('MFA challenge stops before creating an API key', () async {
    const baseUrl = 'https://odoo.example.com';
    adapter.onPost(
      '$baseUrl/web/session/authenticate',
      (server) => server.reply(
        200,
        {
          'jsonrpc': '2.0',
          'id': 1,
          'result': {'uid': 23},
        },
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'set-cookie': ['session_id=mfa-session; HttpOnly; Secure'],
        },
      ),
      data: Matchers.any,
    );
    adapter.onPost(
      '$baseUrl/web/session/identity/check',
      (server) => server.reply(200, {
        'jsonrpc': '2.0',
        'id': 2,
        'result': {
          'mfa': true,
          'auth_methods': ['totp'],
        },
      }),
      data: Matchers.any,
    );

    await expectLater(
      NativeOdooAuthBootstrap(httpClient: dio).authenticateAndCreateApiKey(
        baseUrl: baseUrl,
        database: 'erp2',
        login: 'cashier',
        password: 'test-password',
      ),
      throwsA(
        isA<NativeAuthBootstrapException>()
            .having(
              (error) => error.kind,
              'kind',
              NativeAuthBootstrapFailureKind.additionalVerificationRequired,
            )
            .having((error) => error.authMethods, 'methods', ['totp']),
      ),
    );
  });

  test('refuses password bootstrap over clear-text HTTP', () async {
    await expectLater(
      NativeOdooAuthBootstrap(httpClient: dio).authenticateAndCreateApiKey(
        baseUrl: 'http://odoo.example.com',
        database: 'erp2',
        login: 'seller',
        password: 'test-password',
      ),
      throwsA(
        isA<NativeAuthBootstrapException>().having(
          (error) => error.kind,
          'kind',
          NativeAuthBootstrapFailureKind.insecureTransport,
        ),
      ),
    );
  });

  test('authentication failures never expose the submitted password', () async {
    const baseUrl = 'https://odoo.example.com';
    const password = 'private-test-password';
    adapter.onPost(
      '$baseUrl/web/session/authenticate',
      (server) => server.reply(200, {
        'jsonrpc': '2.0',
        'id': 1,
        'error': {'message': 'Rejected $password'},
      }),
      data: Matchers.any,
    );

    Object? failure;
    try {
      await NativeOdooAuthBootstrap(httpClient: dio)
          .authenticateAndCreateApiKey(
            baseUrl: baseUrl,
            database: 'erp2',
            login: 'seller',
            password: password,
          );
    } catch (error) {
      failure = error;
    }

    expect(failure, isA<NativeAuthBootstrapException>());
    expect(
      (failure! as NativeAuthBootstrapException).kind,
      NativeAuthBootstrapFailureKind.invalidCredentials,
    );
    expect(failure.toString(), isNot(contains(password)));
  });
}
