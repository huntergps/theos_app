import 'dart:convert';

import 'package:drift/drift.dart';

import '../../database/database.dart';
import 'operation_outcome.dart';

/// Scoped local snapshot cache. It is versioned and identity-bound; it is not
/// a cryptographic signature because no trusted key root exists in core.
final class CapabilitySnapshotStore {
  const CapabilitySnapshotStore(this.db);
  final AppDatabase db;

  String _key(String scopeKey) => 'capability:$scopeKey';

  Future<void> save(String scopeKey, CapabilitySnapshot snapshot) async {
    if (snapshot.scopeKey != scopeKey || snapshot.companyId <= 0) {
      throw const FormatException('Capability scope mismatch');
    }
    await db.customStatement(
      'INSERT OR REPLACE INTO sync_metadata (key, value) VALUES (?, ?)',
      [
        _key(scopeKey),
        jsonEncode({
          'version': 1,
          'scopeKey': snapshot.scopeKey,
          'companyId': snapshot.companyId,
          'pointId': snapshot.pointId,
          'revision': snapshot.revision,
          'fetchedAt': snapshot.fetchedAt.toIso8601String(),
          'permissions': snapshot.permissions.toList(),
          'counterPolicies': snapshot.counterPolicies.toList(),
          'offlineOperations': snapshot.offlineOperations.toList(),
        }),
      ],
    );
  }

  Future<CapabilitySnapshot?> read(
    String scopeKey, {
    required int companyId,
  }) async {
    final rows = await db
        .customSelect(
          'SELECT value FROM sync_metadata WHERE key = ?',
          variables: [Variable<String>(_key(scopeKey))],
        )
        .get();
    if (rows.isEmpty) return null;
    final raw = jsonDecode(rows.single.data['value'] as String);
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['scopeKey'] != scopeKey ||
        raw['companyId'] != companyId)
      return null;
    return CapabilitySnapshot(
      scopeKey: scopeKey,
      companyId: raw['companyId'] as int,
      pointId: (raw['pointId'] as num?)?.toInt(),
      revision: (raw['revision'] as num?)?.toInt() ?? 0,
      fetchedAt: DateTime.parse(raw['fetchedAt'] as String),
      permissions: (raw['permissions'] as List).cast<String>(),
      counterPolicies: (raw['counterPolicies'] as List).cast<String>(),
      offlineOperations: (raw['offlineOperations'] as List).cast<String>(),
    );
  }
}
