// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Company _$CompanyFromJson(Map<String, dynamic> json) => _Company(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  vat: json['vat'] as String?,
  street: json['street'] as String?,
  street2: json['street2'] as String?,
  city: json['city'] as String?,
  zip: json['zip'] as String?,
  countryId: (json['countryId'] as num?)?.toInt(),
  countryName: json['countryName'] as String?,
  stateId: (json['stateId'] as num?)?.toInt(),
  stateName: json['stateName'] as String?,
  phone: json['phone'] as String?,
  mobile: json['mobile'] as String?,
  email: json['email'] as String?,
  website: json['website'] as String?,
  currencyId: (json['currencyId'] as num?)?.toInt(),
  currencyName: json['currencyName'] as String?,
  parentId: (json['parentId'] as num?)?.toInt(),
  parentName: json['parentName'] as String?,
  l10nEcComercialName: json['l10nEcComercialName'] as String?,
  l10nEcLegalName: json['l10nEcLegalName'] as String?,
  l10nEcProductionEnv: json['l10nEcProductionEnv'] as bool? ?? false,
  logo: json['logo'] as String?,
  reportHeaderImage: json['reportHeaderImage'] as String?,
  reportFooter: json['reportFooter'] as String?,
  primaryColor: json['primaryColor'] as String?,
  secondaryColor: json['secondaryColor'] as String?,
  font: json['font'] as String?,
  layoutBackground: json['layoutBackground'] as String?,
  externalReportLayoutId: (json['externalReportLayoutId'] as num?)?.toInt(),
  taxCalculationRoundingMethod:
      json['taxCalculationRoundingMethod'] as String? ?? 'round_per_line',
  quotationValidityDays: (json['quotationValidityDays'] as num?)?.toInt() ?? 30,
  portalConfirmationSign: json['portalConfirmationSign'] as bool? ?? true,
  portalConfirmationPay: json['portalConfirmationPay'] as bool? ?? false,
  prepaymentPercent: (json['prepaymentPercent'] as num?)?.toDouble() ?? 1.0,
  saleDiscountProductId: (json['saleDiscountProductId'] as num?)?.toInt(),
  saleDiscountProductName: json['saleDiscountProductName'] as String?,
  defaultPartnerId: (json['defaultPartnerId'] as num?)?.toInt(),
  defaultPartnerName: json['defaultPartnerName'] as String?,
  defaultWarehouseId: (json['defaultWarehouseId'] as num?)?.toInt(),
  defaultWarehouseName: json['defaultWarehouseName'] as String?,
  defaultPricelistId: (json['defaultPricelistId'] as num?)?.toInt(),
  defaultPricelistName: json['defaultPricelistName'] as String?,
  defaultPaymentTermId: (json['defaultPaymentTermId'] as num?)?.toInt(),
  defaultPaymentTermName: json['defaultPaymentTermName'] as String?,
  pedirEndCustomerData: json['pedirEndCustomerData'] as bool? ?? false,
  pedirSaleReferrer: json['pedirSaleReferrer'] as bool? ?? false,
  pedirTipoCanalCliente: json['pedirTipoCanalCliente'] as bool? ?? false,
  saleCustomerInvoiceLimitSri: (json['saleCustomerInvoiceLimitSri'] as num?)
      ?.toDouble(),
  maxDiscountPercentage:
      (json['maxDiscountPercentage'] as num?)?.toDouble() ?? 100.0,
  creditOverdueDaysThreshold:
      (json['creditOverdueDaysThreshold'] as num?)?.toInt() ?? 30,
  creditOverdueInvoicesThreshold:
      (json['creditOverdueInvoicesThreshold'] as num?)?.toInt() ?? 3,
  creditOfflineSafetyMargin:
      (json['creditOfflineSafetyMargin'] as num?)?.toDouble() ?? 0.0,
  creditDataMaxAgeHours: (json['creditDataMaxAgeHours'] as num?)?.toInt() ?? 24,
  reservationExpiryDays: (json['reservationExpiryDays'] as num?)?.toInt() ?? 7,
  reservationWarehouseId: (json['reservationWarehouseId'] as num?)?.toInt(),
  reservationWarehouseName: json['reservationWarehouseName'] as String?,
  reservationLocationId: (json['reservationLocationId'] as num?)?.toInt(),
  reservationLocationName: json['reservationLocationName'] as String?,
  reserveFromQuotation: json['reserveFromQuotation'] as bool? ?? false,
  writeDate: json['writeDate'] == null
      ? null
      : DateTime.parse(json['writeDate'] as String),
);

