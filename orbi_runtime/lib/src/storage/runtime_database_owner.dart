import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase;

import '../contracts.dart';

typedef AppDatabaseFactory = AppDatabase Function(String databaseName);

/// Owns exactly one Drift connection for the currently active [AppScope].
final class RuntimeDatabaseOwner {
  RuntimeDatabaseOwner({AppDatabaseFactory? factory})
      : _factory = factory ?? _defaultFactory;

  final AppDatabaseFactory _factory;
  RuntimeDatabase? _active;
  int _nextGeneration = 0;
  int _openEpoch = 0;

  RuntimeDatabase? get active => _active;

  Future<RuntimeDatabase> open(AppScope scope) async {
    final requestEpoch = ++_openEpoch;
    final existing = _active;
    if (existing != null && existing.scope == scope) return existing;

    final databaseName = databaseNameFor(scope);
    final database = _factory(databaseName);
    final lease = SessionLease(scope: scope, generation: ++_nextGeneration);
    try {
      // Drift opens lazily. A real query makes the opening/migration boundary
      // observable before this owner publishes the active connection.
      await database.customSelect('SELECT 1').get();
      // Runtime-owned, additive schema: editable buffers are not commercial
      // sale orders and must never enqueue confirmation merely by being saved.
      // Keep this outside the shared POS schema/version: only Orbi opens it.
      // Future changes require explicit migrations preserving these rows.
      await database.customStatement('''
        CREATE TABLE IF NOT EXISTS orbi_editable_draft (
          scope_key TEXT NOT NULL,
          company_id INTEGER NOT NULL CHECK (company_id > 0),
          draft_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          revision INTEGER NOT NULL CHECK (revision > 0),
          PRIMARY KEY (scope_key, company_id, draft_id)
        )
      ''');
      // Read cache only: Odoo remains the authority for envases quantities.
      // A complete refresh replaces one company's snapshot atomically. The
      // timestamp is local retrieval time, never presented as server time.
      await database.customStatement('''
        CREATE TABLE IF NOT EXISTS orbi_envases_dashboard_cache (
          scope_key TEXT NOT NULL,
          company_id INTEGER NOT NULL CHECK (company_id > 0),
          payload TEXT NOT NULL,
          cached_at TEXT NOT NULL,
          PRIMARY KEY (scope_key, company_id)
        )
      ''');
    } catch (_) {
      await database.close();
      rethrow;
    }
    // A newer activation owns publication. Only close this newly-created
    // connection here; never close whatever newer scope has published.
    if (requestEpoch != _openEpoch) {
      await database.close();
      throw StateError('Database activation superseded by a newer scope');
    }
    final previous = _active;
    _active = null;
    if (previous != null) await previous.database.close();
    final opened = RuntimeDatabase(
      database: database,
      scope: scope,
      lease: lease,
      databaseName: databaseName,
    );
    _active = opened;
    return opened;
  }

  Future<void> close() async {
    ++_openEpoch;
    final current = _active;
    _active = null;
    if (current != null) await current.database.close();
  }

  bool accepts(SessionLease lease) =>
      _active?.lease == lease && lease.accepts(
            scope: _active!.scope,
            generation: _active!.lease.generation,
          );

  static String databaseNameFor(AppScope scope) {
    final digest = sha256.convert(utf8.encode(scope.scopeKey)).toString();
    return 'orbi_${digest.substring(0, 40)}';
  }

  static AppDatabase _defaultFactory(String name) =>
      AppDatabase(
        driftDatabase(
          name: name,
          web: DriftWebOptions(
            // Drift loads these with fetch()/Worker, not through Flutter's
            // AssetBundle. Web hosts must publish them beside index.html.
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.dart.js'),
          ),
        ),
      );
}

final class RuntimeDatabase {
  const RuntimeDatabase({
    required this.database,
    required this.scope,
    required this.lease,
    required this.databaseName,
  });

  final AppDatabase database;
  final AppScope scope;
  final SessionLease lease;
  final String databaseName;
}
