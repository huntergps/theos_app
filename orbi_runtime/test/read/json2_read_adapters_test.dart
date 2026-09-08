import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

class _Reader implements Json2ReadPort {
  String? model;
  List<dynamic>? domain;
  int? limit;
  int? offset;
  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async {
    this.model = model;
    this.domain = domain;
    this.limit = limit;
    this.offset = offset;
    return const [
      <String, dynamic>{'id': 7, 'name': 'A'},
    ];
  }
}

void main() {
  test(
    'catalog loader uses stable cursor pagination and scoped UUID',
    () async {
      final reader = _Reader();
      final loader = RuntimeCatalogLoader(reader, pageSize: 10);
      final scope = AppScope(
        appId: 'panel',
        installationId: 'i',
        normalizedServerUrl: 'https://erp.test',
        database: 'db',
        userId: 2,
      );
      final batch = await loader.loader(RuntimeCatalogs.products)(scope, '10');
      expect(reader.model, 'product.product');
      expect(reader.offset, 10);
      expect(batch.records.single.uuid, contains(':products:7'));
      expect(batch.cursor, isNull);
    },
  );

  test('cashier pending never adds seller filter', () async {
    final reader = _Reader();
    await RuntimeOrderReader(reader).read(
      OrderQuery(
        companyId: 4,
        authorFilter: 99,
        workQueue: OrderWorkQueue.cashierPending,
      ),
    );
    expect(reader.model, 'sale.order');
    expect(
      reader.domain!.any((part) => part is List && part.contains('user_id')),
      isFalse,
    );
    expect(
      reader.domain!.any(
        (part) =>
            part is List &&
            part.length == 3 &&
            part[0] == 'state' &&
            part[2] == 'sale',
      ),
      isTrue,
    );
    expect(reader.domain, contains('|'));
    expect(
      reader.domain!.any(
        (part) =>
            part is List && part.length == 3 && part[0] == 'amount_unpaid',
      ),
      isTrue,
    );
  });

  test('misconfigured page cursor is rejected safely', () async {
    final reader = _Reader();
    final loader = RuntimeCatalogLoader(reader);
    final scope = AppScope(
      appId: 'panel',
      installationId: 'i',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 2,
    );
    final batch = await loader.loader(RuntimeCatalogs.customers)(scope, 'bad');
    expect(reader.offset, 0);
    expect(batch.records, hasLength(1));
  });
}
