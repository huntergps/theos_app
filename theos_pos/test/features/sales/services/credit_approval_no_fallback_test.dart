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
        name: 'TEST-CREDIT-42',
        state: SaleOrderState.approved,
      ),
    );
    repository = SalesRepository(
      db: _DatabaseHelper(),
      appDb: database,
      offlineQueue: queue,
    );

    // No pending request, and a valid partner credit snapshot.
    when(
      () => client.searchRead(
        model: 'approval.request',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        order: any(named: 'order'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => client.searchRead(
        model: 'res.partner',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => [
        {'credit_limit': 1000, 'credit': 0, 'credit_to_invoice': 0},
      ],
    );
    when(
      () => client.searchRead(
        model: 'approval.category',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => [
        {'id': 8, 'name': 'Crédito'},
      ],
    );
    when(
      () => client.searchRead(
        model: 'sale.order',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => [
        {'name': 'TEST-CREDIT-42'},
      ],
    );
    when(
      () => client.create(
        model: 'approval.request',
        values: any(named: 'values'),
      ),
    ).thenAnswer((_) async => 123);
    when(
      () => client.call(
        model: 'approval.request',
        method: 'action_confirm',
        ids: [123],
      ),
    ).thenAnswer((_) async => true);
    when(
      () => client.write(
        model: 'sale.order',
        ids: [42],
        values: {'state': 'waiting'},
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(() async {
    resetModelManagersSession();
    await database.close();
  });

  Future<void> expectUnchanged() async {
    final order = await saleOrderManager.readLocal(42);
    expect(order?.state, SaleOrderState.approved);
    expect(await database.select(database.offlineQueue).get(), isEmpty);
    verifyNever(
      () => client.create(
        model: 'approval.request',
        values: any(named: 'values'),
      ),
    );
    verifyNever(
      () => client.write(
        model: 'sale.order',
        ids: [42],
        values: {'state': 'waiting'},
      ),
    );
  }

  test(
    'wizard create rejection does not use direct approval fallback',
    () async {
      when(
        () => client.create(
          model: 'credit.limit.exceeded.wizard',
          values: any(named: 'values'),
        ),
      ).thenThrow(StateError('AccessError: wizard create denied'));

      await expectLater(
        repository.createCreditApprovalRequest(
          orderId: 42,
          partnerId: 7,
          amount: 250,
          reason: 'Límite excedido',
          checkType: 'credit_limit',
        ),
        throwsA(isA<StateError>()),
      );
      await expectUnchanged();
    },
  );

  test(
    'wizard action rejection does not use direct approval fallback',
    () async {
      when(
        () => client.create(
          model: 'credit.limit.exceeded.wizard',
          values: any(named: 'values'),
        ),
      ).thenAnswer((_) async => 99);
      when(
        () => client.call(
          model: 'credit.limit.exceeded.wizard',
          method: 'action_create_approval_request',
          ids: [99],
        ),
      ).thenThrow(StateError('ValidationError: approval rejected'));

      await expectLater(
        repository.createCreditApprovalRequest(
          orderId: 42,
          partnerId: 7,
          amount: 250,
          reason: 'Límite excedido',
          checkType: 'credit_limit',
        ),
        throwsA(isA<StateError>()),
      );
      await expectUnchanged();
    },
  );

  test(
    'native approval action uses context and confirms pending request',
    () async {
      const action = {
        'type': 'ir.actions.act_window',
        'res_model': 'credit.limit.exceeded.wizard',
        'context': {'default_sale_order_id': 42, 'default_partner_id': 7},
      };
      when(
        () => client.call(
          model: 'credit.limit.exceeded.wizard',
          method: 'create',
          kwargs: {
            'vals_list': [<String, dynamic>{}],
          },
          context: any(named: 'context'),
        ),
      ).thenAnswer((_) async => 77);
      when(
        () => client.call(
          model: 'credit.limit.exceeded.wizard',
          method: 'action_create_approval_request',
          ids: [77],
        ),
      ).thenAnswer((_) async => true);
      when(
        () => client.searchRead(
          model: 'approval.request',
          domain: any(named: 'domain'),
          fields: ['id'],
          order: 'id desc',
          limit: 1,
        ),
      ).thenAnswer(
        (_) async => [
          {'id': 501},
        ],
      );

      final result = await repository.createCreditApprovalRequest(
        orderId: 42,
        partnerId: 7,
        amount: 250,
        reason: 'Límite excedido',
        checkType: 'credit_limit',
        approvalAction: action,
      );

      expect(result, 501);
      verifyNever(
        () => client.searchRead(
          model: 'res.partner',
          domain: any(named: 'domain'),
          fields: any(named: 'fields'),
          limit: any(named: 'limit'),
        ),
      );
      verifyNever(
        () => client.create(
          model: 'approval.request',
          values: any(named: 'values'),
        ),
      );
    },
  );

  test(
    'native approval action with another order or partner is rejected',
    () async {
      const action = {
        'type': 'ir.actions.act_window',
        'res_model': 'credit.limit.exceeded.wizard',
        'context': {'default_sale_order_id': 999, 'default_partner_id': 998},
      };

      await expectLater(
        repository.createCreditApprovalRequest(
          orderId: 42,
          partnerId: 7,
          amount: 250,
          reason: 'Límite excedido',
          checkType: 'credit_limit',
          approvalAction: action,
        ),
        throwsA(isA<StateError>()),
      );
      verifyNever(
        () => client.call(
          model: 'credit.limit.exceeded.wizard',
          method: 'create',
          kwargs: any(named: 'kwargs'),
          context: any(named: 'context'),
        ),
      );
      verifyNever(
        () => client.create(
          model: 'approval.request',
          values: any(named: 'values'),
        ),
      );
    },
  );

  test('native action without a confirmed pending request fails', () async {
    const action = {
      'type': 'ir.actions.act_window',
      'res_model': 'credit.limit.exceeded.wizard',
      'context': {'default_sale_order_id': 42, 'default_partner_id': 7},
    };
    when(
      () => client.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'create',
        kwargs: {
          'vals_list': [<String, dynamic>{}],
        },
        context: any(named: 'context'),
      ),
    ).thenAnswer((_) async => 77);
    when(
      () => client.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'action_create_approval_request',
        ids: [77],
      ),
    ).thenAnswer((_) async => true);

    await expectLater(
      repository.createCreditApprovalRequest(
        orderId: 42,
        partnerId: 7,
        amount: 250,
        reason: 'Límite excedido',
        checkType: 'credit_limit',
        approvalAction: action,
      ),
      throwsA(isA<StateError>()),
    );
    verifyNever(
      () => client.create(
        model: 'approval.request',
        values: any(named: 'values'),
      ),
    );
  });
}
