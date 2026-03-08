import 'dart:convert';
import 'package:drift/drift.dart';
import '../../database/database.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import '../../utils/precision_config.dart';

/// Unified service for all tax-related operations
///
/// This is the single source of truth for taxes in the application.
/// Like Odoo's account.tax model, this class centralizes:
///
/// **Lookup & Data:**
/// - Product tax lookup from local database
/// - Fiscal position tax mapping (e.g., IVA 12% -> IVA 0% for exports)
/// - Tax ID parsing and conversion
///
/// **Calculations:**
/// - Multi-tax calculation with different computation types (percent, fixed, division)
/// - Tax-inclusive price extraction
/// - Line amount calculations (subtotal, tax, total)
/// - Order totals aggregation
///
/// **Display & Formatting:**
/// - Tax name simplification (remove percentage in parentheses)
/// - Tax grouping for totals display
/// - Tax list building for QWeb reports
///
/// Usage:
/// ```dart
/// final taxService = ref.read(taxCalculatorProvider);
///
/// // Get tax info for a product
/// final taxInfo = await taxService.getProductTaxInfo(productId: 123);
///
/// // Calculate line amounts
/// final result = taxService.calculateLineAmounts(
///   priceUnit: 100.0,
///   quantity: 2.0,
///   discount: 10.0,
///   taxes: taxInfo.taxes,
/// );
///
/// // Format tax name for display
/// final displayName = TaxCalculatorService.simplifyTaxName("IVA 15% (15%)");
/// // Returns: "IVA 15%"
/// ```
class TaxCalculatorService {
  final AppDatabase _db;
  MoneyRounding _rounding = const MoneyRounding();
  bool _precisionInitialized = false;

  /// Cache for fiscal position tax mappings to avoid repeated DB queries
  final Map<int, List<AccountFiscalPositionTaxData>> _fiscalPositionCache = {};

  TaxCalculatorService(this._db);

  /// Lazily initialize precision from database configuration.
  ///
  /// Called automatically before any calculation that uses [_rounding].
  /// Safe to call multiple times — only loads from DB on the first call.
  Future<void> _ensurePrecision() async {
    if (_precisionInitialized) return;
    _precisionInitialized = true;
    try {
      final config = await PrecisionConfig.fromDatabase(_db);
      _rounding = config.amountRounding;
      logger.d(
        '[TaxCalculator]',
        'Initialized precision: ${_rounding.decimalPlaces} decimals',
      );
    } catch (e) {
      logger.w(
        '[TaxCalculator]',
        'Failed to load precision config, using defaults: $e',
      );
    }
  }

  /// Force re-initialization of precision config (e.g., after sync).
  Future<void> refreshPrecision() async {
    _precisionInitialized = false;
    await _ensurePrecision();
  }

  /// Clear the fiscal position cache (call after sync)
  void clearCache() {
    _fiscalPositionCache.clear();
    logger.d('[TaxCalculator]', 'Cache cleared');
  }

