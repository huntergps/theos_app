import 'package:drift/drift.dart' as drift;

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

/// Service for syncing stock quantities by warehouse and detecting changes (M7)
///
/// Features:
/// - Sync stock quantities by product and warehouse from Odoo
/// - Detect and log price changes
/// - Detect and log stock quantity changes
/// - Provide notifications for UI updates
/// - Incremental sync support (M10 improvement)
class StockSyncService {
  final OdooClient? _odooClient;
  final AppDatabase _db;

  /// Key for storing last stock sync timestamp in SyncMetadata
  static const String _lastStockSyncKey = 'last_stock_sync';

  StockSyncService(this._odooClient, this._db);

  /// Get the last stock sync timestamp
  Future<DateTime?> getLastStockSyncTime() async {
    final result = await (_db.select(
      _db.syncMetadata,
    )..where((tbl) => tbl.key.equals(_lastStockSyncKey))).getSingleOrNull();
    return result?.value != null ? DateTime.tryParse(result!.value) : null;
  }

  /// Update the last stock sync timestamp
  Future<void> _updateLastStockSyncTime(DateTime time) async {
    await _db
        .into(_db.syncMetadata)
        .insertOnConflictUpdate(
          SyncMetadataCompanion.insert(
            key: _lastStockSyncKey,
            value: time.toUtc().toIso8601String(),
          ),
        );
  }

