// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'company.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Company {

// ═══════════════════ Identifiers ═══════════════════
@OdooId() int get id;@OdooString() String get name;// ═══════════════════ Basic Info ═══════════════════
@OdooString() String? get vat;@OdooString() String? get street;@OdooString(odooName: 'street2') String? get street2;@OdooString() String? get city;@OdooString() String? get zip;@OdooMany2One('res.country', odooName: 'country_id') int? get countryId;@OdooMany2OneName(sourceField: 'country_id') String? get countryName;@OdooMany2One('res.country.state', odooName: 'state_id') int? get stateId;@OdooMany2OneName(sourceField: 'state_id') String? get stateName;@OdooString() String? get phone;@OdooLocalOnly() String? get mobile;// Removed from Odoo 19
@OdooString() String? get email;@OdooString() String? get website;@OdooMany2One('res.currency', odooName: 'currency_id') int? get currencyId;@OdooMany2OneName(sourceField: 'currency_id') String? get currencyName;@OdooMany2One('res.company', odooName: 'parent_id') int? get parentId;@OdooMany2OneName(sourceField: 'parent_id') String? get parentName;// ═══════════════════ Ecuador SRI Fields ═══════════════════
@OdooString(odooName: 'l10n_ec_comercial_name') String? get l10nEcComercialName;@OdooString(odooName: 'l10n_ec_legal_name') String? get l10nEcLegalName;@OdooBoolean(odooName: 'l10n_ec_production_env') bool get l10nEcProductionEnv;// ═══════════════════ Document Layout ═══════════════════
@OdooBinary() String? get logo;@OdooBinary(odooName: 'report_header_image') String? get reportHeaderImage;@OdooHtml(odooName: 'report_footer') String? get reportFooter;@OdooString(odooName: 'primary_color') String? get primaryColor;@OdooString(odooName: 'secondary_color') String? get secondaryColor;@OdooString() String? get font;@OdooLocalOnly() String? get layoutBackground;// Removed from Odoo 19
@OdooMany2One('ir.ui.view', odooName: 'external_report_layout_id') int? get externalReportLayoutId;// ═══════════════════ Tax Configuration ═══════════════════
@OdooSelection(odooName: 'tax_calculation_rounding_method') String get taxCalculationRoundingMethod;// ═══════════════════ Sales Configuration ═══════════════════
/// Days a quotation is valid
@OdooInteger(odooName: 'quotation_validity_days') int get quotationValidityDays;/// Require signature for portal confirmation
@OdooBoolean(odooName: 'portal_confirmation_sign') bool get portalConfirmationSign;/// Require payment for portal confirmation
@OdooBoolean(odooName: 'portal_confirmation_pay') bool get portalConfirmationPay;/// Prepayment percentage
@OdooFloat(odooName: 'prepayment_percent') double get prepaymentPercent;/// Discount product ID
@OdooMany2One('product.product', odooName: 'sale_discount_product_id') int? get saleDiscountProductId;/// Discount product name
@OdooMany2OneName(sourceField: 'sale_discount_product_id') String? get saleDiscountProductName;// ═══════════════════ Sales Defaults ═══════════════════
/// Default partner for new sales
@OdooMany2One('res.partner', odooName: 'partner_id') int? get defaultPartnerId;@OdooMany2OneName(sourceField: 'partner_id') String? get defaultPartnerName;/// Default warehouse for new sales
@OdooMany2One('stock.warehouse', odooName: 'warehouse_id') int? get defaultWarehouseId;@OdooMany2OneName(sourceField: 'warehouse_id') String? get defaultWarehouseName;/// Default pricelist for new sales
@OdooMany2One('product.pricelist', odooName: 'default_pricelist_id') int? get defaultPricelistId;@OdooMany2OneName(sourceField: 'default_pricelist_id') String? get defaultPricelistName;/// Default payment term for new sales
@OdooMany2One('account.payment.term', odooName: 'default_payment_term_id') int? get defaultPaymentTermId;@OdooMany2OneName(sourceField: 'default_payment_term_id') String? get defaultPaymentTermName;/// Whether to require end customer data in sales
@OdooBoolean(odooName: 'pedir_end_customer_data') bool get pedirEndCustomerData;/// Whether to require sales referrer
@OdooBoolean(odooName: 'pedir_sale_referrer') bool get pedirSaleReferrer;/// Whether to require client type/channel
@OdooBoolean(odooName: 'pedir_tipo_canal_cliente') bool get pedirTipoCanalCliente;/// SRI invoice limit for sales customers
@OdooFloat(odooName: 'sale_customer_invoice_limit_sri') double? get saleCustomerInvoiceLimitSri;/// Maximum discount percentage allowed
@OdooFloat(odooName: 'max_discount_percentage') double get maxDiscountPercentage;// ═══════════════════ Credit Control Configuration ═══════════════════
/// Overdue days threshold for credit blocking
@OdooInteger(odooName: 'credit_overdue_days_threshold') int get creditOverdueDaysThreshold;/// Overdue invoices threshold for credit blocking
@OdooInteger(odooName: 'credit_overdue_invoices_threshold') int get creditOverdueInvoicesThreshold;/// Safety margin for offline credit validation (%)
@OdooFloat(odooName: 'credit_offline_safety_margin') double get creditOfflineSafetyMargin;/// Maximum age in hours for credit data to be considered valid
@OdooInteger(odooName: 'credit_data_max_age_hours') int get creditDataMaxAgeHours;// ═══════════════════ Reservation Configuration ═══════════════════
/// Days before a reservation expires
@OdooInteger(odooName: 'reservation_expiry_days') int get reservationExpiryDays;/// Warehouse for reservations
@OdooMany2One('stock.warehouse', odooName: 'reservation_warehouse_id') int? get reservationWarehouseId;/// Warehouse name for reservations
@OdooMany2OneName(sourceField: 'reservation_warehouse_id') String? get reservationWarehouseName;/// Location for reservations
@OdooMany2One('stock.location', odooName: 'reservation_location_id') int? get reservationLocationId;/// Location name for reservations
@OdooMany2OneName(sourceField: 'reservation_location_id') String? get reservationLocationName;/// Reserve stock from quotation stage
@OdooBoolean(odooName: 'reserve_from_quotation') bool get reserveFromQuotation;// ═══════════════════ Metadata ═══════════════════
@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyCopyWith<Company> get copyWith => _$CompanyCopyWithImpl<Company>(this as Company, _$identity);

  /// Serializes this Company to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Company&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.vat, vat) || other.vat == vat)&&(identical(other.street, street) || other.street == street)&&(identical(other.street2, street2) || other.street2 == street2)&&(identical(other.city, city) || other.city == city)&&(identical(other.zip, zip) || other.zip == zip)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.countryName, countryName) || other.countryName == countryName)&&(identical(other.stateId, stateId) || other.stateId == stateId)&&(identical(other.stateName, stateName) || other.stateName == stateName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.email, email) || other.email == email)&&(identical(other.website, website) || other.website == website)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.currencyName, currencyName) || other.currencyName == currencyName)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.parentName, parentName) || other.parentName == parentName)&&(identical(other.l10nEcComercialName, l10nEcComercialName) || other.l10nEcComercialName == l10nEcComercialName)&&(identical(other.l10nEcLegalName, l10nEcLegalName) || other.l10nEcLegalName == l10nEcLegalName)&&(identical(other.l10nEcProductionEnv, l10nEcProductionEnv) || other.l10nEcProductionEnv == l10nEcProductionEnv)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.reportHeaderImage, reportHeaderImage) || other.reportHeaderImage == reportHeaderImage)&&(identical(other.reportFooter, reportFooter) || other.reportFooter == reportFooter)&&(identical(other.primaryColor, primaryColor) || other.primaryColor == primaryColor)&&(identical(other.secondaryColor, secondaryColor) || other.secondaryColor == secondaryColor)&&(identical(other.font, font) || other.font == font)&&(identical(other.layoutBackground, layoutBackground) || other.layoutBackground == layoutBackground)&&(identical(other.externalReportLayoutId, externalReportLayoutId) || other.externalReportLayoutId == externalReportLayoutId)&&(identical(other.taxCalculationRoundingMethod, taxCalculationRoundingMethod) || other.taxCalculationRoundingMethod == taxCalculationRoundingMethod)&&(identical(other.quotationValidityDays, quotationValidityDays) || other.quotationValidityDays == quotationValidityDays)&&(identical(other.portalConfirmationSign, portalConfirmationSign) || other.portalConfirmationSign == portalConfirmationSign)&&(identical(other.portalConfirmationPay, portalConfirmationPay) || other.portalConfirmationPay == portalConfirmationPay)&&(identical(other.prepaymentPercent, prepaymentPercent) || other.prepaymentPercent == prepaymentPercent)&&(identical(other.saleDiscountProductId, saleDiscountProductId) || other.saleDiscountProductId == saleDiscountProductId)&&(identical(other.saleDiscountProductName, saleDiscountProductName) || other.saleDiscountProductName == saleDiscountProductName)&&(identical(other.defaultPartnerId, defaultPartnerId) || other.defaultPartnerId == defaultPartnerId)&&(identical(other.defaultPartnerName, defaultPartnerName) || other.defaultPartnerName == defaultPartnerName)&&(identical(other.defaultWarehouseId, defaultWarehouseId) || other.defaultWarehouseId == defaultWarehouseId)&&(identical(other.defaultWarehouseName, defaultWarehouseName) || other.defaultWarehouseName == defaultWarehouseName)&&(identical(other.defaultPricelistId, defaultPricelistId) || other.defaultPricelistId == defaultPricelistId)&&(identical(other.defaultPricelistName, defaultPricelistName) || other.defaultPricelistName == defaultPricelistName)&&(identical(other.defaultPaymentTermId, defaultPaymentTermId) || other.defaultPaymentTermId == defaultPaymentTermId)&&(identical(other.defaultPaymentTermName, defaultPaymentTermName) || other.defaultPaymentTermName == defaultPaymentTermName)&&(identical(other.pedirEndCustomerData, pedirEndCustomerData) || other.pedirEndCustomerData == pedirEndCustomerData)&&(identical(other.pedirSaleReferrer, pedirSaleReferrer) || other.pedirSaleReferrer == pedirSaleReferrer)&&(identical(other.pedirTipoCanalCliente, pedirTipoCanalCliente) || other.pedirTipoCanalCliente == pedirTipoCanalCliente)&&(identical(other.saleCustomerInvoiceLimitSri, saleCustomerInvoiceLimitSri) || other.saleCustomerInvoiceLimitSri == saleCustomerInvoiceLimitSri)&&(identical(other.maxDiscountPercentage, maxDiscountPercentage) || other.maxDiscountPercentage == maxDiscountPercentage)&&(identical(other.creditOverdueDaysThreshold, creditOverdueDaysThreshold) || other.creditOverdueDaysThreshold == creditOverdueDaysThreshold)&&(identical(other.creditOverdueInvoicesThreshold, creditOverdueInvoicesThreshold) || other.creditOverdueInvoicesThreshold == creditOverdueInvoicesThreshold)&&(identical(other.creditOfflineSafetyMargin, creditOfflineSafetyMargin) || other.creditOfflineSafetyMargin == creditOfflineSafetyMargin)&&(identical(other.creditDataMaxAgeHours, creditDataMaxAgeHours) || other.creditDataMaxAgeHours == creditDataMaxAgeHours)&&(identical(other.reservationExpiryDays, reservationExpiryDays) || other.reservationExpiryDays == reservationExpiryDays)&&(identical(other.reservationWarehouseId, reservationWarehouseId) || other.reservationWarehouseId == reservationWarehouseId)&&(identical(other.reservationWarehouseName, reservationWarehouseName) || other.reservationWarehouseName == reservationWarehouseName)&&(identical(other.reservationLocationId, reservationLocationId) || other.reservationLocationId == reservationLocationId)&&(identical(other.reservationLocationName, reservationLocationName) || other.reservationLocationName == reservationLocationName)&&(identical(other.reserveFromQuotation, reserveFromQuotation) || other.reserveFromQuotation == reserveFromQuotation)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,vat,street,street2,city,zip,countryId,countryName,stateId,stateName,phone,mobile,email,website,currencyId,currencyName,parentId,parentName,l10nEcComercialName,l10nEcLegalName,l10nEcProductionEnv,logo,reportHeaderImage,reportFooter,primaryColor,secondaryColor,font,layoutBackground,externalReportLayoutId,taxCalculationRoundingMethod,quotationValidityDays,portalConfirmationSign,portalConfirmationPay,prepaymentPercent,saleDiscountProductId,saleDiscountProductName,defaultPartnerId,defaultPartnerName,defaultWarehouseId,defaultWarehouseName,defaultPricelistId,defaultPricelistName,defaultPaymentTermId,defaultPaymentTermName,pedirEndCustomerData,pedirSaleReferrer,pedirTipoCanalCliente,saleCustomerInvoiceLimitSri,maxDiscountPercentage,creditOverdueDaysThreshold,creditOverdueInvoicesThreshold,creditOfflineSafetyMargin,creditDataMaxAgeHours,reservationExpiryDays,reservationWarehouseId,reservationWarehouseName,reservationLocationId,reservationLocationName,reserveFromQuotation,writeDate]);

