import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/warehouse/stock_quant_reader.dart';

void main() {
  final scope = AppScope(
    appId: 'orbi',
    installationId: 'i',
    normalizedServerUrl: 'https://erp.test',
    database: 'db',
    userId: 1,
  );
  CompanyContext company(int id) => CompanyContext.forScope(
    scope: scope,
    companyId: id,
    allowedCompanyIds: [id],
    capabilityRevision: 1,
  );
  Map<String, dynamic> row({
    int companyId = 4,
    int id = 1,
    int productId = 10,
    int locationId = 8,
    Object? warehouse = const [3, 'Guayaquil'],
    Object? reservadoPor = false,
  }) => {
    'id': id,
    'product_id': [productId, 'Tornillo 1/4'],
    'uom_id': [2, 'Unidad'],
    'location_id': [locationId, 'GYE/Existencias'],
    'warehouse_id': warehouse,
    'company_id': [companyId, 'Empresa'],
    'quantity': 25.0,
    'reserved_quantity': 5.0,
    'available_quantity': 20.0,
    'reservado_por': reservadoPor,
  };

  test(
    'requests the verified stock.quant domain, fields and internal-location filter',
    () async {
      List<dynamic>? capturedDomain;
      final reader = StockQuantReader(
        company: company(4),
        productId: 10,
        locationId: 8,
        warehouseId: 3,
        transport:
            ({
              required model,
              required domain,
              required fields,
              required context,
              required limit,
              required offset,
              required order,
            }) async {
              expect(model, 'stock.quant');
              capturedDomain = domain;
              expect(fields, StockQuantReader.fields);
              expect(context, {
                'allowed_company_ids': [4],
                'company_id': 4,
              });
              expect(limit, 100);
              expect(offset, 0);
              expect(order, StockQuantReader.order);
              return [row()];
            },
      );
      final result = await reader.readPage();
      expect(capturedDomain, [
        ['company_id', '=', 4],
        ['location_id.usage', '=', 'internal'],
        ['product_id', '=', 10],
        ['location_id', '=', 8],
        ['warehouse_id', '=', 3],
      ]);
      expect(result.single.availableQuantity, 20.0);
      expect(result.single.reservedQuantity, 5.0);
      expect(result.single.reservedBy, isNull);
      expect(result.single.warehouseName, 'Guayaquil');
    },
  );

  test('reads reservado_por and tolerates a location without a warehouse', () async {
    final reader = StockQuantReader(
      company: company(4),
      transport:
          ({
            required model,
            required domain,
            required fields,
            required context,
            required limit,
            required offset,
            required order,
          }) async => [
            row(warehouse: false, reservadoPor: 'OUT/00042'),
          ],
    );
    final result = await reader.readPage();
    expect(result.single.warehouseId, isNull);
    expect(result.single.warehouseName, isNull);
    expect(result.single.reservedBy, 'OUT/00042');
  });

  test('enforces company scope on every row', () async {
    final reader = StockQuantReader(
      company: company(4),
      transport:
          ({
            required model,
            required domain,
            required fields,
            required context,
            required limit,
            required offset,
            required order,
          }) async => [row(companyId: 9)],
    );
    expect(reader.readPage, throwsStateError);
  });

  test('readAll pages until the last short page and rejects duplicate quant ids', () async {
    var calls = 0;
    final reader = StockQuantReader(
      company: company(4),
      pageSize: 2,
      transport:
          ({
            required model,
            required domain,
            required fields,
            required context,
            required limit,
            required offset,
            required order,
          }) async {
            calls++;
            return offset == 0 ? [row(id: 1), row(id: 2)] : [row(id: 3)];
          },
    );
    final rows = await reader.readAll();
    expect(rows.map((r) => r.id), [1, 2, 3]);
    expect(calls, 2);

    final duplicate = StockQuantReader(
      company: company(4),
      transport: ({
        required model,
        required domain,
        required fields,
        required context,
        required limit,
        required offset,
        required order,
      }) async => [row(id: 1), row(id: 1)],
    );
    expect(duplicate.readAll, throwsStateError);
  });

  test('rejects malformed numeric fields and invalid constructor filters', () {
    expect(
      () => StockQuantReader(
        company: company(4),
        productId: -1,
        transport: _empty,
      ),
      throwsArgumentError,
    );
    final malformed = StockQuantReader(
      company: company(4),
      transport:
          ({
            required model,
            required domain,
            required fields,
            required context,
            required limit,
            required offset,
            required order,
          }) async => [
            {...row(), 'available_quantity': null},
          ],
    );
    expect(malformed.readPage, throwsFormatException);
  });
}

Future<List<Map<String, dynamic>>> _empty({
  required String model,
  required List<dynamic> domain,
  required List<String> fields,
  required Map<String, dynamic> context,
  required int limit,
  required int offset,
  required String order,
}) async => [];