  /// Get tax information for a product from local database
  ///
  /// Returns [TaxInfo] containing:
  /// - taxIds: List of tax IDs (comma-separated string for sale.order.line)
  /// - taxNames: Combined display names of applicable taxes
  /// - taxPercent: Total tax percentage (sum of all applicable taxes)
  /// - taxes: Full tax records for detailed calculations
  ///
  /// [productId] - product.product ID
  /// [productTmplId] - product.template ID (if known)
  /// [typeTaxUse] - 'sale' or 'purchase' (default: 'sale')
  /// [fiscalPositionId] - Optional fiscal position ID for tax mapping
  Future<TaxInfo> getProductTaxInfo({
    required int productId,
    int? productTmplId,
    String typeTaxUse = 'sale',
    int? fiscalPositionId,
  }) async {
    await _ensurePrecision();
    try {
      logger.d(
        '[TaxCalculator]',
        'Getting tax info for product $productId (fiscalPos: $fiscalPositionId)',
      );

      // Get product to find tax IDs
      final product = await (_db.select(
        _db.productProduct,
      )..where((t) => t.odooId.equals(productId))).getSingleOrNull();

      if (product == null) {
        logger.w('[TaxCalculator]', 'Product $productId not found in local DB');
        return TaxInfo.empty();
      }

      // Get tax IDs from product (stored as JSON array or comma-separated string)
      List<int> taxIds = _parseProductTaxIds(product.taxesId);

      if (taxIds.isEmpty) {
        logger.d(
          '[TaxCalculator]',
          'No taxes configured for product $productId (${product.name})',
        );
        return TaxInfo.empty();
      }

      logger.d(
        '[TaxCalculator]',
        'Product ${product.name} has source tax IDs: $taxIds',
      );

      // Get tax records from database
      List<AccountTaxData> taxes = await getTaxesByIds(
        taxIds,
        typeTaxUse: typeTaxUse,
      );

      if (taxes.isEmpty) {
        logger.d(
          '[TaxCalculator]',
          'No active taxes found for IDs: $taxIds (type: $typeTaxUse)',
        );
        return TaxInfo.empty();
      }

      // Apply fiscal position tax mapping if provided
      if (fiscalPositionId != null && fiscalPositionId > 0) {
        taxes = await mapTaxesForFiscalPosition(taxes, fiscalPositionId);
        logger.d(
          '[TaxCalculator]',
          'After fiscal position mapping: ${taxes.map((t) => '${t.name} (${t.odooId})').join(', ')}',
        );
      }

      // Calculate total tax percentage and build display names
      double totalTaxPercent = 0.0;
      final taxNamesList = <String>[];

      for (final tax in taxes) {
        // Only percent type taxes are summed directly
        // Fixed and division types need different handling
        if (tax.amountType == 'percent') {
          totalTaxPercent += tax.amount;
        }
        taxNamesList.add(tax.name);
        logger.d(
          '[TaxCalculator]',
          '  Tax: ${tax.name} (${tax.amountType}=${tax.amount}%, priceInclude=${tax.priceInclude})',
        );
      }

      final taxIdsStr = taxes.map((t) => t.odooId).join(',');
      final taxNamesStr = taxNamesList.join(', ');

      logger.d(
        '[TaxCalculator]',
        'Final: Product $productId taxes: $taxNamesStr (total $totalTaxPercent%)',
      );

      return TaxInfo(
        taxIds: taxIdsStr,
        taxNames: taxNamesStr,
        taxPercent: totalTaxPercent,
        taxes: taxes,
      );
    } catch (e, stack) {
      logger.e('[TaxCalculator]', 'Error getting tax info: $e', e, stack);
      return TaxInfo.empty();
    }
  }

