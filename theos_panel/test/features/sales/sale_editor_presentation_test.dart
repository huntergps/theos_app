// Pruebas del encargo "la pantalla de una venta a la altura de theos_pos"
// (sólo presentación): términos sin HTML crudo, el total viene del puerto
// inyectado (no se recalcula en la vista), la cadena de estados resalta el
// paso actual, y no hay desbordamiento a 400/800/1280px.
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/sales/sale_editor.dart';
import 'package:theos_panel/features/sales/widgets/sale_order_status_chain.dart';
import 'package:theos_panel/features/sales/widgets/sale_order_totals_panel.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show SaleApprovalState, SaleOrderState;

final class _Port implements SaleEditorPort {
  @override
  Future<SaleEditorResult> submit(SaleDraftSnapshot draft) async =>
      const SaleEditorResult(accepted: true);
}

/// Como confirmaría el runtime real: la venta queda aprobada y su estado de
/// negocio pasa a "sale" (Orden de venta).
final class _ConfirmingPort implements SaleEditorPort {
  @override
  Future<SaleEditorResult> submit(SaleDraftSnapshot draft) async =>
      const SaleEditorResult(
        accepted: true,
        approval: SaleApprovalState.approved,
        businessState: SaleOrderState.sale,
      );
}

final class _FixedTotalsPort implements SaleOrderTotalsPort {
  const _FixedTotalsPort(this.value);
  final double value;

  @override
  SaleOrderTotals totals(List<SaleDraftLine> lines) => SaleOrderTotals(
    netSubtotal: value,
    taxGroups: const [],
    total: value,
  );
}

