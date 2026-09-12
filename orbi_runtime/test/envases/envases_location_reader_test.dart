import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_location_reader.dart';

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
  Map<String, dynamic> row({int companyId = 4, int id = 1}) => {
    'id': id,
    'product_id': [10, 'Jaba'],
    'uom_id': [2, 'Unidad'],
    'location_id': [8, 'GYE Envases'],
    'warehouse_id': [3, 'Guayaquil'],
    'company_id': [companyId, 'Empresa'],
    'envases_rol': 'transito',
    'envases_origen_id': [3, 'Guayaquil'],
    'envases_destino_id': [4, 'Galápagos'],
    'quantity': 5.0,
  };

  test(
    'requests exact stock.quant domain, fields and transit direction',
    () async {
      List<dynamic>? capturedDomain;
      final reader = EnvasesLocationReader(
        company: company(4),
        productId: 10,
        role: 'transito',
        originWarehouseId: 3,
        destinationWarehouseId: 4,
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
              expect(fields, EnvasesLocationReader.fields);
              expect(context, {
                'allowed_company_ids': [4],
                'company_id': 4,
              });
              expect(limit, 100);
              expect(offset, 0);
              expect(order, EnvasesLocationReader.order);
              return [row()];
            },
      );
      final result = await reader.readPage();
      expect(capturedDomain, [
        [
          'location_id.usage',
          'in',
          ['internal', 'transit'],
        ],
        ['location_id.envases_rol', '!=', false],
        ['company_id', '=', 4],
        ['product_id', '=', 10],
        ['envases_origen_id', '=', 3],
        ['envases_destino_id', '=', 4],
        ['envases_rol', '=', 'transito'],
      ]);
      expect(result.single.originWarehouseName, 'Guayaquil');
      expect(result.single.destinationWarehouseId, 4);
    },
  );

  test(
    'enforces company scope and accepts false/null optional directions',
    () async {
      final reader = EnvasesLocationReader(
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
              {
                ...row(),
                'envases_origen_id': false,
                'envases_destino_id': null,
              },
            ],
      );
      final result = await reader.readPage();
      expect(result.single.originWarehouseId, isNull);
      expect(result.single.destinationWarehouseId, isNull);

      final escaped = EnvasesLocationReader(
        company: company(4),
        transport: ({
          required model,
          required domain,
          required fields,
          required context,
          required limit,
          required offset,
          required order,
        }) async => [row(companyId: 9)],
      );
      expect(escaped.readPage, throwsStateError);
    },
  );

  test('readAll is bounded, paged and rejects duplicate quant rows', () async {
    var calls = 0;
    final reader = EnvasesLocationReader(
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

    final duplicate = EnvasesLocationReader(
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

  test(
    'strictly rejects malformed required values and invalid filters',
    () async {
      expect(
        () => EnvasesLocationReader(
          company: company(4),
          role: 'unknown',
          transport: _empty,
        ),
        throwsArgumentError,
      );
      final malformed = EnvasesLocationReader(
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
              {...row(), 'quantity': null},
            ],
      );
      expect(malformed.readPage, throwsFormatException);
    },
  );
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
