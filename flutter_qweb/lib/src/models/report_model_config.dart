/// Configuration for how a report extracts lines from a document model.
///
/// Different Odoo models store their line items in different fields
/// (e.g., `order_line` for sale orders, `invoice_line_ids` for invoices).
/// This config tells the report service where to find them.
///
/// ```dart
/// // Use a preset
/// final config = ReportModelConfig.saleOrder;
///
/// // Or define your own
/// final config = ReportModelConfig(
///   lineFields: ['picking_line_ids'],
///   subtotalLabel: 'Subtotal',
/// );
/// ```
library;

/// Configuration for report line extraction and labeling.
class ReportModelConfig {
  /// Ordered list of field names to check for line items.
  /// The first non-empty field found will be used.
  final List<String> lineFields;

  /// Optional method name for custom line filtering (e.g., '_get_order_lines_to_report').
  final String? linesToReportMethod;

  /// Default tax group name when tax_totals is missing and must be synthesized.
  /// If null, no tax group label is assumed.
  final String? defaultTaxGroupName;

  /// Label for the subtotal row in tax_totals.
  final String subtotalLabel;

  const ReportModelConfig({
    this.lineFields = const ['order_line', 'invoice_line_ids', 'line_ids'],
    this.linesToReportMethod,
    this.defaultTaxGroupName,
    this.subtotalLabel = 'Subtotal',
  });

  /// Preset for sale.order documents.
  static const saleOrder = ReportModelConfig(
    lineFields: ['order_line'],
    linesToReportMethod: '_get_order_lines_to_report',
  );

  /// Preset for account.move (invoice/bill) documents.
  static const accountMove = ReportModelConfig(
    lineFields: ['invoice_line_ids'],
    linesToReportMethod: '_get_move_lines_to_report',
  );

  /// Generic preset — tries common line field names in order.
  static const generic = ReportModelConfig();
}
