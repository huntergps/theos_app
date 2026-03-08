import '../../models/sales/sale_order_line.model.dart';
import '../taxes/tax_calculator_service.dart';

/// Represents a tax group for display in totals breakdown
class TaxGroupTotal {
  final String name;
  final double base;
  final double amount;

  const TaxGroupTotal({
    required this.name,
    required this.base,
    required this.amount,
  });
}

/// Calculated totals for a set of sale order lines
class OrderTotalsBreakdown {
  /// Price x Qty (without discount)
  final double subtotalUndiscounted;

  /// Total discount amount
  final double totalDiscount;

  /// Base for taxes (with discount applied)
  final double subtotal;

  /// Total including taxes
  final double total;

  /// Tax groups for breakdown display
  final List<TaxGroupTotal> taxGroups;

  /// Whether any discount was applied
  bool get hasDiscount => totalDiscount > 0;

  const OrderTotalsBreakdown({
    required this.subtotalUndiscounted,
    required this.totalDiscount,
    required this.subtotal,
    required this.total,
    required this.taxGroups,
  });
}

/// Calculates order totals from a list of sale order lines.
///
/// Extracts the business logic that was previously embedded in the
/// _CalculatedTotalsBreakdown widget. Groups taxes by name and
/// aggregates line amounts into order-level totals.
class OrderTotalsCalculator {
  const OrderTotalsCalculator();

  /// Calculate totals breakdown from visible order lines.
  ///
  /// [lines] - The product lines to aggregate
  /// [taxNameResolver] - Optional function to resolve tax names from taxIds/taxNames
  OrderTotalsBreakdown calculate({
    required List<SaleOrderLine> lines,
    String Function(String? taxIds, String? taxNames)? taxNameResolver,
  }) {
    double subtotalUndiscounted = 0;
    double totalDiscount = 0;
    double subtotal = 0;
    double total = 0;

    final taxGroupsMap = <String, TaxGroupTotal>{};

    for (final line in lines) {
      if (line.isProductLine) {
        final baseAmount = line.priceUnit * line.productUomQty;
        final discountAmount = baseAmount * (line.discount / 100);
        final lineSubtotal = line.priceSubtotal;
        final lineTax = line.priceTax;

        subtotalUndiscounted += baseAmount;
        totalDiscount += discountAmount;
        subtotal += lineSubtotal;
        total += line.priceTotal;

        // Group by tax name
        if (lineSubtotal > 0) {
          String groupName;
          String? resolvedNames = line.taxNames;
          if ((resolvedNames == null || resolvedNames.isEmpty) &&
              taxNameResolver != null) {
            resolvedNames = taxNameResolver(line.taxIds, line.taxNames);
          }
          if (resolvedNames != null && resolvedNames.isNotEmpty) {
            groupName =
                TaxCalculatorService.getFirstSimplifiedTaxName(resolvedNames);
          } else if (lineTax > 0) {
            groupName = 'Impuestos';
          } else {
            groupName = 'IVA 0%';
          }

          if (taxGroupsMap.containsKey(groupName)) {
            final current = taxGroupsMap[groupName]!;
            taxGroupsMap[groupName] = TaxGroupTotal(
              name: groupName,
              base: current.base + lineSubtotal,
              amount: current.amount + lineTax,
            );
          } else {
            taxGroupsMap[groupName] = TaxGroupTotal(
              name: groupName,
              base: lineSubtotal,
              amount: lineTax,
            );
          }
        }
      }
    }

    return OrderTotalsBreakdown(
      subtotalUndiscounted: subtotalUndiscounted,
      totalDiscount: totalDiscount,
      subtotal: subtotal,
      total: total,
      taxGroups: taxGroupsMap.values.toList(),
    );
  }
}

/// Global instance (stateless, can be const)
const orderTotalsCalculator = OrderTotalsCalculator();
