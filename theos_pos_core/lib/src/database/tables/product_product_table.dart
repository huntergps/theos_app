import 'package:drift/drift.dart';

/// ProductProduct table definition - Product data
///
/// This table stores all product information synced from Odoo.
/// Used by ProductManager and related services.
class ProductProduct extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get defaultCode => text().nullable()(); // SKU/Barcode
  TextColumn get barcode => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get descriptionSale => text().nullable()();
  TextColumn get descriptionPurchase => text().nullable()();
  TextColumn get type => text().nullable()(); // 'product', 'service', 'consu'
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get saleOk => boolean().withDefault(const Constant(true))();
  BoolColumn get purchaseOk => boolean().withDefault(const Constant(true))();
  BoolColumn get canBeExpensed => boolean().withDefault(const Constant(false))();
  IntColumn get categId => integer().nullable()();
  TextColumn get categName => text().nullable()();
  IntColumn get uomId => integer().nullable()();
  TextColumn get uomName => text().nullable()();
  IntColumn get uomPoId => integer().nullable()();
  TextColumn get uomPoName => text().nullable()();
  RealColumn get lstPrice => real().nullable()(); // Sale price (Odoo field name)
  RealColumn get listPrice => real().nullable()(); // Sale price (alias)
  RealColumn get standardPrice => real().nullable()(); // Cost price
  RealColumn get weight => real().nullable()();
  RealColumn get volume => real().nullable()();
  BoolColumn get availableInPos => boolean().withDefault(const Constant(false))();
  TextColumn get posCategId => text().nullable()();
  TextColumn get posCategName => text().nullable()();
  TextColumn get image128 => text().nullable()();
  TextColumn get image1920 => text().nullable()();
  TextColumn get taxesId => text().nullable()(); // JSON array of tax IDs
  TextColumn get supplierTaxesId => text().nullable()(); // JSON array of tax IDs
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();

  // Product template relation
  IntColumn get productTmplId => integer().nullable()(); // Product template ID
  TextColumn get uomIds => text().nullable()(); // JSON array of UoM IDs

  // Tracking fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
  TextColumn get uuid => text().nullable()();

  // Stock quantities from Odoo
  RealColumn get qtyAvailable => real().withDefault(const Constant(0.0))();
  RealColumn get virtualAvailable => real().withDefault(const Constant(0.0))();

  // Ecuador-specific fields
  TextColumn get l10nEcAuxiliaryCode => text().nullable()(); // Código auxiliar Ecuador

  // Product tracking and storage
  TextColumn get tracking => text().nullable()(); // 'none', 'serial', 'lot'
  BoolColumn get isStorable => boolean().withDefault(const Constant(true))();
  BoolColumn get isUnitProduct => boolean().withDefault(const Constant(false))();
  BoolColumn get temporalNoDespachar => boolean().withDefault(const Constant(false))();

  // Computed fields stored for performance
  RealColumn get availableQuantity => real().nullable()();
  TextColumn get displayPrice => text().nullable()();
  BoolColumn get canBeSold => boolean().nullable()();
}