@override
String toString() {
  return 'Company(id: $id, name: $name, vat: $vat, street: $street, street2: $street2, city: $city, zip: $zip, countryId: $countryId, countryName: $countryName, stateId: $stateId, stateName: $stateName, phone: $phone, mobile: $mobile, email: $email, website: $website, currencyId: $currencyId, currencyName: $currencyName, parentId: $parentId, parentName: $parentName, l10nEcComercialName: $l10nEcComercialName, l10nEcLegalName: $l10nEcLegalName, l10nEcProductionEnv: $l10nEcProductionEnv, logo: $logo, reportHeaderImage: $reportHeaderImage, reportFooter: $reportFooter, primaryColor: $primaryColor, secondaryColor: $secondaryColor, font: $font, layoutBackground: $layoutBackground, externalReportLayoutId: $externalReportLayoutId, taxCalculationRoundingMethod: $taxCalculationRoundingMethod, quotationValidityDays: $quotationValidityDays, portalConfirmationSign: $portalConfirmationSign, portalConfirmationPay: $portalConfirmationPay, prepaymentPercent: $prepaymentPercent, saleDiscountProductId: $saleDiscountProductId, saleDiscountProductName: $saleDiscountProductName, defaultPartnerId: $defaultPartnerId, defaultPartnerName: $defaultPartnerName, defaultWarehouseId: $defaultWarehouseId, defaultWarehouseName: $defaultWarehouseName, defaultPricelistId: $defaultPricelistId, defaultPricelistName: $defaultPricelistName, defaultPaymentTermId: $defaultPaymentTermId, defaultPaymentTermName: $defaultPaymentTermName, pedirEndCustomerData: $pedirEndCustomerData, pedirSaleReferrer: $pedirSaleReferrer, pedirTipoCanalCliente: $pedirTipoCanalCliente, saleCustomerInvoiceLimitSri: $saleCustomerInvoiceLimitSri, maxDiscountPercentage: $maxDiscountPercentage, creditOverdueDaysThreshold: $creditOverdueDaysThreshold, creditOverdueInvoicesThreshold: $creditOverdueInvoicesThreshold, creditOfflineSafetyMargin: $creditOfflineSafetyMargin, creditDataMaxAgeHours: $creditDataMaxAgeHours, reservationExpiryDays: $reservationExpiryDays, reservationWarehouseId: $reservationWarehouseId, reservationWarehouseName: $reservationWarehouseName, reservationLocationId: $reservationLocationId, reservationLocationName: $reservationLocationName, reserveFromQuotation: $reserveFromQuotation, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $CompanyCopyWith<$Res>  {
  factory $CompanyCopyWith(Company value, $Res Function(Company) _then) = _$CompanyCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String? vat,@OdooString() String? street,@OdooString(odooName: 'street2') String? street2,@OdooString() String? city,@OdooString() String? zip,@OdooMany2One('res.country', odooName: 'country_id') int? countryId,@OdooMany2OneName(sourceField: 'country_id') String? countryName,@OdooMany2One('res.country.state', odooName: 'state_id') int? stateId,@OdooMany2OneName(sourceField: 'state_id') String? stateName,@OdooString() String? phone,@OdooLocalOnly() String? mobile,@OdooString() String? email,@OdooString() String? website,@OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,@OdooMany2OneName(sourceField: 'currency_id') String? currencyName,@OdooMany2One('res.company', odooName: 'parent_id') int? parentId,@OdooMany2OneName(sourceField: 'parent_id') String? parentName,@OdooString(odooName: 'l10n_ec_comercial_name') String? l10nEcComercialName,@OdooString(odooName: 'l10n_ec_legal_name') String? l10nEcLegalName,@OdooBoolean(odooName: 'l10n_ec_production_env') bool l10nEcProductionEnv,@OdooBinary() String? logo,@OdooBinary(odooName: 'report_header_image') String? reportHeaderImage,@OdooHtml(odooName: 'report_footer') String? reportFooter,@OdooString(odooName: 'primary_color') String? primaryColor,@OdooString(odooName: 'secondary_color') String? secondaryColor,@OdooString() String? font,@OdooLocalOnly() String? layoutBackground,@OdooMany2One('ir.ui.view', odooName: 'external_report_layout_id') int? externalReportLayoutId,@OdooSelection(odooName: 'tax_calculation_rounding_method') String taxCalculationRoundingMethod,@OdooInteger(odooName: 'quotation_validity_days') int quotationValidityDays,@OdooBoolean(odooName: 'portal_confirmation_sign') bool portalConfirmationSign,@OdooBoolean(odooName: 'portal_confirmation_pay') bool portalConfirmationPay,@OdooFloat(odooName: 'prepayment_percent') double prepaymentPercent,@OdooMany2One('product.product', odooName: 'sale_discount_product_id') int? saleDiscountProductId,@OdooMany2OneName(sourceField: 'sale_discount_product_id') String? saleDiscountProductName,@OdooMany2One('res.partner', odooName: 'partner_id') int? defaultPartnerId,@OdooMany2OneName(sourceField: 'partner_id') String? defaultPartnerName,@OdooMany2One('stock.warehouse', odooName: 'warehouse_id') int? defaultWarehouseId,@OdooMany2OneName(sourceField: 'warehouse_id') String? defaultWarehouseName,@OdooMany2One('product.pricelist', odooName: 'default_pricelist_id') int? defaultPricelistId,@OdooMany2OneName(sourceField: 'default_pricelist_id') String? defaultPricelistName,@OdooMany2One('account.payment.term', odooName: 'default_payment_term_id') int? defaultPaymentTermId,@OdooMany2OneName(sourceField: 'default_payment_term_id') String? defaultPaymentTermName,@OdooBoolean(odooName: 'pedir_end_customer_data') bool pedirEndCustomerData,@OdooBoolean(odooName: 'pedir_sale_referrer') bool pedirSaleReferrer,@OdooBoolean(odooName: 'pedir_tipo_canal_cliente') bool pedirTipoCanalCliente,@OdooFloat(odooName: 'sale_customer_invoice_limit_sri') double? saleCustomerInvoiceLimitSri,@OdooFloat(odooName: 'max_discount_percentage') double maxDiscountPercentage,@OdooInteger(odooName: 'credit_overdue_days_threshold') int creditOverdueDaysThreshold,@OdooInteger(odooName: 'credit_overdue_invoices_threshold') int creditOverdueInvoicesThreshold,@OdooFloat(odooName: 'credit_offline_safety_margin') double creditOfflineSafetyMargin,@OdooInteger(odooName: 'credit_data_max_age_hours') int creditDataMaxAgeHours,@OdooInteger(odooName: 'reservation_expiry_days') int reservationExpiryDays,@OdooMany2One('stock.warehouse', odooName: 'reservation_warehouse_id') int? reservationWarehouseId,@OdooMany2OneName(sourceField: 'reservation_warehouse_id') String? reservationWarehouseName,@OdooMany2One('stock.location', odooName: 'reservation_location_id') int? reservationLocationId,@OdooMany2OneName(sourceField: 'reservation_location_id') String? reservationLocationName,@OdooBoolean(odooName: 'reserve_from_quotation') bool reserveFromQuotation,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$CompanyCopyWithImpl<$Res>
    implements $CompanyCopyWith<$Res> {
  _$CompanyCopyWithImpl(this._self, this._then);

  final Company _self;
  final $Res Function(Company) _then;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? vat = freezed,Object? street = freezed,Object? street2 = freezed,Object? city = freezed,Object? zip = freezed,Object? countryId = freezed,Object? countryName = freezed,Object? stateId = freezed,Object? stateName = freezed,Object? phone = freezed,Object? mobile = freezed,Object? email = freezed,Object? website = freezed,Object? currencyId = freezed,Object? currencyName = freezed,Object? parentId = freezed,Object? parentName = freezed,Object? l10nEcComercialName = freezed,Object? l10nEcLegalName = freezed,Object? l10nEcProductionEnv = null,Object? logo = freezed,Object? reportHeaderImage = freezed,Object? reportFooter = freezed,Object? primaryColor = freezed,Object? secondaryColor = freezed,Object? font = freezed,Object? layoutBackground = freezed,Object? externalReportLayoutId = freezed,Object? taxCalculationRoundingMethod = null,Object? quotationValidityDays = null,Object? portalConfirmationSign = null,Object? portalConfirmationPay = null,Object? prepaymentPercent = null,Object? saleDiscountProductId = freezed,Object? saleDiscountProductName = freezed,Object? defaultPartnerId = freezed,Object? defaultPartnerName = freezed,Object? defaultWarehouseId = freezed,Object? defaultWarehouseName = freezed,Object? defaultPricelistId = freezed,Object? defaultPricelistName = freezed,Object? defaultPaymentTermId = freezed,Object? defaultPaymentTermName = freezed,Object? pedirEndCustomerData = null,Object? pedirSaleReferrer = null,Object? pedirTipoCanalCliente = null,Object? saleCustomerInvoiceLimitSri = freezed,Object? maxDiscountPercentage = null,Object? creditOverdueDaysThreshold = null,Object? creditOverdueInvoicesThreshold = null,Object? creditOfflineSafetyMargin = null,Object? creditDataMaxAgeHours = null,Object? reservationExpiryDays = null,Object? reservationWarehouseId = freezed,Object? reservationWarehouseName = freezed,Object? reservationLocationId = freezed,Object? reservationLocationName = freezed,Object? reserveFromQuotation = null,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,vat: freezed == vat ? _self.vat : vat // ignore: cast_nullable_to_non_nullable
as String?,street: freezed == street ? _self.street : street // ignore: cast_nullable_to_non_nullable
as String?,street2: freezed == street2 ? _self.street2 : street2 // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,zip: freezed == zip ? _self.zip : zip // ignore: cast_nullable_to_non_nullable
as String?,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as int?,countryName: freezed == countryName ? _self.countryName : countryName // ignore: cast_nullable_to_non_nullable
as String?,stateId: freezed == stateId ? _self.stateId : stateId // ignore: cast_nullable_to_non_nullable
as int?,stateName: freezed == stateName ? _self.stateName : stateName // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,website: freezed == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String?,currencyId: freezed == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as int?,currencyName: freezed == currencyName ? _self.currencyName : currencyName // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as int?,parentName: freezed == parentName ? _self.parentName : parentName // ignore: cast_nullable_to_non_nullable
as String?,l10nEcComercialName: freezed == l10nEcComercialName ? _self.l10nEcComercialName : l10nEcComercialName // ignore: cast_nullable_to_non_nullable
as String?,l10nEcLegalName: freezed == l10nEcLegalName ? _self.l10nEcLegalName : l10nEcLegalName // ignore: cast_nullable_to_non_nullable
as String?,l10nEcProductionEnv: null == l10nEcProductionEnv ? _self.l10nEcProductionEnv : l10nEcProductionEnv // ignore: cast_nullable_to_non_nullable
as bool,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,reportHeaderImage: freezed == reportHeaderImage ? _self.reportHeaderImage : reportHeaderImage // ignore: cast_nullable_to_non_nullable
as String?,reportFooter: freezed == reportFooter ? _self.reportFooter : reportFooter // ignore: cast_nullable_to_non_nullable
as String?,primaryColor: freezed == primaryColor ? _self.primaryColor : primaryColor // ignore: cast_nullable_to_non_nullable
as String?,secondaryColor: freezed == secondaryColor ? _self.secondaryColor : secondaryColor // ignore: cast_nullable_to_non_nullable
as String?,font: freezed == font ? _self.font : font // ignore: cast_nullable_to_non_nullable
as String?,layoutBackground: freezed == layoutBackground ? _self.layoutBackground : layoutBackground // ignore: cast_nullable_to_non_nullable
as String?,externalReportLayoutId: freezed == externalReportLayoutId ? _self.externalReportLayoutId : externalReportLayoutId // ignore: cast_nullable_to_non_nullable
as int?,taxCalculationRoundingMethod: null == taxCalculationRoundingMethod ? _self.taxCalculationRoundingMethod : taxCalculationRoundingMethod // ignore: cast_nullable_to_non_nullable
as String,quotationValidityDays: null == quotationValidityDays ? _self.quotationValidityDays : quotationValidityDays // ignore: cast_nullable_to_non_nullable
as int,portalConfirmationSign: null == portalConfirmationSign ? _self.portalConfirmationSign : portalConfirmationSign // ignore: cast_nullable_to_non_nullable
as bool,portalConfirmationPay: null == portalConfirmationPay ? _self.portalConfirmationPay : portalConfirmationPay // ignore: cast_nullable_to_non_nullable
as bool,prepaymentPercent: null == prepaymentPercent ? _self.prepaymentPercent : prepaymentPercent // ignore: cast_nullable_to_non_nullable
as double,saleDiscountProductId: freezed == saleDiscountProductId ? _self.saleDiscountProductId : saleDiscountProductId // ignore: cast_nullable_to_non_nullable
as int?,saleDiscountProductName: freezed == saleDiscountProductName ? _self.saleDiscountProductName : saleDiscountProductName // ignore: cast_nullable_to_non_nullable
as String?,defaultPartnerId: freezed == defaultPartnerId ? _self.defaultPartnerId : defaultPartnerId // ignore: cast_nullable_to_non_nullable
as int?,defaultPartnerName: freezed == defaultPartnerName ? _self.defaultPartnerName : defaultPartnerName // ignore: cast_nullable_to_non_nullable
as String?,defaultWarehouseId: freezed == defaultWarehouseId ? _self.defaultWarehouseId : defaultWarehouseId // ignore: cast_nullable_to_non_nullable
as int?,defaultWarehouseName: freezed == defaultWarehouseName ? _self.defaultWarehouseName : defaultWarehouseName // ignore: cast_nullable_to_non_nullable
as String?,defaultPricelistId: freezed == defaultPricelistId ? _self.defaultPricelistId : defaultPricelistId // ignore: cast_nullable_to_non_nullable
as int?,defaultPricelistName: freezed == defaultPricelistName ? _self.defaultPricelistName : defaultPricelistName // ignore: cast_nullable_to_non_nullable
as String?,defaultPaymentTermId: freezed == defaultPaymentTermId ? _self.defaultPaymentTermId : defaultPaymentTermId // ignore: cast_nullable_to_non_nullable
as int?,defaultPaymentTermName: freezed == defaultPaymentTermName ? _self.defaultPaymentTermName : defaultPaymentTermName // ignore: cast_nullable_to_non_nullable
as String?,pedirEndCustomerData: null == pedirEndCustomerData ? _self.pedirEndCustomerData : pedirEndCustomerData // ignore: cast_nullable_to_non_nullable
as bool,pedirSaleReferrer: null == pedirSaleReferrer ? _self.pedirSaleReferrer : pedirSaleReferrer // ignore: cast_nullable_to_non_nullable
as bool,pedirTipoCanalCliente: null == pedirTipoCanalCliente ? _self.pedirTipoCanalCliente : pedirTipoCanalCliente // ignore: cast_nullable_to_non_nullable
as bool,saleCustomerInvoiceLimitSri: freezed == saleCustomerInvoiceLimitSri ? _self.saleCustomerInvoiceLimitSri : saleCustomerInvoiceLimitSri // ignore: cast_nullable_to_non_nullable
as double?,maxDiscountPercentage: null == maxDiscountPercentage ? _self.maxDiscountPercentage : maxDiscountPercentage // ignore: cast_nullable_to_non_nullable
as double,creditOverdueDaysThreshold: null == creditOverdueDaysThreshold ? _self.creditOverdueDaysThreshold : creditOverdueDaysThreshold // ignore: cast_nullable_to_non_nullable
as int,creditOverdueInvoicesThreshold: null == creditOverdueInvoicesThreshold ? _self.creditOverdueInvoicesThreshold : creditOverdueInvoicesThreshold // ignore: cast_nullable_to_non_nullable
as int,creditOfflineSafetyMargin: null == creditOfflineSafetyMargin ? _self.creditOfflineSafetyMargin : creditOfflineSafetyMargin // ignore: cast_nullable_to_non_nullable
as double,creditDataMaxAgeHours: null == creditDataMaxAgeHours ? _self.creditDataMaxAgeHours : creditDataMaxAgeHours // ignore: cast_nullable_to_non_nullable
as int,reservationExpiryDays: null == reservationExpiryDays ? _self.reservationExpiryDays : reservationExpiryDays // ignore: cast_nullable_to_non_nullable
as int,reservationWarehouseId: freezed == reservationWarehouseId ? _self.reservationWarehouseId : reservationWarehouseId // ignore: cast_nullable_to_non_nullable
as int?,reservationWarehouseName: freezed == reservationWarehouseName ? _self.reservationWarehouseName : reservationWarehouseName // ignore: cast_nullable_to_non_nullable
as String?,reservationLocationId: freezed == reservationLocationId ? _self.reservationLocationId : reservationLocationId // ignore: cast_nullable_to_non_nullable
as int?,reservationLocationName: freezed == reservationLocationName ? _self.reservationLocationName : reservationLocationName // ignore: cast_nullable_to_non_nullable
as String?,reserveFromQuotation: null == reserveFromQuotation ? _self.reserveFromQuotation : reserveFromQuotation // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Company].
extension CompanyPatterns on Company {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Company value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Company() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Company value)  $default,){
final _that = this;
switch (_that) {
case _Company():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Company value)?  $default,){
final _that = this;
switch (_that) {
case _Company() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? vat, @OdooString()  String? street, @OdooString(odooName: 'street2')  String? street2, @OdooString()  String? city, @OdooString()  String? zip, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooMany2One('res.country.state', odooName: 'state_id')  int? stateId, @OdooMany2OneName(sourceField: 'state_id')  String? stateName, @OdooString()  String? phone, @OdooLocalOnly()  String? mobile, @OdooString()  String? email, @OdooString()  String? website, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencyName, @OdooMany2One('res.company', odooName: 'parent_id')  int? parentId, @OdooMany2OneName(sourceField: 'parent_id')  String? parentName, @OdooString(odooName: 'l10n_ec_comercial_name')  String? l10nEcComercialName, @OdooString(odooName: 'l10n_ec_legal_name')  String? l10nEcLegalName, @OdooBoolean(odooName: 'l10n_ec_production_env')  bool l10nEcProductionEnv, @OdooBinary()  String? logo, @OdooBinary(odooName: 'report_header_image')  String? reportHeaderImage, @OdooHtml(odooName: 'report_footer')  String? reportFooter, @OdooString(odooName: 'primary_color')  String? primaryColor, @OdooString(odooName: 'secondary_color')  String? secondaryColor, @OdooString()  String? font, @OdooLocalOnly()  String? layoutBackground, @OdooMany2One('ir.ui.view', odooName: 'external_report_layout_id')  int? externalReportLayoutId, @OdooSelection(odooName: 'tax_calculation_rounding_method')  String taxCalculationRoundingMethod, @OdooInteger(odooName: 'quotation_validity_days')  int quotationValidityDays, @OdooBoolean(odooName: 'portal_confirmation_sign')  bool portalConfirmationSign, @OdooBoolean(odooName: 'portal_confirmation_pay')  bool portalConfirmationPay, @OdooFloat(odooName: 'prepayment_percent')  double prepaymentPercent, @OdooMany2One('product.product', odooName: 'sale_discount_product_id')  int? saleDiscountProductId, @OdooMany2OneName(sourceField: 'sale_discount_product_id')  String? saleDiscountProductName, @OdooMany2One('res.partner', odooName: 'partner_id')  int? defaultPartnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? defaultPartnerName, @OdooMany2One('stock.warehouse', odooName: 'warehouse_id')  int? defaultWarehouseId, @OdooMany2OneName(sourceField: 'warehouse_id')  String? defaultWarehouseName, @OdooMany2One('product.pricelist', odooName: 'default_pricelist_id')  int? defaultPricelistId, @OdooMany2OneName(sourceField: 'default_pricelist_id')  String? defaultPricelistName, @OdooMany2One('account.payment.term', odooName: 'default_payment_term_id')  int? defaultPaymentTermId, @OdooMany2OneName(sourceField: 'default_payment_term_id')  String? defaultPaymentTermName, @OdooBoolean(odooName: 'pedir_end_customer_data')  bool pedirEndCustomerData, @OdooBoolean(odooName: 'pedir_sale_referrer')  bool pedirSaleReferrer, @OdooBoolean(odooName: 'pedir_tipo_canal_cliente')  bool pedirTipoCanalCliente, @OdooFloat(odooName: 'sale_customer_invoice_limit_sri')  double? saleCustomerInvoiceLimitSri, @OdooFloat(odooName: 'max_discount_percentage')  double maxDiscountPercentage, @OdooInteger(odooName: 'credit_overdue_days_threshold')  int creditOverdueDaysThreshold, @OdooInteger(odooName: 'credit_overdue_invoices_threshold')  int creditOverdueInvoicesThreshold, @OdooFloat(odooName: 'credit_offline_safety_margin')  double creditOfflineSafetyMargin, @OdooInteger(odooName: 'credit_data_max_age_hours')  int creditDataMaxAgeHours, @OdooInteger(odooName: 'reservation_expiry_days')  int reservationExpiryDays, @OdooMany2One('stock.warehouse', odooName: 'reservation_warehouse_id')  int? reservationWarehouseId, @OdooMany2OneName(sourceField: 'reservation_warehouse_id')  String? reservationWarehouseName, @OdooMany2One('stock.location', odooName: 'reservation_location_id')  int? reservationLocationId, @OdooMany2OneName(sourceField: 'reservation_location_id')  String? reservationLocationName, @OdooBoolean(odooName: 'reserve_from_quotation')  bool reserveFromQuotation, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Company() when $default != null:
return $default(_that.id,_that.name,_that.vat,_that.street,_that.street2,_that.city,_that.zip,_that.countryId,_that.countryName,_that.stateId,_that.stateName,_that.phone,_that.mobile,_that.email,_that.website,_that.currencyId,_that.currencyName,_that.parentId,_that.parentName,_that.l10nEcComercialName,_that.l10nEcLegalName,_that.l10nEcProductionEnv,_that.logo,_that.reportHeaderImage,_that.reportFooter,_that.primaryColor,_that.secondaryColor,_that.font,_that.layoutBackground,_that.externalReportLayoutId,_that.taxCalculationRoundingMethod,_that.quotationValidityDays,_that.portalConfirmationSign,_that.portalConfirmationPay,_that.prepaymentPercent,_that.saleDiscountProductId,_that.saleDiscountProductName,_that.defaultPartnerId,_that.defaultPartnerName,_that.defaultWarehouseId,_that.defaultWarehouseName,_that.defaultPricelistId,_that.defaultPricelistName,_that.defaultPaymentTermId,_that.defaultPaymentTermName,_that.pedirEndCustomerData,_that.pedirSaleReferrer,_that.pedirTipoCanalCliente,_that.saleCustomerInvoiceLimitSri,_that.maxDiscountPercentage,_that.creditOverdueDaysThreshold,_that.creditOverdueInvoicesThreshold,_that.creditOfflineSafetyMargin,_that.creditDataMaxAgeHours,_that.reservationExpiryDays,_that.reservationWarehouseId,_that.reservationWarehouseName,_that.reservationLocationId,_that.reservationLocationName,_that.reserveFromQuotation,_that.writeDate);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? vat, @OdooString()  String? street, @OdooString(odooName: 'street2')  String? street2, @OdooString()  String? city, @OdooString()  String? zip, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooMany2One('res.country.state', odooName: 'state_id')  int? stateId, @OdooMany2OneName(sourceField: 'state_id')  String? stateName, @OdooString()  String? phone, @OdooLocalOnly()  String? mobile, @OdooString()  String? email, @OdooString()  String? website, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencyName, @OdooMany2One('res.company', odooName: 'parent_id')  int? parentId, @OdooMany2OneName(sourceField: 'parent_id')  String? parentName, @OdooString(odooName: 'l10n_ec_comercial_name')  String? l10nEcComercialName, @OdooString(odooName: 'l10n_ec_legal_name')  String? l10nEcLegalName, @OdooBoolean(odooName: 'l10n_ec_production_env')  bool l10nEcProductionEnv, @OdooBinary()  String? logo, @OdooBinary(odooName: 'report_header_image')  String? reportHeaderImage, @OdooHtml(odooName: 'report_footer')  String? reportFooter, @OdooString(odooName: 'primary_color')  String? primaryColor, @OdooString(odooName: 'secondary_color')  String? secondaryColor, @OdooString()  String? font, @OdooLocalOnly()  String? layoutBackground, @OdooMany2One('ir.ui.view', odooName: 'external_report_layout_id')  int? externalReportLayoutId, @OdooSelection(odooName: 'tax_calculation_rounding_method')  String taxCalculationRoundingMethod, @OdooInteger(odooName: 'quotation_validity_days')  int quotationValidityDays, @OdooBoolean(odooName: 'portal_confirmation_sign')  bool portalConfirmationSign, @OdooBoolean(odooName: 'portal_confirmation_pay')  bool portalConfirmationPay, @OdooFloat(odooName: 'prepayment_percent')  double prepaymentPercent, @OdooMany2One('product.product', odooName: 'sale_discount_product_id')  int? saleDiscountProductId, @OdooMany2OneName(sourceField: 'sale_discount_product_id')  String? saleDiscountProductName, @OdooMany2One('res.partner', odooName: 'partner_id')  int? defaultPartnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? defaultPartnerName, @OdooMany2One('stock.warehouse', odooName: 'warehouse_id')  int? defaultWarehouseId, @OdooMany2OneName(sourceField: 'warehouse_id')  String? defaultWarehouseName, @OdooMany2One('product.pricelist', odooName: 'default_pricelist_id')  int? defaultPricelistId, @OdooMany2OneName(sourceField: 'default_pricelist_id')  String? defaultPricelistName, @OdooMany2One('account.payment.term', odooName: 'default_payment_term_id')  int? defaultPaymentTermId, @OdooMany2OneName(sourceField: 'default_payment_term_id')  String? defaultPaymentTermName, @OdooBoolean(odooName: 'pedir_end_customer_data')  bool pedirEndCustomerData, @OdooBoolean(odooName: 'pedir_sale_referrer')  bool pedirSaleReferrer, @OdooBoolean(odooName: 'pedir_tipo_canal_cliente')  bool pedirTipoCanalCliente, @OdooFloat(odooName: 'sale_customer_invoice_limit_sri')  double? saleCustomerInvoiceLimitSri, @OdooFloat(odooName: 'max_discount_percentage')  double maxDiscountPercentage, @OdooInteger(odooName: 'credit_overdue_days_threshold')  int creditOverdueDaysThreshold, @OdooInteger(odooName: 'credit_overdue_invoices_threshold')  int creditOverdueInvoicesThreshold, @OdooFloat(odooName: 'credit_offline_safety_margin')  double creditOfflineSafetyMargin, @OdooInteger(odooName: 'credit_data_max_age_hours')  int creditDataMaxAgeHours, @OdooInteger(odooName: 'reservation_expiry_days')  int reservationExpiryDays, @OdooMany2One('stock.warehouse', odooName: 'reservation_warehouse_id')  int? reservationWarehouseId, @OdooMany2OneName(sourceField: 'reservation_warehouse_id')  String? reservationWarehouseName, @OdooMany2One('stock.location', odooName: 'reservation_location_id')  int? reservationLocationId, @OdooMany2OneName(sourceField: 'reservation_location_id')  String? reservationLocationName, @OdooBoolean(odooName: 'reserve_from_quotation')  bool reserveFromQuotation, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _Company():
return $default(_that.id,_that.name,_that.vat,_that.street,_that.street2,_that.city,_that.zip,_that.countryId,_that.countryName,_that.stateId,_that.stateName,_that.phone,_that.mobile,_that.email,_that.website,_that.currencyId,_that.currencyName,_that.parentId,_that.parentName,_that.l10nEcComercialName,_that.l10nEcLegalName,_that.l10nEcProductionEnv,_that.logo,_that.reportHeaderImage,_that.reportFooter,_that.primaryColor,_that.secondaryColor,_that.font,_that.layoutBackground,_that.externalReportLayoutId,_that.taxCalculationRoundingMethod,_that.quotationValidityDays,_that.portalConfirmationSign,_that.portalConfirmationPay,_that.prepaymentPercent,_that.saleDiscountProductId,_that.saleDiscountProductName,_that.defaultPartnerId,_that.defaultPartnerName,_that.defaultWarehouseId,_that.defaultWarehouseName,_that.defaultPricelistId,_that.defaultPricelistName,_that.defaultPaymentTermId,_that.defaultPaymentTermName,_that.pedirEndCustomerData,_that.pedirSaleReferrer,_that.pedirTipoCanalCliente,_that.saleCustomerInvoiceLimitSri,_that.maxDiscountPercentage,_that.creditOverdueDaysThreshold,_that.creditOverdueInvoicesThreshold,_that.creditOfflineSafetyMargin,_that.creditDataMaxAgeHours,_that.reservationExpiryDays,_that.reservationWarehouseId,_that.reservationWarehouseName,_that.reservationLocationId,_that.reservationLocationName,_that.reserveFromQuotation,_that.writeDate);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? vat, @OdooString()  String? street, @OdooString(odooName: 'street2')  String? street2, @OdooString()  String? city, @OdooString()  String? zip, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooMany2One('res.country.state', odooName: 'state_id')  int? stateId, @OdooMany2OneName(sourceField: 'state_id')  String? stateName, @OdooString()  String? phone, @OdooLocalOnly()  String? mobile, @OdooString()  String? email, @OdooString()  String? website, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencyName, @OdooMany2One('res.company', odooName: 'parent_id')  int? parentId, @OdooMany2OneName(sourceField: 'parent_id')  String? parentName, @OdooString(odooName: 'l10n_ec_comercial_name')  String? l10nEcComercialName, @OdooString(odooName: 'l10n_ec_legal_name')  String? l10nEcLegalName, @OdooBoolean(odooName: 'l10n_ec_production_env')  bool l10nEcProductionEnv, @OdooBinary()  String? logo, @OdooBinary(odooName: 'report_header_image')  String? reportHeaderImage, @OdooHtml(odooName: 'report_footer')  String? reportFooter, @OdooString(odooName: 'primary_color')  String? primaryColor, @OdooString(odooName: 'secondary_color')  String? secondaryColor, @OdooString()  String? font, @OdooLocalOnly()  String? layoutBackground, @OdooMany2One('ir.ui.view', odooName: 'external_report_layout_id')  int? externalReportLayoutId, @OdooSelection(odooName: 'tax_calculation_rounding_method')  String taxCalculationRoundingMethod, @OdooInteger(odooName: 'quotation_validity_days')  int quotationValidityDays, @OdooBoolean(odooName: 'portal_confirmation_sign')  bool portalConfirmationSign, @OdooBoolean(odooName: 'portal_confirmation_pay')  bool portalConfirmationPay, @OdooFloat(odooName: 'prepayment_percent')  double prepaymentPercent, @OdooMany2One('product.product', odooName: 'sale_discount_product_id')  int? saleDiscountProductId, @OdooMany2OneName(sourceField: 'sale_discount_product_id')  String? saleDiscountProductName, @OdooMany2One('res.partner', odooName: 'partner_id')  int? defaultPartnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? defaultPartnerName, @OdooMany2One('stock.warehouse', odooName: 'warehouse_id')  int? defaultWarehouseId, @OdooMany2OneName(sourceField: 'warehouse_id')  String? defaultWarehouseName, @OdooMany2One('product.pricelist', odooName: 'default_pricelist_id')  int? defaultPricelistId, @OdooMany2OneName(sourceField: 'default_pricelist_id')  String? defaultPricelistName, @OdooMany2One('account.payment.term', odooName: 'default_payment_term_id')  int? defaultPaymentTermId, @OdooMany2OneName(sourceField: 'default_payment_term_id')  String? defaultPaymentTermName, @OdooBoolean(odooName: 'pedir_end_customer_data')  bool pedirEndCustomerData, @OdooBoolean(odooName: 'pedir_sale_referrer')  bool pedirSaleReferrer, @OdooBoolean(odooName: 'pedir_tipo_canal_cliente')  bool pedirTipoCanalCliente, @OdooFloat(odooName: 'sale_customer_invoice_limit_sri')  double? saleCustomerInvoiceLimitSri, @OdooFloat(odooName: 'max_discount_percentage')  double maxDiscountPercentage, @OdooInteger(odooName: 'credit_overdue_days_threshold')  int creditOverdueDaysThreshold, @OdooInteger(odooName: 'credit_overdue_invoices_threshold')  int creditOverdueInvoicesThreshold, @OdooFloat(odooName: 'credit_offline_safety_margin')  double creditOfflineSafetyMargin, @OdooInteger(odooName: 'credit_data_max_age_hours')  int creditDataMaxAgeHours, @OdooInteger(odooName: 'reservation_expiry_days')  int reservationExpiryDays, @OdooMany2One('stock.warehouse', odooName: 'reservation_warehouse_id')  int? reservationWarehouseId, @OdooMany2OneName(sourceField: 'reservation_warehouse_id')  String? reservationWarehouseName, @OdooMany2One('stock.location', odooName: 'reservation_location_id')  int? reservationLocationId, @OdooMany2OneName(sourceField: 'reservation_location_id')  String? reservationLocationName, @OdooBoolean(odooName: 'reserve_from_quotation')  bool reserveFromQuotation, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _Company() when $default != null:
return $default(_that.id,_that.name,_that.vat,_that.street,_that.street2,_that.city,_that.zip,_that.countryId,_that.countryName,_that.stateId,_that.stateName,_that.phone,_that.mobile,_that.email,_that.website,_that.currencyId,_that.currencyName,_that.parentId,_that.parentName,_that.l10nEcComercialName,_that.l10nEcLegalName,_that.l10nEcProductionEnv,_that.logo,_that.reportHeaderImage,_that.reportFooter,_that.primaryColor,_that.secondaryColor,_that.font,_that.layoutBackground,_that.externalReportLayoutId,_that.taxCalculationRoundingMethod,_that.quotationValidityDays,_that.portalConfirmationSign,_that.portalConfirmationPay,_that.prepaymentPercent,_that.saleDiscountProductId,_that.saleDiscountProductName,_that.defaultPartnerId,_that.defaultPartnerName,_that.defaultWarehouseId,_that.defaultWarehouseName,_that.defaultPricelistId,_that.defaultPricelistName,_that.defaultPaymentTermId,_that.defaultPaymentTermName,_that.pedirEndCustomerData,_that.pedirSaleReferrer,_that.pedirTipoCanalCliente,_that.saleCustomerInvoiceLimitSri,_that.maxDiscountPercentage,_that.creditOverdueDaysThreshold,_that.creditOverdueInvoicesThreshold,_that.creditOfflineSafetyMargin,_that.creditDataMaxAgeHours,_that.reservationExpiryDays,_that.reservationWarehouseId,_that.reservationWarehouseName,_that.reservationLocationId,_that.reservationLocationName,_that.reserveFromQuotation,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Company extends Company {
  const _Company({@OdooId() required this.id, @OdooString() required this.name, @OdooString() this.vat, @OdooString() this.street, @OdooString(odooName: 'street2') this.street2, @OdooString() this.city, @OdooString() this.zip, @OdooMany2One('res.country', odooName: 'country_id') this.countryId, @OdooMany2OneName(sourceField: 'country_id') this.countryName, @OdooMany2One('res.country.state', odooName: 'state_id') this.stateId, @OdooMany2OneName(sourceField: 'state_id') this.stateName, @OdooString() this.phone, @OdooLocalOnly() this.mobile, @OdooString() this.email, @OdooString() this.website, @OdooMany2One('res.currency', odooName: 'currency_id') this.currencyId, @OdooMany2OneName(sourceField: 'currency_id') this.currencyName, @OdooMany2One('res.company', odooName: 'parent_id') this.parentId, @OdooMany2OneName(sourceField: 'parent_id') this.parentName, @OdooString(odooName: 'l10n_ec_comercial_name') this.l10nEcComercialName, @OdooString(odooName: 'l10n_ec_legal_name') this.l10nEcLegalName, @OdooBoolean(odooName: 'l10n_ec_production_env') this.l10nEcProductionEnv = false, @OdooBinary() this.logo, @OdooBinary(odooName: 'report_header_image') this.reportHeaderImage, @OdooHtml(odooName: 'report_footer') this.reportFooter, @OdooString(odooName: 'primary_color') this.primaryColor, @OdooString(odooName: 'secondary_color') this.secondaryColor, @OdooString() this.font, @OdooLocalOnly() this.layoutBackground, @OdooMany2One('ir.ui.view', odooName: 'external_report_layout_id') this.externalReportLayoutId, @OdooSelection(odooName: 'tax_calculation_rounding_method') this.taxCalculationRoundingMethod = 'round_per_line', @OdooInteger(odooName: 'quotation_validity_days') this.quotationValidityDays = 30, @OdooBoolean(odooName: 'portal_confirmation_sign') this.portalConfirmationSign = true, @OdooBoolean(odooName: 'portal_confirmation_pay') this.portalConfirmationPay = false, @OdooFloat(odooName: 'prepayment_percent') this.prepaymentPercent = 1.0, @OdooMany2One('product.product', odooName: 'sale_discount_product_id') this.saleDiscountProductId, @OdooMany2OneName(sourceField: 'sale_discount_product_id') this.saleDiscountProductName, @OdooMany2One('res.partner', odooName: 'partner_id') this.defaultPartnerId, @OdooMany2OneName(sourceField: 'partner_id') this.defaultPartnerName, @OdooMany2One('stock.warehouse', odooName: 'warehouse_id') this.defaultWarehouseId, @OdooMany2OneName(sourceField: 'warehouse_id') this.defaultWarehouseName, @OdooMany2One('product.pricelist', odooName: 'default_pricelist_id') this.defaultPricelistId, @OdooMany2OneName(sourceField: 'default_pricelist_id') this.defaultPricelistName, @OdooMany2One('account.payment.term', odooName: 'default_payment_term_id') this.defaultPaymentTermId, @OdooMany2OneName(sourceField: 'default_payment_term_id') this.defaultPaymentTermName, @OdooBoolean(odooName: 'pedir_end_customer_data') this.pedirEndCustomerData = false, @OdooBoolean(odooName: 'pedir_sale_referrer') this.pedirSaleReferrer = false, @OdooBoolean(odooName: 'pedir_tipo_canal_cliente') this.pedirTipoCanalCliente = false, @OdooFloat(odooName: 'sale_customer_invoice_limit_sri') this.saleCustomerInvoiceLimitSri, @OdooFloat(odooName: 'max_discount_percentage') this.maxDiscountPercentage = 100.0, @OdooInteger(odooName: 'credit_overdue_days_threshold') this.creditOverdueDaysThreshold = 30, @OdooInteger(odooName: 'credit_overdue_invoices_threshold') this.creditOverdueInvoicesThreshold = 3, @OdooFloat(odooName: 'credit_offline_safety_margin') this.creditOfflineSafetyMargin = 0.0, @OdooInteger(odooName: 'credit_data_max_age_hours') this.creditDataMaxAgeHours = 24, @OdooInteger(odooName: 'reservation_expiry_days') this.reservationExpiryDays = 7, @OdooMany2One('stock.warehouse', odooName: 'reservation_warehouse_id') this.reservationWarehouseId, @OdooMany2OneName(sourceField: 'reservation_warehouse_id') this.reservationWarehouseName, @OdooMany2One('stock.location', odooName: 'reservation_location_id') this.reservationLocationId, @OdooMany2OneName(sourceField: 'reservation_location_id') this.reservationLocationName, @OdooBoolean(odooName: 'reserve_from_quotation') this.reserveFromQuotation = false, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  factory _Company.fromJson(Map<String, dynamic> json) => _$CompanyFromJson(json);

// ═══════════════════ Identifiers ═══════════════════
@override@OdooId() final  int id;
@override@OdooString() final  String name;
// ═══════════════════ Basic Info ═══════════════════
@override@OdooString() final  String? vat;
@override@OdooString() final  String? street;
@override@OdooString(odooName: 'street2') final  String? street2;
@override@OdooString() final  String? city;
@override@OdooString() final  String? zip;
@override@OdooMany2One('res.country', odooName: 'country_id') final  int? countryId;
@override@OdooMany2OneName(sourceField: 'country_id') final  String? countryName;
@override@OdooMany2One('res.country.state', odooName: 'state_id') final  int? stateId;
@override@OdooMany2OneName(sourceField: 'state_id') final  String? stateName;
@override@OdooString() final  String? phone;
@override@OdooLocalOnly() final  String? mobile;
// Removed from Odoo 19
@override@OdooString() final  String? email;
@override@OdooString() final  String? website;
@override@OdooMany2One('res.currency', odooName: 'currency_id') final  int? currencyId;
@override@OdooMany2OneName(sourceField: 'currency_id') final  String? currencyName;
@override@OdooMany2One('res.company', odooName: 'parent_id') final  int? parentId;
@override@OdooMany2OneName(sourceField: 'parent_id') final  String? parentName;
// ═══════════════════ Ecuador SRI Fields ═══════════════════
@override@OdooString(odooName: 'l10n_ec_comercial_name') final  String? l10nEcComercialName;
@override@OdooString(odooName: 'l10n_ec_legal_name') final  String? l10nEcLegalName;
@override@JsonKey()@OdooBoolean(odooName: 'l10n_ec_production_env') final  bool l10nEcProductionEnv;
// ═══════════════════ Document Layout ═══════════════════
@override@OdooBinary() final  String? logo;
@override@OdooBinary(odooName: 'report_header_image') final  String? reportHeaderImage;
@override@OdooHtml(odooName: 'report_footer') final  String? reportFooter;
@override@OdooString(odooName: 'primary_color') final  String? primaryColor;
@override@OdooString(odooName: 'secondary_color') final  String? secondaryColor;
@override@OdooString() final  String? font;
@override@OdooLocalOnly() final  String? layoutBackground;
// Removed from Odoo 19
@override@OdooMany2One('ir.ui.view', odooName: 'external_report_layout_id') final  int? externalReportLayoutId;
// ═══════════════════ Tax Configuration ═══════════════════
@override@JsonKey()@OdooSelection(odooName: 'tax_calculation_rounding_method') final  String taxCalculationRoundingMethod;
// ═══════════════════ Sales Configuration ═══════════════════
/// Days a quotation is valid
@override@JsonKey()@OdooInteger(odooName: 'quotation_validity_days') final  int quotationValidityDays;
/// Require signature for portal confirmation
@override@JsonKey()@OdooBoolean(odooName: 'portal_confirmation_sign') final  bool portalConfirmationSign;
/// Require payment for portal confirmation
@override@JsonKey()@OdooBoolean(odooName: 'portal_confirmation_pay') final  bool portalConfirmationPay;
/// Prepayment percentage
@override@JsonKey()@OdooFloat(odooName: 'prepayment_percent') final  double prepaymentPercent;
/// Discount product ID
@override@OdooMany2One('product.product', odooName: 'sale_discount_product_id') final  int? saleDiscountProductId;
/// Discount product name
@override@OdooMany2OneName(sourceField: 'sale_discount_product_id') final  String? saleDiscountProductName;
// ═══════════════════ Sales Defaults ═══════════════════
/// Default partner for new sales
@override@OdooMany2One('res.partner', odooName: 'partner_id') final  int? defaultPartnerId;
@override@OdooMany2OneName(sourceField: 'partner_id') final  String? defaultPartnerName;
/// Default warehouse for new sales
@override@OdooMany2One('stock.warehouse', odooName: 'warehouse_id') final  int? defaultWarehouseId;
@override@OdooMany2OneName(sourceField: 'warehouse_id') final  String? defaultWarehouseName;
/// Default pricelist for new sales
@override@OdooMany2One('product.pricelist', odooName: 'default_pricelist_id') final  int? defaultPricelistId;
@override@OdooMany2OneName(sourceField: 'default_pricelist_id') final  String? defaultPricelistName;
/// Default payment term for new sales
@override@OdooMany2One('account.payment.term', odooName: 'default_payment_term_id') final  int? defaultPaymentTermId;
@override@OdooMany2OneName(sourceField: 'default_payment_term_id') final  String? defaultPaymentTermName;
/// Whether to require end customer data in sales
@override@JsonKey()@OdooBoolean(odooName: 'pedir_end_customer_data') final  bool pedirEndCustomerData;
/// Whether to require sales referrer
@override@JsonKey()@OdooBoolean(odooName: 'pedir_sale_referrer') final  bool pedirSaleReferrer;
/// Whether to require client type/channel
@override@JsonKey()@OdooBoolean(odooName: 'pedir_tipo_canal_cliente') final  bool pedirTipoCanalCliente;
/// SRI invoice limit for sales customers
@override@OdooFloat(odooName: 'sale_customer_invoice_limit_sri') final  double? saleCustomerInvoiceLimitSri;
/// Maximum discount percentage allowed
@override@JsonKey()@OdooFloat(odooName: 'max_discount_percentage') final  double maxDiscountPercentage;
// ═══════════════════ Credit Control Configuration ═══════════════════
/// Overdue days threshold for credit blocking
@override@JsonKey()@OdooInteger(odooName: 'credit_overdue_days_threshold') final  int creditOverdueDaysThreshold;
/// Overdue invoices threshold for credit blocking
@override@JsonKey()@OdooInteger(odooName: 'credit_overdue_invoices_threshold') final  int creditOverdueInvoicesThreshold;
/// Safety margin for offline credit validation (%)
@override@JsonKey()@OdooFloat(odooName: 'credit_offline_safety_margin') final  double creditOfflineSafetyMargin;
/// Maximum age in hours for credit data to be considered valid
@override@JsonKey()@OdooInteger(odooName: 'credit_data_max_age_hours') final  int creditDataMaxAgeHours;
// ═══════════════════ Reservation Configuration ═══════════════════
/// Days before a reservation expires
@override@JsonKey()@OdooInteger(odooName: 'reservation_expiry_days') final  int reservationExpiryDays;
/// Warehouse for reservations
@override@OdooMany2One('stock.warehouse', odooName: 'reservation_warehouse_id') final  int? reservationWarehouseId;
/// Warehouse name for reservations
@override@OdooMany2OneName(sourceField: 'reservation_warehouse_id') final  String? reservationWarehouseName;
/// Location for reservations
@override@OdooMany2One('stock.location', odooName: 'reservation_location_id') final  int? reservationLocationId;
/// Location name for reservations
@override@OdooMany2OneName(sourceField: 'reservation_location_id') final  String? reservationLocationName;
/// Reserve stock from quotation stage
@override@JsonKey()@OdooBoolean(odooName: 'reserve_from_quotation') final  bool reserveFromQuotation;
// ═══════════════════ Metadata ═══════════════════
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyCopyWith<_Company> get copyWith => __$CompanyCopyWithImpl<_Company>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Company&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.vat, vat) || other.vat == vat)&&(identical(other.street, street) || other.street == street)&&(identical(other.street2, street2) || other.street2 == street2)&&(identical(other.city, city) || other.city == city)&&(identical(other.zip, zip) || other.zip == zip)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.countryName, countryName) || other.countryName == countryName)&&(identical(other.stateId, stateId) || other.stateId == stateId)&&(identical(other.stateName, stateName) || other.stateName == stateName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.email, email) || other.email == email)&&(identical(other.website, website) || other.website == website)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.currencyName, currencyName) || other.currencyName == currencyName)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.parentName, parentName) || other.parentName == parentName)&&(identical(other.l10nEcComercialName, l10nEcComercialName) || other.l10nEcComercialName == l10nEcComercialName)&&(identical(other.l10nEcLegalName, l10nEcLegalName) || other.l10nEcLegalName == l10nEcLegalName)&&(identical(other.l10nEcProductionEnv, l10nEcProductionEnv) || other.l10nEcProductionEnv == l10nEcProductionEnv)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.reportHeaderImage, reportHeaderImage) || other.reportHeaderImage == reportHeaderImage)&&(identical(other.reportFooter, reportFooter) || other.reportFooter == reportFooter)&&(identical(other.primaryColor, primaryColor) || other.primaryColor == primaryColor)&&(identical(other.secondaryColor, secondaryColor) || other.secondaryColor == secondaryColor)&&(identical(other.font, font) || other.font == font)&&(identical(other.layoutBackground, layoutBackground) || other.layoutBackground == layoutBackground)&&(identical(other.externalReportLayoutId, externalReportLayoutId) || other.externalReportLayoutId == externalReportLayoutId)&&(identical(other.taxCalculationRoundingMethod, taxCalculationRoundingMethod) || other.taxCalculationRoundingMethod == taxCalculationRoundingMethod)&&(identical(other.quotationValidityDays, quotationValidityDays) || other.quotationValidityDays == quotationValidityDays)&&(identical(other.portalConfirmationSign, portalConfirmationSign) || other.portalConfirmationSign == portalConfirmationSign)&&(identical(other.portalConfirmationPay, portalConfirmationPay) || other.portalConfirmationPay == portalConfirmationPay)&&(identical(other.prepaymentPercent, prepaymentPercent) || other.prepaymentPercent == prepaymentPercent)&&(identical(other.saleDiscountProductId, saleDiscountProductId) || other.saleDiscountProductId == saleDiscountProductId)&&(identical(other.saleDiscountProductName, saleDiscountProductName) || other.saleDiscountProductName == saleDiscountProductName)&&(identical(other.defaultPartnerId, defaultPartnerId) || other.defaultPartnerId == defaultPartnerId)&&(identical(other.defaultPartnerName, defaultPartnerName) || other.defaultPartnerName == defaultPartnerName)&&(identical(other.defaultWarehouseId, defaultWarehouseId) || other.defaultWarehouseId == defaultWarehouseId)&&(identical(other.defaultWarehouseName, defaultWarehouseName) || other.defaultWarehouseName == defaultWarehouseName)&&(identical(other.defaultPricelistId, defaultPricelistId) || other.defaultPricelistId == defaultPricelistId)&&(identical(other.defaultPricelistName, defaultPricelistName) || other.defaultPricelistName == defaultPricelistName)&&(identical(other.defaultPaymentTermId, defaultPaymentTermId) || other.defaultPaymentTermId == defaultPaymentTermId)&&(identical(other.defaultPaymentTermName, defaultPaymentTermName) || other.defaultPaymentTermName == defaultPaymentTermName)&&(identical(other.pedirEndCustomerData, pedirEndCustomerData) || other.pedirEndCustomerData == pedirEndCustomerData)&&(identical(other.pedirSaleReferrer, pedirSaleReferrer) || other.pedirSaleReferrer == pedirSaleReferrer)&&(identical(other.pedirTipoCanalCliente, pedirTipoCanalCliente) || other.pedirTipoCanalCliente == pedirTipoCanalCliente)&&(identical(other.saleCustomerInvoiceLimitSri, saleCustomerInvoiceLimitSri) || other.saleCustomerInvoiceLimitSri == saleCustomerInvoiceLimitSri)&&(identical(other.maxDiscountPercentage, maxDiscountPercentage) || other.maxDiscountPercentage == maxDiscountPercentage)&&(identical(other.creditOverdueDaysThreshold, creditOverdueDaysThreshold) || other.creditOverdueDaysThreshold == creditOverdueDaysThreshold)&&(identical(other.creditOverdueInvoicesThreshold, creditOverdueInvoicesThreshold) || other.creditOverdueInvoicesThreshold == creditOverdueInvoicesThreshold)&&(identical(other.creditOfflineSafetyMargin, creditOfflineSafetyMargin) || other.creditOfflineSafetyMargin == creditOfflineSafetyMargin)&&(identical(other.creditDataMaxAgeHours, creditDataMaxAgeHours) || other.creditDataMaxAgeHours == creditDataMaxAgeHours)&&(identical(other.reservationExpiryDays, reservationExpiryDays) || other.reservationExpiryDays == reservationExpiryDays)&&(identical(other.reservationWarehouseId, reservationWarehouseId) || other.reservationWarehouseId == reservationWarehouseId)&&(identical(other.reservationWarehouseName, reservationWarehouseName) || other.reservationWarehouseName == reservationWarehouseName)&&(identical(other.reservationLocationId, reservationLocationId) || other.reservationLocationId == reservationLocationId)&&(identical(other.reservationLocationName, reservationLocationName) || other.reservationLocationName == reservationLocationName)&&(identical(other.reserveFromQuotation, reserveFromQuotation) || other.reserveFromQuotation == reserveFromQuotation)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,vat,street,street2,city,zip,countryId,countryName,stateId,stateName,phone,mobile,email,website,currencyId,currencyName,parentId,parentName,l10nEcComercialName,l10nEcLegalName,l10nEcProductionEnv,logo,reportHeaderImage,reportFooter,primaryColor,secondaryColor,font,layoutBackground,externalReportLayoutId,taxCalculationRoundingMethod,quotationValidityDays,portalConfirmationSign,portalConfirmationPay,prepaymentPercent,saleDiscountProductId,saleDiscountProductName,defaultPartnerId,defaultPartnerName,defaultWarehouseId,defaultWarehouseName,defaultPricelistId,defaultPricelistName,defaultPaymentTermId,defaultPaymentTermName,pedirEndCustomerData,pedirSaleReferrer,pedirTipoCanalCliente,saleCustomerInvoiceLimitSri,maxDiscountPercentage,creditOverdueDaysThreshold,creditOverdueInvoicesThreshold,creditOfflineSafetyMargin,creditDataMaxAgeHours,reservationExpiryDays,reservationWarehouseId,reservationWarehouseName,reservationLocationId,reservationLocationName,reserveFromQuotation,writeDate]);

