import 'package:uuid/uuid.dart';

import '../../products/repositories/product_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

/// Callback type for resolving max discount percentage asynchronously
typedef MaxDiscountResolver = Future<double> Function();

/// Result of creating an order line
class OrderLineCreationResult {
  final SaleOrderLine? line;
  final bool success;
  final String? error;

  const OrderLineCreationResult._({
    this.line,
    required this.success,
    this.error,
  });

  factory OrderLineCreationResult.success(SaleOrderLine line) =>
      OrderLineCreationResult._(line: line, success: true);

  factory OrderLineCreationResult.failure(String error) =>
      OrderLineCreationResult._(success: false, error: error);
}

/// Unified service for creating order lines
///
/// This service consolidates the line creation logic from both
/// Fast Sale POS and Sale Order Form screens.
///
/// Features:
/// - Offline-first price calculation using local pricelist rules
/// - Tax calculation from local database
/// - Discount validation against company max discount
/// - Line totals calculation
///
/// Usage:
/// ```dart
/// final service = ref.read(orderLineCreationServiceProvider);
/// final result = await service.createLine(
///   productId: 123,
///   quantity: 2.0,
///   pricelistId: 1,
/// );
/// if (result.success) {
///   // Use result.line
/// }
/// ```
class OrderLineCreationService {
  static const _tag = '[OrderLineCreation]';

  final AppDatabase _db;
  final PricelistCalculatorService _pricelistCalculator;
  final ProductRepository? _productRepository;
  final TaxCalculatorService _taxCalculator;
  final MaxDiscountResolver _maxDiscountResolver;

  OrderLineCreationService({
    required AppDatabase db,
    required PricelistCalculatorService pricelistCalculator,
    required ProductRepository? productRepository,
    required TaxCalculatorService taxCalculator,
    required MaxDiscountResolver maxDiscountResolver,
  })  : _db = db,
        _pricelistCalculator = pricelistCalculator,
        _productRepository = productRepository,
        _taxCalculator = taxCalculator,
        _maxDiscountResolver = maxDiscountResolver;

  /// Create a new order line with full calculation
  ///
  /// Offline-first approach:
  /// 1. Try to calculate price from local pricelist rules
  /// 2. If online and no local price, fallback to Odoo onchange
  /// 3. Get tax info from local database
  /// 4. Validate discount against company max
  /// 5. Calculate line totals
  ///
  /// [orderId] - Order ID (can be negative for unsaved orders)
  /// [productId] - Product ID
  /// [productName] - Product display name
  /// [quantity] - Quantity to add
  /// [pricelistId] - Pricelist ID for price calculation
  /// [discount] - Optional discount override (will be validated)
  /// [uomId] - Unit of measure ID (optional, uses product default if null)
  /// [uomName] - Unit of measure name
  /// [priceUnit] - Optional price override (skips pricelist calculation)
  /// [taxIds] - Optional tax IDs string (comma-separated)
  /// [taxNames] - Optional tax names string
  /// [taxPercent] - Optional tax percentage override
  /// [productCode] - Product internal reference/code
  /// [sequence] - Line sequence number
  Future<OrderLineCreationResult> createLine({
    required int orderId,
    required int productId,
    required String productName,
    required double quantity,
    int? pricelistId,
    double? discount,
    int? uomId,
    String? uomName,
    double? priceUnit,
    String? taxIds,
    String? taxNames,
    double? taxPercent,
    String? productCode,
    int sequence = 0,
  }) async {
    try {
      logger.d(_tag, 'Creating line: product=$productId, qty=$quantity, '
          'pricelist=$pricelistId, priceOverride=$priceUnit');

      // Get product data from local database
      final db = _db;
      final product = await (db.select(db.productProduct)
            ..where((t) => t.odooId.equals(productId)))
          .getSingleOrNull();

      // Use product defaults if not provided
      final effectiveUomId = uomId ?? product?.uomId;
      final effectiveUomName = uomName ?? product?.uomName ?? 'Unidades';
      final effectiveProductCode = productCode ?? product?.defaultCode;
      final listPrice = product?.listPrice ?? 0.0;

      // 1. Calculate price from pricelist (offline-first)
      double finalPriceUnit = priceUnit ?? listPrice;
      double finalDiscount = discount ?? 0.0;
      bool priceCalculated = priceUnit != null;

      if (!priceCalculated && pricelistId != null && product != null) {
        try {
          final result = await _pricelistCalculator.calculatePrice(
            productId: productId,
            productTmplId: product.productTmplId ?? productId,
            pricelistId: pricelistId,
            quantity: quantity,
            uomId: effectiveUomId,
            productUomId: product.uomId,
            listPrice: listPrice,
            standardPrice: product.standardPrice,
          );

          finalPriceUnit = result.basePrice;
          finalDiscount = discount ?? result.discount;
          priceCalculated = true;
          logger.d(_tag, 'Price from pricelist: $finalPriceUnit, '
              'discount: $finalDiscount%, rule: ${result.ruleId}');
        } catch (e) {
          logger.w(_tag, 'Local pricelist calc failed: $e');
        }
      }

      // 2. Fallback to Odoo onchange if online, price not calculated, and order exists
      if (!priceCalculated && orderId > 0) {
        if (_productRepository != null) {
          try {
            final onchangeResult = await _productRepository.onchangeProduct(
              orderId: orderId,
              productId: productId,
              pricelistId: pricelistId,
              qty: quantity,
            );

            if (onchangeResult != null) {
              finalPriceUnit = (onchangeResult['price_unit'] as num?)
                      ?.toDouble() ??
                  finalPriceUnit;
              finalDiscount = discount ??
                  (onchangeResult['discount'] as num?)?.toDouble() ??
                  0.0;
              priceCalculated = true;
              logger.d(_tag, 'Price from Odoo: $finalPriceUnit, '
                  'discount: $finalDiscount%');
            }
          } catch (e) {
            logger.w(_tag, 'Odoo onchange failed: $e');
          }
        }
      }

      // 3. Validate discount against company max
      final maxDiscount = await _maxDiscountResolver();
      if (finalDiscount > maxDiscount) {
        logger.w(_tag, 'Discount $finalDiscount% exceeds max $maxDiscount%, '
            'clamping to max');
        finalDiscount = maxDiscount;
      }

      // 4. Get tax info
      double effectiveTaxPercent = taxPercent ?? 0.0;
      String? effectiveTaxIds = taxIds;
      String? effectiveTaxNames = taxNames;

      if (taxPercent == null) {
        try {
          final taxInfo = await _taxCalculator.getProductTaxInfo(
            productId: productId,
          );
          effectiveTaxPercent = taxInfo.taxPercent;
          effectiveTaxIds = taxInfo.taxIds;
          effectiveTaxNames = taxInfo.taxNames;
          logger.d(_tag, 'Tax from DB: $effectiveTaxPercent%, '
              'ids: $effectiveTaxIds');
        } catch (e) {
          logger.w(_tag, 'Tax lookup failed: $e');
        }
      }

      // 5. Calculate line totals
      final calc = saleOrderLineCalculator.calculateLine(
        priceUnit: finalPriceUnit,
        quantity: quantity,
        discountPercent: finalDiscount,
        taxPercent: effectiveTaxPercent,
      );

      // 6. Create line with all calculated values
      final line = SaleOrderLine(
        id: -DateTime.now().millisecondsSinceEpoch,
        lineUuid: const Uuid().v4(),
        orderId: orderId,
        sequence: sequence > 0 ? sequence : 10,
        productId: productId,
        productName: productName,
        productCode: effectiveProductCode,
        name: productName,
        productUomQty: quantity,
        productUomId: effectiveUomId,
        productUomName: effectiveUomName,
        priceUnit: finalPriceUnit,
        discount: finalDiscount,
        priceSubtotal: calc.priceSubtotal,
        priceTax: calc.priceTax,
        priceTotal: calc.priceTotal,
        taxIds: effectiveTaxIds,
        taxNames: effectiveTaxNames,
        displayType: LineDisplayType.product,
        isUnitProduct: product?.isUnitProduct ?? false,
      );

      logger.i(_tag, 'Line created: ${line.productName} x${line.productUomQty} '
          '@ ${line.priceUnit} - ${line.discount}% = ${line.priceTotal}');

      return OrderLineCreationResult.success(line);
    } catch (e, stack) {
      logger.e(_tag, 'Error creating line', e, stack);
      return OrderLineCreationResult.failure('Error al crear línea: $e');
    }
  }

