import 'package:drift/drift.dart';

/// CollectionConfig - Configuración de puntos de cobro
class CollectionConfig extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  IntColumn get companyId => integer()();
  TextColumn get companyName => text().nullable()();
  IntColumn get currencyId => integer().nullable()();
  TextColumn get currencyName => text().nullable()();
  IntColumn get journalId => integer().nullable()();
  TextColumn get journalName => text().nullable()();
  IntColumn get cashJournalId => integer().nullable()();
  TextColumn get cashJournalName => text().nullable()();
  TextColumn get allowedJournalIds => text().nullable()(); // JSON array
  IntColumn get cashDifferenceAccountId => integer().nullable()();
  BoolColumn get setMaximumDifference => boolean().withDefault(const Constant(false))();
  RealColumn get amountAuthorizedDiff => real().withDefault(const Constant(0.0))();
  TextColumn get userIds => text().nullable()(); // JSON array
  IntColumn get currentSessionId => integer().nullable()();
  TextColumn get currentSessionState => text().nullable()();
  TextColumn get currentSessionName => text().nullable()();
  IntColumn get numberOfOpenedSession => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSessionClosingDate => dateTime().nullable()();
  RealColumn get lastSessionClosingCash => real().withDefault(const Constant(0.0))();
  TextColumn get collectionSessionUsername => text().nullable()();
  TextColumn get currentSessionStateDisplay => text().nullable()();
  IntColumn get numberOfRescueSession => integer().withDefault(const Constant(0))();
  TextColumn get state => text().withDefault(const Constant('active'))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// CollectionSession - Sesiones de cobro
class CollectionSession extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get sessionUuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get state => text().withDefault(const Constant('opening_control'))();
  IntColumn get configId => integer()();
  TextColumn get configName => text().nullable()();
  IntColumn get companyId => integer()();
  TextColumn get companyName => text().nullable()();
  IntColumn get userId => integer()();
  TextColumn get userName => text().nullable()();
  IntColumn get currencyId => integer()();
  TextColumn get currencySymbol => text().nullable()();
  IntColumn get cashJournalId => integer().nullable()();
  TextColumn get cashJournalName => text().nullable()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get stopAt => dateTime().nullable()();
  RealColumn get cashRegisterBalanceStart => real().withDefault(const Constant(0.0))();
  RealColumn get cashRegisterBalanceEndReal => real().withDefault(const Constant(0.0))();
  RealColumn get cashRegisterBalanceEnd => real().withDefault(const Constant(0.0))();
  RealColumn get cashRegisterDifference => real().withDefault(const Constant(0.0))();
  IntColumn get orderCount => integer().withDefault(const Constant(0))();
  IntColumn get invoiceCount => integer().withDefault(const Constant(0))();
  IntColumn get paymentCount => integer().withDefault(const Constant(0))();
  IntColumn get advanceCount => integer().withDefault(const Constant(0))();
  IntColumn get chequeRecibidoCount => integer().withDefault(const Constant(0))();
  IntColumn get cashOutCount => integer().withDefault(const Constant(0))();
  IntColumn get depositCount => integer().withDefault(const Constant(0))();
  IntColumn get withholdCount => integer().withDefault(const Constant(0))();
  RealColumn get totalPaymentsAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalCashOutAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalDepositAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalWithholdAmount => real().withDefault(const Constant(0.0))();
  RealColumn get cashOutSecurityTotal => real().withDefault(const Constant(0.0))();
  RealColumn get cashOutInvoiceTotal => real().withDefault(const Constant(0.0))();
  RealColumn get cashOutRefundTotal => real().withDefault(const Constant(0.0))();
  RealColumn get cashOutWithholdTotal => real().withDefault(const Constant(0.0))();
  RealColumn get cashOutOtherTotal => real().withDefault(const Constant(0.0))();
  RealColumn get checksOnDayTotal => real().withDefault(const Constant(0.0))();
  RealColumn get checksPostdatedTotal => real().withDefault(const Constant(0.0))();
  RealColumn get totalCash => real().withDefault(const Constant(0.0))();
  RealColumn get totalCards => real().withDefault(const Constant(0.0))();
  RealColumn get totalTransfers => real().withDefault(const Constant(0.0))();
  RealColumn get totalChecksDay => real().withDefault(const Constant(0.0))();
  RealColumn get totalChecksPost => real().withDefault(const Constant(0.0))();
  RealColumn get totalGeneral => real().withDefault(const Constant(0.0))();

  // Fact (Facturas) payment method totals
  RealColumn get factCash => real().withDefault(const Constant(0.0))();
  RealColumn get factCards => real().withDefault(const Constant(0.0))();
  RealColumn get factTransfers => real().withDefault(const Constant(0.0))();
  RealColumn get factChecksDay => real().withDefault(const Constant(0.0))();
  RealColumn get factChecksPost => real().withDefault(const Constant(0.0))();
  RealColumn get factTotal => real().withDefault(const Constant(0.0))();

  // Cartera (Cartera) payment method totals
  RealColumn get carteraCash => real().withDefault(const Constant(0.0))();
  RealColumn get carteraCards => real().withDefault(const Constant(0.0))();
  RealColumn get carteraTransfers => real().withDefault(const Constant(0.0))();
  RealColumn get carteraChecksDay => real().withDefault(const Constant(0.0))();
  RealColumn get carteraChecksPost => real().withDefault(const Constant(0.0))();
  RealColumn get carteraTotal => real().withDefault(const Constant(0.0))();

  // Anticipo (Advance) payment method totals
  RealColumn get anticipoCash => real().withDefault(const Constant(0.0))();
  RealColumn get anticipoCards => real().withDefault(const Constant(0.0))();
  RealColumn get anticipoTransfers => real().withDefault(const Constant(0.0))();
  RealColumn get anticipoChecksDay => real().withDefault(const Constant(0.0))();
  RealColumn get anticipoChecksPost => real().withDefault(const Constant(0.0))();
  RealColumn get anticipoTotal => real().withDefault(const Constant(0.0))();

  IntColumn get supervisorId => integer().nullable()();
  TextColumn get supervisorName => text().nullable()();
  DateTimeColumn get supervisorValidationDate => dateTime().nullable()();
  TextColumn get supervisorNotes => text().nullable()();
  TextColumn get openingNotes => text().nullable()();
  TextColumn get closingNotes => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();
  IntColumn get syncRetryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// CollectionSessionCash - Saldos de efectivo por sesión
