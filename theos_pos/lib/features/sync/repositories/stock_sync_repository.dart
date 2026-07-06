/// StockSyncRepository - Actualización de stock por WebSocket + auditoría
///
/// Extraído de CatalogSyncRepository (Fase E2).
library;

import 'package:drift/drift.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

/// Repository for stock quantity updates (from WebSocket push) and their
/// audit trail (`StockQuantityChange`).
class StockSyncRepository {
  final AppDatabase _appDb;

  StockSyncRepository({required AppDatabase appDb}) : _appDb = appDb;

  /// Update stock from WebSocket notification
  Future<bool> updateStockFromWebSocket({
    required int productId,
    required String productName,
    String? defaultCode,
    required int warehouseId,
    required String warehouseName,
    required double quantity,
    required double reservedQuantity,
    required double availableQuantity,
  }) async {
    try {
      await _appDb
          .into(_appDb.stockByWarehouse)
          .insertOnConflictUpdate(
            StockByWarehouseCompanion(
              productId: Value(productId),
              productName: Value(productName),
              defaultCode: Value(defaultCode),
              warehouseId: Value(warehouseId),
              warehouseName: Value(warehouseName),
              quantity: Value(quantity),
              reservedQuantity: Value(reservedQuantity),
              availableQuantity: Value(availableQuantity),
              lastSyncAt: Value(DateTime.now()),
            ),
          );
      return true;
    } catch (e) {
      logger.e('[CatalogSync]', 'Error updating stock from WebSocket', e);
      return false;
    }
  }

  /// Record a stock change for audit purposes
  Future<void> recordStockChange({
    required int productId,
    required String productName,
    String? defaultCode,
    required int warehouseId,
    required String warehouseName,
    required double oldQuantity,
    required double newQuantity,
  }) async {
    try {
      await _appDb
          .into(_appDb.stockQuantityChange)
          .insert(
            StockQuantityChangeCompanion(
              productId: Value(productId),
              productName: Value(productName),
              defaultCode: Value(defaultCode),
              warehouseId: Value(warehouseId),
              warehouseName: Value(warehouseName),
              oldQuantity: Value(oldQuantity),
              newQuantity: Value(newQuantity),
              quantityChange: Value(newQuantity - oldQuantity),
              detectedAt: Value(DateTime.now()),
            ),
          );
    } catch (e) {
      logger.e('[CatalogSync]', 'Error recording stock change', e);
    }
  }
}
