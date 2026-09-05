import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/features/sync/services/offline_sync_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    hide DatabaseHelper, OfflineOperation;

import '../../../mocks/mock_odoo_client.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

class _MemoryAuditLogger implements OfflineQueueAuditLogger {
  final operations = <String>[];
  final conflicts = <ConflictInfo>[];

  @override
  Future<void> logConflict(OfflineOperation op, ConflictInfo conflict) async {
    conflicts.add(conflict);
  }

  @override
  Future<void> logOperation(
    OfflineOperation op, {
    required String result,
    int? odooId,
    String? errorMessage,
  }) async {
    operations.add(result);
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
    when(
      () => client.hasField(
        'l10n_ec_collection_box.sale.order.payment.wizard.line',
        'line_type',
      ),
    ).thenAnswer((_) async => true);
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

  Future<int> queueInvoice({
    String? accessKey,
    int? sequential,
    String? emissionDate,
    String? clientOpUuid,
  }) {
    final key =
        accessKey ?? '0509202601179001122300110010020000000013121521410';
    return queue.queueCommand(
      model: 'sale.order',
      command: OfflineLocalCommand.invoiceCreateWithPayments,
      parentOrderId: 42,
      values: {
        'sale_id': 42,
        'order_uuid': 'order-test-42',
        'offline_access_key': key,
        'offline_invoice_name': '001-002-000000001',
        'sequential': sequential ?? 1,
        'emission_date': emissionDate ?? '2026-09-05',
        'client_op_uuid': clientOpUuid ?? 'invoice-test-42',
        'collection_session_id': 8,
        'payment_lines': [
          {
            'date': '2026-08-26',
            'amount': 20.0,
            'journal_id': 4,
            'payment_method_line_id': 6,
            'state': 'draft',
          },
        ],
      },
    );
  }

  void stubNoExistingInvoice() {
    when(
      () => client.searchRead(
        model: 'account.move',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer((_) async => const []);
  }

  for (final wrappedPrintAction in [false, true]) {
    test(
      'canonical replay completes on invoice (print wrapper: $wrappedPrintAction)',
      () async {
        stubNoExistingInvoice();
        when(
          () => client.call(
            model: 'l10n_ec_collection_box.sale.order.payment.wizard',
            method: 'create',
            ids: null,
            // ignore: deprecated_member_use
            args: null,
            kwargs: any(named: 'kwargs'),
          ),
        ).thenAnswer((_) async => 71);
        when(
          () => client.call(
            model: 'l10n_ec_collection_box.sale.order.payment.wizard',
            method: 'action_apply_and_create_invoice',
            ids: [71],
            // ignore: deprecated_member_use
            args: null,
            kwargs: null,
          ),
        ).thenAnswer(
          (_) async => wrappedPrintAction
              ? {
                  'type': 'ir.actions.client',
                  'tag': 'collection_print',
                  'params': {
                    'next_action': {
                      'type': 'ir.actions.act_window',
                      'res_model': 'account.move',
                      'res_id': 901,
                    },
                  },
                }
              : {
                  'type': 'ir.actions.act_window',
                  'res_model': 'account.move',
                  'res_id': 901,
                },
        );
        await queueInvoice();

        final result = await service.processQueue();

        expect(result.errors, isEmpty);
        expect(result.synced, 1);
        expect(result.conflicts, isEmpty);
        expect(await queue.getPendingCount(), 0);
        final invocation = verify(
          () => client.call(
            model: 'l10n_ec_collection_box.sale.order.payment.wizard',
            method: 'create',
            ids: null,
            // ignore: deprecated_member_use
            args: null,
            kwargs: captureAny(named: 'kwargs'),
          ),
        );
        final kwargs = invocation.captured.single as Map<String, dynamic>;
        final wizard = (kwargs['vals_list'] as List).single as Map;
        final command = (wizard['line_ids'] as List).single as List;
        final line = command[2] as Map;
        expect(line, containsPair('line_type', 'payment'));
        expect(line, isNot(contains('state')));
        expect(wizard, containsPair('pos_client_sequential', 1));
        expect(wizard, containsPair('pos_emission_date', '2026-09-05'));
        expect(
          wizard,
          containsPair(
            'pos_access_key',
            '0509202601179001122300110010020000000013121521410',
          ),
        );
        expect(wizard, containsPair('pos_client_op_uuid', 'invoice-test-42'));
        verifyNever(
          () => client.call(
            model: 'sale.order',
            method: 'action_pos_confirm_and_invoice',
            ids: any(named: 'ids'),
            // ignore: deprecated_member_use
            args: null,
            kwargs: any(named: 'kwargs'),
          ),
        );
      },
    );
  }

  test(
    'overpayment confirmation is retained as a conflict, not success',
    () async {
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'create',
          ids: null,
          // ignore: deprecated_member_use
          args: null,
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer((_) async => 71);
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'action_apply_and_create_invoice',
          ids: [71],
          // ignore: deprecated_member_use
          args: null,
          kwargs: null,
        ),
      ).thenAnswer(
        (_) async => {
          'type': 'ir.actions.act_window',
          'res_model': 'l10n_ec_collection_box.confirm.advance.wizard',
          'context': {
            'default_payment_wizard_id': 71,
            'default_sale_id': 42,
            'default_overpayment_amount': 3.5,
          },
        },
      );
      final operationId = await queueInvoice();

      final result = await service.processQueue();

      expect(result.errors, isEmpty);
      expect(result.synced, 0);
      expect(result.conflicts, hasLength(1));
      expect(audit.conflicts, hasLength(1));
      final retained = await queue.getOperationById(operationId);
      expect(retained?.status, OfflineOperationStatus.conflict);
      expect(await queue.getPendingCount(), 0);
    },
  );

  test(
    'replay runs the payment wizard even when the invoice already exists',
    () async {
      when(
        () => client.searchRead(
          model: 'account.move',
          domain: any(named: 'domain'),
          fields: any(named: 'fields'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
        ),
      ).thenAnswer(
        (_) async => const [
          {'id': 901},
        ],
      );
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'create',
          ids: null,
          // ignore: deprecated_member_use
          args: null,
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer((_) async => 71);
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'action_apply_and_create_invoice',
          ids: [71],
          // ignore: deprecated_member_use
          args: null,
          kwargs: null,
        ),
      ).thenAnswer(
        (_) async => {
          'type': 'ir.actions.act_window',
          'res_model': 'account.move',
          'res_id': 901,
        },
      );
      await queueInvoice();

      final result = await service.processQueue();

      expect(result.errors, isEmpty);
      expect(result.synced, 1);
      expect(await queue.getPendingCount(), 0);
      verify(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'create',
          ids: null,
          // ignore: deprecated_member_use
          args: null,
          kwargs: any(named: 'kwargs'),
        ),
      ).called(1);
    },
  );

  test('rejects an offline invoice key that is not 49 digits', () async {
    await queueInvoice(accessKey: '9' * 48);
    final result = await service.processQueue();
    expect(result.synced, 0);
    expect(result.errors, hasLength(1));
    expect(result.conflicts, isEmpty);
    expect(await queue.getOperationById(1), isNotNull);
    verifyNever(
      () => client.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'create',
        ids: null,
        // ignore: deprecated_member_use
        args: null,
        kwargs: any(named: 'kwargs'),
      ),
    );
  });

  test('rejects a sequential that disagrees with the offline key', () async {
    await queueInvoice(sequential: 2);
    final result = await service.processQueue();
    expect(result.synced, 0);
    expect(result.errors, hasLength(1));
    expect(result.conflicts, isEmpty);
    expect(await queue.getOperationById(1), isNotNull);
    verifyNever(
      () => client.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'create',
        ids: null,
        // ignore: deprecated_member_use
        args: null,
        kwargs: any(named: 'kwargs'),
      ),
    );
  });

  test(
    'rejects an impossible or mismatched fiscal date before wizard create',
    () async {
      const validKey = '0509202601179001122300110010020000000013121521410';
      final impossibleDateKey = '32022026${validKey.substring(8)}';
      await queueInvoice(accessKey: impossibleDateKey);
      final result = await service.processQueue();
      expect(result.synced, 0);
      expect(result.errors, hasLength(1));
      expect(result.conflicts, isEmpty);
      expect(await queue.getOperationById(1), isNotNull);
      verifyNever(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'create',
          ids: null,
          // ignore: deprecated_member_use
          args: null,
          kwargs: any(named: 'kwargs'),
        ),
      );
    },
  );

  test(
    'session-open replay reconciles an already-open remote session',
    () async {
      when(
        () => client.searchRead(
          model: 'collection.session',
          domain: any(named: 'domain'),
          fields: any(named: 'fields'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
        ),
      ).thenAnswer(
        (_) async => const [
          {'id': 81, 'state': 'opened'},
        ],
      );
      await queue.queueCommand(
        model: 'collection.session',
        command: OfflineLocalCommand.sessionOpen,
        recordId: 81,
        values: const {'session_id': 81, 'cash_register_balance_start': 100.0},
      );

      final result = await service.processQueue();

      expect(result.errors, isEmpty);
      expect(result.synced, 1);
      verifyNever(
        () => client.write(
          model: 'collection.session',
          ids: any(named: 'ids'),
          values: any(named: 'values'),
        ),
      );
      verifyNever(
        () => client.call(
          model: 'collection.session',
          method: 'action_session_open',
          ids: any(named: 'ids'),
          // ignore: deprecated_member_use
          args: null,
          kwargs: any(named: 'kwargs'),
        ),
      );
    },
  );

  test('local-wins resumes the recorded overpayment confirmation', () async {
    stubNoExistingInvoice();
    final operationId = await queueInvoice();
    final action = {
      'type': 'ir.actions.act_window',
      'res_model': 'l10n_ec_collection_box.confirm.advance.wizard',
      'context': {
        'default_payment_wizard_id': 71,
        'default_sale_id': 42,
        'default_overpayment_amount': 3.5,
      },
    };
    final now = DateTime.now().toUtc();
    await database
        .into(database.syncConflict)
        .insert(
          SyncConflictCompanion.insert(
            operationId: operationId,
            model: 'sale.order',
            localId: 42,
            remoteId: 42,
            conflictType: 'both_modified',
            localData: jsonEncode({
              'field': '__record__',
              'value': jsonEncode(const {'resolution_required': true}),
              'write_date': now.toIso8601String(),
            }),
            remoteData: jsonEncode({
              'field': '__record__',
              'value': jsonEncode(action),
              'write_date': now.toIso8601String(),
            }),
            detectedAt: now,
            resolution: const drift.Value('local_wins'),
            isResolved: const drift.Value(true),
            resolvedAt: drift.Value(now),
          ),
        );
    when(
      () => client.call(
        model: 'l10n_ec_collection_box.confirm.advance.wizard',
        method: 'create',
        ids: null,
        // ignore: deprecated_member_use
        args: null,
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer((_) async => 72);
    when(
      () => client.call(
        model: 'l10n_ec_collection_box.confirm.advance.wizard',
        method: 'action_create_advance',
        ids: [72],
        // ignore: deprecated_member_use
        args: null,
        kwargs: null,
      ),
    ).thenAnswer(
      (_) async => {
        'type': 'ir.actions.act_window',
        'res_model': 'account.move',
        'res_id': 902,
      },
    );

    final result = await service.processQueue();

    expect(result.errors, isEmpty);
    expect(result.synced, 1);
    verifyNever(
      () => client.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'create',
        ids: any(named: 'ids'),
        // ignore: deprecated_member_use
        args: null,
        kwargs: any(named: 'kwargs'),
      ),
    );
  });
}
