import 'operation_outcome.dart';

/// Pure capability materializer. Transport adapters supply the exact Odoo
/// reads/calls; this layer never infers authorization from UI roles.
abstract final class CapabilityProvisioner {
  static CapabilitySnapshot materialize({
    required String scopeKey,
    required int companyId,
    int? pointId,
    required int revision,
    required DateTime fetchedAt,
    required Iterable<int> allGroupIds,
    required Map<int, String> externalIds,
    required bool Function(String externalId) hasGroup,
    Iterable<String> offlineOperations = const [],
  }) {
    final ids = allGroupIds.toSet();
    if (ids.any((id) => id <= 0))
      throw const FormatException('Invalid group IDs');
    final effective = externalIds.entries
        .where((entry) => ids.contains(entry.key) && hasGroup(entry.value))
        .map((entry) => entry.value)
        .toSet();
    final canViewAllOrders = _any(effective, const [
      'view_all',
      'orders.view_all',
      'sales_team.group_sale_salesman_all_leads',
      'sales_team.group_sale_manager',
    ]);
    final permissions = <String>{
      if (_any(effective, const [
        'salesman',
        'seller',
        'sales_team.group_sale_salesman',
        'sales_team.group_sale_salesman_all_leads',
        'sales_team.group_sale_manager',
      ]))
        'seller',
      if (_any(effective, const [
        'cashier',
        'collection_box',
        'l10n_ec_collection_box.group_collection_user',
        'l10n_ec_collection_box.group_collection_manager',
      ]))
        'cashier',
      if (_any(effective, const [
        'approver',
        'sales_manager',
        'approvals.group_approval_manager',
        'l10n_ec_base.group_view_approvals_manager',
        'l10n_ec_sale_credit.group_credit_approver',
      ]))
        'approver',
      if (canViewAllOrders) 'view_all',
      if (canViewAllOrders) 'orders.view_all',
    };
    return CapabilitySnapshot(
      scopeKey: scopeKey,
      companyId: companyId,
      pointId: pointId,
      revision: revision,
      fetchedAt: fetchedAt,
      permissions: permissions,
      offlineOperations: offlineOperations,
    );
  }

  static bool _any(Set<String> values, List<String> names) => names.any(
    (name) => values.any(
      (value) =>
          value == name || (!name.contains('.') && value.endsWith('.$name')),
    ),
  );
}
