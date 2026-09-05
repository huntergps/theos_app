import 'dart:convert';

import 'package:theos_pos_core/theos_pos_core.dart';

/// Enriches a batch before either sync path commits it to its scoped cache.
/// Metadata failures and malformed replies propagate; absence is not failure.
Future<List<CollectionConfig>> loadPosAppCapabilities(
  OdooClient client,
  List<CollectionConfig> configs,
) async {
  if (configs.isEmpty ||
      !await client.hasField('collection.config', 'pos_app_contract_version')) {
    return configs;
  }
  final payload = await client.call(
    model: 'collection.config',
    method: 'pos_app_capabilities',
    ids: configs.map((config) => config.id).toList(),
  );
  if (payload is! List || payload.length != configs.length) {
    throw const FormatException('Incomplete POS capability response');
  }
  final snapshots = <int, PosAppCapabilities>{};
  for (final row in payload) {
    if (row is! Map) {
      throw const FormatException('Invalid POS capabilities');
    }
    final snapshot = PosAppCapabilities.fromJson(
      Map<String, dynamic>.from(row),
    );
    if (snapshots.containsKey(snapshot.configId)) {
      throw const FormatException('Duplicate POS capability identity');
    }
    snapshots[snapshot.configId] = snapshot;
  }
  return configs.map((config) {
    final snapshot = snapshots[config.id];
    if (snapshot == null || snapshot.companyId != config.companyId) {
      throw const FormatException('POS capability scope mismatch');
    }
    return config.copyWith(
      posAppCapabilitiesJson: jsonEncode(snapshot.toJson()),
    );
  }).toList();
}
