import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../contracts.dart';
import '../storage/runtime_database_owner.dart';
import 'envases_partner_balance_reader.dart';

const _tableName = 'orbi_envases_saldo_terceros_cache';
const _snapshotVersion = 1;

/// A locally retrieved, read-only copy of `l10n_ec.envases.saldo.tercero`
/// (the derived per-third-party custody balance).
///
/// A non-null snapshot with zero rows is a loaded-empty balance, not an
/// unloaded one — same distinction `EnvasesMovimientosSnapshot` makes.
final class EnvasesSaldoTercerosSnapshot {
  EnvasesSaldoTercerosSnapshot({
    required Iterable<EnvasesPartnerBalanceRow> rows,
    required DateTime cachedAt,
  }) : rows = List.unmodifiable(rows),
       cachedAt = cachedAt.toUtc();

  final List<EnvasesPartnerBalanceRow> rows;
  final DateTime cachedAt;
}

final class _StoredCache {
  const _StoredCache(this.payload, this.cachedAt);
  final String payload;
  final String cachedAt;
}

/// Durable cache for `l10n_ec.envases.saldo.tercero`. Same shape as
/// `EnvasesMovimientosCache`: isolated by app scope and selected company,
/// bound to the supplied session lease, read-only — Odoo remains the sole
/// authority for the balance (it is a SQL view over `stock.move.line`,
/// never a value this app can write).
final class EnvasesSaldoTercerosCache {
  EnvasesSaldoTercerosCache({
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
      if (writing) {
        throw StateError('Envases saldo terceros cache scope is no longer active');
      }
      return null;
    }
    return active;
  }

  Future<EnvasesSaldoTercerosSnapshot?> read() async {
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
      throw StateError('Malformed envases saldo terceros cache row');
    }
    return _StoredCache(payload, columnCachedAt);
  }

  /// Watches the database row, emitting its current value and every
  /// committed replacement — the screen redraws itself once a refresh
  /// commits, without polling Odoo on every repaint.
  Stream<EnvasesSaldoTercerosSnapshot?> watch() {
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

  Future<EnvasesSaldoTercerosSnapshot> refresh(
    EnvasesPartnerBalanceReader reader,
  ) async {
    _active(writing: true);
    if (reader.company.scopeKey != _company.scopeKey ||
        reader.company.companyId != _company.companyId) {
      throw ArgumentError('Reader does not match the selected scope/company');
    }
    if (_refreshing) {
      throw StateError('Envases saldo terceros refresh already running');
    }
    _refreshing = true;
    try {
      final initialActive = _active(writing: true)!;
      final baseline = await _readStored(initialActive);
      _active(writing: true);
      // Complete the remote read before opening the write transaction. Any
      // failed or malformed fetch therefore leaves the previous copy intact.
      final rows = await reader.readPage();
      _active(writing: true);
      final active = _active(writing: true)!;
      final cachedAt = DateTime.now().toUtc();
      final snapshot = EnvasesSaldoTercerosSnapshot(
        rows: rows,
        cachedAt: cachedAt,
      );
      final payload = _encode(snapshot);
      await active.database.transaction(() async {
        _active(writing: true);
        final current = await _readStored(active);
        if (current?.payload != baseline?.payload ||
            current?.cachedAt != baseline?.cachedAt) {
          throw StateError('Envases saldo terceros cache changed during refresh');
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

  String _encode(EnvasesSaldoTercerosSnapshot snapshot) => jsonEncode({
    'version': _snapshotVersion,
    'cached_at': snapshot.cachedAt.toIso8601String(),
    'rows': snapshot.rows.map(_rowToJson).toList(growable: false),
  });

  EnvasesSaldoTercerosSnapshot _decode(
    String encoded, {
    required String expectedCachedAt,
  }) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Invalid envases saldo terceros cache payload');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (map.keys.length != 3 ||
        !map.keys.toSet().containsAll({'version', 'cached_at', 'rows'}) ||
        map['version'] != _snapshotVersion ||
        map['cached_at'] != expectedCachedAt ||
        map['cached_at'] is! String ||
        map['rows'] is! List) {
      throw const FormatException(
        'Invalid envases saldo terceros cache payload schema',
      );
    }
    final instant = DateTime.tryParse(map['cached_at'] as String);
    if (instant == null || !instant.isUtc) {
      throw const FormatException('Invalid cache timestamp');
    }
    final rows = (map['rows'] as List)
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid cached envases saldo tercero row');
          }
          return EnvasesPartnerBalanceRow.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
    final ids = <int>{};
    for (final row in rows) {
      if (!ids.add(row.id)) {
        throw const FormatException('Duplicate cached envases saldo tercero row');
      }
    }
    return EnvasesSaldoTercerosSnapshot(rows: rows, cachedAt: instant);
  }

  static Map<String, dynamic> _rowToJson(EnvasesPartnerBalanceRow row) => {
    'id': row.id,
    'location_id': [row.locationId, row.locationName],
    'warehouse_id': [row.warehouseId, row.warehouseName],
    'envases_rol': row.role,
    // `false`, no `null`: mismo cableado que Odoo manda por el JSON-2, así
    // `EnvasesPartnerBalanceRow.fromJson` lo decodifica con la misma regla
    // que un `partner_id` vacío recién llegado del servidor.
    'partner_id': row.partnerId == null ? false : [row.partnerId, row.partnerName],
    'product_id': [row.productId, row.productName],
    'company_id': [row.companyId, ''],
    'cantidad': row.quantity,
  };
}
