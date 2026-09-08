import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        AppDatabase,
        PartnerRecordMapper,
        JournalRecordMapper,
        CollectionConfigRecordMapper,
        CollectionSessionRecordMapper;

void main() {
  test('physical config/session roundtrip survives reopen', () async {
    final dir = await Directory.systemTemp.createTemp('orbi-collection-');
    final path = '${dir.path}/collection.sqlite';
    final first = AppDatabase(NativeDatabase(File(path)));
    await CollectionConfigRecordMapper.upsert(first, {
      'id': 21,
      'name': 'Caja Norte',
      'code': 'CN',
      'company_id': 7,
      'allowed_journal_ids': [3, 4],
      'user_ids': [2],
      'current_session_id': 31,
      'current_session_state': 'opened',
    });
    await CollectionSessionRecordMapper.upsert(first, {
      'id': 31,
      'session_uuid': 'session-31',
      'name': 'Turno Norte',
      'state': 'opened',
      'config_id': 21,
      'company_id': 7,
      'user_id': 2,
      'currency_id': 1,
      'start_at': '2026-01-01 10:00:00',
      'cash_register_balance_start': 100,
    });
    await first.close();
    final second = AppDatabase(NativeDatabase(File(path)));
    addTearDown(() async {
      await second.close();
      await dir.delete(recursive: true);
    });
    expect(
      (await second.select(second.collectionConfig).get()).single.name,
      'Caja Norte',
    );
    expect(
      (await second.select(second.collectionSession).get()).single.sessionUuid,
      'session-31',
    );
    expect(
      (await second.select(second.collectionSession).get())
          .single
          .cashRegisterBalanceStart,
      100,
    );
  });

  test(
    'physical database restart preserves partner journal and cursor',
    () async {
      final dir = await Directory.systemTemp.createTemp('orbi-catalog-');
      final path = '${dir.path}/catalog.sqlite';
      final first = AppDatabase(NativeDatabase(File(path)));
      await PartnerRecordMapper.upsert(first, {'id': 11, 'name': 'Cliente'});
      await JournalRecordMapper.upsert(first, {
        'id': 12,
        'name': 'Caja',
        'code': 'CJ',
        'type': 'cash',
      });
      await first.customStatement(
        'INSERT OR REPLACE INTO sync_metadata (key, value) VALUES (?, ?)',
        ['catalog:test', '{"cursor":"page-2"}'],
      );
      await first.close();
      final second = AppDatabase(NativeDatabase(File(path)));
      addTearDown(() async {
        await second.close();
        await dir.delete(recursive: true);
      });
      expect(
        (await PartnerRecordMapper.read(second)).single['name'],
        'Cliente',
      );
      expect((await JournalRecordMapper.read(second)).single['name'], 'Caja');
      final cursor = await second
          .customSelect(
            'SELECT value FROM sync_metadata WHERE key = ?',
            variables: [Variable<String>('catalog:test')],
          )
          .getSingle();
      expect(cursor.data['value'], '{"cursor":"page-2"}');
      await PartnerRecordMapper.upsert(second, {
        'id': 11,
        'name': 'Cliente actualizado',
      });
      expect((await PartnerRecordMapper.read(second)).length, 1);
    },
  );

  test('watch emits persisted cursor after commit and error', () async {
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final scope = AppScope(
      appId: 'panel',
      installationId: 'i',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 2,
    );
    await owner.open(scope);
    addTearDown(owner.close);
    final store = DriftCatalogStore<Map<String, dynamic>>(
      owner: owner,
      writeRows: (_, _, _) async {},
    );
    final states = <CatalogState<Map<String, dynamic>>>[];
    final done = Completer<void>();
    final sub = store.watch(scope).listen((state) {
      states.add(state);
      if (states.length == 3 && !done.isCompleted) done.complete();
    });
    await Future<void>.delayed(Duration.zero);
    await store.commit(scope, const CatalogBatch(records: [], cursor: 'next'));
    await store.recordError(scope, StateError('offline'));
    await done.future.timeout(const Duration(seconds: 2));
    await sub.cancel();
    expect(states[1].cursor, 'next');
    expect(states[2].cursor, 'next');
    expect(states[2].error, contains('offline'));
  });
}
