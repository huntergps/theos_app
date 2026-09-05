import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/adaptive/adaptive_layout_policy.dart';
import 'package:theos_pos/features/collection/screens/cash_count_dialog.dart';
import 'package:theos_pos/features/collection/widgets/session_validation_dialog.dart';
import 'package:theos_pos/shared/widgets/reactive/reactive_cash_count_field.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cash-count policy covers the supported window classes', () {
    final compact = CashCountLayoutPolicy.fromWidth(390);
    final medium = CashCountLayoutPolicy.fromWidth(
      768,
      inputs: const AdaptiveInputCapabilities(
        touch: true,
        precisePointer: true,
      ),
    );
    final expanded = CashCountLayoutPolicy.fromWidth(
      1024,
      inputs: const AdaptiveInputCapabilities(precisePointer: true),
    );

    expect(compact.usesFullScreenDialog, isTrue);
    expect(compact.stacksDenominationGroups, isTrue);
    expect(compact.transactionColumns, 2);
    expect(compact.minimumInteractiveExtent, 48);

    expect(medium.usesFullScreenDialog, isFalse);
    expect(medium.stacksDenominationGroups, isFalse);
    expect(medium.transactionColumns, 4);
    expect(medium.minimumInteractiveExtent, 44);

    expect(expanded.usesFullScreenDialog, isFalse);
    expect(expanded.stacksDenominationGroups, isFalse);
    expect(expanded.transactionColumns, 4);
    expect(expanded.minimumInteractiveExtent, 32);
  });

  testWidgets(
    'cash count reflows at 390x844 and preserves counts at 1024x768',
    (tester) async {
      await _pumpAtSize(
        tester,
        const Size(390, 844),
        const CashCountDialog(
          title: 'Conteo de cierre',
          sessionId: 17,
          sessionState: SessionState.closingControl,
          cashType: CashType.closing,
          initialCash: CollectionSessionCash(
            collectionSessionId: 17,
            cashType: CashType.closing,
            bills100: 2,
          ),
        ),
      );

      final compactDialog = tester.widget<ContentDialog>(
        find.byKey(CashCountDialog.compactPresentationKey),
      );
      expect(compactDialog.constraints.minWidth, 390);
      expect(compactDialog.constraints.minHeight, 844);
      expect(
        find.byKey(ReactiveCashCountField.stackedDenominationsKey),
        findsOneWidget,
      );
      expect(find.byKey(CashCountDialog.stackedActionsKey), findsOneWidget);
      expect(find.text(r'$200.00'), findsWidgets);
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'Confirmar')).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);

      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pump();

      expect(find.byKey(CashCountDialog.modalPresentationKey), findsOneWidget);
      expect(
        find.byKey(ReactiveCashCountField.splitDenominationsKey),
        findsOneWidget,
      );
      expect(find.byKey(CashCountDialog.inlineActionsKey), findsOneWidget);
      expect(find.text(r'$200.00'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cash count uses the medium modal layout at 768x1024', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      const Size(768, 1024),
      const CashCountDialog(
        title: 'Conteo de apertura',
        sessionState: SessionState.openingControl,
        cashType: CashType.opening,
        inputCapabilities: AdaptiveInputCapabilities(
          touch: true,
          precisePointer: true,
        ),
      ),
    );

    final dialog = tester.widget<ContentDialog>(
      find.byKey(CashCountDialog.modalPresentationKey),
    );
    expect(dialog.constraints.maxWidth, 720);
    expect(
      find.byKey(ReactiveCashCountField.splitDenominationsKey),
      findsOneWidget,
    );
    expect(find.byKey(CashCountDialog.inlineActionsKey), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Confirmar')).height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('validation dialog reflows without losing supervisor notes', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      const Size(390, 844),
      SessionValidationDialog(session: _session),
    );

    expect(
      find.byKey(SessionValidationDialog.compactPresentationKey),
      findsOneWidget,
    );
    expect(
      find.byKey(SessionValidationDialog.stackedInformationKey),
      findsOneWidget,
    );
    expect(
      find.byKey(SessionValidationDialog.stackedActionsKey),
      findsOneWidget,
    );
    final notesFinder = find.byType(TextBox).last;
    await tester.enterText(notesFinder, 'nota preservada');
    await tester.pump();

    await tester.binding.setSurfaceSize(const Size(768, 1024));
    await tester.pump();

    expect(
      find.byKey(SessionValidationDialog.modalPresentationKey),
      findsOneWidget,
    );
    expect(
      find.byKey(SessionValidationDialog.splitInformationKey),
      findsOneWidget,
    );
    expect(
      find.byKey(SessionValidationDialog.inlineActionsKey),
      findsOneWidget,
    );
    expect(
      tester.widget<TextBox>(find.byType(TextBox).last).controller?.text,
      'nota preservada',
    );
    expect(tester.takeException(), isNull);
  });
}

const _session = CollectionSession(
  id: 17,
  name: 'Caja principal',
  state: SessionState.closingControl,
  userName: 'Ana',
  cashRegisterBalanceStart: 100,
  cashRegisterBalanceEnd: 250,
  cashRegisterBalanceEndReal: 260,
  orderCount: 12,
  paymentCount: 8,
  advanceCount: 3,
  chequeRecibidoCount: 2,
);

Future<void> _pumpAtSize(WidgetTester tester, Size size, Widget child) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(child: FluentApp(home: child)));
  await tester.pump();
}
