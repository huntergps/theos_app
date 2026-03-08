import 'package:drift/drift.dart';

/// ResBank - Bancos disponibles en el sistema
class ResBank extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get bic => text().nullable()(); // Bank Identifier Code (SWIFT)
  IntColumn get countryId => integer().nullable()();
  TextColumn get countryName => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// ResPartnerBank - Cuentas bancarias de partners
class ResPartnerBank extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer()(); // Can be negative for local-only records
  TextColumn get accNumber => text()(); // Account number (required)
  TextColumn get accHolderName => text().nullable()(); // Account holder name
  IntColumn get partnerId => integer()(); // Owner of the bank account
  TextColumn get partnerName => text().nullable()(); // Cached partner name
  IntColumn get bankId => integer().nullable()(); // res.bank reference
  TextColumn get bankName => text().nullable()(); // Cached bank name
  IntColumn get companyId => integer().nullable()();
  IntColumn get currencyId => integer().nullable()();
  IntColumn get sequence => integer().withDefault(const Constant(10))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get allowOutPayment => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
  // Sync tracking
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
}

/// ResCompanyTable - Información extendida de compañías
class ResCompanyTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get vat => text().nullable()(); // RUC / Tax ID
  TextColumn get street => text().nullable()();
  TextColumn get street2 => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get zip => text().nullable()();
  IntColumn get countryId => integer().nullable()();
  TextColumn get countryName => text().nullable()();
  IntColumn get stateId => integer().nullable()();
  TextColumn get stateName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get mobile => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get logo => text().nullable()(); // Base64 encoded logo
  IntColumn get currencyId => integer().nullable()();
  TextColumn get currencyName => text().nullable()();
  IntColumn get parentId => integer().nullable()();
  TextColumn get parentName => text().nullable()();

  // Ecuador SRI fields
  TextColumn get l10nEcComercialName => text().nullable()();
  TextColumn get l10nEcLegalName => text().nullable()();
  BoolColumn get l10nEcProductionEnv => boolean().withDefault(const Constant(false))();

  // Document Layout fields
  TextColumn get reportHeaderImage => text().nullable()();
  TextColumn get reportFooter => text().nullable()();
  TextColumn get primaryColor => text().nullable()();
  TextColumn get secondaryColor => text().nullable()();
  TextColumn get font => text().nullable()();
  TextColumn get layoutBackground => text().nullable()();
  IntColumn get externalReportLayoutId => integer().nullable()();

  // Tax configuration
  TextColumn get taxCalculationRoundingMethod => text().withDefault(const Constant('round_per_line'))();

  // Sales Configuration
  IntColumn get quotationValidityDays => integer().withDefault(const Constant(30))();
  BoolColumn get portalConfirmationSign => boolean().withDefault(const Constant(false))();
  BoolColumn get portalConfirmationPay => boolean().withDefault(const Constant(false))();
  RealColumn get prepaymentPercent => real().withDefault(const Constant(0.0))();
  IntColumn get saleDiscountProductId => integer().nullable()();
  TextColumn get saleDiscountProductName => text().nullable()();
  BoolColumn get pedirEndCustomerData => boolean().withDefault(const Constant(false))();
  BoolColumn get pedirSaleReferrer => boolean().withDefault(const Constant(false))();
  BoolColumn get pedirTipoCanalCliente => boolean().withDefault(const Constant(false))();
  RealColumn get saleCustomerInvoiceLimitSri => real().nullable()();
  RealColumn get maxDiscountPercentage => real().withDefault(const Constant(100.0))();

  // Credit Control Configuration
  IntColumn get creditOverdueDaysThreshold => integer().withDefault(const Constant(0))();
  IntColumn get creditOverdueInvoicesThreshold => integer().withDefault(const Constant(0))();
  RealColumn get creditOfflineSafetyMargin => real().withDefault(const Constant(0.0))();
  IntColumn get creditDataMaxAgeHours => integer().withDefault(const Constant(24))();

  // Reservation Configuration
  IntColumn get reservationExpiryDays => integer().withDefault(const Constant(7))();
  IntColumn get reservationWarehouseId => integer().nullable()();
  TextColumn get reservationWarehouseName => text().nullable()();
  IntColumn get reservationLocationId => integer().nullable()();
  TextColumn get reservationLocationName => text().nullable()();
  BoolColumn get reserveFromQuotation => boolean().withDefault(const Constant(false))();

  // Sales defaults
  IntColumn get defaultPartnerId => integer().nullable()();
  TextColumn get defaultPartnerName => text().nullable()();
  IntColumn get defaultWarehouseId => integer().nullable()();
  TextColumn get defaultWarehouseName => text().nullable()();
  IntColumn get defaultPricelistId => integer().nullable()();
  TextColumn get defaultPricelistName => text().nullable()();
  IntColumn get defaultPaymentTermId => integer().nullable()();
  TextColumn get defaultPaymentTermName => text().nullable()();

  DateTimeColumn get writeDate => dateTime().nullable()();
}