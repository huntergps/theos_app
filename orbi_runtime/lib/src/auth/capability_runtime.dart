import 'package:theos_pos_core/theos_pos_core.dart';

import '../contracts.dart';
import 'native_auth_service.dart';

/// JSON-2 adapter for the capability materializer. All calls are scoped to
/// the activated user; failures propagate and never publish a partial snapshot.
final class OdooCapabilityReader {
  final OdooClient client;
  const OdooCapabilityReader(this.client);

  static const envasesUserGroup = 'l10n_ec_stock_envases.group_envases_user';
  static const envasesManagerGroup =
      'l10n_ec_stock_envases.group_envases_manager';

  static bool hasEnvasesRead(Iterable<String> effectiveExternalIds) =>
      effectiveExternalIds.contains(envasesUserGroup) ||
      effectiveExternalIds.contains(envasesManagerGroup);

  /// "Supervisor de Caja" — `l10n_ec_collection_box.group_collection_manager`
  /// (`l10n_ec_collection_box/security/collection_box_groups.xml:96-101`).
  /// `CapabilityProvisioner.materialize` (theos_pos_core) already folds this
  /// group into the shared `cashier` permission — it implies
  /// `group_collection_user`, so a supervisor keeps every cashier screen —
  /// but that merge loses the distinction a supervisor-only feature needs
  /// (opening ANOTHER cashier's turn, `collection_session_manager_rule` /
  /// `collection_session_all_manager_rule`,
  /// `l10n_ec_collection_box/security/collection_box_rules.xml:24-31,159-165`,
  /// unrestricted `crud` domain). Materialized here, the same way
  /// `hasEnvasesRead` is, instead of touching `theos_pos_core` for a flag
  /// that only this app's supervisor-overview feature reads.
  static bool hasCollectionSupervisor(Iterable<String> effectiveExternalIds) =>
      effectiveExternalIds.contains(
        'l10n_ec_collection_box.group_collection_manager',
      );

  Future<CapabilitySnapshot> read({
    required AppScope scope,
    required int companyId,
    int? pointId,
    required int revision,
    Iterable<String> offlineOperations = const [],
  }) async {
    final rows = await client.read(
      model: 'res.users',
      ids: [scope.userId],
      fields: ['id', 'all_group_ids'],
    );
    if (rows.length != 1 || rows.single['id'] != scope.userId) {
      throw StateError('Capability user identity mismatch');
    }
    final raw = rows.single['all_group_ids'];
    if (raw is! List || raw.any((id) => id is! int || id <= 0)) {
      throw FormatException('Invalid all_group_ids');
    }
    final ids = raw.cast<int>();
    final result = await client.call(
      model: 'res.groups',
      method: 'get_external_id',
      ids: ids,
    );
    if (result is! Map) throw FormatException('Invalid group external IDs');
    final external = <int, String>{};
    for (final entry in result.entries) {
      final id = int.tryParse(entry.key.toString());
      if (id != null && entry.value is String) {
        external[id] = entry.value as String;
      }
    }
    // `all_group_ids` is Odoo's expanded effective membership, including
    // implied groups. Calling `has_group` once per XML ID repeated information
    // already returned by that field and made login cost O(number of groups).
    final effectiveXmlIds = external.values.toSet();
    final snapshot = CapabilityProvisioner.materialize(
      scopeKey: scope.scopeKey,
      companyId: companyId,
      pointId: pointId,
      revision: revision,
      fetchedAt: DateTime.now().toUtc(),
      allGroupIds: ids,
      externalIds: external,
      hasGroup: effectiveXmlIds.contains,
      offlineOperations: offlineOperations,
    );
    final extra = <String>{
      if (hasEnvasesRead(effectiveXmlIds)) 'envases_read',
      if (hasCollectionSupervisor(effectiveXmlIds)) 'collection_supervisor',
    };
    if (extra.isEmpty) return snapshot;
    return CapabilitySnapshot(
      scopeKey: snapshot.scopeKey,
      companyId: snapshot.companyId,
      pointId: snapshot.pointId,
      revision: snapshot.revision,
      fetchedAt: snapshot.fetchedAt,
      permissions: {...snapshot.permissions, ...extra},
      counterPolicies: snapshot.counterPolicies,
      offlineOperations: snapshot.offlineOperations,
    );
  }
}

final class OdooActiveIdentityReader implements ActiveIdentityReader {
  final OdooClient client;
  const OdooActiveIdentityReader(this.client);

  @override
  Future<
    ({
      int companyId,
      String? companyName,
      String? name,
      List<int> allowedCompanyIds,
    })
  >
  read(AppScope scope) async {
    final rows = await client.read(
      model: 'res.users',
      ids: [scope.userId],
      fields: ['id', 'name', 'company_id', 'company_ids'],
    );
    if (rows.length != 1 || rows.single['id'] != scope.userId) {
      throw StateError('Active identity mismatch');
    }
    final name = rows.single['name'];
    final userName = name is String && name.trim().isNotEmpty ? name : null;
    final company = rows.single['company_id'];
    final companyId = company is int
        ? company
        : (company is List && company.first is int
              ? company.first as int
              : null);
    // Odoo's JSON-2 `read` returns a many2one as `[id, display_name]`. The id
    // is validated above; the display name travels along in the very same
    // response — reading it here is not a second request, just no longer
    // throwing it away (`OperationalContext.companyLabel` used to show
    // "Empresa #<id>" even though the real name had already arrived).
    final companyName =
        company is List && company.length > 1 && company[1] is String
        ? company[1] as String
        : null;
    final raw = rows.single['company_ids'];
    if (companyId == null || companyId <= 0 || raw is! List) {
      throw FormatException('Invalid company identity');
    }
    final allowed = raw.whereType<int>().where((id) => id > 0).toSet().toList()
      ..sort();
    if (!allowed.contains(companyId)) {
      throw FormatException('Selected company is not allowed');
    }
    return (
      companyId: companyId,
      companyName: companyName,
      name: userName,
      allowedCompanyIds: allowed,
    );
  }
}
