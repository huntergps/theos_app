import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/core/managers/manager_providers.dart';
import 'package:theos_pos/features/sync/repositories/product_sync_repository.dart';
import 'package:theos_pos/features/sync/repositories/user_sync_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import '../../../mocks/mock_odoo_client.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late MockOdooClient client;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    client = MockOdooClient.online();
    await initializeModelManagers(
      client: client,
      db: database,
      queueStore: OfflineQueueDataSource(database),
    );
  });

  tearDown(() async {
    resetModelManagersSession();
    await database.close();
  });

  group('pricelist child reconciliation', () {
    test('runs when no parent changed, batches all parents and removes only stale remote rows', () async {
      await _insertPricelist(database, 1, 'Público');
      await _insertPricelist(database, 2, 'Mayorista');
      await _insertRule(database, id: 100, pricelistId: 1);
      await _insertRule(database, id: -101, pricelistId: 1);
      await _insertRule(database, id: 200, pricelistId: 99);

      when(
        () => client.searchCount(
          model: 'product.pricelist',
          domain: any(named: 'domain'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => client.searchCount(
          model: 'product.pricelist.item',
          domain: any(named: 'domain'),
        ),
      ).thenAnswer((_) async => 2);
      when(
        () => client.searchRead(
          model: 'product.pricelist.item',
          domain: any(named: 'domain'),
          fields: any(named: 'fields'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
        ),
      ).thenAnswer((_) async => [_remoteRule(101, 1), _remoteRule(102, 2)]);

      final repository = ProductSyncRepository(
        db: database,
        odooClient: client,
      );

      expect(
        await repository.syncPricelists(sinceDate: DateTime.utc(2026, 8, 26)),
        0,
      );

      final rows = await database.select(database.productPricelistItem).get();
      expect(rows.map((row) => row.odooId), containsAll(<int>[-101, 101, 102]));
      expect(rows.map((row) => row.odooId), isNot(contains(100)));
      expect(rows.map((row) => row.odooId), isNot(contains(200)));

      verify(
        () => client.searchRead(
          model: 'product.pricelist.item',
          domain: any(named: 'domain'),
          fields: any(named: 'fields'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: 'id asc',
        ),
      ).called(1);
    });

    test(
      'transport failure preserves the previously cached child scope',
      () async {
        await _insertPricelist(database, 1, 'Público');
        await _insertRule(database, id: 100, pricelistId: 1);

        when(
          () => client.searchCount(
            model: 'product.pricelist',
            domain: any(named: 'domain'),
          ),
        ).thenAnswer((_) async => 0);
        when(
          () => client.searchCount(
            model: 'product.pricelist.item',
            domain: any(named: 'domain'),
          ),
        ).thenAnswer((_) async => 1);
        when(
          () => client.searchRead(
            model: 'product.pricelist.item',
            domain: any(named: 'domain'),
            fields: any(named: 'fields'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
          ),
        ).thenThrow(StateError('network unavailable'));

        final repository = ProductSyncRepository(
          db: database,
          odooClient: client,
        );

        await expectLater(
          repository.syncPricelists(),
          throwsA(isA<StateError>()),
        );
        expect(
          await (database.select(
            database.productPricelistItem,
          )..where((table) => table.odooId.equals(100))).getSingleOrNull(),
          isNotNull,
        );
      },
    );
  });

  group('fiscal position derived mapping reconciliation', () {
    test('runs when no fiscal position parent changed', () async {
      when(
        () => client.searchCount(
          model: 'account.fiscal.position',
          domain: any(named: 'domain'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => client.searchCount(
          model: FiscalPositionTax.odooModel,
          domain: any(named: 'domain'),
        ),
      ).thenAnswer((_) async => 1);
      when(
        () => client.searchRead(
          model: FiscalPositionTax.odooModel,
          domain: any(named: 'domain'),
          fields: any(named: 'fields'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
        ),
      ).thenAnswer(
        (_) async => const [
          {
            'id': 19,
            'fiscal_position_ids': [4],
            'original_tax_ids': [5],
            'write_date': '2026-08-26 00:00:00',
          },
        ],
      );

      final repository = UserSyncRepository(
        db: _MockDatabaseHelper(),
        odooClient: client,
        appDatabase: database,
      );

      expect(await repository.syncFiscalPositions(), 0);
      final mapping = await database
          .select(database.accountFiscalPositionTax)
          .getSingle();
      expect(mapping.positionId, 4);
      expect(mapping.taxSrcId, 5);
      expect(mapping.taxDestId, 19);
    });

    test('cancellation keeps the last complete mapping snapshot', () async {
      await database
          .into(database.accountFiscalPositionTax)
          .insert(
            AccountFiscalPositionTaxCompanion.insert(
              odooId: -900,
              positionId: 7,
              taxSrcId: 8,
              taxDestId: 9,
            ),
          );
      when(
        () => client.searchCount(
          model: FiscalPositionTax.odooModel,
          domain: any(named: 'domain'),
        ),
      ).thenAnswer((_) async => 2);
      when(
        () => client.searchRead(
          model: FiscalPositionTax.odooModel,
          domain: any(named: 'domain'),
          fields: any(named: 'fields'),
          limit: 1,
          offset: 0,
          order: 'id asc',
        ),
      ).thenAnswer(
        (_) async => const [
          {
            'id': 19,
            'fiscal_position_ids': [4],
            'original_tax_ids': [5],
            'write_date': '2026-08-26 00:00:00',
          },
        ],
      );

      final repository = UserSyncRepository(
        db: _MockDatabaseHelper(),
        odooClient: client,
        appDatabase: database,
      );

      await expectLater(
        repository.syncFiscalPositionTaxMappings(
          limit: 1,
          onProgress: (progress) {
            if (progress.synced == 1) repository.cancelSync();
          },
        ),
        throwsA(isA<SyncCancelledException>()),
      );

      final rows = await database
          .select(database.accountFiscalPositionTax)
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.odooId, -900);
    });
  });
}

Future<void> _insertPricelist(AppDatabase database, int id, String name) async {
  await database
      .into(database.productPricelist)
      .insert(ProductPricelistCompanion.insert(odooId: id, name: name));
}

Future<void> _insertRule(
  AppDatabase database, {
  required int id,
  required int pricelistId,
}) async {
  await database
      .into(database.productPricelistItem)
      .insert(
        ProductPricelistItemCompanion.insert(
          odooId: id,
          pricelistId: pricelistId,
          appliedOn: '3_global',
          base: 'list_price',
        ),
      );
}

Map<String, dynamic> _remoteRule(int id, int pricelistId) => {
  'id': id,
  'pricelist_id': [pricelistId, 'Lista $pricelistId'],
  'applied_on': '3_global',
  'compute_price': 'fixed',
  'fixed_price': 10.0,
  'base': 'list_price',
};
