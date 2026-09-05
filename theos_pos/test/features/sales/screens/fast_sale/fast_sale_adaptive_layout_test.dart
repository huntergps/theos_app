import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/adaptive/adaptive_layout_policy.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/fast_sale_screen.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/product_favorites_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FastSaleAdaptiveLayout', () {
    testWidgets('uses compact one-column composition at 390x844', (
      tester,
    ) async {
      await _pumpLayout(tester, size: const Size(390, 844), inputs: _touchOnly);

      expect(find.byKey(FastSaleAdaptiveLayout.compactKey), findsOneWidget);
      expect(find.text('order-lines'), findsOneWidget);
      expect(find.text('compact-customer'), findsOneWidget);
      expect(find.text('compact-actions'), findsOneWidget);
      expect(find.text('customer-keypad'), findsNothing);
      expect(
        find.byKey(FastSaleAdaptiveLayout.touchActionsKey),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses medium two-column composition at 768x1024', (
      tester,
    ) async {
      await _pumpLayout(
        tester,
        size: const Size(768, 1024),
        inputs: _touchOnly,
      );

      expect(find.byKey(FastSaleAdaptiveLayout.mediumKey), findsOneWidget);
      expect(find.text('order-lines'), findsOneWidget);
      expect(find.text('customer-keypad'), findsOneWidget);
      expect(find.text('horizontal-actions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses expanded three-column composition at 1024x768', (
      tester,
    ) async {
      await _pumpLayout(
        tester,
        size: const Size(1024, 768),
        inputs: _touchOnly,
      );

      expect(find.byKey(FastSaleAdaptiveLayout.expandedKey), findsOneWidget);
      expect(find.text('order-lines'), findsOneWidget);
      expect(find.text('customer-keypad'), findsOneWidget);
      expect(find.text('actions'), findsOneWidget);
      expect(find.byKey(FastSaleAdaptiveLayout.touchActionsKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'supports touch and keyboard together without hiding touch UI',
      (tester) async {
        await _pumpLayout(
          tester,
          size: const Size(768, 1024),
          inputs: const AdaptiveInputCapabilities(
            touch: true,
            hardwareKeyboard: true,
          ),
        );

        expect(find.byKey(FastSaleAdaptiveLayout.mediumKey), findsOneWidget);
        expect(
          find.byKey(FastSaleAdaptiveLayout.touchActionsKey),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('uses pointer layout at 1440x900 without touch overlay', (
      tester,
    ) async {
      await _pumpLayout(
        tester,
        size: const Size(1440, 900),
        inputs: const AdaptiveInputCapabilities(
          precisePointer: true,
          hardwareKeyboard: true,
        ),
      );

      expect(find.byKey(FastSaleAdaptiveLayout.expandedKey), findsOneWidget);
      expect(find.byKey(FastSaleAdaptiveLayout.touchActionsKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses parent constraints instead of the full app window', (
      tester,
    ) async {
      await _pumpLayout(
        tester,
        size: const Size(1440, 900),
        availableSize: const Size(390, 700),
        inputs: _touchOnly,
      );

      expect(find.byKey(FastSaleAdaptiveLayout.compactKey), findsOneWidget);
      expect(find.byKey(FastSaleAdaptiveLayout.expandedKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('preserves child state while resizing medium to expanded', (
      tester,
    ) async {
      final counterKey = GlobalKey<_CounterPanelState>();

      await _pumpLayout(
        tester,
        size: const Size(768, 1024),
        inputs: _touchOnly,
        orderLinesPanel: _CounterPanel(key: counterKey),
      );
      await tester.tap(find.text('increment'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('count: 1'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pump();

      expect(find.byKey(FastSaleAdaptiveLayout.expandedKey), findsOneWidget);
      expect(find.text('count: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('favorite product columns use the grid local width', () {
    expect(favoriteProductColumnCount(300), 1);
    expect(favoriteProductColumnCount(500), 2);
    expect(favoriteProductColumnCount(700), 3);
    expect(favoriteProductColumnCount(900), 4);
  });
}

const _touchOnly = AdaptiveInputCapabilities(touch: true);

Future<void> _pumpLayout(
  WidgetTester tester, {
  required Size size,
  required AdaptiveInputCapabilities inputs,
  Size? availableSize,
  Widget orderLinesPanel = const _Panel('order-lines'),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    FluentApp(
      home: Center(
        child: SizedBox(
          width: availableSize?.width,
          height: availableSize?.height,
          child: FastSaleAdaptiveLayout(
            inputCapabilities: inputs,
            showActions: true,
            orderLinesPanel: orderLinesPanel,
            customerKeypadPanel: const _Panel('customer-keypad'),
            compactCustomerPanel: const _Panel('compact-customer'),
            actionsPanel: const _Panel('actions'),
            horizontalActionsPanel: const _Panel('horizontal-actions'),
            compactActionsPanel: const _Panel('compact-actions'),
            touchActions: const Positioned(
              right: 0,
              bottom: 0,
              child: Text('touch-actions'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _Panel extends StatelessWidget {
  const _Panel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}

class _CounterPanel extends StatefulWidget {
  const _CounterPanel({super.key});

  @override
  State<_CounterPanel> createState() => _CounterPanelState();
}

class _CounterPanelState extends State<_CounterPanel> {
  var _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('count: $_count'),
        Button(
          onPressed: () => setState(() => _count++),
          child: const Text('increment'),
        ),
      ],
    );
  }
}
