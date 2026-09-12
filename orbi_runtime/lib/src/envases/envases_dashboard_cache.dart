import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../contracts.dart';
import '../storage/runtime_database_owner.dart';
import 'envases_dashboard_reader.dart';
import 'envases_location_reader.dart';

const _tableName = 'orbi_envases_dashboard_cache';
const _snapshotVersion = 2;

/// A locally retrieved, read-only copy of the Envases dashboard.
///
/// A nullable result from [EnvasesDashboardCache.read] means that no copy has
/// been retrieved yet.  A non-null snapshot may deliberately contain zero
/// rows: that is a loaded-empty dashboard, not an unloaded one.
final class EnvasesDashboardSnapshot {
  EnvasesDashboardSnapshot({
    required Iterable<EnvasesDashboardRow> rows,
    required DateTime cachedAt,
    Iterable<EnvasesLocationRow>? locations,
  }) : rows = List.unmodifiable(rows),
       locations = locations == null ? null : List.unmodifiable(locations),
       cachedAt = cachedAt.toUtc();

  final List<EnvasesDashboardRow> rows;

  /// Null means detail was not downloaded; [] means downloaded and empty.
  final List<EnvasesLocationRow>? locations;
  final DateTime cachedAt;
}

final class _StoredCache {
  const _StoredCache(this.payload, this.cachedAt);
  final String payload;
  final String cachedAt;
}

/// Durable cache for the read-only Envases dashboard query.
///
/// The cache is isolated by both the app scope and selected company, and all
/// operations are bound to the supplied session lease. It never writes stock,
/// financial, or replay/outbox records.
final class EnvasesDashboardCache {
  EnvasesDashboardCache({
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
      if (writing) throw StateError('Envases cache scope is no longer active');
      return null;
    }
    return active;
  }