  /// Parse tax IDs from product.taxesId field
  /// Handles both JSON array format [1, 2, 3] and comma-separated "1,2,3"
  List<int> _parseProductTaxIds(String? taxesId) {
    if (taxesId == null || taxesId.isEmpty) return [];

    try {
      final decoded = json.decode(taxesId);
      if (decoded is List) {
        return decoded.map((e) => e as int).toList();
      }
    } catch (_) {
      // Not JSON, try parsing as comma-separated string
    }

    return taxesId
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  /// Map taxes according to fiscal position rules
  ///
  /// Fiscal positions define tax substitutions, e.g.:
  /// - IVA 12% -> IVA 0% for exports
  /// - IVA 12% -> (removed) for tax-exempt customers
  ///
  /// [sourceTaxes] - Original taxes from product
  /// [fiscalPositionId] - Fiscal position to apply
  Future<List<AccountTaxData>> mapTaxesForFiscalPosition(
    List<AccountTaxData> sourceTaxes,
    int fiscalPositionId,
  ) async {
    if (sourceTaxes.isEmpty || fiscalPositionId <= 0) return sourceTaxes;

    try {
      // Get fiscal position tax mappings (use cache if available)
      List<AccountFiscalPositionTaxData> mappings;
      if (_fiscalPositionCache.containsKey(fiscalPositionId)) {
        mappings = _fiscalPositionCache[fiscalPositionId]!;
      } else {
        mappings = await (_db.select(
          _db.accountFiscalPositionTax,
        )..where((t) => t.positionId.equals(fiscalPositionId))).get();
        _fiscalPositionCache[fiscalPositionId] = mappings;
        logger.d(
          '[TaxCalculator]',
          'Cached ${mappings.length} tax mappings for fiscal position $fiscalPositionId',
        );
      }

      if (mappings.isEmpty) {
        logger.d(
          '[TaxCalculator]',
          'No tax mappings found for fiscal position $fiscalPositionId',
        );
        return sourceTaxes;
      }

      // Apply mappings
      final resultTaxIds = <int>[];

      for (final sourceTax in sourceTaxes) {
        // Find mapping for this source tax
        final mapping = mappings.firstWhere(
          (m) => m.taxSrcId == sourceTax.odooId,
          orElse: () => AccountFiscalPositionTaxData(
            id: -1,
            odooId: -1,
            positionId: fiscalPositionId,
            taxSrcId: sourceTax.odooId,
            taxSrcName: null,
            taxDestId: sourceTax.odooId, // Keep original if no mapping
            taxDestName: null,
            writeDate: null,
          ),
        );

        if (mapping.taxDestId > 0) {
          // Map to destination tax
          resultTaxIds.add(mapping.taxDestId);
          logger.d(
            '[TaxCalculator]',
            'Fiscal position: ${sourceTax.name} -> ${mapping.taxDestName ?? 'tax ID ${mapping.taxDestId}'}',
          );
        } else if (mapping.id == -1) {
          // No mapping found, keep original
          resultTaxIds.add(sourceTax.odooId);
          logger.d(
            '[TaxCalculator]',
            'Fiscal position: ${sourceTax.name} -> (no mapping, keeping original)',
          );
        } else {
          // Mapping exists but destination is null = remove tax
          logger.d(
            '[TaxCalculator]',
            'Fiscal position: ${sourceTax.name} -> (removed/exempt)',
          );
        }
      }

      if (resultTaxIds.isEmpty) {
        return [];
      }

      // Fetch the mapped taxes
      return getTaxesByIds(resultTaxIds);
    } catch (e, stack) {
      logger.e(
        '[TaxCalculator]',
        'Error applying fiscal position mapping: $e',
        e,
        stack,
      );
      return sourceTaxes; // Return original taxes on error
    }
  }

  /// Get tax records by IDs
  ///
  /// [taxIds] - List of tax IDs to fetch
  /// [typeTaxUse] - Filter by type_tax_use ('sale', 'purchase', or null for all)
  Future<List<AccountTaxData>> getTaxesByIds(
    List<int> taxIds, {
    String? typeTaxUse,
  }) async {
    await _ensurePrecision();
    if (taxIds.isEmpty) return [];

    try {
      var query = _db.select(_db.accountTax)
        ..where((t) => t.odooId.isIn(taxIds))
        ..where((t) => t.active.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.sequence)]);

      final taxes = await query.get();

      // Filter by type_tax_use if specified
      if (typeTaxUse != null) {
        return taxes
            .where((t) => t.typeTaxUse == typeTaxUse || t.typeTaxUse == 'none')
            .toList();
      }

      return taxes;
    } catch (e) {
      logger.e('[TaxCalculator]', 'Error getting taxes by IDs: $e');
      return [];
    }
  }

  /// Calculate tax amount for a given subtotal
  ///
  /// Handles different tax computation types:
  /// - percent: tax = subtotal * amount / 100
  /// - fixed: tax = amount * quantity
  /// - division: tax = subtotal - (subtotal / (1 + amount/100))
  ///
  /// [subtotal] - The amount to calculate tax on
  /// [taxes] - List of taxes to apply
  /// [quantity] - Quantity (for fixed taxes)
  /// [priceInclude] - Whether the price already includes tax
  TaxCalculationResult calculateTaxes({
    required double subtotal,
    required List<AccountTaxData> taxes,
    double quantity = 1.0,
    bool priceInclude = false,
  }) {
    if (taxes.isEmpty) {
      return TaxCalculationResult(
        taxAmount: 0.0,
        subtotalWithoutTax: subtotal,
        subtotalWithTax: subtotal,
        taxDetails: [],
      );
    }

    double totalTax = 0.0;
    double baseAmount = subtotal;
    final taxDetails = <TaxDetail>[];

    // Sort taxes by sequence
    final sortedTaxes = List<AccountTaxData>.from(taxes)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    for (final tax in sortedTaxes) {
      double taxAmount = 0.0;

      switch (tax.amountType) {
        case 'percent':
          if (tax.priceInclude) {
            // Extract tax from price-included amount
            // subtotal = base + tax = base + base*rate = base*(1+rate)
            // base = subtotal / (1 + rate)
            // tax = subtotal - base
            final rate = tax.amount / 100;
            final base = baseAmount / (1 + rate);
            taxAmount = baseAmount - base;
          } else {
            taxAmount = baseAmount * (tax.amount / 100);
          }
          break;

        case 'fixed':
          taxAmount = tax.amount * quantity;
          break;

        case 'division':
          // Division: price_include tax type
          // tax = subtotal - subtotal / (1 + rate)
          final rate = tax.amount / 100;
          taxAmount = baseAmount - (baseAmount / (1 + rate));
          break;

        default:
          taxAmount = baseAmount * (tax.amount / 100);
      }

      // Round tax amount per tax
      taxAmount = _rounding.round(taxAmount);

      totalTax += taxAmount;

      // If tax includes base amount, add to base for next tax calculation
      if (tax.includeBaseAmount) {
        baseAmount += taxAmount;
      }

      taxDetails.add(
        TaxDetail(
          taxId: tax.odooId,
          taxName: tax.name,
          amount: tax.amount,
          amountType: tax.amountType,
          taxAmount: taxAmount,
        ),
      );
    }

    return TaxCalculationResult(
      taxAmount: _rounding.round(totalTax),
      subtotalWithoutTax: _rounding.round(
        priceInclude ? subtotal - totalTax : subtotal,
      ),
      subtotalWithTax: _rounding.round(
        priceInclude ? subtotal : subtotal + totalTax,
      ),
      taxDetails: taxDetails,
    );
  }

  /// Get the default tax percent for sale operations
  /// Used when no specific product taxes are defined
  Future<double> getDefaultSaleTaxPercent() async {
    await _ensurePrecision();
    try {
      // Get the first active sale tax (typically IVA)
      final tax =
          await (_db.select(_db.accountTax)
                ..where((t) => t.active.equals(true))
                ..where((t) => t.typeTaxUse.equals('sale'))
                ..where((t) => t.amountType.equals('percent'))
                ..orderBy([(t) => OrderingTerm.asc(t.sequence)])
                ..limit(1))
              .getSingleOrNull();

      return tax?.amount ?? 0.0;
    } catch (e) {
      logger.e('[TaxCalculator]', 'Error getting default tax: $e');
      return 0.0;
    }
  }

  /// Calculate full line amounts for a sale order line
  ///
  /// This is the main entry point for calculating sale.order.line amounts:
  /// - Calculates subtotal from price_unit * quantity
  /// - Applies discount (percent or fixed amount)
  /// - Calculates taxes (handling price_include correctly)
  /// - Returns all computed fields
  ///
  /// [priceUnit] - Unit price (may include tax if product taxes have price_include=true)
  /// [quantity] - Product quantity
  /// [discount] - Discount percentage (0-100)
  /// [discountAmount] - Fixed discount amount (optional, takes precedence over percent)
  /// [taxes] - List of applicable taxes (from getProductTaxInfo)
  LineAmountResult calculateLineAmounts({
    required double priceUnit,
    required double quantity,
    double discount = 0.0,
    double? discountAmount,
    List<AccountTaxData> taxes = const [],
  }) {
    logger.d(
      '[TaxCalculator]',
      'calculateLineAmounts: price=$priceUnit, qty=$quantity, disc=$discount%, '
          'discAmt=$discountAmount, taxes=${taxes.length}',
    );

    // Step 1: Calculate base subtotal (before discount and taxes)
    final subtotalBeforeDiscount = priceUnit * quantity;

    // Step 2: Calculate discount
    double effectiveDiscountAmount;
    if (discountAmount != null && discountAmount > 0) {
      // Fixed discount amount
      effectiveDiscountAmount = discountAmount;
    } else if (discount > 0) {
      // Percentage discount
      effectiveDiscountAmount = subtotalBeforeDiscount * (discount / 100);
    } else {
      effectiveDiscountAmount = 0.0;
    }

    // Step 3: Calculate subtotal after discount
    final subtotalAfterDiscount =
        subtotalBeforeDiscount - effectiveDiscountAmount;

    // Step 4: Calculate taxes
    final taxResult = calculateTaxes(
      subtotal: subtotalAfterDiscount,
      taxes: taxes,
      quantity: quantity,
    );

    // Step 5: Handle price_include taxes
    // If any tax has price_include=true, the priceUnit already contains tax
    final hasPriceIncludeTax = taxes.any((t) => t.priceInclude);

    double priceSubtotal; // Amount without tax
    double priceTax; // Tax amount
    double priceTotal; // Total with tax

    if (hasPriceIncludeTax) {
      // Price already includes tax, we need to extract it
      priceTotal = subtotalAfterDiscount;
      priceTax = taxResult.taxAmount;
      priceSubtotal = subtotalAfterDiscount - priceTax;
    } else {
      // Price doesn't include tax, add it
      priceSubtotal = subtotalAfterDiscount;
      priceTax = taxResult.taxAmount;
      priceTotal = subtotalAfterDiscount + priceTax;
    }

    logger.d(
      '[TaxCalculator]',
      'Line result: subtotal=$priceSubtotal, tax=$priceTax, total=$priceTotal '
          '(priceInclude=$hasPriceIncludeTax)',
    );

    return LineAmountResult(
      priceSubtotal: _rounding.round(priceSubtotal),
      priceTax: _rounding.round(priceTax),
      priceTotal: _rounding.round(priceTotal),
      discountAmount: _rounding.round(effectiveDiscountAmount),
      taxDetails: taxResult.taxDetails,
    );
  }

  /// Calculate amounts for multiple lines (for order totals)
  ///
  /// Aggregates line amounts into order totals:
  /// - amountUntaxed: Sum of all line subtotals
  /// - amountTax: Sum of all line taxes
  /// - amountTotal: Sum of all line totals
  OrderTotalsResult calculateOrderTotals(List<LineAmountResult> lineResults) {
    double amountUntaxed = 0.0;
    double amountTax = 0.0;
    double amountTotal = 0.0;
    double totalDiscount = 0.0;

    for (final line in lineResults) {
      amountUntaxed += line.priceSubtotal;
      amountTax += line.priceTax;
      amountTotal += line.priceTotal;
      totalDiscount += line.discountAmount;
    }

    return OrderTotalsResult(
      amountUntaxed: _rounding.round(amountUntaxed),
      amountTax: _rounding.round(amountTax),
      amountTotal: _rounding.round(amountTotal),
      totalDiscountAmount: _rounding.round(totalDiscount),
    );
  }

  // ===========================================================================
  // STATIC UTILITIES - TAX NAME FORMATTING
  // ===========================================================================

  /// Simplify tax name by removing the percentage in parentheses
  ///
  /// Example: "IVA 15% (15%)" -> "IVA 15%"
  /// Example: "IVA 0% Venta Bienes (0%)" -> "IVA 0% Venta Bienes"
  ///
  /// Used for display in badges, totals, and reports.
  static String simplifyTaxName(String fullName) {
    if (fullName.isEmpty) return fullName;

    final parenIndex = fullName.indexOf('(');
    if (parenIndex > 0) {
      return fullName.substring(0, parenIndex).trim();
    }
    return fullName;
  }

  /// Get the first tax name from a comma-separated list and simplify it
  ///
  /// Example: "IVA 15% (15%), IVA 0%" -> "IVA 15%"
  static String getFirstSimplifiedTaxName(String? taxNames) {
    if (taxNames == null || taxNames.isEmpty) return '';

    final firstName = taxNames.split(',').first.trim();
    return simplifyTaxName(firstName);
  }

  /// Simplify all tax names in a comma-separated list
  ///
  /// Example: "IVA 15% (15%), IVA 0% (0%)" -> "IVA 15%, IVA 0%"
  static String simplifyAllTaxNames(String? taxNames) {
    if (taxNames == null || taxNames.isEmpty) return '';

    return taxNames
        .split(',')
        .map((name) => simplifyTaxName(name.trim()))
        .join(', ');
  }

  // ===========================================================================
  // STATIC UTILITIES - TAX ID PARSING
  // ===========================================================================

  /// Parse tax IDs from a comma-separated string
  ///
  /// Example: "1, 2, 3" -> [1, 2, 3]
  /// Example: "1,2,3" -> [1, 2, 3]
  static List<int> parseTaxIds(String? taxIdsStr) {
    if (taxIdsStr == null || taxIdsStr.isEmpty) return [];

    return taxIdsStr
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  /// Convert tax IDs list to comma-separated string
  ///
  /// Example: [1, 2, 3] -> "1,2,3"
  static String taxIdsToString(List<int> taxIds) {
    return taxIds.join(',');
  }

  // ===========================================================================
  // STATIC UTILITIES - TAX REPORT BUILDING
  // ===========================================================================

  /// Build tax list for QWeb report templates
  ///
  /// Creates a list of tax maps with structure expected by Odoo templates:
  /// ```dart
  /// [
  ///   {'id': 1, 'name': 'IVA 15%', 'tax_label': 'IVA 15%', 'amount': 15.0},
  ///   {'id': 2, 'name': 'IVA 0%', 'tax_label': 'IVA 0%', 'amount': 0.0},
  /// ]
  /// ```
  ///
  /// [taxIds] - Comma-separated tax IDs (e.g., "1,2")
  /// [taxNames] - Comma-separated tax names (e.g., "IVA 15%, IVA 0%")
  /// [taxDataMap] - Optional map of tax ID -> tax data for enhanced info
  ///
  /// Priority:
  /// 1. Uses taxDataMap if provided (has full tax info including amounts)
  /// 2. Falls back to parsing taxNames with taxIds for basic info
  static List<Map<String, dynamic>> buildTaxListForReport({
    String? taxIds,
    String? taxNames,
    Map<int, Map<String, dynamic>>? taxDataMap,
  }) {
    final taxList = <Map<String, dynamic>>[];

    // First try: Use taxDataMap for full tax info (includes amounts)
    if (taxDataMap != null && taxIds != null && taxIds.isNotEmpty) {
      final ids = parseTaxIds(taxIds);
      for (final taxId in ids) {
        final taxData = taxDataMap[taxId];
        if (taxData != null) {
          final taxName = taxData['name']?.toString() ?? 'IVA';
          taxList.add({
            'id': taxId,
            'name': taxName,
            'tax_label': taxName,
            'amount': taxData['amount'],
          });
        }
      }
    }

    // Second try: Use taxNames if taxDataMap didn't provide results
    if (taxList.isEmpty && taxNames != null && taxNames.isNotEmpty) {
      final names = taxNames.split(', ');
      final ids = parseTaxIds(taxIds);

      for (var i = 0; i < names.length; i++) {
        final name = names[i].trim();
        taxList.add({
          'id': i < ids.length ? ids[i] : null,
          'name': name,
          'tax_label': name,
        });
      }
    }

    return taxList;
  }

  /// Check if a line has taxes (either tax list or tax amount)
  static bool hasTaxes({
    List<Map<String, dynamic>>? taxList,
    double? priceTax,
  }) {
    return (taxList != null && taxList.isNotEmpty) ||
        (priceTax != null && priceTax > 0);
  }

  // ===========================================================================
  // STATIC UTILITIES - TAX GROUPING
  // ===========================================================================

  /// Group tax data for display in totals breakdown
  ///
  /// Returns a map of simplified tax name -> TaxGroupData
  /// Used by sales_order_totals widget.
  static Map<String, TaxGroupData> groupTaxesByName(
    List<TaxLineData> lines,
  ) {
    final groups = <String, TaxGroupData>{};

    for (final line in lines) {
      String groupName;

      if (line.taxNames != null && line.taxNames!.isNotEmpty) {
        groupName = getFirstSimplifiedTaxName(line.taxNames);
      } else if (line.taxAmount > 0) {
        // Has tax amount but no name - use generic
        groupName = 'Impuestos';
      } else {
        groupName = 'IVA 0%';
      }

      if (groups.containsKey(groupName)) {
        final current = groups[groupName]!;
        groups[groupName] = TaxGroupData(
          name: groupName,
          base: current.base + line.baseAmount,
          amount: current.amount + line.taxAmount,
        );
      } else {
        groups[groupName] = TaxGroupData(
          name: groupName,
          base: line.baseAmount,
          amount: line.taxAmount,
        );
      }
    }

    return groups;
  }
}

