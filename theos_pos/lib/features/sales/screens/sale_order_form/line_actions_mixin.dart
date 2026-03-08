import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/providers.dart';
import '../../../../core/database/repositories/repository_providers.dart';
import '../../../../core/services/platform/global_notification_service.dart';
import '../../../../shared/providers/company_config_provider.dart'
    show getMaxDiscountPercentage;
import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import '../../providers/providers.dart';
import '../../widgets/editable_cell_type.dart';
import 'edit_dialogs.dart';

/// States where the sale order cannot be modified (Odoo 19 compatible)
/// These states mean the order is locked for editing
const Set<String> kReadonlyOrderStates = {
  'sale', // Confirmed/Sales Order
  'cancel', // Cancelled
  'approved', // Approved (custom workflow)
  'rejected', // Rejected (custom workflow)
  'waiting', // Waiting for approval
};

/// Mixin providing line action callbacks for SaleOrderFormLines
///
/// Extracts line manipulation logic (update qty, price, discount, uom, delete, etc.)
/// from the main widget to improve code organization.
mixin SaleOrderFormLineActionsMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Whether the form is in edit mode
  bool get isLineEditingEnabled;

  /// The order ID for this form
  int get currentOrderId;

  // ============================================================================
  // TAX HELPER - OFFLINE-FIRST
  // ============================================================================

  /// Get the correct tax percentage for a line.
  /// OFFLINE-FIRST: Uses TaxCalculatorService to get the actual tax % from product.
  /// NUNCA calcula en reversa desde los montos - siempre usa el % real del impuesto.
  /// Get the fiscal position ID from the current order being edited.
  int? get _currentFiscalPositionId =>
      ref.read(saleOrderFormProvider).order?.fiscalPositionId;

  Future<double> _getTaxPercentForLine(SaleOrderLine line) async {
    // If the line has a productId, get the actual tax percent from the product
    if (line.productId != null && line.productId! > 0) {
      try {
        final taxCalculator = ref.read(taxCalculatorProvider);
        final taxInfo = await taxCalculator.getProductTaxInfo(
          productId: line.productId!,
          fiscalPositionId: _currentFiscalPositionId,
        );
        if (taxInfo.isNotEmpty) {
          logger.d(
            '[SaleOrderFormLines]',
            'Tax from LOCAL DB: ${taxInfo.taxNames} (${taxInfo.taxPercent}%)',
          );
          return taxInfo.taxPercent;
        }
        logger.w(
          '[SaleOrderFormLines]',
          'No taxes found for product ${line.productId}, using 0%',
        );
      } catch (e) {
        logger.e('[SaleOrderFormLines]', 'Tax lookup failed: $e');
      }
    }
    // No product or no taxes found - return 0 (no reverse calculation)
    return 0.0;
  }

  // ============================================================================
  // LINE UPDATE ACTIONS
  // ============================================================================

  Future<void> updateLineQty(SaleOrderLine lineFromCallback, double qty) async {
    if (!isLineEditingEnabled) return;

    final currentLine = ref
        .read(saleOrderFormProvider.notifier)
        .getLine(lineFromCallback.id);
    if (currentLine == null) {
      logger.w('[SaleOrderFormLines]', 'Line ${lineFromCallback.id} not found');
      return;
    }

    // Apply is_unit_product validation - round to integer if product requires it
    double finalQty = qty;
    if (currentLine.productId != null) {
      final product = await productManager.readLocal(currentLine.productId!);

      if (product != null && product.isUnitProduct) {
        final roundedQty = qty.round().toDouble();
        if (roundedQty != qty) {
          logger.i(
            '[SaleOrderFormLines]',
            'is_unit_product: rounding qty $qty -> $roundedQty for ${currentLine.productName}',
          );
          finalQty = roundedQty;
        }
      }
    }

    if (finalQty == currentLine.productUomQty) return;

    logger.i(
      '[SaleOrderFormLines]',
      'Updating qty: ${currentLine.productUomQty} -> $finalQty',
    );

    final state = ref.read(saleOrderFormProvider);
    double newPriceUnit = currentLine.priceUnit;
    double newDiscount = currentLine.discount;

    // Recalculate price using pricelist rules
    if (state.pricelistId != null && currentLine.productId != null) {
      try {
        final pricelistCalc = ref.read(pricelistCalculatorProvider);
        final product = await productManager.readLocal(currentLine.productId!);

        if (product != null) {
          final result = await pricelistCalc.calculatePrice(
            productId: currentLine.productId!,
            productTmplId: product.productTmplId ?? currentLine.productId!,
            pricelistId: state.pricelistId!,
            quantity: finalQty,
            uomId: currentLine.productUomId,
            productUomId: product.uomId,
            listPrice: product.listPrice,
          );
          newPriceUnit = result.basePrice;
          newDiscount = result.discount;

          // Validate pricelist discount against company's max discount
          final maxDiscount = await getMaxDiscountPercentage(ref);
          if (newDiscount > maxDiscount) {
            logger.w(
              '[SaleOrderFormLines]',
              'Pricelist discount $newDiscount% exceeds max $maxDiscount% - clamping',
            );
            newDiscount = maxDiscount;
          }
        }
      } catch (e) {
        logger.e('[SaleOrderFormLines]', 'Error recalculating price: $e');
      }
    }

    // OFFLINE-FIRST: Get tax percent from product (not reverse calculated)
    final taxPercent = await _getTaxPercentForLine(currentLine);
    final updatedLine = saleOrderLineCalculator.updateLineCalculations(
      currentLine,
      newPriceUnit: newPriceUnit,
      newQuantity: finalQty,
      newDiscount: newDiscount,
      taxPercent: taxPercent,
    );

    ref.read(saleOrderFormProvider.notifier).updateLine(updatedLine);
  }

  Future<void> updateLinePrice(
    SaleOrderLine lineFromCallback,
    double price,
  ) async {
    if (!isLineEditingEnabled) return;

    final currentLine = ref
        .read(saleOrderFormProvider.notifier)
        .getLine(lineFromCallback.id);
    if (currentLine == null || price == currentLine.priceUnit) return;

    // OFFLINE-FIRST: Get tax percent from product (not reverse calculated)
    final taxPercent = await _getTaxPercentForLine(currentLine);
    final updatedLine = saleOrderLineCalculator.updateLineCalculations(
      currentLine,
      newPriceUnit: price,
      taxPercent: taxPercent,
    );

    ref.read(saleOrderFormProvider.notifier).updateLine(updatedLine);
  }

  Future<void> updateLineDiscount(
    SaleOrderLine lineFromCallback,
    double discount,
  ) async {
    if (!isLineEditingEnabled) return;

    final currentLine = ref
        .read(saleOrderFormProvider.notifier)
        .getLine(lineFromCallback.id);
    if (currentLine == null || discount == currentLine.discount) return;

    // Validate against company's max discount percentage (await to ensure data is loaded)
    final maxDiscount = await getMaxDiscountPercentage(ref);

    logger.d(
      '[SaleOrderFormLines]',
      'Discount validation: requested=$discount%, max=$maxDiscount%',
    );

    if (discount > maxDiscount) {
      // Show error message
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Descuento excede límite',
          message:
              'El descuento de ${discount.toStringAsFixed(1)}% excede el límite máximo permitido de ${maxDiscount.toStringAsFixed(1)}%',
        );
      }
      logger.w(
        '[SaleOrderFormLines]',
        'Discount $discount% exceeds max allowed $maxDiscount%',
      );
      return;
    }

    // Clamp discount to valid range
    final clampedDiscount = discount.clamp(0.0, maxDiscount);

    // OFFLINE-FIRST: Get tax percent from product (not reverse calculated)
    final taxPercent = await _getTaxPercentForLine(currentLine);
    final updatedLine = saleOrderLineCalculator.updateLineCalculations(
      currentLine,
      newDiscount: clampedDiscount,
      taxPercent: taxPercent,
    );

    ref.read(saleOrderFormProvider.notifier).updateLine(updatedLine);
  }

  void updateLineName(SaleOrderLine lineFromCallback, String name) {
    if (!isLineEditingEnabled) return;

    final currentLine = ref
        .read(saleOrderFormProvider.notifier)
        .getLine(lineFromCallback.id);
    if (currentLine == null) return;

    final updatedLine = currentLine.copyWith(name: name);
    ref.read(saleOrderFormProvider.notifier).updateLine(updatedLine);
  }

  void updateLineUom(
    SaleOrderLine lineFromCallback,
    int uomId,
    String uomName,
  ) {
    if (!isLineEditingEnabled) return;

    final currentLine = ref
        .read(saleOrderFormProvider.notifier)
        .getLine(lineFromCallback.id);
    if (currentLine == null) return;

    final updatedLine = currentLine.copyWith(
      productUomId: uomId,
      productUomName: uomName,
    );
    ref.read(saleOrderFormProvider.notifier).updateLine(updatedLine);
  }

  // ============================================================================
  // UOM SELECTION WITH PRICE RECALCULATION (Odoo 19 compatible)
  // ============================================================================

  /// Check if the order is in a readonly state (cannot be modified)
  /// Matches Odoo 19 behavior where orders in certain states are locked
  bool isOrderReadonly(String? orderState) {
    if (orderState == null) return false;
    return kReadonlyOrderStates.contains(orderState);
  }

  /// Check if UoM can be changed for this line (Odoo 19: product_uom_readonly)
  /// UoM is readonly when order is in a locked state
  bool isUomReadonly(SaleOrderLine line) {
    return isOrderReadonly(line.orderState);
  }

  /// Check if the line can be edited (considering order state)
  /// Returns true only if both form editing is enabled AND order is not locked
  bool canEditLine(SaleOrderLine line) {
    return isLineEditingEnabled && !isOrderReadonly(line.orderState);
  }

  Future<void> selectUomForLine(
    BuildContext context,
    SaleOrderLine lineFromCallback,
  ) async {
    if (!isLineEditingEnabled) return;

    final currentLine = ref
        .read(saleOrderFormProvider.notifier)
        .getLine(lineFromCallback.id);
    if (currentLine == null) return;

    // Check if UoM is readonly (Odoo 19: product_uom_readonly)
    if (isUomReadonly(currentLine)) {
      if (context.mounted) {
        CopyableInfoBar.showWarning(
          context,
          title: 'Orden bloqueada',
          message:
              'No se puede modificar una orden en estado "${currentLine.orderState}". '
              'Solo se pueden editar órdenes en estado borrador o cotización.',
        );
      }
      return;
    }

    final formState = ref.read(saleOrderFormProvider);
    final pricelistId = formState.pricelistId;

    double? listPrice;
    int? productTmplId;
    List<int>? allowedUomIds;
    int? productBaseUomId;

    if (currentLine.productId != null) {
      final product = await productManager.readLocal(currentLine.productId!);
      if (product != null) {
        listPrice = product.listPrice;
        productTmplId = product.productTmplId;
        productBaseUomId = product.uomId;

        // Get allowed UoMs (Odoo 19: allowed_uom_ids = product.uom_id | product.uom_ids)
        final uomIds = <int>{};
        if (product.uomId != null) {
          uomIds.add(product.uomId!);
        }
        if (product.uomIds != null && product.uomIds!.isNotEmpty) {
          uomIds.addAll(product.uomIds!);
        }
        if (uomIds.isNotEmpty) {
          allowedUomIds = uomIds.toList();
        }
      }
    }

    if (!context.mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SelectUomDialog(
        currentUomId: currentLine.productUomId,
        currentUomName: currentLine.productUomName,
        productId: currentLine.productId,
        productTmplId: productTmplId,
        pricelistId: pricelistId,
        listPrice: listPrice,
        allowedUomIds: allowedUomIds, // Pass allowed UoMs for validation
      ),
    );

    if (result != null) {
      final uomId = result['id'] as int;
      final uomName = result['name'] as String;
      final newUomFactor = (result['factor'] as double?) ?? 1.0;

      if (uomId != currentLine.productUomId && currentLine.productId != null) {
        await _updateLineUomWithPriceAndQtyConversion(
          currentLine,
          uomId,
          uomName,
          newUomFactor,
          productBaseUomId,
        );
      } else {
        updateLineUom(currentLine, uomId, uomName);
      }
    }
  }

  /// Update line with UoM change and price recalculation
  /// Mimics Odoo 19's behavior where changing UoM:
  /// 1. Keeps the quantity value the same (user entered 3, it stays 3)
  /// 2. Only recalculates price based on the new UoM's pricelist rules
  ///
  /// Note: In Odoo 19, when you change UoM the quantity number stays the same.
  /// Example: "3 units" → change to "box" → "3 boxes" (not converted to 0.25 boxes)
  Future<void> _updateLineUomWithPriceAndQtyConversion(
    SaleOrderLine line,
    int newUomId,
    String newUomName,
    double newUomFactor,
    int? productBaseUomId,
  ) async {
    final state = ref.read(saleOrderFormProvider);

    // Odoo 19 behavior: Keep quantity the same, only change UoM and recalculate price
    // The numeric value stays the same - only the unit changes
    final newQty = line.productUomQty;

    logger.i(
      '[SaleOrderFormLines]',
      'UoM change: ${line.productUomName} (ID: ${line.productUomId}) -> $newUomName (ID: $newUomId)',
    );
    logger.d(
      '[SaleOrderFormLines]',
      'UoM details: factor=$newUomFactor, productBaseUomId=$productBaseUomId, qty stays $newQty',
    );

    // Calculate new price with the new UoM
    double newPriceUnit = line.priceUnit;
    double newDiscount = line.discount;
    bool priceCalculated = false;

    if (state.pricelistId != null && line.productId != null) {
      try {
        final calculator = ref.read(pricelistCalculatorProvider);
        final product = await productManager.readLocal(line.productId!);

        if (product != null) {
          logger.d(
            '[SaleOrderFormLines]',
            'Calculating price for UoM change: product=${product.name}, listPrice=${product.listPrice}, pricelist=${state.pricelistId}',
          );

          final result = await calculator.calculatePrice(
            productId: line.productId!,
            productTmplId: product.productTmplId ?? line.productId!,
            pricelistId: state.pricelistId!,
            quantity: newQty, // Use converted quantity for price calculation
            uomId: newUomId,
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
              '[SaleOrderFormLines]',
              'Pricelist discount $newDiscount% exceeds max $maxDiscount% - clamping',
            );
            newDiscount = maxDiscount;
          }

          logger.i(
            '[SaleOrderFormLines]',
            'Price calculated from LOCAL pricelist: basePrice=$newPriceUnit, discount=$newDiscount% (ruleId: ${result.ruleId})',
          );
        }
      } catch (e, stack) {
        logger.e('[SaleOrderFormLines]', 'Price calc error: $e', e, stack);
      }
    }

    // Fallback to Odoo onchange if local calculation failed
    if (!priceCalculated) {
      logger.d(
        '[SaleOrderFormLines]',
        'Local price calc not available, trying ODOO onchange fallback...',
      );
      final productRepo = ref.read(productRepositoryProvider);
      if (productRepo != null) {
        try {
          final onchangeResult = await productRepo.onchangeUom(
            orderId: currentOrderId,
            productId: line.productId!,
            uomId: newUomId,
            partnerId: state.partnerId,
            pricelistId: state.pricelistId,
            qty: newQty,
          );

          if (onchangeResult != null && onchangeResult['price_unit'] != null) {
            newPriceUnit = (onchangeResult['price_unit'] as num).toDouble();
            if (onchangeResult['discount'] != null) {
              newDiscount = (onchangeResult['discount'] as num).toDouble();

              // Validate discount against company's max
              final maxDiscount = await getMaxDiscountPercentage(ref);
              if (newDiscount > maxDiscount) {
                logger.w(
                  '[SaleOrderFormLines]',
                  'Odoo discount $newDiscount% exceeds max $maxDiscount% - clamping',
                );
                newDiscount = maxDiscount;
              }
            }
            logger.i(
              '[SaleOrderFormLines]',
              'Price from ODOO onchange: price=$newPriceUnit, discount=$newDiscount%',
            );
          }
        } catch (e) {
          logger.e('[SaleOrderFormLines]', 'Odoo onchange failed: $e');
        }
      }
    }

    // Get current line state (might have changed)
    final currentLine = ref
        .read(saleOrderFormProvider.notifier)
        .getLine(line.id);
    if (currentLine == null) return;

    // OFFLINE-FIRST: Get tax percentage from product taxes using TaxCalculatorService
    // NUNCA calcular en reversa - siempre usar el % real del impuesto del producto
    double taxPercent = 0.0;
    String? taxIdsStr = currentLine.taxIds;
    String? taxNames = currentLine.taxNames;

    if (line.productId != null && line.productId! > 0) {
      try {
        final taxCalculator = ref.read(taxCalculatorProvider);
        final taxInfo = await taxCalculator.getProductTaxInfo(
          productId: line.productId!,
          fiscalPositionId: _currentFiscalPositionId,
        );
        if (taxInfo.isNotEmpty) {
          taxPercent = taxInfo.taxPercent;
          taxIdsStr = taxInfo.taxIds;
          taxNames = taxInfo.taxNames;
          logger.d(
            '[SaleOrderFormLines]',
            'Tax info from LOCAL DB for UoM change: $taxNames ($taxPercent%)',
          );
        } else {
          logger.w(
            '[SaleOrderFormLines]',
            'No taxes found for product ${line.productId}, using 0%',
          );
        }
      } catch (e) {
        logger.e('[SaleOrderFormLines]', 'Error getting tax info: $e');
        // No fallback - use 0% if tax lookup fails
      }
    } else {
      // Lines without product have no taxes
      logger.d('[SaleOrderFormLines]', 'Line has no product, using 0% tax');
    }

    // Apply all changes: UoM, quantity, price, discount, taxes
    final lineWithUomAndQty = currentLine.copyWith(
      productUomId: newUomId,
      productUomName: newUomName,
      taxIds: taxIdsStr,
      taxNames: taxNames,
    );
    final updatedLine = saleOrderLineCalculator.updateLineCalculations(
      lineWithUomAndQty,
      newPriceUnit: newPriceUnit,
      newQuantity: newQty,
      newDiscount: newDiscount,
      taxPercent: taxPercent,
    );

    logger.i(
      '[SaleOrderFormLines]',
      'Line updated after UoM change:  priceUnit=$newPriceUnit, qty=$newQty, discount=$newDiscount%, tax=$taxPercent%',
    );
    logger.d(
      '[SaleOrderFormLines]',
      'Final amounts: subtotal=${updatedLine.priceSubtotal}, tax=${updatedLine.priceTax}, total=${updatedLine.priceTotal}',
    );

    ref.read(saleOrderFormProvider.notifier).updateLine(updatedLine);
  }

  // ============================================================================
  // DELETE / DUPLICATE / MOVE
  // ============================================================================

  /// Elimina una línea después de confirmar con el usuario.
  /// Devuelve true si se eliminó, false si se canceló.
  Future<bool> deleteLine(BuildContext context, SaleOrderLine line) async {
    if (!isLineEditingEnabled) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Eliminar linea'),
        content: Text('Desea eliminar "${line.productName ?? line.name}"?'),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(saleOrderFormProvider.notifier).deleteLine(line.id);
      return true;
    }
    return false;
  }

  /// Mueve una línea hacia arriba en la secuencia
  void moveLineUp(SaleOrderLine line) {
    if (!isLineEditingEnabled) return;

    final notifier = ref.read(saleOrderFormProvider.notifier);
    final visibleLines = notifier.getVisibleLines();

    // Ordenar por secuencia
    visibleLines.sort((a, b) => a.sequence.compareTo(b.sequence));

    final currentIndex = visibleLines.indexWhere((l) => l.id == line.id);
    if (currentIndex <= 0) return; // Ya es el primero

    // Intercambiar secuencias con la línea anterior
    final prevLine = visibleLines[currentIndex - 1];
    final currentSequence = line.sequence;
    final prevSequence = prevLine.sequence;

    notifier.updateLine(line.copyWith(sequence: prevSequence));
    notifier.updateLine(prevLine.copyWith(sequence: currentSequence));
  }

  /// Mueve una línea hacia abajo en la secuencia
  void moveLineDown(SaleOrderLine line) {
    if (!isLineEditingEnabled) return;

    final notifier = ref.read(saleOrderFormProvider.notifier);
    final visibleLines = notifier.getVisibleLines();

    // Ordenar por secuencia
    visibleLines.sort((a, b) => a.sequence.compareTo(b.sequence));

    final currentIndex = visibleLines.indexWhere((l) => l.id == line.id);
    if (currentIndex < 0 || currentIndex >= visibleLines.length - 1) {
      return; // Ya es el ultimo
    }

    // Intercambiar secuencias con la línea siguiente
    final nextLine = visibleLines[currentIndex + 1];
    final currentSequence = line.sequence;
    final nextSequence = nextLine.sequence;

    notifier.updateLine(line.copyWith(sequence: nextSequence));
    notifier.updateLine(nextLine.copyWith(sequence: currentSequence));
  }

  void duplicateLine(SaleOrderLine line) {
    if (!isLineEditingEnabled) return;

    final duplicatedLine = line.copyWith(
      id: -DateTime.now().millisecondsSinceEpoch,
      lineUuid: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      sequence: line.sequence + 5,
    );
    ref.read(saleOrderFormProvider.notifier).addLine(duplicatedLine);
  }

  // ============================================================================
  // TOGGLE FLAGS
  // ============================================================================

  void toggleHidePrices(SaleOrderLine line) {
    if (!isLineEditingEnabled) return;
    final updatedLine = line.copyWith(collapsePrices: !line.collapsePrices);
    ref.read(saleOrderFormProvider.notifier).updateLine(updatedLine);
  }

  void toggleHideComposition(SaleOrderLine line) {
    if (!isLineEditingEnabled) return;
    final updatedLine = line.copyWith(
      collapseComposition: !line.collapseComposition,
    );
    ref.read(saleOrderFormProvider.notifier).updateLine(updatedLine);
  }

  void toggleOptional(SaleOrderLine line) {
    if (!isLineEditingEnabled) return;
    final updatedLine = line.copyWith(isOptional: !line.isOptional);
    ref.read(saleOrderFormProvider.notifier).updateLine(updatedLine);
  }

  // ============================================================================
  // PRODUCT SELECTION
  // ============================================================================

  /// Updates the line product by code (smart search)
  ///
  /// Logic:
  /// 1. Search local DB for product with [code]
  /// 2. If 1 exact match (default_code or barcode): Select it automatically
  /// 3. If 0 matches: Show error notification
  /// 4. If >1 matches: Open product selection dialog
  ///
  /// Returns [ProductCodeSearchResult] to indicate the outcome for navigation decisions.
  /// - For existing lines (had product): returns successExistingLine/multipleSelectedExisting
  /// - For new lines (no product): returns successNewLine/multipleSelectedNew
  Future<ProductCodeSearchResult> updateLineProductByCode(
    BuildContext context,
    SaleOrderLine line,
    String code,
  ) async {
    if (!isLineEditingEnabled) return ProductCodeSearchResult.cancelled;

    // Determine if this is an existing line (had product) or new line (empty)
    final isExistingLine = line.productId != null;

    // Normalize codes for comparison
    final currentCode = line.productCode?.trim() ?? '';
    final newCode = code.trim();

    if (newCode.isEmpty) return ProductCodeSearchResult.unchanged;
    if (newCode.toLowerCase() == currentCode.toLowerCase()) {
      logger.d('[SaleOrderFormLines] Code unchanged (ignoring case): $newCode');
      return ProductCodeSearchResult.unchanged;
    }

    logger.i(
      '[SaleOrderFormLines] Searching product by code: $newCode (isExisting: $isExistingLine)',
    );

    // 1. Search local DB
    final productRepo = ref.read(productRepositoryProvider);
    if (productRepo == null) return ProductCodeSearchResult.cancelled;

    try {
      // Search by exact code first (case insensitive)
      final exactMatches = await productManager.searchLocal(
        domain: [
          '|',
          ['default_code', '=ilike', newCode],
          ['barcode', '=ilike', newCode],
        ],
      );

      logger.d(
        '[SaleOrderFormLines] Found ${exactMatches.length} exact matches',
      );

      if (exactMatches.length == 1) {
        // 2. Exact match found - Select it automatically
        final product = exactMatches.first;
        if (!context.mounted) return ProductCodeSearchResult.cancelled;

        logger.i(
          '[SaleOrderFormLines] Auto-selecting product: ${product.name}',
        );

        // Construct mock result map expected by _applyProductSelection logic
        final productMap = {
          'id': product.id,
          'name': product.name,
          'display_name': product.displayName,
          'default_code': product.defaultCode,
          'list_price': product.listPrice,
          'product_tmpl_id': product.productTmplId,
          'uom_id': [product.uomId, product.uomName ?? 'Units'],
        };
        // Reuse common selection logic
        await _applyProductSelection(context, line, productMap);

        // Return appropriate result based on line type
        return isExistingLine
            ? ProductCodeSearchResult.successExistingLine
            : ProductCodeSearchResult.successNewLine;
      } else if (exactMatches.isEmpty) {
        // 3. No matches - Show warning notification
        logger.i('[SaleOrderFormLines] No match found for: $newCode');
        if (!context.mounted) return ProductCodeSearchResult.cancelled;
        ref
            .read(globalNotificationProvider)
            .showWarning(
              context,
              title: 'Producto no encontrado',
              message: 'No se encontró producto con código: $newCode',
              durationSeconds: 3,
            );
        return ProductCodeSearchResult.notFound;
      } else {
        // 4. Multiple matches - Open selection dialog
        logger.i(
          '[SaleOrderFormLines] Multiple matches (${exactMatches.length}) for: $newCode - opening dialog',
        );
        if (!context.mounted) return ProductCodeSearchResult.cancelled;

        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => SelectProductDialog(initialSearch: newCode),
        );

        if (result == null) {
          // User cancelled the dialog
          return ProductCodeSearchResult.cancelled;
        }

        if (!context.mounted) return ProductCodeSearchResult.cancelled;
        await _applyProductSelection(context, line, result);

        // Return appropriate result based on line type
        return isExistingLine
            ? ProductCodeSearchResult.multipleSelectedExisting
            : ProductCodeSearchResult.multipleSelectedNew;
      }
    } catch (e, stack) {
      logger.e(
        '[SaleOrderFormLines]',
        'Error searching product by code: $e',
        e,
        stack,
      );
      return ProductCodeSearchResult.cancelled;
    }
  }

  /// Internal helper to apply product selection (shared between dialog and auto-select)
  Future<void> _applyProductSelection(
    BuildContext context,
    SaleOrderLine line,
    Map<String, dynamic> result,
  ) async {
    final rawName = result['display_name'] ?? result['name'] as String;
    final productCode = result['default_code'] as String?;
    final productName = _cleanProductName(rawName);
    final productId = result['id'] as int;
    final listPrice = (result['list_price'] as num?)?.toDouble() ?? 0.0;

    final uomData = result['uom_id'];
    int? uomId;
    String? uomName;
    if (uomData is List && uomData.length >= 2) {
      uomId = uomData[0] as int;
      uomName = uomData[1] as String;
    }

    // OFFLINE-FIRST: Always try local database first for tax data
    // Enhanced logging for debugging product selection
    logger.i(
      '[SaleOrderFormLines]',
      'Product selected: $productName (ID: $productId, code: $productCode)',
    );
    logger.d(
      '[SaleOrderFormLines]',
      'Product details: listPrice=$listPrice, uomId=$uomId ($uomName)',
    );

    String? taxIdsStr;
    String? taxNames;
    double taxPercent = 0.0;

    // 1. First try local database (offline-first approach)
    if (productId > 0) {
      try {
        final taxCalculator = ref.read(taxCalculatorProvider);
        final taxInfo = await taxCalculator.getProductTaxInfo(
          productId: productId,
          productTmplId: result['product_tmpl_id'] as int?,
          fiscalPositionId: _currentFiscalPositionId,
        );
        if (taxInfo.isNotEmpty) {
          taxIdsStr = taxInfo.taxIds;
          taxNames = taxInfo.taxNames;
          taxPercent = taxInfo.taxPercent;
          logger.i(
            '[SaleOrderFormLines]',
            'Tax info from LOCAL DB: $taxNames ($taxPercent%)',
          );
          // Log individual taxes for debugging
          for (final tax in taxInfo.taxes) {
            logger.d(
              '[SaleOrderFormLines]',
              '  Tax ${tax.odooId}: ${tax.name} (${tax.amountType}=${tax.amount}%, priceInclude=${tax.priceInclude})',
            );
          }
        }
      } catch (e, stack) {
        logger.e(
          '[SaleOrderFormLines]',
          'Error getting local tax info: $e',
          e,
          stack,
        );
      }
    }

    // 2. Fallback to Odoo result only if local data not available
    if (taxIdsStr == null || taxIdsStr.isEmpty) {
      final odooTaxNames = result['tax_names'] as String?;
      final odooTaxPercent = (result['tax_percent'] as num?)?.toDouble() ?? 0.0;
      final odooTaxIds = result['taxes_id'];
      if (odooTaxIds is List && odooTaxIds.isNotEmpty) {
        taxIdsStr = odooTaxIds.whereType<int>().join(',');
        taxNames = odooTaxNames;
        taxPercent = odooTaxPercent;
        logger.i(
          '[SaleOrderFormLines]',
          'Tax info from ODOO fallback: $taxNames ($taxPercent%)',
        );
      } else {
        logger.w(
          '[SaleOrderFormLines]',
          'No tax info available (local or Odoo)',
        );
      }
    }

    double finalPrice = listPrice;
    double finalDiscount = line.discount; // Default to existing line discount
    final state = ref.read(saleOrderFormProvider);

    // Check temporal_no_despachar validation
    final localProduct = await productManager.readLocal(productId);

    if (localProduct != null &&
        localProduct.temporalNoDespachar &&
        context.mounted) {
      logger.w(
        '[SaleOrderFormLines]',
        'temporal_no_despachar: blocking product ${localProduct.name}',
      );
      CopyableInfoBar.showWarning(
        context,
        title: 'Producto temporal',
        message:
            'El producto "${localProduct.name}" es temporal y no puede ser despachado. '
            'Por favor seleccione otro producto.',
      );
      return;
    }

    if (state.pricelistId != null && localProduct != null) {
      try {
        final calculator = ref.read(pricelistCalculatorProvider);
        final productTmplId = localProduct.productTmplId ?? productId;

        final calcResult = await calculator.calculatePrice(
          productId: productId,
          productTmplId: productTmplId,
          pricelistId: state.pricelistId!,
          quantity: line.productUomQty,
          uomId: uomId,
          listPrice: listPrice,
        );

        if (calcResult.ruleId != null) {
          // Odoo 19 behavior:
          // price_unit = basePrice (price before pricelist discount)
          // discount = pricelist discount percentage
          // This way the UI correctly shows: subtotal = price_unit * (1 - discount%) * qty
          finalPrice = calcResult.basePrice;
          finalDiscount = calcResult.discount;
          logger.d(
            '[SaleOrderFormLines]',
            'Pricelist applied: basePrice=$finalPrice, discount=$finalDiscount%',
          );
        }
      } catch (e) {
        logger.e('[SaleOrderFormLines]', 'Error calculating price: $e');
      }
    }

    // Update the line
    final updatedLine = saleOrderLineCalculator.updateLineCalculations(
      line.copyWith(
        productId: productId,
        productName: productName,
        productCode: productCode,
        name: productName,
        productUomId: uomId,
        productUomName: uomName,
        // priceUnit: finalPrice, // Handled by updateLineCalculations
        // discount: finalDiscount, // Handled by updateLineCalculations
        // priceSubtotal: lineCalc.priceSubtotal, // Handled by updateLineCalculations
        // priceTax: lineCalc.priceTax, // Handled by updateLineCalculations
        // priceTotal: lineCalc.priceTotal, // Handled by updateLineCalculations
        taxIds: taxIdsStr,
        taxNames: taxNames,
        isUnitProduct: localProduct?.isUnitProduct ?? true,
      ),
      newPriceUnit: finalPrice,
      newDiscount: finalDiscount,
      taxPercent: taxPercent,
      newQuantity: 1.0, // Reset to 1 on product change
    );

    ref.read(saleOrderFormProvider.notifier).updateLine(updatedLine);
  }

  Future<void> selectProductForLine(
    BuildContext context,
    SaleOrderLine line, {
    String? initialSearch,
  }) async {
    if (!isLineEditingEnabled) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SelectProductDialog(initialSearch: initialSearch),
    );

    if (result == null) return;
    if (!context.mounted) return;

    await _applyProductSelection(context, line, result);
  }

  Future<void> showProductInfo(BuildContext context, SaleOrderLine line) async {
    if (line.productId == null) return;

    final formState = ref.read(saleOrderFormProvider);
    await showDialog(
      context: context,
      builder: (context) => ProductInfoDialog(
        productId: line.productId!,
        partnerId: formState.partnerId,
        partnerName: formState.partnerName,
        pricelistId: formState.pricelistId,
      ),
    );
  }

  /// Cleans product name by removing [code] prefix
  /// Odoo display_name format: "[HER0049] AMPERIMETRO DE GANCHO DIGITAL"
  /// Returns: "AMPERIMETRO DE GANCHO DIGITAL"
  String _cleanProductName(String name) {
    final regex = RegExp(r'^\[.*?\]\s*');
    return name.replaceFirst(regex, '');
  }
}
