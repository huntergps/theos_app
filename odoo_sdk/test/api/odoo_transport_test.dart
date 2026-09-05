@Tags(['unit'])
library;

import 'package:dio/dio.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('Json2Transport', () {
    late _RecordingCrudApi crudApi;
    late OdooTransport transport;

    setUp(() {
      crudApi = _RecordingCrudApi();
      transport = Json2Transport(crudApi: crudApi);
    });

    test('delegates searchRead without exposing JSON-2 paths', () async {
      crudApi.searchReadResponse = [
        {'id': 7, 'name': 'Ada'},
      ];

      final result = await transport.searchRead(
        model: 'res.partner',
        fields: const ['name'],
        domain: const [
          ['active', '=', true],
        ],
        limit: 10,
        offset: 5,
        order: 'name asc',
      );

      expect(result, [
        {'id': 7, 'name': 'Ada'},
      ]);
      expect(crudApi.lastModel, 'res.partner');
      expect(crudApi.lastFields, ['name']);
      expect(crudApi.lastDomain, [
        ['active', '=', true],
      ]);
      expect(crudApi.lastLimit, 10);
      expect(crudApi.lastOffset, 5);
      expect(crudApi.lastOrder, 'name asc');
    });

    test('uses an empty domain by default', () async {
      crudApi.searchReadResponse = [];

      await transport.searchRead(model: 'res.partner', fields: const ['id']);

      expect(crudApi.lastDomain, isEmpty);
    });

    test('keeps recordset ids separate from method kwargs', () async {
      crudApi.callResponse = true;

      final result = await transport.call(
        model: 'sale.order',
        method: 'action_confirm',
        ids: const [42],
        kwargs: const {'force': true},
      );

      expect(result, isTrue);
      expect(crudApi.lastModel, 'sale.order');
      expect(crudApi.lastMethod, 'action_confirm');
      expect(crudApi.lastIds, [42]);
      expect(crudApi.lastKwargs, {'force': true});
      expect(crudApi.lastKwargs, isNot(contains('ids')));
    });
  });

  group('OdooClient transport facade', () {
    test('exposes one Json2Transport while retaining crud access', () {
      final client = OdooClient(
        config: const OdooClientConfig(
          baseUrl: 'https://odoo.example.com',
          apiKey: 'test-key',
        ),
      );

      expect(client.transport, isA<Json2Transport>());
      expect(identical(client.transport, client.transport), isTrue);
      expect(client.crud, isA<OdooCrudApi>());
    });
  });
}

class _RecordingCrudApi extends OdooCrudApi {
  _RecordingCrudApi()
    : super(
        httpClient: OdooHttpClient(
          config: const OdooClientConfig(
            baseUrl: 'https://odoo.example.com',
            apiKey: 'test-key',
          ),
        ),
      );

  String? lastModel;
  String? lastMethod;
  List<String>? lastFields;
  List<dynamic>? lastDomain;
  int? lastLimit;
  int? lastOffset;
  String? lastOrder;
  List<int>? lastIds;
  Map<String, dynamic>? lastKwargs;
  List<Map<String, dynamic>> searchReadResponse = [];
  dynamic callResponse;

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
    CancelToken? cancelToken,
  }) async {
    lastModel = model;
    lastFields = fields;
    lastDomain = domain;
    lastLimit = limit;
    lastOffset = offset;
    lastOrder = order;
    return searchReadResponse;
  }

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
    lastModel = model;
    lastMethod = method;
    lastIds = ids;
    lastKwargs = kwargs;
    return callResponse;
  }
}
