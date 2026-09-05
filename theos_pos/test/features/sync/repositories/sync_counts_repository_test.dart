import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/features/sync/repositories/qweb_template_sync_repository.dart';
import 'package:theos_pos/features/sync/repositories/sync_counts_repository.dart';
import 'package:theos_pos/features/sync/repositories/sync_scope_domains.dart';
import 'package:theos_pos/features/sync/services/offline_mode_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../mocks/mock_odoo_client.dart';

class _MockQwebTemplateSyncRepository extends Mock
    implements QwebTemplateSyncRepository {}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('sync counts return aggregate row counts for known models', () async {
    final repository = SyncCountsRepository(
      appDb: db,
      odooClient: null,
      qwebTemplateSync: _MockQwebTemplateSyncRepository(),
    );

    await db.customStatement(
      "INSERT INTO product_product (odoo_id, name) VALUES (1, 'A'), (2, 'B')",
    );
    await db.customStatement(
      "INSERT INTO product_category (odoo_id, name) VALUES (10, 'General')",
    );

    expect(await repository.getLocalProductCount(), 2);
    expect(await repository.getLocalCategoryCount(), 1);
    expect(await repository.getLocalCountForModel('product.product'), 2);
    expect(await repository.getLocalCountForModel('res.partner'), 0);
  });

  test('offline queue count stream emits SQL aggregate updates', () async {
    final service = OfflineModeService(db: db);
    final emissions = service.watchPendingOperationsCount().take(2).toList();

    expect(await service.getPendingOperationsCount(), 0);
    await db
        .into(db.offlineQueue)
        .insert(
          OfflineQueueCompanion.insert(
            model: 'sale.order',
            values: '{}',
            createdAt: DateTime.now(),
          ),
        );

    expect(await emissions, [0, 1]);
    expect(await service.getPendingOperationsCount(), 1);
  });

  test(
    'removes remote tombstones and records that left the product domain',
    () async {
      final client = MockOdooClient.online();
      final repository = SyncCountsRepository(
        appDb: db,
        odooClient: client,
        qwebTemplateSync: _MockQwebTemplateSyncRepository(),
      );
      await db.customStatement(
        "INSERT INTO product_product (odoo_id, name) VALUES "
        "(10, 'Deleted'), (20, 'No longer saleable')",
      );

      when(
        () => client.call(
          model: 'sync.deleted.record',
          method: 'get_deleted_since',
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer(
        (_) async => const [
          {'record_id': 10},
        ],
      );
      when(
        () => client.call(
          model: 'product.product',
          method: 'search_read',
          kwargs: any(named: 'kwargs'),
          context: any(named: 'context'),
        ),
      ).thenAnswer(
        (_) async => const [
          {'id': 20},
        ],
      );

      final deleted = await repository.syncDeletedRecords(
        odooModel: 'product.product',
        sinceDate: DateTime.utc(2026, 8, 26),
      );

      expect(deleted, 2);
      expect(await db.select(db.productProduct).get(), isEmpty);

      final domainCall = verify(
        () => client.call(
          model: 'product.product',
          method: 'search_read',
          kwargs: captureAny(named: 'kwargs'),
          context: captureAny(named: 'context'),
        ),
      );
      final kwargs = domainCall.captured.first as Map<String, dynamic>;
      final context = domainCall.captured.last as Map<String, dynamic>;
      expect(kwargs['domain'], contains(equals(['active', '=', false])));
      expect(kwargs['domain'], contains(equals(['sale_ok', '=', false])));
      expect(context, containsPair('active_test', false));
    },
  );

  test('removes credit notes that left the available domain but preserves queued offline intent', () async {
    final client = MockOdooClient.online();
    final repository = SyncCountsRepository(
      appDb: db,
      odooClient: client,
      qwebTemplateSync: _MockQwebTemplateSyncRepository(),
    );
    await db.customStatement(
      "INSERT INTO account_move "
      "(odoo_id, name, move_type, state, amount_residual, payment_state) "
      "VALUES "
      "(20, 'NC pagada', 'out_refund', 'posted', 0, 'paid'), "
      "(30, 'NC en pago offline', 'out_refund', 'posted', 50, 'partial'), "
      "(40, 'NC con cambio directo', 'out_refund', 'cancel', 50, 'not_paid')",
    );
    await db.customStatement(
      "INSERT INTO account_move_line "
      "(odoo_id, move_id, account_id, name) VALUES "
      "(201, 20, 1, 'Línea pagada'), "
      "(301, 30, 1, 'Línea protegida')",
    );
    await db
        .into(db.offlineQueue)
        .insert(
          OfflineQueueCompanion.insert(
            model: 'l10n_ec_collection_box.sale.order.payment.wizard',
            values: '{"line_ids":[{"line_type":"credit_note","credit_note_id":30}]}',
            createdAt: DateTime.utc(2026, 8, 26),
          ),
        );
    await db
        .into(db.offlineQueue)
        .insert(
          OfflineQueueCompanion.insert(
            model: 'account.move',
            values: '{}',
            createdAt: DateTime.utc(2026, 8, 26),
            recordId: const Value(40),
            status: const Value('processing'),
          ),
        );

    when(
      () => client.call(
        model: 'sync.deleted.record',
        method: 'get_deleted_since',
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer((_) async => const []);
    when(
      () => client.call(
        model: 'account.move',
        method: 'search_read',
        kwargs: any(named: 'kwargs'),
        context: any(named: 'context'),
      ),
    ).thenAnswer(
      (_) async => const [
        {'id': 20},
        {'id': 30},
        {'id': 40},
      ],
    );

    final deleted = await repository.syncDeletedRecords(
      odooModel: 'account.move',
      sinceDate: DateTime.utc(2026, 8, 26),
    );

    expect(deleted, 1);
    final remaining = await db.select(db.accountMove).get();
    expect(remaining.map((row) => row.odooId), unorderedEquals([30, 40]));
    final remainingLines = await db.select(db.accountMoveLine).get();
    expect(remainingLines.map((row) => row.odooId), [301]);

    final domainCall = verify(
      () => client.call(
        model: 'account.move',
        method: 'search_read',
        kwargs: captureAny(named: 'kwargs'),
        context: any(named: 'context'),
      ),
    );
    final kwargs = domainCall.captured.single as Map<String, dynamic>;
    expect(
      kwargs['domain'],
      contains(equals(['move_type', '=', 'out_refund'])),
    );
    expect(kwargs['domain'], contains(equals(['state', '!=', 'posted'])));
    expect(
      kwargs['domain'],
      contains(
        equals([
          'payment_state',
          'not in',
          ['not_paid', 'partial'],
        ]),
      ),
    );
    expect(kwargs['domain'], contains(equals(['amount_residual', '<=', 0])));
  });

  test('reconciles sale orders outside the rolling scope without deleting offline work', () async {
    final client = MockOdooClient.online();
    final repository = SyncCountsRepository(
      appDb: db,
      odooClient: client,
      qwebTemplateSync: _MockQwebTemplateSyncRepository(),
      now: () => DateTime(2026, 8, 26),
    );
    await db.customStatement(
      "INSERT INTO sale_order "
      "(odoo_id, name, is_synced, pending_confirm, has_queued_invoice) VALUES "
      "(1, 'Outside scope', 1, 0, 0), "
      "(2, 'Still current', 1, 0, 0), "
      "(3, 'Unsynced header', 0, 0, 0), "
      "(4, 'Queued write', 1, 0, 0), "
      "(5, 'Unsynced line', 1, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO sale_order_line "
      "(odoo_id, order_id, name, is_synced) VALUES "
      "(51, 5, 'Pending line', 0)",
    );
    await db
        .into(db.offlineQueue)
        .insert(
          OfflineQueueCompanion.insert(
            model: 'sale.order',
            recordId: const Value(4),
            values: '{}',
            createdAt: DateTime(2026, 8, 26),
          ),
        );

    when(
      () => client.call(
        model: 'sync.deleted.record',
        method: 'get_deleted_since',
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer(
      (_) async => const [
        {'record_id': 4},
      ],
    );
    when(
      () => client.call(
        model: 'sale.order',
        method: 'search_read',
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer(
      (_) async => const [
        {'id': 2},
      ],
    );

    final deleted = await repository.syncDeletedRecords(
      odooModel: 'sale.order',
      sinceDate: DateTime.utc(2026, 8, 25),
    );

    expect(deleted, 1);
    expect(
      (await db.select(db.saleOrder).get())
          .map((order) => order.odooId)
          .toSet(),
      {2, 3, 4, 5},
    );
    expect(await db.select(db.saleOrderLine).get(), hasLength(1));

    final scopeCall = verify(
      () => client.call(
        model: 'sale.order',
        method: 'search_read',
        kwargs: captureAny(named: 'kwargs'),
      ),
    );
    final kwargs = scopeCall.captured.single as Map<String, dynamic>;
    final domain = kwargs['domain'] as List<dynamic>;
    expect(
      domain,
      contains(
        equals([
          'id',
          'in',
          [1, 2],
        ]),
      ),
    );
    expect(domain, contains('|'));
    expect(domain, contains(equals(['state', 'in', saleOrderLiveStates])));
    expect(domain, contains(equals(['date_order', '>=', '2026-05-28'])));
  });

  test(
    'removes exhausted advances but preserves local and queued advances',
    () async {
      final client = MockOdooClient.online();
      final repository = SyncCountsRepository(
        appDb: db,
        odooClient: client,
        qwebTemplateSync: _MockQwebTemplateSyncRepository(),
      );
      await db.customStatement(
        "INSERT INTO account_advance "
        "(odoo_id, advance_type, partner_id, date, state, amount_available) VALUES "
        "(10, 'advance', 1, 0, 'posted', 20), "
        "(11, 'advance', 1, 0, 'posted', 20), "
        "(12, 'advance', 1, 0, 'posted', 20), "
        "(-1, 'advance', 1, 0, 'posted', 20)",
      );
      await db
          .into(db.offlineQueue)
          .insert(
            OfflineQueueCompanion.insert(
              model: 'account.advance',
              recordId: const Value(12),
              values: '{}',
              createdAt: DateTime(2026, 8, 26),
            ),
          );

      when(
        () => client.call(
          model: 'sync.deleted.record',
          method: 'get_deleted_since',
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer(
        (_) async => const [
          {'record_id': 12},
        ],
      );
      when(
        () => client.call(
          model: 'account.advance',
          method: 'search_read',
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer(
        (_) async => const [
          {'id': 11},
        ],
      );

      expect(
        await repository.syncDeletedRecords(odooModel: 'account.advance'),
        1,
      );
      expect(
        (await db.select(db.accountAdvance).get())
            .map((advance) => advance.odooId)
            .toSet(),
        {-1, 11, 12},
      );

      final scopeCall = verify(
        () => client.call(
          model: 'account.advance',
          method: 'search_read',
          kwargs: captureAny(named: 'kwargs'),
        ),
      );
      final domain =
          (scopeCall.captured.single as Map<String, dynamic>)['domain']
              as List<dynamic>;
      expect(domain, contains(equals(['state', '=', 'posted'])));
      expect(domain, contains(equals(['amount_available', '>', 0])));
    },
  );

  test('removes closed card lotes and preserves queued lote work', () async {
    final client = MockOdooClient.online();
    final repository = SyncCountsRepository(
      appDb: db,
      odooClient: client,
      qwebTemplateSync: _MockQwebTemplateSyncRepository(),
    );
    await db.customStatement(
      "INSERT INTO account_card_lote "
      "(odoo_id, name, journal_id, state) VALUES "
      "(20, 'Closed remotely', 1, 'open'), "
      "(21, 'Still open', 1, 'open'), "
      "(22, 'Queued update', 1, 'open'), "
      "(-1, 'Local lote', 1, 'open')",
    );
    await db
        .into(db.offlineQueue)
        .insert(
          OfflineQueueCompanion.insert(
            model: 'account.card.lote',
            recordId: const Value(22),
            values: '{}',
            createdAt: DateTime(2026, 8, 26),
          ),
        );

    when(
      () => client.call(
        model: 'sync.deleted.record',
        method: 'get_deleted_since',
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer(
      (_) async => const [
        {'record_id': 22},
      ],
    );
    when(
      () => client.call(
        model: 'account.card.lote',
        method: 'search_read',
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer(
      (_) async => const [
        {'id': 21},
      ],
    );

    expect(
      await repository.syncDeletedRecords(odooModel: 'account.card.lote'),
      1,
    );
    expect(
      (await db.select(db.accountCardLote).get())
          .map((lote) => lote.odooId)
          .toSet(),
      {-1, 21, 22},
    );

    final scopeCall = verify(
      () => client.call(
        model: 'account.card.lote',
        method: 'search_read',
        kwargs: captureAny(named: 'kwargs'),
      ),
    );
    final domain =
        (scopeCall.captured.single as Map<String, dynamic>)['domain']
            as List<dynamic>;
    expect(domain, contains(equals(['state', '=', 'open'])));
  });

  test('removes banks that became inactive', () async {
    final client = MockOdooClient.online();
    final repository = SyncCountsRepository(
      appDb: db,
      odooClient: client,
      qwebTemplateSync: _MockQwebTemplateSyncRepository(),
    );
    await db.customStatement(
      "INSERT INTO res_bank (odoo_id, name) VALUES (30, 'Inactive')",
    );

    when(
      () => client.call(
        model: 'sync.deleted.record',
        method: 'get_deleted_since',
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer((_) async => const []);
    when(
      () => client.call(
        model: 'l10n.ec.bank',
        method: 'search_read',
        kwargs: any(named: 'kwargs'),
        context: any(named: 'context'),
      ),
    ).thenAnswer(
      (_) async => const [
        {'id': 30},
      ],
    );

    expect(await repository.syncDeletedRecords(odooModel: 'l10n.ec.bank'), 1);
    expect(await db.select(db.resBank).get(), isEmpty);

    final inverseCall = verify(
      () => client.call(
        model: 'l10n.ec.bank',
        method: 'search_read',
        kwargs: captureAny(named: 'kwargs'),
        context: any(named: 'context'),
      ),
    );
    final kwargs = inverseCall.captured.single as Map<String, dynamic>;
    expect(kwargs['domain'], contains(equals(['active', '=', false])));
  });

  test('propagates tombstone transport failures', () async {
    final client = MockOdooClient.online();
    final repository = SyncCountsRepository(
      appDb: db,
      odooClient: client,
      qwebTemplateSync: _MockQwebTemplateSyncRepository(),
    );
    when(
      () => client.call(
        model: 'sync.deleted.record',
        method: 'get_deleted_since',
        kwargs: any(named: 'kwargs'),
      ),
    ).thenThrow(StateError('tombstone endpoint unavailable'));

    await expectLater(
      repository.syncDeletedRecords(
        odooModel: 'product.product',
        sinceDate: DateTime.utc(2026, 8, 26),
      ),
      throwsStateError,
    );
  });
}
