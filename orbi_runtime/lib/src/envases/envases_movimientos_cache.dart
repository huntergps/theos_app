import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../contracts.dart';
import '../storage/runtime_database_owner.dart';
import 'envases_movimientos_reader.dart';

const _tableName = 'orbi_envases_movimientos_cache';
const _snapshotVersion = 1;

/// A locally retrieved, read-only copy of `envases_movimientos()`.
///
/// Always the default (no `desde`/`hasta`) window a refresh downloads — the
/// screen's date filter narrows these already-local rows client-side while
/// offline, and only reaches Odoo directly (bypassing this cache) when a
/// connection is available, same boundary as
/// `WarehouseExistencesFilter.apply` over `StockQuantSnapshot`.
final class EnvasesMovimientosSnapshot {
  EnvasesMovimientosSnapshot({required Iterable<EnvasesMovimientoRow> rows, required DateTime cachedAt})
    : rows = List.unmodifiable(rows),
      cachedAt = cachedAt.toUtc();

  final List<EnvasesMovimientoRow> rows;
  final DateTime cachedAt;
}

final class _StoredCache {
  const _StoredCache(this.payload, this.cachedAt);
  final String payload;
  final String cachedAt;
}

/// Durable cache for `stock.move.line.envases_movimientos()`. Same shape as
/// `EnvasesPorRecibirCache`/`EnvasesDashboardCache`: isolated by app scope
/// and selected company, bound to the supplied session lease, read-only —
/// Odoo remains the sole authority for movement history.
final class EnvasesMovimientosCache {
  EnvasesMovimientosCache({required this._owner, required this._lease, required this._company}) {
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
      if (writing) throw StateError('Envases movimientos cache scope is no longer active');
      return null;
    }
    return active;
  }

  Future<EnvasesMovimientosSnapshot?> read() async {
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
      throw StateError('Malformed envases movimientos cache row');
    }
    return _StoredCache(payload, columnCachedAt);
  }

  Stream<EnvasesMovimientosSnapshot?> watch() {
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

  Future<EnvasesMovimientosSnapshot> refresh(EnvasesMovimientosReader reader) async {
    _active(writing: true);
    if (reader.company.scopeKey != _company.scopeKey || reader.company.companyId != _company.companyId) {
      throw ArgumentError('Reader does not match the selected scope/company');
    }
    if (_refreshing) {
      throw StateError('Envases movimientos refresh already running');
    }
    _refreshing = true;
    try {
      final initialActive = _active(writing: true)!;
      final baseline = await _readStored(initialActive);
      _active(writing: true);
      final rows = await reader.readAll();
      _active(writing: true);
      final active = _active(writing: true)!;
      final cachedAt = DateTime.now().toUtc();
      final snapshot = EnvasesMovimientosSnapshot(rows: rows, cachedAt: cachedAt);
      final payload = _encode(snapshot);
      await active.database.transaction(() async {
        _active(writing: true);
        final current = await _readStored(active);
        if (current?.payload != baseline?.payload || current?.cachedAt != baseline?.cachedAt) {
          throw StateError('Envases movimientos cache changed during refresh');
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

  String _encode(EnvasesMovimientosSnapshot snapshot) => jsonEncode({
    'version': _snapshotVersion,
    'cached_at': snapshot.cachedAt.toIso8601String(),
    'rows': snapshot.rows.map(_rowToJson).toList(growable: false),
  });

  EnvasesMovimientosSnapshot _decode(String encoded, {required String expectedCachedAt}) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Invalid envases movimientos cache payload');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (map.keys.length != 3 ||
        !map.keys.toSet().containsAll({'version', 'cached_at', 'rows'}) ||
        map['version'] != _snapshotVersion ||
        map['cached_at'] != expectedCachedAt ||
        map['cached_at'] is! String ||
        map['rows'] is! List) {
      throw const FormatException('Invalid envases movimientos cache payload schema');
    }
    final instant = DateTime.tryParse(map['cached_at'] as String);
    if (instant == null || !instant.isUtc) {
      throw const FormatException('Invalid cache timestamp');
    }
    final decodedRows = (map['rows'] as List)
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid cached envases movimiento row');
          }
          return EnvasesMovimientoRow.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
    final ids = <int>{};
    for (final row in decodedRows) {
      if (!ids.add(row.id)) {
        throw const FormatException('Duplicate cached envases movimiento row');
      }
    }
    return EnvasesMovimientosSnapshot(rows: decodedRows, cachedAt: instant);
  }

  static Map<String, dynamic> _rowToJson(EnvasesMovimientoRow row) => {
    'id': row.id,
    'date': _odooDatetime(row.date),
    'product_id': [row.productId, row.productName],
    'quantity': row.quantity,
    'envases_desde': row.desde ?? false,
    'envases_hacia': row.hacia ?? false,
    'envases_warehouse_id': row.warehouseId == null ? false : [row.warehouseId, row.warehouseName ?? ''],
    'envases_responsable_id': row.responsableId == null
        ? false
        : [row.responsableId, row.responsableName ?? ''],
    'picking_id': row.pickingId == null ? false : [row.pickingId, row.pickingName ?? ''],
    'envases_operacion_uuid': row.operacionUuid ?? false,
  };
}

String _odooDatetime(DateTime value) {
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
}
