import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/warehouse/stock_picking_reader.dart';

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
    String code = 'outgoing',
    Object? partner = const [7, 'Cliente Uno'],
  }) => {
    'id': id,
    'name': 'WH/OUT/00042',
    'origin': 'S00099',
    'state': 'assigned',
    'scheduled_date': '2026-09-11 15:30:00',
    'location_id': [8, 'WH/Existencias'],
    'location_dest_id': [9, 'Clientes'],
    'picking_type_id': [5, 'Entregas'],
    'picking_type_code': code,
    'partner_id': partner,
    'company_id': [companyId, 'Empresa'],
  };

  test(
    'requests the verified stock.picking domain, fields and UTC-parses scheduled_date',
    () async {
      List<dynamic>? capturedDomain;
      final reader = StockPickingReader(
        company: company(4),
        pickingTypeCode: 'outgoing',
        states: const ['assigned', 'confirmed'],
        partnerId: 7,
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
              expect(model, 'stock.picking');
              capturedDomain = domain;
              expect(fields, StockPickingReader.fields);
              expect(context, {
                'allowed_company_ids': [4],
                'company_id': 4,
              });
              expect(order, StockPickingReader.order);
              return [row()];
            },
      );
      final result = await reader.readPage();
      expect(capturedDomain, [
        ['company_id', '=', 4],
        ['picking_type_code', '=', 'outgoing'],
        [
          'state',
          'in',
          ['assigned', 'confirmed'],
        ],
        ['partner_id', '=', 7],
      ]);
      final picking = result.single;
      expect(picking.pickingTypeCode, 'outgoing');
      expect(picking.scheduledDate, DateTime.utc(2026, 9, 11, 15, 30));
      expect(picking.scheduledDate.isUtc, isTrue);
      expect(picking.partnerName, 'Cliente Uno');
    },
  );

  test('accepts recepción/transferencia codes and a picking without a partner', () async {
    for (final code in const ['incoming', 'internal']) {
      final reader = StockPickingReader(
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
            }) async => [row(code: code, partner: false)],
      );
      final result = await reader.readPage();
      expect(result.single.pickingTypeCode, code);
      expect(result.single.partnerId, isNull);
    }
  });

  test('rejects an invalid picking type code filter', () {
    expect(
      () => StockPickingReader(
        company: company(4),
        pickingTypeCode: 'manufacturing',
        transport: _empty,
      ),
      throwsArgumentError,
    );
  });

  test('enforces company scope on every row', () async {
    final reader = StockPickingReader(
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

  test('readAll pages until the last short page and rejects duplicate ids', () async {
    var calls = 0;
    final reader = StockPickingReader(
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

    final duplicate = StockPickingReader(
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

  test('rejects a malformed state and an unknown picking type code from the server', () async {
    final badState = StockPickingReader(
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
            {...row(), 'state': 'unknown-state'},
          ],
    );
    expect(badState.readPage, throwsFormatException);

    final badCode = StockPickingReader(
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
            {...row(), 'picking_type_code': 'manufacturing'},
          ],
    );
    expect(badCode.readPage, throwsFormatException);
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
