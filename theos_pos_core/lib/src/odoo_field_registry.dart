/// Centralized registry of Odoo field definitions for all synced models.
///
/// This is the SINGLE SOURCE OF TRUTH for:
/// - Manager `odooFields` (which fields to request from Odoo API)
/// - WebSocket field mappings (Odoo field name → local column name)
/// - Companion builder type information (how to convert each value)
///
/// Adding a new field: add ONE entry here. Consumers pick it up automatically.

/// Types of Odoo fields, determining how values are converted for local storage.
enum OdooFieldType {
  /// Text/char fields: stored as String
  string,

  /// Integer fields (non-ID): stored as int
  integer,

  /// Float/monetary fields: stored as double
  double_,

  /// Boolean fields: stored as bool
  boolean,

  /// Datetime/date fields: stored as DateTime
  datetime,

  /// Many2one references: Odoo sends [id, name], stored as int (ID only)
  many2one,

  /// Many2many references: Odoo sends List<int>, stored as JSON string
  many2many,

  /// Serialized data: JSON objects or comma-separated values stored as String
  serialized,

  /// Selection fields: treated same as string for storage
  selection,
}

/// Definition of a single Odoo ↔ local field mapping.
class OdooFieldDef {
  /// Odoo API field name (e.g., 'partner_id', 'amount_total')
  final String odooName;

  /// Dart property name in camelCase (e.g., 'partnerId', 'amountTotal')
  final String dartName;

  /// How to convert values between Odoo and local storage
  final OdooFieldType type;

  /// Whether this field arrives via WebSocket notifications
  final bool syncViaWebSocket;

  /// Whether this field is requested in search_read API calls
  final bool syncViaApi;

  const OdooFieldDef({
    required this.odooName,
    required this.dartName,
    required this.type,
    this.syncViaWebSocket = true,
    this.syncViaApi = true,
  });

  /// SQL column name derived from dartName (camelCase → snake_case)
  String get columnName => _camelToSnake(dartName);

  static String _camelToSnake(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'(?<=[a-z0-9])[A-Z]'),
          (m) => '_${m.group(0)!.toLowerCase()}',
        )
        .toLowerCase();
  }
}

/// Centralized registry of all Odoo models and their field definitions.
///
/// Usage:
/// ```dart
/// // Get Odoo field names for API sync
/// final fields = OdooFieldRegistry.getOdooFields('sale.order');
///
/// // Get field mapping for WebSocket sync (odooName → dartName)
/// final mapping = OdooFieldRegistry.getFieldMapping('sale.order');
///
/// // Look up a specific field definition
/// final fieldDef = OdooFieldRegistry.getFieldDef('sale.order', 'partner_id');
/// ```
class OdooFieldRegistry {
  OdooFieldRegistry._();

  static const Map<String, List<OdooFieldDef>> models = {
    'sale.order': _saleOrderFields,
    'res.partner': _partnerFields,
    'product.product': _productFields,
    'res.company': _companyFields,
    'res.users': _userFields,
    'account.move': _accountMoveFields,
  };

  /// Get mapping from Odoo field name → Dart property name (for WebSocket sync)
  static Map<String, String> getFieldMapping(String model) {
    final fields = models[model];
    if (fields == null) return {};
    return {
      for (final f in fields)
        if (f.syncViaWebSocket) f.odooName: f.dartName,
    };
  }

  /// Get list of Odoo field names for API search_read calls
  static List<String> getOdooFields(String model) {
    final fields = models[model];
    if (fields == null) return [];
    return fields
        .where((f) => f.syncViaApi)
        .map((f) => f.odooName)
        .toList();
  }

  /// Get list of Odoo field names that arrive via WebSocket
  static List<String> getWebSocketFields(String model) {
    final fields = models[model];
    if (fields == null) return [];
    return fields
        .where((f) => f.syncViaWebSocket)
        .map((f) => f.odooName)
        .toList();
  }

