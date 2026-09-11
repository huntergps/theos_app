import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_panel/features/sales/sale_editor.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/features/approvals/approval_contracts.dart';

final class _Port implements SaleEditorPort {
  SaleDraftSnapshot? submitted;
  int calls = 0;
  @override
  Future<SaleEditorResult> submit(SaleDraftSnapshot draft) async {
    calls++;
    submitted = draft;
    return SaleEditorResult(
      accepted: true,
      approval: SaleApprovalState.approved,
    );
  }
}

final class _Approval implements ApprovalPort {
  int calls = 0;
  @override
  Future<List<ApprovalRequest>> pending() async => const [];
  @override
  Future<ApprovalResult> request(ApprovalRequest request) async =>
      const ApprovalResult(accepted: true, message: 'ok');
  @override
  Future<ApprovalResult> resolve({
    required ApprovalRequest request,
    required ApprovalDecision decision,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async => const ApprovalResult(accepted: true, message: 'ok');
  @override
  Future<ApprovalResult> performAction({
    required ApprovalRequest request,
    required ApprovalAction action,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async {
    calls++;
    return const ApprovalResult(accepted: true, message: 'ok');
  }
}

final class _TrackingStore implements SaleDraftStore {
  SaleDraftSnapshot? saved;
  @override
  Future<SaleDraftSnapshot?> load(String scopeKey) async => saved;
  @override
  Future<void> save(SaleDraftSnapshot draft) async => saved = draft;
}

final class _Catalog implements SaleCatalogPort {
  @override
  Future<List<SalePaymentTerm>> paymentTerms() async => [
    SalePaymentTerm(
      id: 99,
      label: 'Condición local',
      installments: [PaymentTermInstallment(dueDays: 45)],
    ),
  ];
}

final class _CommandStore implements SaleCommandStore {
  int calls = 0;
  String? commandId;
  EntityReference? entity;
  int? expectedVersion;
  Completer<OperationOutcome<SaleOrderState>>? gate;

  @override
  Future<OperationOutcome<SaleOrderState>> commitAndEnqueueIfAbsent({
    required String commandId,
    required EntityReference entity,
    required int expectedVersion,
    required OperationOutcome<SaleOrderState> outcome,
  }) async {
    calls++;
    this.commandId = commandId;
    this.entity = entity;
    this.expectedVersion = expectedVersion;
    return gate == null ? outcome : gate!.future;
  }
}

final class _Reconciliation implements CollectionReconciliationPort {
  @override
  Future<OperationOutcome<SaleOrderState>?> findByCommandOrReference({
    required String commandId,
    required EntityReference order,
    int? expectedAmountMinor,
  }) async => null;
}

final class _Collection implements SaleCollectionPort {
  @override
  Future<OperationOutcome<SaleOrderState>> collect({
    required String commandId,
    required EntityReference order,
    required int expectedVersion,
  }) async => throw UnimplementedError();
}

final class _Shifts implements SaleShiftStore {
  @override
  Future<OperationOutcome<SaleShiftState>> apply({
    required String commandId,
    required EntityReference shift,
    required int expectedVersion,
    required SaleShiftState state,
  }) async => throw UnimplementedError();
}

CapabilitySnapshot _capabilities(String scopeKey) => CapabilitySnapshot(
  scopeKey: scopeKey,
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026),
);

RuntimeSaleCommandPort _runtimeCommands(_CommandStore store) =>
    RuntimeSaleCommandPort(
      SaleOperationOrchestrator(
        commands: store,
        reconciliation: _Reconciliation(),
        collection: _Collection(),
        shifts: _Shifts(),
      ),
    );

SaleDraftSnapshot _configuredDraft({String scopeKey = 'scope-a'}) =>
    SaleDraftSnapshot(
      scopeKey: scopeKey,
      commandId: 'sale-command-1',
      orderLocalId: 'draft-local-1',
      orderRemoteId: 17,
      expectedVersion: 4,
      approval: SaleApprovalState.approved,
    );

void main() {
  test(
    'unresolved amounts block submit and approval but remain editable',
    () async {
      final port = _Port();
      final approval = _Approval();
      final store = _TrackingStore();
      final controller = SaleDraftController(
        port: port,
        approvalPort: approval,
        capabilities: _capabilities('scope-a'),
        store: store,
        scopeKey: 'scope-a',
      );
      addTearDown(controller.dispose);
      controller.update(
        lines: const [SaleDraftLine(uuid: 'l', name: 'P', quantity: 1)],
      );
      final submit = await controller.submit();
      expect(submit.accepted, isFalse);
      expect(submit.message, contains('Importes pendientes'));
      final approvalResult = await controller.requestApproval();
      expect(approvalResult.accepted, isFalse);
      expect(port.calls, 0);
      expect(approval.calls, 0);
      await controller.flush();
      expect(store.saved!.lines.single.amountsCalculated, isFalse);
      controller.update(
        lines: const [
          SaleDraftLine(
            uuid: 'l',
            name: 'P',
            quantity: 2,
            amountsCalculated: false,
          ),
        ],
      );
      expect(controller.draft.lines.single.amountsCalculated, isFalse);
    },
  );

  test('pricing context and line edits invalidate calculated provenance', () {
    final controller = SaleDraftController(
      port: _Port(),
      store: MemorySaleDraftStore(),
      initial: SaleDraftSnapshot(
        clientName: 'Cliente original',
        lines: const [
          SaleDraftLine(
            uuid: 'line',
            name: 'Producto',
            quantity: 2,
            unitPrice: 10,
            total: 20,
            amountsCalculated: true,
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);

    controller.update(clientName: 'Cliente nuevo');

    expect(controller.draft.lines.single.amountsCalculated, isFalse);
    expect(controller.draft.lines.single.unitPrice, 10);
    expect(controller.draft.lines.single.total, 20);

    controller.update(
      lines: const [
        SaleDraftLine(
          uuid: 'line',
          name: 'Producto',
          quantity: 3,
          unitPrice: 10,
          total: 30,
          amountsCalculated: true,
        ),
      ],
    );

    expect(controller.draft.lines.single.amountsCalculated, isFalse);
    expect(controller.draft.lines.single.quantity, 3);
    expect(controller.draft.lines.single.total, 30);
  });

  testWidgets('same draft and command survive counter/consultive resize', (
    tester,
  ) async {
    final port = _Port();
    final controller = SaleDraftController(
      port: port,
      store: MemorySaleDraftStore(),
      initial: SaleDraftSnapshot(
        clientName: 'Cliente Sebastián',
        lines: const [
          SaleDraftLine(
            uuid: 'line-1',
            name: 'Producto',
            quantity: 2,
            amountsCalculated: true,
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 599,
          height: 700,
          child: SaleEditorScreen(
            controller: controller,
            presentation: SalePresentation.counter,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 700,
          child: SaleEditorScreen(
            controller: controller,
            presentation: SalePresentation.consultive,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Cliente Sebastián'), findsWidgets);
    expect(find.text('Producto'), findsWidgets);
    final result = await controller.submit();
    expect(result.accepted, isTrue);
    expect(port.submitted?.lines.single.uuid, 'line-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sale editor reflows at large text on a phone', (tester) async {
    final controller = SaleDraftController(
      port: _Port(),
      store: MemorySaleDraftStore(),
    );
    addTearDown(controller.dispose);
    controller.update(
      clientName: 'Cliente con nombre largo',
      lines: const [
        SaleDraftLine(
          uuid: 'line-a11y',
          name: 'Producto con descripción larga',
          quantity: 2,
          unitPrice: 12.5,
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: MaterialApp(home: SaleEditorScreen(controller: controller)),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sale editor wide columns scroll at large text', (tester) async {
    final controller = SaleDraftController(
      port: _Port(),
      store: MemorySaleDraftStore(),
    );
    addTearDown(controller.dispose);
    controller.update(
      clientName: 'Cliente con nombre largo',
      lines: const [
        SaleDraftLine(
          uuid: 'line-wide-a11y',
          name: 'Producto con descripción larga',
          quantity: 2,
          unitPrice: 12.5,
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1200, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(1200, 600),
          textScaler: TextScaler.linear(2),
        ),
        child: MaterialApp(home: SaleEditorScreen(controller: controller)),
      ),
    );
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));
    expect(find.byType(SfDataGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sale editor keeps context, lines and actions across four viewports',
    (tester) async {
      const sizes = [
        Size(390, 844),
        Size(820, 1180),
        Size(1180, 820),
        Size(1440, 900),
      ];
      for (final size in sizes) {
        final controller = SaleDraftController(
          port: _Port(),
          store: MemorySaleDraftStore(),
        );
        controller.update(
          clientName: 'Cliente de prueba',
          lines: const [
            SaleDraftLine(uuid: 'viewport-line', name: 'Producto', quantity: 1),
          ],
        );
        addTearDown(controller.dispose);
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: SaleEditorScreen(controller: controller),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Cliente'), findsOneWidget);
        expect(find.text('Productos'), findsOneWidget);
        final wide = size.width >= 840 && size.width >= size.height;
        expect(find.byType(SfDataGrid), wide ? findsOneWidget : findsNothing);
        await tester.ensureVisible(find.text('Continuar'));
        expect(find.text('Continuar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  test('dirty draft is not replaced by a refresh of the screen', () {
    final controller = SaleDraftController(
      port: _Port(),
      store: MemorySaleDraftStore(),
    );
    addTearDown(controller.dispose);
    controller.update(note: 'Borrador local');
    expect(controller.draft.note, 'Borrador local');
  });

  test(
    'payment terms classify all F05 variants and survive restart by scope',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesSaleDraftStore(
        await SharedPreferences.getInstance(),
      );
      final first = SaleDraftController(
        port: _Port(),
        store: store,
        scopeKey: 'scope-a',
      );
      first.update(installments: [PaymentTermInstallment(dueDays: 0)]);
      expect(first.draft.classification, SaleTermsClassification.cash);
      first.update(installments: [PaymentTermInstallment(dueDays: 30)]);
      expect(first.draft.classification, SaleTermsClassification.credit);
      first.update(
        installments: [
          PaymentTermInstallment(dueDays: 0),
          PaymentTermInstallment(dueDays: 15),
        ],
      );
      expect(first.draft.classification, SaleTermsClassification.mixed);
      first.update(
        installments: [
          PaymentTermInstallment(dueDays: 0),
          PaymentTermInstallment(dueDays: 30),
        ],
      );
      expect(first.draft.classification, SaleTermsClassification.mixed);
      // Reopening must wait for the explicit durable boundary, not assume
      // async writes finish after an arbitrary number of microtasks.
      await first.flush();
      final restarted = SaleDraftController(
        port: _Port(),
        store: store,
        scopeKey: 'scope-a',
      );
      await restarted.restore();
      expect(restarted.draft.classification, SaleTermsClassification.mixed);
      await first.dispose();
      await restarted.dispose();
    },
  );

  test('approval blocks confirmation and duplicate submit is idempotent at UI boundary', () async {
    final port = _Port();
    final controller = SaleDraftController(
      port: port,
      store: MemorySaleDraftStore(),
    );
    final first = controller.submit();
    final second = await controller.submit();
    await first;
    expect(second.accepted, isFalse);
    expect(port.calls, 1);
    await controller.dispose();
    final local = SaleDraftController(
      port: LocalSaleEditorPort(),
      store: MemorySaleDraftStore(),
    );
    final result = await local.submit();
    expect(result.accepted, isFalse);
    expect(result.pendingAction, isTrue);
    await local.dispose();
  });

  test('runtime port queues with the draft reference/version and stable command id', () async {
    final store = _CommandStore();
    final port = RuntimeSaleEditorPort(
      _runtimeCommands(store),
      _capabilities('scope-a'),
    );
    final result = await port.submit(_configuredDraft());
    expect(result.accepted, isTrue);
    expect(result.pendingAction, isFalse);
    expect(store.calls, 1);
    expect(store.commandId, 'sale-command-1');
    expect(store.entity?.localId, 'draft-local-1');
    expect(store.entity?.remoteId, 17);
    expect(store.expectedVersion, 4);
  });

  test(
    'runtime port exposes approval pending and rejects a changed scope',
    () async {
      final store = _CommandStore();
      final port = RuntimeSaleEditorPort(
        _runtimeCommands(store),
        _capabilities('scope-a'),
      );
      final pending = await port.submit(
        _configuredDraft().copyWith(approval: SaleApprovalState.pending),
      );
      expect(pending.accepted, isFalse);
      expect(pending.pendingAction, isTrue);
      expect(store.calls, 0);

      final changedScope = await port.submit(
        _configuredDraft(scopeKey: 'scope-b'),
      );
      expect(changedScope.accepted, isFalse);
      expect(changedScope.pendingAction, isTrue);
      expect(store.calls, 0);
    },
  );

  test('double submit keeps one command id and one queued command', () async {
    final store = _CommandStore();
    final outcome = OperationOutcome<SaleOrderState>(
      commandId: 'sale-command-1',
      entity: EntityReference(localId: 'draft-local-1', remoteId: 17),
      businessState: SaleOrderState.sale,
      syncState: OperationSyncState.queued,
    );
    store.gate = Completer<OperationOutcome<SaleOrderState>>();
    final controller = SaleDraftController(
      port: RuntimeSaleEditorPort(
        _runtimeCommands(store),
        _capabilities('scope-a'),
      ),
      store: MemorySaleDraftStore(),
      scopeKey: 'scope-a',
      initial: _configuredDraft(),
    );
    final first = controller.submit();
    final second = await controller.submit();
    expect(second.accepted, isFalse);
    expect(second.message, 'Operación en curso');
    expect(store.calls, 1);
    expect(store.commandId, 'sale-command-1');
    store.gate!.complete(outcome);
    expect((await first).accepted, isTrue);
    await controller.dispose();
  });

  testWidgets(
    'catalog terms and operational line amounts render without hardcoded choices',
    (tester) async {
      final controller = SaleDraftController(
        port: _Port(),
        store: MemorySaleDraftStore(),
        initial: SaleDraftSnapshot(
          lines: const [
            SaleDraftLine(
              uuid: 'l',
              name: 'Producto',
              quantity: 2,
              unitPrice: 10,
              discount: 5,
              tax: 12,
              total: 21.28,
              amountsCalculated: true,
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SaleEditorScreen(controller: controller, catalog: _Catalog()),
        ),
      );
      await tester.pumpAndSettle();
      final termField = find.byType(DropdownButtonFormField<int>);
      expect(termField, findsOneWidget);
      await tester.tap(termField);
      await tester.pumpAndSettle();
      expect(find.text('Condición local'), findsOneWidget);
      await tester.tap(find.text('Condición local').last);
      await tester.pumpAndSettle();
      expect(controller.draft.paymentTermId, 99);
      expect(find.textContaining('Precio 10'), findsOneWidget);
      expect(find.textContaining('Impuesto 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
