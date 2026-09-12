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
    final canSynchronize = _any(effective, const [
      'administrator',
      'account.group_account_manager',
      'base.group_system',
    ]);
    final isSeller = _any(effective, const [
      'salesman',
      'seller',
      'sales_team.group_sale_salesman',
      'sales_team.group_sale_salesman_all_leads',
      'sales_team.group_sale_manager',
    ]);
    final isCashier = _any(effective, const [
      'cashier',
      'collection_box',
      'l10n_ec_collection_box.group_collection_user',
      'l10n_ec_collection_box.group_collection_manager',
    ]);
    // Envases has its own privilege in `l10n_ec_stock_envases/security/`:
    // `group_envases_user` (dashboard + entregas/devoluciones) and
    // `group_envases_manager` (implies the former, plus ajustes sensibles).
    // Odoo materializes `implied_ids` as real group membership, so a manager
    // already appears here through `group_envases_user` too; both external
    // IDs are listed for clarity, not because either is redundant to check.
    final canReadEnvases = _any(effective, const [
      'envases_read',
      'l10n_ec_stock_envases.group_envases_user',
      'l10n_ec_stock_envases.group_envases_manager',
    ]);
    // "Sistema" — Actividades y Avisos — is documented as diagnóstico
    // personal, not administración (NAVIGATION_CAPABILITY_MATRIX.md §3, fila
    // "Sistema"): it only shows the caller's own activities/notifications.
    // The real Odoo group behind "can this account even be here" is
    // `base.group_user` (Usuario interno) — every other permission this
    // provisioner emits already implies it, so granting these two from it
    // never reaches wider than someone who could already log in.
    final isInternalUser = _any(effective, const ['base.group_user']);
    final permissions = <String>{
      if (isSeller) 'seller',
      if (isCashier) 'cashier',
      if (_any(effective, const [
        'approver',
        'sales_manager',
        'approvals.group_approval_manager',
        'l10n_ec_base.group_view_approvals_manager',
        'l10n_ec_sale_credit.group_credit_approver',
      ]))
        'approver',
      if (_any(effective, const [
        'warehouse',
        'stock.group_stock_user',
        'stock.group_stock_manager',
      ]))
        'warehouse',
      if (canReadEnvases) 'envases_read',
      if (canViewAllOrders) 'view_all',
      if (canViewAllOrders) 'orders.view_all',
      if (canSynchronize) 'administrator',
      if (canSynchronize) 'sync',
      if (isInternalUser) 'activities',
      if (isInternalUser) 'notifications',
      // The `/reports/:documentId` viewer only ever renders sale-side
      // documents today (invoices/receipts — see theos_pos's reports
      // feature, wired from the sale order form and the invoice section).
      // It shows business figures, so it stays behind the same gate as
      // Ventas/Caja themselves, never wider — no independent "informes"
      // group exists to derive it from, and this repo forbids inventing one.
      if (isSeller || isCashier) 'reports',
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