  /// Create a section line (display_type = 'line_section')
  SaleOrderLine createSectionLine({
    required int orderId,
    required String name,
    int sequence = 0,
  }) {
    return SaleOrderLine(
      id: -DateTime.now().millisecondsSinceEpoch,
      lineUuid: const Uuid().v4(),
      orderId: orderId,
      sequence: sequence,
      name: name,
      displayType: LineDisplayType.lineSection,
      productUomQty: 0,
      priceUnit: 0,
      discount: 0,
      priceSubtotal: 0,
      priceTax: 0,
      priceTotal: 0,
    );
  }

  /// Create a note line (display_type = 'line_note')
  SaleOrderLine createNoteLine({
    required int orderId,
    required String name,
    int sequence = 0,
  }) {
    return SaleOrderLine(
      id: -DateTime.now().millisecondsSinceEpoch,
      lineUuid: const Uuid().v4(),
      orderId: orderId,
      sequence: sequence,
      name: name,
      displayType: LineDisplayType.lineNote,
      productUomQty: 0,
      priceUnit: 0,
      discount: 0,
      priceSubtotal: 0,
      priceTax: 0,
      priceTotal: 0,
    );
  }

  /// Recalculate an existing line with new values
  ///
  /// Use this when updating quantity, price, or discount on an existing line.
  Future<SaleOrderLine> recalculateLine(
    SaleOrderLine line, {
    double? newQuantity,
    double? newPriceUnit,
    double? newDiscount,
  }) async {
    final quantity = newQuantity ?? line.productUomQty;
    final priceUnit = newPriceUnit ?? line.priceUnit;
    var discount = newDiscount ?? line.discount;

    // Validate discount
    final maxDiscount = await _maxDiscountResolver();
    if (discount > maxDiscount) {
      discount = maxDiscount;
    }

    // Get tax percent
    double taxPercent = 0.0;
    if (line.productId != null) {
      try {
        final taxInfo = await _taxCalculator.getProductTaxInfo(
          productId: line.productId!,
        );
        taxPercent = taxInfo.taxPercent;
      } catch (e) {
        // Use existing tax info if lookup fails
        // Try to infer from existing values
        if (line.priceSubtotal > 0 && line.priceTax > 0) {
          taxPercent = (line.priceTax / line.priceSubtotal) * 100;
        }
      }
    }

    // Calculate new totals
    final calc = saleOrderLineCalculator.calculateLine(
      priceUnit: priceUnit,
      quantity: quantity,
      discountPercent: discount,
      taxPercent: taxPercent,
    );

    return line.copyWith(
      productUomQty: quantity,
      priceUnit: priceUnit,
      discount: discount,
      priceSubtotal: calc.priceSubtotal,
      priceTax: calc.priceTax,
      priceTotal: calc.priceTotal,
    );
  }
}