Map<String, dynamic> _$CompanyToJson(_Company instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'vat': instance.vat,
  'street': instance.street,
  'street2': instance.street2,
  'city': instance.city,
  'zip': instance.zip,
  'countryId': instance.countryId,
  'countryName': instance.countryName,
  'stateId': instance.stateId,
  'stateName': instance.stateName,
  'phone': instance.phone,
  'mobile': instance.mobile,
  'email': instance.email,
  'website': instance.website,
  'currencyId': instance.currencyId,
  'currencyName': instance.currencyName,
  'parentId': instance.parentId,
  'parentName': instance.parentName,
  'l10nEcComercialName': instance.l10nEcComercialName,
  'l10nEcLegalName': instance.l10nEcLegalName,
  'l10nEcProductionEnv': instance.l10nEcProductionEnv,
  'logo': instance.logo,
  'reportHeaderImage': instance.reportHeaderImage,
  'reportFooter': instance.reportFooter,
  'primaryColor': instance.primaryColor,
  'secondaryColor': instance.secondaryColor,
  'font': instance.font,
  'layoutBackground': instance.layoutBackground,
  'externalReportLayoutId': instance.externalReportLayoutId,
  'taxCalculationRoundingMethod': instance.taxCalculationRoundingMethod,
  'quotationValidityDays': instance.quotationValidityDays,
  'portalConfirmationSign': instance.portalConfirmationSign,
  'portalConfirmationPay': instance.portalConfirmationPay,
  'prepaymentPercent': instance.prepaymentPercent,
  'saleDiscountProductId': instance.saleDiscountProductId,
  'saleDiscountProductName': instance.saleDiscountProductName,
  'defaultPartnerId': instance.defaultPartnerId,
  'defaultPartnerName': instance.defaultPartnerName,
  'defaultWarehouseId': instance.defaultWarehouseId,
  'defaultWarehouseName': instance.defaultWarehouseName,
  'defaultPricelistId': instance.defaultPricelistId,
  'defaultPricelistName': instance.defaultPricelistName,
  'defaultPaymentTermId': instance.defaultPaymentTermId,
  'defaultPaymentTermName': instance.defaultPaymentTermName,
  'pedirEndCustomerData': instance.pedirEndCustomerData,
  'pedirSaleReferrer': instance.pedirSaleReferrer,
  'pedirTipoCanalCliente': instance.pedirTipoCanalCliente,
  'saleCustomerInvoiceLimitSri': instance.saleCustomerInvoiceLimitSri,
  'maxDiscountPercentage': instance.maxDiscountPercentage,
  'creditOverdueDaysThreshold': instance.creditOverdueDaysThreshold,
  'creditOverdueInvoicesThreshold': instance.creditOverdueInvoicesThreshold,
  'creditOfflineSafetyMargin': instance.creditOfflineSafetyMargin,
  'creditDataMaxAgeHours': instance.creditDataMaxAgeHours,
  'reservationExpiryDays': instance.reservationExpiryDays,
  'reservationWarehouseId': instance.reservationWarehouseId,
  'reservationWarehouseName': instance.reservationWarehouseName,
  'reservationLocationId': instance.reservationLocationId,
  'reservationLocationName': instance.reservationLocationName,
  'reserveFromQuotation': instance.reserveFromQuotation,
  'writeDate': instance.writeDate?.toIso8601String(),
};

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for Company.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: res.company
class CompanyManager extends OdooModelManager<Company>
    with GenericDriftOperations<Company> {
  @override
  String get odooModel => 'res.company';

  @override
  String get tableName => 'res_company_table';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'vat',
    'street',
    'street2',
    'city',
    'zip',
    'country_id',
    'state_id',
    'phone',
    'email',
    'website',
    'currency_id',
    'parent_id',
    'l10n_ec_comercial_name',
    'l10n_ec_legal_name',
    'l10n_ec_production_env',
    'logo',
    'report_header_image',
    'report_footer',
    'primary_color',
    'secondary_color',
    'font',
    'external_report_layout_id',
    'tax_calculation_rounding_method',
    'quotation_validity_days',
    'portal_confirmation_sign',
    'portal_confirmation_pay',
    'prepayment_percent',
    'sale_discount_product_id',
    'partner_id',
    'warehouse_id',
    'default_pricelist_id',
    'default_payment_term_id',
    'pedir_end_customer_data',
    'pedir_sale_referrer',
    'pedir_tipo_canal_cliente',
    'sale_customer_invoice_limit_sri',
    'max_discount_percentage',
    'credit_overdue_days_threshold',
    'credit_overdue_invoices_threshold',
    'credit_offline_safety_margin',
    'credit_data_max_age_hours',
    'reservation_expiry_days',
    'reservation_warehouse_id',
    'reservation_location_id',
    'reserve_from_quotation',
    'write_date',
  ];

  @override
  Company fromOdoo(Map<String, dynamic> data) {
    return Company(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      vat: parseOdooString(data['vat']),
      street: parseOdooString(data['street']),
      street2: parseOdooString(data['street2']),
      city: parseOdooString(data['city']),
      zip: parseOdooString(data['zip']),
      countryId: extractMany2oneId(data['country_id']),
      countryName: extractMany2oneName(data['country_id']),
      stateId: extractMany2oneId(data['state_id']),
      stateName: extractMany2oneName(data['state_id']),
      phone: parseOdooString(data['phone']),
      email: parseOdooString(data['email']),
      website: parseOdooString(data['website']),
      currencyId: extractMany2oneId(data['currency_id']),
      currencyName: extractMany2oneName(data['currency_id']),
      parentId: extractMany2oneId(data['parent_id']),
      parentName: extractMany2oneName(data['parent_id']),
      l10nEcComercialName: parseOdooString(data['l10n_ec_comercial_name']),
      l10nEcLegalName: parseOdooString(data['l10n_ec_legal_name']),
      l10nEcProductionEnv: parseOdooBool(data['l10n_ec_production_env']),
      logo: parseOdooString(data['logo']),
      reportHeaderImage: parseOdooString(data['report_header_image']),
      reportFooter: parseOdooString(data['report_footer']),
      primaryColor: parseOdooString(data['primary_color']),
      secondaryColor: parseOdooString(data['secondary_color']),
      font: parseOdooString(data['font']),
      externalReportLayoutId: extractMany2oneId(
        data['external_report_layout_id'],
      ),
      taxCalculationRoundingMethod:
          parseOdooSelection(data['tax_calculation_rounding_method']) ?? '',
      quotationValidityDays: parseOdooInt(data['quotation_validity_days']) ?? 0,
      portalConfirmationSign: parseOdooBool(data['portal_confirmation_sign']),
      portalConfirmationPay: parseOdooBool(data['portal_confirmation_pay']),
      prepaymentPercent: parseOdooDouble(data['prepayment_percent']) ?? 0.0,
      saleDiscountProductId: extractMany2oneId(
        data['sale_discount_product_id'],
      ),
      saleDiscountProductName: extractMany2oneName(
        data['sale_discount_product_id'],
      ),
      defaultPartnerId: extractMany2oneId(data['partner_id']),
      defaultPartnerName: extractMany2oneName(data['partner_id']),
      defaultWarehouseId: extractMany2oneId(data['warehouse_id']),
      defaultWarehouseName: extractMany2oneName(data['warehouse_id']),
      defaultPricelistId: extractMany2oneId(data['default_pricelist_id']),
      defaultPricelistName: extractMany2oneName(data['default_pricelist_id']),
      defaultPaymentTermId: extractMany2oneId(data['default_payment_term_id']),
      defaultPaymentTermName: extractMany2oneName(
        data['default_payment_term_id'],
      ),
      pedirEndCustomerData: parseOdooBool(data['pedir_end_customer_data']),
      pedirSaleReferrer: parseOdooBool(data['pedir_sale_referrer']),
      pedirTipoCanalCliente: parseOdooBool(data['pedir_tipo_canal_cliente']),
      saleCustomerInvoiceLimitSri: parseOdooDouble(
        data['sale_customer_invoice_limit_sri'],
      ),
      maxDiscountPercentage:
          parseOdooDouble(data['max_discount_percentage']) ?? 0.0,
      creditOverdueDaysThreshold:
          parseOdooInt(data['credit_overdue_days_threshold']) ?? 0,
      creditOverdueInvoicesThreshold:
          parseOdooInt(data['credit_overdue_invoices_threshold']) ?? 0,
      creditOfflineSafetyMargin:
          parseOdooDouble(data['credit_offline_safety_margin']) ?? 0.0,
      creditDataMaxAgeHours:
          parseOdooInt(data['credit_data_max_age_hours']) ?? 0,
      reservationExpiryDays: parseOdooInt(data['reservation_expiry_days']) ?? 0,
      reservationWarehouseId: extractMany2oneId(
        data['reservation_warehouse_id'],
      ),
      reservationWarehouseName: extractMany2oneName(
        data['reservation_warehouse_id'],
      ),
      reservationLocationId: extractMany2oneId(data['reservation_location_id']),
      reservationLocationName: extractMany2oneName(
        data['reservation_location_id'],
      ),
      reserveFromQuotation: parseOdooBool(data['reserve_from_quotation']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(Company record) {
    return {
      'name': record.name,
      'vat': record.vat,
      'street': record.street,
      'street2': record.street2,
      'city': record.city,
      'zip': record.zip,
      'country_id': record.countryId,
      'state_id': record.stateId,
      'phone': record.phone,
      'email': record.email,
      'website': record.website,
      'currency_id': record.currencyId,
      'parent_id': record.parentId,
      'l10n_ec_comercial_name': record.l10nEcComercialName,
      'l10n_ec_legal_name': record.l10nEcLegalName,
      'l10n_ec_production_env': record.l10nEcProductionEnv,
      'logo': record.logo,
      'report_header_image': record.reportHeaderImage,
      'report_footer': record.reportFooter,
      'primary_color': record.primaryColor,
      'secondary_color': record.secondaryColor,
      'font': record.font,
      'external_report_layout_id': record.externalReportLayoutId,
      'tax_calculation_rounding_method': record.taxCalculationRoundingMethod,
      'quotation_validity_days': record.quotationValidityDays,
      'portal_confirmation_sign': record.portalConfirmationSign,
      'portal_confirmation_pay': record.portalConfirmationPay,
      'prepayment_percent': record.prepaymentPercent,
      'sale_discount_product_id': record.saleDiscountProductId,
      'partner_id': record.defaultPartnerId,
      'warehouse_id': record.defaultWarehouseId,
      'default_pricelist_id': record.defaultPricelistId,
      'default_payment_term_id': record.defaultPaymentTermId,
      'pedir_end_customer_data': record.pedirEndCustomerData,
      'pedir_sale_referrer': record.pedirSaleReferrer,
      'pedir_tipo_canal_cliente': record.pedirTipoCanalCliente,
      'sale_customer_invoice_limit_sri': record.saleCustomerInvoiceLimitSri,
      'max_discount_percentage': record.maxDiscountPercentage,
      'credit_overdue_days_threshold': record.creditOverdueDaysThreshold,
      'credit_overdue_invoices_threshold':
          record.creditOverdueInvoicesThreshold,
      'credit_offline_safety_margin': record.creditOfflineSafetyMargin,
      'credit_data_max_age_hours': record.creditDataMaxAgeHours,
      'reservation_expiry_days': record.reservationExpiryDays,
      'reservation_warehouse_id': record.reservationWarehouseId,
      'reservation_location_id': record.reservationLocationId,
      'reserve_from_quotation': record.reserveFromQuotation,
    };
  }

  @override
  Company fromDrift(dynamic row) {
    return Company(
      id: row.odooId as int,
      name: row.name as String,
      vat: row.vat as String?,
      street: row.street as String?,
      street2: row.street2 as String?,
      city: row.city as String?,
      zip: row.zip as String?,
      countryId: row.countryId as int?,
      countryName: row.countryName as String?,
      stateId: row.stateId as int?,
      stateName: row.stateName as String?,
      phone: row.phone as String?,
      mobile: row.mobile as String?,
      email: row.email as String?,
      website: row.website as String?,
      currencyId: row.currencyId as int?,
      currencyName: row.currencyName as String?,
      parentId: row.parentId as int?,
      parentName: row.parentName as String?,
      l10nEcComercialName: row.l10nEcComercialName as String?,
      l10nEcLegalName: row.l10nEcLegalName as String?,
      l10nEcProductionEnv: row.l10nEcProductionEnv as bool,
      logo: row.logo as String?,
      reportHeaderImage: row.reportHeaderImage as String?,
      reportFooter: row.reportFooter as String?,
      primaryColor: row.primaryColor as String?,
      secondaryColor: row.secondaryColor as String?,
      font: row.font as String?,
      layoutBackground: row.layoutBackground as String?,
      externalReportLayoutId: row.externalReportLayoutId as int?,
      taxCalculationRoundingMethod: row.taxCalculationRoundingMethod as String,
      quotationValidityDays: row.quotationValidityDays as int,
      portalConfirmationSign: row.portalConfirmationSign as bool,
      portalConfirmationPay: row.portalConfirmationPay as bool,
      prepaymentPercent: row.prepaymentPercent as double,
      saleDiscountProductId: row.saleDiscountProductId as int?,
      saleDiscountProductName: row.saleDiscountProductName as String?,
      defaultPartnerId: row.partnerId as int?,
      defaultPartnerName: row.defaultPartnerName as String?,
      defaultWarehouseId: row.warehouseId as int?,
      defaultWarehouseName: row.defaultWarehouseName as String?,
      defaultPricelistId: row.defaultPricelistId as int?,
      defaultPricelistName: row.defaultPricelistName as String?,
      defaultPaymentTermId: row.defaultPaymentTermId as int?,
      defaultPaymentTermName: row.defaultPaymentTermName as String?,
      pedirEndCustomerData: row.pedirEndCustomerData as bool,
      pedirSaleReferrer: row.pedirSaleReferrer as bool,
      pedirTipoCanalCliente: row.pedirTipoCanalCliente as bool,
      saleCustomerInvoiceLimitSri: row.saleCustomerInvoiceLimitSri as double?,
      maxDiscountPercentage: row.maxDiscountPercentage as double,
      creditOverdueDaysThreshold: row.creditOverdueDaysThreshold as int,
      creditOverdueInvoicesThreshold: row.creditOverdueInvoicesThreshold as int,
      creditOfflineSafetyMargin: row.creditOfflineSafetyMargin as double,
      creditDataMaxAgeHours: row.creditDataMaxAgeHours as int,
      reservationExpiryDays: row.reservationExpiryDays as int,
      reservationWarehouseId: row.reservationWarehouseId as int?,
      reservationWarehouseName: row.reservationWarehouseName as String?,
      reservationLocationId: row.reservationLocationId as int?,
      reservationLocationName: row.reservationLocationName as String?,
      reserveFromQuotation: row.reserveFromQuotation as bool,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(Company record) => record.id;

  @override
  String? getUuid(Company record) => null;

  @override
  Company withIdAndUuid(Company record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  Company withSyncStatus(Company record, bool isSynced) {
    return record; // No sync status field
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'name': 'name',
    'vat': 'vat',
    'street': 'street',
    'street2': 'street2',
    'city': 'city',
    'zip': 'zip',
    'country_id': 'countryId',
    'state_id': 'stateId',
    'phone': 'phone',
    'email': 'email',
    'website': 'website',
    'currency_id': 'currencyId',
    'parent_id': 'parentId',
    'l10n_ec_comercial_name': 'l10nEcComercialName',
    'l10n_ec_legal_name': 'l10nEcLegalName',
    'l10n_ec_production_env': 'l10nEcProductionEnv',
    'logo': 'logo',
    'report_header_image': 'reportHeaderImage',
    'report_footer': 'reportFooter',
    'primary_color': 'primaryColor',
    'secondary_color': 'secondaryColor',
    'font': 'font',
    'external_report_layout_id': 'externalReportLayoutId',
    'tax_calculation_rounding_method': 'taxCalculationRoundingMethod',
    'quotation_validity_days': 'quotationValidityDays',
    'portal_confirmation_sign': 'portalConfirmationSign',
    'portal_confirmation_pay': 'portalConfirmationPay',
    'prepayment_percent': 'prepaymentPercent',
    'sale_discount_product_id': 'saleDiscountProductId',
    'partner_id': 'defaultPartnerId',
    'warehouse_id': 'defaultWarehouseId',
    'default_pricelist_id': 'defaultPricelistId',
    'default_payment_term_id': 'defaultPaymentTermId',
    'pedir_end_customer_data': 'pedirEndCustomerData',
    'pedir_sale_referrer': 'pedirSaleReferrer',
    'pedir_tipo_canal_cliente': 'pedirTipoCanalCliente',
    'sale_customer_invoice_limit_sri': 'saleCustomerInvoiceLimitSri',
    'max_discount_percentage': 'maxDiscountPercentage',
    'credit_overdue_days_threshold': 'creditOverdueDaysThreshold',
    'credit_overdue_invoices_threshold': 'creditOverdueInvoicesThreshold',
    'credit_offline_safety_margin': 'creditOfflineSafetyMargin',
    'credit_data_max_age_hours': 'creditDataMaxAgeHours',
    'reservation_expiry_days': 'reservationExpiryDays',
    'reservation_warehouse_id': 'reservationWarehouseId',
    'reservation_location_id': 'reservationLocationId',
    'reserve_from_quotation': 'reserveFromQuotation',
    'write_date': 'writeDate',
  };

  /// Get Dart field name from Odoo field name.
  String? getDartFieldName(String odooField) => fieldMappings[odooField];

  /// Get Odoo field name from Dart field name.
  String? getOdooFieldName(String dartField) {
    for (final entry in fieldMappings.entries) {
      if (entry.value == dartField) return entry.key;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════
  // GenericDriftOperations — Database & Table
  // ═══════════════════════════════════════════════════

  @override
  GeneratedDatabase get database {
    final db = this.db;
    if (db == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return db;
  }

  @override
  TableInfo get table {
    final resolved = resolveTable();
    if (resolved == null) {
      throw StateError('Table \'res_company_table\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(Company record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'vat': driftVar<String>(record.vat),
      'street': driftVar<String>(record.street),
      'street2': driftVar<String>(record.street2),
      'city': driftVar<String>(record.city),
      'zip': driftVar<String>(record.zip),
      'country_id': driftVar<int>(record.countryId),
      'country_id_name': driftVar<String>(record.countryName),
      'state_id': driftVar<int>(record.stateId),
      'state_id_name': driftVar<String>(record.stateName),
      'phone': driftVar<String>(record.phone),
      'email': driftVar<String>(record.email),
      'website': driftVar<String>(record.website),
      'currency_id': driftVar<int>(record.currencyId),
      'currency_id_name': driftVar<String>(record.currencyName),
      'parent_id': driftVar<int>(record.parentId),
      'parent_id_name': driftVar<String>(record.parentName),
      'l10n_ec_comercial_name': driftVar<String>(record.l10nEcComercialName),
      'l10n_ec_legal_name': driftVar<String>(record.l10nEcLegalName),
      'l10n_ec_production_env': Variable<bool>(record.l10nEcProductionEnv),
      'logo': driftVar<String>(record.logo),
      'report_header_image': driftVar<String>(record.reportHeaderImage),
      'report_footer': driftVar<String>(record.reportFooter),
      'primary_color': driftVar<String>(record.primaryColor),
      'secondary_color': driftVar<String>(record.secondaryColor),
      'font': driftVar<String>(record.font),
      'external_report_layout_id': driftVar<int>(record.externalReportLayoutId),
      'tax_calculation_rounding_method': Variable<String>(
        record.taxCalculationRoundingMethod,
      ),
      'quotation_validity_days': Variable<int>(record.quotationValidityDays),
      'portal_confirmation_sign': Variable<bool>(record.portalConfirmationSign),
      'portal_confirmation_pay': Variable<bool>(record.portalConfirmationPay),
      'prepayment_percent': Variable<double>(record.prepaymentPercent),
      'sale_discount_product_id': driftVar<int>(record.saleDiscountProductId),
      'sale_discount_product_id_name': driftVar<String>(
        record.saleDiscountProductName,
      ),
      'partner_id': driftVar<int>(record.defaultPartnerId),
      'partner_id_name': driftVar<String>(record.defaultPartnerName),
      'warehouse_id': driftVar<int>(record.defaultWarehouseId),
      'warehouse_id_name': driftVar<String>(record.defaultWarehouseName),
      'default_pricelist_id': driftVar<int>(record.defaultPricelistId),
      'default_pricelist_id_name': driftVar<String>(
        record.defaultPricelistName,
      ),
      'default_payment_term_id': driftVar<int>(record.defaultPaymentTermId),
      'default_payment_term_id_name': driftVar<String>(
        record.defaultPaymentTermName,
      ),
      'pedir_end_customer_data': Variable<bool>(record.pedirEndCustomerData),
      'pedir_sale_referrer': Variable<bool>(record.pedirSaleReferrer),
      'pedir_tipo_canal_cliente': Variable<bool>(record.pedirTipoCanalCliente),
      'sale_customer_invoice_limit_sri': driftVar<double>(
        record.saleCustomerInvoiceLimitSri,
      ),
      'max_discount_percentage': Variable<double>(record.maxDiscountPercentage),
      'credit_overdue_days_threshold': Variable<int>(
        record.creditOverdueDaysThreshold,
      ),
      'credit_overdue_invoices_threshold': Variable<int>(
        record.creditOverdueInvoicesThreshold,
      ),
      'credit_offline_safety_margin': Variable<double>(
        record.creditOfflineSafetyMargin,
      ),
      'credit_data_max_age_hours': Variable<int>(record.creditDataMaxAgeHours),
      'reservation_expiry_days': Variable<int>(record.reservationExpiryDays),
      'reservation_warehouse_id': driftVar<int>(record.reservationWarehouseId),
      'reservation_warehouse_id_name': driftVar<String>(
        record.reservationWarehouseName,
      ),
      'reservation_location_id': driftVar<int>(record.reservationLocationId),
      'reservation_location_id_name': driftVar<String>(
        record.reservationLocationName,
      ),
      'reserve_from_quotation': Variable<bool>(record.reserveFromQuotation),
      'write_date': driftVar<DateTime>(record.writeDate),
      'mobile': driftVar<String>(record.mobile),
      'layout_background': driftVar<String>(record.layoutBackground),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'vat',
    'street',
    'street2',
    'city',
    'zip',
    'countryId',
    'stateId',
    'phone',
    'email',
    'website',
    'currencyId',
    'parentId',
    'l10nEcComercialName',
    'l10nEcLegalName',
    'l10nEcProductionEnv',
    'logo',
    'reportHeaderImage',
    'reportFooter',
    'primaryColor',
    'secondaryColor',
    'font',
    'externalReportLayoutId',
    'taxCalculationRoundingMethod',
    'quotationValidityDays',
    'portalConfirmationSign',
    'portalConfirmationPay',
    'prepaymentPercent',
    'saleDiscountProductId',
    'defaultPartnerId',
    'defaultWarehouseId',
    'defaultPricelistId',
    'defaultPaymentTermId',
    'pedirEndCustomerData',
    'pedirSaleReferrer',
    'pedirTipoCanalCliente',
    'saleCustomerInvoiceLimitSri',
    'maxDiscountPercentage',
    'creditOverdueDaysThreshold',
    'creditOverdueInvoicesThreshold',
    'creditOfflineSafetyMargin',
    'creditDataMaxAgeHours',
    'reservationExpiryDays',
    'reservationWarehouseId',
    'reservationLocationId',
    'reserveFromQuotation',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'vat': 'Vat',
    'street': 'Street',
    'street2': 'Street2',
    'city': 'City',
    'zip': 'Zip',
    'countryId': 'Country Id',
    'countryName': 'Country Name',
    'stateId': 'State Id',
    'stateName': 'State Name',
    'phone': 'Phone',
    'mobile': 'Mobile',
    'email': 'Email',
    'website': 'Website',
    'currencyId': 'Currency Id',
    'currencyName': 'Currency Name',
    'parentId': 'Parent Id',
    'parentName': 'Parent Name',
    'l10nEcComercialName': 'L10n Ec Comercial Name',
    'l10nEcLegalName': 'L10n Ec Legal Name',
    'l10nEcProductionEnv': 'L10n Ec Production Env',
    'logo': 'Logo',
    'reportHeaderImage': 'Report Header Image',
    'reportFooter': 'Report Footer',
    'primaryColor': 'Primary Color',
    'secondaryColor': 'Secondary Color',
    'font': 'Font',
    'layoutBackground': 'Layout Background',
    'externalReportLayoutId': 'External Report Layout Id',
    'taxCalculationRoundingMethod': 'Tax Calculation Rounding Method',
    'quotationValidityDays': 'Quotation Validity Days',
    'portalConfirmationSign': 'Portal Confirmation Sign',
    'portalConfirmationPay': 'Portal Confirmation Pay',
    'prepaymentPercent': 'Prepayment Percent',
    'saleDiscountProductId': 'Sale Discount Product Id',
    'saleDiscountProductName': 'Sale Discount Product Name',
    'defaultPartnerId': 'Default Partner Id',
    'defaultPartnerName': 'Default Partner Name',
    'defaultWarehouseId': 'Default Warehouse Id',
    'defaultWarehouseName': 'Default Warehouse Name',
    'defaultPricelistId': 'Default Pricelist Id',
    'defaultPricelistName': 'Default Pricelist Name',
    'defaultPaymentTermId': 'Default Payment Term Id',
    'defaultPaymentTermName': 'Default Payment Term Name',
    'pedirEndCustomerData': 'Pedir End Customer Data',
    'pedirSaleReferrer': 'Pedir Sale Referrer',
    'pedirTipoCanalCliente': 'Pedir Tipo Canal Cliente',
    'saleCustomerInvoiceLimitSri': 'Sale Customer Invoice Limit Sri',
    'maxDiscountPercentage': 'Max Discount Percentage',
    'creditOverdueDaysThreshold': 'Credit Overdue Days Threshold',
    'creditOverdueInvoicesThreshold': 'Credit Overdue Invoices Threshold',
    'creditOfflineSafetyMargin': 'Credit Offline Safety Margin',
    'creditDataMaxAgeHours': 'Credit Data Max Age Hours',
    'reservationExpiryDays': 'Reservation Expiry Days',
    'reservationWarehouseId': 'Reservation Warehouse Id',
    'reservationWarehouseName': 'Reservation Warehouse Name',
    'reservationLocationId': 'Reservation Location Id',
    'reservationLocationName': 'Reservation Location Name',
    'reserveFromQuotation': 'Reserve From Quotation',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(Company record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(Company record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(Company record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(Company record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'vat':
        return record.vat;
      case 'street':
        return record.street;
      case 'street2':
        return record.street2;
      case 'city':
        return record.city;
      case 'zip':
        return record.zip;
      case 'countryId':
        return record.countryId;
      case 'countryName':
        return record.countryName;
      case 'stateId':
        return record.stateId;
      case 'stateName':
        return record.stateName;
      case 'phone':
        return record.phone;
      case 'mobile':
        return record.mobile;
      case 'email':
        return record.email;
      case 'website':
        return record.website;
      case 'currencyId':
        return record.currencyId;
      case 'currencyName':
        return record.currencyName;
      case 'parentId':
        return record.parentId;
      case 'parentName':
        return record.parentName;
      case 'l10nEcComercialName':
        return record.l10nEcComercialName;
      case 'l10nEcLegalName':
        return record.l10nEcLegalName;
      case 'l10nEcProductionEnv':
        return record.l10nEcProductionEnv;
      case 'logo':
        return record.logo;
      case 'reportHeaderImage':
        return record.reportHeaderImage;
      case 'reportFooter':
        return record.reportFooter;
      case 'primaryColor':
        return record.primaryColor;
      case 'secondaryColor':
        return record.secondaryColor;
      case 'font':
        return record.font;
      case 'layoutBackground':
        return record.layoutBackground;
      case 'externalReportLayoutId':
        return record.externalReportLayoutId;
      case 'taxCalculationRoundingMethod':
        return record.taxCalculationRoundingMethod;
      case 'quotationValidityDays':
        return record.quotationValidityDays;
      case 'portalConfirmationSign':
        return record.portalConfirmationSign;
      case 'portalConfirmationPay':
        return record.portalConfirmationPay;
      case 'prepaymentPercent':
        return record.prepaymentPercent;
      case 'saleDiscountProductId':
        return record.saleDiscountProductId;
      case 'saleDiscountProductName':
        return record.saleDiscountProductName;
      case 'defaultPartnerId':
        return record.defaultPartnerId;
      case 'defaultPartnerName':
        return record.defaultPartnerName;
      case 'defaultWarehouseId':
        return record.defaultWarehouseId;
      case 'defaultWarehouseName':
        return record.defaultWarehouseName;
      case 'defaultPricelistId':
        return record.defaultPricelistId;
      case 'defaultPricelistName':
        return record.defaultPricelistName;
      case 'defaultPaymentTermId':
        return record.defaultPaymentTermId;
      case 'defaultPaymentTermName':
        return record.defaultPaymentTermName;
      case 'pedirEndCustomerData':
        return record.pedirEndCustomerData;
      case 'pedirSaleReferrer':
        return record.pedirSaleReferrer;
      case 'pedirTipoCanalCliente':
        return record.pedirTipoCanalCliente;
      case 'saleCustomerInvoiceLimitSri':
        return record.saleCustomerInvoiceLimitSri;
      case 'maxDiscountPercentage':
        return record.maxDiscountPercentage;
      case 'creditOverdueDaysThreshold':
        return record.creditOverdueDaysThreshold;
      case 'creditOverdueInvoicesThreshold':
        return record.creditOverdueInvoicesThreshold;
      case 'creditOfflineSafetyMargin':
        return record.creditOfflineSafetyMargin;
      case 'creditDataMaxAgeHours':
        return record.creditDataMaxAgeHours;
      case 'reservationExpiryDays':
        return record.reservationExpiryDays;
      case 'reservationWarehouseId':
        return record.reservationWarehouseId;
      case 'reservationWarehouseName':
        return record.reservationWarehouseName;
      case 'reservationLocationId':
        return record.reservationLocationId;
      case 'reservationLocationName':
        return record.reservationLocationName;
      case 'reserveFromQuotation':
        return record.reserveFromQuotation;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  Company applyWebSocketChangesToRecord(
    Company record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      mobile: record.mobile,
      layoutBackground: record.layoutBackground,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'name':
        return (obj as dynamic).name;
      case 'vat':
        return (obj as dynamic).vat;
      case 'street':
        return (obj as dynamic).street;
      case 'street2':
        return (obj as dynamic).street2;
      case 'city':
        return (obj as dynamic).city;
      case 'zip':
        return (obj as dynamic).zip;
      case 'countryId':
        return (obj as dynamic).countryId;
      case 'countryName':
        return (obj as dynamic).countryName;
      case 'stateId':
        return (obj as dynamic).stateId;
      case 'stateName':
        return (obj as dynamic).stateName;
      case 'phone':
        return (obj as dynamic).phone;
      case 'mobile':
        return (obj as dynamic).mobile;
      case 'email':
        return (obj as dynamic).email;
      case 'website':
        return (obj as dynamic).website;
      case 'currencyId':
        return (obj as dynamic).currencyId;
      case 'currencyName':
        return (obj as dynamic).currencyName;
      case 'parentId':
        return (obj as dynamic).parentId;
      case 'parentName':
        return (obj as dynamic).parentName;
      case 'l10nEcComercialName':
        return (obj as dynamic).l10nEcComercialName;
      case 'l10nEcLegalName':
        return (obj as dynamic).l10nEcLegalName;
      case 'l10nEcProductionEnv':
        return (obj as dynamic).l10nEcProductionEnv;
      case 'logo':
        return (obj as dynamic).logo;
      case 'reportHeaderImage':
        return (obj as dynamic).reportHeaderImage;
      case 'reportFooter':
        return (obj as dynamic).reportFooter;
      case 'primaryColor':
        return (obj as dynamic).primaryColor;
      case 'secondaryColor':
        return (obj as dynamic).secondaryColor;
      case 'font':
        return (obj as dynamic).font;
      case 'layoutBackground':
        return (obj as dynamic).layoutBackground;
      case 'externalReportLayoutId':
        return (obj as dynamic).externalReportLayoutId;
      case 'taxCalculationRoundingMethod':
        return (obj as dynamic).taxCalculationRoundingMethod;
      case 'quotationValidityDays':
        return (obj as dynamic).quotationValidityDays;
      case 'portalConfirmationSign':
        return (obj as dynamic).portalConfirmationSign;
      case 'portalConfirmationPay':
        return (obj as dynamic).portalConfirmationPay;
      case 'prepaymentPercent':
        return (obj as dynamic).prepaymentPercent;
      case 'saleDiscountProductId':
        return (obj as dynamic).saleDiscountProductId;
      case 'saleDiscountProductName':
        return (obj as dynamic).saleDiscountProductName;
      case 'defaultPartnerId':
        return (obj as dynamic).partnerId;
      case 'defaultPartnerName':
        return (obj as dynamic).defaultPartnerName;
      case 'defaultWarehouseId':
        return (obj as dynamic).warehouseId;
      case 'defaultWarehouseName':
        return (obj as dynamic).defaultWarehouseName;
      case 'defaultPricelistId':
        return (obj as dynamic).defaultPricelistId;
      case 'defaultPricelistName':
        return (obj as dynamic).defaultPricelistName;
      case 'defaultPaymentTermId':
        return (obj as dynamic).defaultPaymentTermId;
      case 'defaultPaymentTermName':
        return (obj as dynamic).defaultPaymentTermName;
      case 'pedirEndCustomerData':
        return (obj as dynamic).pedirEndCustomerData;
      case 'pedirSaleReferrer':
        return (obj as dynamic).pedirSaleReferrer;
      case 'pedirTipoCanalCliente':
        return (obj as dynamic).pedirTipoCanalCliente;
      case 'saleCustomerInvoiceLimitSri':
        return (obj as dynamic).saleCustomerInvoiceLimitSri;
      case 'maxDiscountPercentage':
        return (obj as dynamic).maxDiscountPercentage;
      case 'creditOverdueDaysThreshold':
        return (obj as dynamic).creditOverdueDaysThreshold;
      case 'creditOverdueInvoicesThreshold':
        return (obj as dynamic).creditOverdueInvoicesThreshold;
      case 'creditOfflineSafetyMargin':
        return (obj as dynamic).creditOfflineSafetyMargin;
      case 'creditDataMaxAgeHours':
        return (obj as dynamic).creditDataMaxAgeHours;
      case 'reservationExpiryDays':
        return (obj as dynamic).reservationExpiryDays;
      case 'reservationWarehouseId':
        return (obj as dynamic).reservationWarehouseId;
      case 'reservationWarehouseName':
        return (obj as dynamic).reservationWarehouseName;
      case 'reservationLocationId':
        return (obj as dynamic).reservationLocationId;
      case 'reservationLocationName':
        return (obj as dynamic).reservationLocationName;
      case 'reserveFromQuotation':
        return (obj as dynamic).reserveFromQuotation;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'uuid':
        return (obj as dynamic).uuid;
      case 'localCreatedAt':
        return (obj as dynamic).localCreatedAt;
      default:
        return super.accessProperty(obj, name);
    }
  }

  @override
  List<String> get computedFieldNames => const [];

  @override
  List<String> get storedFieldNames => const [
    'id',
    'name',
    'vat',
    'street',
    'street2',
    'city',
    'zip',
    'countryId',
    'countryName',
    'stateId',
    'stateName',
    'phone',
    'mobile',
    'email',
    'website',
    'currencyId',
    'currencyName',
    'parentId',
    'parentName',
    'l10nEcComercialName',
    'l10nEcLegalName',
    'l10nEcProductionEnv',
    'logo',
    'reportHeaderImage',
    'reportFooter',
    'primaryColor',
    'secondaryColor',
    'font',
    'layoutBackground',
    'externalReportLayoutId',
    'taxCalculationRoundingMethod',
    'quotationValidityDays',
    'portalConfirmationSign',
    'portalConfirmationPay',
    'prepaymentPercent',
    'saleDiscountProductId',
    'saleDiscountProductName',
    'defaultPartnerId',
    'defaultPartnerName',
    'defaultWarehouseId',
    'defaultWarehouseName',
    'defaultPricelistId',
    'defaultPricelistName',
    'defaultPaymentTermId',
    'defaultPaymentTermName',
    'pedirEndCustomerData',
    'pedirSaleReferrer',
    'pedirTipoCanalCliente',
    'saleCustomerInvoiceLimitSri',
    'maxDiscountPercentage',
    'creditOverdueDaysThreshold',
    'creditOverdueInvoicesThreshold',
    'creditOfflineSafetyMargin',
    'creditDataMaxAgeHours',
    'reservationExpiryDays',
    'reservationWarehouseId',
    'reservationWarehouseName',
    'reservationLocationId',
    'reservationLocationName',
    'reserveFromQuotation',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'vat',
    'street',
    'street2',
    'city',
    'zip',
    'countryId',
    'stateId',
    'phone',
    'email',
    'website',
    'currencyId',
    'parentId',
    'l10nEcComercialName',
    'l10nEcLegalName',
    'l10nEcProductionEnv',
    'logo',
    'reportHeaderImage',
    'reportFooter',
    'primaryColor',
    'secondaryColor',
    'font',
    'externalReportLayoutId',
    'taxCalculationRoundingMethod',
    'quotationValidityDays',
    'portalConfirmationSign',
    'portalConfirmationPay',
    'prepaymentPercent',
    'saleDiscountProductId',
    'defaultPartnerId',
    'defaultWarehouseId',
    'defaultPricelistId',
    'defaultPaymentTermId',
    'pedirEndCustomerData',
    'pedirSaleReferrer',
    'pedirTipoCanalCliente',
    'saleCustomerInvoiceLimitSri',
    'maxDiscountPercentage',
    'creditOverdueDaysThreshold',
    'creditOverdueInvoicesThreshold',
    'creditOfflineSafetyMargin',
    'creditDataMaxAgeHours',
    'reservationExpiryDays',
    'reservationWarehouseId',
    'reservationLocationId',
    'reserveFromQuotation',
  ];
}

/// Global instance of CompanyManager.
final companyManager = CompanyManager();
