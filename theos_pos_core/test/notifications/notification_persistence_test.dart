import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

final t = DateTime.utc(2026);
NotificationEntriesCompanion e(
  String id, {
  String scope = 's',
  int rev = 1,
  String source = 'source',
  DateTime? updated,
}) => NotificationEntriesCompanion.insert(
  id: id,
  scopeKey: scope,
  partitionKey: 'global',
  sourceKey: source,
  revision: rev,
  kind: 'system',
  severity: 'info',
  titleKey: 't',
  bodyKey: 'b',
  occurredAt: t,
  createdAt: t,
  updatedAt: updated ?? t,
  origin: 'local',
);
NotificationDeliveriesCompanion d(
  String id, {
  String scope = 's',
  int rev = 1,
  int systemId = 1,
}) => NotificationDeliveriesCompanion.insert(
  entryId: id,
  scopeKey: scope,
  revision: rev,
  channel: 'system',
  state: 'pending',
  systemId: Value(systemId),
);

final class _Allocator implements NotificationSystemIdAllocator {
  _Allocator({this.fixedId});

  final int? fixedId;
  var _next = 1;
  final _ids = <String, int>{};

  @override
  Future<int> allocate({
    required String scopeKey,
    required String entryId,
    required String channel,
  }) async {
    final key = jsonEncode([scopeKey, entryId, channel]);
    return _ids.putIfAbsent(key, () => fixedId ?? _next++);
  }
}

