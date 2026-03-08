import 'package:drift/drift.dart';

/// ProductPricelist - Listas de precios
class ProductPricelist extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get currencyId => integer().nullable()();
  TextColumn get currencyName => text().nullable()();
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  IntColumn get sequence => integer().withDefault(const Constant(16))();
  TextColumn get discountPolicy => text().nullable()(); // 'with_discount', 'without_discount'
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// ProductPricelistItem - Ítems individuales de listas de precios
class ProductPricelistItem extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  IntColumn get pricelistId => integer()();
  TextColumn get pricelistName => text().nullable()();
  IntColumn get sequence => integer().withDefault(const Constant(5))();
  TextColumn get appliedOn =>
      text()(); // '3_global', '2_product_category', '1_product', '0_product_variant'
  IntColumn get productId => integer().nullable()();
  TextColumn get productName => text().nullable()();
  IntColumn get productTmplId => integer().nullable()();
  TextColumn get productTmplName => text().nullable()();
  IntColumn get categId => integer().nullable()();
  TextColumn get categName => text().nullable()();
  RealColumn get minQuantity => real().withDefault(const Constant(0.0))();
  DateTimeColumn get dateStart => dateTime().nullable()();
  DateTimeColumn get dateEnd => dateTime().nullable()();
  TextColumn get computePrice =>
      text().withDefault(const Constant('fixed'))(); // 'fixed', 'percentage', 'formula'
  RealColumn get fixedPrice => real().withDefault(const Constant(0.0))();
  RealColumn get percentPrice => real().withDefault(const Constant(0.0))();
  TextColumn get base =>
      text()(); // 'list_price', 'standard_price', 'pricelist', 'fixed', 'percentage'
  IntColumn get basePricelistId => integer().nullable()();
  IntColumn get uomId => integer().nullable()();
  RealColumn get priceDiscount => real().withDefault(const Constant(0.0))();
  RealColumn get priceSurcharge => real().withDefault(const Constant(0.0))();
  RealColumn get priceRound => real().withDefault(const Constant(0.0))();
  RealColumn get priceMinMargin => real().withDefault(const Constant(0.0))();
  RealColumn get priceMaxMargin => real().withDefault(const Constant(0.0))();
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  IntColumn get currencyId => integer().nullable()();
  TextColumn get currencyName => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}