void main() {
  testWidgets('terms and conditions render clean of raw HTML tags', (
    tester,
  ) async {
    final controller = SaleDraftController(
      port: _Port(),
      store: MemorySaleDraftStore(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      FluentApp(
        home: SaleEditorScreen(
          controller: controller,
          termsAndConditionsHtml: '<p>Hola</p>',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola'), findsOneWidget);
    expect(find.textContaining('<p>'), findsNothing);
    expect(find.textContaining('</p>'), findsNothing);
  });

  testWidgets(
    'the displayed total is exactly what the injected totals port returns',
    (tester) async {
      final controller = SaleDraftController(
        port: _Port(),
        store: MemorySaleDraftStore(),
      );
      addTearDown(controller.dispose);
      // Una línea real cuyo total naif (precio * cantidad) es 20 — bien
      // distinto del total fijo (777) que el doble va a devolver. Si la
      // pantalla recalculara en el build en vez de usar el puerto, se vería
      // "20", no "777".
      controller.update(
        lines: const [
          SaleDraftLine(
            uuid: 'l1',
            name: 'Producto',
            quantity: 2,
            unitPrice: 10,
            total: 20,
            amountsCalculated: true,
          ),
        ],
      );
      // Suficientemente alto para que el panel de totales, al final de la
      // columna angosta, no quede fuera del área visible del `ListView` (si
      // no se monta, `find` no lo ve).
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        FluentApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 2400)),
            child: SaleEditorScreen(
              controller: controller,
              totalsPort: const _FixedTotalsPort(777),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final totalTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('sale-order-total')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .join(' ');
      expect(totalTexts, contains('777'));
      expect(totalTexts, isNot(contains('20')));
    },
  );

  test(
    'default totals port matches document-level rounding, not the sum of '
    'per-line rounded IVA',
    () {
      // 3 líneas de 1 × 0,335 con IVA 15%: cada línea, redondeada por sí
      // sola, da IVA 0,05 (total 0,39); sumadas así el documento saldría en
      // 1,17. El IVA correcto por documento se calcula sobre la base
      // agregada (1,005 × 15% = 0,15075) y sólo se redondea una vez, al
      // final: 1,16. `line.total`/`line.tax` de abajo llevan A PROPÓSITO el
      // total ya redondeado por línea (0,39): si el puerto lo sumara tal
      // cual (como hacía antes) daría 1,17 en vez de 1,16.
      const port = DraftLineTotalsPort();
      final lines = List.generate(
        3,
        (i) => SaleDraftLine(
          uuid: 'line-$i',
          name: 'Producto',
          quantity: 1,
          unitPrice: 0.335,
          tax: 15,
          total: 0.39,
          amountsCalculated: true,
        ),
      );

      final totals = port.totals(lines);

      expect(totals.total, closeTo(1.15575, 0.0005));
      expect(totals.total, isNot(closeTo(1.17, 0.0005)));
      expect(totals.taxGroups.single.amount, closeTo(0.15075, 0.0005));
      expect(totals.taxGroups.single.amount, isNot(closeTo(0.15, 0.0005)));
    },
  );

  testWidgets(
    'the sale editor shows the document-level total, not the sum of '
    'per-line rounded IVA',
    (tester) async {
      // `initial:`, no `controller.update(lines: ...)`: cambiar la lista de
      // líneas por `update()` invalida a propósito `amountsCalculated` (ver
      // `_withUncalculatedAmounts` en `sale_editor.dart`) hasta que un
      // cálculo confiable la reponga — aquí ya se quiere partir de líneas
      // calculadas.
      final controller = SaleDraftController(
        port: _Port(),
        store: MemorySaleDraftStore(),
        initial: SaleDraftSnapshot(
          lines: List.generate(
            3,
            (i) => SaleDraftLine(
              uuid: 'line-$i',
              name: 'Producto',
              quantity: 1,
              unitPrice: 0.335,
              tax: 15,
              total: 0.39,
              amountsCalculated: true,
            ),
          ),
        ),
      );
      addTearDown(controller.dispose);
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        FluentApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 2400)),
            child: SaleEditorScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final totalTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('sale-order-total')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .join(' ');
      expect(totalTexts, contains('16'));
      expect(totalTexts, isNot(contains('17')));
    },
  );

  testWidgets('the status chain highlights the quotation step on a new draft', (
    tester,
  ) async {
    final controller = SaleDraftController(
      port: _Port(),
      store: MemorySaleDraftStore(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      FluentApp(home: SaleEditorScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    final active = tester.widget<Text>(
      find.byKey(const Key('sale-status-active')),
    );
    expect(active.data, 'Cotización');
  });

  testWidgets(
    'the status chain highlights the sale order step once confirmed',
    (tester) async {
      final controller = SaleDraftController(
        port: _ConfirmingPort(),
        store: MemorySaleDraftStore(),
        initial: SaleDraftSnapshot(approval: SaleApprovalState.approved),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        FluentApp(home: SaleEditorScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('sale-status-active'))).data,
        'Aprobado',
      );

      final result = await controller.submit();
      expect(result.accepted, isTrue);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('sale-status-active'))).data,
        'Orden de venta',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('SaleOrderStatusChain highlights each of its states in isolation', (
    tester,
  ) async {
    // `Align` en vez de dejar que `SaleOrderStatusChain` sea la raíz de la
    // página: en la pantalla real vive dentro de una `Column`, que le da alto
    // suelto — como raíz de `FluentApp.home` recibe alto fijo (el del
    // viewport) y el `BreadcrumbBar` no está pensado para estirarse así.
    await tester.pumpWidget(
      const FluentApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SaleOrderStatusChain(state: SaleOrderState.sale),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('sale-status-active'))).data,
      'Orden de venta',
    );
  });

  testWidgets(
    'sale editor has no layout overflow at 400, 800 and 1280 px wide',
    (tester) async {
      const widths = [400.0, 800.0, 1280.0];
      for (final width in widths) {
        final size = Size(width, 900);
        final controller = SaleDraftController(
          port: _Port(),
          store: MemorySaleDraftStore(),
        );
        controller.update(
          clientName: 'Cliente de prueba',
          lines: const [
            SaleDraftLine(uuid: 'l', name: 'Producto', quantity: 1),
          ],
        );
        addTearDown(controller.dispose);
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          FluentApp(
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: SaleEditorScreen(
                controller: controller,
                termsAndConditionsHtml: '<p>Términos</p>',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}
