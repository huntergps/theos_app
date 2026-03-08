import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/repository_providers.dart'
    show salesRepositoryProvider;
import '../repositories/sales_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'service_providers.dart' show orderLineCreationServiceProvider;

/// Mixin providing shared line operations for order notifiers
///
/// This mixin consolidates common line manipulation logic used by both
/// [FastSaleNotifier] and [SaleOrderFormNotifier].
///
/// Features:
/// - Add/remove/update lines
/// - Quantity increment/decrement
/// - UoM changes with price recalculation
/// - Line reordering
/// - Merge duplicate lines (for POS)
///
/// Usage:
/// ```dart
/// class MyOrderNotifier extends Notifier<MyOrderState>
///     with OrderLinesController<MyOrderState> {
///   @override
///   String get logTag => '[MyOrder]';
///
///   @override
///   List<SaleOrderLine> get currentLines => state.lines;
///
///   @override
///   void updateStateLines(List<SaleOrderLine> lines) {
///     state = state.copyWith(lines: lines);
///   }
/// }
/// ```
mixin OrderLinesController<T> on Notifier<T> {
  /// Tag for logging (override in subclass)
  String get logTag => '[OrderLines]';

  /// Get current order ID from state (override in subclass)
  int get currentOrderId;

  /// Get current pricelist ID from state (override in subclass)
  int? get currentPricelistId;

  /// Get current lines from state (override in subclass)
  List<SaleOrderLine> get currentLines;

  /// Update lines in state (override in subclass)
  void updateStateLines(List<SaleOrderLine> lines);

  /// Mark state as having changes (override in subclass)
  void markHasChanges();

  /// Increment lines version for WebSocket updates (override in subclass)
  void incrementLinesVersion();

  /// Get selected line index (override in subclass)
  int get selectedLineIndex => -1;

  /// Update selected line index (override in subclass)
  void updateSelectedLineIndex(int index) {}

  // ========== Add Line Operations ==========

  /// Add a new product line using the OrderLineCreationService
  ///
  /// Returns the created line or null if failed
  Future<SaleOrderLine?> addProductLine({
    required int productId,
    required String productName,
    double quantity = 1.0,
    double? priceUnit,
    double? discount,
    int? uomId,
    String? uomName,
    String? productCode,
    String? taxIds,
    String? taxNames,
    double? taxPercent,
  }) async {
    logger.d(logTag, 'Adding product line: $productName (id=$productId)');

    try {
      final creationService = ref.read(orderLineCreationServiceProvider);
      final result = await creationService.createLine(
        orderId: currentOrderId,
        productId: productId,
        productName: productName,
        quantity: quantity,
        pricelistId: currentPricelistId,
        priceUnit: priceUnit,
        discount: discount,
        uomId: uomId,
        uomName: uomName,
        productCode: productCode,
        taxIds: taxIds,
        taxNames: taxNames,
        taxPercent: taxPercent,
        sequence: _getNextSequence(),
      );

      if (!result.success || result.line == null) {
        logger.w(logTag, 'Failed to create line: ${result.error}');
        return null;
      }

      final newLine = result.line!;

      // Check if we should merge with existing line
      final mergedIndex = _findMergeableLine(productId, uomId ?? newLine.productUomId);
      if (mergedIndex >= 0) {
        await _mergeWithExistingLine(mergedIndex, quantity);
        return currentLines[mergedIndex];
      }

      // Add as new line
      final newLines = List<SaleOrderLine>.from(currentLines)..add(newLine);
      updateStateLines(newLines);
      markHasChanges();
      incrementLinesVersion();

      // Select the new line
      updateSelectedLineIndex(newLines.length - 1);

      logger.i(logTag, 'Line added: ${newLine.productName} (index=${newLines.length - 1})');
      return newLine;
    } catch (e, stack) {
      logger.e(logTag, 'Error adding line', e, stack);
      return null;
    }
  }

  /// Add a section line
  SaleOrderLine addSectionLine(String name) {
    final creationService = ref.read(orderLineCreationServiceProvider);
    final section = creationService.createSectionLine(
      orderId: currentOrderId,
      name: name,
      sequence: _getNextSequence(),
    );

    final newLines = List<SaleOrderLine>.from(currentLines)..add(section);
    updateStateLines(newLines);
    markHasChanges();
    incrementLinesVersion();

    return section;
  }

  /// Add a note line
  SaleOrderLine addNoteLine(String name) {
    final creationService = ref.read(orderLineCreationServiceProvider);
    final note = creationService.createNoteLine(
      orderId: currentOrderId,
      name: name,
      sequence: _getNextSequence(),
    );

    final newLines = List<SaleOrderLine>.from(currentLines)..add(note);
    updateStateLines(newLines);
    markHasChanges();
    incrementLinesVersion();

    return note;
  }

  // ========== Remove Line Operations ==========

  /// Remove a line by index
  ///
  /// Returns true if the line was successfully removed
  Future<bool> removeLine(int index) async {
    if (index < 0 || index >= currentLines.length) {
      logger.w(logTag, 'Invalid line index: $index');
      return false;
    }

    final line = currentLines[index];
    logger.d(logTag, 'Removing line at index $index: ${line.productName}');

    // If line is synced to Odoo, delete from server
    if (line.id > 0) {
      try {
        final salesRepo = ref.read(salesRepositoryProvider);
        if (salesRepo != null) {
          final success = await salesRepo.deleteLine(line.id);
          if (!success) {
            logger.w(logTag, 'Failed to delete line from Odoo');
            // Continue with local deletion
          }
        }
      } catch (e) {
        logger.w(logTag, 'Error deleting line from Odoo: $e');
        // Continue with local deletion
      }
    }

    final newLines = List<SaleOrderLine>.from(currentLines);
    newLines.removeAt(index);
    updateStateLines(newLines);
    markHasChanges();
    incrementLinesVersion();

    // Update selection
    if (selectedLineIndex >= newLines.length) {
      updateSelectedLineIndex(newLines.isEmpty ? -1 : newLines.length - 1);
    }

    logger.i(logTag, 'Line removed at index $index');
    return true;
  }

  /// Remove all lines
  void clearAllLines() {
    logger.d(logTag, 'Clearing all lines');
    updateStateLines([]);
    updateSelectedLineIndex(-1);
    markHasChanges();
    incrementLinesVersion();
  }

  // ========== Update Line Operations ==========

  /// Update quantity for a line
  ///
  /// Recalculates totals after update
  Future<void> updateLineQuantity(int index, double newQuantity) async {
    if (index < 0 || index >= currentLines.length) return;
    if (newQuantity <= 0) return;

    final line = currentLines[index];
    logger.d(logTag, 'Updating quantity: ${line.productUomQty} -> $newQuantity');

    final creationService = ref.read(orderLineCreationServiceProvider);
    final updatedLine = await creationService.recalculateLine(
      line,
      newQuantity: newQuantity,
    );

    final newLines = List<SaleOrderLine>.from(currentLines);
    newLines[index] = updatedLine;
    updateStateLines(newLines);
    markHasChanges();
    incrementLinesVersion();

    logger.d(logTag, 'Quantity updated at index $index');
  }

  /// Increment quantity by 1 (or 0.5 for unit products)
  Future<void> incrementLineQuantity(int index) async {
    if (index < 0 || index >= currentLines.length) return;

    final line = currentLines[index];
    final increment = line.isUnitProduct ? 0.5 : 1.0;
    await updateLineQuantity(index, line.productUomQty + increment);
  }

  /// Decrement quantity by 1 (or 0.5 for unit products)
  ///
  /// Will not go below minimum quantity (0.5 for unit products, 1.0 otherwise)
  Future<void> decrementLineQuantity(int index) async {
    if (index < 0 || index >= currentLines.length) return;

    final line = currentLines[index];
    final decrement = line.isUnitProduct ? 0.5 : 1.0;
    final minQty = line.isUnitProduct ? 0.5 : 1.0;
    final newQty = (line.productUomQty - decrement).clamp(minQty, double.infinity);

    if (newQty != line.productUomQty) {
      await updateLineQuantity(index, newQty);
    }
  }

  /// Update price for a line
  Future<void> updateLinePrice(int index, double newPrice) async {
    if (index < 0 || index >= currentLines.length) return;

    final line = currentLines[index];
    logger.d(logTag, 'Updating price: ${line.priceUnit} -> $newPrice');

    final creationService = ref.read(orderLineCreationServiceProvider);
    final updatedLine = await creationService.recalculateLine(
      line,
      newPriceUnit: newPrice,
    );

    final newLines = List<SaleOrderLine>.from(currentLines);
    newLines[index] = updatedLine;
    updateStateLines(newLines);
    markHasChanges();
    incrementLinesVersion();
  }

  /// Update discount for a line
  Future<void> updateLineDiscount(int index, double newDiscount) async {
    if (index < 0 || index >= currentLines.length) return;

    final line = currentLines[index];
    logger.d(logTag, 'Updating discount: ${line.discount} -> $newDiscount');

    final creationService = ref.read(orderLineCreationServiceProvider);
    final updatedLine = await creationService.recalculateLine(
      line,
      newDiscount: newDiscount,
    );

    final newLines = List<SaleOrderLine>.from(currentLines);
    newLines[index] = updatedLine;
    updateStateLines(newLines);
    markHasChanges();
    incrementLinesVersion();
  }

  /// Update UoM for a line (with price recalculation)
  Future<void> updateLineUom(
    int index,
    int newUomId,
    String newUomName, {
    double? dialogPrice,
  }) async {
    if (index < 0 || index >= currentLines.length) return;

    final line = currentLines[index];
    logger.d(logTag, 'Updating UoM: ${line.productUomId} -> $newUomId');

    // Calculate new price based on UoM ratio if no dialog price provided
    double newPrice = dialogPrice ?? line.priceUnit;

    // Recalculate line with new price
    final calc = saleOrderLineCalculator.calculateLine(
      priceUnit: newPrice,
      quantity: line.productUomQty,
      discountPercent: line.discount,
      taxPercent: _getTaxPercentFromLine(line),
    );

    final updatedLine = line.copyWith(
      productUomId: newUomId,
      productUomName: newUomName,
      priceUnit: newPrice,
      priceSubtotal: calc.priceSubtotal,
      priceTax: calc.priceTax,
      priceTotal: calc.priceTotal,
    );

    final newLines = List<SaleOrderLine>.from(currentLines);
    newLines[index] = updatedLine;
    updateStateLines(newLines);
    markHasChanges();
    incrementLinesVersion();

    logger.d(logTag, 'UoM updated at index $index');
  }

  /// Update description for a line
  void updateLineDescription(int index, String newDescription) {
    if (index < 0 || index >= currentLines.length) return;

    final line = currentLines[index];
    if (newDescription == line.name) return;

    logger.d(logTag, 'Updating description at index $index');

    final updatedLine = line.copyWith(name: newDescription);
    final newLines = List<SaleOrderLine>.from(currentLines);
    newLines[index] = updatedLine;
    updateStateLines(newLines);
    markHasChanges();
  }

  // ========== Selection Operations ==========

  /// Select a line by index
  void selectLine(int index) {
    if (index < -1 || index >= currentLines.length) return;
    updateSelectedLineIndex(index);
  }

  /// Get the currently selected line or null
  SaleOrderLine? get selectedLine {
    if (selectedLineIndex < 0 || selectedLineIndex >= currentLines.length) {
      return null;
    }
    return currentLines[selectedLineIndex];
  }

  // ========== Reorder Operations ==========

  /// Move a line from one position to another
  void reorderLine(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= currentLines.length) return;
    if (newIndex < 0 || newIndex >= currentLines.length) return;
    if (oldIndex == newIndex) return;

    logger.d(logTag, 'Reordering line: $oldIndex -> $newIndex');

    final newLines = List<SaleOrderLine>.from(currentLines);
    final line = newLines.removeAt(oldIndex);
    newLines.insert(newIndex, line);

    // Update sequences
    for (int i = 0; i < newLines.length; i++) {
      newLines[i] = newLines[i].copyWith(sequence: (i + 1) * 10);
    }

    updateStateLines(newLines);
    markHasChanges();
    incrementLinesVersion();

    // Update selection to follow moved line
    if (selectedLineIndex == oldIndex) {
      updateSelectedLineIndex(newIndex);
    }
  }

  // ========== Merge Operations (for POS) ==========

  /// Find a line that can be merged with a new product
  ///
  /// Returns the index of the mergeable line, or -1 if none found
  int _findMergeableLine(int productId, int? uomId) {
    for (int i = 0; i < currentLines.length; i++) {
      final line = currentLines[i];
      if (line.productId == productId &&
          line.productUomId == uomId &&
          line.isProductLine) {
        return i;
      }
    }
    return -1;
  }

  /// Merge quantity with an existing line
  Future<void> _mergeWithExistingLine(int index, double additionalQty) async {
    final line = currentLines[index];
    final newQty = line.productUomQty + additionalQty;

    logger.d(logTag, 'Merging with existing line at index $index: '
        '${line.productUomQty} + $additionalQty = $newQty');

    await updateLineQuantity(index, newQty);
    updateSelectedLineIndex(index);
  }

  // ========== Helper Methods ==========

  int _getNextSequence() {
    if (currentLines.isEmpty) return 10;
    final maxSeq = currentLines.map((l) => l.sequence).reduce((a, b) => a > b ? a : b);
    return maxSeq + 10;
  }

  double _getTaxPercentFromLine(SaleOrderLine line) {
    if (line.priceSubtotal > 0 && line.priceTax > 0) {
      return (line.priceTax / line.priceSubtotal) * 100;
    }
    return 0.0;
  }

  // ========== Computed Properties ==========

  /// Calculate subtotal from all product lines
  double get linesSubtotal {
    return currentLines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceSubtotal);
  }

  /// Calculate tax total from all product lines
  double get linesTaxTotal {
    return currentLines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceTax);
  }

  /// Calculate grand total from all product lines
  double get linesTotal {
    return currentLines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceTotal);
  }

  /// Number of product lines (excluding sections/notes)
  int get productLineCount {
    return currentLines.where((l) => l.isProductLine).length;
  }
}
