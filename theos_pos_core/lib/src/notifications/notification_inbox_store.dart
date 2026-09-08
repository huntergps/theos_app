import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';

abstract interface class NotificationSystemIdAllocator {
  Future<int> allocate({
    required String scopeKey,
    required String entryId,
    required String channel,
  });
}

class NotificationInboxStore {
  NotificationInboxStore(this.db, {this.systemIdAllocator});
  final AppDatabase db;
  final NotificationSystemIdAllocator? systemIdAllocator;

  Stream<List<NotificationEntry>> watch(NotificationQuery query) {
    final statement = db.select(db.notificationEntries)
      ..where(
        (t) =>
            t.scopeKey.equals(query.scopeKey) &
            t.partitionKey.equals(query.partitionKey),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(query.limit, offset: query.offset);
    return statement.watch();
  }

  Future<void> ingest({
    required NotificationEntriesCompanion entry,
    required NotificationDeliveriesCompanion? delivery,
    required NotificationCursorsCompanion? cursor,
  }) async {
    await db.transaction(() async {
      final existing =
          await (db.select(db.notificationEntries)..where(
                (t) =>
                    t.scopeKey.equals(entry.scopeKey.value) &
                    t.partitionKey.equals(entry.partitionKey.value) &
                    t.sourceKey.equals(entry.sourceKey.value),
              ))
              .getSingleOrNull();
      if (existing == null) {
        await db.into(db.notificationEntries).insert(entry);
      } else if (entry.revision.value > existing.revision) {
        await (db.update(db.notificationEntries)
              ..where((t) => t.id.equals(existing.id)))
            .write(entry.copyWith(id: Value(existing.id)));
      }
      if (existing == null || entry.revision.value > existing.revision) {
        if (delivery != null) {
          if (delivery.scopeKey.value != entry.scopeKey.value ||
              delivery.revision.value != entry.revision.value) {
            throw ArgumentError('delivery scope/revision does not match entry');
          }
          final baselineComplete =
              cursor == null ||
              !cursor.baselineComplete.present ||
              cursor.baselineComplete.value;
          if (baselineComplete) {
            final targetEntryId = existing?.id ?? entry.id.value;
            final systemId = await _systemIdFor(
              scopeKey: entry.scopeKey.value,
              entryId: targetEntryId,
              channel: delivery.channel.value,
            );
            await db
                .into(db.notificationDeliveries)
                .insertOnConflictUpdate(
                  delivery.copyWith(
                    entryId: Value(targetEntryId),
                    systemId: Value(systemId),
                  ),
                );
          }
        }
      }
      if (cursor != null) {
        if (cursor.scopeKey.present &&
            cursor.scopeKey.value != entry.scopeKey.value) {
          throw ArgumentError('cursor scope does not match entry');
        }
        if (cursor.partitionKey.present &&
            cursor.partitionKey.value != entry.partitionKey.value) {
          throw ArgumentError('cursor partition does not match entry');
        }
        final current =
            await (db.select(db.notificationCursors)..where(
                  (t) =>
                      t.scopeKey.equals(cursor.scopeKey.value) &
                      t.partitionKey.equals(cursor.partitionKey.value) &
                      t.source.equals(cursor.source.value),
                ))
                .getSingleOrNull();
        if (current == null ||
            cursor.updatedAt.value.isAfter(current.updatedAt)) {
          await db.into(db.notificationCursors).insertOnConflictUpdate(cursor);
        }
      }
    });
  }

  Future<int> _systemIdFor({
    required String scopeKey,
    required String entryId,
    required String channel,
  }) async {
    final allocator = systemIdAllocator;
    if (allocator == null) {
      throw StateError(
        'NotificationSystemIdAllocator is required for system delivery',
      );
    }
    final allocated = await allocator.allocate(
      scopeKey: scopeKey,
      entryId: entryId,
      channel: channel,
    );
    if (allocated <= 0) throw StateError('allocator returned invalid systemId');
    final existing =
        await (db.select(db.notificationSystemIds)..where(
              (t) =>
                  t.scopeKey.equals(scopeKey) &
                  t.entryId.equals(entryId) &
                  t.channel.equals(channel),
            ))
            .getSingleOrNull();
    if (existing != null) {
      if (existing.systemId != allocated) {
        throw StateError('allocator changed an existing systemId');
      }
      return allocated;
    }
    final collision = await (db.select(
      db.notificationSystemIds,
    )..where((t) => t.systemId.equals(allocated))).getSingleOrNull();
    if (collision != null) throw StateError('systemId already assigned');
    await db
        .into(db.notificationSystemIds)
        .insert(
          NotificationSystemIdsCompanion.insert(
            scopeKey: scopeKey,
            entryId: entryId,
            channel: channel,
            systemId: allocated,
          ),
        );
    return allocated;
  }

  Future<int> markRead(
    String id,
    String scopeKey,
    String partitionKey,
    DateTime at,
  ) =>
      (db.update(db.notificationEntries)..where(
            (t) =>
                t.id.equals(id) &
                t.scopeKey.equals(scopeKey) &
                t.partitionKey.equals(partitionKey),
          ))
          .write(NotificationEntriesCompanion(readAt: Value(at)));

  Future<int> markUnread(String id, String scopeKey, String partitionKey) =>
      (db.update(db.notificationEntries)..where(
            (t) =>
                t.id.equals(id) &
                t.scopeKey.equals(scopeKey) &
                t.partitionKey.equals(partitionKey),
          ))
          .write(const NotificationEntriesCompanion(readAt: Value(null)));

  Future<int> archive(
    String id,
    String scopeKey,
    String partitionKey,
    DateTime at,
  ) =>
      (db.update(db.notificationEntries)..where(
            (t) =>
                t.id.equals(id) &
                t.scopeKey.equals(scopeKey) &
                t.partitionKey.equals(partitionKey),
          ))
          .write(NotificationEntriesCompanion(archivedAt: Value(at)));

  Future<int> resolve(
    String sourceKey,
    String scopeKey,
    String partitionKey,
    DateTime at,
  ) =>
      (db.update(db.notificationEntries)..where(
            (t) =>
                t.sourceKey.equals(sourceKey) &
                t.scopeKey.equals(scopeKey) &
                t.partitionKey.equals(partitionKey),
          ))
          .write(NotificationEntriesCompanion(resolvedAt: Value(at)));

  Future<int> reclaimExpiredLeases(DateTime now) =>
      (db.update(db.notificationDeliveries)..where(
            (t) =>
                t.state.equals('claimed') &
                t.leaseExpiresAt.isSmallerThanValue(now),
          ))
          .write(
            const NotificationDeliveriesCompanion(state: Value('pending')),
          );

  Future<int> purgeOld(DateTime cutoff) async {
    return db.transaction(() async {
      final old =
          await (db.select(db.notificationEntries)..where(
                (t) =>
                    t.resolvedAt.isSmallerThanValue(cutoff) &
                    t.readAt.isSmallerThanValue(cutoff),
              ))
              .get();
      var count = 0;
      for (final entry in old) {
        final active =
            await (db.select(db.notificationDeliveries)..where(
                  (d) =>
                      d.entryId.equals(entry.id) &
                      (d.state.equals('pending') | d.state.equals('claimed')),
                ))
                .get();
        if (active.isNotEmpty) continue;
        await (db.delete(
          db.notificationDeliveries,
        )..where((d) => d.entryId.equals(entry.id))).go();
        await (db.delete(
          db.notificationSystemIds,
        )..where((s) => s.entryId.equals(entry.id))).go();
        count += await (db.delete(
          db.notificationEntries,
        )..where((t) => t.id.equals(entry.id))).go();
      }
      return count;
    });
  }

  static String encodeArgs(Map<String, String> args) => jsonEncode(args);
}

class NotificationQuery {
  final String scopeKey;
  final String partitionKey;
  final int limit;
  final int offset;

  NotificationQuery({
    required String scopeKey,
    required String partitionKey,
    this.limit = 50,
    this.offset = 0,
  }) : scopeKey = _required(scopeKey, 'scopeKey'),
       partitionKey = _required(partitionKey, 'partitionKey') {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit');
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
  }

  static String _required(String value, String name) {
    if (value.trim().isEmpty) throw ArgumentError.value(value, name);
    return value;
  }
}
