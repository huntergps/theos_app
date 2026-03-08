import 'package:theos_pos_core/theos_pos_core.dart' show SaleOrderLine;

import '../../../core/services/logger_service.dart';
import '../../prices/prices.dart';
import '../../taxes/taxes.dart';

/// Service for managing sale order lines
///
/// Provides reusable logic for:
/// - Creating lines with calculated prices
/// - Updating line quantities, prices, discounts
/// - Managing line collections (add, update, delete, visibility)
///
/// This service is stateless and can be used by multiple providers.
class SaleOrderLineService {
  final TaxCalculatorService _taxCalculator;
  final PricelistCalculatorService _pricelistCalculator;

  SaleOrderLineService({
    required TaxCalculatorService taxCalculator,
    required PricelistCalculatorService pricelistCalculator,
  })  : _taxCalculator = taxCalculator,
        _pricelistCalculator = pricelistCalculator;

  /// Create a new line with calculated prices
  ///
  /// [productId] - Product ID
  /// [productName] - Product display name
  /// [productCode] - Product internal reference
  /// [productTmplId] - Product template ID
  /// [quantity] - Quantity
  /// [priceUnit] - Unit price (if null, calculated from pricelist)
  /// [discount] - Discount percentage
  /// [uomId] - Unit of measure ID
  /// [uomName] - Unit of measure name
  /// [pricelistId] - Pricelist ID for price calculation
  /// [orderId] - Order ID (0 for new orders)
  /// [sequence] - Line sequence
  /// [fiscalPositionId] - Fiscal position for tax mapping
  Future<SaleOrderLine> createLine({
    required int productId,
    required String productName,
    String? productCode,
    int? productTmplId,
    double quantity = 1.0,
    double? priceUnit,
    double discount = 0.0,
    int? uomId,
    String? uomName,
    int? pricelistId,
    int orderId = 0,
    int sequence = 10,
    int? fiscalPositionId,
  }) async {
    logger.d(
      '[SaleOrderLineService]',
      'Creating line: $productName (qty: $quantity, price: $priceUnit)',
    );

    // Calculate price from pricelist if not provided
    double effectivePrice = priceUnit ?? 0.0;
    if (priceUnit == null && pricelistId != null && productTmplId != null) {
      final priceResult = await _pricelistCalculator.calculatePrice(
        productId: productId,
        productTmplId: productTmplId,
        pricelistId: pricelistId,
        quantity: quantity,
        uomId: uomId,
        productUomId: uomId,
        listPrice: 0, // Will be looked up from DB
      );
      effectivePrice = priceResult.price;
    }

    // Get tax info for product
    final taxInfo = await _taxCalculator.getProductTaxInfo(
      productId: productId,
      productTmplId: productTmplId,
      fiscalPositionId: fiscalPositionId,
    );

    // Calculate line amounts
    final amounts = _taxCalculator.calculateLineAmounts(
      priceUnit: effectivePrice,
      quantity: quantity,
      discount: discount,
      taxes: taxInfo.taxes,
    );

    // Calculate price with discount (priceReduce)
    final priceReduce = effectivePrice * (1 - discount / 100);

    return SaleOrderLine(
      id: 0, // Will be assigned by caller
      orderId: orderId,
      sequence: sequence,
      productId: productId,
      productName: productName,
      productCode: productCode,
      name: productName,
      productUomQty: quantity,
      productUomId: uomId,
      productUomName: uomName ?? 'Unidades',
      priceUnit: effectivePrice,
      discount: discount,
      priceSubtotal: amounts.priceSubtotal,
      priceTax: amounts.priceTax,
      priceTotal: amounts.priceTotal,
      priceReduce: priceReduce,
      taxIds: taxInfo.taxIds,
      taxNames: taxInfo.taxNames,
    );
  }

