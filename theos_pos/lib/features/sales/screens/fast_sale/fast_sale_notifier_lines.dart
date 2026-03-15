// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'fast_sale_providers.dart';

/// Extension on [FastSaleNotifier] for order line management operations.
///
/// Includes: line selection, product search by code/barcode, adding products,
/// quantity/price/discount updates, line deletion, UoM changes, and description editing.
extension FastSaleNotifierLines on FastSaleNotifier {
  // ============================================================
  // LINE MANAGEMENT
  // ============================================================

  /// Select a line in the active tab
  void selectLine(int index) {
    final activeTab = state.activeTab;
    if (activeTab == null) return;

    final updatedTab = activeTab.copyWith(selectedLineIndex: index);
    _updateActiveTab(updatedTab);
  }

  /// Select the next line (arrow down)
  void selectNextLine() {
    final activeTab = state.activeTab;
    if (activeTab == null || activeTab.lines.isEmpty) return;

    final currentIndex = activeTab.selectedLineIndex;
    final newIndex = (currentIndex + 1).clamp(0, activeTab.lines.length - 1);
    if (newIndex != currentIndex) {
      selectLine(newIndex);
    }
  }

  /// Select the previous line (arrow up)
  void selectPreviousLine() {
    final activeTab = state.activeTab;
    if (activeTab == null || activeTab.lines.isEmpty) return;

    final currentIndex = activeTab.selectedLineIndex;
    // If no line selected, select the first one
    if (currentIndex < 0) {
      selectLine(0);
      return;
    }
    final newIndex = (currentIndex - 1).clamp(0, activeTab.lines.length - 1);
    if (newIndex != currentIndex) {
      selectLine(newIndex);
    }
  }

  // ============================================================
  // PRODUCT SEARCH BY CODE (for barcode scanner / keyboard input)
  // ============================================================

  /// Parse code input with optional quantity and discount prefixes
  ///
  /// Supported formats:
  /// - "ACC0117" → qty=1, code="ACC0117", discount=0
  /// - "3+ACC0117" → qty=3, code="ACC0117", discount=0
  /// - "5%+ACC0117" → qty=1, code="ACC0117", discount=5
  /// - "3+5%+ACC0117" → qty=3, code="ACC0117", discount=5
  /// - "3*ACC0117" → qty=3, code="ACC0117" (star as separator)
  ({double quantity, double discount, String code}) _parseCodeInput(
    String input,
  ) {
    final trimmed = input.trim();
    double quantity = 1.0;
    double discount = 0.0;

    // Split by '+' to get parts
    final parts = trimmed.split('+');

    if (parts.isEmpty) {
      return (quantity: 1.0, discount: 0.0, code: trimmed);
    }

    // Last part is always the code
    String code = parts.last.trim();

    // Process preceding parts for quantity and discount
    for (int i = 0; i < parts.length - 1; i++) {
      final part = parts[i].trim();

      if (part.endsWith('%')) {
        // This is a discount (e.g., "5%")
        final discountValue = double.tryParse(part.replaceAll('%', ''));
        if (discountValue != null &&
            discountValue >= 0 &&
            discountValue <= 100) {
          discount = discountValue;
        }
      } else {
        // This is a quantity (e.g., "3")
        final qtyValue = double.tryParse(part);
        if (qtyValue != null && qtyValue > 0) {
          quantity = qtyValue;
        }
      }
    }

    // Also support '*' as quantity separator (e.g., "3*ACC0117")
    if (parts.length == 1 && code.contains('*')) {
      final starParts = code.split('*');
      if (starParts.length == 2) {
        final qtyValue = double.tryParse(starParts[0].trim());
        if (qtyValue != null && qtyValue > 0) {
          quantity = qtyValue;
          code = starParts[1].trim();
        }
      }
    }

    return (quantity: quantity, discount: discount, code: code);
  }