  /// Look up a specific field definition by Odoo field name
  static OdooFieldDef? getFieldDef(String model, String odooFieldName) {
    final fields = models[model];
    if (fields == null) return null;
    for (final f in fields) {
      if (f.odooName == odooFieldName) return f;
    }
    return null;
  }

  /// Get all field definitions for a model (for companion builder)
  static Map<String, OdooFieldDef> getFieldDefMap(String model) {
    final fields = models[model];
    if (fields == null) return {};
    return {for (final f in fields) f.odooName: f};
  }
}

// =============================================================================
// sale.order
// =============================================================================

const _saleOrderFields = <OdooFieldDef>[
  // Identity
  OdooFieldDef(odooName: 'id', dartName: 'odooId', type: OdooFieldType.integer),
  OdooFieldDef(odooName: 'name', dartName: 'name', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'state', dartName: 'state', type: OdooFieldType.selection),
  // Dates
  OdooFieldDef(odooName: 'date_order', dartName: 'dateOrder', type: OdooFieldType.datetime),
  OdooFieldDef(odooName: 'validity_date', dartName: 'validityDate', type: OdooFieldType.datetime),
  OdooFieldDef(odooName: 'commitment_date', dartName: 'commitmentDate', type: OdooFieldType.datetime),
  OdooFieldDef(odooName: 'expected_date', dartName: 'expectedDate', type: OdooFieldType.datetime),
  // Partner
  OdooFieldDef(odooName: 'partner_id', dartName: 'partnerId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'partner_name', dartName: 'partnerName', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'partner_vat', dartName: 'partnerVat', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'partner_street', dartName: 'partnerStreet', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'partner_phone', dartName: 'partnerPhone', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'partner_email', dartName: 'partnerEmail', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'partner_invoice_id', dartName: 'partnerInvoiceId', type: OdooFieldType.many2one, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'partner_shipping_id', dartName: 'partnerShippingId', type: OdooFieldType.many2one, syncViaWebSocket: false),
  // Salesperson / Team
  OdooFieldDef(odooName: 'user_id', dartName: 'userId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'user_name', dartName: 'userName', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'team_id', dartName: 'teamId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'team_name', dartName: 'teamName', type: OdooFieldType.string, syncViaApi: false),
  // Company / Warehouse
  OdooFieldDef(odooName: 'company_id', dartName: 'companyId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'company_name', dartName: 'companyName', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'warehouse_id', dartName: 'warehouseId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'warehouse_name', dartName: 'warehouseName', type: OdooFieldType.string, syncViaApi: false),
  // Pricing
  OdooFieldDef(odooName: 'pricelist_id', dartName: 'pricelistId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'pricelist_name', dartName: 'pricelistName', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'currency_id', dartName: 'currencyId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'currency_symbol', dartName: 'currencySymbol', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'currency_rate', dartName: 'currencyRate', type: OdooFieldType.double_, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'payment_term_id', dartName: 'paymentTermId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'payment_term_name', dartName: 'paymentTermName', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'fiscal_position_id', dartName: 'fiscalPositionId', type: OdooFieldType.many2one, syncViaWebSocket: false),
  // Amounts
  OdooFieldDef(odooName: 'amount_untaxed', dartName: 'amountUntaxed', type: OdooFieldType.double_),
  OdooFieldDef(odooName: 'amount_tax', dartName: 'amountTax', type: OdooFieldType.double_),
  OdooFieldDef(odooName: 'amount_total', dartName: 'amountTotal', type: OdooFieldType.double_),
  OdooFieldDef(odooName: 'amount_to_invoice', dartName: 'amountToInvoice', type: OdooFieldType.double_, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'amount_invoiced', dartName: 'amountInvoiced', type: OdooFieldType.double_, syncViaWebSocket: false),
  // Invoice
  OdooFieldDef(odooName: 'invoice_status', dartName: 'invoiceStatus', type: OdooFieldType.selection),
  OdooFieldDef(odooName: 'invoice_count', dartName: 'invoiceCount', type: OdooFieldType.integer),
  // Notes
  OdooFieldDef(odooName: 'note', dartName: 'note', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'client_order_ref', dartName: 'clientOrderRef', type: OdooFieldType.string),
  // Signature / Payment
  OdooFieldDef(odooName: 'require_signature', dartName: 'requireSignature', type: OdooFieldType.boolean, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'signature', dartName: 'signature', type: OdooFieldType.string, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'signed_by', dartName: 'signedBy', type: OdooFieldType.string, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'signed_on', dartName: 'signedOn', type: OdooFieldType.datetime, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'require_payment', dartName: 'requirePayment', type: OdooFieldType.boolean, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'prepayment_percent', dartName: 'prepaymentPercent', type: OdooFieldType.double_, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'locked', dartName: 'locked', type: OdooFieldType.boolean, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'is_expired', dartName: 'isExpired', type: OdooFieldType.boolean, syncViaWebSocket: false),
  // Discount
  OdooFieldDef(odooName: 'total_discount_amount', dartName: 'totalDiscountAmount', type: OdooFieldType.double_, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'total_amount_undiscounted', dartName: 'amountUntaxedUndiscounted', type: OdooFieldType.double_, syncViaWebSocket: false),
  // End customer (pedir module)
  OdooFieldDef(odooName: 'is_final_consumer', dartName: 'isFinalConsumer', type: OdooFieldType.boolean, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'end_customer_name', dartName: 'endCustomerName', type: OdooFieldType.string, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'end_customer_phone', dartName: 'endCustomerPhone', type: OdooFieldType.string, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'end_customer_email', dartName: 'endCustomerEmail', type: OdooFieldType.string, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'exceeds_final_consumer_limit', dartName: 'exceedsFinalConsumerLimit', type: OdooFieldType.boolean, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'emitir_factura_fecha_posterior', dartName: 'emitirFacturaFechaPosterior', type: OdooFieldType.boolean, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'fecha_facturar', dartName: 'fechaFacturar', type: OdooFieldType.datetime, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'referrer_id', dartName: 'referrerId', type: OdooFieldType.many2one, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'tipo_cliente', dartName: 'tipoCliente', type: OdooFieldType.selection, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'canal_cliente', dartName: 'canalCliente', type: OdooFieldType.selection, syncViaWebSocket: false),
  // Delivery
  OdooFieldDef(odooName: 'picking_ids', dartName: 'pickingIds', type: OdooFieldType.many2many, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'delivery_status', dartName: 'deliveryStatus', type: OdooFieldType.selection, syncViaWebSocket: false),
  // Tax and payment type
  OdooFieldDef(odooName: 'tax_totals', dartName: 'taxTotals', type: OdooFieldType.serialized, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'is_cash', dartName: 'isCash', type: OdooFieldType.boolean, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'is_credit', dartName: 'isCredit', type: OdooFieldType.boolean, syncViaWebSocket: false),
  // Sync
  OdooFieldDef(odooName: 'write_date', dartName: 'writeDate', type: OdooFieldType.datetime),
];

// =============================================================================
// res.partner
// =============================================================================

const _partnerFields = <OdooFieldDef>[
  // Identity
  OdooFieldDef(odooName: 'id', dartName: 'odooId', type: OdooFieldType.integer),
  OdooFieldDef(odooName: 'name', dartName: 'name', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'display_name', dartName: 'displayName', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'ref', dartName: 'ref', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'vat', dartName: 'vat', type: OdooFieldType.string),
  // Contact
  OdooFieldDef(odooName: 'email', dartName: 'email', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'phone', dartName: 'phone', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'mobile', dartName: 'mobile', type: OdooFieldType.string),
  // Address
  OdooFieldDef(odooName: 'street', dartName: 'street', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'street2', dartName: 'street2', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'city', dartName: 'city', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'zip', dartName: 'zip', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'country_id', dartName: 'countryId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'country_name', dartName: 'countryName', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'state_id', dartName: 'stateId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'state_name', dartName: 'stateName', type: OdooFieldType.string, syncViaApi: false),
  // Avatar
  OdooFieldDef(odooName: 'avatar_128', dartName: 'avatar128', type: OdooFieldType.string),
  // Flags
  OdooFieldDef(odooName: 'is_company', dartName: 'isCompany', type: OdooFieldType.boolean),
  OdooFieldDef(odooName: 'active', dartName: 'active', type: OdooFieldType.boolean),
  // Parent / Commercial
  OdooFieldDef(odooName: 'parent_id', dartName: 'parentId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'parent_name', dartName: 'parentName', type: OdooFieldType.string, syncViaApi: false),
  OdooFieldDef(odooName: 'commercial_partner_id', dartName: 'commercialPartnerId', type: OdooFieldType.many2one, syncViaWebSocket: false),
  // Pricing / Payment defaults
  OdooFieldDef(odooName: 'property_product_pricelist', dartName: 'propertyProductPricelistId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'property_payment_term_id', dartName: 'propertyPaymentTermId', type: OdooFieldType.many2one),
  // Language
  OdooFieldDef(odooName: 'lang', dartName: 'lang', type: OdooFieldType.selection),
  OdooFieldDef(odooName: 'comment', dartName: 'comment', type: OdooFieldType.string),
  // Credit control (l10n_ec_sale_credit)
  OdooFieldDef(odooName: 'credit_limit', dartName: 'creditLimit', type: OdooFieldType.double_),
  OdooFieldDef(odooName: 'credit', dartName: 'credit', type: OdooFieldType.double_),
  OdooFieldDef(odooName: 'credit_to_invoice', dartName: 'creditToInvoice', type: OdooFieldType.double_),
  OdooFieldDef(odooName: 'total_overdue', dartName: 'totalOverdue', type: OdooFieldType.double_),
  OdooFieldDef(odooName: 'allow_over_credit', dartName: 'allowOverCredit', type: OdooFieldType.boolean),
  OdooFieldDef(odooName: 'use_partner_credit_limit', dartName: 'usePartnerCreditLimit', type: OdooFieldType.boolean),
  OdooFieldDef(odooName: 'unpaid_invoices_count', dartName: 'overdueInvoicesCount', type: OdooFieldType.integer),
  OdooFieldDef(odooName: 'oldest_overdue_days', dartName: 'oldestOverdueDays', type: OdooFieldType.integer, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'dias_max_factura_posterior', dartName: 'diasMaxFacturaPosterior', type: OdooFieldType.integer, syncViaWebSocket: false),
  // Sync
  OdooFieldDef(odooName: 'write_date', dartName: 'writeDate', type: OdooFieldType.datetime),
];

// =============================================================================
// product.product
// =============================================================================

const _productFields = <OdooFieldDef>[
  // Identity
  OdooFieldDef(odooName: 'id', dartName: 'odooId', type: OdooFieldType.integer),
  OdooFieldDef(odooName: 'name', dartName: 'name', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'display_name', dartName: 'displayName', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'default_code', dartName: 'defaultCode', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'barcode', dartName: 'barcode', type: OdooFieldType.string),
  // Type / flags
  OdooFieldDef(odooName: 'type', dartName: 'type', type: OdooFieldType.selection),
  OdooFieldDef(odooName: 'sale_ok', dartName: 'saleOk', type: OdooFieldType.boolean),
  OdooFieldDef(odooName: 'purchase_ok', dartName: 'purchaseOk', type: OdooFieldType.boolean),
  OdooFieldDef(odooName: 'active', dartName: 'active', type: OdooFieldType.boolean),
  // Pricing
  OdooFieldDef(odooName: 'list_price', dartName: 'listPrice', type: OdooFieldType.double_),
  OdooFieldDef(odooName: 'standard_price', dartName: 'standardPrice', type: OdooFieldType.double_),
  // Category
  OdooFieldDef(odooName: 'categ_id', dartName: 'categId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'categ_name', dartName: 'categName', type: OdooFieldType.string, syncViaApi: false),
  // UoM
  OdooFieldDef(odooName: 'uom_id', dartName: 'uomId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'uom_name', dartName: 'uomName', type: OdooFieldType.string, syncViaApi: false),
  // Taxes
  OdooFieldDef(odooName: 'taxes_id', dartName: 'taxesId', type: OdooFieldType.many2many),
  OdooFieldDef(odooName: 'supplier_taxes_id', dartName: 'supplierTaxesId', type: OdooFieldType.many2many, syncViaWebSocket: false),
  // Descriptions
  OdooFieldDef(odooName: 'description', dartName: 'description', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'description_sale', dartName: 'descriptionSale', type: OdooFieldType.string),
  // Template
  OdooFieldDef(odooName: 'product_tmpl_id', dartName: 'productTmplId', type: OdooFieldType.many2one),
  // Stock (API only — computed fields)
  OdooFieldDef(odooName: 'qty_available', dartName: 'qtyAvailable', type: OdooFieldType.double_, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'virtual_available', dartName: 'virtualAvailable', type: OdooFieldType.double_, syncViaWebSocket: false),
  // Tracking
  OdooFieldDef(odooName: 'tracking', dartName: 'tracking', type: OdooFieldType.selection, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'is_storable', dartName: 'isStorable', type: OdooFieldType.boolean, syncViaWebSocket: false),
  // Ecuador / Custom
  OdooFieldDef(odooName: 'l10n_ec_auxiliary_code', dartName: 'l10nEcAuxiliaryCode', type: OdooFieldType.string, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'is_unit_product', dartName: 'isUnitProduct', type: OdooFieldType.boolean, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'temporal_no_despachar', dartName: 'temporalNoDespachar', type: OdooFieldType.boolean, syncViaWebSocket: false),
  // Sync
  OdooFieldDef(odooName: 'write_date', dartName: 'writeDate', type: OdooFieldType.datetime),
];

// =============================================================================
// res.company
// =============================================================================

const _companyFields = <OdooFieldDef>[
  // Identity
  OdooFieldDef(odooName: 'id', dartName: 'odooId', type: OdooFieldType.integer),
  OdooFieldDef(odooName: 'name', dartName: 'name', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'vat', dartName: 'vat', type: OdooFieldType.string),
  // Contact
  OdooFieldDef(odooName: 'email', dartName: 'email', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'phone', dartName: 'phone', type: OdooFieldType.string),
  // NOTE: 'mobile' does not exist on res.company in Odoo 19 — removed
  OdooFieldDef(odooName: 'website', dartName: 'website', type: OdooFieldType.string),
  // Address
  OdooFieldDef(odooName: 'street', dartName: 'street', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'street2', dartName: 'street2', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'city', dartName: 'city', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'zip', dartName: 'zip', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'country_id', dartName: 'countryId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'state_id', dartName: 'stateId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'currency_id', dartName: 'currencyId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'parent_id', dartName: 'parentId', type: OdooFieldType.many2one, syncViaWebSocket: false),
  // Branding / Logo
  OdooFieldDef(odooName: 'logo', dartName: 'logo', type: OdooFieldType.string),
  // Sales configuration (WS-only — manager doesn't request these via API)
  OdooFieldDef(odooName: 'quotation_validity_days', dartName: 'quotationValidityDays', type: OdooFieldType.integer, syncViaApi: false),
  OdooFieldDef(odooName: 'portal_confirmation_sign', dartName: 'portalConfirmationSign', type: OdooFieldType.boolean, syncViaApi: false),
  OdooFieldDef(odooName: 'portal_confirmation_pay', dartName: 'portalConfirmationPay', type: OdooFieldType.boolean, syncViaApi: false),
  OdooFieldDef(odooName: 'prepayment_percent', dartName: 'prepaymentPercent', type: OdooFieldType.double_, syncViaApi: false),
  OdooFieldDef(odooName: 'sale_discount_product_id', dartName: 'saleDiscountProductId', type: OdooFieldType.many2one, syncViaApi: false),
  OdooFieldDef(odooName: 'default_pricelist_id', dartName: 'defaultPricelistId', type: OdooFieldType.many2one, syncViaApi: false),
  OdooFieldDef(odooName: 'default_payment_term_id', dartName: 'defaultPaymentTermId', type: OdooFieldType.many2one, syncViaApi: false),
  OdooFieldDef(odooName: 'default_partner_id', dartName: 'defaultPartnerId', type: OdooFieldType.many2one, syncViaApi: false),
  OdooFieldDef(odooName: 'default_warehouse_id', dartName: 'defaultWarehouseId', type: OdooFieldType.many2one, syncViaApi: false),
  // Document layout
  OdooFieldDef(odooName: 'l10n_ec_comercial_name', dartName: 'l10nEcComercialName', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'report_footer', dartName: 'reportFooter', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'primary_color', dartName: 'primaryColor', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'secondary_color', dartName: 'secondaryColor', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'font', dartName: 'font', type: OdooFieldType.string),
  // NOTE: 'layout_background' does not exist in Odoo 19 — removed
  OdooFieldDef(odooName: 'external_report_layout_id', dartName: 'externalReportLayoutId', type: OdooFieldType.string),
  // Ecuador SRI
  OdooFieldDef(odooName: 'sale_customer_invoice_limit_sri', dartName: 'saleCustomerInvoiceLimitSri', type: OdooFieldType.double_, syncViaApi: false),
  OdooFieldDef(odooName: 'l10n_ec_legal_name', dartName: 'l10nEcLegalName', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'l10n_ec_production_env', dartName: 'l10nEcProductionEnv', type: OdooFieldType.boolean),
  // Pedir module (WS-only — manager doesn't request these via API)
  OdooFieldDef(odooName: 'pedir_end_customer_data', dartName: 'pedirEndCustomerData', type: OdooFieldType.boolean, syncViaApi: false),
  OdooFieldDef(odooName: 'pedir_sale_referrer', dartName: 'pedirSaleReferrer', type: OdooFieldType.boolean, syncViaApi: false),
  OdooFieldDef(odooName: 'pedir_tipo_canal_cliente', dartName: 'pedirTipoCanalCliente', type: OdooFieldType.boolean, syncViaApi: false),
  OdooFieldDef(odooName: 'credit_overdue_days_threshold', dartName: 'creditOverdueDaysThreshold', type: OdooFieldType.integer, syncViaApi: false),
  OdooFieldDef(odooName: 'credit_overdue_invoices_threshold', dartName: 'creditOverdueInvoicesThreshold', type: OdooFieldType.integer, syncViaApi: false),
  OdooFieldDef(odooName: 'max_discount_percentage', dartName: 'maxDiscountPercentage', type: OdooFieldType.double_, syncViaApi: false),
  // Reservation configuration (WS-only)
  OdooFieldDef(odooName: 'reservation_expiry_days', dartName: 'reservationExpiryDays', type: OdooFieldType.integer, syncViaApi: false),
  OdooFieldDef(odooName: 'reservation_warehouse_id', dartName: 'reservationWarehouseId', type: OdooFieldType.many2one, syncViaApi: false),
  OdooFieldDef(odooName: 'reservation_location_id', dartName: 'reservationLocationId', type: OdooFieldType.many2one, syncViaApi: false),
  OdooFieldDef(odooName: 'reserve_from_quotation', dartName: 'reserveFromQuotation', type: OdooFieldType.boolean, syncViaApi: false),
  // Manager-only fields
  OdooFieldDef(odooName: 'report_header_image', dartName: 'reportHeaderImage', type: OdooFieldType.string, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'tax_calculation_rounding_method', dartName: 'taxCalculationRoundingMethod', type: OdooFieldType.selection, syncViaWebSocket: false),
  // Sync
  OdooFieldDef(odooName: 'write_date', dartName: 'writeDate', type: OdooFieldType.datetime),
];

// =============================================================================
// res.users
// =============================================================================

const _userFields = <OdooFieldDef>[
  // Identity
  OdooFieldDef(odooName: 'id', dartName: 'odooId', type: OdooFieldType.integer),
  OdooFieldDef(odooName: 'name', dartName: 'name', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'login', dartName: 'login', type: OdooFieldType.string),
  // Contact
  OdooFieldDef(odooName: 'email', dartName: 'email', type: OdooFieldType.string),
  // References
  OdooFieldDef(odooName: 'partner_id', dartName: 'partnerId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'company_id', dartName: 'companyId', type: OdooFieldType.many2one),
  // Preferences
  OdooFieldDef(odooName: 'lang', dartName: 'lang', type: OdooFieldType.selection),
  OdooFieldDef(odooName: 'tz', dartName: 'tz', type: OdooFieldType.selection),
  // Groups — NOT included in API fields (not readable via external API).
  // User group memberships are fetched via syncUserGroups() / has_group().
  // Manager-only fields
  OdooFieldDef(odooName: 'signature', dartName: 'signature', type: OdooFieldType.string, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'property_warehouse_id', dartName: 'warehouseId', type: OdooFieldType.many2one, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'avatar_128', dartName: 'avatar128', type: OdooFieldType.string, syncViaWebSocket: false),
  OdooFieldDef(odooName: 'notification_type', dartName: 'notificationType', type: OdooFieldType.selection, syncViaWebSocket: false),
  // Sync
  OdooFieldDef(odooName: 'write_date', dartName: 'writeDate', type: OdooFieldType.datetime),
];

// =============================================================================
// account.move
// =============================================================================

const _accountMoveFields = <OdooFieldDef>[
  // Identity
  OdooFieldDef(odooName: 'id', dartName: 'odooId', type: OdooFieldType.integer),
  OdooFieldDef(odooName: 'name', dartName: 'name', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'ref', dartName: 'ref', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'move_type', dartName: 'moveType', type: OdooFieldType.selection),
  // State
  OdooFieldDef(odooName: 'state', dartName: 'state', type: OdooFieldType.selection),
  OdooFieldDef(odooName: 'payment_state', dartName: 'paymentState', type: OdooFieldType.selection),
  // Dates
  OdooFieldDef(odooName: 'date', dartName: 'date', type: OdooFieldType.datetime),
  OdooFieldDef(odooName: 'invoice_date', dartName: 'invoiceDate', type: OdooFieldType.datetime),
  OdooFieldDef(odooName: 'invoice_date_due', dartName: 'invoiceDateDue', type: OdooFieldType.datetime),
  // Partner
  OdooFieldDef(odooName: 'partner_id', dartName: 'partnerId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'partner_vat', dartName: 'partnerVat', type: OdooFieldType.string),
  // References
  OdooFieldDef(odooName: 'journal_id', dartName: 'journalId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'company_id', dartName: 'companyId', type: OdooFieldType.many2one),
  OdooFieldDef(odooName: 'currency_id', dartName: 'currencyId', type: OdooFieldType.many2one),
  // Amounts
  OdooFieldDef(odooName: 'amount_untaxed', dartName: 'amountUntaxed', type: OdooFieldType.double_),
  OdooFieldDef(odooName: 'amount_tax', dartName: 'amountTax', type: OdooFieldType.double_),
  OdooFieldDef(odooName: 'amount_total', dartName: 'amountTotal', type: OdooFieldType.double_),
  OdooFieldDef(odooName: 'amount_residual', dartName: 'amountResidual', type: OdooFieldType.double_),
  // Ecuador localization
  OdooFieldDef(odooName: 'l10n_ec_authorization_number', dartName: 'l10nEcAuthorizationNumber', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'l10n_latam_document_number', dartName: 'l10nLatamDocumentNumber', type: OdooFieldType.string),
  OdooFieldDef(odooName: 'l10n_latam_document_type_id', dartName: 'l10nLatamDocumentTypeId', type: OdooFieldType.many2one),
  // SRI payment name (text field, API-only)
  OdooFieldDef(odooName: 'l10n_ec_sri_payment_name', dartName: 'l10nEcSriPaymentName', type: OdooFieldType.string, syncViaWebSocket: false),
  // Origin
  OdooFieldDef(odooName: 'invoice_origin', dartName: 'invoiceOrigin', type: OdooFieldType.string),
  // Sync
  OdooFieldDef(odooName: 'write_date', dartName: 'writeDate', type: OdooFieldType.datetime),
];
