/// Configurable locale for PDF report rendering.
///
/// Encapsulates all locale-specific formatting (number separators, currency,
/// date patterns) and UI labels used in report generation. This replaces
/// hardcoded Spanish/Ecuador defaults with a configurable system.
///
/// ```dart
/// // Use preset locales
/// final options = RenderOptions(reportLocale: ReportLocale.us());
/// final options = RenderOptions(reportLocale: ReportLocale.ecuador());
///
/// // Or configure custom locale
/// final options = RenderOptions(
///   reportLocale: ReportLocale(
///     thousandsSeparator: ' ',
///     decimalSeparator: ',',
///     currencySymbol: '€',
///     currencyPattern: CurrencyPattern.symbolAfter,
///   ),
/// );
/// ```
library;

/// Where to place the currency symbol relative to the amount.
enum CurrencyPattern {
  /// Symbol before amount: $1,234.56
  symbolBefore,

  /// Symbol after amount: 1.234,56 €
  symbolAfter,
}

/// Locale configuration for PDF report rendering.
///
/// Controls number formatting, currency display, date patterns, and
/// translatable labels used in tax totals and other report components.
class ReportLocale {
  /// Thousands separator character (e.g., ',' for US, '.' for Ecuador).
  final String thousandsSeparator;

  /// Decimal separator character (e.g., '.' for US, ',' for Ecuador).
  final String decimalSeparator;

  /// Currency symbol (e.g., '$', '€', 'S/.').
  final String currencySymbol;

  /// Where to place the currency symbol.
  final CurrencyPattern currencyPattern;

  /// Number of decimal places for currency formatting.
  final int decimalPlaces;

  /// Date format pattern (e.g., 'dd/MM/yyyy', 'MM/dd/yyyy').
  final String dateFormat;

  /// Locale identifier (e.g., 'es_EC', 'en_US').
  final String localeCode;

  // --- Translatable labels for tax totals widget ---

  /// Label for "Subtotal before Discount" row.
  final String labelSubtotalBeforeDiscount;

  /// Label for "Discount" row.
  final String labelDiscount;

  /// Label for "Total" row.
  final String labelTotal;

  /// Prefix for tax base rows (e.g., "Base" in "Base IVA 15%").
  final String labelTaxBasePrefix;

  /// Default tax group label when tax_totals is synthesized and no
  /// specific group name is available (e.g., 'Tax', 'IVA 15%').
  /// If null, the tax group row is omitted when no name is known.
  final String? defaultTaxGroupLabel;

  /// Label for the "Subtotal" row in tax_totals.
  final String labelSubtotal;

  // --- Translatable labels for document layout ---

  /// Label for quotation documents (draft/sent state).
  final String labelQuotation;

  /// Label for confirmed sale order documents.
  final String labelSaleOrder;

  /// Label for cancelled quotation documents.
  final String labelQuotationCancelled;

  /// Label prefix for payment terms (e.g., "Payment terms:").
  final String labelPaymentTerms;

  /// Label for page number in footer (e.g., "Page").
  final String labelPage;

  const ReportLocale({
    this.thousandsSeparator = ',',
    this.decimalSeparator = '.',
    this.currencySymbol = r'$',
    this.currencyPattern = CurrencyPattern.symbolBefore,
    this.decimalPlaces = 2,
    this.dateFormat = 'MM/dd/yyyy',
    this.localeCode = 'en_US',
    this.labelSubtotalBeforeDiscount = 'Subtotal before Discount',
    this.labelDiscount = 'Discount',
    this.labelTotal = 'Total',
    this.labelTaxBasePrefix = 'Base',
    this.defaultTaxGroupLabel,
    this.labelSubtotal = 'Subtotal',
    this.labelQuotation = 'Quotation',
    this.labelSaleOrder = 'Sale Order',
    this.labelQuotationCancelled = 'Cancelled Quotation',
    this.labelPaymentTerms = 'Payment terms:',
    this.labelPage = 'Page',
  });

