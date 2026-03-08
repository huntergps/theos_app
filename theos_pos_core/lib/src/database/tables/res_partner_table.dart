import 'package:drift/drift.dart';

/// ResPartner table definition - Client/Partner data
///
/// This table stores all partner (client/customer) information synced from Odoo.
/// Used by PartnerManager and related services.
class ResPartner extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get ref => text().nullable()(); // Internal reference
  TextColumn get vat => text().nullable()(); // RUC/Tax ID
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get mobile => text().nullable()();
  TextColumn get street => text().nullable()();
  TextColumn get street2 => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get zip => text().nullable()();
  IntColumn get countryId => integer().nullable()();
  TextColumn get countryName => text().nullable()();
  IntColumn get stateId => integer().nullable()();
  TextColumn get stateName => text().nullable()();
  TextColumn get avatar128 => text().nullable()();
  BoolColumn get isCompany => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get parentId => integer().nullable()();
  TextColumn get parentName => text().nullable()();
  IntColumn get commercialPartnerId => integer().nullable()();
  TextColumn get commercialPartnerName => text().nullable()();
  IntColumn get propertyProductPricelistId => integer().nullable()();
  TextColumn get propertyProductPricelistName => text().nullable()();
  IntColumn get propertyPaymentTermId => integer().nullable()();
  TextColumn get propertyPaymentTermName => text().nullable()();
  TextColumn get lang => text().nullable()();
  TextColumn get comment => text().nullable()();

  // Credit Control Fields
  RealColumn get creditLimit => real().withDefault(const Constant(0.0))();
  RealColumn get credit => real().withDefault(const Constant(0.0))();
  RealColumn get creditToInvoice => real().withDefault(const Constant(0.0))();
  RealColumn get totalOverdue => real().withDefault(const Constant(0.0))();
  BoolColumn get allowOverCredit => boolean().withDefault(const Constant(false))();
  BoolColumn get usePartnerCreditLimit => boolean().withDefault(const Constant(false))();

  // Overdue Debt Fields
  IntColumn get overdueInvoicesCount => integer().withDefault(const Constant(0))();
  RealColumn get oldestOverdueDays => real().withDefault(const Constant(0))();

  // Ecuador-specific fields
  IntColumn get diasMaxFacturaPosterior => integer().nullable()();

  // Customer Classification (l10n_ec_sale_base)
  TextColumn get tipoCliente => text().nullable()();
  TextColumn get canalCliente => text().nullable()();

  // Ranking
  IntColumn get customerRank => integer().withDefault(const Constant(0))();
  IntColumn get supplierRank => integer().withDefault(const Constant(0))();

  // Check Acceptance
  BoolColumn get aceptaCheques => boolean().withDefault(const Constant(true))();

  // Invoice Configuration
  BoolColumn get emitirFacturaFechaPosterior => boolean().withDefault(const Constant(false))();
  BoolColumn get noInvoice => boolean().withDefault(const Constant(false))();
  IntColumn get lastDayToInvoice => integer().nullable()();

  // External ID
  TextColumn get externalId => text().nullable()();

  // Geolocation
  RealColumn get partnerLatitude => real().nullable()();
  RealColumn get partnerLongitude => real().nullable()();

  // Custom Payments
  BoolColumn get canUseCustomPayments => boolean().withDefault(const Constant(true))();

  // Sync fields
  TextColumn get partnerUuid => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
  DateTimeColumn get creditLastSyncDate => dateTime().nullable()();

  // Computed fields stored for performance
  RealColumn get creditAvailable => real().nullable()();
  RealColumn get creditUsagePercentage => real().nullable()();
  BoolColumn get creditExceeded => boolean().nullable()();
}
