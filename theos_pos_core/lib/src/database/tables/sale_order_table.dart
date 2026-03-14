import 'package:drift/drift.dart';

/// SaleOrder table definition - Sales order data
///
/// This table stores all sales order information synced from Odoo.
/// Used by SaleOrderManager and related services.
class SaleOrder extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get state => text().nullable()();
  DateTimeColumn get dateOrder => dateTime().nullable()();
  DateTimeColumn get validityDate => dateTime().nullable()();
  DateTimeColumn get dateConfirmed => dateTime().nullable()();
  IntColumn get partnerId => integer().nullable()();
  TextColumn get partnerName => text().nullable()();
  IntColumn get partnerInvoiceId => integer().nullable()();
  TextColumn get partnerInvoiceName => text().nullable()();
  IntColumn get partnerShippingId => integer().nullable()();
  TextColumn get partnerShippingName => text().nullable()();
  IntColumn get pricelistId => integer().nullable()();
  TextColumn get pricelistName => text().nullable()();
  IntColumn get paymentTermId => integer().nullable()();
  TextColumn get paymentTermName => text().nullable()();
  IntColumn get userId => integer().nullable()();
  TextColumn get userName => text().nullable()();
  IntColumn get teamId => integer().nullable()();
  TextColumn get teamName => text().nullable()();
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  IntColumn get warehouseId => integer().nullable()();
  TextColumn get warehouseName => text().nullable()();
  IntColumn get currencyId => integer().nullable()();
  TextColumn get currencyName => text().nullable()();
  RealColumn get amountUntaxed => real().nullable()();
  RealColumn get amountTax => real().nullable()();
  RealColumn get amountTotal => real().nullable()();
  RealColumn get amountPaid => real().nullable()();
  RealColumn get amountResidual => real().nullable()();
  TextColumn get paymentState => text().nullable()();
  TextColumn get invoiceStatus => text().nullable()();
  TextColumn get deliveryStatus => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get origin => text().nullable()();
  TextColumn get clientOrderRef => text().nullable()();
  IntColumn get fiscalPositionId => integer().nullable()();
  TextColumn get fiscalPositionName => text().nullable()();
  BoolColumn get requireSignature => boolean().withDefault(const Constant(false))();
  BoolColumn get requirePayment => boolean().withDefault(const Constant(false))();
  TextColumn get signedBy => text().nullable()();
  DateTimeColumn get signedOn => dateTime().nullable()();
  DateTimeColumn get commitmentDate => dateTime().nullable()();
  DateTimeColumn get expectedDate => dateTime().nullable()();
  BoolColumn get isExpired => boolean().withDefault(const Constant(false))();
  TextColumn get showUpdatePricelist => text().nullable()();
  IntColumn get analyticAccountId => integer().nullable()();
  TextColumn get analyticAccountName => text().nullable()();
  IntColumn get campaignId => integer().nullable()();
  TextColumn get campaignName => text().nullable()();
  IntColumn get sourceId => integer().nullable()();
  TextColumn get sourceName => text().nullable()();
  IntColumn get mediumId => integer().nullable()();
  TextColumn get mediumName => text().nullable()();
  TextColumn get websiteMessageIds => text().nullable()();
  TextColumn get accessToken => text().nullable()();
  TextColumn get accessWarning => text().nullable()();

  // Collection-specific fields
  IntColumn get collectionSessionId => integer().nullable()();
  TextColumn get collectionSessionName => text().nullable()();
  IntColumn get collectionConfigId => integer().nullable()();
  TextColumn get collectionConfigName => text().nullable()();
  IntColumn get collectionUserId => integer().nullable()();
  TextColumn get collectionUserName => text().nullable()();
  IntColumn get saleCreatedUserId => integer().nullable()();

  // Partner additional fields
  TextColumn get partnerVat => text().nullable()();
  TextColumn get partnerStreet => text().nullable()();
  TextColumn get partnerPhone => text().nullable()();
  TextColumn get partnerEmail => text().nullable()();
  TextColumn get partnerAvatar => text().nullable()();
  TextColumn get partnerInvoiceAddress => text().nullable()();
  TextColumn get partnerShippingAddress => text().nullable()();

  // Currency additional fields
  TextColumn get currencySymbol => text().nullable()();
  RealColumn get currencyRate => real().withDefault(const Constant(1.0))();

  // Payment type
  BoolColumn get isCash => boolean().withDefault(const Constant(true))();
  BoolColumn get isCredit => boolean().withDefault(const Constant(false))();

  // Invoice amounts
  RealColumn get amountToInvoice => real().withDefault(const Constant(0.0))();
  RealColumn get amountInvoiced => real().withDefault(const Constant(0.0))();
  IntColumn get invoiceCount => integer().withDefault(const Constant(0))();

  // Signature
  TextColumn get signature => text().nullable()();
  RealColumn get prepaymentPercent => real().withDefault(const Constant(0.0))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();

  // Discounts (l10n_ec_sale_discount)
  RealColumn get totalDiscountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmountUndiscounted => real().withDefault(const Constant(0.0))();

  // Final Consumer (l10n_ec_sale_base)
  BoolColumn get isFinalConsumer => boolean().withDefault(const Constant(false))();
  TextColumn get endCustomerName => text().nullable()();
  TextColumn get endCustomerPhone => text().nullable()();
  TextColumn get endCustomerEmail => text().nullable()();
  BoolColumn get exceedsFinalConsumerLimit => boolean().withDefault(const Constant(false))();

  // Postdated Invoice (l10n_ec_sale_base)
  BoolColumn get emitirFacturaFechaPosterior => boolean().withDefault(const Constant(false))();
  DateTimeColumn get fechaFacturar => dateTime().nullable()();

  // Referrer (l10n_ec_sale_base)
  IntColumn get referrerId => integer().nullable()();
  TextColumn get referrerName => text().nullable()();

  // Customer Type/Channel (l10n_ec_sale_base)
  TextColumn get tipoCliente => text().nullable()();
  TextColumn get canalCliente => text().nullable()();

  // Pickings (sale_stock) - stored as JSON
  TextColumn get pickingIds => text().nullable()();

  // Tax totals JSON
  TextColumn get taxTotals => text().nullable()();

  // Credit Control (l10n_ec_sale_credit)
  BoolColumn get creditExceeded => boolean().withDefault(const Constant(false))();
  BoolColumn get creditCheckBypassed => boolean().withDefault(const Constant(false))();

  // Additional Amounts
  RealColumn get amountCash => real().withDefault(const Constant(0.0))();
  RealColumn get amountUnpaid => real().withDefault(const Constant(0.0))();
  RealColumn get totalCostAmount => real().withDefault(const Constant(0.0))();
  RealColumn get margin => real().withDefault(const Constant(0.0))();
  RealColumn get marginPercent => real().withDefault(const Constant(0.0))();
  RealColumn get retenidoAmount => real().withDefault(const Constant(0.0))();

  // Approvals (l10n_ec_sale_credit)
  IntColumn get approvalCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get approvedDate => dateTime().nullable()();
  DateTimeColumn get rejectedDate => dateTime().nullable()();
  TextColumn get rejectedReason => text().nullable()();

  // Dispatch Control (l10n_ec_sale_base)
  BoolColumn get entregarSoloPagado => boolean().withDefault(const Constant(false))();
  BoolColumn get esParaDespacho => boolean().withDefault(const Constant(false))();
  TextColumn get notaAdicional => text().nullable()();

  // UUID fields
  TextColumn get orderUuid => text().nullable()();
  TextColumn get xUuid => text().nullable()();

  // Sync fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
  BoolColumn get pendingConfirm => boolean().withDefault(const Constant(false))();
  DateTimeColumn get writeDate => dateTime().nullable()();
  TextColumn get uuid => text().nullable()();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();
  IntColumn get syncRetryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();
  BoolColumn get hasQueuedInvoice => boolean().withDefault(const Constant(false))();

  // Computed fields stored for performance
  RealColumn get totalQuantity => real().nullable()();
  IntColumn get lineCount => integer().nullable()();
  TextColumn get displayAmount => text().nullable()();
  BoolColumn get hasUnsyncedLines => boolean().nullable()();
}
