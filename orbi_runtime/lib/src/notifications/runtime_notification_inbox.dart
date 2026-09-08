import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:theos_pos_core/theos_pos_core.dart' as core;

import '../session/session_runtime.dart';

/// Scope-bound adapter over the database already owned by [SessionRuntime].
/// It never opens a database and refuses work when the lease is inactive.
final class RuntimeNotificationInbox {
  RuntimeNotificationInbox(this.sessions, {required this.allocator});

  final SessionRuntime sessions;
  final core.NotificationSystemIdAllocator allocator;

  core.NotificationInboxStore _store() {
    final active = sessions.active;
    if (active == null) throw StateError('notification scope is inactive');
    return core.NotificationInboxStore(
      active.database.database,
      systemIdAllocator: allocator,
    );
  }

  Stream<core.NotificationEntry> watch(core.NotificationQuery query) {
    final active = sessions.active;
    if (active == null) {
      return Stream.error(StateError('notification scope is inactive'));
    }
    if (query.scopeKey != active.scope.scopeKey) {
      return Stream.error(
        StateError('notification scope does not match session'),
      );
    }
    return _store().watch(query).map(_entry);
  }

  Future<void> ingest(
    core.NotificationEvent event, {
    bool baseline = false,
  }) async {
    final active = sessions.active;
    if (active == null || event.scope.scopeKey != active.scope.scopeKey) {
      throw StateError('notification scope does not match session');
    }
    final now = DateTime.now().toUtc();
    final entry = core.NotificationEntriesCompanion.insert(
      id: event.dedupeKey,
      scopeKey: event.scope.scopeKey,
      partitionKey: event.scope.partitionKey,
      companyId: event.scope.companyId == null
          ? const Value.absent()
          : Value(event.scope.companyId),
      sourceKey: event.sourceKey,
      revision: event.revision,
      kind: event.kind.name,
      severity: event.severity.name,
      titleKey: event.titleKey,
      bodyKey: event.bodyKey,
      occurredAt: event.occurredAt,
      createdAt: now,
      updatedAt: now,
      targetType: event.target == null
          ? const Value.absent()
          : Value(event.target!.type),
      targetReference: event.target == null
          ? const Value.absent()
          : Value(event.target!.reference),
      origin: core.NotificationOrigin.local.name,
      argsJson: const Value('{}'),
    );
    await _store().ingest(entry: entry, delivery: null, cursor: null);
  }

  Future<int> markRead(String id, core.NotificationScope scope) => _store()
      .markRead(id, scope.scopeKey, scope.partitionKey, DateTime.now().toUtc());
  Future<int> markUnread(String id, core.NotificationScope scope) =>
      _store().markUnread(id, scope.scopeKey, scope.partitionKey);
  Future<int> archive(String id, core.NotificationScope scope) => _store()
      .archive(id, scope.scopeKey, scope.partitionKey, DateTime.now().toUtc());

  core.NotificationEntry _entry(dynamic row) => core.NotificationEntry(
    id: row.id as String,
    scope: core.NotificationScope(
      scopeKey: row.scopeKey as String,
      partitionKey: row.partitionKey as String,
      companyId: row.companyId as int?,
    ),
    sourceKey: row.sourceKey as String,
    revision: row.revision as int,
    kind: core.NotificationKind.values.byName(row.kind as String),
    severity: core.NotificationSeverity.values.byName(row.severity as String),
    titleKey: row.titleKey as String,
    bodyKey: row.bodyKey as String,
    args: (jsonDecode(row.argsJson as String) as Map).map(
      (key, value) => MapEntry(key as String, value as String),
    ),
    fallbackText: row.fallbackText as String?,
    occurredAt: row.occurredAt as DateTime,
    createdAt: row.createdAt as DateTime,
    updatedAt: row.updatedAt as DateTime,
    readAt: row.readAt as DateTime?,
    archivedAt: row.archivedAt as DateTime?,
    resolvedAt: row.resolvedAt as DateTime?,
    target: row.targetType == null
        ? null
        : core.NotificationTarget(
            type: row.targetType as String,
            reference: row.targetReference as String,
          ),
    origin: core.NotificationOrigin.values.byName(row.origin as String),
    expiresAt: row.expiresAt as DateTime?,
  );
}
