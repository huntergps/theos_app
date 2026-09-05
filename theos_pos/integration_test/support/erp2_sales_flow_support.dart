import 'package:odoo_sdk/odoo_sdk.dart';

import 'environment_reader.dart';

/// IDs are supplied by the ERP2 fixture owner; no business data is embedded.
final class Erp2SalesFlowIds {
  const Erp2SalesFlowIds({
    required this.cash,
    required this.credit,
    required this.mixed,
    required this.facturarSinCobro,
  });

  final int cash;
  final int credit;
  final int mixed;
  final int facturarSinCobro;

  static Erp2SalesFlowIds fromEnvironment() => Erp2SalesFlowIds(
    cash: _required('THEOS_E2E_CASH_ORDER_ID'),
    credit: _required('THEOS_E2E_CREDIT_ORDER_ID'),
    mixed: _required('THEOS_E2E_MIXED_ORDER_ID'),
    facturarSinCobro: _required('THEOS_E2E_FSC_ORDER_ID'),
  );

  static int _required(String name) {
    final value = readProcessEnvironment(name) ?? String.fromEnvironment(name);
    final id = int.tryParse(value.trim());
    if (id == null || id <= 0) {
      throw StateError('$name must be a positive ERP2 fixture ID.');
    }
    return id;
  }
}

const erp2SalesFlowFields = <String>[
  'id',
  'name',
  'client_order_ref',
  'state',
  'locked',
  'is_cash',
  'is_credit',
  'invoice_status',
  'invoice_ids',
  'picking_ids',
  'l10n_ec_collection_panel_origin',
];

Future<Map<String, dynamic>> readErp2SaleOrder(
  OdooClient client,
  int orderId,
) async {
  final rows = await client.searchRead(
    model: 'sale.order',
    domain: [
      ['id', '=', orderId],
    ],
    fields: erp2SalesFlowFields,
    limit: 1,
  );
  if (rows.length != 1) {
    throw StateError('ERP2 fixture sale.order $orderId was not found.');
  }
  return rows.single;
}

int many2oneId(Object? value) =>
    value is List ? value.first as int : value as int;

void assertErp2FixtureTag(Map<String, dynamic> order, String flow) {
  final reference = order['client_order_ref'];
  if (reference is! String ||
      !reference.startsWith('THEOS-E2E-FLOW-20260905-$flow-')) {
    throw StateError(
      'Fixture must have client_order_ref THEOS-E2E-FLOW-20260905-$flow-*.',
    );
  }
}
