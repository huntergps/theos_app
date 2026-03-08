import 'package:drift/drift.dart';

/// StockWarehouse - Almacenes
class StockWarehouse extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  IntColumn get partnerId => integer().nullable()();
  TextColumn get partnerName => text().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// StockByWarehouse - Saldos de inventario por almacén
class StockByWarehouse extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer()();
  TextColumn get productName => text().nullable()();
  TextColumn get defaultCode => text().nullable()(); // Product internal reference
  IntColumn get warehouseId => integer()();
  TextColumn get warehouseName => text().nullable()();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  RealColumn get reservedQuantity => real().withDefault(const Constant(0.0))();
  RealColumn get availableQuantity => real().withDefault(const Constant(0.0))();
  RealColumn get listPrice => real().nullable()(); // Product list price at sync time
  RealColumn get standardPrice => real().nullable()(); // Product cost at sync time
  DateTimeColumn get lastUpdate => dateTime()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();

  /// Unique constraint on (productId, warehouseId) for upsert to work
  @override
  List<Set<Column>> get uniqueKeys => [
        {productId, warehouseId},
      ];
}

/// ProductPriceChange - Cambios de precio de productos
class ProductPriceChange extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer()();
  TextColumn get productName => text().nullable()();
  TextColumn get defaultCode => text().nullable()(); // Product internal reference
  TextColumn get changeType => text().withDefault(const Constant('both'))(); // list_price, standard_price, both
  RealColumn get oldPrice => real()();
  RealColumn get newPrice => real()();
  RealColumn get oldListPrice => real().nullable()();
  RealColumn get newListPrice => real().nullable()();
  RealColumn get oldStandardPrice => real().nullable()();
  RealColumn get newStandardPrice => real().nullable()();
  TextColumn get reason => text().nullable()();
  IntColumn get userId => integer().nullable()();
  TextColumn get userName => text().nullable()();
  DateTimeColumn get changeDate => dateTime()();
  DateTimeColumn get detectedAt => dateTime().nullable()(); // When change was detected
  BoolColumn get notifiedToUser => boolean().withDefault(const Constant(false))();
  DateTimeColumn get notifiedAt => dateTime().nullable()();
}

/// StockQuantityChange - Cambios de cantidad en inventario
class StockQuantityChange extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer()();
  TextColumn get productName => text().nullable()();
  TextColumn get defaultCode => text().nullable()(); // Product internal reference
  IntColumn get warehouseId => integer()();
  TextColumn get warehouseName => text().nullable()();
  RealColumn get oldQuantity => real()();
  RealColumn get newQuantity => real()();
  RealColumn get difference => real()();
  RealColumn get quantityChange => real().nullable()(); // Alias for difference
  TextColumn get reason => text().nullable()();
  IntColumn get userId => integer().nullable()();
  TextColumn get userName => text().nullable()();
  DateTimeColumn get changeDate => dateTime()();
  DateTimeColumn get detectedAt => dateTime().nullable()(); // When change was detected
  BoolColumn get notifiedToUser => boolean().withDefault(const Constant(false))();
  DateTimeColumn get notifiedAt => dateTime().nullable()();
}