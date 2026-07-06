part of '../notification_provider.dart';

// ============================================================
// CATALOG (products, pricelists, UoM, categories, stock)
// WebSocket Sync Handlers
// ============================================================
//
// Extraído de notification_provider.dart (refactor de descomposición,
// plan aprobado por software-architect). Cero cambio de comportamiento:
// los métodos se movieron tal cual, solo cambia su ubicación física.

mixin _CatalogNotificationHandlers {
  /// Provisto por [NotificationCounterNotifier] (via `Notifier<T>`).
  Ref get ref;

  /// Provisto por [NotificationCounterNotifier].
  AppDatabase get _db;

  /// Handle product price updated notification
  /// Refreshes the specific product from Odoo and updates local DB
  /// Also updates denormalized productName in sale_order_line
  Future<void> _handleProductPriceUpdated(
    int productId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      if (catalogRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ CatalogSyncRepository not available for product refresh',
        );
        return;
      }

      // Sync the specific product from Odoo and get product data
      final productData = await catalogRepo.syncSingleProduct(productId);

      if (productData != null) {
        // Update denormalized productName in sale_order_line table
        final updatedLines = await catalogRepo.updateSaleOrderLinesProductName(
          productId,
          productData.name,
        );
        logger.d(
          '[NotificationProvider] ✅ Product $productId synced, updated $updatedLines sale order lines',
        );
      } else {
        logger.d(
          '[NotificationProvider] ⚠️ Product $productId sync returned no data (offline?)',
        );
      }
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling product price update: $e',
      );
    }
  }

  /// Handle pricelist item updated notification
  /// Refreshes pricelist items from Odoo and updates local DB
  Future<void> _handlePricelistItemUpdated(
    int pricelistItemId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      if (catalogRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ CatalogSyncRepository not available for pricelist refresh',
        );
        return;
      }

      final action = payload['action'] as String?;
      // Handle product_id: can be int, false (bool), or null
      final rawProductId = payload['product_id'];
      final productId = rawProductId is int ? rawProductId : null;

      // Also check product_tmpl_id for template-level pricelist items
      final rawProductTmplId = payload['product_tmpl_id'];
      final productTmplId = rawProductTmplId is int ? rawProductTmplId : null;

      if (action == 'deleted') {
        // Delete the pricelist item from local DB
        await catalogRepo.deletePricelistItem(pricelistItemId);
      } else {
        // Sync pricelist items for the affected product
        if (productId != null && productId > 0) {
          await catalogRepo.syncPricelistItemsForProduct(productId);
        } else if (productTmplId != null && productTmplId > 0) {
          // If product_id is false but we have template, sync products for this template
          // This handles cases where pricelist item applies to template (applied_on: 1_product)
          logger.d(
            '[NotificationProvider] 📦 Pricelist item for template $productTmplId - will sync on next full sync',
          );
        }
        // Skip full sync if no specific product - we can't do full sync without pricelistId
      }

      logger.d(
        '[NotificationProvider] ✅ Pricelist item $pricelistItemId ($action) synced',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling pricelist item update: $e',
      );
    }
  }

  /// Handle product UoM updated notification
  /// Refreshes product UoMs from Odoo and updates local DB
  Future<void> _handleProductUomUpdated(
    int uomId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      if (catalogRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ CatalogSyncRepository not available for UoM refresh',
        );
        return;
      }

      final action = payload['action'] as String?;
      // Handle product_id: can be int, false (bool), or null
      final rawProductId = payload['product_id'];
      final productId = rawProductId is int ? rawProductId : null;

      if (action == 'deleted') {
        // Delete the UoM from local DB
        await catalogRepo.deleteProductUom(uomId);
      } else {
        // Sync UoMs for the affected product
        if (productId != null && productId > 0) {
          await catalogRepo.syncProductUomsForProduct(productId);
        }
        // Skip full sync if no specific product - we sync UoMs per product only
      }

      logger.d('[NotificationProvider] ✅ Product UoM $uomId ($action) synced');
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling product UoM update: $e',
      );
    }
  }

  /// Handle standard uom.uom updated notification from Odoo
  /// This updates the UomUom table (standard Odoo UoM model)
  Future<void> _handleUomUomUpdated(
    int uomId,
    Map<String, dynamic> payload,
  ) async {
    final action = payload['action'] as String?;
    final values = payload['values'] as Map<String, dynamic>?;

    logger.i(
      '[NotificationProvider] 📏 Processing standard UoM update: '
      'id=$uomId, action=$action',
    );

    // Handle deletion
    if (action == 'deleted') {
      try {
        await uomManager.deleteLocal(uomId);
        logger.i('[NotificationProvider] ✅ Standard UoM deleted: $uomId');
      } catch (e) {
        logger.e('[NotificationProvider] Error deleting standard UoM: $e');
      }
      return;
    }

    // Handle create/update
    if (values == null) {
      logger.w('[NotificationProvider] No values in uom_uom_updated payload');
      return;
    }

    try {
      // Extract values from payload
      // NOTE: category_id, uom_type, factor_inv, rounding were removed in Odoo 19.2
      // Use safe defaults when absent to support both Odoo 19.1 and 19.2
      final name = values['name'] as String? ?? '';
      final categoryId = values['category_id'] as int? ?? 1;
      final categoryName = values['category_name'] as String?;
      final factor = (values['factor'] as num?)?.toDouble() ?? 1.0;
      final factorInv = (values['factor_inv'] as num?)?.toDouble() ?? 1.0;
      final uomTypeStr = values['uom_type'] as String? ?? 'reference';
      final rounding = (values['rounding'] as num?)?.toDouble() ?? 0.01;
      final active = values['active'] as bool? ?? true;
      final writeDateStr = values['write_date'] as String?;

      DateTime? writeDate;
      if (writeDateStr != null) {
        writeDate = DateTime.tryParse(writeDateStr);
      }

      final uomType = UomType.values.firstWhere(
        (t) => t.name == uomTypeStr,
        orElse: () => UomType.reference,
      );

      final uom = Uom(
        id: uomId,
        name: name,
        categoryId: categoryId,
        categoryName: categoryName,
        factor: factor,
        factorInv: factorInv,
        uomType: uomType,
        rounding: rounding,
        active: active,
        writeDate: writeDate,
      );

      await uomManager.upsertLocal(uom);

      logger.i(
        '[NotificationProvider] ✅ Standard UoM upserted: '
        'id=$uomId, name=$name, type=$uomTypeStr',
      );

      // Invalidate providers that depend on UoM data
      // Products provider invalidation handled elsewhere
    } catch (e) {
      logger.e('[NotificationProvider] Error upserting standard UoM: $e');
    }
  }

  /// Handle stock quant update notification from Odoo WebSocket
  /// Updates local StockByWarehouse table directly from WebSocket payload
  Future<void> _handleStockQuantUpdated(Map<String, dynamic> payload) async {
    try {
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      if (catalogRepo == null) {
        logger.d(
          '[NotificationProvider] ⚠️ CatalogSyncRepository not available for stock update',
        );
        return;
      }

      // Extract data from WebSocket payload
      final productId = payload['product_id'] as int;
      final productName = payload['product_name'] as String? ?? '';
      final defaultCode = payload['default_code'] as String?;
      final warehouseId = payload['warehouse_id'] as int;
      final warehouseName = payload['warehouse_name'] as String? ?? '';
      final quantity = (payload['quantity'] as num?)?.toDouble() ?? 0.0;
      final reservedQuantity =
          (payload['reserved_quantity'] as num?)?.toDouble() ?? 0.0;
      final availableQuantity =
          (payload['available_quantity'] as num?)?.toDouble() ?? 0.0;
      final operation = payload['operation'] as String?;
      final oldQuantity = (payload['old_quantity'] as num?)?.toDouble();

      // Update stock by warehouse table directly from WebSocket data
      final success = await catalogRepo.updateStockFromWebSocket(
        productId: productId,
        productName: productName,
        defaultCode: defaultCode,
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        quantity: quantity,
        reservedQuantity: reservedQuantity,
        availableQuantity: availableQuantity,
      );

      if (success) {
        // Record stock change for audit if there was a quantity change
        if (operation == 'update' && oldQuantity != null) {
          await catalogRepo.recordStockChange(
            productId: productId,
            productName: productName,
            defaultCode: defaultCode,
            warehouseId: warehouseId,
            warehouseName: warehouseName,
            oldQuantity: oldQuantity,
            newQuantity: quantity,
          );
        }

        // NOTE: No need to invalidate provider - StockByWarehouse table
        // is watched directly by UI components that display stock data.
        // Updating the Drift table automatically triggers UI rebuilds.

        logger.d(
          '[NotificationProvider] ✅ Stock updated for product $productId '
          '($productName) in warehouse $warehouseId: qty=$quantity',
        );
      }
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling stock quant update: $e',
      );
    }
  }

  /// Handle product category update notification from Odoo WebSocket
  /// Updates product category in local database
  Future<void> _handleProductCategoryUpdated(
    int categoryId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete product category from local DB
        await (db.delete(db.productCategory)
              ..where((t) => t.odooId.equals(categoryId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ ProductCategory $categoryId deleted locally');
        return;
      }

      if (values == null) return;

      // Extract values from payload
      // Note: Odoo sends `false` (not `null`) for empty Many2one fields,
      // so we use `is Type` checks instead of direct `as Type?` casts.
      final name = values['name'] is String ? values['name'] as String : '';
      final completeName = values['complete_name'] is String ? values['complete_name'] as String : null;
      final parentId = values['parent_id'] is List
          ? (values['parent_id'] as List).first as int?
          : values['parent_id'] is int ? values['parent_id'] as int : null;
      final parentName = values['parent_id'] is List && (values['parent_id'] as List).length > 1
          ? (values['parent_id'] as List)[1] as String?
          : values['parent_name'] is String ? values['parent_name'] as String : null;

      final companion = ProductCategoryCompanion.insert(
        odooId: categoryId,
        name: name,
        completeName: Value(completeName),
        parentId: Value(parentId),
        parentName: Value(parentName),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.productCategory).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.productCategory.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ ProductCategory $categoryId upserted: $name');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling product category update: $e');
    }
  }
}