class CollectionSessionCash extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  IntColumn get sessionId => integer()();
  IntColumn get collectionSessionId => integer()(); // Alias for sessionId
  TextColumn get denomination => text().nullable()(); // 100, 50, 20, 10, 5, 1, 0.50, 0.25, etc.
  TextColumn get cashType => text().nullable()(); // opening, closing
  IntColumn get count => integer().withDefault(const Constant(0))();
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  // Individual denomination fields (legacy/compatibility)
  IntColumn get bills100 => integer().withDefault(const Constant(0))();
  IntColumn get bills50 => integer().withDefault(const Constant(0))();
  IntColumn get bills20 => integer().withDefault(const Constant(0))();
  IntColumn get bills10 => integer().withDefault(const Constant(0))();
  IntColumn get bills5 => integer().withDefault(const Constant(0))();
  IntColumn get bills1 => integer().withDefault(const Constant(0))();
  IntColumn get coins1 => integer().withDefault(const Constant(0))();
  IntColumn get coins50 => integer().withDefault(const Constant(0))();
  IntColumn get coins25 => integer().withDefault(const Constant(0))();
  IntColumn get coins10 => integer().withDefault(const Constant(0))();
  IntColumn get coins5 => integer().withDefault(const Constant(0))();
  IntColumn get coins1Cent => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// CollectionSessionDeposit - Depósitos realizados en sesión
class CollectionSessionDeposit extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique().nullable()();
  IntColumn get sessionId => integer()();
  IntColumn get collectionSessionId => integer()(); // Alias for sessionId
  TextColumn get depositType => text()(); // bank, cash, check
  TextColumn get type => text().nullable()(); // Alias for depositType
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  TextColumn get reference => text().nullable()();
  TextColumn get number => text().nullable()(); // Alias for reference
  IntColumn get bankId => integer().nullable()();
  TextColumn get bankName => text().nullable()();
  DateTimeColumn get depositDate => dateTime()();
  DateTimeColumn get date => dateTime().nullable()(); // Alias for depositDate
  TextColumn get state => text().withDefault(const Constant('draft'))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// CashOut - Salidas de caja
class CashOut extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique().nullable()();
  IntColumn get sessionId => integer()();
  IntColumn get collectionSessionId => integer()(); // Alias for sessionId (backwards compatibility)
  TextColumn get cashOutType => text()(); // security, invoice, refund, withhold, other
  TextColumn get type => text().nullable()(); // Alias for cashOutType
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  TextColumn get description => text().nullable()();
  TextColumn get name => text().nullable()(); // Alias for description
  TextColumn get note => text().nullable()(); // Additional notes
  DateTimeColumn get date => dateTime().nullable()();
  TextColumn get uuid => text().nullable()();
  IntColumn get approvedById => integer().nullable()();
  TextColumn get approvedByName => text().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  TextColumn get state => text().withDefault(const Constant('draft'))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// CashOutType - Tipos de salida de caja
class CashOutType extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  IntColumn get sequence => integer().withDefault(const Constant(10))();
  TextColumn get description => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get requiresApproval => boolean().withDefault(const Constant(false))();
  RealColumn get maxAmount => real().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}