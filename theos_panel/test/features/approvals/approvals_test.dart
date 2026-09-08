import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/approvals/approval_contracts.dart';
import 'package:theos_panel/features/approvals/approvals_screen.dart';
import 'package:theos_panel/features/approvals/approval_runtime_adapter.dart';
import 'package:theos_panel/app/business_composition_factory.dart';

class FakeApprovalPort implements ApprovalPort {
  FakeApprovalPort(this.items);
  final List<ApprovalRequest> items;
  final actions = <ApprovalAction>[];
  final decisions = <ApprovalDecision>[];
  @override
  Future<List<ApprovalRequest>> pending() async => List.unmodifiable(items);
  @override
  Future<ApprovalResult> request(ApprovalRequest request) async =>
      const ApprovalResult(accepted: true, message: 'Solicitada');
  @override
  Future<ApprovalResult> resolve({
    required ApprovalRequest request,
    required ApprovalDecision decision,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async {
    decisions.add(decision);
    if (offline && !snapshot.offlineOperations.contains('approve_credit')) {
      return const ApprovalResult(
        accepted: false,
        message: 'Capacidad offline no vigente',
      );
    }
    return const ApprovalResult(accepted: true, message: 'Decisión registrada');
  }

  @override
  Future<ApprovalResult> performAction({
    required ApprovalRequest request,
    required ApprovalAction action,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async {
    actions.add(action);
    if (action == ApprovalAction.delivery) {
      return const ApprovalResult(
        accepted: false,
        message: 'Entrega requiere cobro',
      );
    }
    if (!request.fsc || request.terms != ApprovalTerms.cash) {
      return const ApprovalResult(
        accepted: false,
        message: 'FSC requiere contado',
      );
    }
    return const ApprovalResult(
      accepted: true,
      message:
          'Factura y despacho preparados; entrega queda condicionada al pago',
    );
  }
}

CapabilitySnapshot snapshot({Iterable<String> offline = const []}) =>
    CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 2,
      fetchedAt: DateTime.utc(2026, 1, 1),
      offlineOperations: offline,
    );

final class _Rpc implements ApprovalRpc {
  final calls = <Map<String, dynamic>>[];
  dynamic response = const {'approval_required': true};
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    calls.add({'model': model, 'method': method, 'ids': ids, 'kwargs': kwargs});
    return response;
  }
}

final class _Actions implements SaleOdooActions {
  final calls = <Map<String, dynamic>>[];
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    calls.add({'model': model, 'method': method, 'ids': ids, 'kwargs': kwargs});
    return null;
  }
}

final class _Queue implements ApprovalOfflineQueue {
  final ids = <String>[];
  @override
  Future<void> enqueue({
    required String commandId,
    required ApprovalRequest request,
    required ApprovalAction action,
    required String scopeKey,
    ApprovalDecision? decision,
  }) async => ids.add(commandId);
}

SessionApprovalPort _runtimePort(_Rpc rpc, _Queue queue) {
  final client = OdooClient(
    config: OdooClientConfig(
      baseUrl: 'https://erp.test',
      apiKey: 'test',
      database: 'db',
    ),
  );
  return SessionApprovalPort(
    runtime: SessionRuntime(),
    capabilities: CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026),
      permissions: const ['approver'],
      offlineOperations: const ['approve_credit'],
    ),
    offlineQueue: queue,
    rpcFactory: (_) => rpc,
    sessionContext: () =>
        ApprovalSessionContext(scopeKey: 'scope', userId: 7, client: client),
  );
}

