import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/render_options.dart';


/// Widget for rendering tax totals in PDF reports.
///
/// Creates a table with:
/// - Subtotal before Discount (if discounts exist) - italic, grey
/// - Discount (if discounts exist) - bold, red
/// - Subtotal
/// - Tax base per tax group
/// - Tax amount per tax group
/// - Total - primary color background, white text
///
/// Labels and currency formatting are driven by [RenderOptions.effectiveLocale].
class TaxTotalsWidget {
  final Map<String, dynamic> context;
  final RenderOptions options;

  TaxTotalsWidget({
    required this.context,
    required this.options,
  });

  /// Renders the tax totals widget.
  /// Returns null if no tax_totals found in context.
  List<pw.Widget>? render() {
    // Check doc for discount info
    final doc = context['doc'];

    // Get tax_totals from context - try multiple sources
    var taxTotals = context['tax_totals'];

    // If tax_totals is a function (lazy evaluation), call it
    if (taxTotals is Function) {
      taxTotals = taxTotals();
    }

    // Try to get from doc if not at root
    if (taxTotals == null || taxTotals is! Map) {
      if (doc is Map) {
        taxTotals = doc['tax_totals'];
        if (taxTotals is Function) {
          taxTotals = taxTotals();
        }
      }
    }

    if (taxTotals == null || taxTotals is! Map) {
      return null;
    }

    final primaryColor = _getPrimaryColor();
    final locale = options.effectiveLocale;
    final rows = <pw.TableRow>[];

    // 1. Subtotal before Discount (if has discounts)
    final hasDiscounts = taxTotals['has_discounts'] == true;

    if (hasDiscounts) {
      final amountUndiscounted = taxTotals['amount_undiscounted_currency'] ?? 0.0;
      rows.add(_createRow(
        locale.labelSubtotalBeforeDiscount,
        locale.formatCurrency(amountUndiscounted),
        isItalic: true,
        textColor: PdfColors.grey600,
      ));

      // 2. Discount
      final discountAmount = taxTotals['discount_amount_currency'] ?? 0.0;
      rows.add(_createRow(
        locale.labelDiscount,
        locale.formatCurrency(discountAmount),
        isBold: true,
        textColor: PdfColors.red,
      ));
    }

    // 3. Process subtotals
    final subtotals = taxTotals['subtotals'];
    if (subtotals is List) {
      for (final subtotal in subtotals) {
        if (subtotal is Map) {
          // Subtotal row
          final subtotalName = subtotal['name']?.toString() ?? 'Subtotal';
          final baseAmount = subtotal['base_amount_currency'] ??
                            subtotal['amount'] ?? 0.0;
          rows.add(_createRow(subtotalName, locale.formatCurrency(baseAmount)));

          // Tax groups (Base IVA X% and IVA X%)
          final taxGroups = subtotal['tax_groups'];
          if (taxGroups is List) {
            for (final taxGroup in taxGroups) {
              if (taxGroup is Map) {
                final groupName = taxGroup['group_name']?.toString() ??
                    locale.defaultTaxGroupLabel ?? 'Tax';
                final taxBase = taxGroup['display_base_amount_currency'] ??
                    taxGroup['base_amount_currency'] ??
                    subtotal['base_amount_currency'] ??
                    subtotal['amount'] ??
                    0.0;
                final taxAmount = taxGroup['tax_amount_currency'] ??
                                 taxGroup['tax_group_amount'] ?? 0.0;

                // Base Tax X%
                rows.add(_createRow('${locale.labelTaxBasePrefix} $groupName', locale.formatCurrency(taxBase)));
                // Tax X%
                rows.add(_createRow(groupName, locale.formatCurrency(taxAmount)));
              }
            }
          }
        }
      }
    }

    // 4. Total row
    final totalAmount = taxTotals['total_amount_currency'] ??
                       taxTotals['amount_total'] ?? 0.0;
    rows.add(_createRow(
      locale.labelTotal,
      locale.formatCurrency(totalAmount),
      isBold: true,
      textColor: PdfColors.white,
      bgColor: primaryColor,
    ));

    // Create table with thin borders (Odoo style)
    final table = pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Label column - flexible
        1: const pw.FixedColumnWidth(100), // Value column - wider for currency format
      },
      children: rows,
    );

    // Return just the table - alignment is handled by parent cell
    return [
      table,
    ];
  }

  /// Gets the company primary color from context.
  PdfColor _getPrimaryColor() {
    final company = context['company'];
    if (company is Map && company['primary_color'] != null) {
      final colorHex = company['primary_color'].toString();
      if (colorHex.startsWith('#') && colorHex.length >= 7) {
        final hex = colorHex.substring(1);
        final intColor = int.tryParse(hex, radix: 16);
        if (intColor != null) {
          return PdfColor.fromInt(0xFF000000 | intColor);
        }
      }
    }
    return const PdfColor.fromInt(0xFF17a2b8);
  }

  /// Creates a table row with optional styles.
  pw.TableRow _createRow(
    String label,
    String value, {
    bool isBold = false,
    bool isItalic = false,
    PdfColor? textColor,
    PdfColor? bgColor,
  }) {
    final fontSize = options.baseFontSize - 1; // Slightly smaller for totals
    return pw.TableRow(
      decoration: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
              color: textColor ?? PdfColors.black,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
              color: textColor ?? PdfColors.black,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }
}
