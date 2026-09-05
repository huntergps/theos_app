import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/src/database/database.dart';
import 'package:theos_pos_core/src/managers/collection/journal_manager.dart';

void main() {
  late AppDatabase database;
  late JournalManager manager;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    manager = JournalManager(database);
  });

  tearDown(() => database.close());

  test('maps SRI entity and emission from Odoo into Drift', () async {
    final journal = manager.fromOdoo({
      'id': 12,
      'name': 'Ventas Quito',
      'code': 'VTA',
      'type': 'sale',
      'company_id': [7, 'Emisor'],
      'currency_id': false,
      'l10n_ec_entity': '001',
      'l10n_ec_emission': '003',
      'numbered_by_client': true,
      'active': true,
      'write_date': false,
    });

    expect(journal.l10nEcEntity, '001');
    expect(journal.l10nEcEmission, '003');
    await manager.upsertLocal(journal);

    final row = await manager.getById(12);
    expect(row!.l10nEcEntity, '001');
    expect(row.l10nEcEmission, '003');
    expect(row.currencyId, isNull);
    expect(row.writeDate, isNull);
    expect(row.numberedByClient, isTrue);
  });

  test(
    'parses Odoo false SRI values as null and preserves local sequence',
    () async {
      await database
          .into(database.accountJournal)
          .insert(
            AccountJournalCompanion.insert(
              odooId: 13,
              name: 'Caja',
              code: 'CJ',
              type: 'cash',
              lastInvoiceSequence: const Value(87),
            ),
          );

      final journal = manager.fromOdoo({
        'id': 13,
        'name': 'Caja actualizada',
        'code': 'CJ',
        'type': 'cash',
        'company_id': false,
        'currency_id': false,
        'l10n_ec_entity': false,
        'l10n_ec_emission': null,
        'numbered_by_client': false,
        'active': true,
        'write_date': null,
      });
      expect(journal.l10nEcEntity, isNull);
      expect(journal.l10nEcEmission, isNull);

      await manager.upsertLocal(journal);
      final row = await manager.getById(13);
      expect(row!.name, 'Caja actualizada');
      expect(row.l10nEcEntity, isNull);
      expect(row.l10nEcEmission, isNull);
      expect(row.lastInvoiceSequence, 87);
    },
  );
}
