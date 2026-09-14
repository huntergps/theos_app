// ignore_for_file: prefer_initializing_formals, type_init_formals
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../contracts.dart';
import '../storage/runtime_database_owner.dart';

const _tableName = 'orbi_editable_draft';

Map<String, dynamic> _copyJsonPayload(Map<String, dynamic> payload) {
  try {
    final decoded = jsonDecode(jsonEncode(payload));
    if (decoded is! Map) {
      throw const FormatException('Payload is not an object');
    }
    return Map<String, dynamic>.from(decoded);
  } on Object catch (error) {
    throw ArgumentError('Payload must be a JSON object: $error');
  }
}

/// The identity of an editable draft.  The company is deliberately part of
/// the key: a scope can have more than one active company.
final class EditableDraftKey {
  const EditableDraftKey({
    required this.scopeKey,
    required this.companyId,
    required this.draftId,
  });

  final String scopeKey;
  final int companyId;
  final String draftId;

  @override
  bool operator ==(Object other) =>
      other is EditableDraftKey &&
      other.scopeKey == scopeKey &&
      other.companyId == companyId &&
      other.draftId == draftId;

  @override
  int get hashCode => Object.hash(scopeKey, companyId, draftId);
}

final class EditableDraftRecord {
  EditableDraftRecord({
    required this.key,
    required Map<String, dynamic> payload,
    required this.revision,
  }) : payload = _copyJsonPayload(payload);

  final EditableDraftKey key;
  final Map<String, dynamic> payload;
  final int revision;
}

/// Durable, scope- and lease-bound storage for an in-progress sale editor.
///
/// This class intentionally has no outbox behavior.  Confirming a sale is a
/// separate operation with its own transaction and synchronization semantics.
final class EditableDraftStore {
  EditableDraftStore({
    required RuntimeDatabaseOwner this._owner,
    required SessionLease this._lease,
    required CompanyContext this._company,
  }) {
    if (_company.scopeKey != _lease.scope.scopeKey) {
      throw ArgumentError('Company context does not belong to the lease scope');
    }
  }

  final RuntimeDatabaseOwner _owner;
  final SessionLease _lease;
  final CompanyContext _company;

  EditableDraftKey _key(String draftId) {
    _validateId(draftId, 'draftId');
    return EditableDraftKey(
      scopeKey: _company.scopeKey,
      companyId: _company.companyId,
      draftId: draftId,
    );
  }

  RuntimeDatabase? _checkedActive({required bool writing}) {
    final active = _owner.active;
    if (active == null || !_owner.accepts(_lease)) {
      if (writing) throw StateError('Session lease is no longer active');
      return null;
    }
    if (active.scope.scopeKey != _company.scopeKey ||
        active.scope.scopeKey != _lease.scope.scopeKey) {
      if (writing) throw StateError('Draft scope is no longer active');
      return null;
    }
    return active;
  }

  Future<EditableDraftRecord?> read(String draftId) async {
    final key = _key(draftId);
    final active = _checkedActive(writing: false);
    if (active == null) return null;
    final rows = await active.database
        .customSelect(
          'SELECT payload, revision FROM $_tableName '
          'WHERE scope_key = ? AND company_id = ? AND draft_id = ?',
          variables: _variables(key),
        )
        .get();
    if (_checkedActive(writing: false) == null || rows.isEmpty) return null;
    return _record(key, rows.first.data);
  }

  /// Reads a deterministic, company-isolated page of drafts.
  ///
  /// [afterDraftId] is an exclusive keyset cursor in ascending draft ID
  /// order. Rows are decoded strictly: malformed rows surface an error rather
  /// than being silently omitted.
  Future<List<EditableDraftRecord>> list({
    int limit = 50,
    String? afterDraftId,
  }) async {
    _validateLimit(limit);
    if (afterDraftId != null) _validateId(afterDraftId, 'afterDraftId');
    final active = _checkedActive(writing: false);
    if (active == null) return const <EditableDraftRecord>[];
    final variables = <Variable<Object>>[
      Variable<String>(_company.scopeKey),
      Variable<int>(_company.companyId),
    ];
    final cursorClause = afterDraftId == null ? '' : ' AND draft_id > ?';
    if (afterDraftId != null) variables.add(Variable<String>(afterDraftId));
    variables.add(Variable<int>(limit));
    final rows = await active.database
        .customSelect(
          'SELECT draft_id, payload, revision FROM $_tableName '
          'WHERE scope_key = ? AND company_id = ?$cursorClause '
          'ORDER BY draft_id ASC LIMIT ?',
          variables: variables,
        )
        .get();
    if (_checkedActive(writing: false) == null) return const [];
    final records = rows
        .map((row) {
          final draftId = row.data['draft_id'];
          if (draftId is! String) {
            throw StateError('Malformed editable draft ID');
          }
          return _record(
            EditableDraftKey(
              scopeKey: _company.scopeKey,
              companyId: _company.companyId,
              draftId: draftId,
            ),
            row.data,
          );
        })
        .toList(growable: false);
    return List<EditableDraftRecord>.unmodifiable(records);
  }