  /// Search product by code/barcode and add to order
  ///
  /// Supports prefixes:
  /// - "3+ACC0117" adds 3 units of product ACC0117
  /// - "5%+ACC0117" adds 1 unit with 5% discount
  /// - "3+5%+ACC0117" adds 3 units with 5% discount
  ///
  /// Returns:
  /// - success: Product found and added (new line or incremented)
  /// - incrementedQuantity: Product existed, quantity was increased
  /// - notFound: No product found with this code
  /// - multipleMatches: Multiple products found, returns list in state
  /// - cancelled: No active order or error
  Future<(ProductSearchAddResult, List<Map<String, dynamic>>?)>
  searchAndAddProductByCode(String input) async {
    final activeTab = state.activeTab;
    if (activeTab == null) {
      return (ProductSearchAddResult.cancelled, null);
    }

    // Parse quantity, discount and code
    final parsed = _parseCodeInput(input);
    final quantity = parsed.quantity;
    final discount = parsed.discount;
    final code = parsed.code;

    if (code.isEmpty) {
      return (ProductSearchAddResult.cancelled, null);
    }

    logger.i(
      '[FastSale] Searching product by code: "$code" (qty: $quantity, discount: $discount%)',
    );

    try {
      // Search local DB via productManager for exact match (case insensitive)
      final lowerCode = code.toLowerCase();
      final searchResults = await productManager.searchProducts(code);
      final exactMatches = searchResults.where((p) =>
          p.defaultCode?.toLowerCase() == lowerCode ||
          p.barcode?.toLowerCase() == lowerCode,
      ).toList();

      logger.d(
        '[FastSale] Found ${exactMatches.length} matches for code: $code',
      );

      if (exactMatches.length == 1) {
        // Exact match found - add to order
        final product = exactMatches.first;

        // Check if product already exists in lines with same UOM
        final existingIndex = activeTab.lines.indexWhere(
          (l) =>
              l.productId == product.id && l.productUomId == product.uomId,
        );

        if (existingIndex >= 0) {
          // Increment quantity on existing line
          final existingLine = activeTab.lines[existingIndex];
          final newQty = existingLine.productUomQty + quantity;
          await _updateLineQuantity(existingIndex, newQty);

          // Apply discount if specified
          if (discount > 0 && discount != existingLine.discount) {
            await _updateLineDiscount(existingIndex, discount);
          }

          selectLine(existingIndex);

          logger.i(
            '[FastSale] Incremented qty: ${product.name} → $newQty (discount: $discount%)',
          );
          return (ProductSearchAddResult.incrementedQuantity, null);
        }

        // Add new line
        await addProduct(
          productId: product.id,
          productName: product.name,
          productCode: product.defaultCode,
          quantity: quantity,
          uomId: product.uomId,
          uomName: product.uomName,
          priceUnit: product.listPrice,
          discount: discount,
          taxIds: product.taxIdsList.isNotEmpty ? product.taxIdsList : null,
        );

        logger.i(
          '[FastSale] Added product: ${product.name} x $quantity (discount: $discount%)',
        );
        return (ProductSearchAddResult.success, null);
      } else if (exactMatches.isEmpty) {
        // No matches found
        logger.i('[FastSale] No product found for code: $code');
        return (ProductSearchAddResult.notFound, null);
      } else {
        // Multiple matches - return list for dialog selection
        logger.i(
          '[FastSale] Multiple matches (${exactMatches.length}) for code: $code',
        );

        final matchesList = exactMatches
            .map(
              (p) => <String, dynamic>{
                'id': p.id,
                'name': p.name,
                'display_name': p.displayName,
                'default_code': p.defaultCode,
                'barcode': p.barcode,
                'list_price': p.listPrice,
                'uom_id': [p.uomId, p.uomName ?? 'Unidades'],
                'taxes_id': p.taxIdsList.isNotEmpty ? p.taxIdsList : null,
                '_quantity': quantity, // Pass parsed quantity for later use
                '_discount': discount, // Pass parsed discount for later use
              },
            )
            .toList();

        return (ProductSearchAddResult.multipleMatches, matchesList);
      }
    } catch (e) {
      logger.e('[FastSale] Error searching product by code: $e');
      return (ProductSearchAddResult.cancelled, null);
    }
  }

