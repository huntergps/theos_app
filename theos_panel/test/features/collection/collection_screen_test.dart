import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/collection/collection_contracts.dart';
import 'package:theos_panel/features/collection/collection_screen.dart';

class _Actions implements CollectionActions {
  int calls = 0;
  CollectionResultState result;
  _Actions(this.result);
  @override
  Future<CollectionShiftSnapshot> open(CollectionShiftSnapshot s) async => s;
  @override
  Future<CollectionShiftSnapshot> close(CollectionShiftSnapshot s) async => s;
  @override
  Future<CollectionResultState> collect(
    CollectionPendingSale s,
    List<CollectionPaymentDraft> p,
  ) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return result;
  }
}

void main() {
  testWidgets('shows remaining amount and does not count conflict', (
    tester,
  ) async {
    final actions = _Actions(CollectionResultState.ambiguous);
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionScreen(
          shift: const CollectionShiftSnapshot(
            id: '1',
            state: CollectionShiftState.opened,
            expectedVersion: 1,
          ),
          pending: const [
            CollectionPendingSale(
              id: 'sale',
              label: 'Venta',
              amountMinor: 1000,
              remoteId: 4,
              commandId: 'c',
            ),
          ],
          capabilities: const CollectionCapabilitySnapshot(),
          actions: actions,
          journals: const [CollectionJournalOption(id: 1, name: 'Caja')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Venta'));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Caja').last);
    await tester.enterText(find.byType(TextField).first, '5');
    await tester.tap(find.text('Añadir medio'));
    await tester.pump();
    await tester.tap(find.text('Cobrar'));
    await tester.tap(find.text('Cobrar'));
    await tester.pumpAndSettle();
    expect(actions.calls, 1);
    expect(find.textContaining('no confirmado'), findsOneWidget);
  });

  testWidgets('compact collection scrolls at large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: CollectionScreen(
            shift: const CollectionShiftSnapshot(
              id: '1',
              state: CollectionShiftState.opened,
              expectedVersion: 1,
            ),
            pending: const [
              CollectionPendingSale(
                id: 'sale',
                label: 'Venta larga para accesibilidad',
                amountMinor: 1000,
                remoteId: 4,
                commandId: 'c',
              ),
            ],
            capabilities: const CollectionCapabilitySnapshot(),
            actions: _Actions(CollectionResultState.queued),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Caja y cobros'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('financial online action is single-flight and reports result', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionScreen(
          shift: const CollectionShiftSnapshot(
            id: '1',
            state: CollectionShiftState.opened,
            expectedVersion: 1,
          ),
          pending: const [],
          capabilities: const CollectionCapabilitySnapshot(),
          actions: _Actions(CollectionResultState.queued),
          financialActions: [
            CollectionFinancialAction(
              capability: CollectionCapability.deposits,
              label: 'Registrar depósito',
              run: () async {
                calls++;
                await Future<void>.delayed(const Duration(milliseconds: 10));
                return CollectionResultState.synced;
              },
            ),
          ],
        ),
      ),
    );
    await tester.ensureVisible(find.text('Registrar depósito'));
    await tester.tap(find.text('Registrar depósito'));
    await tester.ensureVisible(find.text('Registrar depósito'));
    await tester.tap(find.text('Registrar depósito'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Resultado: synced'), findsOneWidget);
  });

  testWidgets('mixed amount requires explicit due confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionScreen(
          shift: const CollectionShiftSnapshot(
            id: '1',
            state: CollectionShiftState.opened,
            expectedVersion: 1,
          ),
          pending: const [
            CollectionPendingSale(
              id: 'mixed',
              label: 'ORBI-E2E-MIXED',
              amountMinor: 5000,
              calculatedDueMinor: 2500,
              requiresDueConfirmation: true,
            ),
          ],
          capabilities: const CollectionCapabilitySnapshot(),
          actions: _Actions(CollectionResultState.queued),
          journals: const [CollectionJournalOption(id: 1, name: 'Caja')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ORBI-E2E-MIXED'));
    await tester.pump();
    expect(find.byKey(const Key('mixed-due-confirmation')), findsOneWidget);
    expect(find.text('Exigible calculado: 25.00'), findsOneWidget);
    final before = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Cobrar'),
    );
    expect(before.onPressed, isNull);
    await tester.ensureVisible(find.text('Confirmar monto mixto exigible'));
    await tester.tap(find.text('Confirmar monto mixto exigible'));
    await tester.pump();
    final after = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Cobrar'),
    );
    expect(after.onPressed, isNotNull);
  });
}