  Future<EditableDraftRecord> save(
    String draftId,
    Map<String, dynamic> payload, {
    required int expectedRevision,
  }) async {
    if (expectedRevision < 0) {
      throw ArgumentError.value(expectedRevision, 'expectedRevision');
    }
    final key = _key(draftId);
    final active = _checkedActive(writing: true)!;
    final snapshot = _copyJsonPayload(payload);
    final encoded = jsonEncode(snapshot);
    EditableDraftRecord? result;

    await active.database.transaction(() async {
      if (_checkedActive(writing: true) == null) {
        throw StateError('Session lease is no longer active');
      }
      final rows = await active.database
          .customSelect(
            'SELECT payload, revision FROM $_tableName '
            'WHERE scope_key = ? AND company_id = ? AND draft_id = ?',
            variables: _variables(key),
          )
          .get();
      final current = rows.isEmpty ? null : rows.first.data;
      final currentRevision = current == null ? 0 : current['revision'] as int;
      if (current != null && currentRevision != expectedRevision ||
          current == null && expectedRevision != 0) {
        throw StateError('Editable draft revision conflict');
      }
      final nextRevision = expectedRevision + 1;
      if (current == null) {
        await active.database.customInsert(
          'INSERT INTO $_tableName '
          '(scope_key, company_id, draft_id, payload, revision) '
          'VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable<String>(key.scopeKey),
            Variable<int>(key.companyId),
            Variable<String>(key.draftId),
            Variable<String>(encoded),
            Variable<int>(nextRevision),
          ],
        );
      } else {
        final changed = await active.database.customUpdate(
          'UPDATE $_tableName SET payload = ?, revision = ? '
          'WHERE scope_key = ? AND company_id = ? AND draft_id = ? '
          'AND revision = ?',
          variables: [
            Variable<String>(encoded),
            Variable<int>(nextRevision),
            ..._variables(key),
            Variable<int>(expectedRevision),
          ],
        );
        if (changed != 1) throw StateError('Editable draft revision conflict');
      }
      result = EditableDraftRecord(
        key: key,
        payload: snapshot,
        revision: nextRevision,
      );
    });
    active.database.notifyUpdates({const TableUpdate(_tableName)});
    if (_checkedActive(writing: false) == null) {
      throw StateError('Session lease changed while saving draft');
    }
    return result!;
  }

  /// Borra un borrador de forma definitiva. A diferencia de [save], no exige
  /// una revisión esperada: quien pide borrar ya asumió el registro como
  /// aceptado, y no hay nada con lo que reconciliar un conflicto. Borrar un
  /// borrador que no existe es una operación silenciosa, no un error.
  Future<void> delete(String draftId) async {
    final key = _key(draftId);
    final active = _checkedActive(writing: true)!;
    await active.database.transaction(() async {
      if (_checkedActive(writing: true) == null) {
        throw StateError('Session lease is no longer active');
      }
      await active.database.customUpdate(
        'DELETE FROM $_tableName '
        'WHERE scope_key = ? AND company_id = ? AND draft_id = ?',
        variables: _variables(key),
      );
    });
    active.database.notifyUpdates({const TableUpdate(_tableName)});
    if (_checkedActive(writing: false) == null) {
      throw StateError('Session lease changed while deleting draft');
    }
  }

  Stream<EditableDraftRecord?> watch(String draftId) {
    final key = _key(draftId);
    return Stream.multi((controller) {
      final active = _checkedActive(writing: false);
      if (active == null) {
        controller.close();
        return;
      }
      var closed = false;
      Future<void> emit() async {
        if (closed) return;
        final value = await read(key.draftId);
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

      // Subscribe before the initial read so a commit cannot fall between the
      // read and subscription. Drift coalesces table updates, so re-reading is
      // the source of truth and also makes duplicate notifications harmless.
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

  /// Watches [list] and re-reads it whenever the draft table changes.
  Stream<List<EditableDraftRecord>> watchList({
    int limit = 50,
    String? afterDraftId,
  }) {
    _validateLimit(limit);
    if (afterDraftId != null) _validateId(afterDraftId, 'afterDraftId');
    return Stream.multi((controller) {
      final active = _checkedActive(writing: false);
      if (active == null) {
        controller.close();
        return;
      }
      var closed = false;
      Future<void> emit() async {
        if (closed) return;
        final value = await list(limit: limit, afterDraftId: afterDraftId);
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

      // Subscribe before the initial read so a commit cannot be missed.
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

  static List<Variable<Object>> _variables(EditableDraftKey key) => [
    Variable<String>(key.scopeKey),
    Variable<int>(key.companyId),
    Variable<String>(key.draftId),
  ];

  static EditableDraftRecord _record(
    EditableDraftKey key,
    Map<String, Object?> row,
  ) {
    final revision = row['revision'];
    if (revision is! int || revision < 1) {
      throw StateError('Malformed editable draft revision');
    }
    try {
      final decoded = jsonDecode(row['payload'] as String);
      if (decoded is! Map) {
        throw const FormatException('Payload is not an object');
      }
      return EditableDraftRecord(
        key: key,
        payload: Map<String, dynamic>.from(decoded),
        revision: revision,
      );
    } on Object catch (error) {
      throw StateError('Malformed editable draft payload: $error');
    }
  }

  static void _validateId(String value, String name) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$').hasMatch(value)) {
      throw ArgumentError.value(
        value,
        name,
        'must be a non-empty safe identifier',
      );
    }
  }

  static void _validateLimit(int limit) {
    if (limit < 1 || limit > 200) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 200');
    }
  }
}