  /// Sync stock quantities for all products from all warehouses
  ///
  /// If [incremental] is true (default), only syncs products modified since
  /// the last sync. This dramatically reduces sync time for large catalogs.
  ///
  /// Returns map with stats about the sync:
  /// - products_synced: number of products synced
  /// - warehouses_synced: number of warehouses synced
  /// - price_changes_detected: number of price changes detected
  /// - stock_changes_detected: number of stock changes detected
  /// - is_incremental: whether this was an incremental sync
  Future<Map<String, int>> syncAllStock({
    List<int>? warehouseIds,
    bool incremental = true,
  }) async {
    if (_odooClient == null) {
      logger.w('[StockSyncService] No Odoo client available');
      return {
        'products_synced': 0,
        'warehouses_synced': 0,
        'price_changes_detected': 0,
        'stock_changes_detected': 0,
        'is_incremental': 0,
      };
    }

    // Get last sync time for incremental sync
    DateTime? lastSyncTime;
    if (incremental) {
      lastSyncTime = await getLastStockSyncTime();
    }

    final syncStartTime = DateTime.now().toUtc();
    final isIncrementalSync = incremental && lastSyncTime != null;

    logger.d(
      '[StockSyncService] Starting ${isIncrementalSync ? 'incremental' : 'full'} stock sync'
      '${lastSyncTime != null ? ' (since ${lastSyncTime.toIso8601String()})' : ''}...',
    );

    try {
      // Get stock summary from Odoo with optional since filter
      final result = await _odooClient.call(
        model: 'stock.quant',
        method: 'get_stock_summary_by_warehouse',
        kwargs: {
          'product_ids': null, // All products
          'warehouse_ids': warehouseIds,
          'include_zero': false,
          // Pass since date for incremental sync (Odoo method must support this)
          if (isIncrementalSync)
            'since_date': lastSyncTime.toIso8601String(),
        },
      );

      if (result == null || result is! List) {
        logger.w('[StockSyncService] No stock data received');
        // Still update the sync time even if no data - server may have no changes
        await _updateLastStockSyncTime(syncStartTime);
        return {
          'products_synced': 0,
          'warehouses_synced': 0,
          'price_changes_detected': 0,
          'stock_changes_detected': 0,
          'is_incremental': isIncrementalSync ? 1 : 0,
        };
      }

      final stockData = result.cast<Map<String, dynamic>>();
      logger.d('[StockSyncService] Received ${stockData.length} stock records');

      int priceChanges = 0;
      int stockChanges = 0;
      final warehousesSeen = <int>{};
      final productsSeen = <int>{};
      final now = DateTime.now().toUtc();

      for (final record in stockData) {
        final productId = record['product_id'] as int;
        final warehouseId = record['warehouse_id'] as int;

        productsSeen.add(productId);
        warehousesSeen.add(warehouseId);

        // Get existing record
        final existing = await _getExistingStock(productId, warehouseId);

        // Detect price changes
        if (existing != null) {
          final oldListPrice = existing.listPrice ?? 0.0;
          final newListPrice =
              (record['list_price'] as num?)?.toDouble() ?? 0.0;
          final oldStandardPrice = existing.standardPrice ?? 0.0;
          final newStandardPrice =
              (record['standard_price'] as num?)?.toDouble() ?? 0.0;

          if ((oldListPrice - newListPrice).abs() > 0.001 ||
              (oldStandardPrice - newStandardPrice).abs() > 0.001) {
            await _logPriceChange(
              productId: productId,
              productName: record['product_name'] as String?,
              defaultCode: record['default_code'] as String?,
              oldListPrice: oldListPrice,
              newListPrice: newListPrice,
              oldStandardPrice: oldStandardPrice,
              newStandardPrice: newStandardPrice,
            );
            priceChanges++;
          }

          // Detect stock quantity changes
          final oldQty = existing.quantity;
          final newQty = (record['quantity'] as num?)?.toDouble() ?? 0.0;

          if ((oldQty - newQty).abs() > 0.001) {
            await _logStockChange(
              productId: productId,
              productName: record['product_name'] as String?,
              defaultCode: record['default_code'] as String?,
              warehouseId: warehouseId,
              warehouseName: record['warehouse_name'] as String?,
              oldQuantity: oldQty,
              newQuantity: newQty,
            );
            stockChanges++;
          }
        }

        // Upsert stock record
        await _upsertStock(
          productId: productId,
          productName: record['product_name'] as String?,
          defaultCode: record['default_code'] as String?,
          warehouseId: warehouseId,
          warehouseName: record['warehouse_name'] as String?,
          quantity: (record['quantity'] as num?)?.toDouble() ?? 0.0,
          reservedQuantity:
              (record['reserved_quantity'] as num?)?.toDouble() ?? 0.0,
          availableQuantity:
              (record['available_quantity'] as num?)?.toDouble() ?? 0.0,
          listPrice: (record['list_price'] as num?)?.toDouble() ?? 0.0,
          standardPrice: (record['standard_price'] as num?)?.toDouble() ?? 0.0,
          syncTime: now,
        );
      }

      // Update last sync timestamp
      await _updateLastStockSyncTime(syncStartTime);

      logger.d(
        '[StockSyncService] ${isIncrementalSync ? 'Incremental' : 'Full'} sync complete: '
        '${productsSeen.length} products, '
        '${warehousesSeen.length} warehouses, '
        '$priceChanges price changes, '
        '$stockChanges stock changes',
      );

      return {
        'products_synced': productsSeen.length,
        'warehouses_synced': warehousesSeen.length,
        'price_changes_detected': priceChanges,
        'stock_changes_detected': stockChanges,
        'is_incremental': isIncrementalSync ? 1 : 0,
      };
    } catch (e) {
      logger.e('[StockSyncService] Error syncing stock: $e');
      return {
        'products_synced': 0,
        'warehouses_synced': 0,
        'price_changes_detected': 0,
        'stock_changes_detected': 0,
        'is_incremental': isIncrementalSync ? 1 : 0,
        'error': 1,
      };
    }
  }

  /// Force a full stock sync (ignore last sync time)
  /// Use when you need to refresh all stock data from scratch
  Future<Map<String, int>> syncAllStockFull({List<int>? warehouseIds}) async {
    return syncAllStock(warehouseIds: warehouseIds, incremental: false);
  }

  /// Reset last sync time to force full sync on next call
  Future<void> resetLastSyncTime() async {
    await (_db.delete(
      _db.syncMetadata,
    )..where((tbl) => tbl.key.equals(_lastStockSyncKey))).go();
    logger.d(
      '[StockSyncService] Last sync time reset - next sync will be full',
    );
  }

  /// Get stock for a specific product across all warehouses
  Future<List<StockByWarehouseData>> getProductStock(int productId) async {
    return await (_db.select(
      _db.stockByWarehouse,
    )..where((tbl) => tbl.productId.equals(productId))).get();
  }

  /// Get stock for a specific warehouse
  Future<List<StockByWarehouseData>> getWarehouseStock(int warehouseId) async {
    return await (_db.select(
      _db.stockByWarehouse,
    )..where((tbl) => tbl.warehouseId.equals(warehouseId))).get();
  }

