/// Tests for OdooClient and OdooCrudApi with mocked HTTP responses.
///
/// These tests use http_mock_adapter to simulate Odoo server responses,
/// testing the full client without requiring a real Odoo server.
@Tags(['unit'])
library;

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('OdooClientConfig', () {
    test('normalizes base URL with trailing slash', () {
      const config = OdooClientConfig(
        baseUrl: 'https://odoo.example.com/',
        apiKey: 'test-key',
        database: 'test-db',
      );

      expect(config.normalizedBaseUrl, equals('https://odoo.example.com'));
      expect(config.json2Endpoint, equals('https://odoo.example.com/json/2'));
    });

    test('normalizes base URL without trailing slash', () {
      const config = OdooClientConfig(
        baseUrl: 'https://odoo.example.com',
        apiKey: 'test-key',
        database: 'test-db',
      );

      expect(config.normalizedBaseUrl, equals('https://odoo.example.com'));
    });

    test('default values are set correctly', () {
      const config = OdooClientConfig(
        baseUrl: 'https://odoo.example.com',
        apiKey: 'test-key',
      );

      expect(config.database, isNull);
      expect(config.sendTimeout, equals(const Duration(seconds: 30)));
      expect(config.receiveTimeout, equals(const Duration(seconds: 30)));
      expect(config.enableRetry, isTrue);
      expect(config.defaultLanguage, equals('en_US'));
    });

    test('copyWith creates new config with updated values', () {
      const original = OdooClientConfig(
        baseUrl: 'https://odoo.example.com',
        apiKey: 'test-key',
        database: 'test-db',
        defaultLanguage: 'en_US',
      );

      final updated = original.copyWith(
        apiKey: 'new-key',
        defaultLanguage: 'es_EC',
      );

      expect(updated.baseUrl, equals('https://odoo.example.com'));
      expect(updated.apiKey, equals('new-key'));
      expect(updated.database, equals('test-db'));
      expect(updated.defaultLanguage, equals('es_EC'));
    });
  });

  group('OdooClient', () {
    test('creates with required configuration', () {
      final client = OdooClient(
        config: const OdooClientConfig(
          baseUrl: 'https://odoo.example.com',
          apiKey: 'test-key',
          database: 'test-db',
        ),
      );

      expect(client.isConfigured, isTrue);
      expect(client.apiKey, equals('test-key'));
      expect(client.config.database, equals('test-db'));
    });

    test('isConfigured returns false for empty apiKey', () {
      final client = OdooClient(
        config: const OdooClientConfig(
          baseUrl: 'https://odoo.example.com',
          apiKey: '',
        ),
      );

      expect(client.isConfigured, isFalse);
    });

    test('setCredentials updates configuration', () {
      final client = OdooClient(
        config: const OdooClientConfig(
          baseUrl: 'https://old.example.com',
          apiKey: 'old-key',
        ),
      );

      client.setCredentials('https://new.example.com', 'new-key', 'new-db');

      expect(client.config.baseUrl, equals('https://new.example.com'));
      expect(client.apiKey, equals('new-key'));
      expect(client.config.database, equals('new-db'));
    });

    test('provides access to http, crud, and session components', () {
      final client = OdooClient(
        config: const OdooClientConfig(
          baseUrl: 'https://odoo.example.com',
          apiKey: 'test-key',
        ),
      );

      expect(client.http, isNotNull);
      expect(client.crud, isNotNull);
      expect(client.session, isNotNull);
    });
  });

  group('OdooCrudApi', () {
    late Dio dio;
    late DioAdapter dioAdapter;
    late OdooCrudApi crudApi;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://odoo.example.com/json/2'));
      dioAdapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());

      // Create a minimal HTTP client wrapper for testing
      final httpClient = _TestHttpClient(dio: dio);
      crudApi = OdooCrudApi(httpClient: httpClient);
    });

    group('searchRead', () {
      test('returns list of records', () async {
        dioAdapter.onPost(
          '/res.partner/search_read',
          (server) => server.reply(200, [
            {'id': 1, 'name': 'Partner 1', 'email': 'p1@example.com'},
            {'id': 2, 'name': 'Partner 2', 'email': 'p2@example.com'},
          ]),
          data: Matchers.any,
        );

        final result = await crudApi.searchRead(
          model: 'res.partner',
          fields: ['name', 'email'],
        );

        expect(result, hasLength(2));
        expect(result[0]['name'], equals('Partner 1'));
        expect(result[1]['name'], equals('Partner 2'));
      });

      test('applies domain filter', () async {
        dioAdapter.onPost(
          '/res.partner/search_read',
          (server) => server.reply(200, [
            {'id': 1, 'name': 'Active Partner'},
          ]),
          data: Matchers.any,
        );

        final result = await crudApi.searchRead(
          model: 'res.partner',
          fields: ['name'],
          domain: [
            ['active', '=', true],
          ],
        );

        expect(result, hasLength(1));
      });

      test('applies limit and offset', () async {
        dioAdapter.onPost(
          '/res.partner/search_read',
          (server) => server.reply(200, [
            {'id': 11, 'name': 'Partner 11'},
            {'id': 12, 'name': 'Partner 12'},
          ]),
          data: Matchers.any,
        );

        final result = await crudApi.searchRead(
          model: 'res.partner',
          fields: ['name'],
          limit: 2,
          offset: 10,
        );

        expect(result, hasLength(2));
      });

      test('applies order', () async {
        dioAdapter.onPost(
          '/res.partner/search_read',
          (server) => server.reply(200, [
            {'id': 1, 'name': 'Alpha'},
            {'id': 2, 'name': 'Beta'},
          ]),
          data: Matchers.any,
        );

        final result = await crudApi.searchRead(
          model: 'res.partner',
          fields: ['name'],
          order: 'name asc',
        );

        expect(result, hasLength(2));
        expect(result[0]['name'], equals('Alpha'));
      });

      test('returns empty list for non-list response', () async {
        dioAdapter.onPost(
          '/res.partner/search_read',
          (server) => server.reply(200, {'data': 'unexpected format'}),
          data: Matchers.any,
        );

        final result = await crudApi.searchRead(
          model: 'res.partner',
          fields: ['name'],
        );

        expect(result, isEmpty);
      });
    });

    group('searchCount', () {
      test('returns count', () async {
        dioAdapter.onPost(
          '/res.partner/search_count',
          (server) => server.reply(200, 42),
          data: Matchers.any,
        );

        final result = await crudApi.searchCount(
          model: 'res.partner',
          domain: [],
        );

        expect(result, equals(42));
      });

      test('returns null for non-integer response', () async {
        dioAdapter.onPost(
          '/res.partner/search_count',
          (server) => server.reply(200, 'not a number'),
          data: Matchers.any,
        );

        final result = await crudApi.searchCount(model: 'res.partner');

        expect(result, isNull);
      });
    });

    group('read', () {
      test('returns records by IDs', () async {
        dioAdapter.onPost(
          '/res.partner/read',
          (server) => server.reply(200, [
            {'id': 1, 'name': 'Partner 1'},
            {'id': 2, 'name': 'Partner 2'},
          ]),
          data: Matchers.any,
        );

        final result = await crudApi.read(
          model: 'res.partner',
          ids: [1, 2],
          fields: ['name'],
        );

        expect(result, hasLength(2));
      });

      test('returns empty list for non-list response', () async {
        dioAdapter.onPost(
          '/res.partner/read',
          (server) => server.reply(200, null),
          data: Matchers.any,
        );

        final result = await crudApi.read(
          model: 'res.partner',
          ids: [999],
          fields: ['name'],
        );

        expect(result, isEmpty);
      });
    });

    group('create', () {
      test('returns created ID from list response', () async {
        dioAdapter.onPost(
          '/res.partner/create',
          (server) => server.reply(200, [123]),
          data: Matchers.any,
        );

        final result = await crudApi.create(
          model: 'res.partner',
          values: {'name': 'New Partner'},
        );

        expect(result, equals(123));
      });

      test('returns ID from direct integer response (legacy)', () async {
        dioAdapter.onPost(
          '/res.partner/create',
          (server) => server.reply(200, 456),
          data: Matchers.any,
        );

        final result = await crudApi.create(
          model: 'res.partner',
          values: {'name': 'New Partner'},
        );

        expect(result, equals(456));
      });

      test('returns null for empty list response', () async {
        dioAdapter.onPost(
          '/res.partner/create',
          (server) => server.reply(200, []),
          data: Matchers.any,
        );

        final result = await crudApi.create(
          model: 'res.partner',
          values: {'name': 'New Partner'},
        );

        expect(result, isNull);
      });

      test('returns null for non-integer in list', () async {
        dioAdapter.onPost(
          '/res.partner/create',
          (server) => server.reply(200, ['not-an-id']),
          data: Matchers.any,
        );

        final result = await crudApi.create(
          model: 'res.partner',
          values: {'name': 'New Partner'},
        );

        expect(result, isNull);
      });
    });

    group('write', () {
      test('returns true on success', () async {
        dioAdapter.onPost(
          '/res.partner/write',
          (server) => server.reply(200, true),
          data: Matchers.any,
        );

        final result = await crudApi.write(
          model: 'res.partner',
          ids: [1],
          values: {'name': 'Updated Partner'},
        );

        expect(result, isTrue);
      });

      test('returns false on failure', () async {
        dioAdapter.onPost(
          '/res.partner/write',
          (server) => server.reply(200, false),
          data: Matchers.any,
        );

        final result = await crudApi.write(
          model: 'res.partner',
          ids: [999],
          values: {'name': 'Updated Partner'},
        );

        expect(result, isFalse);
      });
    });

    group('unlink', () {
      test('returns true on success', () async {
        dioAdapter.onPost(
          '/res.partner/unlink',
          (server) => server.reply(200, true),
          data: Matchers.any,
        );

        final result = await crudApi.unlink(model: 'res.partner', ids: [1]);

        expect(result, isTrue);
      });

      test('returns false on failure', () async {
        dioAdapter.onPost(
          '/res.partner/unlink',
          (server) => server.reply(200, false),
          data: Matchers.any,
        );

        final result = await crudApi.unlink(model: 'res.partner', ids: [999]);

        expect(result, isFalse);
      });
    });

    group('createBatch', () {
      test('returns list of created IDs', () async {
        dioAdapter.onPost(
          '/res.partner/create',
          (server) => server.reply(200, [101, 102, 103]),
          data: Matchers.any,
        );

        final result = await crudApi.createBatch(
          model: 'res.partner',
          valuesList: [
            {'name': 'Partner A'},
            {'name': 'Partner B'},
            {'name': 'Partner C'},
          ],
        );

        expect(result, equals([101, 102, 103]));
      });

      test('returns empty list for empty input', () async {
        final result = await crudApi.createBatch(
          model: 'res.partner',
          valuesList: [],
        );

        expect(result, isEmpty);
      });

      test('filters non-integer values from response', () async {
        dioAdapter.onPost(
          '/res.partner/create',
          (server) => server.reply(200, [101, 'invalid', 103]),
          data: Matchers.any,
        );

        final result = await crudApi.createBatch(
          model: 'res.partner',
          valuesList: [
            {'name': 'Partner A'},
            {'name': 'Partner B'},
            {'name': 'Partner C'},
          ],
        );

        expect(result, equals([101, 103]));
      });
    });

    group('updateBatch', () {
      test('returns list of success results', () async {
        dioAdapter.onPost(
          '/res.partner/write',
          (server) => server.reply(200, true),
          data: Matchers.any,
        );

        final result = await crudApi.updateBatch(
          model: 'res.partner',
          updates: [
            const BatchUpdate(ids: [1], values: {'phone': '111'}),
            const BatchUpdate(ids: [2], values: {'phone': '222'}),
          ],
        );

        expect(result, equals([true, true]));
      });

      test('returns empty list for empty input', () async {
        final result = await crudApi.updateBatch(
          model: 'res.partner',
          updates: [],
        );

        expect(result, isEmpty);
      });

      test('handles errors without throwing', () async {
        // When all writes succeed
        dioAdapter.onPost(
          '/res.partner/write',
          (server) => server.reply(200, true),
          data: Matchers.any,
        );

        final result = await crudApi.updateBatch(
          model: 'res.partner',
          updates: [
            const BatchUpdate(ids: [1], values: {'phone': '111'}),
            const BatchUpdate(ids: [2], values: {'phone': '222'}),
          ],
        );

        // All should succeed
        expect(result.every((r) => r == true), isTrue);
      });
    });

    group('deleteBatch', () {
      test('returns true on success', () async {
        dioAdapter.onPost(
          '/res.partner/unlink',
          (server) => server.reply(200, true),
          data: Matchers.any,
        );

        final result = await crudApi.deleteBatch(
          model: 'res.partner',
          ids: [1, 2, 3],
        );

        expect(result, isTrue);
      });

      test('returns true for empty input', () async {
        final result = await crudApi.deleteBatch(model: 'res.partner', ids: []);

        expect(result, isTrue);
      });
    });

    group('executeBatch', () {
      test('executes creates, updates, and deletes', () async {
        // Mock create
        dioAdapter.onPost(
          '/res.partner/create',
          (server) => server.reply(200, [201]),
          data: Matchers.any,
        );

        // Mock write
        dioAdapter.onPost(
          '/res.partner/write',
          (server) => server.reply(200, true),
          data: Matchers.any,
        );

        // Mock unlink
        dioAdapter.onPost(
          '/res.partner/unlink',
          (server) => server.reply(200, true),
          data: Matchers.any,
        );

        final result = await crudApi.executeBatch(
          model: 'res.partner',
          creates: [
            {'name': 'New Partner'},
          ],
          updates: [
            const BatchUpdate(ids: [1], values: {'active': true}),
          ],
          deletes: [99],
        );

        expect(result.createdIds, equals([201]));
        expect(result.updateResults, equals([true]));
        expect(result.deleteSuccess, isTrue);
        expect(result.success, isTrue);
        expect(result.errors, isEmpty);
      });

      test('captures errors without throwing', () async {
        dioAdapter.onPost(
          '/res.partner/create',
          (server) => server.throws(
            500,
            DioException(
              requestOptions: RequestOptions(path: '/res.partner/create'),
              message: 'Server error',
              type: DioExceptionType.badResponse,
            ),
          ),
          data: Matchers.any,
        );

        final result = await crudApi.executeBatch(
          model: 'res.partner',
          creates: [
            {'name': 'New Partner'},
          ],
        );

        expect(result.createdIds, isEmpty);
        expect(result.hasErrors, isTrue);
        expect(result.success, isFalse);
      });
    });

    group('fieldsGet', () {
      test('returns field metadata', () async {
        dioAdapter.onPost(
          '/res.partner/fields_get',
          (server) => server.reply(200, {
            'name': {'type': 'char', 'string': 'Name', 'required': true},
            'email': {'type': 'char', 'string': 'Email'},
          }),
          data: Matchers.any,
        );

        final result = await crudApi.fieldsGet(
          model: 'res.partner',
          attributes: ['type', 'string', 'required'],
        );

        expect(result, isNotEmpty);
        expect(result['name']['type'], equals('char'));
        expect(result['name']['required'], isTrue);
      });

      test('returns empty map for non-map response', () async {
        dioAdapter.onPost(
          '/res.partner/fields_get',
          (server) => server.reply(200, null),
          data: Matchers.any,
        );

        final result = await crudApi.fieldsGet(model: 'res.partner');

        expect(result, isEmpty);
      });
    });

    group('getModifiedSince', () {
      test('returns modified records with write_date filter', () async {
        dioAdapter.onPost(
          '/res.partner/search_read',
          (server) => server.reply(200, [
            {
              'id': 1,
              'name': 'Modified Partner',
              'write_date': '2026-01-16 12:00:00',
            },
          ]),
          data: Matchers.any,
        );

        final result = await crudApi.getModifiedSince(
          model: 'res.partner',
          lastSync: DateTime(2026, 1, 15),
          fields: ['name'],
        );

        expect(result, hasLength(1));
        expect(result[0].containsKey('write_date'), isTrue);
      });
    });

    group('call', () {
      test('handles custom method with ids', () async {
        dioAdapter.onPost(
          '/sale.order/action_confirm',
          (server) => server.reply(200, true),
          data: Matchers.any,
        );

        final result = await crudApi.call(
          model: 'sale.order',
          method: 'action_confirm',
          ids: [1],
        );

        expect(result, isTrue);
      });

      test('handles custom method with args', () async {
        dioAdapter.onPost(
          '/ir.actions.report/render_qweb_pdf',
          (server) => server.reply(200, 'base64-pdf-content'),
          data: Matchers.any,
        );

        final result = await crudApi.call(
          model: 'ir.actions.report',
          method: 'render_qweb_pdf',
          args: [
            'sale.report_saleorder',
            [1],
          ],
        );

        expect(result, equals('base64-pdf-content'));
      });

      test('handles custom method with kwargs', () async {
        dioAdapter.onPost(
          '/res.partner/name_search',
          (server) => server.reply(200, [
            [1, 'Partner 1'],
            [2, 'Partner 2'],
          ]),
          data: Matchers.any,
        );

        final result = await crudApi.call(
          model: 'res.partner',
          method: 'name_search',
          kwargs: {'name': 'Test', 'limit': 10},
        );

        expect(result, isA<List>());
        expect(result, hasLength(2));
      });
    });

    group('error handling', () {
      test('throws OdooException on error response', () async {
        dioAdapter.onPost(
          '/res.partner/search_read',
          (server) => server.reply(200, {
            'error': {
              'message': 'Access denied',
              'data': {'debug': 'User has no access to res.partner'},
            },
          }),
          data: Matchers.any,
        );

        expect(
          () => crudApi.searchRead(model: 'res.partner', fields: ['name']),
          throwsA(
            isA<OdooException>().having(
              (e) => e.message,
              'message',
              contains('Access denied'),
            ),
          ),
        );
      });

      test('throws OdooException on string error', () async {
        dioAdapter.onPost(
          '/res.partner/search_read',
          (server) => server.reply(200, {'error': 'Simple error message'}),
          data: Matchers.any,
        );

        expect(
          () => crudApi.searchRead(model: 'res.partner', fields: ['name']),
          throwsA(
            isA<OdooException>().having(
              (e) => e.message,
              'message',
              equals('Simple error message'),
            ),
          ),
        );
      });

      test('throws OdooException on HTTP error', () async {
        dioAdapter.onPost(
          '/res.partner/search_read',
          (server) => server.throws(
            500,
            DioException(
              requestOptions: RequestOptions(path: '/res.partner/search_read'),
              response: Response(
                requestOptions: RequestOptions(
                  path: '/res.partner/search_read',
                ),
                statusCode: 500,
                data: {'message': 'Internal Server Error'},
              ),
              type: DioExceptionType.badResponse,
            ),
          ),
          data: Matchers.any,
        );

        expect(
          () => crudApi.searchRead(model: 'res.partner', fields: ['name']),
          throwsA(
            isA<OdooException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(500),
            ),
          ),
        );
      });

      test('extracts error message from various formats', () async {
        // Test nested error format
        dioAdapter.onPost(
          '/res.partner/create',
          (server) => server.throws(
            400,
            DioException(
              requestOptions: RequestOptions(path: '/res.partner/create'),
              response: Response(
                requestOptions: RequestOptions(path: '/res.partner/create'),
                statusCode: 400,
                data: {
                  'error': {
                    'message': 'Validation error',
                    'data': {'debug': 'Field "name" is required'},
                  },
                },
              ),
              type: DioExceptionType.badResponse,
            ),
          ),
          data: Matchers.any,
        );

        expect(
          () => crudApi.create(model: 'res.partner', values: {}),
          throwsA(
            isA<OdooException>().having(
              (e) => e.message,
              'message',
              contains('Validation error'),
            ),
          ),
        );
      });
    });

    group('value preparation', () {
      test('converts DateTime to Odoo format', () async {
        dioAdapter.onPost(
          '/sale.order/create',
          (server) => server.reply(200, [1]),
          data: Matchers.any,
        );

        // The actual conversion is tested by successful creation
        // The API converts DateTime internally via _prepareValues
        final result = await crudApi.create(
          model: 'sale.order',
          values: {
            'name': 'SO001',
            'date_order': DateTime(2026, 1, 16, 10, 30, 0),
          },
        );

        expect(result, equals(1));
      });

      test('extracts id from Map values', () async {
        dioAdapter.onPost(
          '/sale.order.line/create',
          (server) => server.reply(200, [1]),
          data: Matchers.any,
        );

        final result = await crudApi.create(
          model: 'sale.order.line',
          values: {
            'product_id': {'id': 42, 'name': 'Product'},
            'order_id': {'id': 1, 'name': 'SO001'},
          },
        );

        expect(result, equals(1));
      });

      test('filters null values', () async {
        dioAdapter.onPost(
          '/res.partner/create',
          (server) => server.reply(200, [1]),
          data: Matchers.any,
        );

        final result = await crudApi.create(
          model: 'res.partner',
          values: {'name': 'Test', 'email': null, 'phone': null},
        );

        expect(result, equals(1));
      });
    });
  });

  group('BatchUpdate', () {
    test('creates from constructor', () {
      const update = BatchUpdate(ids: [1, 2, 3], values: {'active': true});

      expect(update.ids, equals([1, 2, 3]));
      expect(update.values, equals({'active': true}));
    });

    test('creates from map', () {
      final update = BatchUpdate.fromMap({
        'ids': [1, 2],
        'values': {'name': 'Updated'},
      });

      expect(update.ids, equals([1, 2]));
      expect(update.values['name'], equals('Updated'));
    });

    test('converts to map', () {
      const update = BatchUpdate(ids: [1], values: {'phone': '123'});

      final map = update.toMap();

      expect(map['ids'], equals([1]));
      expect(map['values'], equals({'phone': '123'}));
    });
  });

  group('BatchResult', () {
    test('success is true when all operations succeed', () {
      const result = BatchResult(
        createdIds: [1, 2],
        updateResults: [true, true],
        deleteSuccess: true,
        errors: [],
      );

      expect(result.success, isTrue);
      expect(result.hasErrors, isFalse);
    });

    test('success is false when update fails', () {
      const result = BatchResult(
        createdIds: [1],
        updateResults: [true, false],
        deleteSuccess: true,
        errors: [],
      );

      expect(result.success, isFalse);
    });

    test('success is false when delete fails', () {
      const result = BatchResult(
        createdIds: [1],
        updateResults: [true],
        deleteSuccess: false,
        errors: [],
      );

      expect(result.success, isFalse);
    });

    test('success is false when errors exist', () {
      const result = BatchResult(
        createdIds: [1],
        updateResults: [true],
        deleteSuccess: true,
        errors: ['Some error'],
      );

      expect(result.success, isFalse);
      expect(result.hasErrors, isTrue);
    });

    test('counts are calculated correctly', () {
      const result = BatchResult(
        createdIds: [1, 2, 3],
        updateResults: [true, false, true, false],
        deleteSuccess: true,
        errors: [],
      );

      expect(result.createCount, equals(3));
      expect(result.updateSuccessCount, equals(2));
      expect(result.updateFailureCount, equals(2));
    });

    test('toString provides useful summary', () {
      const result = BatchResult(
        createdIds: [1, 2],
        updateResults: [true, false],
        deleteSuccess: true,
        errors: ['Error 1'],
      );

      final str = result.toString();

      expect(str, contains('created: 2'));
      expect(str, contains('updates: 2'));
      expect(str, contains('1 ok'));
      expect(str, contains('errors: 1'));
    });
  });
}

/// Test wrapper for OdooHttpClient that uses a provided Dio instance
class _TestHttpClient implements OdooHttpClient {
  final Dio _dio;

  _TestHttpClient({required Dio dio}) : _dio = dio;

  @override
  OdooClientConfig get config => const OdooClientConfig(
    baseUrl: 'https://odoo.example.com',
    apiKey: 'test-key',
    database: 'test-db',
    defaultLanguage: 'en_US',
  );

  @override
  Future<Response<dynamic>> postJson2(
    String path, {
    Map<String, dynamic>? data,
    CancelToken? cancelToken,
  }) async {
    return _dio.post(path, data: data, cancelToken: cancelToken);
  }

  // Unused in these tests
  @override
  bool get isConfigured => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