  /// Recalculate line amounts after changes
  ///
  /// Call this after modifying quantity, price, or discount
  Future<SaleOrderLine> recalculateLine(
    SaleOrderLine line, {
    int? fiscalPositionId,
  }) async {
    // Get tax info for product
    TaxInfo taxInfo;
    if (line.productId != null) {
      taxInfo = await _taxCalculator.getProductTaxInfo(
        productId: line.productId!,
        fiscalPositionId: fiscalPositionId,
      );
    } else {
      taxInfo = TaxInfo.empty();
    }

    // Calculate line amounts
    final amounts = _taxCalculator.calculateLineAmounts(
      priceUnit: line.priceUnit,
      quantity: line.productUomQty,
      discount: line.discount,
      taxes: taxInfo.taxes,
    );

    // Calculate price with discount (priceReduce)
    final priceReduce = line.priceUnit * (1 - line.discount / 100);

    return line.copyWith(
      priceSubtotal: amounts.priceSubtotal,
      priceTax: amounts.priceTax,
      priceTotal: amounts.priceTotal,
      priceReduce: priceReduce,
      taxIds: taxInfo.taxIds.isNotEmpty ? taxInfo.taxIds : line.taxIds,
      taxNames: taxInfo.taxNames.isNotEmpty ? taxInfo.taxNames : line.taxNames,
    );
  }

  /// Update line quantity and recalculate
  Future<SaleOrderLine> updateQuantity(
    SaleOrderLine line,
    double quantity, {
    int? fiscalPositionId,
  }) async {
    final updated = line.copyWith(productUomQty: quantity);
    return recalculateLine(updated, fiscalPositionId: fiscalPositionId);
  }

  /// Update line price and recalculate
  Future<SaleOrderLine> updatePrice(
    SaleOrderLine line,
    double priceUnit, {
    int? fiscalPositionId,
  }) async {
    final updated = line.copyWith(priceUnit: priceUnit);
    return recalculateLine(updated, fiscalPositionId: fiscalPositionId);
  }

  /// Update line discount and recalculate
  Future<SaleOrderLine> updateDiscount(
    SaleOrderLine line,
    double discount, {
    int? fiscalPositionId,
  }) async {
    final updated = line.copyWith(discount: discount.clamp(0, 100));
    return recalculateLine(updated, fiscalPositionId: fiscalPositionId);
  }

  /// Update line UoM and recalculate price
  Future<SaleOrderLine> updateUom(
    SaleOrderLine line, {
    required int newUomId,
    required String newUomName,
    required double newPrice,
    int? fiscalPositionId,
  }) async {
    final updated = line.copyWith(
      productUomId: newUomId,
      productUomName: newUomName,
      priceUnit: newPrice,
    );
    return recalculateLine(updated, fiscalPositionId: fiscalPositionId);
  }
}

/// State interface for line collections
///
/// Implement this to use [SaleOrderLineCollectionService]
abstract class LineCollectionState {
  /// Original lines (from database)
  List<SaleOrderLine> get lines;

  /// New lines added in current session
  List<SaleOrderLine> get newLines;

  /// Lines that have been updated
  List<SaleOrderLine> get updatedLines;

  /// IDs of lines marked for deletion
  List<int> get deletedLineIds;
}

/// Service for managing collections of lines
///
/// Provides pure functions for line collection operations.
/// Does not maintain state - returns new collections.
class SaleOrderLineCollectionService {
  const SaleOrderLineCollectionService();

  /// Generate a temporary ID for new lines
  int generateTempId(int existingNewLinesCount) {
    return -(existingNewLinesCount + 1);
  }

  /// Add a line to the new lines collection
  ///
  /// Returns updated newLines list
  List<SaleOrderLine> addLine(
    List<SaleOrderLine> currentNewLines,
    SaleOrderLine line, {
    required int orderId,
    required int totalLinesCount,
  }) {
    final tempId = generateTempId(currentNewLines.length);
    final lineWithTempId = line.copyWith(
      id: tempId,
      orderId: orderId,
      sequence: (totalLinesCount + 1) * 10,
    );

    logger.d(
      '[LineCollectionService]',
      'Added line: ${lineWithTempId.productName} (ID: $tempId)',
    );

    return [...currentNewLines, lineWithTempId];
  }