  /// Add a product to the active order
  ///
  /// Uses [OrderLineCreationService] for offline-first pricing and tax calculation.
  /// Returns early if order is not editable (waiting, approved, sale, done, cancel).
  Future<void> addProduct({
    required int productId,
    required String productName,
    String? productCode,
    double quantity = 1.0,
    int? uomId,
    String? uomName,
    double? priceUnit,
    double discount = 0.0,
    List<int>? taxIds,
  }) async {
    // Block if order is not editable
    if (!_ensureCanModify('addProduct')) return;

    final activeTab = state.activeTab;
    if (activeTab == null) return;

    // Check if product already exists in lines (merge logic for POS)
    final existingIndex = activeTab.lines.indexWhere(
      (l) => l.productId == productId && l.productUomId == uomId,
    );

    if (existingIndex >= 0) {
      // Increment quantity of existing line
      final existingLine = activeTab.lines[existingIndex];
      final newQty = existingLine.productUomQty + quantity;
      await _updateLineQuantity(existingIndex, newQty);

      // Apply discount if specified
      if (discount > 0 && discount != existingLine.discount) {
        await _updateLineDiscount(existingIndex, discount);
      }

      selectLine(existingIndex);
      return;
    }

    // Create new line using OrderLineCreationService (offline-first)
    final creationService = ref.read(orderLineCreationServiceProvider);
    final result = await creationService.createLine(
      orderId: activeTab.orderId,
      productId: productId,
      productName: productName,
      quantity: quantity,
      pricelistId: activeTab.order?.pricelistId,
      priceUnit: priceUnit,
      discount: discount,
      uomId: uomId,
      uomName: uomName,
      productCode: productCode,
      taxIds: taxIds?.join(','),
      sequence: (activeTab.lines.length + 1) * 10,
    );

    if (!result.success || result.line == null) {
      logger.e('[FastSale]', 'Error creating line: ${result.error}');
      return;
    }

    final newLine = result.line!;
    final newLines = [...activeTab.lines, newLine];
    final updatedTab = activeTab.copyWith(
      lines: newLines,
      hasChanges: true,
      selectedLineIndex: newLines.length - 1,
      linesVersion: activeTab.linesVersion + 1,
    );

    _updateActiveTab(updatedTab);

    // Auto-save the order and line to database
    await _saveLineToDatabase(newLine);
  }

  /// Save a single line to the database and update order totals.
  ///
  /// After local persistence, fires off a background sync to Odoo:
  /// - New lines (id < 0) on orders that exist in Odoo (orderId > 0) are created remotely.
  /// - Existing lines (id > 0) are updated remotely.
  /// - If offline or sync fails, the operation is queued for later.
  Future<void> _saveLineToDatabase(SaleOrderLine line) async {
    try {
      final activeTab = state.activeTab;
      if (activeTab == null) return;

      // First ensure the order exists in database with updated totals
      if (activeTab.order != null) {
        // Recalculate order totals from all lines
        final orderWithTotals = _recalculateOrderTotals(
          activeTab.order!,
          activeTab.lines,
        );
        await saleOrderManager.upsertLocal(orderWithTotals);

        // Update the order in state with new totals
        final updatedTab = activeTab.copyWith(order: orderWithTotals);
        _updateActiveTab(updatedTab);
      }

      // Then save the line locally
      await saleOrderLineManager.upsertLocal(line);

      logger.d('[FastSale]', 'Line saved to database: ${line.productName}');

      // Invalidate providers so other screens reload from database
      // This ensures changes from POS are visible everywhere in the app
      ref.invalidate(saleOrderFormProvider);
      ref.invalidate(saleOrderWithLinesProvider(activeTab.orderId));

      // Fire-and-forget: sync line to Odoo in background
      // Only for orders that exist in Odoo (orderId > 0)
      if (activeTab.orderId > 0) {
        final salesRepo = ref.read(salesRepositoryProvider);
        if (salesRepo != null) {
          // Ensure line has orderId set for the sync
          final lineWithOrderId = line.orderId == activeTab.orderId
              ? line
              : line.copyWith(orderId: activeTab.orderId);

          salesRepo.syncLineToOdoo(lineWithOrderId).then((_) {
            // After successful sync, refresh state if line got a remote ID
            _refreshLineAfterSync(lineWithOrderId.lineUuid);
          }).catchError((e) {
            logger.w('[FastSale]', 'Background sync failed (will retry later): $e');
          });
        }
      }
    } catch (e) {
      logger.e('[FastSale]', 'Error saving line to database', e);
    }
  }

