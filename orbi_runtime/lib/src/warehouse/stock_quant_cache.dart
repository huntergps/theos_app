import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../contracts.dart';
import '../storage/runtime_database_owner.dart';
import 'stock_quant_reader.dart';

const _tableName = 'orbi_stock_quant_cache';
const _snapshotVersion = 1;

/// A locally retrieved, read-only copy of `stock.quant` for one company.
///
/// A nullable result from [StockQuantCache.read] means that no copy has been
/// retrieved yet. A non-null snapshot may deliberately contain zero rows:
/// that is a loaded-empty result (no on-hand existences), not an unloaded
/// one.
final class StockQuantSnapshot {
  StockQuantSnapshot({required Iterable<StockQuantRow> rows, required DateTime cachedAt})
    : rows = List.unmodifiable(rows),
      cachedAt = cachedAt.toUtc();

  final List<StockQuantRow> rows;
  final DateTime cachedAt;
}

final class _StoredCache {
  const _StoredCache(this.payload, this.cachedAt);
  final String payload;
  final String cachedAt;
}

/// Durable cache for the read-only `stock.quant` query backing BOD-01
/// (existences), and read by BOD-02/BOD-03 to show what is on hand before an
/// operation. Same shape and same reasoning as `EnvasesDashboardCache`: a
/// dedicated table (`orbi_stock_quant_cache`, created in
/// `RuntimeDatabaseOwner.open`) rather than the generic `sync_metadata`
/// key/value bridge, specifically so screens can `watch()` this row and
/// refresh themselves the moment a sync completes — without polling the
/// server on every repaint.
///
/// The cache is isolated by both the app scope and selected company, and all
/// operations are bound to the supplied session lease. It never writes
/// stock, financial, or replay/outbox records — Odoo remains the sole
/// authority for on-hand quantities.
final class StockQuantCache {
  StockQuantCache({
    required this._owner,
    required this._lease,
    required this._company,
  }) {
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
      if (writing) throw StateError('Stock quant cache scope is no longer active');
      return null;
    }
    return active;
  }

  Future<StockQuantSnapshot?> read() async {
    final active = _active(writing: false);
    if (active == null) return null;
    final stored = await _readStored(active);
    if (_active(writing: false) == null || stored == null) return null;
    return _decode(stored.payload, expectedCachedAt: stored.cachedAt);
  }

  Future<_StoredCache?> _readStored(RuntimeDatabase active) async {
    final result = await active.database
        .customSelect(
          'SELECT payload, cached_at FROM $_tableName '
          'WHERE scope_key = ? AND company_id = ?',
          variables: [
            Variable<String>(_company.scopeKey),
            Variable<int>(_company.companyId),
          ],
        )
        .get();
    if (result.isEmpty) return null;
    final data = result.first.data;
    final payload = data['payload'];
    final columnCachedAt = data['cached_at'];
    if (payload is! String || columnCachedAt is! String) {
      throw StateError('Malformed stock.quant cache row');
    }
    return _StoredCache(payload, columnCachedAt);
  }

  /// Watches the database row, emitting its current value and every
  /// committed replacement. Changes are re-read from SQLite, which remains
  /// the source of truth; an empty snapshot is distinguishable from null.
  /// This is what lets a BOD-01/02/03 screen react to a sync completing
  /// without polling Odoo on every repaint.
  Stream<StockQuantSnapshot?> watch() {
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
        pending = pending.then((_) => emit()).catchError((
          Object error,
          StackTrace stack,
        ) {
          if (!closed) controller.addError(error, stack);
        });
      }

      final updates = active.database
          .tableUpdates(const TableUpdateQuery.onTableName(_tableName))
          .listen(
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

  Future<StockQuantSnapshot> refresh(StockQuantReader reader) async {
    _active(writing: true);
    if (reader.company.scopeKey != _company.scopeKey ||
        reader.company.companyId != _company.companyId) {
      throw ArgumentError('Reader does not match the selected scope/company');
    }
    if (reader.productId != null ||
        reader.locationId != null ||
        reader.warehouseId != null) {
      throw ArgumentError('Cache refresh reader must read the complete company scope');
    }
    if (_refreshing) {
      throw StateError('stock.quant refresh already running');
    }
    _refreshing = true;
    try {
      final initialActive = _active(writing: true)!;
      final baseline = await _readStored(initialActive);
      _active(writing: true);
      // Complete the remote read before opening the write transaction. A
      // failed or malformed fetch therefore leaves the previous copy intact.
      final rows = await reader.readAll();
      _active(writing: true);
      final active = _active(writing: true)!;
      final cachedAt = DateTime.now().toUtc();
      final snapshot = StockQuantSnapshot(rows: rows, cachedAt: cachedAt);
      final payload = _encode(snapshot);
      await active.database.transaction(() async {
        _active(writing: true);
        final current = await _readStored(active);
        if (current?.payload != baseline?.payload ||
            current?.cachedAt != baseline?.cachedAt) {
          throw StateError('stock.quant cache changed during refresh');
        }
        await active.database.customInsert(
          'INSERT OR REPLACE INTO $_tableName '
          '(scope_key, company_id, payload, cached_at) VALUES (?, ?, ?, ?)',
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

  String _encode(StockQuantSnapshot snapshot) => jsonEncode({
    'version': _snapshotVersion,
    'cached_at': snapshot.cachedAt.toIso8601String(),
    'rows': snapshot.rows.map(_rowToJson).toList(growable: false),
  });

  StockQuantSnapshot _decode(String encoded, {required String expectedCachedAt}) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Invalid stock.quant cache payload');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (map.keys.length != 3 ||
        !map.keys.toSet().containsAll({'version', 'cached_at', 'rows'}) ||
        map['version'] != _snapshotVersion ||
        map['cached_at'] != expectedCachedAt ||
        map['cached_at'] is! String ||
        map['rows'] is! List) {
      throw const FormatException('Invalid stock.quant cache payload schema');
    }
    final instant = DateTime.tryParse(map['cached_at'] as String);
    if (instant == null || !instant.isUtc) {
      throw const FormatException('Invalid cache timestamp');
    }
    final decodedRows = (map['rows'] as List)
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid cached stock.quant row');
          }
          final row = Map<String, dynamic>.from(item);
          const fields = {
            'id',
            'product_id',
            'uom_id',
            'location_id',
            'warehouse_id',
            'company_id',
            'quantity',
            'reserved_quantity',
            'available_quantity',
            'reservado_por',
          };
          if (row.keys.toSet().length != fields.length ||
              !row.keys.toSet().containsAll(fields)) {
            throw const FormatException('Invalid cached stock.quant row schema');
          }
          return StockQuantRow.fromJson(row);
        })
        .toList(growable: false);
    final ids = <int>{};
    for (final row in decodedRows) {
      if (row.companyId != _company.companyId || !ids.add(row.id)) {
        throw const FormatException(
          'Invalid duplicate or escaped cached stock.quant row',
        );
      }
    }
    return StockQuantSnapshot(rows: decodedRows, cachedAt: instant);
  }

  static Map<String, dynamic> _rowToJson(StockQuantRow row) => {
    'id': row.id,
    'product_id': [row.productId, row.productName],
    'uom_id': [row.uomId, row.uomName],
    'location_id': [row.locationId, row.locationName],
    'warehouse_id': row.warehouseId == null
        ? false
        : [row.warehouseId, row.warehouseName ?? ''],
    'company_id': [row.companyId, row.companyName],
    'quantity': row.quantity,
    'reserved_quantity': row.reservedQuantity,
    'available_quantity': row.availableQuantity,
    'reservado_por': row.reservedBy ?? false,
  };
}
