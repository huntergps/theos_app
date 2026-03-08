import 'package:theos_pos_core/theos_pos_core.dart' show SaleOrderLine;

import '../../../core/services/logger_service.dart';
import 'order_line_creation_service.dart';
import 'line_calculator.dart';

/// Result of a line operation
class LineOperationResult {
  final bool success;
  final List<SaleOrderLine> lines;
  final int? selectedIndex;
  final String? error;

  const LineOperationResult._({
    required this.success,
    required this.lines,
    this.selectedIndex,
    this.error,
  });

  factory LineOperationResult.success(
    List<SaleOrderLine> lines, {
    int? selectedIndex,
  }) =>
      LineOperationResult._(
        success: true,
        lines: lines,
        selectedIndex: selectedIndex,
      );

  factory LineOperationResult.error(String error, List<SaleOrderLine> lines) =>
      LineOperationResult._(
        success: false,
        lines: lines,
        error: error,
      );

  factory LineOperationResult.noChange(List<SaleOrderLine> lines) =>
      LineOperationResult._(
        success: true,
        lines: lines,
      );
}

/// Shared helper for line operations
///
/// This class provides stateless line manipulation operations that can be used
/// by both [FastSaleNotifier] (multi-tab) and [SaleOrderFormNotifier] (single order).
///
/// Unlike mixins, this helper doesn't require specific state structure and returns
/// the modified lines list for the caller to manage.
///
/// Usage:
/// ```dart
/// final helper = ref.read(lineOperationsHelperProvider('[MyTag]'));
/// final result = await helper.addProductLine(
///   lines: currentLines,
///   orderId: orderId,
///   productId: productId,
///   productName: 'Product',
/// );
/// if (result.success) {
///   state = state.copyWith(lines: result.lines);
/// }
/// ```
class LineOperationsHelper {
  final OrderLineCreationService _creationService;
  final String logTag;

  LineOperationsHelper(this._creationService, {this.logTag = '[LineOps]'});

  // ========== Add Line Operations ==========

  /// Add a new product line
  ///
  /// Returns updated lines list with the new line appended
  Future<LineOperationResult> addProductLine({
    required List<SaleOrderLine> lines,
    required int orderId,
    required int productId,
    required String productName,
    int? pricelistId,
    double quantity = 1.0,
    double? priceUnit,
    double? discount,
    int? uomId,
    String? uomName,
    String? productCode,
    String? taxIds,
    String? taxNames,
    double? taxPercent,
    bool mergeIfExists = true,
  }) async {
    logger.d(logTag, 'Adding product line: $productName (id=$productId)');

    try {
      final creationService = _creationService;
      final result = await creationService.createLine(
        orderId: orderId,
        productId: productId,
        productName: productName,
        quantity: quantity,
        pricelistId: pricelistId,
        priceUnit: priceUnit,
        discount: discount,
        uomId: uomId,
        uomName: uomName,
        productCode: productCode,
        taxIds: taxIds,
        taxNames: taxNames,
        taxPercent: taxPercent,
        sequence: _getNextSequence(lines),
      );

      if (!result.success || result.line == null) {
        logger.w(logTag, 'Failed to create line: ${result.error}');
        return LineOperationResult.error(
          result.error ?? 'Error creating line',
          lines,
        );
      }

      final newLine = result.line!;

      // Check if we should merge with existing line
      if (mergeIfExists) {
        final mergedIndex = _findMergeableLine(
          lines,
          productId,
          uomId ?? newLine.productUomId,
        );
        if (mergedIndex >= 0) {
          return await updateLineQuantity(
            lines: lines,
            index: mergedIndex,
            newQuantity: lines[mergedIndex].productUomQty + quantity,
            selectedIndex: mergedIndex,
          );
        }
      }

      // Add as new line
      final newLines = List<SaleOrderLine>.from(lines)..add(newLine);
      logger.i(logTag, 'Line added: ${newLine.productName}');

      return LineOperationResult.success(
        newLines,
        selectedIndex: newLines.length - 1,
      );
    } catch (e, stack) {
      logger.e(logTag, 'Error adding line', e, stack);
      return LineOperationResult.error('Error adding line: $e', lines);
    }
  }

  /// Add a section line
  LineOperationResult addSectionLine({
    required List<SaleOrderLine> lines,
    required int orderId,
    required String name,
  }) {
    final creationService = _creationService;
    final section = creationService.createSectionLine(
      orderId: orderId,
      name: name,
      sequence: _getNextSequence(lines),
    );

    final newLines = List<SaleOrderLine>.from(lines)..add(section);
    return LineOperationResult.success(newLines);
  }

