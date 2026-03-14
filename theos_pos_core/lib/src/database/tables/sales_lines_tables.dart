import 'package:drift/drift.dart';

/// SaleOrderLine - Líneas de órdenes de venta
class SaleOrderLine extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique().nullable()();
  TextColumn get lineUuid =>
      text().unique().nullable()(); // Local UUID for sync
  IntColumn get orderId => integer()(); // FK to SaleOrder.odooId
  IntColumn get sequence => integer().withDefault(const Constant(10))();

  // Line type
  TextColumn get displayType => text().withDefault(
    const Constant(''),
  )(); // '', 'line_section', 'line_subsection', 'line_note'
  BoolColumn get isDownpayment =>
      boolean().withDefault(const Constant(false))();

  // Product
  IntColumn get productId => integer().nullable()();
  TextColumn get productName => text().nullable()();
  TextColumn get productDefaultCode => text().nullable()(); // default_code from Odoo
  IntColumn get productTemplateId => integer().nullable()();
  TextColumn get productTemplateName => text().nullable()();
  TextColumn get productType =>
      text().nullable()(); // 'consu', 'service', 'product'
  IntColumn get categId => integer().nullable()();
  TextColumn get categName => text().nullable()();

  // Description
  TextColumn get name => text()(); // Line description

  // Quantity and UoM
  RealColumn get productUomQty => real().withDefault(const Constant(1.0))();
  IntColumn get productUomId => integer().nullable()();
  TextColumn get productUomName => text().nullable()();

  // Prices
  RealColumn get priceUnit => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount =>
      real().withDefault(const Constant(0.0))(); // Monto de descuento calculado
  RealColumn get priceSubtotal => real().withDefault(const Constant(0.0))();
  RealColumn get priceTax => real().withDefault(const Constant(0.0))();
  RealColumn get priceTotal => real().withDefault(const Constant(0.0))();
  RealColumn get priceReduce => real().withDefault(const Constant(0.0))();

  // Taxes (JSON array of IDs)
  TextColumn get taxIds => text().nullable()();

  // Delivery
  RealColumn get qtyDelivered => real().withDefault(const Constant(0.0))();
  RealColumn get customerLead => real().withDefault(const Constant(0.0))();

  // Invoicing
  RealColumn get qtyInvoiced => real().withDefault(const Constant(0.0))();
  RealColumn get qtyToInvoice => real().withDefault(const Constant(0.0))();
  TextColumn get invoiceStatus => text().withDefault(const Constant('no'))();

  // Order state (related)
  TextColumn get orderState => text().nullable()();

  // Section settings (Odoo 19)
  BoolColumn get collapsePrices => boolean().withDefault(const Constant(false))();
  BoolColumn get collapseComposition => boolean().withDefault(const Constant(false))();
  BoolColumn get isOptional => boolean().withDefault(const Constant(false))();

  // Margin (sale_margin)
  RealColumn get margin => real().withDefault(const Constant(0.0))();
  RealColumn get marginPercent => real().withDefault(const Constant(0.0))();
  RealColumn get purchasePrice => real().withDefault(const Constant(0.0))();
  RealColumn get lastPurchaseCost => real().withDefault(const Constant(0.0))();

  // Cost (l10n_ec_sale_base)
  RealColumn get totalCostLine => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get amountUndiscounted => real().withDefault(const Constant(0.0))();

  // Tax names (for display)
  TextColumn get taxNames => text().nullable()();

  // Collection Session (l10n_ec_collection_box)
  IntColumn get collectionSessionId => integer().nullable()();
  IntColumn get saleCreatedUserId => integer().nullable()();

  // UUID for offline sync (l10n_ec_collection_box_pos)
  TextColumn get xUuid => text().nullable()();

  // Product flags
  BoolColumn get isUnitProduct => boolean().withDefault(const Constant(true))();

  // Sync Status
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// SaleOrderWithholdLine - Líneas de retenciones en órdenes de venta
class SaleOrderWithholdLine extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique().nullable()();
  TextColumn get lineUuid => text().unique().nullable()(); // Local UUID for offline sync

  // Reference to sale order
  IntColumn get orderId => integer()(); // FK to SaleOrder.odooId
  IntColumn get sequence => integer().withDefault(const Constant(10))();

  // Tax information
  IntColumn get taxId => integer()();
  TextColumn get taxName => text()();
  RealColumn get taxPercent => real().withDefault(const Constant(0.0))(); // e.g., 0.30 for 30%
  TextColumn get withholdType => text()(); // 'withhold_vat_sale' or 'withhold_income_sale'

  // Tax support code (Ecuador SRI)
  TextColumn get taxsupportCode => text().nullable()(); // '01', '02', '03', '04', '05'

  // Amounts
  RealColumn get base => real().withDefault(const Constant(0.0))();
  RealColumn get amount => real().withDefault(const Constant(0.0))();

  // Legacy aliases (for backwards compatibility)
  RealColumn get baseAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get percentage => real().withDefault(const Constant(0.0))();

  // Notes
  TextColumn get notes => text().nullable()();

  // Sync Status
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// SaleOrderPaymentLine - Líneas de pago en órdenes de venta
class SaleOrderPaymentLine extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique().nullable()();
  TextColumn get lineUuid => text().unique().nullable()(); // Local UUID for offline sync

  // References
  IntColumn get orderId => integer()(); // FK to SaleOrder.odooId
  TextColumn get paymentType => text().withDefault(const Constant('inbound'))(); // inbound, outbound
  IntColumn get journalId => integer().nullable()();
  TextColumn get journalName => text().nullable()();
  TextColumn get journalType => text().nullable()(); // cash, bank, card, etc.
  IntColumn get paymentMethodId => integer().nullable()();
  IntColumn get paymentMethodLineId => integer().nullable()();
  TextColumn get paymentMethodCode => text().nullable()();
  TextColumn get paymentMethodName => text().nullable()();

  // Payment details
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  TextColumn get reference => text().nullable()();
  TextColumn get paymentReference => text().nullable()();
  DateTimeColumn get date => dateTime().nullable()();
  TextColumn get state => text().withDefault(const Constant('draft'))();

  // Credit note / advance references
  IntColumn get creditNoteId => integer().nullable()();
  TextColumn get creditNoteName => text().nullable()();
  IntColumn get advanceId => integer().nullable()();
  TextColumn get advanceName => text().nullable()();

  // Card payment fields
  TextColumn get cardType => text().nullable()(); // credit, debit
  IntColumn get cardBrandId => integer().nullable()();
  TextColumn get cardBrandName => text().nullable()();
  IntColumn get cardDeadlineId => integer().nullable()();
  TextColumn get cardDeadlineName => text().nullable()();
  IntColumn get loteId => integer().nullable()();
  TextColumn get loteName => text().nullable()();

  // Bank / transfer fields
  IntColumn get bankId => integer().nullable()();
  TextColumn get bankName => text().nullable()();
  IntColumn get partnerBankId => integer().nullable()();
  TextColumn get partnerBankName => text().nullable()();
  DateTimeColumn get effectiveDate => dateTime().nullable()();
  DateTimeColumn get bankReferenceDate => dateTime().nullable()();

  // Sync Status
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncDate => dateTime().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}