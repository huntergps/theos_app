@Tags(['unit'])
library;

import 'package:dio/dio.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('OdooErrorMapper.fromResponse', () {
    test('maps access errors', () {
      final error = OdooErrorMapper.fromResponse({
        'error': {
          'message': 'Access denied',
          'data': {'name': 'odoo.exceptions.AccessError'},
        },
      }, statusCode: 403);

      expect(error, isA<OdooAccessDeniedException>());
    });

    test('maps validation errors and preserves sanitized field errors', () {
      final error = OdooErrorMapper.fromResponse({
        'error': {
          'message': 'Invalid customer john@example.com',
          'data': {
            'name': 'odoo.exceptions.ValidationError',
            'field_errors': {
              'email': ['john@example.com is already registered'],
            },
          },
        },
      }, statusCode: 422);

      expect(error, isA<OdooValidationException>());
      expect(error.statusCode, 422);
      expect(error.message, isNot(contains('john@example.com')));
      expect(error.toString(), isNot(contains('john@example.com')));
    });

    test('maps an expired session separately from invalid credentials', () {
      final error = OdooErrorMapper.fromResponse({
        'message': 'Session expired, authenticate again',
      }, statusCode: 401);

      expect(error, isA<OdooSessionExpiredException>());
    });

    test(
      'maps Odoo 20 flat SessionExpiredException responses with HTTP 403',
      () {
        final error = OdooErrorMapper.fromResponse({
          'name': 'odoo.http.session.SessionExpiredException',
          'message': 'Session expired',
          'arguments': ['Session expired'],
          'context': {},
        }, statusCode: 403);

        expect(error, isA<OdooSessionExpiredException>());
        expect(error.statusCode, 403);
      },
    );

    test('maps JSON-RPC session code 100 without relying on HTTP status', () {
      final error = OdooErrorMapper.fromResponse({
        'error': {
          'code': 100,
          'message': 'Odoo Session Expired',
          'data': {
            'name': 'odoo.http.session.SessionExpiredException',
            'message': 'Session expired',
          },
        },
      });

      expect(error, isA<OdooSessionExpiredException>());
      expect(error.statusCode, 403);
    });

    test('maps a missing model method', () {
      final error = OdooErrorMapper.fromResponse(
        {'message': 'Method action_missing does not exist'},
        statusCode: 404,
        model: 'sale.order',
        method: 'action_missing',
      );

      expect(error, isA<OdooMethodNotFoundException>());
      expect(
        (error as OdooMethodNotFoundException).methodName,
        'action_missing',
      );
    });

    test('maps an invalid field', () {
      final error = OdooErrorMapper.fromResponse(
        {'message': "Invalid field 'legacy_code' on model 'res.partner'"},
        statusCode: 422,
        model: 'res.partner',
        method: 'search_read',
      );

      expect(error, isA<OdooFieldNotFoundException>());
      expect((error as OdooFieldNotFoundException).fieldName, 'legacy_code');
    });

    test('normalizes qualified invalid fields to the field leaf', () {
      final error = OdooErrorMapper.fromResponse(
        {'message': 'Invalid field res.partner.legacy_code'},
        statusCode: 422,
        model: 'res.partner',
        method: 'search_read',
      );

      expect(error, isA<OdooFieldNotFoundException>());
      expect((error as OdooFieldNotFoundException).fieldName, 'legacy_code');
    });

    test('does not retain credentials in message, details, or data', () {
      const token = 'sk-live.ab_12';
      final error = OdooErrorMapper.fromResponse({
        'error': {
          'message': 'Request failed token=$token',
          'data': {
            'debug': 'Authorization: Bearer $token',
            'api_key': token,
            'cookie': 'session_id=short-_token',
          },
        },
      }, statusCode: 500);

      expect(error.message, isNot(contains(token)));
      expect(error.technicalDetails, isNot(contains(token)));
      expect(error.data.toString(), isNot(contains(token)));
      expect(error.toString(), isNot(contains(token)));
    });
  });

  group('OdooErrorMapper.fromDio', () {
    test('maps timeouts', () {
      final request = RequestOptions(path: '/res.partner/search_read');
      final error = OdooErrorMapper.fromDio(
        DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(error, isA<OdooTimeoutException>());
    });

    test('maps disconnections', () {
      final request = RequestOptions(path: '/res.partner/search_read');
      final error = OdooErrorMapper.fromDio(
        DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
          message: 'Socket closed',
        ),
      );

      expect(error, isA<OdooConnectionException>());
    });

    test('maps caller cancellation separately from disconnection', () {
      final error = OdooErrorMapper.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/res.partner/search_read'),
          type: DioExceptionType.cancel,
        ),
      );

      expect(error, isA<OdooRequestCancelledException>());
    });

    test('delegates HTTP responses to the response mapper', () {
      final request = RequestOptions(path: '/sale.order/write');
      final error = OdooErrorMapper.fromDio(
        DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: request,
            statusCode: 403,
            data: {'message': 'Forbidden'},
          ),
        ),
        model: 'sale.order',
        method: 'write',
      );

      expect(error, isA<OdooAccessDeniedException>());
    });
  });

  group('OdooCrudApi error boundary', () {
    test('maps JSON-2 error envelopes before exposing them', () async {
      final httpClient = _ErrorHttpClient(
        responseData: {
          'error': {
            'message': 'Access denied',
            'data': {'name': 'odoo.exceptions.AccessError'},
          },
        },
      );
      final api = OdooCrudApi(httpClient: httpClient);

      await expectLater(
        api.call(model: 'sale.order', method: 'action_confirm'),
        throwsA(isA<OdooAccessDeniedException>()),
      );
    });

    test('maps Dio disconnections before exposing them', () async {
      final request = RequestOptions(path: '/res.partner/search_read');
      final httpClient = _ErrorHttpClient(
        dioError: DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
          message: 'Socket closed',
        ),
      );
      final api = OdooCrudApi(httpClient: httpClient);

      await expectLater(
        api.searchRead(model: 'res.partner', fields: const ['name']),
        throwsA(isA<OdooConnectionException>()),
      );
    });

    test('allows a successful JSON-2 result containing only message', () async {
      final httpClient = _ErrorHttpClient(
        responseData: {'message': 'Operation completed'},
      );
      final api = OdooCrudApi(httpClient: httpClient);

      final result = await api.call(model: 'custom.model', method: 'notify');

      expect(result, {'message': 'Operation completed'});
    });
  });

}

class _ErrorHttpClient implements OdooHttpClient {
  final dynamic responseData;
  final DioException? dioError;

  _ErrorHttpClient({this.responseData, this.dioError});

  @override
  OdooClientConfig get config => const OdooClientConfig(
    baseUrl: 'https://odoo.example.com',
    apiKey: 'test-key',
  );

  @override
  Future<Response<dynamic>> postJson2(
    String path, {
    Map<String, dynamic>? data,
    CancelToken? cancelToken,
  }) async {
    if (dioError != null) throw dioError!;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: responseData,
    );
  }

  @override
  Future<Response<dynamic>> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    if (dioError != null) throw dioError!;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: url),
      statusCode: 200,
      data: responseData,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
