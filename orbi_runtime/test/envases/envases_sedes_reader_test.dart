import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_sedes_reader.dart';

void main() {
  final scope = AppScope(
    appId: 'orbi',
    installationId: 'install-1',
    normalizedServerUrl: 'https://odoo.example',
    database: 'db',
    userId: 7,
  );

  CompanyContext company() =>
      CompanyContext.forScope(scope: scope, companyId: 4, allowedCompanyIds: [4], capabilityRevision: 1);

  Map<String, dynamic> warehouseRow(int id, String name) => {'id': id, 'name': name};

  test('requests stock.warehouse with controla_envases and the company domain', () async {
    List<dynamic>? capturedDomain;
    final reader = EnvasesSedesReader(
      company: company(),
      userId: 7,
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
            if (model == 'stock.warehouse') {
              capturedDomain = domain;
              return [warehouseRow(1, 'Guayaquil')];
            }
            return [
              {'id': 7, 'envases_warehouse_ids': <int>[]},
            ];
          },
    );

    await reader.leer();

    expect(capturedDomain, [
      ['controla_envases', '=', true],
      ['company_id', '=', 4],
    ]);
  });

  test('requests the calling uid on res.users, never a different one', () async {
    List<dynamic>? capturedUserDomain;
    final reader = EnvasesSedesReader(
      company: company(),
      userId: 7,
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
            if (model == 'res.users') {
              capturedUserDomain = domain;
              return [
                {'id': 7, 'envases_warehouse_ids': <int>[]},
              ];
            }
            return [];
          },
    );

    await reader.leer();

    expect(capturedUserDomain, [
      ['id', '=', 7],
    ]);
  });

  test('a user with no sedes assigned gets an empty propias list, never all of posibles', () async {
    final reader = EnvasesSedesReader(
      company: company(),
      userId: 7,
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
            if (model == 'stock.warehouse') {
              return [warehouseRow(1, 'Guayaquil'), warehouseRow(2, 'Manta')];
            }
            return [
              {'id': 7, 'envases_warehouse_ids': false},
            ];
          },
    );

    final result = await reader.leer();

    expect(result.posibles.map((s) => s.id), [1, 2]);
    expect(result.propias, isEmpty);
  });

  test('intersects the user many2many ids against posibles, preserving posibles order', () async {
    final reader = EnvasesSedesReader(
      company: company(),
      userId: 7,
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
            if (model == 'stock.warehouse') {
              return [warehouseRow(1, 'Guayaquil'), warehouseRow(2, 'Manta'), warehouseRow(3, 'Quito')];
            }
            return [
              {
                'id': 7,
                'envases_warehouse_ids': [3, 1],
              },
            ];
          },
    );

    final result = await reader.leer();

    expect(result.propias.map((s) => s.id), [1, 3]);
  });

  test('rejects a missing res.users row for the calling uid', () async {
    final reader = EnvasesSedesReader(
      company: company(),
      userId: 7,
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
            if (model == 'stock.warehouse') return [];
            return [];
          },
    );

    expect(reader.leer, throwsStateError);
  });

  test('rejects a malformed warehouse row', () async {
    final reader = EnvasesSedesReader(
      company: company(),
      userId: 7,
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
            if (model == 'stock.warehouse') {
              return [
                {'id': 0, 'name': 'Bad'},
              ];
            }
            return [
              {'id': 7, 'envases_warehouse_ids': <int>[]},
            ];
          },
    );

    expect(reader.leer, throwsFormatException);
  });
}
