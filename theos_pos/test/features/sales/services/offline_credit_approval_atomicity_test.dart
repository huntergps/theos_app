import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/core/managers/manager_providers.dart';
import 'package:theos_pos/features/sales/repositories/sales_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

final class _FailingOfflineQueue extends OfflineQueueDataSource {
  _FailingOfflineQueue(super.db);

  @override
  Future<int> queueOperation({
    required String model,
    required String method,
    int? recordId,
    required Map<String, dynamic> values,
    DateTime? baseWriteDate,
    int? parentOrderId,
    int priority = OfflinePriority.normal,
    String? deviceId,
    String? operationKey,
    int commandVersion = 1,
    OfflineReplayPolicy? replayPolicy,
  }) => throw StateError('simulated credit approval outbox failure');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late OfflineQueueDataSource queue;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    queue = OfflineQueueDataSource(database);
    await initializeModelManagers(db: database, queueStore: queue);
  });

  tearDown(() async {
    resetModelManagersSession();
    await database.close();
  });

  SaleOrder order(int id) => SaleOrder(
    id: id,
    orderUuid: 'credit-order-$id',
    name: 'SO$id',
    state: SaleOrderState.draft,
    partnerId: 77,
    amountTotal: 125,
  );

  SalesRepository repository(OfflineQueueDataSource? offlineQueue) =>
      SalesRepository(
        db: _MockDatabaseHelper(),
        appDb: database,
        offlineQueue: offlineQueue,
      );

  Future<void> expectOriginalOrder(int id) async {
    final local = await saleOrderManager.readLocal(id);
    expect(local, isNotNull);
    expect(local!.state, SaleOrderState.draft);
    final row = await (database.select(
      database.saleOrder,
    )..where((table) => table.odooId.equals(id))).getSingle();
    expect(row.pendingConfirm, isFalse);
  }

  test(
    'failed credit approval queue rolls back waiting and pendingConfirm',
    () async {
      await saleOrderManager.upsertLocal(order(301));
      final repo = repository(_FailingOfflineQueue(database));

      await expectLater(
        repo.createCreditApprovalRequest(
          orderId: 301,
          partnerId: 77,
          amount: 125,
          reason: 'limit',
          checkType: 'credit_limit',
        ),
        throwsA(isA<StateError>()),
      );

      await expectOriginalOrder(301);
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );

  test(
    'credit approval without an offline queue does not mutate the order',
    () async {
      await saleOrderManager.upsertLocal(order(302));

      final result = await repository(null).createCreditApprovalRequest(
        orderId: 302,
        partnerId: 77,
        amount: 125,
        reason: 'limit',
        checkType: 'credit_limit',
      );

      expect(result, isNull);
      await expectOriginalOrder(302);
    },
  );

  test(
    'real offline queue preserves waiting order and credit approval command',
    () async {
      await saleOrderManager.upsertLocal(order(303));

      final result = await repository(queue).createCreditApprovalRequest(
        orderId: 303,
        partnerId: 77,
        amount: 125,
        reason: 'limit',
        checkType: 'credit_limit',
        paymentTermId: 12,
      );

      expect(result, -1);
      final local = await saleOrderManager.readLocal(303);
      expect(local!.state, SaleOrderState.waitingApproval);
      final row = await (database.select(
        database.saleOrder,
      )..where((table) => table.odooId.equals(303))).getSingle();
      expect(row.pendingConfirm, isTrue);

      final operations = await queue.getOperationsForSaleOrder(303);
      expect(operations, hasLength(1));
      final operation = operations.single;
      expect(operation.method, 'credit_approval_create');
      expect(
        operation.operationKey,
        'v1:sale.order:credit_approval_create:credit-order-303:credit_limit',
      );
      expect(operation.values['order_uuid'], 'credit-order-303');
      expect(operation.values['payment_term_id'], 12);
    },
  );
}
