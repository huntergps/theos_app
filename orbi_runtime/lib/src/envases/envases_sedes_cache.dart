import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../contracts.dart';
import '../storage/runtime_database_owner.dart';
import 'envases_sedes_reader.dart';

const _tableName = 'orbi_envases_sedes_cache';
const _snapshotVersion = 1;

/// A locally retrieved, read-only copy of the two sede lists the "Enviar"
/// form needs. `null` from [EnvasesSedesCache.read] means no copy has been
/// retrieved yet; a non-null snapshot with empty lists is a loaded-empty
/// result (no sedes configured yet), not an unloaded one.
final class EnvasesSedesSnapshot {
  EnvasesSedesSnapshot({required this.propias, required this.posibles, required DateTime cachedAt})
    : cachedAt = cachedAt.toUtc();

  final List<EnvasesSedeRow> propias;
  final List<EnvasesSedeRow> posibles;
  final DateTime cachedAt;
}

final class _StoredCache {
  const _StoredCache(this.payload, this.cachedAt);
  final String payload;
  final String cachedAt;
}

/// Durable cache for the two sede lists the "Enviar" form needs
/// (`res.users.envases_warehouse_ids` y `stock.warehouse` con
/// `controla_envases`). Same shape and reasoning as `EnvasesPorRecibirCache`:
/// isolated by app scope and selected company, bound to the supplied
/// session lease, read-only.
final class EnvasesSedesCache {
  EnvasesSedesCache({required this._owner, required this._lease, required this._company}) {
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
      if (writing) throw StateError('Envases sedes cache scope is no longer active');
      return null;
    }
    return active;
  }

  Future<EnvasesSedesSnapshot?> read() async {
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
      throw StateError('Malformed envases sedes cache row');
    }
    return _StoredCache(payload, columnCachedAt);
  }

  Stream<EnvasesSedesSnapshot?> watch() {
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

  Future<EnvasesSedesSnapshot> refresh(EnvasesSedesReader reader) async {
    _active(writing: true);
    if (reader.company.scopeKey != _company.scopeKey || reader.company.companyId != _company.companyId) {
      throw ArgumentError('Reader does not match the selected scope/company');
    }
    if (_refreshing) {
      throw StateError('Envases sedes refresh already running');
    }
    _refreshing = true;
    try {
      final initialActive = _active(writing: true)!;
      final baseline = await _readStored(initialActive);
      _active(writing: true);
      final result = await reader.leer();
      _active(writing: true);
      final active = _active(writing: true)!;
      final cachedAt = DateTime.now().toUtc();
      final snapshot = EnvasesSedesSnapshot(propias: result.propias, posibles: result.posibles, cachedAt: cachedAt);
      final payload = _encode(snapshot);
      await active.database.transaction(() async {
        _active(writing: true);
        final current = await _readStored(active);
        if (current?.payload != baseline?.payload || current?.cachedAt != baseline?.cachedAt) {
          throw StateError('Envases sedes cache changed during refresh');
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

  String _encode(EnvasesSedesSnapshot snapshot) => jsonEncode({
    'version': _snapshotVersion,
    'cached_at': snapshot.cachedAt.toIso8601String(),
    'propias': snapshot.propias.map(_sedeToJson).toList(growable: false),
    'posibles': snapshot.posibles.map(_sedeToJson).toList(growable: false),
  });

  EnvasesSedesSnapshot _decode(String encoded, {required String expectedCachedAt}) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Invalid envases sedes cache payload');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (map.keys.length != 4 ||
        !map.keys.toSet().containsAll({'version', 'cached_at', 'propias', 'posibles'}) ||
        map['version'] != _snapshotVersion ||
        map['cached_at'] != expectedCachedAt ||
        map['cached_at'] is! String ||
        map['propias'] is! List ||
        map['posibles'] is! List) {
      throw const FormatException('Invalid envases sedes cache payload schema');
    }
    final instant = DateTime.tryParse(map['cached_at'] as String);
    if (instant == null || !instant.isUtc) {
      throw const FormatException('Invalid cache timestamp');
    }
    return EnvasesSedesSnapshot(
      propias: (map['propias'] as List).map(_sedeFromJson).toList(growable: false),
      posibles: (map['posibles'] as List).map(_sedeFromJson).toList(growable: false),
      cachedAt: instant,
    );
  }

  static Map<String, dynamic> _sedeToJson(EnvasesSedeRow sede) => {'id': sede.id, 'name': sede.name};

  static EnvasesSedeRow _sedeFromJson(dynamic item) {
    if (item is! Map) throw const FormatException('Invalid cached sede row');
    final map = Map<String, dynamic>.from(item);
    final id = map['id'];
    final name = map['name'];
    if (id is! int || id <= 0 || name is! String) {
      throw const FormatException('Invalid cached sede row schema');
    }
    return EnvasesSedeRow(id: id, name: name);
  }
}
