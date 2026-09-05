@Tags(['unit'])
library;

import 'package:dio/dio.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

const _defaultContext = {'lang': 'es_EC'};

void main() {
  group('JSON-2 HTTP contract', () {
    late _RecordingHttpClient httpClient;
    late OdooCrudApi api;

    setUp(() {
      httpClient = _RecordingHttpClient();
      api = OdooCrudApi(httpClient: httpClient);
    });

    test('search_read sends model kwargs without ids or args', () async {
      httpClient.responseData = <Map<String, dynamic>>[];

      await api.searchRead(
        model: 'res.partner',
        fields: const ['name', 'email'],
        domain: const [
          ['active', '=', true],
        ],
        limit: 25,
        offset: 5,
        order: 'name asc',
      );

      expect(httpClient.lastPath, '/res.partner/search_read');
      expect(httpClient.lastBody, {
        'domain': [
          ['active', '=', true],
        ],
        'fields': ['name', 'email'],
        'limit': 25,
        'offset': 5,
        'order': 'name asc',
        'context': _defaultContext,
      });
      expect(httpClient.lastBody, isNot(contains('ids')));
      expect(httpClient.lastBody, isNot(contains('args')));
      expect(httpClient.lastBody, isNot(contains('kwargs')));
    });

    test(
      'create sends vals_list as model kwargs without recordset ids',
      () async {
        httpClient.responseData = [91];

        final id = await api.create(
          model: 'res.partner',
          values: const {'name': 'Ada'},
        );

        expect(id, 91);
        expect(httpClient.lastPath, '/res.partner/create');
        expect(httpClient.lastBody, {
          'vals_list': [
            {'name': 'Ada'},
          ],
          'context': _defaultContext,
        });
        expect(httpClient.lastBody, isNot(contains('ids')));
      },
    );

    test(
      'recordset call keeps ids separate from method kwargs and context',
      () async {
        httpClient.responseData = true;

        await api.call(
          model: 'sale.order',
          method: 'action_confirm',
          ids: const [42],
          kwargs: const {'force': true},
          context: const {
            'allowed_company_ids': [3],
          },
        );

        expect(httpClient.lastPath, '/sale.order/action_confirm');
        expect(httpClient.lastBody, {
          'force': true,
          'ids': [42],
          'context': {
            'lang': 'es_EC',
            'allowed_company_ids': [3],
          },
        });
        expect(httpClient.lastBody, isNot(contains('kwargs')));
      },
    );

    test(
      'legacy args remain explicit only when deliberately requested',
      () async {
        httpClient.responseData = {'qty_available': 8};

        await api.call(
          model: 'product.template',
          method: 'get_stock_by_warehouse',
          args: const [17, null, true],
        );

        expect(httpClient.lastBody, {
          'args': [17, null, true],
          'context': _defaultContext,
        });
      },
    );
  });

  group('CRUD recordset routing', () {
    late _RecordingCrudApi api;

    setUp(() => api = _RecordingCrudApi());

    test('read routes ids through the recordset parameter', () async {
      api.responseData = <Map<String, dynamic>>[];

      await api.read(
        model: 'res.partner',
        ids: const [7, 8],
        fields: const ['name'],
      );

      expect(api.lastIds, [7, 8]);
      expect(api.lastKwargs, {
        'fields': ['name'],
      });
      expect(api.lastKwargs, isNot(contains('ids')));
    });

    test('write routes ids through the recordset parameter', () async {
      api.responseData = true;

      await api.write(
        model: 'res.partner',
        ids: const [7, 8],
        values: const {'active': false},
      );

      expect(api.lastIds, [7, 8]);
      expect(api.lastKwargs, {
        'vals': {'active': false},
      });
      expect(api.lastKwargs, isNot(contains('ids')));
    });

    test('unlink routes ids without manufacturing method kwargs', () async {
      api.responseData = true;

      await api.unlink(model: 'res.partner', ids: const [7, 8]);

      expect(api.lastIds, [7, 8]);
      expect(api.lastKwargs, isNull);
    });
  });
}

class _RecordingHttpClient implements OdooHttpClient {
  String? lastPath;
  Map<String, dynamic>? lastBody;
  dynamic responseData;

  @override
  OdooClientConfig get config => const OdooClientConfig(
    baseUrl: 'https://odoo.example.com',
    apiKey: 'test-key',
    defaultLanguage: 'es_EC',
  );

  @override
  Future<Response<dynamic>> postJson2(
    String path, {
    Map<String, dynamic>? data,
    CancelToken? cancelToken,
  }) async {
    lastPath = path;
    lastBody = data;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: responseData,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingCrudApi extends OdooCrudApi {
  _RecordingCrudApi() : super(httpClient: _RecordingHttpClient());

  List<int>? lastIds;
  Map<String, dynamic>? lastKwargs;
  dynamic responseData;

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
    CancelToken? cancelToken,
  }) async {
    lastIds = ids;
    lastKwargs = kwargs;
    return responseData;
  }
}
