import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_widgets/odoo_widgets.dart' show OdooSummaryCard, OdooSummaryRow;

import '../../../products/products.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

// ==============================================================================
// PUBLIC WIDGET
// ==============================================================================

/// Widget for displaying sales order totals.
///
/// Can calculate totals from [lines] (local calculation, Ecuador style)
/// or use [order.tax_totals] (Odoo provided).
class SalesOrderTotals extends ConsumerWidget {
  final SaleOrder? order;
  final List<SaleOrderLine> lines;

  const SalesOrderTotals({super.key, this.order, this.lines = const []});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If we have an order but no lines (or empty lines), fallback to Odoo's tax totals
    if (order != null && lines.isEmpty) {
      return _TaxTotalsBreakdown(order: order!);
    }

    // Resolve tax names from local cache (taxIds -> name)
    // Use catalogInitProvider to ensure cache is loaded before resolving
    final catalogAsync = ref.watch(catalogInitProvider);

    // Calculate totals using the extracted service
    final taxNameResolver = catalogAsync.whenOrNull(
      data: (catalog) => (String? taxIds, String? taxNames) =>
          catalog.resolveTaxGroupName(taxIds, taxNames),
    );

    final totals = orderTotalsCalculator.calculate(
      lines: lines,
      taxNameResolver: taxNameResolver,
    );

    return _OrderTotalsView(
      subtotalUndiscounted: totals.subtotalUndiscounted,
      totalDiscount: totals.totalDiscount,
      subtotalResult: totals.subtotal,
      total: totals.total,
      taxGroups: totals.taxGroups,
      currencySymbol: order?.currencySymbol ?? '\$',
      hasDiscount: totals.hasDiscount,
    );
  }
}

// ==============================================================================
// INTERNAL WIDGETS
// ==============================================================================

/// Widget to handle Odoo data parsing for totals
class _TaxTotalsBreakdown extends StatelessWidget {
  final SaleOrder order;

  const _TaxTotalsBreakdown({required this.order});

  @override
  Widget build(BuildContext context) {
    final symbol = order.currencySymbol ?? '\$';
    final taxTotals = order.taxTotals;
    final hasDiscount = order.totalDiscountAmount > 0;

    // Calculate subtotal without discount
    final subtotalUndiscounted =
        order.amountUntaxed + order.totalDiscountAmount;

    // Build tax groups from Odoo JSON
    // Supports both Odoo 17 (groups_by_subtotal) and Odoo 18/19 (subtotals -> tax_groups)
    final taxGroups = <TaxGroupTotal>[];
    if (taxTotals != null) {
      // Odoo 18/19 format: subtotals[] -> tax_groups[]
      final subtotals = taxTotals['subtotals'];
      if (subtotals is List && subtotals.isNotEmpty) {
        for (final subtotal in subtotals) {
          if (subtotal is Map) {
            final tGroups = subtotal['tax_groups'];
            if (tGroups is List) {
              for (final group in tGroups) {
                if (group is Map) {
                  final name = group['group_name']?.toString() ??
                      group['tax_group_name']?.toString() ??
                      'Impuesto';
                  final amount = _toDouble(
                    group['tax_amount_currency'] ??
                        group['tax_group_amount'],
                  );
                  final base = _toDouble(
                    group['display_base_amount_currency'] ??
                        group['base_amount_currency'] ??
                        group['tax_group_base_amount'],
                  );
                  taxGroups.add(TaxGroupTotal(
                    name: name,
                    base: base,
                    amount: amount,
                  ));
                }
              }
            }
          }
        }
      }

      // Fallback: Odoo 17 format (groups_by_subtotal)
      if (taxGroups.isEmpty) {
        final groupsBySubtotal = taxTotals['groups_by_subtotal'];
        if (groupsBySubtotal is Map) {
          for (final entry in groupsBySubtotal.entries) {
            final groups = entry.value;
            if (groups is List) {
              for (final group in groups) {
                if (group is Map) {
                  final taxGroupName =
                      group['tax_group_name']?.toString() ?? 'Impuesto';
                  final taxGroupAmount =
                      _toDouble(group['tax_group_amount']);
                  final taxGroupBase = _toDouble(
                    group['display_base_amount_currency'] ??
                        group['tax_group_base_amount'],
                  );
                  taxGroups.add(TaxGroupTotal(
                    name: taxGroupName,
                    base: taxGroupBase,
                    amount: taxGroupAmount,
                  ));
                }
              }
            }
          }
        }
      }
    }

    return _OrderTotalsView(
      subtotalUndiscounted: subtotalUndiscounted,
      totalDiscount: order.totalDiscountAmount,
      subtotalResult: order.amountUntaxed,
      total: order.amountTotal,
      taxGroups: taxGroups,
      currencySymbol: symbol,
      hasDiscount: hasDiscount,
    );
  }

  double _toDouble(dynamic value) {
    if (value == null || value == false) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Shared view widget used by both calculation methods
class _OrderTotalsView extends StatelessWidget {
  final double subtotalUndiscounted;
  final double totalDiscount;
  final double subtotalResult;
  final double total;
  final List<TaxGroupTotal> taxGroups;
  final String currencySymbol;
  final bool hasDiscount;

  const _OrderTotalsView({
    required this.subtotalUndiscounted,
    required this.totalDiscount,
    required this.subtotalResult,
    required this.total,
    required this.taxGroups,
    required this.currencySymbol,
    this.hasDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return OdooSummaryCard(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Subtotal without Discount
        if (hasDiscount) ...[
          OdooSummaryRow(
            label: 'Subtotal',
            amount: subtotalUndiscounted,
            prefix: currencySymbol,
            amountStyle: theme.typography.body?.copyWith(fontWeight: FontWeight.bold),
          ),
          OdooSummaryRow(
            label: 'Descuento',
            amount: -totalDiscount,
            prefix: currencySymbol,
            highlightNegative: true,
          ),
        ],

        // 2. Subtotal Net
        OdooSummaryRow(
          label: 'Subtotal Neto',
          amount: subtotalResult,
          prefix: currencySymbol,
          amountStyle: theme.typography.body?.copyWith(fontWeight: FontWeight.bold),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Divider(),
        ),

        // 3. Tax Breakdown
        if (taxGroups.isNotEmpty)
          ...taxGroups.expand(
            (group) => [
              if (group.base > 0)
                OdooSummaryRow(
                  label: 'Base ${group.name}',
                  amount: group.base,
                  prefix: currencySymbol,
                  compact: true,
                ),
              OdooSummaryRow(
                label: group.name,
                amount: group.amount,
                prefix: currencySymbol,
                amountStyle: theme.typography.body?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          )
        else
          OdooSummaryRow(
            label: 'Impuestos',
            amount: 0,
            prefix: currencySymbol,
          ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(
            style: DividerThemeData(
              thickness: 2,
              decoration: BoxDecoration(color: theme.accentColor),
            ),
          ),
        ),

        // 4. Total
        OdooSummaryRow(
          label: 'Total',
          amount: total,
          prefix: currencySymbol,
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