  /// Update a line in the appropriate collection
  ///
  /// Returns a record with updated newLines and updatedLines
  ({List<SaleOrderLine> newLines, List<SaleOrderLine> updatedLines}) updateLine(
    List<SaleOrderLine> currentNewLines,
    List<SaleOrderLine> currentUpdatedLines,
    SaleOrderLine updatedLine,
  ) {
    // Check if line is in newLines
    final isInNewLines = currentNewLines.any((l) => l.id == updatedLine.id);

    if (isInNewLines) {
      // Update in newLines
      final newLinesList = currentNewLines.map((l) {
        return l.id == updatedLine.id ? updatedLine : l;
      }).toList();

      logger.d(
        '[LineCollectionService]',
        'Updated in newLines: ID=${updatedLine.id}',
      );

      return (newLines: newLinesList, updatedLines: currentUpdatedLines);
    } else {
      // Update in updatedLines
      final existingIndex = currentUpdatedLines.indexWhere(
        (l) => l.id == updatedLine.id,
      );

      List<SaleOrderLine> newUpdatedLines;
      if (existingIndex >= 0) {
        newUpdatedLines = List<SaleOrderLine>.from(currentUpdatedLines);
        newUpdatedLines[existingIndex] = updatedLine;
      } else {
        newUpdatedLines = [...currentUpdatedLines, updatedLine];
      }

      logger.d(
        '[LineCollectionService]',
        'Updated in updatedLines: ID=${updatedLine.id}',
      );

      return (newLines: currentNewLines, updatedLines: newUpdatedLines);
    }
  }

  /// Delete a line from the collections
  ///
  /// Returns a record with updated collections
  ({
    List<SaleOrderLine> newLines,
    List<SaleOrderLine> updatedLines,
    List<int> deletedLineIds,
  }) deleteLine(
    List<SaleOrderLine> currentNewLines,
    List<SaleOrderLine> currentUpdatedLines,
    List<int> currentDeletedIds,
    int lineId,
  ) {
    // Check if line is in newLines
    final isInNewLines = currentNewLines.any((l) => l.id == lineId);

    if (isInNewLines) {
      // Remove from newLines
      logger.d('[LineCollectionService]', 'Removed from newLines: ID=$lineId');
      return (
        newLines: currentNewLines.where((l) => l.id != lineId).toList(),
        updatedLines: currentUpdatedLines,
        deletedLineIds: currentDeletedIds,
      );
    } else {
      // Mark for deletion
      if (currentDeletedIds.contains(lineId)) {
        return (
          newLines: currentNewLines,
          updatedLines: currentUpdatedLines,
          deletedLineIds: currentDeletedIds,
        );
      }

      logger.d('[LineCollectionService]', 'Marked for deletion: ID=$lineId');
      return (
        newLines: currentNewLines,
        updatedLines: currentUpdatedLines.where((l) => l.id != lineId).toList(),
        deletedLineIds: [...currentDeletedIds, lineId],
      );
    }
  }

  /// Get all visible lines (not deleted, with updates applied)
  List<SaleOrderLine> getVisibleLines(
    List<SaleOrderLine> originalLines,
    List<SaleOrderLine> newLines,
    List<SaleOrderLine> updatedLines,
    List<int> deletedLineIds,
  ) {
    final result = <SaleOrderLine>[];

    // Original lines not deleted (with updates applied)
    for (final line in originalLines) {
      if (deletedLineIds.contains(line.id)) continue;

      final updated = updatedLines.firstWhere(
        (l) => l.id == line.id,
        orElse: () => line,
      );
      result.add(updated);
    }

    // Add new lines
    result.addAll(newLines);

    // Sort by sequence
    result.sort((a, b) => a.sequence.compareTo(b.sequence));

    return result;
  }

  /// Get only product lines (exclude sections, notes)
  List<SaleOrderLine> getProductLines(List<SaleOrderLine> visibleLines) {
    return visibleLines.where((l) => l.isProductLine).toList();
  }

  /// Find a line by ID across all collections
  SaleOrderLine? findLine(
    List<SaleOrderLine> originalLines,
    List<SaleOrderLine> newLines,
    List<SaleOrderLine> updatedLines,
    int lineId,
  ) {
    // Check newLines first
    try {
      return newLines.firstWhere((l) => l.id == lineId);
    } catch (_) {}

    // Check updatedLines
    try {
      return updatedLines.firstWhere((l) => l.id == lineId);
    } catch (_) {}

    // Check original lines
    try {
      return originalLines.firstWhere((l) => l.id == lineId);
    } catch (_) {}

    return null;
  }

  /// Find a line by product ID
  SaleOrderLine? findLineByProduct(
    List<SaleOrderLine> visibleLines,
    int productId,
  ) {
    try {
      return visibleLines.firstWhere((l) => l.productId == productId);
    } catch (_) {
      return null;
    }
  }

  /// Check if a product already exists in the lines
  bool hasProduct(List<SaleOrderLine> visibleLines, int productId) {
    return visibleLines.any((l) => l.productId == productId);
  }
}