  /// Delete a line from the local database and sync the deletion to Odoo.
  ///
  /// After local deletion, recalculates order totals and fires a background
  /// sync to Odoo (fire-and-forget, same pattern as [_saveLineToDatabase]):
  /// - Lines with id > 0: calls `salesRepo.deleteLine()` which handles
  ///   local delete + Odoo unlink (or queues if offline).
  /// - Lines with id < 0: deletes locally only (never existed in Odoo).
  Future<void> _deleteLineFromDatabase(
    SaleOrderLine deletedLine,
    List<SaleOrderLine> remainingLines,
  ) async {
    try {
      final activeTab = state.activeTab;
      if (activeTab == null) return;

      // Recalculate and save order totals with the remaining lines
      if (activeTab.order != null) {
        final orderWithTotals = _recalculateOrderTotals(
          activeTab.order!,
          remainingLines,
        );
        await saleOrderManager.upsertLocal(orderWithTotals);

        // Update the order in state with new totals
        final updatedTab = state.activeTab?.copyWith(order: orderWithTotals);
        if (updatedTab != null) {
          _updateActiveTab(updatedTab);
        }
      }

      // Delete from local DB + sync to Odoo via repository
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo != null) {
        // salesRepo.deleteLine handles:
        // - Local DB delete
        // - Odoo unlink if id > 0 and online
        // - Queue for later if offline
        await salesRepo.deleteLine(deletedLine.id);
      } else {
        // Fallback: at least delete locally if no repo available
        await saleOrderLineManager.deleteLocal(deletedLine.id);
      }

      logger.d(
        '[FastSale]',
        'Line deleted from database: id=${deletedLine.id}, product=${deletedLine.productName}',
      );

      // Invalidate providers so other screens reload from database
      ref.invalidate(saleOrderFormProvider);
      ref.invalidate(saleOrderWithLinesProvider(activeTab.orderId));
    } catch (e) {
      logger.e('[FastSale]', 'Error deleting line from database', e);
    }
  }

  /// Refresh a line in state after sync assigns a remote ID.
  ///
  /// Reads the line back from DB by UUID and updates the in-memory state
  /// so the UI reflects the real Odoo ID instead of the negative local ID.
  Future<void> _refreshLineAfterSync(String? lineUuid) async {
    if (lineUuid == null || lineUuid.isEmpty) return;

    try {
      final activeTab = state.activeTab;
      if (activeTab == null) return;

      // Find the line in current state by UUID
      final lineIndex = activeTab.lines.indexWhere(
        (l) => l.lineUuid == lineUuid,
      );
      if (lineIndex < 0) return;

      final currentLine = activeTab.lines[lineIndex];

      // Only refresh if the line still has a negative (local) ID
      if (currentLine.id >= 0) return;

      // Read updated line from DB by UUID (may have remote ID now)
      final results = await saleOrderLineManager.searchLocal(
        domain: [['line_uuid', '=', lineUuid]],
        limit: 1,
      );
      final updatedLine = results.isNotEmpty ? results.first : null;
      if (updatedLine == null || updatedLine.id == currentLine.id) return;

      // Update in-memory state with the synced line
      final newLines = List<SaleOrderLine>.from(activeTab.lines);
      newLines[lineIndex] = updatedLine;

      final updatedTab = activeTab.copyWith(
        lines: newLines,
        linesVersion: activeTab.linesVersion + 1,
      );
      _updateActiveTab(updatedTab);

      logger.d(
        '[FastSale]',
        'Line refreshed after sync: ${currentLine.id} -> ${updatedLine.id}',
      );
    } catch (e) {
      // Non-critical: line will get its remote ID on next full refresh
      logger.d('[FastSale]', 'Could not refresh line after sync: $e');
    }
  }

  /// Recalculate order totals from lines
  SaleOrder _recalculateOrderTotals(
    SaleOrder order,
    List<SaleOrderLine> lines,
  ) {
    double amountUntaxed = 0.0;
    double amountTax = 0.0;
    double amountTotal = 0.0;

    for (final line in lines) {
      if (line.isProductLine) {
        amountUntaxed += line.priceSubtotal;
        amountTax += line.priceTax;
        amountTotal += line.priceTotal;
      }
    }

    return order.copyWith(
      amountUntaxed: amountUntaxed,
      amountTax: amountTax,
      amountTotal: amountTotal,
    );
  }

  /// Update quantity of selected line
  Future<void> _updateSelectedLineQuantity(double quantity) async {
    final activeTab = state.activeTab;
    if (activeTab == null || activeTab.selectedLineIndex < 0) return;

    await _updateLineQuantity(activeTab.selectedLineIndex, quantity);
  }

  /// Update quantity of a specific line and save to database
  ///
  /// Uses [OrderLineCreationService.recalculateLine] for consistent offline-first calculation.
  Future<void> _updateLineQuantity(int lineIndex, double quantity) async {
    final activeTab = state.activeTab;
    if (activeTab == null) return;
    if (lineIndex < 0 || lineIndex >= activeTab.lines.length) return;

    final line = activeTab.lines[lineIndex];
    final creationService = ref.read(orderLineCreationServiceProvider);
    final calculatedLine = await creationService.recalculateLine(
      line,
      newQuantity: quantity,
    );

    final newLines = List<SaleOrderLine>.from(activeTab.lines);
    newLines[lineIndex] = calculatedLine;

    final updatedTab = activeTab.copyWith(
      lines: newLines,
      hasChanges: true,
      linesVersion: activeTab.linesVersion + 1,
    );

    _updateActiveTab(updatedTab);

    // Auto-save to database
    await _saveLineToDatabase(calculatedLine);
  }

  /// Update discount of selected line and save to database
  Future<void> _updateSelectedLineDiscount(double discount) async {
    final activeTab = state.activeTab;
    if (activeTab == null || activeTab.selectedLineIndex < 0) return;
    await _updateLineDiscount(activeTab.selectedLineIndex, discount);
  }

  /// Update discount of a specific line and save to database
  ///
  /// Uses [OrderLineCreationService.recalculateLine] for consistent offline-first calculation.
  /// Validates against company's max discount percentage.
  Future<void> _updateLineDiscount(int lineIndex, double discount) async {
    logger.d(
      '[FastSale]',
      '🔍 _updateLineDiscount CALLED with lineIndex=$lineIndex, discount=$discount%',
    );

    final activeTab = state.activeTab;
    if (activeTab == null) return;
    if (lineIndex < 0 || lineIndex >= activeTab.lines.length) return;

    // Validate against company's max discount percentage (await to ensure data is loaded)
    final maxDiscount = await getMaxDiscountPercentage(ref);

    logger.d(
      '[FastSale]',
      '🔍 Discount validation: requested=$discount%, maxAllowed=$maxDiscount%',
    );

    if (discount > maxDiscount) {
      state = state.copyWith(
        error:
            'El descuento de ${discount.toStringAsFixed(1)}% excede el límite máximo de ${maxDiscount.toStringAsFixed(1)}%',
      );
      logger.w(
        '[FastSale]',
        'Discount $discount% exceeds max allowed $maxDiscount%',
      );
      return;
    }

    final line = activeTab.lines[lineIndex];
    final clampedDiscount = discount.clamp(0.0, maxDiscount);
    final creationService = ref.read(orderLineCreationServiceProvider);
    final calculatedLine = await creationService.recalculateLine(
      line,
      newDiscount: clampedDiscount,
    );

    final newLines = List<SaleOrderLine>.from(activeTab.lines);
    newLines[lineIndex] = calculatedLine;

    final updatedTab = activeTab.copyWith(
      lines: newLines,
      hasChanges: true,
      linesVersion: activeTab.linesVersion + 1,
    );

    _updateActiveTab(updatedTab);

    // Auto-save to database
    await _saveLineToDatabase(calculatedLine);
  }

  /// Delete selected line
  void deleteSelectedLine() {
    final activeTab = state.activeTab;
    if (activeTab == null || activeTab.selectedLineIndex < 0) return;

    deleteLine(activeTab.selectedLineIndex);
  }

  /// Delete a specific line (with undo support)
  ///
  /// Returns early if order is not editable.
  /// Call [undoDeleteLine] to restore the last deleted line.
  ///
  /// Persists the deletion to local DB and fires a background sync to Odoo:
  /// - Lines with id > 0 (exist in Odoo): local delete + Odoo unlink
  /// - Lines with id < 0 (local-only): local delete only
  /// - If offline: deletion is queued for later sync
  void deleteLine(int lineIndex) {
    // Block if order is not editable
    if (!_ensureCanModify('deleteLine')) return;

    final activeTab = state.activeTab;
    if (activeTab == null) return;
    if (lineIndex < 0 || lineIndex >= activeTab.lines.length) return;

    // Store deleted line for undo (fields on FastSaleNotifier class)
    final deletedLine = activeTab.lines[lineIndex];
    lastDeletedLine = deletedLine;
    lastDeletedLineIndex = lineIndex;

    final newLines = List<SaleOrderLine>.from(activeTab.lines)
      ..removeAt(lineIndex);

    int newSelectedIndex = activeTab.selectedLineIndex;
    if (newSelectedIndex >= newLines.length) {
      newSelectedIndex = newLines.length - 1;
    }
    if (newSelectedIndex == lineIndex) {
      newSelectedIndex = -1;
    }

    final updatedTab = activeTab.copyWith(
      lines: newLines,
      hasChanges: true,
      selectedLineIndex: newSelectedIndex,
      linesVersion: activeTab.linesVersion + 1,
    );

    _updateActiveTab(updatedTab);

    // Persist deletion to local DB + sync to Odoo (fire-and-forget)
    _deleteLineFromDatabase(deletedLine, newLines);
  }

  /// Whether an undo is available for the last deleted line
  bool get canUndoDeleteLine => lastDeletedLine != null;

  /// Undo the last line deletion, restoring the line at its original position.
  ///
  /// Since [deleteLine] now persists the deletion to the database, undo must
  /// re-save the restored line via [_saveLineToDatabase] to keep DB in sync.
  void undoDeleteLine() {
    final activeTab = state.activeTab;
    if (activeTab == null || lastDeletedLine == null) return;

    final restoredLine = lastDeletedLine!;
    final insertIndex = (lastDeletedLineIndex ?? activeTab.lines.length)
        .clamp(0, activeTab.lines.length);

    final newLines = List<SaleOrderLine>.from(activeTab.lines)
      ..insert(insertIndex, restoredLine);

    final updatedTab = activeTab.copyWith(
      lines: newLines,
      hasChanges: true,
      selectedLineIndex: insertIndex,
      linesVersion: activeTab.linesVersion + 1,
    );

    _updateActiveTab(updatedTab);

    // Clear undo state
    lastDeletedLine = null;
    lastDeletedLineIndex = null;

    // Re-save the restored line to database (fire-and-forget)
    _saveLineToDatabase(restoredLine);
  }

  /// Increment quantity of a specific line by 1 (or step for decimals)
  ///
  /// Returns early if order is not editable.
  Future<void> incrementLineQuantity(int lineIndex) async {
    // Block if order is not editable
    if (!_ensureCanModify('incrementLineQuantity')) return;

    final activeTab = state.activeTab;
    if (activeTab == null) return;
    if (lineIndex < 0 || lineIndex >= activeTab.lines.length) return;

    final line = activeTab.lines[lineIndex];
    // Use step of 1 for units, 0.1 for decimals
    final step = line.isUnitProduct ? 1.0 : 0.1;
    final newQty = line.productUomQty + step;

    await _updateLineQuantity(lineIndex, newQty);
  }

  /// Decrement quantity of a specific line by 1 (or step for decimals)
  /// Minimum quantity is 1.
  /// Returns early if order is not editable.
  Future<void> decrementLineQuantity(int lineIndex) async {
    // Block if order is not editable
    if (!_ensureCanModify('decrementLineQuantity')) return;

    final activeTab = state.activeTab;
    if (activeTab == null) return;
    if (lineIndex < 0 || lineIndex >= activeTab.lines.length) return;

    final line = activeTab.lines[lineIndex];
    // Use step of 1 for units, 0.1 for decimals
    final step = line.isUnitProduct ? 1.0 : 0.1;
    final newQty = (line.productUomQty - step).clamp(1.0, double.infinity);

    await _updateLineQuantity(lineIndex, newQty);
  }

  /// Increment quantity of the currently selected line
  Future<void> incrementSelectedLineQuantity() async {
    final activeTab = state.activeTab;
    if (activeTab == null) return;
    if (activeTab.selectedLineIndex < 0) return;

    await incrementLineQuantity(activeTab.selectedLineIndex);
  }

  /// Decrement quantity of the currently selected line
  Future<void> decrementSelectedLineQuantity() async {
    final activeTab = state.activeTab;
    if (activeTab == null) return;
    if (activeTab.selectedLineIndex < 0) return;

    await decrementLineQuantity(activeTab.selectedLineIndex);
  }

  /// Increment discount of the currently selected line by 1%
  Future<void> incrementSelectedLineDiscount() async {
    final activeTab = state.activeTab;
    if (activeTab == null) return;
    if (activeTab.selectedLineIndex < 0) return;

    final line = activeTab.lines[activeTab.selectedLineIndex];
    final newDiscount = (line.discount + 1.0).clamp(0.0, 100.0);
    await _updateLineDiscount(activeTab.selectedLineIndex, newDiscount);
  }

  /// Decrement discount of the currently selected line by 1%
  Future<void> decrementSelectedLineDiscount() async {
    final activeTab = state.activeTab;
    if (activeTab == null) return;
    if (activeTab.selectedLineIndex < 0) return;

    final line = activeTab.lines[activeTab.selectedLineIndex];
    final newDiscount = (line.discount - 1.0).clamp(0.0, 100.0);
    await _updateLineDiscount(activeTab.selectedLineIndex, newDiscount);
  }

  /// Update the UoM for a specific line and recalculate prices
  ///
  /// This method mimics Odoo 19 behavior:
  /// 1. Keeps quantity the same (only UoM changes)
  /// 2. Recalculates price using pricelist rules for the new UoM
  /// 3. Recalculates taxes and totals
  ///
  /// [newUomFactor] - Factor from SelectUomDialog result
  /// Returns early if order is not editable.
  Future<void> updateLineUom(
    int lineIndex,
    int uomId,
    String uomName, {
    double? newUomFactor,
    double? dialogPrice,
  }) async {
    // Block if order is not editable
    if (!_ensureCanModify('updateLineUom')) return;

    final activeTab = state.activeTab;
    if (activeTab == null) return;
    if (lineIndex < 0 || lineIndex >= activeTab.lines.length) return;

    final line = activeTab.lines[lineIndex];
    if (line.productId == null) {
      // No product - just update UoM fields
      final updatedLine = line.copyWith(
        productUomId: uomId,
        productUomName: uomName,
      );
      final newLines = List<SaleOrderLine>.from(activeTab.lines);
      newLines[lineIndex] = updatedLine;
      _updateActiveTab(activeTab.copyWith(lines: newLines, hasChanges: true));
      return;
    }

    final pricelistId = activeTab.order?.pricelistId;

    // Get product info for price calculation
    final product = await productManager.readLocal(line.productId!);

    logger.i(
      '[FastSale]',
      'UoM change: ${line.productUomName} -> $uomName (ID: $uomId)',
    );

    // Calculate new price with the new UoM
    double newPriceUnit = dialogPrice ?? line.priceUnit;
    double newDiscount = line.discount;
    bool priceCalculated = dialogPrice != null;

    // If dialog didn't provide price, calculate it
    if (!priceCalculated && pricelistId != null && product != null) {
      try {
        final calculator = ref.read(pricelistCalculatorProvider);

        logger.d(
          '[FastSale]',
          'Calculating price for UoM: product=${product.name}, listPrice=${product.listPrice}, pricelist=$pricelistId',
        );

        final result = await calculator.calculatePrice(
          productId: line.productId!,
          productTmplId: product.productTmplId ?? line.productId!,
          pricelistId: pricelistId,
          quantity: line.productUomQty,
          uomId: uomId,
          productUomId: product.uomId,
          listPrice: product.listPrice,
        );

        newPriceUnit = result.basePrice;
        newDiscount = result.discount;
        priceCalculated = true;

        // Validate pricelist discount against company's max discount
        final maxDiscount = await getMaxDiscountPercentage(ref);
        if (newDiscount > maxDiscount) {
          logger.w(
            '[FastSale]',
            'Pricelist discount $newDiscount% exceeds max $maxDiscount% - clamping',
          );
          newDiscount = maxDiscount;
        }

        logger.i(
          '[FastSale]',
          'Price from LOCAL pricelist: basePrice=$newPriceUnit, discount=$newDiscount% (ruleId: ${result.ruleId})',
        );
      } catch (e, stack) {
        logger.e('[FastSale]', 'Error calculating price: $e', e, stack);
      }
    }

    // Get tax info from product
    double taxPercent = 0.0;
    String? taxIdsStr = line.taxIds;
    String? taxNames = line.taxNames;

    try {
      final taxCalculator = ref.read(taxCalculatorProvider);
      final taxInfo = await taxCalculator.getProductTaxInfo(
        productId: line.productId!,
      );
      if (taxInfo.isNotEmpty) {
        taxPercent = taxInfo.taxPercent;
        taxIdsStr = taxInfo.taxIds;
        taxNames = taxInfo.taxNames;
        logger.d('[FastSale]', 'Tax info: $taxNames ($taxPercent%)');
      }
    } catch (e) {
      logger.e('[FastSale]', 'Error getting tax info: $e');
    }

    // Apply all changes: UoM, price, discount, taxes
    final lineWithUom = line.copyWith(
      productUomId: uomId,
      productUomName: uomName,
      taxIds: taxIdsStr,
      taxNames: taxNames,
    );

    // Use saleOrderLineCalculator (same as normal form)
    final updatedLine = saleOrderLineCalculator.updateLineCalculations(
      lineWithUom,
      newPriceUnit: newPriceUnit,
      newQuantity: line.productUomQty,
      newDiscount: newDiscount,
      taxPercent: taxPercent,
    );

    final newLines = List<SaleOrderLine>.from(activeTab.lines);
    newLines[lineIndex] = updatedLine;

    final updatedTab = activeTab.copyWith(lines: newLines, hasChanges: true);

    _updateActiveTab(updatedTab);

    logger.i(
      '[FastSale]',
      'Line updated: price=$newPriceUnit, discount=$newDiscount%, tax=$taxPercent%',
    );
    logger.d(
      '[FastSale]',
      'Totals: subtotal=${updatedLine.priceSubtotal}, tax=${updatedLine.priceTax}, total=${updatedLine.priceTotal}',
    );

    // Auto-save to database
    await _saveLineToDatabase(updatedLine);
  }

  /// Update the custom description (name) for a specific line
  ///
  /// This allows overriding the product name with a custom description
  /// The productName field keeps the original product name for reference
  void updateLineDescription(int lineIndex, String description) {
    final activeTab = state.activeTab;
    if (activeTab == null) return;
    if (lineIndex < 0 || lineIndex >= activeTab.lines.length) return;

    final line = activeTab.lines[lineIndex];
    final updatedLine = line.copyWith(name: description);

    final newLines = List<SaleOrderLine>.from(activeTab.lines);
    newLines[lineIndex] = updatedLine;

    final updatedTab = activeTab.copyWith(lines: newLines, hasChanges: true);

    _updateActiveTab(updatedTab);
    logger.d('[FastSale]', 'Line description updated: $description');
  }

  /// Set exact quantity for a specific line
  Future<void> setLineQuantity(int lineIndex, double quantity) async {
    if (quantity < 1) quantity = 1;
    await _updateLineQuantity(lineIndex, quantity);
  }
}
