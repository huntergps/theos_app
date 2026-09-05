import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/features/sales/services/credit_approval_service.dart';
import 'package:theos_pos/features/sync/services/offline_sync_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    hide DatabaseHelper, OfflineOperation;

import '../../../mocks/mock_odoo_client.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

class _MemoryAuditLogger implements OfflineQueueAuditLogger {
  final results = <String>[];

  @override
  Future<void> logConflict(OfflineOperation op, ConflictInfo conflict) async {}

  @override
  Future<void> logOperation(
    OfflineOperation op, {
    required String result,
    int? odooId,
    String? errorMessage,
  }) async {
    results.add(result);
  }
}

void main() {
  late AppDatabase database;
  late OfflineQueueDataSource queue;
  late MockOdooClient client;
  late _MemoryAuditLogger audit;
  late OfflineSyncService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    queue = OfflineQueueDataSource(database);
    client = MockOdooClient.online();
    audit = _MemoryAuditLogger();
    service = OfflineSyncService(
      db: _MockDatabaseHelper(),
      appDb: database,
      odooClient: client,
      offlineQueue: queue,
      sessionManager: collectionSessionManager,
      paymentManager: accountPaymentManager,
      auditLogger: audit,
    );
  });

  tearDown(() async {
    await service.shutdown();
    await database.close();
  });

  Future<int> enqueueApproval() => CreditApprovalOfflineContract.enqueue(
    queue: queue,
    orderId: 42,
    partnerId: 7,
    amount: 125.50,
    checkType: 'credit_limit_exceeded',
    paymentTermId: 9,
    orderUuid: 'order-42',
  );

  void stubNoPendingApproval() {
    when(
      () => client.searchRead(
        model: 'approval.request',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer((_) async => const []);
  }

  void stubPartnerCredit() {
    when(
      () => client.searchRead(
        model: 'res.partner',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer(
      (_) async => const [
        {'credit_limit': 500.0, 'credit': 100.0, 'credit_to_invoice': 25.0},
      ],
    );
  }

  test(
    'replays the canonical JSON-2 wizard and removes the operation',
    () async {
      stubNoPendingApproval();
      stubPartnerCredit();
      when(
        () => client.call(
          model: 'credit.limit.exceeded.wizard',
          method: 'create',
          ids: null,
          // ignore: deprecated_member_use
          args: null,
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer((_) async => [71]);
      when(
        () => client.call(
          model: 'credit.limit.exceeded.wizard',
          method: 'action_create_approval_request',
          ids: [71],
          // ignore: deprecated_member_use
          args: null,
          kwargs: null,
        ),
      ).thenAnswer((_) async => null);
      final operationId = await enqueueApproval();

      final queued = await queue.getOperationById(operationId);
      expect(queued?.method, CreditApprovalOfflineContract.method);
      expect(queued?.replayPolicy, OfflineReplayPolicy.retrySafe);
      final result = await service.processQueue();

      expect(result.synced, 1);
      expect(result.errors, isEmpty);
      expect(await queue.getOperationById(operationId), isNull);
      final invocation = verify(
        () => client.call(
          model: 'credit.limit.exceeded.wizard',
          method: 'create',
          ids: null,
          // ignore: deprecated_member_use
          args: null,
          kwargs: captureAny(named: 'kwargs'),
        ),
      );
      final kwargs = invocation.captured.single as Map<String, dynamic>;
      final values = (kwargs['vals_list'] as List).single as Map;
      expect(values, containsPair('sale_order_id', 42));
      expect(values, containsPair('partner_id', 7));
      expect(values, containsPair('transaction_amount', 125.50));
      expect(values, containsPair('credit_available', 375.0));
      expect(values, containsPair('payment_term_id', 9));
    },
  );

  test('retry reconciles a remote commit and does not create twice', () async {
    stubNoPendingApproval();
    stubPartnerCredit();
    when(
      () => client.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'create',
        ids: null,
        // ignore: deprecated_member_use
        args: null,
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer((_) async => 71);
    when(
      () => client.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'action_create_approval_request',
        ids: [71],
        // ignore: deprecated_member_use
        args: null,
        kwargs: null,
      ),
    ).thenThrow(StateError('response lost after commit'));
    final operationId = await enqueueApproval();

    final firstResult = await service.processQueue();

    expect(firstResult.failed, 1);
    var retained = await queue.getOperationById(operationId);
    expect(retained?.status, OfflineOperationStatus.pending);
    expect(retained?.replayPolicy, OfflineReplayPolicy.retrySafe);
    await queue.resetOperationRetry(operationId);
    when(
      () => client.searchRead(
        model: 'approval.request',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer(
      (_) async => const [
        {'id': 88},
      ],
    );

    final retryResult = await service.processQueue();

    expect(retryResult.synced, 1);
    expect(await queue.getOperationById(operationId), isNull);
    verify(
      () => client.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'create',
        ids: null,
        // ignore: deprecated_member_use
        args: null,
        kwargs: any(named: 'kwargs'),
      ),
    ).called(1);
    verify(
      () => client.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'action_create_approval_request',
        ids: [71],
        // ignore: deprecated_member_use
        args: null,
        kwargs: null,
      ),
    ).called(1);
  });

  test(
    'non-ambiguous invalid payload fails before any JSON-2 request',
    () async {
      final operationId = await queue.queueOperation(
        model: CreditApprovalOfflineContract.aggregateModel,
        method: CreditApprovalOfflineContract.method,
        recordId: 42,
        parentOrderId: 42,
        values: const {
          'order_id': 42,
          'partner_id': 0,
          'amount': 125.50,
          'check_type': 'credit_limit_exceeded',
        },
        commandVersion: CreditApprovalOfflineContract.version,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );

      final result = await service.processQueue();

      expect(result.failed, 1);
      final retained = await queue.getOperationById(operationId);
      expect(retained?.status, OfflineOperationStatus.pending);
      expect(retained?.retryCount, 1);
      expect(await queue.getDeadLetterOperations(), isEmpty);
      verifyNever(
        () => client.searchRead(
          model: any(named: 'model'),
          domain: any(named: 'domain'),
          fields: any(named: 'fields'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
        ),
      );
      verifyNever(
        () => client.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          ids: any(named: 'ids'),
          // ignore: deprecated_member_use
          args: any(named: 'args'),
          kwargs: any(named: 'kwargs'),
        ),
      );
    },
  );
}