@override
String toString() {
  return 'Company(id: $id, name: $name, vat: $vat, street: $street, street2: $street2, city: $city, zip: $zip, countryId: $countryId, countryName: $countryName, stateId: $stateId, stateName: $stateName, phone: $phone, mobile: $mobile, email: $email, website: $website, currencyId: $currencyId, currencyName: $currencyName, parentId: $parentId, parentName: $parentName, l10nEcComercialName: $l10nEcComercialName, l10nEcLegalName: $l10nEcLegalName, l10nEcProductionEnv: $l10nEcProductionEnv, logo: $logo, reportHeaderImage: $reportHeaderImage, reportFooter: $reportFooter, primaryColor: $primaryColor, secondaryColor: $secondaryColor, font: $font, layoutBackground: $layoutBackground, externalReportLayoutId: $externalReportLayoutId, taxCalculationRoundingMethod: $taxCalculationRoundingMethod, quotationValidityDays: $quotationValidityDays, portalConfirmationSign: $portalConfirmationSign, portalConfirmationPay: $portalConfirmationPay, prepaymentPercent: $prepaymentPercent, saleDiscountProductId: $saleDiscountProductId, saleDiscountProductName: $saleDiscountProductName, defaultPartnerId: $defaultPartnerId, defaultPartnerName: $defaultPartnerName, defaultWarehouseId: $defaultWarehouseId, defaultWarehouseName: $defaultWarehouseName, defaultPricelistId: $defaultPricelistId, defaultPricelistName: $defaultPricelistName, defaultPaymentTermId: $defaultPaymentTermId, defaultPaymentTermName: $defaultPaymentTermName, pedirEndCustomerData: $pedirEndCustomerData, pedirSaleReferrer: $pedirSaleReferrer, pedirTipoCanalCliente: $pedirTipoCanalCliente, saleCustomerInvoiceLimitSri: $saleCustomerInvoiceLimitSri, maxDiscountPercentage: $maxDiscountPercentage, creditOverdueDaysThreshold: $creditOverdueDaysThreshold, creditOverdueInvoicesThreshold: $creditOverdueInvoicesThreshold, creditOfflineSafetyMargin: $creditOfflineSafetyMargin, creditDataMaxAgeHours: $creditDataMaxAgeHours, reservationExpiryDays: $reservationExpiryDays, reservationWarehouseId: $reservationWarehouseId, reservationWarehouseName: $reservationWarehouseName, reservationLocationId: $reservationLocationId, reservationLocationName: $reservationLocationName, reserveFromQuotation: $reserveFromQuotation, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$CompanyCopyWith<$Res> implements $CompanyCopyWith<$Res> {
  factory _$CompanyCopyWith(_Company value, $Res Function(_Company) _then) = __$CompanyCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String? vat,@OdooString() String? street,@OdooString(odooName: 'street2') String? street2,@OdooString() String? city,@OdooString() String? zip,@OdooMany2One('res.country', odooName: 'country_id') int? countryId,@OdooMany2OneName(sourceField: 'country_id') String? countryName,@OdooMany2One('res.country.state', odooName: 'state_id') int? stateId,@OdooMany2OneName(sourceField: 'state_id') String? stateName,@OdooString() String? phone,@OdooLocalOnly() String? mobile,@OdooString() String? email,@OdooString() String? website,@OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,@OdooMany2OneName(sourceField: 'currency_id') String? currencyName,@OdooMany2One('res.company', odooName: 'parent_id') int? parentId,@OdooMany2OneName(sourceField: 'parent_id') String? parentName,@OdooString(odooName: 'l10n_ec_comercial_name') String? l10nEcComercialName,@OdooString(odooName: 'l10n_ec_legal_name') String? l10nEcLegalName,@OdooBoolean(odooName: 'l10n_ec_production_env') bool l10nEcProductionEnv,@OdooBinary() String? logo,@OdooBinary(odooName: 'report_header_image') String? reportHeaderImage,@OdooHtml(odooName: 'report_footer') String? reportFooter,@OdooString(odooName: 'primary_color') String? primaryColor,@OdooString(odooName: 'secondary_color') String? secondaryColor,@OdooString() String? font,@OdooLocalOnly() String? layoutBackground,@OdooMany2One('ir.ui.view', odooName: 'external_report_layout_id') int? externalReportLayoutId,@OdooSelection(odooName: 'tax_calculation_rounding_method') String taxCalculationRoundingMethod,@OdooInteger(odooName: 'quotation_validity_days') int quotationValidityDays,@OdooBoolean(odooName: 'portal_confirmation_sign') bool portalConfirmationSign,@OdooBoolean(odooName: 'portal_confirmation_pay') bool portalConfirmationPay,@OdooFloat(odooName: 'prepayment_percent') double prepaymentPercent,@OdooMany2One('product.product', odooName: 'sale_discount_product_id') int? saleDiscountProductId,@OdooMany2OneName(sourceField: 'sale_discount_product_id') String? saleDiscountProductName,@OdooMany2One('res.partner', odooName: 'partner_id') int? defaultPartnerId,@OdooMany2OneName(sourceField: 'partner_id') String? defaultPartnerName,@OdooMany2One('stock.warehouse', odooName: 'warehouse_id') int? defaultWarehouseId,@OdooMany2OneName(sourceField: 'warehouse_id') String? defaultWarehouseName,@OdooMany2One('product.pricelist', odooName: 'default_pricelist_id') int? defaultPricelistId,@OdooMany2OneName(sourceField: 'default_pricelist_id') String? defaultPricelistName,@OdooMany2One('account.payment.term', odooName: 'default_payment_term_id') int? defaultPaymentTermId,@OdooMany2OneName(sourceField: 'default_payment_term_id') String? defaultPaymentTermName,@OdooBoolean(odooName: 'pedir_end_customer_data') bool pedirEndCustomerData,@OdooBoolean(odooName: 'pedir_sale_referrer') bool pedirSaleReferrer,@OdooBoolean(odooName: 'pedir_tipo_canal_cliente') bool pedirTipoCanalCliente,@OdooFloat(odooName: 'sale_customer_invoice_limit_sri') double? saleCustomerInvoiceLimitSri,@OdooFloat(odooName: 'max_discount_percentage') double maxDiscountPercentage,@OdooInteger(odooName: 'credit_overdue_days_threshold') int creditOverdueDaysThreshold,@OdooInteger(odooName: 'credit_overdue_invoices_threshold') int creditOverdueInvoicesThreshold,@OdooFloat(odooName: 'credit_offline_safety_margin') double creditOfflineSafetyMargin,@OdooInteger(odooName: 'credit_data_max_age_hours') int creditDataMaxAgeHours,@OdooInteger(odooName: 'reservation_expiry_days') int reservationExpiryDays,@OdooMany2One('stock.warehouse', odooName: 'reservation_warehouse_id') int? reservationWarehouseId,@OdooMany2OneName(sourceField: 'reservation_warehouse_id') String? reservationWarehouseName,@OdooMany2One('stock.location', odooName: 'reservation_location_id') int? reservationLocationId,@OdooMany2OneName(sourceField: 'reservation_location_id') String? reservationLocationName,@OdooBoolean(odooName: 'reserve_from_quotation') bool reserveFromQuotation,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$CompanyCopyWithImpl<$Res>
    implements _$CompanyCopyWith<$Res> {
  __$CompanyCopyWithImpl(this._self, this._then);

  final _Company _self;
  final $Res Function(_Company) _then;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? vat = freezed,Object? street = freezed,Object? street2 = freezed,Object? city = freezed,Object? zip = freezed,Object? countryId = freezed,Object? countryName = freezed,Object? stateId = freezed,Object? stateName = freezed,Object? phone = freezed,Object? mobile = freezed,Object? email = freezed,Object? website = freezed,Object? currencyId = freezed,Object? currencyName = freezed,Object? parentId = freezed,Object? parentName = freezed,Object? l10nEcComercialName = freezed,Object? l10nEcLegalName = freezed,Object? l10nEcProductionEnv = null,Object? logo = freezed,Object? reportHeaderImage = freezed,Object? reportFooter = freezed,Object? primaryColor = freezed,Object? secondaryColor = freezed,Object? font = freezed,Object? layoutBackground = freezed,Object? externalReportLayoutId = freezed,Object? taxCalculationRoundingMethod = null,Object? quotationValidityDays = null,Object? portalConfirmationSign = null,Object? portalConfirmationPay = null,Object? prepaymentPercent = null,Object? saleDiscountProductId = freezed,Object? saleDiscountProductName = freezed,Object? defaultPartnerId = freezed,Object? defaultPartnerName = freezed,Object? defaultWarehouseId = freezed,Object? defaultWarehouseName = freezed,Object? defaultPricelistId = freezed,Object? defaultPricelistName = freezed,Object? defaultPaymentTermId = freezed,Object? defaultPaymentTermName = freezed,Object? pedirEndCustomerData = null,Object? pedirSaleReferrer = null,Object? pedirTipoCanalCliente = null,Object? saleCustomerInvoiceLimitSri = freezed,Object? maxDiscountPercentage = null,Object? creditOverdueDaysThreshold = null,Object? creditOverdueInvoicesThreshold = null,Object? creditOfflineSafetyMargin = null,Object? creditDataMaxAgeHours = null,Object? reservationExpiryDays = null,Object? reservationWarehouseId = freezed,Object? reservationWarehouseName = freezed,Object? reservationLocationId = freezed,Object? reservationLocationName = freezed,Object? reserveFromQuotation = null,Object? writeDate = freezed,}) {
  return _then(_Company(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,vat: freezed == vat ? _self.vat : vat // ignore: cast_nullable_to_non_nullable
as String?,street: freezed == street ? _self.street : street // ignore: cast_nullable_to_non_nullable
as String?,street2: freezed == street2 ? _self.street2 : street2 // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,zip: freezed == zip ? _self.zip : zip // ignore: cast_nullable_to_non_nullable
as String?,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as int?,countryName: freezed == countryName ? _self.countryName : countryName // ignore: cast_nullable_to_non_nullable
as String?,stateId: freezed == stateId ? _self.stateId : stateId // ignore: cast_nullable_to_non_nullable
as int?,stateName: freezed == stateName ? _self.stateName : stateName // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,website: freezed == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String?,currencyId: freezed == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as int?,currencyName: freezed == currencyName ? _self.currencyName : currencyName // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as int?,parentName: freezed == parentName ? _self.parentName : parentName // ignore: cast_nullable_to_non_nullable
as String?,l10nEcComercialName: freezed == l10nEcComercialName ? _self.l10nEcComercialName : l10nEcComercialName // ignore: cast_nullable_to_non_nullable
as String?,l10nEcLegalName: freezed == l10nEcLegalName ? _self.l10nEcLegalName : l10nEcLegalName // ignore: cast_nullable_to_non_nullable
as String?,l10nEcProductionEnv: null == l10nEcProductionEnv ? _self.l10nEcProductionEnv : l10nEcProductionEnv // ignore: cast_nullable_to_non_nullable
as bool,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,reportHeaderImage: freezed == reportHeaderImage ? _self.reportHeaderImage : reportHeaderImage // ignore: cast_nullable_to_non_nullable
as String?,reportFooter: freezed == reportFooter ? _self.reportFooter : reportFooter // ignore: cast_nullable_to_non_nullable
as String?,primaryColor: freezed == primaryColor ? _self.primaryColor : primaryColor // ignore: cast_nullable_to_non_nullable
as String?,secondaryColor: freezed == secondaryColor ? _self.secondaryColor : secondaryColor // ignore: cast_nullable_to_non_nullable
as String?,font: freezed == font ? _self.font : font // ignore: cast_nullable_to_non_nullable
as String?,layoutBackground: freezed == layoutBackground ? _self.layoutBackground : layoutBackground // ignore: cast_nullable_to_non_nullable
as String?,externalReportLayoutId: freezed == externalReportLayoutId ? _self.externalReportLayoutId : externalReportLayoutId // ignore: cast_nullable_to_non_nullable
as int?,taxCalculationRoundingMethod: null == taxCalculationRoundingMethod ? _self.taxCalculationRoundingMethod : taxCalculationRoundingMethod // ignore: cast_nullable_to_non_nullable
as String,quotationValidityDays: null == quotationValidityDays ? _self.quotationValidityDays : quotationValidityDays // ignore: cast_nullable_to_non_nullable
as int,portalConfirmationSign: null == portalConfirmationSign ? _self.portalConfirmationSign : portalConfirmationSign // ignore: cast_nullable_to_non_nullable
as bool,portalConfirmationPay: null == portalConfirmationPay ? _self.portalConfirmationPay : portalConfirmationPay // ignore: cast_nullable_to_non_nullable
as bool,prepaymentPercent: null == prepaymentPercent ? _self.prepaymentPercent : prepaymentPercent // ignore: cast_nullable_to_non_nullable
as double,saleDiscountProductId: freezed == saleDiscountProductId ? _self.saleDiscountProductId : saleDiscountProductId // ignore: cast_nullable_to_non_nullable
as int?,saleDiscountProductName: freezed == saleDiscountProductName ? _self.saleDiscountProductName : saleDiscountProductName // ignore: cast_nullable_to_non_nullable
as String?,defaultPartnerId: freezed == defaultPartnerId ? _self.defaultPartnerId : defaultPartnerId // ignore: cast_nullable_to_non_nullable
as int?,defaultPartnerName: freezed == defaultPartnerName ? _self.defaultPartnerName : defaultPartnerName // ignore: cast_nullable_to_non_nullable
as String?,defaultWarehouseId: freezed == defaultWarehouseId ? _self.defaultWarehouseId : defaultWarehouseId // ignore: cast_nullable_to_non_nullable
as int?,defaultWarehouseName: freezed == defaultWarehouseName ? _self.defaultWarehouseName : defaultWarehouseName // ignore: cast_nullable_to_non_nullable
as String?,defaultPricelistId: freezed == defaultPricelistId ? _self.defaultPricelistId : defaultPricelistId // ignore: cast_nullable_to_non_nullable
as int?,defaultPricelistName: freezed == defaultPricelistName ? _self.defaultPricelistName : defaultPricelistName // ignore: cast_nullable_to_non_nullable
as String?,defaultPaymentTermId: freezed == defaultPaymentTermId ? _self.defaultPaymentTermId : defaultPaymentTermId // ignore: cast_nullable_to_non_nullable
as int?,defaultPaymentTermName: freezed == defaultPaymentTermName ? _self.defaultPaymentTermName : defaultPaymentTermName // ignore: cast_nullable_to_non_nullable
as String?,pedirEndCustomerData: null == pedirEndCustomerData ? _self.pedirEndCustomerData : pedirEndCustomerData // ignore: cast_nullable_to_non_nullable
as bool,pedirSaleReferrer: null == pedirSaleReferrer ? _self.pedirSaleReferrer : pedirSaleReferrer // ignore: cast_nullable_to_non_nullable
as bool,pedirTipoCanalCliente: null == pedirTipoCanalCliente ? _self.pedirTipoCanalCliente : pedirTipoCanalCliente // ignore: cast_nullable_to_non_nullable
as bool,saleCustomerInvoiceLimitSri: freezed == saleCustomerInvoiceLimitSri ? _self.saleCustomerInvoiceLimitSri : saleCustomerInvoiceLimitSri // ignore: cast_nullable_to_non_nullable
as double?,maxDiscountPercentage: null == maxDiscountPercentage ? _self.maxDiscountPercentage : maxDiscountPercentage // ignore: cast_nullable_to_non_nullable
as double,creditOverdueDaysThreshold: null == creditOverdueDaysThreshold ? _self.creditOverdueDaysThreshold : creditOverdueDaysThreshold // ignore: cast_nullable_to_non_nullable
as int,creditOverdueInvoicesThreshold: null == creditOverdueInvoicesThreshold ? _self.creditOverdueInvoicesThreshold : creditOverdueInvoicesThreshold // ignore: cast_nullable_to_non_nullable
as int,creditOfflineSafetyMargin: null == creditOfflineSafetyMargin ? _self.creditOfflineSafetyMargin : creditOfflineSafetyMargin // ignore: cast_nullable_to_non_nullable
as double,creditDataMaxAgeHours: null == creditDataMaxAgeHours ? _self.creditDataMaxAgeHours : creditDataMaxAgeHours // ignore: cast_nullable_to_non_nullable
as int,reservationExpiryDays: null == reservationExpiryDays ? _self.reservationExpiryDays : reservationExpiryDays // ignore: cast_nullable_to_non_nullable
as int,reservationWarehouseId: freezed == reservationWarehouseId ? _self.reservationWarehouseId : reservationWarehouseId // ignore: cast_nullable_to_non_nullable
as int?,reservationWarehouseName: freezed == reservationWarehouseName ? _self.reservationWarehouseName : reservationWarehouseName // ignore: cast_nullable_to_non_nullable
as String?,reservationLocationId: freezed == reservationLocationId ? _self.reservationLocationId : reservationLocationId // ignore: cast_nullable_to_non_nullable
as int?,reservationLocationName: freezed == reservationLocationName ? _self.reservationLocationName : reservationLocationName // ignore: cast_nullable_to_non_nullable
as String?,reserveFromQuotation: null == reserveFromQuotation ? _self.reserveFromQuotation : reserveFromQuotation // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
