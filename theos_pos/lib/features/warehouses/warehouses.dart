/// Warehouses feature module
///
/// Centralizes all warehouse-related functionality.
///
/// **Models:**
/// - [Warehouse] - Freezed model wrapping StockWarehouseData
///
/// **Providers:**
/// - [warehousesProvider] - All warehouses
/// - [warehouseByIdProvider] - Warehouse by ID
/// - [currentWarehouseProvider] - Current user's warehouse
library;

export 'providers/providers.dart';
