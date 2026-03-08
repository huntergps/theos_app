import 'package:drift/drift.dart';

/// AccountCreditCardBrand - Marcas de tarjetas de crédito
class AccountCreditCardBrand extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// AccountCreditCardDeadline - Plazos de tarjetas de crédito
class AccountCreditCardDeadline extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  IntColumn get deadlineDays => integer()();
  RealColumn get percentage => real().withDefault(const Constant(0.0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// AccountCardLote - Lotes de tarjetas
class AccountCardLote extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  IntColumn get journalId => integer()();
  TextColumn get journalName => text().nullable()();
  DateTimeColumn get dateFrom => dateTime()();
  DateTimeColumn get dateTo => dateTime()();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  IntColumn get transactionCount => integer().withDefault(const Constant(0))();
  TextColumn get state => text().withDefault(const Constant('draft'))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// AccountPaymentMethodLine - Líneas de métodos de pago
class AccountPaymentMethodLine extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  IntColumn get paymentMethodId => integer()();
  TextColumn get paymentMethodName => text().nullable()();
  IntColumn get journalId => integer()();
  TextColumn get journalName => text().nullable()();
  TextColumn get paymentType => text()(); // inbound, outbound
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// AccountAdvance - Anticipos de clientes
class AccountAdvance extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()(); // Número de anticipo (ADV-xxxx)
  TextColumn get state => text().withDefault(
    const Constant('draft'),
  )(); // draft, posted, partial, reconciled, returned, cancelled
  TextColumn get advanceType =>
      text()(); // advance (anticipo), retention (retención)
  TextColumn get partnerType => text()(); // customer, supplier
  IntColumn get partnerId => integer()();
  TextColumn get partnerName => text().nullable()();
  TextColumn get partnerVat => text().nullable()();
  IntColumn get companyId => integer()();
  IntColumn get currencyId => integer().nullable()();
  IntColumn get cashierId => integer().nullable()(); // Usuario que registró
  TextColumn get cashierName => text().nullable()();
  TextColumn get reference => text().nullable()(); // Referencia/memo
  DateTimeColumn get date => dateTime()(); // Fecha del anticipo
  DateTimeColumn get dateEstimated =>
      dateTime().nullable()(); // Fecha estimada de uso
  DateTimeColumn get dateDue => dateTime().nullable()(); // Fecha de vencimiento
  RealColumn get amount =>
      real().withDefault(const Constant(0.0))(); // Monto original
  RealColumn get amountUsed =>
      real().withDefault(const Constant(0.0))(); // Monto usado
  RealColumn get amountAvailable =>
      real().withDefault(const Constant(0.0))(); // Monto disponible
  RealColumn get amountReturned =>
      real().withDefault(const Constant(0.0))(); // Monto devuelto
  BoolColumn get isExpired => boolean().withDefault(const Constant(false))();
  // Collection session reference
  IntColumn get collectionSessionId => integer().nullable()();
  IntColumn get collectionConfigId => integer().nullable()();
  IntColumn get saleOrderId =>
      integer().nullable()(); // Pedido que generó el anticipo
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// AccountCreditNote - Notas de crédito
class AccountCreditNote extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get reference => text().nullable()();
  IntColumn get partnerId => integer()();
  TextColumn get partnerName => text().nullable()();
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dateDue => dateTime().nullable()();
  TextColumn get state => text().withDefault(const Constant('draft'))();
  TextColumn get origin => text().nullable()(); // Origin invoice/document
  IntColumn get companyId => integer()();
  TextColumn get companyName => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}
/// AccountPayment - Pagos registrados en el sistema
class AccountPayment extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique().nullable()();
  TextColumn get paymentUuid => text().unique()(); // Local UUID for sync

  // Relations
  IntColumn get collectionSessionId => integer().nullable()();
  IntColumn get invoiceId => integer().nullable()();
  IntColumn get partnerId => integer().nullable()();
  TextColumn get partnerName => text().nullable()();
  IntColumn get journalId => integer().nullable()();
  TextColumn get journalName => text().nullable()();
  IntColumn get paymentMethodLineId => integer().nullable()();
  TextColumn get paymentMethodLineName => text().nullable()();

  // Economic Data
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  TextColumn get paymentType => text().withDefault(const Constant('inbound'))();
  TextColumn get state => text().withDefault(
    const Constant('draft'),
  )(); // 'draft', 'posted', 'cancel'

  // Classification
  TextColumn get paymentOriginType =>
      text().nullable()(); // 'invoice_day', 'debt', 'advance'
  TextColumn get paymentMethodCategory =>
      text().nullable()(); // 'cash', 'card_credit', etc.

  // Bank (res.bank)
  IntColumn get bankId => integer().nullable()();
  TextColumn get bankName => text().nullable()();

  // Check Fields (l10n_ec_collection_box)
  TextColumn get checkNumber => text().nullable()();
  TextColumn get checkAmountInWords => text().nullable()();
  DateTimeColumn get bankReferenceDate => dateTime().nullable()();
  BoolColumn get esPosfechado => boolean().withDefault(const Constant(false))();
  IntColumn get chequeRecibidoId => integer().nullable()();

  // Card Fields (l10n_ec_collection_box)
  IntColumn get cardBrandId => integer().nullable()();
  TextColumn get cardBrandName => text().nullable()();
  TextColumn get cardType => text().nullable()(); // 'credit' | 'debit'
  IntColumn get loteId => integer().nullable()();
  TextColumn get cardHolderName => text().nullable()();
  TextColumn get cardLast4 => text().nullable()();
  TextColumn get authorizationCode => text().nullable()();

  // Payment Classification (computed flags)
  BoolColumn get isCardPayment => boolean().withDefault(const Constant(false))();
  BoolColumn get isTransferPayment => boolean().withDefault(const Constant(false))();
  BoolColumn get isCheckPayment => boolean().withDefault(const Constant(false))();
  BoolColumn get isCashPayment => boolean().withDefault(const Constant(false))();

  // Sale Order Link
  IntColumn get saleId => integer().nullable()();
  IntColumn get advanceId => integer().nullable()();
  IntColumn get collectionUserId => integer().nullable()();

  // Metadata
  DateTimeColumn get date => dateTime().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get ref => text().nullable()();

  // Sync Status
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}
