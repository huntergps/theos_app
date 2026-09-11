import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/approvals/approval_contracts.dart';
import 'package:theos_panel/features/sales/sale_editor.dart';

final class _Store implements SaleDraftStore {
  final List<SaleDraftSnapshot> writes = [];
  Completer<void>? gate;
  Object? failure;
  Object? loadFailure;
  SaleDraftSnapshot? loaded;
  Completer<SaleDraftSnapshot?>? loadGate;

  @override
  Future<SaleDraftSnapshot?> load(String scopeKey) async {
    if (loadGate != null) return loadGate!.future;
    if (loadFailure != null) throw loadFailure!;
    return loaded;
  }

  @override
  Future<void> save(SaleDraftSnapshot draft) async {
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    writes.add(draft);
  }
}

final class _Port implements SaleEditorPort {
  int calls = 0;

  @override
  Future<SaleEditorResult> submit(SaleDraftSnapshot draft) async {
    calls++;
    return const SaleEditorResult(accepted: true);
  }
}

final class _ApprovalPort implements ApprovalPort {
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

void main() {
  test('serializes saves and writes captured snapshots in order', () async {
    final store = _Store()..gate = Completer<void>();
    final controller = SaleDraftController(port: _Port(), store: store);
    controller.update(note: 'uno');
    controller.update(note: 'dos');
    expect(store.writes, isEmpty);
    store.gate!.complete();
    await controller.flush();
    expect(store.writes.map((draft) => draft.note), ['uno', 'dos']);
    await controller.dispose();
  });

  test('save failure is observable and prevents submit service call', () async {
    final store = _Store()..failure = StateError('disk full');
    final port = _Port();
    final controller = SaleDraftController(port: port, store: store);
    controller.update(note: 'no enviar');
    final result = await controller.submit();
    expect(result.accepted, isFalse);
    expect(port.calls, 0);
    expect(controller.saveError, isA<StateError>());
    expect(controller.flush(), throwsA(isA<StateError>()));
    await controller.dispose();
  });

  test('accepted submit survives final save failure', () async {
    final store = _Store();
    final port = _Port();
    final controller = SaleDraftController(port: port, store: store);
    controller.update(note: 'preparado');
    await controller.flush();
    store.failure = StateError('final write failed');
    final result = await controller.submit();
    expect(result.accepted, isTrue);
    expect(port.calls, 1);
    expect(controller.saveError, isA<StateError>());
    await controller.dispose();
  });

  test('accepted approval survives final save failure', () async {
    final store = _Store();
    final approval = _ApprovalPort();
    final controller = SaleDraftController(
      port: _Port(),
      store: store,
      approvalPort: approval,
      capabilities: CapabilitySnapshot(
        scopeKey: 'default',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026),
      ),
    );
    controller.update(note: 'preparado');
    await controller.flush();
    store.failure = StateError('final approval write failed');
    final result = await controller.requestApproval();
    expect(result.accepted, isTrue);
    expect(approval.calls, 1);
    expect(controller.saveError, isA<StateError>());
    await controller.dispose();
  });

  test('late restore does not overwrite an edit', () async {
    final store = _Store()..loadGate = Completer<SaleDraftSnapshot?>();
    final controller = SaleDraftController(port: _Port(), store: store);
    final restoring = controller.restore();
    controller.update(note: 'edición local');
    store.loadGate!.complete(SaleDraftSnapshot(note: 'valor remoto'));
    await restoring;
    expect(controller.draft.note, 'edición local');
    await controller.dispose();
  });

  test('dispose does not cancel a save already in flight', () async {
    final store = _Store()..gate = Completer<void>();
    final controller = SaleDraftController(port: _Port(), store: store);
    controller.update(note: 'durable');
    await controller.dispose();
    store.gate!.complete();
    await controller.flush();
    expect(store.writes.single.note, 'durable');
  });

  test('saveError is observable through changes after a failed save', () async {
    final store = _Store()..failure = StateError('disk full');
    final controller = SaleDraftController(port: _Port(), store: store);
    final events = <SaleDraftSnapshot>[];
    final subscription = controller.changes.listen(events.add);
    controller.update(note: 'fallo');
    await controller.flush().catchError((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(events, isNotEmpty);
    expect(controller.saveError, isA<StateError>());
    await subscription.cancel();
    await controller.dispose();
  });

  test(
    'restore failure is reported and blocks submit without throwing',
    () async {
      final store = _Store()..loadFailure = StateError('read failed');
      final port = _Port();
      final controller = SaleDraftController(port: port, store: store);
      await controller.restore();
      expect(controller.saveError, isA<StateError>());
      final result = await controller.submit();
      expect(result.accepted, isFalse);
      expect(port.calls, 0);
      await controller.dispose();
    },
  );

  test('busy update is ignored', () async {
    final store = _Store();
    final port = _Port();
    final controller = SaleDraftController(port: port, store: store);
    controller.update(note: 'before');
    final submit = controller.submit();
    controller.update(note: 'during');
    await submit;
    expect(controller.draft.note, 'before');
    await controller.dispose();
  });

  testWidgets('save failure shows a safe local draft banner', (tester) async {
    final store = _Store()..failure = StateError('private storage detail');
    final controller = SaleDraftController(port: _Port(), store: store);
    await tester.pumpWidget(
      MaterialApp(home: SaleEditorScreen(controller: controller)),
    );
    controller.update(note: 'conservar');
    await tester.pump();
    expect(find.textContaining('Cambios aún no guardados'), findsOneWidget);
    expect(find.textContaining('private storage detail'), findsNothing);
    await controller.dispose();
  });

  testWidgets('restored note is reflected in the note field', (tester) async {
    final store = _Store()
      ..loaded = SaleDraftSnapshot(
        clientName: 'Cliente restaurado',
        note: 'Nota restaurada',
      );
    final controller = SaleDraftController(port: _Port(), store: store);
    await tester.pumpWidget(
      MaterialApp(home: SaleEditorScreen(controller: controller)),
    );
    await tester.pump();
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, 'Nota restaurada');
    expect(find.text('Cliente restaurado'), findsWidgets);
    await controller.dispose();
  });

  testWidgets('typed client updates the draft and persists it', (tester) async {
    final store = _Store();
    final controller = SaleDraftController(port: _Port(), store: store);
    await tester.pumpWidget(
      MaterialApp(home: SaleEditorScreen(controller: controller)),
    );
    final client = find.byType(TextField).first;
    await tester.enterText(client, 'Cliente digitado');
    await controller.flush();
    expect(controller.draft.clientName, 'Cliente digitado');
    expect(store.writes.last.clientName, 'Cliente digitado');
    await controller.dispose();
  });

  testWidgets('replacing controller detaches the old snapshot listener', (
    tester,
  ) async {
    final oldStore = _Store();
    final oldController = SaleDraftController(
      port: _Port(),
      store: oldStore,
      initial: SaleDraftSnapshot(clientName: 'Viejo', note: 'Nota vieja'),
    );
    final newController = SaleDraftController(
      port: _Port(),
      store: _Store(),
      initial: SaleDraftSnapshot(clientName: 'Nuevo', note: 'Nota nueva'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SaleEditorScreen(
          key: const ValueKey('editor'),
          controller: oldController,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SaleEditorScreen(
          key: const ValueKey('editor'),
          controller: newController,
        ),
      ),
    );
    oldController.update(clientName: 'Viejo actualizado', note: 'No copiar');
    await tester.pump();
    expect(newController.draft.clientName, 'Nuevo');
    expect(find.text('Viejo actualizado'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'Nota nueva',
    );
    await oldController.dispose();
    await newController.dispose();
  });
}
