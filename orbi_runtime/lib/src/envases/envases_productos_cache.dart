import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../contracts.dart';
import '../storage/runtime_database_owner.dart';
import 'envases_productos_reader.dart';

const _tableName = 'orbi_envases_productos_cache';
const _snapshotVersion = 1;

/// A locally retrieved, read-only copy of the envase products the "Enviar"
/// form may offer. `null` from [EnvasesProductosCache.read] means no copy
/// has been retrieved yet; a non-null snapshot with an empty list means no
/// product is marked `envases_es_retornable` yet, not an unloaded state.
final class EnvasesProductosSnapshot {
  EnvasesProductosSnapshot({required Iterable<EnvasesProductoRow> rows, required DateTime cachedAt})
    : rows = List.unmodifiable(rows),
      cachedAt = cachedAt.toUtc();

  final List<EnvasesProductoRow> rows;
  final DateTime cachedAt;
}

final class _StoredCache {
  const _StoredCache(this.payload, this.cachedAt);
  final String payload;
  final String cachedAt;
}

/// Durable cache for the envase product catalog the "Enviar" form offers.
/// Same shape and reasoning as `EnvasesPorRecibirCache`: isolated by app
/// scope and selected company, bound to the supplied session lease,
/// read-only — Odoo remains the sole authority for the product catalog.
final class EnvasesProductosCache {
  EnvasesProductosCache({required this._owner, required this._lease, required this._company}) {
    if (_company.scopeKey != _lease.scope.scopeKey) {
      throw ArgumentError('Company context does not belong to the lease scope');
    }
  }

  final RuntimeDatabaseOwner _owner;
  final SessionLease _lease;
  final CompanyContext _company;
  bool _refreshing = false;

  RuntimeDatabase? _active({required bool writing}) {
    final active = _owner.active;
    if (active == null || !_owner.accepts(_lease)) {
      if (writing) throw StateError('Session lease is no longer active');
      return null;
    }
    if (active.scope.scopeKey != _company.scopeKey) {
      if (writing) throw StateError('Envases productos cache scope is no longer active');
      return null;
    }
    return active;
  }

  Future<EnvasesProductosSnapshot?> read() async {
    final active = _active(writing: false);
    if (active == null) return null;
    final stored = await _readStored(active);
    if (_active(writing: false) == null || stored == null) return null;
    return _decode(stored.payload, expectedCachedAt: stored.cachedAt);
  }

  Future<_StoredCache?> _readStored(RuntimeDatabase active) async {
    final result = await active.database
        .customSelect(
          'SELECT payload, cached_at FROM $_tableName WHERE scope_key = ? AND company_id = ?',
          variables: [Variable<String>(_company.scopeKey), Variable<int>(_company.companyId)],
        )
        .get();
    if (result.isEmpty) return null;
    final data = result.first.data;
    final payload = data['payload'];
    final columnCachedAt = data['cached_at'];
    if (payload is! String || columnCachedAt is! String) {
      throw StateError('Malformed envases productos cache row');
    }
    return _StoredCache(payload, columnCachedAt);
  }

  Stream<EnvasesProductosSnapshot?> watch() {
    return Stream.multi((controller) {
      final active = _active(writing: false);
      if (active == null) {
        controller.close();
        return;
      }
      var closed = false;
      Future<void> emit() async {
        if (closed) return;
        final value = await read();
        if (!closed) controller.add(value);
      }

      var pending = Future<void>.value();
      void scheduleEmit() {
        pending = pending.then((_) => emit()).catchError((Object error, StackTrace stack) {
          if (!closed) controller.addError(error, stack);
        });
      }

      final updates = active.database.tableUpdates(const TableUpdateQuery.onTableName(_tableName)).listen(
        (_) => scheduleEmit(),
        onError: controller.addError,
        onDone: () {
          if (!closed) controller.close();
        },
      );
      controller.onCancel = () async {
        closed = true;
        await updates.cancel();
      };
      scheduleEmit();
    });
  }

  Future<EnvasesProductosSnapshot> refresh(EnvasesProductosReader reader) async {
    _active(writing: true);
    if (reader.company.scopeKey != _company.scopeKey || reader.company.companyId != _company.companyId) {
      throw ArgumentError('Reader does not match the selected scope/company');
    }
    if (_refreshing) {
      throw StateError('Envases productos refresh already running');
    }
    _refreshing = true;
    try {
      final initialActive = _active(writing: true)!;
      final baseline = await _readStored(initialActive);
      _active(writing: true);
      final rows = await reader.leer();
      _active(writing: true);
      final active = _active(writing: true)!;
      final cachedAt = DateTime.now().toUtc();
      final snapshot = EnvasesProductosSnapshot(rows: rows, cachedAt: cachedAt);
      final payload = _encode(snapshot);
      await active.database.transaction(() async {
        _active(writing: true);
        final current = await _readStored(active);
        if (current?.payload != baseline?.payload || current?.cachedAt != baseline?.cachedAt) {
          throw StateError('Envases productos cache changed during refresh');
        }
        await active.database.customInsert(
          'INSERT OR REPLACE INTO $_tableName (scope_key, company_id, payload, cached_at) VALUES (?, ?, ?, ?)',
          variables: [
            Variable<String>(_company.scopeKey),
            Variable<int>(_company.companyId),
            Variable<String>(payload),
            Variable<String>(cachedAt.toIso8601String()),
          ],
        );
      });
      active.database.notifyUpdates({const TableUpdate(_tableName)});
      _active(writing: true);
      return snapshot;
    } finally {
      _refreshing = false;
    }
  }

  String _encode(EnvasesProductosSnapshot snapshot) => jsonEncode({
    'version': _snapshotVersion,
    'cached_at': snapshot.cachedAt.toIso8601String(),
    'rows': snapshot.rows.map(_rowToJson).toList(growable: false),
  });

  EnvasesProductosSnapshot _decode(String encoded, {required String expectedCachedAt}) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Invalid envases productos cache payload');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (map.keys.length != 3 ||
        !map.keys.toSet().containsAll({'version', 'cached_at', 'rows'}) ||
        map['version'] != _snapshotVersion ||
        map['cached_at'] != expectedCachedAt ||
        map['cached_at'] is! String ||
        map['rows'] is! List) {
      throw const FormatException('Invalid envases productos cache payload schema');
    }
    final instant = DateTime.tryParse(map['cached_at'] as String);
    if (instant == null || !instant.isUtc) {
      throw const FormatException('Invalid cache timestamp');
    }
    final decodedRows = (map['rows'] as List).map((item) {
      if (item is! Map) throw const FormatException('Invalid cached envases producto row');
      final row = Map<String, dynamic>.from(item);
      const fields = {'id', 'name', 'uom_id', 'uom_name'};
      if (row.keys.toSet().length != fields.length || !row.keys.toSet().containsAll(fields)) {
        throw const FormatException('Invalid cached envases producto row schema');
      }
      final id = row['id'];
      final name = row['name'];
      final uomId = row['uom_id'];
      final uomName = row['uom_name'];
      if (id is! int || id <= 0 || name is! String || uomId is! int || uomId <= 0 || uomName is! String) {
        throw const FormatException('Invalid cached envases producto row values');
      }
      return EnvasesProductoRow(id: id, name: name, uomId: uomId, uomName: uomName);
    }).toList(growable: false);
    return EnvasesProductosSnapshot(rows: decodedRows, cachedAt: instant);
  }

  static Map<String, dynamic> _rowToJson(EnvasesProductoRow row) =>
      {'id': row.id, 'name': row.name, 'uom_id': row.uomId, 'uom_name': row.uomName};
}
