import 'package:drift/drift.dart';

/// ProductCategory - Categorías jerárquicas de productos
class ProductCategory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get completeName => text().nullable()();
  IntColumn get parentId => integer().nullable()();
  TextColumn get parentName => text().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// AccountTax - Impuestos aplicables a productos y ventas
class AccountTax extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get typeTaxUse =>
      text().withDefault(const Constant('sale'))(); // sale, purchase, none
  TextColumn get amountType => text().withDefault(
    const Constant('percent'),
  )(); // percent, fixed, division
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get priceInclude => boolean().withDefault(const Constant(false))();
  BoolColumn get includeBaseAmount =>
      boolean().withDefault(const Constant(false))();
  IntColumn get sequence => integer().withDefault(const Constant(1))();
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  IntColumn get taxGroupId => integer().nullable()();
  TextColumn get taxGroupName => text().nullable()();
  TextColumn get taxGroupL10nEcType => text().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// UomUom - Unidades de medida base
class UomUom extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  IntColumn get categoryId => integer().nullable()();
  TextColumn get categoryName => text().nullable()();
  TextColumn get uomType => text().nullable()(); // reference, smaller, bigger
  RealColumn get factor => real().withDefault(const Constant(1.0))();
  RealColumn get factorInv => real().withDefault(const Constant(1.0))();
  RealColumn get rounding => real().withDefault(const Constant(0.01))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get sequence => integer().withDefault(const Constant(1))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// UomCategory - Categorías de unidades de medida
class UomCategory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// ProductUom - Unidades de medida específicas de productos
class ProductUom extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  IntColumn get productId => integer()();
  TextColumn get productName => text().nullable()();
  IntColumn get uomId => integer()();
  TextColumn get uomName => text().nullable()();
  RealColumn get factor => real().withDefault(const Constant(1.0))();
  RealColumn get factorInv => real().withDefault(const Constant(1.0))();
  TextColumn get barcode => text().nullable()(); // Barcode for this UoM
  IntColumn get companyId => integer().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}