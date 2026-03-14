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
  RealColumn get advanceChecksOnDayTotal => real().withDefault(const Constant(0.0))();
  RealColumn get advanceChecksPostdatedTotal => real().withDefault(const Constant(0.0))();
  RealColumn get totalChecksOnDay => real().withDefault(const Constant(0.0))();
  RealColumn get totalChecksPostdated => real().withDefault(const Constant(0.0))();
  RealColumn get totalCashAdvanceAmount => real().withDefault(const Constant(0.0))();

  // Deposits breakdown
  RealColumn get systemDepositsCashTotal => real().withDefault(const Constant(0.0))();
  RealColumn get manualDepositsCashTotal => real().withDefault(const Constant(0.0))();
  RealColumn get diffDepositsCashTotal => real().withDefault(const Constant(0.0))();
  RealColumn get systemDepositsChecksTotal => real().withDefault(const Constant(0.0))();
  RealColumn get manualDepositsChecksTotal => real().withDefault(const Constant(0.0))();
  RealColumn get diffDepositsChecksTotal => real().withDefault(const Constant(0.0))();

  // Cash and credit totals
  RealColumn get totalCashInvoicesAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalCashCollectedAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalCashPendingAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalCreditOrdersAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalCreditInvoicesAmount => real().withDefault(const Constant(0.0))();
  RealColumn get creditSalesDifference => real().withDefault(const Constant(0.0))();

  // System totals by payment method
  RealColumn get systemChecksOnDay => real().withDefault(const Constant(0.0))();
  RealColumn get systemChecksPostdated => real().withDefault(const Constant(0.0))();
  RealColumn get systemCardsTotal => real().withDefault(const Constant(0.0))();
  RealColumn get systemTransfersTotal => real().withDefault(const Constant(0.0))();
  RealColumn get systemAdvancesTotal => real().withDefault(const Constant(0.0))();
  RealColumn get systemCreditNotesTotal => real().withDefault(const Constant(0.0))();

  // Manual totals by payment method
  RealColumn get manualChecksOnDay => real().withDefault(const Constant(0.0))();
  RealColumn get manualChecksPostdated => real().withDefault(const Constant(0.0))();
  RealColumn get manualCardsTotal => real().withDefault(const Constant(0.0))();
  RealColumn get manualTransfersTotal => real().withDefault(const Constant(0.0))();
  RealColumn get manualAdvancesTotal => real().withDefault(const Constant(0.0))();
  RealColumn get manualCreditNotesTotal => real().withDefault(const Constant(0.0))();
  RealColumn get manualWithholdsTotal => real().withDefault(const Constant(0.0))();

  // Difference totals by payment method
  RealColumn get diffChecksOnDay => real().withDefault(const Constant(0.0))();
  RealColumn get diffChecksPostdated => real().withDefault(const Constant(0.0))();
  RealColumn get diffCardsTotal => real().withDefault(const Constant(0.0))();
  RealColumn get diffTransfersTotal => real().withDefault(const Constant(0.0))();
  RealColumn get diffAdvancesTotal => real().withDefault(const Constant(0.0))();
  RealColumn get diffCreditNotesTotal => real().withDefault(const Constant(0.0))();
  RealColumn get diffWithholdsTotal => real().withDefault(const Constant(0.0))();

  // Summary totals
  RealColumn get summarySystemTotal => real().withDefault(const Constant(0.0))();
  RealColumn get summaryManualTotal => real().withDefault(const Constant(0.0))();
  RealColumn get summaryDiffTotal => real().withDefault(const Constant(0.0))();

  // Deposit breakdowns by category
  RealColumn get factDepositsCash => real().withDefault(const Constant(0.0))();
  RealColumn get factDepositsChecks => real().withDefault(const Constant(0.0))();
  RealColumn get carteraDepositsCash => real().withDefault(const Constant(0.0))();
  RealColumn get carteraDepositsChecks => real().withDefault(const Constant(0.0))();
  RealColumn get anticipoDepositsCash => real().withDefault(const Constant(0.0))();
  RealColumn get anticipoDepositsChecks => real().withDefault(const Constant(0.0))();

  // Advances used
  RealColumn get factAdvancesUsed => real().withDefault(const Constant(0.0))();
  RealColumn get carteraAdvancesUsed => real().withDefault(const Constant(0.0))();
  RealColumn get summaryAdvancesUsedTotal => real().withDefault(const Constant(0.0))();

  // Fact total with NC and withholds
  RealColumn get factTotalWithNcWithholds => real().withDefault(const Constant(0.0))();

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
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// CollectionSessionDeposit - Depósitos realizados en sesión
class CollectionSessionDeposit extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique().nullable()();
  TextColumn get uuid => text().nullable()();
  IntColumn get sessionId => integer()();
  IntColumn get collectionSessionId => integer()(); // Alias for sessionId
  TextColumn get name => text().nullable()();
  TextColumn get depositType => text()(); // bank, cash, check
  TextColumn get type => text().nullable()(); // Alias for depositType
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  TextColumn get reference => text().nullable()();
  TextColumn get number => text().nullable()(); // Alias for reference
  TextColumn get sessionUuid => text().nullable()();
  IntColumn get userId => integer().nullable()();
  TextColumn get userName => text().nullable()();
  DateTimeColumn get depositDate => dateTime()();
  DateTimeColumn get date => dateTime().nullable()(); // Alias for depositDate
  DateTimeColumn get accountingDate => dateTime().nullable()();
  RealColumn get cashAmount => real().withDefault(const Constant(0.0))();
  RealColumn get checkAmount => real().withDefault(const Constant(0.0))();
  IntColumn get checkCount => integer().withDefault(const Constant(0))();
  IntColumn get bankJournalId => integer().nullable()();
  TextColumn get bankJournalName => text().nullable()();
  IntColumn get bankId => integer().nullable()();
  TextColumn get bankName => text().nullable()();
  TextColumn get state => text().withDefault(const Constant('draft'))();
  TextColumn get depositSlipNumber => text().nullable()();
  TextColumn get bankReference => text().nullable()();
  IntColumn get moveId => integer().nullable()();
  TextColumn get depositorName => text().nullable()();
  TextColumn get notes => text().nullable()();
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
  TextColumn get cashFlow => text().withDefault(const Constant('out'))(); // out, in
  IntColumn get journalId => integer().withDefault(const Constant(0))();
  TextColumn get journalName => text().nullable()();
  IntColumn get partnerId => integer().nullable()();
  TextColumn get partnerName => text().nullable()();
  IntColumn get accountIdManual => integer().nullable()();
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  TextColumn get description => text().nullable()();
  TextColumn get name => text().nullable()(); // Alias for description
  TextColumn get note => text().nullable()(); // Additional notes
  DateTimeColumn get date => dateTime().nullable()();
  TextColumn get uuid => text().nullable()();
  IntColumn get approvedById => integer().nullable()();
  TextColumn get approvedByName => text().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  IntColumn get moveId => integer().nullable()();
  IntColumn get cashOutTypeId => integer().nullable()();
  TextColumn get typeName => text().nullable()();
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