  /// Ecuador locale: period thousands, comma decimals, $ symbol.
  const ReportLocale.ecuador({
    this.currencySymbol = r'$',
  }) : thousandsSeparator = '.',
       decimalSeparator = ',',
       currencyPattern = CurrencyPattern.symbolBefore,
       decimalPlaces = 2,
       dateFormat = 'dd/MM/yyyy',
       localeCode = 'es_EC',
       labelSubtotalBeforeDiscount = 'Subtotal sin Descuento',
       labelDiscount = 'Descuento',
       labelTotal = 'Total',
       labelTaxBasePrefix = 'Base',
       defaultTaxGroupLabel = 'IVA 15%',
       labelSubtotal = 'Subtotal',
       labelQuotation = 'Cotización',
       labelSaleOrder = 'Orden de Venta',
       labelQuotationCancelled = 'Cotización Cancelada',
       labelPaymentTerms = 'Términos de pago:',
       labelPage = 'Página';

  /// US locale: comma thousands, period decimals, $ symbol.
  const ReportLocale.us({
    this.currencySymbol = r'$',
  }) : thousandsSeparator = ',',
       decimalSeparator = '.',
       currencyPattern = CurrencyPattern.symbolBefore,
       decimalPlaces = 2,
       dateFormat = 'MM/dd/yyyy',
       localeCode = 'en_US',
       labelSubtotalBeforeDiscount = 'Subtotal before Discount',
       labelDiscount = 'Discount',
       labelTotal = 'Total',
       labelTaxBasePrefix = 'Base',
       defaultTaxGroupLabel = null,
       labelSubtotal = 'Subtotal',
       labelQuotation = 'Quotation',
       labelSaleOrder = 'Sale Order',
       labelQuotationCancelled = 'Cancelled Quotation',
       labelPaymentTerms = 'Payment terms:',
       labelPage = 'Page';

  /// European locale: period thousands, comma decimals, euro symbol after.
  const ReportLocale.europe({
    this.currencySymbol = '€',
  }) : thousandsSeparator = '.',
       decimalSeparator = ',',
       currencyPattern = CurrencyPattern.symbolAfter,
       decimalPlaces = 2,
       dateFormat = 'dd/MM/yyyy',
       localeCode = 'es_ES',
       labelSubtotalBeforeDiscount = 'Subtotal antes de Descuento',
       labelDiscount = 'Descuento',
       labelTotal = 'Total',
       labelTaxBasePrefix = 'Base',
       defaultTaxGroupLabel = null,
       labelSubtotal = 'Subtotal',
       labelQuotation = 'Cotización',
       labelSaleOrder = 'Orden de Venta',
       labelQuotationCancelled = 'Cotización Cancelada',
       labelPaymentTerms = 'Términos de pago:',
       labelPage = 'Página';

  /// Format a numeric value as currency string.
  ///
  /// ```dart
  /// final locale = ReportLocale.ecuador();
  /// locale.formatCurrency(1234.56); // '$ 1.234,56'
  ///
  /// final usLocale = ReportLocale.us();
  /// usLocale.formatCurrency(1234.56); // '$1,234.56'
  /// ```
  String formatCurrency(dynamic value) {
    if (value == null) return _buildCurrencyString('0$decimalSeparator${'0' * decimalPlaces}');

    double numValue = 0.0;
    if (value is num) {
      numValue = value.toDouble();
    } else if (value is String) {
      numValue = double.tryParse(value) ?? 0.0;
    }

    final parts = numValue.toStringAsFixed(decimalPlaces).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}$thousandsSeparator',
    );
    final formatted = '$intPart$decimalSeparator${parts[1]}';
    return _buildCurrencyString(formatted);
  }

  String _buildCurrencyString(String formattedNumber) {
    return switch (currencyPattern) {
      CurrencyPattern.symbolBefore => '$currencySymbol $formattedNumber',
      CurrencyPattern.symbolAfter => '$formattedNumber $currencySymbol',
    };
  }
}
