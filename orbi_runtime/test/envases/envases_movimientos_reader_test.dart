import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_movimientos_reader.dart';

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

  Map<String, dynamic> row({int id = 1}) => {
    'id': id,
    'date': '2026-09-01 08:00:00',
    'product_id': [50, 'Jaba 12'],
    'quantity': 3.0,
    'envases_desde': 'Guayaquil - Sede',
    'envases_hacia': 'Tránsito Guayaquil → Manta',
    'envases_warehouse_id': [1, 'Guayaquil'],
    'envases_responsable_id': [9, 'Ana'],
    'picking_id': [11, 'WH2/IN/00001'],
  };

  test('requests the real method with desde/hasta/limite/desplazamiento', () async {
    Map<String, dynamic>? capturedKwargs;
    final reader = EnvasesMovimientosReader(
      company: company(),
      transport:
          ({
            required String model,
            required String method,
            required Map<String, dynamic> kwargs,
            required Map<String, dynamic> context,
          }) async {
            expect(model, 'stock.move.line');
            expect(method, 'envases_movimientos');
            capturedKwargs = kwargs;
            return [row()];
          },
    );

    final page = await reader.readPage(
      desde: DateTime.utc(2026, 9, 1),
      hasta: DateTime.utc(2026, 9, 2),
      limite: 50,
    );

    expect(capturedKwargs, {
      'desde': '2026-09-01 00:00:00',
      'hasta': '2026-09-02 00:00:00',
      'limite': 50,
      'desplazamiento': 0,
    });
    expect(page.rows.single.productName, 'Jaba 12');
    expect(page.rows.single.desde, 'Guayaquil - Sede');
    expect(page.hasMore, isFalse);
  });

  test('sends false when desde/hasta are omitted', () async {
    Map<String, dynamic>? capturedKwargs;
    final reader = EnvasesMovimientosReader(
      company: company(),
      transport: ({required model, required method, required kwargs, required context}) async {
        capturedKwargs = kwargs;
        return <dynamic>[];
      },
    );
    await reader.readPage();
    expect(capturedKwargs!['desde'], false);
    expect(capturedKwargs!['hasta'], false);
  });

  test('readAll accumulates full pages and stops on a short page', () async {
    final offsets = <int>[];
    final reader = EnvasesMovimientosReader(
      company: company(),
      transport: ({required model, required method, required kwargs, required context}) async {
        final offset = kwargs['desplazamiento'] as int;
        offsets.add(offset);
        if (offset == 0) return [row(id: 1), row(id: 2)];
        return [row(id: 3)];
      },
    );
    final rows = await reader.readAll(limite: 2);
    expect(rows.map((r) => r.id), [1, 2, 3]);
    expect(offsets, [0, 2]);
  });

  test('readAll gives up after maxPages without a short page', () async {
    final reader = EnvasesMovimientosReader(
      company: company(),
      maxPages: 2,
      transport: ({required model, required method, required kwargs, required context}) async => [row()],
    );
    expect(() => reader.readAll(limite: 1), throwsStateError);
  });

  test('rejects a malformed response shape', () async {
    final reader = EnvasesMovimientosReader(
      company: company(),
      transport: ({required model, required method, required kwargs, required context}) async => {'x': 1},
    );
    expect(reader.readPage, throwsFormatException);
  });

  test('rejects a row missing required fields', () async {
    final reader = EnvasesMovimientosReader(
      company: company(),
      transport: ({required model, required method, required kwargs, required context}) async => [
        {'id': 1, 'date': '2026-09-01 08:00:00'},
      ],
    );
    expect(reader.readPage, throwsFormatException);
  });

  test('rejects invalid limite/desplazamiento', () async {
    final reader = EnvasesMovimientosReader(
      company: company(),
      transport: ({required model, required method, required kwargs, required context}) async => [],
    );
    expect(() => reader.readPage(limite: 0), throwsArgumentError);
    expect(() => reader.readPage(desplazamiento: -1), throwsArgumentError);
  });
}