void main() {
  test('physical v13 reopen preserves offline queue and creates notification tables', () async {
    final directory = await Directory.systemTemp.createTemp(
      'notification-v13-',
    );
    final file = File('${directory.path}/cache.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    await db.customStatement(
      "INSERT INTO offline_queue (operation, model, \"values\", created_at) VALUES ('create', 'x', '{}', 1767225600000)",
    );
    for (final table in [
      'notification_entries',
      'notification_deliveries',
      'notification_cursors',
      'notification_system_ids',
    ]) {
      await db.customStatement('DROP TABLE $table');
    }
    await db.customStatement('PRAGMA user_version = 13');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);
    expect(await db.select(db.offlineQueue).get(), hasLength(1));
    expect(await db.select(db.notificationEntries).get(), isEmpty);
    expect(await db.select(db.notificationDeliveries).get(), isEmpty);
    expect(await db.select(db.notificationCursors).get(), isEmpty);
    expect(await db.select(db.notificationSystemIds).get(), isEmpty);
    await db.close();
    await directory.delete(recursive: true);
  });

  test('tables exist and ingest is atomic', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = NotificationInboxStore(db, systemIdAllocator: _Allocator());
    await store.ingest(
      entry: e('n1'),
      delivery: null,
      cursor: NotificationCursorsCompanion.insert(
        scopeKey: 's',
        partitionKey: 'global',
        source: 'src',
        updatedAt: t,
      ),
    );
    expect(await db.select(db.notificationEntries).get(), hasLength(1));
    expect(await db.select(db.notificationCursors).get(), hasLength(1));
    await db.close();
  });

  test(
    'watch is scope-partitioned, paginated and rejects invalid query',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final store = NotificationInboxStore(db, systemIdAllocator: _Allocator());
      await store.ingest(entry: e('watch-1'), delivery: null, cursor: null);
      await store.ingest(
        entry: e(
          'watch-2',
          source: 'watch-2',
          updated: t.add(const Duration(minutes: 2)),
        ),
        delivery: null,
        cursor: null,
      );
      await store.ingest(
        entry: e(
          'watch-3',
          source: 'watch-3',
          updated: t.add(const Duration(minutes: 3)),
        ),
        delivery: null,
        cursor: null,
      );
      final page = await store
          .watch(
            NotificationQuery(scopeKey: 's', partitionKey: 'global', limit: 2),
          )
          .first;
      expect(page.map((item) => item.id), ['watch-3', 'watch-2']);
      expect(
        await store
            .watch(NotificationQuery(scopeKey: 'other', partitionKey: 'global'))
            .first,
        isEmpty,
      );
      expect(
        () => NotificationQuery(scopeKey: '', partitionKey: 'global'),
        throwsArgumentError,
      );
      expect(
        () =>
            NotificationQuery(scopeKey: 's', partitionKey: 'global', limit: 0),
        throwsArgumentError,
      );
      await db.close();
    },
  );

  test(
    'newer revision preserves entry ID and stale revision is ignored',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final store = NotificationInboxStore(db, systemIdAllocator: _Allocator());
      await store.ingest(entry: e('old'), delivery: d('old'), cursor: null);
      await store.ingest(
        entry: e('stale', rev: 0),
        delivery: d('stale', rev: 0),
        cursor: null,
      );
      await store.ingest(
        entry: e('new', rev: 2),
        delivery: d('new', rev: 2),
        cursor: null,
      );
      expect((await db.select(db.notificationEntries).getSingle()).id, 'old');
      await db.close();
    },
  );

  test(
    'scope filtering, baseline suppression, monotonic cursor and lease',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final store = NotificationInboxStore(db, systemIdAllocator: _Allocator());
      await store.ingest(
        entry: e('one', scope: 'one'),
        delivery: d('one', scope: 'one'),
        cursor: null,
      );
      await store.ingest(
        entry: e('two', scope: 'two'),
        delivery: d('two', scope: 'two', systemId: 2),
        cursor: null,
      );
      await store.ingest(
        entry: e('baseline', scope: 'baseline'),
        delivery: d('baseline', scope: 'baseline'),
        cursor: NotificationCursorsCompanion(
          scopeKey: const Value('baseline'),
          partitionKey: const Value('global'),
          source: const Value('src'),
          baselineComplete: const Value(false),
          updatedAt: Value(t),
        ),
      );
      expect(
        await (db.select(
          db.notificationDeliveries,
        )..where((row) => row.entryId.equals('baseline'))).get(),
        isEmpty,
      );
      expect(await store.markRead('one', 'two', 'global', t), 0);
      expect(await store.resolve('source', 'one', 'global', t), 1);
      await db
          .update(db.notificationDeliveries)
          .write(
            const NotificationDeliveriesCompanion(
              state: Value('claimed'),
              leaseExpiresAt: Value(null),
            ),
          );
      expect(
        await store.reclaimExpiredLeases(t.add(const Duration(hours: 1))),
        0,
      );
      await db
          .update(db.notificationDeliveries)
          .write(
            NotificationDeliveriesCompanion(
              state: const Value('claimed'),
              leaseExpiresAt: Value(t.subtract(const Duration(minutes: 1))),
            ),
          );
      expect(await store.reclaimExpiredLeases(t), 2);
      expect(
        (await db.select(db.notificationDeliveries).get()).every(
          (row) => row.state == 'pending',
        ),
        isTrue,
      );
      await db.close();
    },
  );

  test('read, archive, cursor and dedupe survive file reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'notification-reopen-',
    );
    final file = File('${directory.path}/cache.sqlite');
    final allocator = _Allocator();
    var db = AppDatabase(NativeDatabase(file));
    var store = NotificationInboxStore(db, systemIdAllocator: allocator);
    await store.ingest(
      entry: e('persisted', source: 'dedupe'),
      delivery: d('persisted'),
      cursor: NotificationCursorsCompanion.insert(
        scopeKey: 's',
        partitionKey: 'global',
        source: 'poll',
        cursorValue: const Value('c1'),
        updatedAt: t,
      ),
    );
    await store.ingest(
      entry: e('ignored', rev: 0, source: 'dedupe'),
      delivery: d('ignored', rev: 0),
      cursor: null,
    );
    await store.markRead('persisted', 's', 'global', t);
    await store.archive('persisted', 's', 'global', t);
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    store = NotificationInboxStore(db, systemIdAllocator: allocator);
    expect(await db.select(db.notificationEntries).get(), hasLength(1));
    final entry = await db.select(db.notificationEntries).getSingle();
    expect(entry.readAt?.toUtc(), t);
    expect(entry.archivedAt?.toUtc(), t);
    expect(
      (await db.select(db.notificationCursors).getSingle()).cursorValue,
      'c1',
    );
    expect((await db.select(db.notificationSystemIds).getSingle()).systemId, 1);
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'purge keeps pending and claimed, removes old resolved entries',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final store = NotificationInboxStore(db, systemIdAllocator: _Allocator());
      for (final id in ['pending', 'claimed', 'done']) {
        await store.ingest(
          entry: e(id, source: id),
          delivery: d(id),
          cursor: null,
        );
        await store.markRead(id, 's', 'global', t);
        await store.resolve(id, 's', 'global', t);
      }
      await (db.update(
        db.notificationDeliveries,
      )..where((row) => row.entryId.equals('claimed'))).write(
        const NotificationDeliveriesCompanion(state: Value('claimed')),
      );
      await (db.update(db.notificationDeliveries)
            ..where((row) => row.entryId.equals('done')))
          .write(const NotificationDeliveriesCompanion(state: Value('shown')));
      expect(await store.purgeOld(t.add(const Duration(days: 1))), 1);
      expect(
        (await db.select(db.notificationEntries).get()).map((row) => row.id),
        containsAll(<String>['pending', 'claimed']),
      );
      await db.close();
    },
  );

  test('duplicate system ID rolls back entry transaction', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = NotificationInboxStore(
      db,
      systemIdAllocator: _Allocator(fixedId: 1),
    );
    await store.ingest(entry: e('a'), delivery: d('a'), cursor: null);
    await expectLater(
      store.ingest(
        entry: e('b', source: 'other'),
        delivery: d('b'),
        cursor: null,
      ),
      throwsA(isA<StateError>()),
    );
    expect(await db.select(db.notificationEntries).get(), hasLength(1));
    await db.close();
  });

  test('cursor scope mismatch rolls back entry and delivery', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = NotificationInboxStore(db, systemIdAllocator: _Allocator());
    await expectLater(
      store.ingest(
        entry: e('mismatch'),
        delivery: d('mismatch'),
        cursor: NotificationCursorsCompanion.insert(
          scopeKey: 'other',
          partitionKey: 'global',
          source: 'poll',
          updatedAt: t,
        ),
      ),
      throwsArgumentError,
    );
    expect(await db.select(db.notificationEntries).get(), isEmpty);
    expect(await db.select(db.notificationDeliveries).get(), isEmpty);
    expect(await db.select(db.notificationCursors).get(), isEmpty);
    await db.close();
  });
}
