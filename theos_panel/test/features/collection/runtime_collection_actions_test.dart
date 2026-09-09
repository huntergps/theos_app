import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/collection/collection_contracts.dart';
import 'package:theos_panel/features/collection/runtime_collection_actions.dart';

final class _Actions implements SaleOdooActions {
  final List<String> calls = [];
  bool ambiguousCash = false;
  bool reconciled = false;

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    calls.add('$model.$method');
    if (model == 'account.move' && method == 'search_read') {
      return reconciled
          ? [
              {
                'id': 88,
                'state': 'posted',
                'payment_state': 'paid',
                'amount_total': 12.50,
                'amount_residual': 0.0,
                'l10n_ec_pos_collection_completed': true,
              },
            ]
          : <Map<String, dynamic>>[];
    }
    if (method == 'action_pos_confirm_and_invoice' && ambiguousCash) {
      ambiguousCash = false;
      reconciled = true;
      throw const AmbiguousOperationException('timeout');
    }
    if (model == 'sale.order' && method == 'search_read') {
      return const [
        {
          'id': 9,
          'invoice_ids': [88],
        },
      ];
    }
    return true;
  }
}

void main() {
  test(
    'generic queued close remains closing until replay confirms it',
    () async {
      final actions = _Actions();
      final runtimeActions = RuntimeCollectionActions(
        sales: null,
        sessions: OdooCollectionSessionStore(actions, const _VersionReader()),
        scopeKey: 'scope',
      );
      final next = await runtimeActions.close(
        const CollectionShiftSnapshot(
          id: '8',
          state: CollectionShiftState.opened,
          expectedVersion: 0,
        ),
      );
      expect(next.state, CollectionShiftState.closing);
    },
  );

  test(
    'offline cash collection survives reopen, dedupes and reconciles',
    () async {
      final directory = await Directory.systemTemp.createTemp('orbi-u06-');
      final file = File('${directory.path}/runtime.sqlite');
      final firstDb = AppDatabase(NativeDatabase(file));
      final firstQueue = OfflineQueueDataSource(firstDb);
      final scope = AppScope(
        appId: 'panel',
        installationId: 'installation',
        normalizedServerUrl: 'https://example.test',
        database: 'db',
        userId: 1,
      );
      final sessions = OdooCollectionSessionStore(
        _Actions(),
        const _VersionReader(),
      );
      final actions = RuntimeCollectionActions(
        sales: null,
        sessions: sessions,
        queue: firstQueue,
        scopeKey: scope.scopeKey,
      );
      const sale = CollectionPendingSale(
        id: 'sale-9',
        label: 'Venta',
        amountMinor: 1250,
        route: CollectionSaleRoute.cashInvoice,
        remoteId: 9,
        commandId: 'collect-9',
        collectionSessionId: 3,
      );
      const payments = [
        CollectionPaymentDraft(journalId: 7, amountMinor: 1250),
      ];
      expect(
        await actions.collect(sale, payments),
        CollectionResultState.queued,
      );
      expect(
        await actions.collect(sale, payments),
        CollectionResultState.queued,
      );
      expect(await firstDb.select(firstDb.offlineQueue).get(), hasLength(1));
      await firstDb.close();

      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await reopened.close();
        await directory.delete(recursive: true);
      });
      final rpc = _Actions()..ambiguousCash = true;
      final job = OperationsSyncJob(
        queue: OfflineQueueDataSource(reopened),
        adapter: OdooOfflineOperationAdapter(
          actions: rpc,
          database: reopened,
          scope: scope,
          queue: OfflineQueueDataSource(reopened),
        ),
      );
      expect((await job.run(scope)).cursorConfirmed, isTrue);
      expect(rpc.calls, contains('sale.order.action_pos_confirm_and_invoice'));
      expect(rpc.calls, contains('account.move.search_read'));
      expect(await reopened.select(reopened.offlineQueue).get(), isEmpty);
      await job.dispose();
    },
  );
}

final class _VersionReader implements SaleShiftVersionReader {
  const _VersionReader();
  @override
  Future<int> read(EntityReference shift) async => 0;
}
