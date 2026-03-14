import 'package:drift/drift.dart';

/// AccountMove - Asientos contables
class AccountMove extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text().nullable()();
  TextColumn get ref => text().nullable()();
  TextColumn get invoiceOrigin => text().nullable()();
  IntColumn get saleOrderId => integer().nullable()();
  TextColumn get moveType => text()(); // out_invoice, in_invoice, out_refund, in_refund, entry
  TextColumn get state => text().withDefault(const Constant('draft'))();
  DateTimeColumn get date => dateTime().nullable()();
  DateTimeColumn get invoiceDate => dateTime().nullable()();
  DateTimeColumn get invoiceDateDue => dateTime().nullable()();
  IntColumn get partnerId => integer().nullable()();
  TextColumn get partnerName => text().nullable()();
  TextColumn get partnerVat => text().nullable()();
  IntColumn get journalId => integer().nullable()();
  TextColumn get journalName => text().nullable()();
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  IntColumn get currencyId => integer().nullable()();
  TextColumn get currencyName => text().nullable()();
  RealColumn get amountUntaxed => real().withDefault(const Constant(0.0))();
  RealColumn get amountTax => real().withDefault(const Constant(0.0))();
  RealColumn get amountTotal => real().withDefault(const Constant(0.0))();
  RealColumn get amountResidual => real().withDefault(const Constant(0.0))();
  TextColumn get paymentState => text().withDefault(const Constant('not_paid'))();

  // Partner contact fields (denormalized for offline display)
  TextColumn get partnerStreet => text().nullable()();
  TextColumn get partnerCity => text().nullable()();
  TextColumn get partnerPhone => text().nullable()();
  TextColumn get partnerEmail => text().nullable()();

  // Currency display
  TextColumn get currencySymbol => text().nullable()();

  // Ecuador localization fields
  DateTimeColumn get l10nEcAuthorizationDate => dateTime().nullable()();
  TextColumn get l10nEcAuthorizationNumber => text().nullable()();
  TextColumn get l10nLatamDocumentNumber => text().nullable()();
  IntColumn get l10nLatamDocumentTypeId => integer().nullable()();
  TextColumn get l10nLatamDocumentTypeName => text().nullable()();
  TextColumn get l10nEcSriPaymentName => text().nullable()();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// AccountMoveLine - Líneas de asientos contables
class AccountMoveLine extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  IntColumn get moveId => integer()();
  TextColumn get moveName => text().nullable()();
  IntColumn get accountId => integer()();
  TextColumn get accountName => text().nullable()();
  IntColumn get partnerId => integer().nullable()();
  TextColumn get partnerName => text().nullable()();
  TextColumn get name => text()();
  TextColumn get displayType => text().nullable()(); // line_section, line_note, product
  IntColumn get sequence => integer().withDefault(const Constant(10))();

  // Product fields
  IntColumn get productId => integer().nullable()();
  TextColumn get productName => text().nullable()();
  TextColumn get productCode => text().nullable()();
  TextColumn get productBarcode => text().nullable()();
  TextColumn get productL10nEcAuxiliaryCode => text().nullable()();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  IntColumn get productUomId => integer().nullable()();
  TextColumn get productUomName => text().nullable()();
  RealColumn get priceUnit => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get priceSubtotal => real().withDefault(const Constant(0.0))();
  RealColumn get priceTotal => real().withDefault(const Constant(0.0))();

  // Tax fields
  TextColumn get taxIds => text().nullable()(); // Comma-separated tax IDs
  TextColumn get taxNames => text().nullable()(); // Comma-separated tax names
  IntColumn get taxLineId => integer().nullable()();
  TextColumn get taxLineName => text().nullable()();

  // Accounting fields
  RealColumn get debit => real().withDefault(const Constant(0.0))();
  RealColumn get credit => real().withDefault(const Constant(0.0))();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  IntColumn get currencyId => integer().nullable()();
  TextColumn get currencyName => text().nullable()();
  RealColumn get amountCurrency => real().nullable()();
  DateTimeColumn get date => dateTime()();
  IntColumn get journalId => integer()();
  TextColumn get journalName => text().nullable()();
  IntColumn get companyId => integer()();
  TextColumn get companyName => text().nullable()();

  // Report display fields
  BoolColumn get collapseComposition => boolean().withDefault(const Constant(false))();
  BoolColumn get collapsePrices => boolean().withDefault(const Constant(false))();
  TextColumn get productType => text().nullable()();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// AccountPaymentTerm - Plazos de pago
class AccountPaymentTerm extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get note => text().nullable()();
  IntColumn get sequence => integer().withDefault(const Constant(10))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get isCash => boolean().withDefault(const Constant(false))();
  BoolColumn get isCredit => boolean().withDefault(const Constant(false))();
  IntColumn get dueDays => integer().withDefault(const Constant(0))(); // Days until payment due
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// AccountFiscalPosition - Posiciones fiscales
class AccountFiscalPosition extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  IntColumn get sequence => integer().withDefault(const Constant(10))();
  TextColumn get note => text().nullable()();
  BoolColumn get autoApply => boolean().withDefault(const Constant(false))();
  IntColumn get countryId => integer().nullable()();
  TextColumn get countryName => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// AccountFiscalPositionTax - Impuestos por posición fiscal
class AccountFiscalPositionTax extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  IntColumn get positionId => integer()();
  TextColumn get positionName => text().nullable()();
  IntColumn get taxSrcId => integer()();
  TextColumn get taxSrcName => text().nullable()();
  IntColumn get taxDestId => integer()();
  TextColumn get taxDestName => text().nullable()();
  IntColumn get companyId => integer().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// CrmTeam - Equipos de ventas
class CrmTeam extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  IntColumn get userId => integer().nullable()();
  TextColumn get userName => text().nullable()();
  IntColumn get sequence => integer().withDefault(const Constant(10))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}