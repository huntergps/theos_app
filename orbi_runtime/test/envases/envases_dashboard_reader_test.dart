import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_dashboard_reader.dart';

void main() {
  final scope = AppScope(
    appId: 'orbi',
    installationId: 'install-1',
    normalizedServerUrl: 'https://odoo.example',
    database: 'db',
    userId: 7,
  );

  CompanyContext company() => CompanyContext.forScope(
    scope: scope,
    companyId: 4,
    allowedCompanyIds: [4, 9],
    capabilityRevision: 1,
  );

  Map<String, dynamic> row({int id = 11, Object? total = 12.0}) => {
    'id': id,
    'product_id': [101, 'Botella'],
    'uom_id': [1, 'Unidades'],
    'company_id': [4, 'Empresa A'],
    'total_propio': total,
    'en_sede': 8.0,
    'danados': 1.0,
    'en_custodia_cliente': 2.0,
    'en_custodia_proveedor': 1.0,
    'en_transito': 0.0,
  };

  test(
    'requests real panel model, fields, company domain and context',
    () async {
      String? capturedModel;
      List<dynamic>? capturedDomain;
      List<String>? capturedFields;
      Map<String, dynamic>? capturedContext;
      final reader = EnvasesDashboardReader(
        company: company(),
        pageSize: 20,
        transport:
            ({
              required String model,
              required List<dynamic> domain,
              required List<String> fields,
              required Map<String, dynamic> context,
              required int limit,
              required int offset,
              required String order,
            }) async {
              capturedModel = model;
              capturedDomain = domain;
              capturedFields = fields;
              capturedContext = context;
              expect(limit, 20);
              expect(offset, 0);
              expect(order, 'product_id asc,company_id asc,id asc');
              return [row()];
            },
      );

      final rows = await reader.readPage();

      expect(capturedModel, 'l10n_ec.envases.panel');
      expect(capturedDomain, [
        ['company_id', '=', 4],
      ]);
      expect(capturedFields, EnvasesDashboardReader.fields);
      expect(capturedContext, {
        'allowed_company_ids': [4],
        'company_id': 4,
      });
      expect(rows.single.totalPropio, 12.0);
      expect(rows.single.productId, 101);
    },
  );

  test('paginates deterministically without summing products', () async {
    final offsets = <int>[];
    final reader = EnvasesDashboardReader(
      company: company(),
      pageSize: 1,
      transport:
          ({
            required String model,
            required List<dynamic> domain,
            required List<String> fields,
            required Map<String, dynamic> context,
            required int limit,
            required int offset,
            required String order,
          }) async {
            offsets.add(offset);
            if (offset == 0) return [row(id: 11)];
            if (offset == 1) {
              return [
                {
                  ...row(id: 12, total: 3),
                  'product_id': [102, 'Jaba'],
                },
              ];
            }
            return [];
          },
    );

    final rows = await reader.readPage();
    expect(rows.single.totalPropio, 12.0);
    expect(offsets, [0]);
    final all = await reader.readAll();
    expect(all.map((item) => item.id), [11, 12]);
    expect(offsets, [0, 0, 1, 2]);
  });

  test('rejects corrupt schema instead of defaulting to zero', () async {
    final reader = EnvasesDashboardReader(
      company: company(),
      transport: ({
        required String model,
        required List<dynamic> domain,
        required List<String> fields,
        required Map<String, dynamic> context,
        required int limit,
        required int offset,
        required String order,
      }) async => [row(total: null)],
    );

    expect(reader.readPage, throwsFormatException);
  });

  test('rejects rows from another company', () async {
    final reader = EnvasesDashboardReader(
      company: company(),
      transport:
          ({
            required String model,
            required List<dynamic> domain,
            required List<String> fields,
            required Map<String, dynamic> context,
            required int limit,
            required int offset,
            required String order,
          }) async => [
            {
              ...row(),
              'company_id': [9, 'Empresa B'],
            },
          ],
    );
    expect(reader.readPage, throwsStateError);
  });

  test('rejects invalid page size and bounded readAll', () async {
    expect(
      () => EnvasesDashboardReader(
        company: company(),
        pageSize: 0,
        transport: _emptyTransport,
      ),
      throwsArgumentError,
    );
    expect(
      () => EnvasesDashboardReader(
        company: company(),
        pageSize: 501,
        transport: _emptyTransport,
      ),
      throwsArgumentError,
    );

    final reader = EnvasesDashboardReader(
      company: company(),
      pageSize: 1,
      maxPages: 2,
      transport: ({
        required String model,
        required List<dynamic> domain,
        required List<String> fields,
        required Map<String, dynamic> context,
        required int limit,
        required int offset,
        required String order,
      }) async => [row(id: offset + 1)],
    );
    expect(reader.readAll, throwsStateError);
  });

  test('rejects repeated product/company rows across pages', () async {
    final reader = EnvasesDashboardReader(
      company: company(),
      pageSize: 1,
      transport: ({
        required String model,
        required List<dynamic> domain,
        required List<String> fields,
        required Map<String, dynamic> context,
        required int limit,
        required int offset,
        required String order,
      }) async => [row(id: offset + 1)],
    );
    expect(reader.readAll, throwsStateError);
  });
}

Future<List<Map<String, dynamic>>> _emptyTransport({
  required String model,
  required List<dynamic> domain,
  required List<String> fields,
  required Map<String, dynamic> context,
  required int limit,
  required int offset,
  required String order,
}) async => [];