  /// Add a note line
  LineOperationResult addNoteLine({
    required List<SaleOrderLine> lines,
    required int orderId,
    required String name,
  }) {
    final creationService = _creationService;
    final note = creationService.createNoteLine(
      orderId: orderId,
      name: name,
      sequence: _getNextSequence(lines),
    );

    final newLines = List<SaleOrderLine>.from(lines)..add(note);
    return LineOperationResult.success(newLines);
  }

  // ========== Update Line Operations ==========

  /// Update quantity for a line
  Future<LineOperationResult> updateLineQuantity({
    required List<SaleOrderLine> lines,
    required int index,
    required double newQuantity,
    int? selectedIndex,
  }) async {
    if (index < 0 || index >= lines.length) {
      return LineOperationResult.error('Invalid line index', lines);
    }
    if (newQuantity <= 0) {
      return LineOperationResult.error('Invalid quantity', lines);
    }

    final line = lines[index];
    logger.d(logTag, 'Updating quantity: ${line.productUomQty} -> $newQuantity');

    final creationService = _creationService;
    final updatedLine = await creationService.recalculateLine(
      line,
      newQuantity: newQuantity,
    );

    final newLines = List<SaleOrderLine>.from(lines);
    newLines[index] = updatedLine;

    return LineOperationResult.success(newLines, selectedIndex: selectedIndex);
  }

  /// Update price for a line
  Future<LineOperationResult> updateLinePrice({
    required List<SaleOrderLine> lines,
    required int index,
    required double newPrice,
  }) async {
    if (index < 0 || index >= lines.length) {
      return LineOperationResult.error('Invalid line index', lines);
    }

    final line = lines[index];
    logger.d(logTag, 'Updating price: ${line.priceUnit} -> $newPrice');

    final creationService = _creationService;
    final updatedLine = await creationService.recalculateLine(
      line,
      newPriceUnit: newPrice,
    );

    final newLines = List<SaleOrderLine>.from(lines);
    newLines[index] = updatedLine;

    return LineOperationResult.success(newLines);
  }

  /// Update discount for a line
  Future<LineOperationResult> updateLineDiscount({
    required List<SaleOrderLine> lines,
    required int index,
    required double newDiscount,
  }) async {
    if (index < 0 || index >= lines.length) {
      return LineOperationResult.error('Invalid line index', lines);
    }

    final line = lines[index];
    logger.d(logTag, 'Updating discount: ${line.discount} -> $newDiscount');

    final creationService = _creationService;
    final updatedLine = await creationService.recalculateLine(
      line,
      newDiscount: newDiscount,
    );

    final newLines = List<SaleOrderLine>.from(lines);
    newLines[index] = updatedLine;

    return LineOperationResult.success(newLines);
  }

  /// Update UoM for a line
  LineOperationResult updateLineUom({
    required List<SaleOrderLine> lines,
    required int index,
    required int newUomId,
    required String newUomName,
    double? newPrice,
  }) {
    if (index < 0 || index >= lines.length) {
      return LineOperationResult.error('Invalid line index', lines);
    }

    final line = lines[index];
    logger.d(logTag, 'Updating UoM: ${line.productUomId} -> $newUomId');

    final price = newPrice ?? line.priceUnit;
    final calc = saleOrderLineCalculator.calculateLine(
      priceUnit: price,
      quantity: line.productUomQty,
      discountPercent: line.discount,
      taxPercent: _getTaxPercentFromLine(line),
    );

    final updatedLine = line.copyWith(
      productUomId: newUomId,
      productUomName: newUomName,
      priceUnit: price,
      priceSubtotal: calc.priceSubtotal,
      priceTax: calc.priceTax,
      priceTotal: calc.priceTotal,
    );

    final newLines = List<SaleOrderLine>.from(lines);
    newLines[index] = updatedLine;

    return LineOperationResult.success(newLines);
  }

  /// Update description for a line
  LineOperationResult updateLineDescription({
    required List<SaleOrderLine> lines,
    required int index,
    required String newDescription,
  }) {
    if (index < 0 || index >= lines.length) {
      return LineOperationResult.error('Invalid line index', lines);
    }

    final line = lines[index];
    if (newDescription == line.name) {
      return LineOperationResult.noChange(lines);
    }

    final updatedLine = line.copyWith(name: newDescription);
    final newLines = List<SaleOrderLine>.from(lines);
    newLines[index] = updatedLine;

    return LineOperationResult.success(newLines);
  }

  // ========== Remove Line Operations ==========