  /// Get all stock records
  Future<List<StockByWarehouseData>> getAllStock() async {
    return await _db.select(_db.stockByWarehouse).get();
  }

  /// Get pending price change notifications
  Future<List<ProductPriceChangeData>> getPendingPriceChanges() async {
    return await (_db.select(_db.productPriceChange)
          ..where((tbl) => tbl.notifiedToUser.equals(false))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.detectedAt)]))
        .get();
  }

  /// Watch pending price change notifications (reactive stream)
  Stream<List<ProductPriceChangeData>> watchPendingPriceChanges() {
    return (_db.select(_db.productPriceChange)
          ..where((tbl) => tbl.notifiedToUser.equals(false))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.detectedAt)]))
        .watch();
  }

  /// Get pending stock change notifications
  Future<List<StockQuantityChangeData>> getPendingStockChanges() async {
    return await (_db.select(_db.stockQuantityChange)
          ..where((tbl) => tbl.notifiedToUser.equals(false))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.detectedAt)]))
        .get();
  }

  /// Watch pending stock change notifications (reactive stream)
  Stream<List<StockQuantityChangeData>> watchPendingStockChanges() {
    return (_db.select(_db.stockQuantityChange)
          ..where((tbl) => tbl.notifiedToUser.equals(false))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.detectedAt)]))
        .watch();
  }

  /// Mark price change as notified
  Future<void> markPriceChangeNotified(int id) async {
    await (_db.update(
      _db.productPriceChange,
    )..where((tbl) => tbl.id.equals(id))).write(
      ProductPriceChangeCompanion(
        notifiedToUser: const drift.Value(true),
        notifiedAt: drift.Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Mark stock change as notified
  Future<void> markStockChangeNotified(int id) async {
    await (_db.update(
      _db.stockQuantityChange,
    )..where((tbl) => tbl.id.equals(id))).write(
      StockQuantityChangeCompanion(
        notifiedToUser: const drift.Value(true),
        notifiedAt: drift.Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Get change statistics
  Future<Map<String, dynamic>> getChangeStats({int days = 7}) async {
    final since = DateTime.now().subtract(Duration(days: days));

    final priceChanges = await (_db.select(
      _db.productPriceChange,
    )..where((tbl) => tbl.detectedAt.isBiggerOrEqualValue(since))).get();

    final stockChanges = await (_db.select(
      _db.stockQuantityChange,
    )..where((tbl) => tbl.detectedAt.isBiggerOrEqualValue(since))).get();

    return {
      'period_days': days,
      'price_changes_total': priceChanges.length,
      'stock_changes_total': stockChanges.length,
      'price_changes_unnotified': priceChanges
          .where((c) => !c.notifiedToUser)
          .length,
      'stock_changes_unnotified': stockChanges
          .where((c) => !c.notifiedToUser)
          .length,
    };
  }

  /// Clear old change records
  Future<int> clearOldChanges({int keepDays = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    int deleted = 0;

    // Delete old price changes
    deleted += await (_db.delete(
      _db.productPriceChange,
    )..where((tbl) => tbl.detectedAt.isSmallerThanValue(cutoffDate))).go();

    // Delete old stock changes
    deleted += await (_db.delete(
      _db.stockQuantityChange,
    )..where((tbl) => tbl.detectedAt.isSmallerThanValue(cutoffDate))).go();

    logger.d('[StockSyncService] Cleared $deleted old change records');
    return deleted;
  }

  // ============ Private Methods ============

  Future<StockByWarehouseData?> _getExistingStock(
    int productId,
    int warehouseId,
  ) async {
    return await (_db.select(_db.stockByWarehouse)..where(
          (tbl) =>
              tbl.productId.equals(productId) &
              tbl.warehouseId.equals(warehouseId),
        ))
        .getSingleOrNull();
  }

  Future<void> _upsertStock({
    required int productId,
    String? productName,
    String? defaultCode,
    required int warehouseId,
    String? warehouseName,
    required double quantity,
    required double reservedQuantity,
    required double availableQuantity,
    required double listPrice,
    required double standardPrice,
    required DateTime syncTime,
  }) async {
    final existing = await _getExistingStock(productId, warehouseId);

    if (existing != null) {
      // Update
      await (_db.update(
        _db.stockByWarehouse,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        StockByWarehouseCompanion(
          productName: drift.Value(productName),
          defaultCode: drift.Value(defaultCode),
          warehouseName: drift.Value(warehouseName),
          quantity: drift.Value(quantity),
          reservedQuantity: drift.Value(reservedQuantity),
          availableQuantity: drift.Value(availableQuantity),
          listPrice: drift.Value(listPrice),
          standardPrice: drift.Value(standardPrice),
          lastSyncAt: drift.Value(syncTime),
          writeDate: drift.Value(syncTime),
        ),
      );
    } else {
      // Insert
      await _db
          .into(_db.stockByWarehouse)
          .insert(
            StockByWarehouseCompanion.insert(
              productId: productId,
              lastUpdate: syncTime,
              productName: drift.Value(productName),
              defaultCode: drift.Value(defaultCode),
              warehouseId: warehouseId,
              warehouseName: drift.Value(warehouseName),
              quantity: drift.Value(quantity),
              reservedQuantity: drift.Value(reservedQuantity),
              availableQuantity: drift.Value(availableQuantity),
              listPrice: drift.Value(listPrice),
              standardPrice: drift.Value(standardPrice),
              lastSyncAt: drift.Value(syncTime),
              writeDate: drift.Value(syncTime),
            ),
          );
    }
  }

  Future<void> _logPriceChange({
    required int productId,
    String? productName,
    String? defaultCode,
    required double oldListPrice,
    required double newListPrice,
    required double oldStandardPrice,
    required double newStandardPrice,
  }) async {
    String changeType = 'both';
    if ((oldListPrice - newListPrice).abs() > 0.001 &&
        (oldStandardPrice - newStandardPrice).abs() <= 0.001) {
      changeType = 'list_price';
    } else if ((oldListPrice - newListPrice).abs() <= 0.001 &&
        (oldStandardPrice - newStandardPrice).abs() > 0.001) {
      changeType = 'standard_price';
    }

    await _db
        .into(_db.productPriceChange)
        .insert(
          ProductPriceChangeCompanion.insert(
            productId: productId,
            productName: drift.Value(productName),
            defaultCode: drift.Value(defaultCode),
            changeType: drift.Value(changeType),
            oldPrice: changeType == 'list_price' ? oldListPrice : oldStandardPrice,
            newPrice: changeType == 'list_price' ? newListPrice : newStandardPrice,
            changeDate: DateTime.now().toUtc(),
            oldListPrice: drift.Value(oldListPrice),
            newListPrice: drift.Value(newListPrice),
            oldStandardPrice: drift.Value(oldStandardPrice),
            newStandardPrice: drift.Value(newStandardPrice),
            detectedAt: drift.Value(DateTime.now().toUtc()),
          ),
        );

    logger.d(
      '[StockSyncService] Price change detected: '
      'product=$productId, type=$changeType, '
      'list: $oldListPrice -> $newListPrice, '
      'cost: $oldStandardPrice -> $newStandardPrice',
    );
  }

  Future<void> _logStockChange({
    required int productId,
    String? productName,
    String? defaultCode,
    required int warehouseId,
    String? warehouseName,
    required double oldQuantity,
    required double newQuantity,
  }) async {
    await _db
        .into(_db.stockQuantityChange)
        .insert(
          StockQuantityChangeCompanion.insert(
            productId: productId,
            productName: drift.Value(productName),
            defaultCode: drift.Value(defaultCode),
            warehouseId: warehouseId,
            warehouseName: drift.Value(warehouseName),
            oldQuantity: oldQuantity,
            newQuantity: newQuantity,
            difference: newQuantity - oldQuantity,
            changeDate: DateTime.now().toUtc(),
            quantityChange: drift.Value(newQuantity - oldQuantity),
            detectedAt: drift.Value(DateTime.now().toUtc()),
          ),
        );

    logger.d(
      '[StockSyncService] Stock change detected: '
      'product=$productId, warehouse=$warehouseId, '
      'qty: $oldQuantity -> $newQuantity (${newQuantity - oldQuantity > 0 ? '+' : ''}${newQuantity - oldQuantity})',
    );
  }
}
