/// Company Model - res.company
///
/// Represents company information synced from Odoo.
/// Includes document layout, Ecuador SRI fields, and sales configuration.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'company.model.freezed.dart';
part 'company.model.g.dart';

/// Company model for res.company
@OdooModel('res.company', tableName: 'res_company_table')
@freezed
abstract class Company with _$Company {
  const Company._();

  const factory Company({
    // ═══════════════════ Identifiers ═══════════════════
    @OdooId() required int id,
    @OdooString() required String name,

    // ═══════════════════ Basic Info ═══════════════════
    @OdooString() String? vat,
    @OdooString() String? street,
    @OdooString(odooName: 'street2') String? street2,
    @OdooString() String? city,
    @OdooString() String? zip,
    @OdooMany2One('res.country', odooName: 'country_id') int? countryId,
    @OdooMany2OneName(sourceField: 'country_id') String? countryName,
    @OdooMany2One('res.country.state', odooName: 'state_id') int? stateId,
    @OdooMany2OneName(sourceField: 'state_id') String? stateName,
    @OdooString() String? phone,
    @OdooLocalOnly() String? mobile, // Removed from Odoo 19
    @OdooString() String? email,
    @OdooString() String? website,
    @OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,
    @OdooMany2OneName(sourceField: 'currency_id') String? currencyName,
    @OdooMany2One('res.company', odooName: 'parent_id') int? parentId,
    @OdooMany2OneName(sourceField: 'parent_id') String? parentName,

    // ═══════════════════ Ecuador SRI Fields ═══════════════════
    @OdooString(odooName: 'l10n_ec_comercial_name') String? l10nEcComercialName,
    @OdooString(odooName: 'l10n_ec_legal_name') String? l10nEcLegalName,
    @OdooBoolean(odooName: 'l10n_ec_production_env') @Default(false) bool l10nEcProductionEnv,

    // ═══════════════════ Document Layout ═══════════════════
    @OdooBinary() String? logo,
    @OdooBinary(odooName: 'report_header_image') String? reportHeaderImage,
    @OdooHtml(odooName: 'report_footer') String? reportFooter,
    @OdooString(odooName: 'primary_color') String? primaryColor,
    @OdooString(odooName: 'secondary_color') String? secondaryColor,
    @OdooString() String? font,
    @OdooLocalOnly() String? layoutBackground, // Removed from Odoo 19
    @OdooMany2One('ir.ui.view', odooName: 'external_report_layout_id') int? externalReportLayoutId,

    // ═══════════════════ Tax Configuration ═══════════════════
    @OdooSelection(odooName: 'tax_calculation_rounding_method') @Default('round_per_line') String taxCalculationRoundingMethod,

    // ═══════════════════ Sales Configuration ═══════════════════
    /// Days a quotation is valid
    @OdooInteger(odooName: 'quotation_validity_days') @Default(30) int quotationValidityDays,

    /// Require signature for portal confirmation
    @OdooBoolean(odooName: 'portal_confirmation_sign') @Default(true) bool portalConfirmationSign,

    /// Require payment for portal confirmation
    @OdooBoolean(odooName: 'portal_confirmation_pay') @Default(false) bool portalConfirmationPay,

    /// Prepayment percentage
    @OdooFloat(odooName: 'prepayment_percent') @Default(1.0) double prepaymentPercent,

    /// Discount product ID
    @OdooMany2One('product.product', odooName: 'sale_discount_product_id') int? saleDiscountProductId,

    /// Discount product name
    @OdooMany2OneName(sourceField: 'sale_discount_product_id') String? saleDiscountProductName,

    // ═══════════════════ Sales Defaults ═══════════════════
    /// Default partner for new sales
    @OdooMany2One('res.partner', odooName: 'partner_id') int? defaultPartnerId,
    @OdooMany2OneName(sourceField: 'partner_id') String? defaultPartnerName,

    /// Default warehouse for new sales
    @OdooMany2One('stock.warehouse', odooName: 'warehouse_id') int? defaultWarehouseId,
    @OdooMany2OneName(sourceField: 'warehouse_id') String? defaultWarehouseName,

    /// Default pricelist for new sales
    @OdooMany2One('product.pricelist', odooName: 'default_pricelist_id') int? defaultPricelistId,
    @OdooMany2OneName(sourceField: 'default_pricelist_id') String? defaultPricelistName,

    /// Default payment term for new sales
    @OdooMany2One('account.payment.term', odooName: 'default_payment_term_id') int? defaultPaymentTermId,
    @OdooMany2OneName(sourceField: 'default_payment_term_id') String? defaultPaymentTermName,

    /// Whether to require end customer data in sales
    @OdooBoolean(odooName: 'pedir_end_customer_data') @Default(false) bool pedirEndCustomerData,

    /// Whether to require sales referrer
    @OdooBoolean(odooName: 'pedir_sale_referrer') @Default(false) bool pedirSaleReferrer,

    /// Whether to require client type/channel
    @OdooBoolean(odooName: 'pedir_tipo_canal_cliente') @Default(false) bool pedirTipoCanalCliente,

    /// SRI invoice limit for sales customers
    @OdooFloat(odooName: 'sale_customer_invoice_limit_sri') double? saleCustomerInvoiceLimitSri,

    /// Maximum discount percentage allowed
    @OdooFloat(odooName: 'max_discount_percentage') @Default(100.0) double maxDiscountPercentage,

    // ═══════════════════ Credit Control Configuration ═══════════════════
    /// Overdue days threshold for credit blocking
    @OdooInteger(odooName: 'credit_overdue_days_threshold') @Default(30) int creditOverdueDaysThreshold,

    /// Overdue invoices threshold for credit blocking
    @OdooInteger(odooName: 'credit_overdue_invoices_threshold') @Default(3) int creditOverdueInvoicesThreshold,

    /// Safety margin for offline credit validation (%)
    @OdooFloat(odooName: 'credit_offline_safety_margin') @Default(0.0) double creditOfflineSafetyMargin,

    /// Maximum age in hours for credit data to be considered valid
    @OdooInteger(odooName: 'credit_data_max_age_hours') @Default(24) int creditDataMaxAgeHours,

    // ═══════════════════ Reservation Configuration ═══════════════════
    /// Days before a reservation expires
    @OdooInteger(odooName: 'reservation_expiry_days') @Default(7) int reservationExpiryDays,

    /// Warehouse for reservations
    @OdooMany2One('stock.warehouse', odooName: 'reservation_warehouse_id') int? reservationWarehouseId,

    /// Warehouse name for reservations
    @OdooMany2OneName(sourceField: 'reservation_warehouse_id') String? reservationWarehouseName,

    /// Location for reservations
    @OdooMany2One('stock.location', odooName: 'reservation_location_id') int? reservationLocationId,

    /// Location name for reservations
    @OdooMany2OneName(sourceField: 'reservation_location_id') String? reservationLocationName,

    /// Reserve stock from quotation stage
    @OdooBoolean(odooName: 'reserve_from_quotation') @Default(false) bool reserveFromQuotation,

    // ═══════════════════ Metadata ═══════════════════
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _Company;

  factory Company.fromJson(Map<String, dynamic> json) => _$CompanyFromJson(json);

  // ═══════════════════════════════════════════════════════════════════════════
  // Computed Getters
  // ═══════════════════════════════════════════════════════════════════════════

  bool get isActive => true;
  DateTime? get lastModified => writeDate;

  bool get hasAddress => street?.isNotEmpty == true || city?.isNotEmpty == true;
  bool get hasContactInfo => phone?.isNotEmpty == true || email?.isNotEmpty == true;
  bool get hasLogo => logo?.isNotEmpty == true;
  bool get hasReportConfig => reportHeaderImage != null || primaryColor != null;

  String get fullAddress {
    final parts = <String?>[];
    if (street?.isNotEmpty == true) parts.add(street);
    if (street2?.isNotEmpty == true) parts.add(street2);
    if (city?.isNotEmpty == true) parts.add(city);
    if (stateName?.isNotEmpty == true) parts.add(stateName);
    if (zip?.isNotEmpty == true) parts.add(zip);
    if (countryName?.isNotEmpty == true) parts.add(countryName);
    return parts.join(', ');
  }

  /// Display name for Ecuador documents
  String get displayName => l10nEcComercialName ?? name;

  /// Legal name for Ecuador documents
  String get legalName => l10nEcLegalName ?? name;

  bool get isValid => name.trim().isNotEmpty && currencyId != null;

  // ═══════════════════════════════════════════════════════════════════════════
  // Static Odoo Field Lists
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<String> odooFieldsCore = [
    'id', 'name', 'email', 'phone', 'website', 'vat',
    'street', 'street2', 'city', 'zip', 'country_id', 'state_id',
    'currency_id', 'parent_id', 'logo', 'write_date',
    'report_footer', 'primary_color', 'secondary_color', 'font',
    'external_report_layout_id',
  ];

  static const List<String> odooFieldsSale = [
    'quotation_validity_days', 'portal_confirmation_sign',
    'portal_confirmation_pay', 'prepayment_percent',
    'sale_discount_product_id', 'tax_calculation_rounding_method',
  ];

  static const List<String> odooFieldsEcuadorSri = [
    'l10n_ec_legal_name', 'l10n_ec_production_env',
  ];

  static const List<String> odooFieldsEcuadorReport = [
    'report_header_image', 'l10n_ec_comercial_name',
  ];

  static const List<String> odooFieldsEcuador = [
    ...odooFieldsEcuadorSri, ...odooFieldsEcuadorReport,
  ];

  static const List<String> odooFieldsPedir = [
    'pedir_end_customer_data', 'pedir_sale_referrer',
    'pedir_tipo_canal_cliente', 'credit_overdue_days_threshold',
    'credit_overdue_invoices_threshold', 'max_discount_percentage',
    'reservation_expiry_days', 'reservation_warehouse_id',
    'reservation_location_id', 'reserve_from_quotation',
  ];

  static const List<String> odooFields = [
    ...odooFieldsCore, ...odooFieldsSale,
    ...odooFieldsEcuador, ...odooFieldsPedir,
  ];
}
