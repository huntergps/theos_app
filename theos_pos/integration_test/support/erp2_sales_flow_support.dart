import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/shared/constants/user_groups.dart';

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

  static const _cashDefine = String.fromEnvironment('THEOS_E2E_CASH_ORDER_ID');
  static const _creditDefine = String.fromEnvironment(
    'THEOS_E2E_CREDIT_ORDER_ID',
  );
  static const _mixedDefine = String.fromEnvironment(
    'THEOS_E2E_MIXED_ORDER_ID',
  );
  static const _fscDefine = String.fromEnvironment('THEOS_E2E_FSC_ORDER_ID');
  static const _approvalDefine = String.fromEnvironment(
    'THEOS_E2E_FSC_APPROVAL_ID',
  );
  static const _cashSessionDefine = String.fromEnvironment(
    'THEOS_E2E_CASH_SESSION_ID',
  );
  static const _cashJournalDefine = String.fromEnvironment(
    'THEOS_E2E_CASH_JOURNAL_ID',
  );
  static const _cashMethodDefine = String.fromEnvironment(
    'THEOS_E2E_CASH_METHOD_ID',
  );

  static Erp2SalesFlowIds fromEnvironment() => Erp2SalesFlowIds(
    cash: _required('THEOS_E2E_CASH_ORDER_ID', _cashDefine),
    credit: _required('THEOS_E2E_CREDIT_ORDER_ID', _creditDefine),
    mixed: _required('THEOS_E2E_MIXED_ORDER_ID', _mixedDefine),
    facturarSinCobro: _required('THEOS_E2E_FSC_ORDER_ID', _fscDefine),
  );

  static int? optional(String name) {
    final define = switch (name) {
      'THEOS_E2E_FSC_APPROVAL_ID' => _approvalDefine,
      'THEOS_E2E_CASH_SESSION_ID' => _cashSessionDefine,
      'THEOS_E2E_CASH_JOURNAL_ID' => _cashJournalDefine,
      'THEOS_E2E_CASH_METHOD_ID' => _cashMethodDefine,
      _ => '',
    };
    final value = readProcessEnvironment(name) ?? define;
    final id = int.tryParse(value.trim());
    if (id == null || id <= 0) return null;
    return id;
  }

  static int _required(String name, String define) {
    final value = readProcessEnvironment(name) ?? define;
    final id = int.tryParse(value.trim());
    if (id == null || id <= 0) {
      throw StateError('$name must be a positive ERP2 fixture ID.');
    }
    return id;
  }
}

void validateErp2StageActor({
  required String stage,
  required int? userId,
  required int? configuredApproverUserId,
  required Iterable<String> permissions,
}) {
  final expectedUserId = switch (stage) {
    'seller' => 43,
    'cashier' => 23,
    'approver' => configuredApproverUserId,
    _ => null,
  };
  if (expectedUserId == null || userId != expectedUserId) {
    throw StateError(
      'ERP2 $stage stage requires user $expectedUserId, got $userId.',
    );
  }
  final permissionSet = permissions.toSet();
  final hasRequiredGroup = switch (stage) {
    'seller' => kSellerGroups.any(permissionSet.contains),
    'cashier' => kCashierGroups.any(permissionSet.contains),
    'approver' => permissionSet.contains(OdooUserGroup.creditApprover),
    _ => false,
  };
  if (!hasRequiredGroup) {
    throw StateError('ERP2 $stage user lacks the required Odoo group.');
  }
}

const _flowStageDefine = String.fromEnvironment('THEOS_E2E_FLOW_STAGE');

String erp2FlowStage() => parseErp2FlowStage(
  readProcessEnvironment('THEOS_E2E_FLOW_STAGE') ?? _flowStageDefine,
);

String parseErp2FlowStage(String value) {
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'seller' || 'cashier' || 'approver' => normalized,
    _ => '',
  };
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
  'exige_pago_total_entrega',
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