/// Result of line amount calculation
class LineAmountResult {
  /// Subtotal without tax (price_subtotal in Odoo)
  final double priceSubtotal;

  /// Tax amount for this line (price_tax in Odoo)
  final double priceTax;

  /// Total including tax (price_total in Odoo)
  final double priceTotal;

  /// Discount amount applied
  final double discountAmount;

  /// Breakdown of taxes applied
  final List<TaxDetail> taxDetails;

  const LineAmountResult({
    required this.priceSubtotal,
    required this.priceTax,
    required this.priceTotal,
    required this.discountAmount,
    required this.taxDetails,
  });

  @override
  String toString() =>
      'LineAmountResult(subtotal: $priceSubtotal, tax: $priceTax, total: $priceTotal, discount: $discountAmount)';
}

/// Result of order totals calculation
class OrderTotalsResult {
  /// Sum of all line subtotals (amount_untaxed in Odoo)
  final double amountUntaxed;

  /// Sum of all line taxes (amount_tax in Odoo)
  final double amountTax;

  /// Sum of all line totals (amount_total in Odoo)
  final double amountTotal;

  /// Sum of all line discounts
  final double totalDiscountAmount;

  const OrderTotalsResult({
    required this.amountUntaxed,
    required this.amountTax,
    required this.amountTotal,
    required this.totalDiscountAmount,
  });

