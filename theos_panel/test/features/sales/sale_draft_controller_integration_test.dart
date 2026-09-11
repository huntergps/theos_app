import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import 'package:theos_panel/features/sales/sale_editor.dart';
import 'package:theos_panel/features/approvals/approval_contracts.dart';

class _Resolver implements SaleLocalOrderResolver {
  const _Resolver(this.db);
  final AppDatabase db;
  @override
  Future<SaleLocalOrderResolution> resolve(EntityReference reference) async {
    final row = await db.select(db.saleOrder).getSingle();
    return SaleLocalOrderResolution(localId: row.id, version: 0);
  }
}

class _NoReconciliation implements CollectionReconciliationPort {
  @override
  Future<OperationOutcome<SaleOrderState>?> findByCommandOrReference({
    required String commandId,
    required EntityReference order,
    int? expectedAmountMinor,
  }) async => null;
}

class _NoCollection implements SaleCollectionPort {
  @override
  Future<OperationOutcome<SaleOrderState>> collect({
    required String commandId,
    required EntityReference order,
    required int expectedVersion,
  }) async => throw StateError('not used');
}

class _NoShift implements SaleShiftStore {
  @override
  Future<OperationOutcome<SaleShiftState>> apply({
    required String commandId,
    required EntityReference shift,
    required int expectedVersion,
    required SaleShiftState state,
  }) async => throw StateError('not used');
}

Future<(AppDatabase, File)> _database() async {
  final file = File(
    '${Directory.systemTemp.path}/sale-controller-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return (AppDatabase(NativeDatabase(file)), file);
}

class _ApprovalRequestPort implements ApprovalPort {
  @override
  Future<List<ApprovalRequest>> pending() async => const [];
  @override
  Future<ApprovalResult> request(ApprovalRequest request) async =>
      const ApprovalResult(accepted: true, message: 'Solicitud registrada');
  @override
  Future<ApprovalResult> resolve({
    required ApprovalRequest request,
    required ApprovalDecision decision,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async => const ApprovalResult(accepted: true, message: 'Resuelta');
  @override
  Future<ApprovalResult> performAction({
    required ApprovalRequest request,
    required ApprovalAction action,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async =>
      const ApprovalResult(accepted: true, message: 'Solicitud registrada');
}

SaleDraftSnapshot _draft(SaleApprovalState approval) => SaleDraftSnapshot(
  scopeKey: 'scope-a',
  commandId: 'controller-${approval.name}',
  orderLocalId: 'local-order',
  partnerId: 77,
  approval: approval,
  lines: const [
    SaleDraftLine(
      uuid: 'line-a',
      name: 'Producto',
      quantity: 2,
      unitPrice: 3.5,
      amountsCalculated: true,
      remoteId: 9,
      uomId: 1,
      taxIds: [5],
    ),
  ],
);

void main() {
  test('submit approved persists and confirms through runtime ports', () async {
    final (db, file) = await _database();
    final repository = DriftSaleDraftRepository(db);
    final commandStore = DriftSaleCommandStore(db, _Resolver(db));
    final orchestrator = SaleOperationOrchestrator(
      commands: commandStore,
      reconciliation: _NoReconciliation(),
      collection: _NoCollection(),
      shifts: _NoShift(),
    );
    final controller = SaleDraftController(
      port: RuntimeSaleEditorPort(
        RuntimeSaleCommandPort(orchestrator),
        CapabilitySnapshot(
          scopeKey: 'scope-a',
          companyId: 1,
          revision: 1,
          fetchedAt: DateTime.utc(2026),
        ),
      ),
      store: MemorySaleDraftStore(),
      repository: repository,
      initial: _draft(SaleApprovalState.approved),
    );
    final result = await controller.submit();
    expect(result.accepted, isTrue);
    final queue = await db.select(db.offlineQueue).get();
    expect(
      queue.map((row) => row.method),
      containsAll(<String?>['create', 'action_pos_confirm']),
    );
    expect(
      queue.singleWhere((row) => row.method == 'action_pos_confirm').values,
      contains('dependsOn'),
    );
    await controller.dispose();
    await db.close();
    final reopened = AppDatabase(NativeDatabase(file));
    expect(await reopened.select(reopened.saleOrder).get(), hasLength(1));
    final savedOrder = await reopened.select(reopened.saleOrder).getSingle();
    final savedLine = await reopened.select(reopened.saleOrderLine).getSingle();
    expect(savedOrder.partnerId, 77);
    expect(savedLine.productId, 9);
    expect(savedLine.productUomId, 1);
    expect(savedLine.priceUnit, 3.5);
    expect(savedLine.taxIds, '[5]');
    await reopened.close();
    await file.delete();
  });

  test(
    'submit pending persists draft but does not enqueue confirmation',
    () async {
      final (db, file) = await _database();
      addTearDown(() async {
        await db.close();
        if (file.existsSync()) await file.delete();
      });
      final orchestrator = SaleOperationOrchestrator(
        commands: DriftSaleCommandStore(db, _Resolver(db)),
        reconciliation: _NoReconciliation(),
        collection: _NoCollection(),
        shifts: _NoShift(),
      );
      final controller = SaleDraftController(
        port: RuntimeSaleEditorPort(
          RuntimeSaleCommandPort(orchestrator),
          CapabilitySnapshot(
            scopeKey: 'scope-a',
            companyId: 1,
            revision: 1,
            fetchedAt: DateTime.utc(2026),
          ),
        ),
        store: MemorySaleDraftStore(),
        repository: DriftSaleDraftRepository(db),
        initial: _draft(SaleApprovalState.pending),
      );
      final result = await controller.submit();
      expect(result.accepted, isFalse);
      final queue = await db.select(db.offlineQueue).get();
      expect(queue, hasLength(2));
      expect(queue.where((row) => row.method == 'action_pos_confirm'), isEmpty);
      await controller.dispose();
    },
  );

  test('submit with unresolved amounts does not persist or enqueue', () async {
    final (db, file) = await _database();
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) await file.delete();
    });
    final controller = SaleDraftController(
      port: LocalSaleEditorPort(),
      store: MemorySaleDraftStore(),
      repository: DriftSaleDraftRepository(db),
      initial: _draft(SaleApprovalState.approved).copyWith(
        lines: [
          const SaleDraftLine(
            uuid: 'unresolved-line',
            name: 'Producto pendiente',
            quantity: 1,
            unitPrice: 3.5,
            remoteId: 9,
            uomId: 1,
            taxIds: [5],
          ),
        ],
      ),
    );

    final result = await controller.submit();

    expect(result.accepted, isFalse);
    expect(result.message, contains('Importes pendientes'));
    expect(await db.select(db.saleOrder).get(), isEmpty);
    expect(await db.select(db.offlineQueue).get(), isEmpty);
    await controller.dispose();
  });

  test('required approval is requested after draft persistence', () async {
    final (db, file) = await _database();
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) await file.delete();
    });
    final controller = SaleDraftController(
      port: LocalSaleEditorPort(),
      store: MemorySaleDraftStore(),
      repository: DriftSaleDraftRepository(db),
      approvalPort: _ApprovalRequestPort(),
      capabilities: CapabilitySnapshot(
        scopeKey: 'scope-a',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026),
      ),
      offline: true,
      initial: _draft(SaleApprovalState.required),
    );
    final result = await controller.requestApproval();
    expect(result.accepted, isTrue);
    expect(controller.draft.approval, SaleApprovalState.pending);
    expect(await db.select(db.offlineQueue).get(), hasLength(2));
    await controller.dispose();
  });
}
