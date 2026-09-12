import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  for (final from in [10, 11, 12]) {
    test('v$from al esquema vigente añade columnas sin borrar lo pendiente', () async {
      final directory = await Directory.systemTemp.createTemp(
        'advance-upgrade-',
      );
      final file = File('${directory.path}/cache.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await directory.delete(recursive: true);
      });

      final manager = AdvanceManager()..initDb(db);
      await manager.upsertLocal(
        Advance(
          id: -42,
          date: DateTime(2026, 9, 5),
          partnerId: 7,
          advanceType: AdvanceType.inbound,
          reference: 'Anticipo local pendiente de sincronizar',
          amount: 25,
        ),
      );
      await OfflineQueueDataSource(db).queueOperation(
        model: 'account.advance',
        method: 'create',
        recordId: -42,
        values: const {'external_id': 'upgrade-test-42'},
      );
      await db
          .into(db.accountJournal)
          .insert(
            AccountJournalCompanion.insert(
              odooId: 901,
              name: 'Diario secuencial offline',
              code: 'OFF',
              type: 'sale',
              sequence: const Value(42),
              lastInvoiceSequence: const Value(87),
              numberedByClient: const Value(true),
            ),
          );

      // Reconstruct the previous schema only inside this temporary fixture.
      if (from == 10)
        await db.customStatement(
          'ALTER TABLE advance_lines DROP COLUMN advance_id',
        );
      await db.customStatement('PRAGMA user_version = $from');
      if (from < 12) {
        await db.customStatement(
          'ALTER TABLE collection_config DROP COLUMN pos_app_capabilities_json',
        );
      }
      await db.customStatement(
        'ALTER TABLE account_journal DROP COLUMN numbered_by_client',
      );
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      final reopened = AdvanceManager()..initDb(db);
      final advance = await reopened.readLocalWithLines(-42);
      expect(advance?.amount, 25);
      expect(advance?.lines, isEmpty);
      expect(await OfflineQueueDataSource(db).getPendingCount(), 1);
      final journal = await (db.select(
        db.accountJournal,
      )..where((table) => table.odooId.equals(901))).getSingle();
      expect(journal.sequence, 42);
      expect(journal.lastInvoiceSequence, 87);
      // The flag did not exist in v12; the v13 default must be false.
      expect(journal.numberedByClient, isFalse);
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      // Contra el esquema VIGENTE, no contra un número escrito a mano: cuando
      // se subió a 15 estas pruebas se pusieron rojas por el número, tapando
      // que la migración de verdad sí funcionaba.
      expect(version.read<int>('user_version'), db.schemaVersion);
      final columns = await db
          .customSelect('PRAGMA table_info(advance_lines)')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        contains('advance_id'),
      );
      final journalColumns = await db
          .customSelect('PRAGMA table_info(account_journal)')
          .get();
      expect(
        journalColumns.map((row) => row.read<String>('name')),
        contains('numbered_by_client'),
      );
      for (final table in [
        'notification_entries',
        'notification_deliveries',
        'notification_cursors',
        'notification_system_ids',
      ]) {
        final found = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
              variables: [Variable.withString(table)],
            )
            .get();
        expect(found, isNotEmpty, reason: table);
      }
    });
  }
}
