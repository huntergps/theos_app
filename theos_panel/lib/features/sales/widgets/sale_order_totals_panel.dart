import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../sale_editor.dart' show SaleDraftLine;

/// Un grupo de impuesto ya agregado, listo para pintar ("Base IVA 15%" /
/// "IVA 15%"). Espejo de `TaxGroupTotal` de
/// `theos_pos_core/lib/src/services/sales/order_totals_calculator.dart`, sin
/// depender de ese tipo en la firma pública de este archivo.
final class SaleOrderTaxGroupTotal {
  const SaleOrderTaxGroupTotal({
    required this.label,
    required this.base,
    required this.amount,
  });

  final String label;
  final double base;
  final double amount;
}

/// Lo que pinta [SaleOrderTotalsPanel]. Un [SaleOrderTotalsPort] es quien lo
/// produce — la pantalla nunca sale del `build()` a calcular esto ella misma.
final class SaleOrderTotals {
  const SaleOrderTotals({
    required this.netSubtotal,
    required this.taxGroups,
    required this.total,
  });

  final double netSubtotal;
  final List<SaleOrderTaxGroupTotal> taxGroups;
  final double total;
}

/// El cálculo real de impuestos y totales vive en
/// `theos_pos_core/lib/src/services/sales/order_totals_calculator.dart` y
/// `line_calculator.dart`. Esta pantalla no suma, no multiplica ni redondea
/// nada: le pide el desglose a un puerto inyectable — así una prueba puede
/// sustituirlo por un total conocido sin que la vista recalcule nada.
abstract interface class SaleOrderTotalsPort {
  SaleOrderTotals totals(List<SaleDraftLine> lines);
}

/// Implementación por defecto: convierte cada línea calculada en un
/// `SaleOrderLine` en memoria (`SaleOrderLine.newProductLine`, el mismo
/// factory que usa theos_pos para líneas todavía no guardadas en Odoo — ver
/// `theos_pos/lib/features/sales/services/order_line_creation_service.dart`),
/// le aplica `saleOrderLineCalculator.updateLineCalculations` (el cálculo real
/// por línea) y entrega la lista a `orderTotalsCalculator.calculate` (la
/// agregación real del documento).
///
/// 🔴 Ninguno de los dos calculadores redondea por línea — a propósito: en
/// Ecuador el IVA del documento se calcula sobre la base agregada, no como
/// suma de IVA redondeado línea por línea (pueden diferir en centavos). El
/// redondeo a 2 decimales sólo ocurre una vez, al formatear para mostrar
/// (`OdooSummaryRow`). Sumar aquí `line.total`/`line.tax` ya redondeados por
/// línea sería exactamente el error que esto evita.
///
/// Las líneas con `amountsCalculated == false` (importe todavía sin validar,
/// ver `sale_editor.dart`) no aportan al total — igual que `submit()` las
/// bloquea para confirmar la venta.
final class DraftLineTotalsPort implements SaleOrderTotalsPort {
  const DraftLineTotalsPort();

  @override
  SaleOrderTotals totals(List<SaleDraftLine> lines) {
    final calculated = <SaleOrderLine>[
      for (final line in lines)
        if (line.amountsCalculated)
          saleOrderLineCalculator.updateLineCalculations(
            SaleOrderLine.newProductLine(
              orderId: 0,
              productId: line.remoteId ?? 0,
              productName: line.name,
              priceUnit: line.unitPrice,
              quantity: line.quantity,
              discount: line.discount,
              uomId: line.uomId,
              uomName: line.uomName,
              taxIds: line.taxIds.isEmpty ? null : line.taxIds.join(','),
              // Sólo etiqueta el grupo ("IVA 15%"); el importe lo calcula
              // `updateLineCalculations` a partir de `taxPercent`, no de este
              // texto.
              taxNames: line.tax > 0 ? 'IVA ${_trimPercent(line.tax)}%' : null,
            ),
            taxPercent: line.tax,
          ),
    ];
    final breakdown = orderTotalsCalculator.calculate(lines: calculated);
    return SaleOrderTotals(
      netSubtotal: breakdown.subtotal,
      taxGroups: [
        for (final group in breakdown.taxGroups)
          SaleOrderTaxGroupTotal(
            label: group.name,
            base: group.base,
            amount: group.amount,
          ),
      ],
      total: breakdown.total,
    );
  }
}

String _trimPercent(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// Panel de totales (Subtotal Neto / Base IVA / IVA / Total), como el de
/// theos_pos (`theos_pos/lib/features/sales/widgets/totals/sales_order_totals.dart`).
/// Reutiliza `OdooSummaryCard`/`OdooSummaryRow` de `odoo_widgets` — el mismo
/// widget compartido que usa esa pantalla — en vez de pintar filas a mano.
class SaleOrderTotalsPanel extends StatelessWidget {
  const SaleOrderTotalsPanel({super.key, required this.totals});

  final SaleOrderTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return OdooSummaryCard(
      children: [
        OdooSummaryRow(label: 'Subtotal Neto', amount: totals.netSubtotal),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Divider(),
        ),
        for (final group in totals.taxGroups) ...[
          if (group.base > 0)
            OdooSummaryRow(
              label: 'Base ${group.label}',
              amount: group.base,
              compact: true,
            ),
          OdooSummaryRow(label: group.label, amount: group.amount),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(
            style: DividerThemeData(
              thickness: 2,
              decoration: BoxDecoration(color: theme.accentColor),
            ),
          ),
        ),
        OdooSummaryRow(
          key: const Key('sale-order-total'),
          label: 'Total',
          amount: totals.total,
          labelStyle: theme.typography.title?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          amountStyle: theme.typography.title?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.accentColor,
          ),
        ),
      ],
    );
  }
}