  Future<EnvasesDashboardSnapshot?> read() async {
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
      throw StateError('Malformed Envases dashboard cache row');
    }
    return _StoredCache(payload, columnCachedAt);
  }

  /// Watches the database row, emitting its current value and every committed
  /// replacement. Changes are re-read from SQLite, which remains the source
  /// of truth; an empty snapshot is distinguishable from null.
  Stream<EnvasesDashboardSnapshot?> watch() {
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

  Future<EnvasesDashboardSnapshot> refresh(
    EnvasesDashboardReader reader, {
    EnvasesLocationReader? locationReader,
  }) async {
    _active(writing: true);
    if (reader.company.scopeKey != _company.scopeKey ||
        reader.company.companyId != _company.companyId) {
      throw ArgumentError('Reader does not match the selected scope/company');
    }
    if (locationReader != null &&
        (locationReader.company.scopeKey != _company.scopeKey ||
            locationReader.company.companyId != _company.companyId)) {
      throw ArgumentError(
        'Location reader does not match the selected scope/company',
      );
    }
    if (locationReader != null &&
        (locationReader.productId != null ||
            locationReader.locationId != null ||
            locationReader.warehouseId != null ||
            locationReader.originWarehouseId != null ||
            locationReader.destinationWarehouseId != null ||
            locationReader.role != null)) {
      throw ArgumentError('Location reader must read the complete cache scope');
    }
    if (_refreshing) {
      throw StateError('Envases dashboard refresh already running');
    }
    _refreshing = true;
    try {
      final initialActive = _active(writing: true)!;
      final baseline = await _readStored(initialActive);
      _active(writing: true);
      // Complete the remote read before opening the write transaction. Any
      // failed or malformed fetch therefore leaves the previous copy intact.
      // These are two separate remote reads, not one atomic server snapshot.
      // Persisting them together only makes the local replacement atomic.
      final rows = await reader.readAll();
      _active(writing: true);
      final locations = locationReader == null
          ? null
          : await locationReader.readAll();
      _active(writing: true);
      final active = _active(writing: true)!;
      final cachedAt = DateTime.now().toUtc();
      final snapshot = EnvasesDashboardSnapshot(
        rows: rows,
        locations: locations,
        cachedAt: cachedAt,
      );
      final payload = _encode(snapshot);
      await active.database.transaction(() async {
        _active(writing: true);
        final current = await _readStored(active);
        if (current?.payload != baseline?.payload ||
            current?.cachedAt != baseline?.cachedAt) {
          throw StateError('Envases dashboard cache changed during refresh');
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

  String _encode(EnvasesDashboardSnapshot snapshot) => jsonEncode({
    'version': _snapshotVersion,
    'cached_at': snapshot.cachedAt.toIso8601String(),
    'rows': snapshot.rows.map(_rowToJson).toList(growable: false),
    'locations': snapshot.locations
        ?.map(_locationToJson)
        .toList(growable: false),
  });

  EnvasesDashboardSnapshot _decode(
    String encoded, {
    required String expectedCachedAt,
  }) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Invalid Envases cache payload');
    }
    final map = Map<String, dynamic>.from(decoded);
    final version = map['version'];
    if (!map.keys.toSet().containsAll({'version', 'cached_at', 'rows'}) ||
        (version != 1 && version != _snapshotVersion) ||
        map['cached_at'] != expectedCachedAt ||
        map['cached_at'] is! String ||
        map['rows'] is! List) {
      throw const FormatException('Invalid Envases cache payload schema');
    }
    final instant = DateTime.tryParse(map['cached_at'] as String);
    if (instant == null || !instant.isUtc) {
      throw const FormatException('Invalid cache timestamp');
    }
    final decodedRows = (map['rows'] as List)
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid cached Envases row');
          }
          final row = Map<String, dynamic>.from(item);
          const fields = {
            'id',
            'product_id',
            'uom_id',
            'company_id',
            'total_propio',
            'en_sede',
            'danados',
            'en_custodia_cliente',
            'en_custodia_proveedor',
            'en_transito',
          };
          if (row.keys.toSet().length != fields.length ||
              !row.keys.toSet().containsAll(fields)) {
            throw const FormatException('Invalid cached Envases row schema');
          }
          return EnvasesDashboardRow.fromJson(row);
        })
        .toList(growable: false);
    final keys = <String>{};
    for (final row in decodedRows) {
      if (row.companyId != _company.companyId) {
        throw const FormatException('Cached row escaped selected company');
      }
      if (!keys.add('${row.companyId}:${row.productId}')) {
        throw const FormatException(
          'Duplicate cached Envases product/company row',
        );
      }
    }
    List<EnvasesLocationRow>? decodedLocations;
    if (version == _snapshotVersion) {
      if (!map.keys.toSet().contains('locations') ||
          map.keys.length != 4 ||
          (map['locations'] != null && map['locations'] is! List)) {
        throw const FormatException('Invalid cached Envases locations schema');
      }
      final rawLocations = map['locations'];
      if (rawLocations is List) {
        decodedLocations = rawLocations
            .map((item) {
              if (item is! Map) {
                throw const FormatException('Invalid cached Envases location');
              }
              final location = Map<String, dynamic>.from(item);
              const fields = {
                'id',
                'product_id',
                'uom_id',
                'location_id',
                'warehouse_id',
                'company_id',
                'envases_rol',
                'envases_origen_id',
                'envases_destino_id',
                'quantity',
              };
              if (location.keys.toSet().length != fields.length ||
                  !location.keys.toSet().containsAll(fields)) {
                throw const FormatException(
                  'Invalid cached Envases location schema',
                );
              }
              return EnvasesLocationRow.fromJson(location);
            })
            .toList(growable: false);
        final ids = <int>{};
        for (final location in decodedLocations) {
          if (location.companyId != _company.companyId ||
              !ids.add(location.id)) {
            throw const FormatException(
              'Invalid duplicate or escaped cached Envases location',
            );
          }
        }
      }
    } else if (map.keys.length != 3) {
      throw const FormatException('Invalid v1 Envases cache payload schema');
    }
    return EnvasesDashboardSnapshot(
      rows: decodedRows,
      locations: decodedLocations,
      cachedAt: instant,
    );
  }

  static Map<String, dynamic> _rowToJson(EnvasesDashboardRow row) => {
    'id': row.id,
    'product_id': [row.productId, row.productName],
    'uom_id': [row.uomId, row.uomName],
    'company_id': [row.companyId, row.companyName],
    'total_propio': row.totalPropio,
    'en_sede': row.enSede,
    'danados': row.danados,
    'en_custodia_cliente': row.enCustodiaCliente,
    'en_custodia_proveedor': row.enCustodiaProveedor,
    'en_transito': row.enTransito,
  };

  static Map<String, dynamic> _locationToJson(EnvasesLocationRow row) => {
    'id': row.id,
    'product_id': [row.productId, row.productName],
    'uom_id': [row.uomId, row.uomName],
    'location_id': [row.locationId, row.locationName],
    'warehouse_id': row.warehouseId == null
        ? false
        : [row.warehouseId, row.warehouseName ?? ''],
    'company_id': [row.companyId, row.companyName],
    'envases_rol': row.role,
    'envases_origen_id': row.originWarehouseId == null
        ? false
        : [row.originWarehouseId, row.originWarehouseName ?? ''],
    'envases_destino_id': row.destinationWarehouseId == null
        ? false
        : [row.destinationWarehouseId, row.destinationWarehouseName ?? ''],
    'quantity': row.quantity,
  };
}
