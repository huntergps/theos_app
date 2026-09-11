import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_partner_balance_reader.dart';

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
  Map<String, dynamic> row({int companyId = 4}) => {
    'id': 1,
    'location_id': [8, 'Custodia'],
    'warehouse_id': [3, 'Bodega'],
    'envases_rol': 'custodia_cliente',
    'partner_id': [20, 'Cliente'],
    'product_id': [10, 'Jaba'],
    'company_id': [companyId, 'Empresa'],
    'cantidad': 4.0,
  };
  test(
    'requests verified view fields, filters, context and deterministic order',
    () async {
      String? capturedModel;
      List<dynamic>? capturedDomain;
      List<String>? capturedFields;
      Map<String, dynamic>? capturedContext;
      String? capturedOrder;
      final reader = EnvasesPartnerBalanceReader(
        company: company(4),
        partnerId: 20,
        productId: 10,
        role: 'custodia_cliente',
        transport:
            ({
              required String model,
              required List<dynamic> domain,
              required List<String> fields,
              required Map<String, dynamic> context,
              required limit,
              required offset,
              required String order,
            }) async {
              capturedModel = model;
              capturedDomain = domain;
              capturedFields = fields;
              capturedContext = context;
              capturedOrder = order;
              expect(limit, 100);
              expect(offset, 0);
              return [row()];
            },
      );
      final result = await reader.readPage();
      expect(capturedModel, 'l10n_ec.envases.saldo.tercero');
      expect(capturedFields, EnvasesPartnerBalanceReader.fields);
      expect(capturedDomain, [
        ['company_id', '=', 4],
        ['partner_id', '=', 20],
        ['product_id', '=', 10],
        ['envases_rol', '=', 'custodia_cliente'],
      ]);
      expect(capturedContext, {
        'allowed_company_ids': [4],
        'company_id': 4,
      });
      expect(capturedOrder, EnvasesPartnerBalanceReader.order);
      expect(result.single.quantity, 4);
      expect(result.single.partnerId, 20);
    },
  );
  test('rejects a response row from another company', () async {
    final reader = EnvasesPartnerBalanceReader(
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
    expect(reader.readPage, throwsStateError);
  });
  test('strictly rejects malformed rows and invalid filters', () async {
    expect(
      () => EnvasesPartnerBalanceReader(
        company: company(4),
        limit: 0,
        transport: _empty,
      ),
      throwsArgumentError,
    );
    final reader = EnvasesPartnerBalanceReader(
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
            {...row(), 'cantidad': null},
          ],
    );
    expect(reader.readPage, throwsFormatException);
  });
  test('does not use quant partner grouping', () {
    expect(
      EnvasesPartnerBalanceReader.fields,
      isNot(contains('envases_partner_id')),
    );
    expect(EnvasesPartnerBalanceReader.model, isNot(contains('stock.quant')));
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