  /// Remove a line by index
  LineOperationResult removeLine({
    required List<SaleOrderLine> lines,
    required int index,
    int? currentSelectedIndex,
  }) {
    if (index < 0 || index >= lines.length) {
      return LineOperationResult.error('Invalid line index', lines);
    }

    final newLines = List<SaleOrderLine>.from(lines);
    newLines.removeAt(index);

    // Calculate new selected index
    int? newSelectedIndex;
    if (currentSelectedIndex != null) {
      if (currentSelectedIndex >= newLines.length) {
        newSelectedIndex = newLines.isEmpty ? null : newLines.length - 1;
      } else {
        newSelectedIndex = currentSelectedIndex;
      }
    }

    return LineOperationResult.success(newLines, selectedIndex: newSelectedIndex);
  }

  /// Clear all lines
  LineOperationResult clearAllLines() {
    return LineOperationResult.success([], selectedIndex: null);
  }

  // ========== Increment/Decrement Operations ==========

  /// Increment quantity by step
  Future<LineOperationResult> incrementLineQuantity({
    required List<SaleOrderLine> lines,
    required int index,
  }) async {
    if (index < 0 || index >= lines.length) {
      return LineOperationResult.error('Invalid line index', lines);
    }

    final line = lines[index];
    final increment = line.isUnitProduct ? 0.5 : 1.0;
    return updateLineQuantity(
      lines: lines,
      index: index,
      newQuantity: line.productUomQty + increment,
    );
  }

  /// Decrement quantity by step (with minimum)
  Future<LineOperationResult> decrementLineQuantity({
    required List<SaleOrderLine> lines,
    required int index,
  }) async {
    if (index < 0 || index >= lines.length) {
      return LineOperationResult.error('Invalid line index', lines);
    }

    final line = lines[index];
    final decrement = line.isUnitProduct ? 0.5 : 1.0;
    final minQty = line.isUnitProduct ? 0.5 : 1.0;
    final newQty = (line.productUomQty - decrement).clamp(minQty, double.infinity);

    if (newQty == line.productUomQty) {
      return LineOperationResult.noChange(lines);
    }

    return updateLineQuantity(
      lines: lines,
      index: index,
      newQuantity: newQty,
    );
  }

  // ========== Reorder Operations ==========

  /// Move a line from one position to another
  LineOperationResult reorderLine({
    required List<SaleOrderLine> lines,
    required int oldIndex,
    required int newIndex,
    int? currentSelectedIndex,
  }) {
    if (oldIndex < 0 || oldIndex >= lines.length) {
      return LineOperationResult.error('Invalid old index', lines);
    }
    if (newIndex < 0 || newIndex >= lines.length) {
      return LineOperationResult.error('Invalid new index', lines);
    }
    if (oldIndex == newIndex) {
      return LineOperationResult.noChange(lines);
    }

    final newLines = List<SaleOrderLine>.from(lines);
    final line = newLines.removeAt(oldIndex);
    newLines.insert(newIndex, line);

    // Update sequences
    for (int i = 0; i < newLines.length; i++) {
      newLines[i] = newLines[i].copyWith(sequence: (i + 1) * 10);
    }

    // Calculate new selected index
    int? newSelectedIndex = currentSelectedIndex;
    if (currentSelectedIndex == oldIndex) {
      newSelectedIndex = newIndex;
    }

    return LineOperationResult.success(newLines, selectedIndex: newSelectedIndex);
  }

  // ========== Computed Properties ==========

  /// Calculate subtotal from all product lines
  double calculateSubtotal(List<SaleOrderLine> lines) {
    return lines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceSubtotal);
  }

  /// Calculate tax total from all product lines
  double calculateTaxTotal(List<SaleOrderLine> lines) {
    return lines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceTax);
  }

  /// Calculate grand total from all product lines
  double calculateTotal(List<SaleOrderLine> lines) {
    return lines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceTotal);
  }

  /// Count product lines (excluding sections/notes)
  int countProductLines(List<SaleOrderLine> lines) {
    return lines.where((l) => l.isProductLine).length;
  }

  // ========== Helper Methods ==========

  int _getNextSequence(List<SaleOrderLine> lines) {
    if (lines.isEmpty) return 10;
    final maxSeq = lines.map((l) => l.sequence).reduce((a, b) => a > b ? a : b);
    return maxSeq + 10;
  }

  int _findMergeableLine(List<SaleOrderLine> lines, int productId, int? uomId) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.productId == productId &&
          line.productUomId == uomId &&
          line.isProductLine) {
        return i;
      }
    }
    return -1;
  }

  double _getTaxPercentFromLine(SaleOrderLine line) {
    if (line.priceSubtotal > 0 && line.priceTax > 0) {
      return (line.priceTax / line.priceSubtotal) * 100;
    }
    return 0.0;
  }
}

// Provider moved to providers/service_providers.dart
