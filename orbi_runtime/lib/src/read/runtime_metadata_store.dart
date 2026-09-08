import 'package:drift/drift.dart';

import '../session/session_runtime.dart';
import '../contracts.dart';

/// Small scope/lease-bound JSON metadata bridge for UI caches.
final class RuntimeMetadataStore {
  RuntimeMetadataStore(this.sessions);
  final SessionRuntime sessions;

  Future<String?> read(String key, {SessionLease? lease}) async {
    final active = sessions.active;
    if (active == null) return null;
    final expected = lease ?? active.lease;
    if (!sessions.accepts(expected)) return null;
    final rows = await active.database.database
        .customSelect(
          'SELECT value FROM sync_metadata WHERE key = ?',
          variables: [Variable<String>(key)],
        )
        .get();
    if (!sessions.accepts(expected)) return null;
    return rows.isEmpty ? null : rows.first.data['value'] as String?;
  }

  Future<void> write(
    String key,
    String value, {
    required SessionLease lease,
  }) async {
    final active = sessions.active;
    if (active == null || !sessions.accepts(lease)) {
      throw StateError('Session lease is no longer active');
    }
    await active.database.database.customStatement(
      'INSERT OR REPLACE INTO sync_metadata (key, value) VALUES (?, ?)',
      [key, value],
    );
    if (!sessions.accepts(lease)) {
      throw StateError('Session lease changed while writing metadata');
    }
  }
}
