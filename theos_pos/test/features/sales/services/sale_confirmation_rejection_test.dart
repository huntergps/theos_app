import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/core/managers/manager_providers.dart';
import 'package:theos_pos/features/sales/repositories/sales_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import '../../../mocks/mock_odoo_client.dart';

class _DatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  late AppDatabase database;
  late MockOdooClient client;
  late OfflineQueueDataSource queue;
  late SalesRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    client = MockOdooClient.online();
    queue = OfflineQueueDataSource(database);
    await initializeModelManagers(
      client: client,
      db: database,
      queueStore: queue,
    );
    await saleOrderManager.upsertLocal(
      const SaleOrder(
        id: 42,
        name: 'TEST-CONFIRM-42',
        state: SaleOrderState.approved,
      ),
    );
    repository = SalesRepository(
      db: _DatabaseHelper(),
      appDb: database,
      offlineQueue: queue,
    );
  });

  tearDown(() async {
    resetModelManagersSession();
    await database.close();
  });

  for (final response in <Map<String, dynamic>>[
    {'success': false, 'error': 'Requiere aprobación de crédito'},
    {'success': true, 'order_id': 42, 'state': 'approved'},
    {
      'type': 'ir.actions.act_window',
      'res_model': 'credit.limit.exceeded.wizard',
    },
  ]) {
    test('confirmation does not publish sale for $response', () async {
      when(
        () => client.call(
          model: 'sale.order',
          method: 'action_pos_confirm',
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer((_) async => response);

      await expectLater(repository.confirm(42), throwsA(isA<StateError>()));

      final order = await saleOrderManager.readLocal(42);
      expect(order?.state, SaleOrderState.approved);
      expect(await database.select(database.offlineQueue).get(), isEmpty);
      verify(
        () => client.call(
          model: 'sale.order',
          method: 'action_pos_confirm',
          ids: [42],
          kwargs: any(named: 'kwargs'),
        ),
      ).called(1);
    });
  }

  test(
    'preserves pending approval without pretending to sell locally',
    () async {
      final action = <String, dynamic>{
        'type': 'ir.actions.act_window',
        'res_model': 'credit.limit.exceeded.wizard',
        'context': {
          'default_sale_order_id': 42,
          'default_partner_id': 7,
          'default_check_type': 'overdue_debt',
          'default_transaction_amount': 10,
        },
      };
      when(
        () => client.call(
          model: 'sale.order',
          method: 'action_pos_confirm',
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer(
        (_) async => {
          'success': false,
          'approval_required': true,
          'order_id': 42,
          'state': 'approved',
          'action': action,
        },
      );

      final result = await repository.posConfirm(42);

      expect(result.requiresApproval, isTrue);
      expect(result.approvalAction, equals(action));
      expect(result.creditIssue?.type, 'overdue_debt');
      expect(result.success, isFalse);
      expect(
        (await saleOrderManager.readLocal(42))?.state,
        SaleOrderState.approved,
      );
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );

  test(
    'rejects pending approval action for another order without queueing',
    () async {
      when(
        () => client.call(
          model: 'sale.order',
          method: 'action_pos_confirm',
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer(
        (_) async => {
          'success': false,
          'approval_required': true,
          'order_id': 42,
          'state': 'approved',
          'action': {
            'type': 'ir.actions.act_window',
            'res_model': 'credit.limit.exceeded.wizard',
            'context': {'default_sale_order_id': 43},
          },
        },
      );

      final result = await repository.posConfirm(42);

      expect(result.requiresApproval, isFalse);
      expect(result.success, isFalse);
      expect(
        (await saleOrderManager.readLocal(42))?.state,
        SaleOrderState.approved,
      );
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );
}