  @override
  String toString() =>
      'OrderTotals(untaxed: $amountUntaxed, tax: $amountTax, total: $amountTotal, discount: $totalDiscountAmount)';
}

/// Tax information for a product
class TaxInfo {
  /// Comma-separated tax IDs (for sale.order.line.tax_id)
  final String taxIds;

  /// Display names of taxes
  final String taxNames;

  /// Total tax percentage (for simple calculations)
  final double taxPercent;

  /// Full tax records for detailed calculations
  final List<AccountTaxData> taxes;

  const TaxInfo({
    required this.taxIds,
    required this.taxNames,
    required this.taxPercent,
    required this.taxes,
  });

  factory TaxInfo.empty() =>
      const TaxInfo(taxIds: '', taxNames: '', taxPercent: 0.0, taxes: []);

  bool get isEmpty => taxIds.isEmpty;
  bool get isNotEmpty => taxIds.isNotEmpty;

  @override
  String toString() =>
      'TaxInfo(ids: $taxIds, names: $taxNames, percent: $taxPercent%)';
}

/// Result of tax calculation
class TaxCalculationResult {
  final double taxAmount;
  final double subtotalWithoutTax;
  final double subtotalWithTax;
  final List<TaxDetail> taxDetails;

  const TaxCalculationResult({
    required this.taxAmount,
    required this.subtotalWithoutTax,
    required this.subtotalWithTax,
    required this.taxDetails,
  });
}

/// Detail of a single tax calculation
class TaxDetail {
  final int taxId;
  final String taxName;
  final double amount;
  final String amountType;
  final double taxAmount;

  const TaxDetail({
    required this.taxId,
    required this.taxName,
    required this.amount,
    required this.amountType,
    required this.taxAmount,
  });
}

/// Data class for tax line information (used for grouping)
class TaxLineData {
  final String? taxNames;
  final double baseAmount;
  final double taxAmount;

  const TaxLineData({
    this.taxNames,
    required this.baseAmount,
    required this.taxAmount,
  });
}

/// Data class for grouped tax totals
class TaxGroupData {
  final String name;
  final double base;
  final double amount;

  const TaxGroupData({
    required this.name,
    required this.base,
    required this.amount,
  });
}