void main() {
  test('port rejects FSC for credit before any action', () {
    expect(
      () => ApprovalRequest(
        commandId: 'a',
        orderDisplayName: 'SO-17',
        saleOrderRemoteId: 17,
        terms: ApprovalTerms.credit,
        fsc: true,
        status: ApprovalStatus.requested,
      ),
      throwsArgumentError,
    );
  });
  test(
    'offline approval requires provisioned capability and FSC never delivers',
    () async {
      final port = FakeApprovalPort([]);
      final request = ApprovalRequest(
        commandId: 'a',
        orderDisplayName: 'SO-17',
        saleOrderRemoteId: 17,
        terms: ApprovalTerms.cash,
        fsc: true,
        status: ApprovalStatus.approved,
      );
      final denied = await port.resolve(
        request: request,
        decision: ApprovalDecision.approve,
        snapshot: snapshot(),
        offline: true,
      );
      expect(denied.accepted, isFalse);
      final fsc = await port.performAction(
        request: request,
        action: ApprovalAction.fscInvoiceAndDispatch,
        snapshot: snapshot(),
        offline: false,
      );
      expect(fsc.accepted, isTrue);
      final delivery = await port.performAction(
        request: request,
        action: ApprovalAction.delivery,
        snapshot: snapshot(),
        offline: false,
      );
      expect(delivery.accepted, isFalse);
    },
  );
  test('unconfigured production port never approves', () async {
    final result = await const UnavailableApprovalPort().resolve(
      request: ApprovalRequest(
        commandId: 'a',
        orderDisplayName: 'SO-17',
        approvalRequestRemoteId: 9,
        saleOrderRemoteId: 17,
        terms: ApprovalTerms.cash,
        fsc: false,
        status: ApprovalStatus.requested,
      ),
      decision: ApprovalDecision.approve,
      snapshot: snapshot(),
      offline: false,
    );
    expect(result.accepted, isFalse);
  });
  test(
    'runtime uses distinct request/sale IDs and exact custom methods',
    () async {
      final rpc = _Rpc();
      final queue = _Queue();
      final port = _runtimePort(rpc, queue);
      final request = ApprovalRequest(
        commandId: 'cmd-1',
        approvalRequestRemoteId: 91,
        saleOrderRemoteId: 17,
        orderDisplayName: 'SO-17',
        terms: ApprovalTerms.cash,
        fsc: true,
        status: ApprovalStatus.requested,
      );
      final pending = await port.pending();
      expect(rpc.calls.single['method'], 'search_read');
      expect(pending, isEmpty); // fake response is not a list
      rpc.response = <dynamic>[
        {
          'id': 91,
          'reference': 'SO-17',
          'sale_order_id': [17, 'SO-17'],
          'approval_type': 'fsc',
          'request_status': 'pending',
        },
      ];
      final mapped = await port.pending();
      expect(mapped.single.approvalRequestRemoteId, 91);
      expect(mapped.single.saleOrderRemoteId, 17);
      rpc.response = const {
        'approval_required': true,
        'action': 'set_approved',
      };
      final commercial = await port.request(
        ApprovalRequest(
          commandId: 'cmd-2',
          saleOrderRemoteId: 17,
          orderDisplayName: 'SO-17',
          terms: ApprovalTerms.cash,
          fsc: false,
          status: ApprovalStatus.requested,
        ),
      );
      expect(commercial.accepted, isFalse);
      expect(commercial.pendingAction, 'set_approved');
      expect(rpc.calls.last['model'], 'sale.order');
      expect(rpc.calls.last['method'], 'action_pos_confirm');
      expect(rpc.calls.last['ids'], [17]);
      await port.resolve(
        request: request,
        decision: ApprovalDecision.approve,
        snapshot: snapshot(),
        offline: false,
      );
      expect(rpc.calls.last['method'], 'action_approve');
      expect(rpc.calls.last['ids'], [91]);
      await port.performAction(
        request: request,
        action: ApprovalAction.fscInvoiceAndDispatch,
        snapshot: snapshot(),
        offline: false,
      );
      expect(rpc.calls.last['method'], 'action_l10n_ec_aprobar_fsc');
      expect(rpc.calls.last['ids'], [17]);
      final rpcCountBeforeDelivery = rpc.calls.length;
      final delivery = await port.performAction(
        request: request,
        action: ApprovalAction.delivery,
        snapshot: snapshot(),
        offline: false,
      );
      expect(delivery.accepted, isFalse);
      expect(rpc.calls.length, rpcCountBeforeDelivery);
    },
  );
  testWidgets(
    'adaptive approval UI keeps request context and delegates resolution',
    (tester) async {
      final request = ApprovalRequest(
        commandId: 'a',
        orderDisplayName: 'SO-17',
        saleOrderRemoteId: 17,
        terms: ApprovalTerms.cash,
        fsc: true,
        status: ApprovalStatus.requested,
      );
      final port = FakeApprovalPort([request]);
      await tester.pumpWidget(
        MaterialApp(
          home: ApprovalsScreen(port: port, snapshot: snapshot()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pedido SO-17'), findsOneWidget);
      await tester.tap(find.text('Aprobar'));
      await tester.pump();
      expect(port.decisions, contains(ApprovalDecision.approve));
    },
  );

  testWidgets('approval cards keep room for actions at large text', (
    tester,
  ) async {
    final request = ApprovalRequest(
      commandId: 'a11y',
      orderDisplayName: 'con referencia extensa',
      saleOrderRemoteId: 17,
      terms: ApprovalTerms.cash,
      fsc: true,
      status: ApprovalStatus.requested,
    );
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: ApprovalsScreen(
            port: FakeApprovalPort([request]),
            snapshot: snapshot(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pedido con referencia extensa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('productive port rejects stale scope and missing authority', () async {
    final rpc = _Rpc();
    final queue = _Queue();
    final client = OdooClient(
      config: OdooClientConfig(
        baseUrl: 'https://erp.test',
        apiKey: 'test',
        database: 'db',
      ),
    );
    final request = ApprovalRequest(
      commandId: 'stale',
      approvalRequestRemoteId: 91,
      saleOrderRemoteId: 17,
      orderDisplayName: 'SO-17',
      terms: ApprovalTerms.cash,
      fsc: false,
      status: ApprovalStatus.requested,
    );
    final stale = SessionApprovalPort(
      runtime: SessionRuntime(),
      capabilities: snapshot(),
      offlineQueue: queue,
      rpcFactory: (_) => rpc,
      sessionContext: () => ApprovalSessionContext(
        scopeKey: 'other-scope',
        userId: 7,
        client: client,
      ),
    );
    expect(
      (await stale.resolve(
        request: request,
        decision: ApprovalDecision.approve,
        snapshot: snapshot(),
        offline: false,
      )).accepted,
      isFalse,
    );
    final noAuthority = SessionApprovalPort(
      runtime: SessionRuntime(),
      capabilities: snapshot(),
      offlineQueue: queue,
      rpcFactory: (_) => rpc,
      sessionContext: () =>
          ApprovalSessionContext(scopeKey: 'scope', userId: 7, client: client),
    );
    expect((await noAuthority.request(request)).accepted, isFalse);
  });

  test(
    'productive composition replays one offline approval after restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('orbi-approval-');
      final path = '${dir.path}/approval.sqlite';
      final firstDb = AppDatabase(NativeDatabase(File(path)));
      final appScope = AppScope(
        appId: 'theos_panel',
        installationId: 'install',
        normalizedServerUrl: 'https://erp.test',
        database: 'db',
        userId: 7,
      );
      final client = OdooClient(
        config: OdooClientConfig(
          baseUrl: 'https://erp.test',
          apiKey: 'test',
          database: 'db',
        ),
      );
      final caps = CapabilitySnapshot(
        scopeKey: appScope.scopeKey,
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026),
        permissions: const ['approver'],
        offlineOperations: const ['approve_credit'],
      );
      final request = ApprovalRequest(
        commandId: 'approval-1',
        approvalRequestRemoteId: 91,
        saleOrderRemoteId: 17,
        orderDisplayName: 'SO-17',
        terms: ApprovalTerms.credit,
        fsc: false,
        status: ApprovalStatus.requested,
      );
      final port = SessionApprovalPort(
        runtime: SessionRuntime(),
        capabilities: caps,
        offlineQueue: DriftApprovalOfflineQueue(firstDb),
        sessionContext: () => ApprovalSessionContext(
          scopeKey: appScope.scopeKey,
          userId: 7,
          client: client,
        ),
      );
      final queued = await port.resolve(
        request: request,
        decision: ApprovalDecision.approve,
        snapshot: caps,
        offline: true,
      );
      expect(queued.accepted, isTrue);
      final rejectedRequest = ApprovalRequest(
        commandId: 'approval-2',
        approvalRequestRemoteId: 92,
        saleOrderRemoteId: 18,
        orderDisplayName: 'SO-18',
        terms: ApprovalTerms.credit,
        fsc: false,
        status: ApprovalStatus.requested,
      );
      final rejected = await port.resolve(
        request: rejectedRequest,
        decision: ApprovalDecision.reject,
        snapshot: caps,
        offline: true,
      );
      expect(rejected.accepted, isTrue);
      await firstDb.close();

      final secondDb = AppDatabase(NativeDatabase(File(path)));
      final queue = OfflineQueueDataSource(secondDb);
      final actions = _Actions();
      final job = OperationsSyncJob(
        queue: queue,
        adapter: OdooOfflineOperationAdapter(
          actions: actions,
          database: secondDb,
          scope: appScope,
          queue: queue,
        ),
      );
      addTearDown(() async {
        await job.dispose();
        await secondDb.close();
        await dir.delete(recursive: true);
      });
      final result = await job.run(appScope);
      expect(result.cursorConfirmed, isTrue);
      final decisions = actions.calls
          .where((call) => call['method'] == 'action_approve')
          .toList();
      expect(decisions, hasLength(1));
      expect(decisions.single['model'], 'approval.request');
      expect(decisions.single['ids'], [91]);
      final refusals = actions.calls
          .where((call) => call['method'] == 'action_refuse')
          .toList();
      expect(refusals, hasLength(1));
      expect(refusals.single['model'], 'approval.request');
      expect(refusals.single['ids'], [92]);
    },
  );
}
