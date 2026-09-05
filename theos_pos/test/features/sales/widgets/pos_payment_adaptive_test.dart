import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/adaptive/adaptive_layout_policy.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/add_payment_dialog.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/pos_payment_tab.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/quick_amount_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('390px reflows metrics, fields, and actions without overflow', (
    tester,
  ) async {
    var leadingTaps = 0;
    var trailingTaps = 0;

    await _pumpAtSize(
      tester,
      const Size(390, 844),
      Column(
        children: [
          AdaptivePaymentMetrics(
            inputCapabilities: _touchInputs,
            items: const [
              _Metric('metric-1'),
              _Metric('metric-2'),
              _Metric('metric-3'),
              _Metric('metric-4'),
            ],
          ),
          const SizedBox(height: 12),
          const AdaptivePaymentFieldPair(
            inputCapabilities: _touchInputs,
            first: Text('first-field'),
            second: Text('second-field'),
          ),
          const SizedBox(height: 12),
          AdaptivePaymentActionRow(
            inputCapabilities: _touchInputs,
            stretchInCompact: true,
            leading: Button(
              onPressed: () => leadingTaps++,
              child: const Text('leading-action'),
            ),
            trailing: FilledButton(
              onPressed: () => trailingTaps++,
              child: const Text('trailing-action'),
            ),
          ),
        ],
      ),
    );

    expect(find.byKey(AdaptivePaymentMetrics.compactKey), findsOneWidget);
    expect(find.byKey(AdaptivePaymentFieldPair.stackedKey), findsOneWidget);
    expect(find.byKey(AdaptivePaymentActionRow.compactKey), findsOneWidget);

    final firstTop = tester.getTopLeft(find.text('metric-1'));
    final secondTop = tester.getTopLeft(find.text('metric-2'));
    final thirdTop = tester.getTopLeft(find.text('metric-3'));
    expect(firstTop.dy, secondTop.dy);
    expect(thirdTop.dy, greaterThan(firstTop.dy));

    await tester.tap(find.text('leading-action'));
    await tester.tap(find.text('trailing-action'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(leadingTaps, 1);
    expect(trailingTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact dialog is full-screen and keeps 48px touch targets', (
    tester,
  ) async {
    var taps = 0;

    await _pumpAtSize(
      tester,
      const Size(390, 844),
      AdaptivePaymentDialogSurface(
        inputCapabilities: _touchInputs,
        title: const Text('Agregar pago'),
        content: const Text('Formulario'),
        actions: [
          Button(onPressed: () => taps++, child: const Text('Cancelar')),
          FilledButton(onPressed: () => taps++, child: const Text('Guardar')),
        ],
      ),
    );

    final dialog = tester.widget<ContentDialog>(
      find.byKey(AdaptivePaymentDialogSurface.fullScreenKey),
    );
    expect(dialog.constraints.minWidth, 390);
    expect(dialog.constraints.maxWidth, 390);
    expect(dialog.constraints.minHeight, 844);
    expect(dialog.constraints.maxHeight, 844);
    expect(tester.getSize(find.widgetWithText(Button, 'Cancelar')).height, 48);

    await tester.tap(find.text('Guardar'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('768px uses modal dialog and inline field pairs', (tester) async {
    await _pumpAtSize(
      tester,
      const Size(768, 1024),
      const AdaptivePaymentDialogSurface(
        inputCapabilities: _touchInputs,
        title: Text('Agregar pago'),
        content: AdaptivePaymentFieldPair(
          inputCapabilities: _touchInputs,
          first: Text('first-field'),
          second: Text('second-field'),
        ),
        actions: [Text('Cancelar'), Text('Guardar')],
      ),
    );

    final dialog = tester.widget<ContentDialog>(
      find.byKey(AdaptivePaymentDialogSurface.modalKey),
    );
    expect(dialog.constraints.maxWidth, 650);
    expect(dialog.constraints.maxHeight, 700);
    expect(find.byKey(AdaptivePaymentFieldPair.inlineKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1024px pointer quick amount uses 32px target and callback', (
    tester,
  ) async {
    var taps = 0;

    await _pumpAtSize(
      tester,
      const Size(1024, 768),
      Center(
        child: QuickAmountButton(
          label: '+\$10',
          amount: 10,
          inputCapabilities: _pointerInputs,
          onTap: () => taps++,
        ),
      ),
    );

    final size = tester.getSize(find.byType(QuickAmountButton));
    expect(size.height, greaterThanOrEqualTo(32));
    expect(size.height, lessThan(48));

    await tester.tap(find.text('+\$10'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}

const _touchInputs = AdaptiveInputCapabilities(touch: true);
const _pointerInputs = AdaptiveInputCapabilities(
  precisePointer: true,
  hardwareKeyboard: true,
);

Future<void> _pumpAtSize(WidgetTester tester, Size size, Widget child) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(FluentApp(home: child));
  await tester.pump();
}

class _Metric extends StatelessWidget {
  const _Metric(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 40, child: Center(child: Text(label)));
  }
}
