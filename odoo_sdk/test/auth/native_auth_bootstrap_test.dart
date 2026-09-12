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
      adapter.onPost(
        '$baseUrl/web/dataset/call_kw/res.users.apikeys/search_read',
        (server) => server.reply(200, {
          'jsonrpc': '2.0',
          'id': 6,
          'result': [
            {'id': 81},
          ],
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
      expect(result.apiKeyId, 81);
      expect(dio.options.headers.toString(), isNot(contains(password)));
      expect(requests, hasLength(6));
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

  test(
    'apiKeyId resolution failure never breaks an otherwise successful login',
    () async {
      const baseUrl = 'https://odoo.example.com';
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
      // The lookup itself errors out: the login must still succeed.
      adapter.onPost(
        '$baseUrl/web/dataset/call_kw/res.users.apikeys/search_read',
        (server) => server.reply(200, {
          'jsonrpc': '2.0',
          'id': 6,
          'error': {'message': 'temporary lookup failure'},
        }),
        data: Matchers.any,
      );

      final result = await NativeOdooAuthBootstrap(httpClient: dio)
          .authenticateAndCreateApiKey(
            baseUrl: baseUrl,
            database: 'erp2',
            login: 'seller',
            password: 'irrelevant',
          );

      expect(result.userId, 43);
      expect(result.apiKey, 'generated-test-api-key');
      expect(result.apiKeyId, isNull);
    },
  );

  test(
    'revokeApiKey removes the exact key a caller failed to persist locally',
    () async {
      const baseUrl = 'https://odoo.example.com';
      const password = 'not-persisted-test-password';
      var removeCallArgs = <dynamic>[];

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
            'set-cookie': ['session_id=revoke-session; HttpOnly; Secure'],
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
        '$baseUrl/web/dataset/call_kw/res.users.apikeys/remove',
        (server) => server.reply(200, {
          'jsonrpc': '2.0',
          'id': 3,
          'result': {'type': 'ir.actions.act_window_close'},
        }),
        data: Matchers.any,
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith(
              '/web/dataset/call_kw/res.users.apikeys/remove',
            )) {
              removeCallArgs = (options.data as Map)['params']['args'] as List;
            }
            handler.next(options);
          },
        ),
      );

      // Simulates: the server already created key 81 for this login, but the
      // caller's own local persistence step failed afterwards.
      await NativeOdooAuthBootstrap(
        httpClient: dio,
      ).revokeApiKey(
        baseUrl: baseUrl,
        database: 'erp2',
        login: 'seller',
        password: password,
        apiKeyId: 81,
      );

      expect(removeCallArgs, [
        [81],
      ]);
      expect(dio.options.headers.toString(), isNot(contains(password)));
    },
  );

  test(
    'a failed revocation is a distinct exception that cannot be mistaken '
    'for the original bootstrap failure it is cleaning up after',
    () async {
      const baseUrl = 'https://odoo.example.com';
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
            'set-cookie': ['session_id=revoke-session; HttpOnly; Secure'],
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
        '$baseUrl/web/dataset/call_kw/res.users.apikeys/remove',
        (server) => server.reply(200, {
          'jsonrpc': '2.0',
          'id': 3,
          'error': {'message': 'access denied'},
        }),
        data: Matchers.any,
      );

      Object? cleanupFailure;
      try {
        await NativeOdooAuthBootstrap(httpClient: dio).revokeApiKey(
          baseUrl: baseUrl,
          database: 'erp2',
          login: 'seller',
          password: 'test-password',
          apiKeyId: 81,
        );
      } catch (error) {
        cleanupFailure = error;
      }

      // A caller that, say, already caught a `NativeAuthBootstrapException`
      // from the local-save step and now attempts cleanup must be able to
      // tell the two failures apart — the type itself carries that signal
      // so the original error is never silently replaced.
      expect(cleanupFailure, isA<NativeAuthBootstrapRevocationException>());
      expect(cleanupFailure, isNot(isA<NativeAuthBootstrapException>()));
    },
  );
}
