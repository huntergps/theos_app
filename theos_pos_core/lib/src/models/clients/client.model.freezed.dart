// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Client {

// ============ Identifiers ============
@OdooId() int get id;@OdooLocalOnly() String? get uuid;@OdooLocalOnly() bool get isSynced;// ============ Basic Data ============
@OdooString() String get name;@OdooString(odooName: 'display_name') String? get displayName;@OdooString() String? get ref;@OdooString() String? get vat;@OdooString() String? get email;@OdooString() String? get phone;@OdooString() String? get mobile;@OdooString() String? get street;@OdooString() String? get street2;@OdooString() String? get city;@OdooString() String? get zip;@OdooMany2One('res.country', odooName: 'country_id') int? get countryId;@OdooMany2OneName(sourceField: 'country_id') String? get countryName;@OdooMany2One('res.country.state', odooName: 'state_id') int? get stateId;@OdooMany2OneName(sourceField: 'state_id') String? get stateName;@OdooString(odooName: 'avatar_128') String? get avatar128;@OdooBoolean(odooName: 'is_company') bool get isCompany;@OdooBoolean() bool get active;// ============ Relations ============
@OdooMany2One('res.partner', odooName: 'parent_id') int? get parentId;@OdooMany2OneName(sourceField: 'parent_id') String? get parentName;@OdooMany2OneName(sourceField: 'commercial_partner_id') String? get commercialPartnerName;@OdooMany2One('product.pricelist', odooName: 'property_product_pricelist') int? get propertyProductPricelistId;@OdooMany2OneName(sourceField: 'property_product_pricelist') String? get propertyProductPricelistName;@OdooMany2One('account.payment.term', odooName: 'property_payment_term_id') int? get propertyPaymentTermId;@OdooMany2OneName(sourceField: 'property_payment_term_id') String? get propertyPaymentTermName;@OdooString() String? get lang;@OdooString() String? get comment;// ============ Credit Control Fields (l10n_ec_sale_credit) ============
@OdooFloat(odooName: 'credit_limit') double? get creditLimit;@OdooFloat() double? get credit;@OdooFloat(odooName: 'credit_to_invoice') double? get creditToInvoice;@OdooBoolean(odooName: 'allow_over_credit') bool get allowOverCredit;@OdooBoolean(odooName: 'use_partner_credit_limit') bool get usePartnerCreditLimit;// ============ Overdue Debt Fields ============
@OdooFloat(odooName: 'total_overdue') double? get totalOverdue;@OdooInteger(odooName: 'unpaid_invoices_count') int? get overdueInvoicesCount;@OdooInteger(odooName: 'oldest_overdue_days') int? get oldestOverdueDays;// ============ Ecuador Fields ============
@OdooInteger(odooName: 'dias_max_factura_posterior') int? get diasMaxFacturaPosterior;// ============ Customer Classification (l10n_ec_sale_base) ============
@OdooSelection(odooName: 'tipo_cliente') String? get tipoCliente;@OdooSelection(odooName: 'canal_cliente') String? get canalCliente;// ============ Ranking ============
@OdooInteger(odooName: 'customer_rank') int? get customerRank;@OdooInteger(odooName: 'supplier_rank') int? get supplierRank;// ============ Check Acceptance ============
@OdooBoolean(odooName: 'acepta_cheques') bool get aceptaCheques;// ============ Invoice Configuration ============
@OdooBoolean(odooName: 'emitir_factura_fecha_posterior') bool get emitirFacturaFechaPosterior;@OdooBoolean(odooName: 'no_invoice') bool get noInvoice;@OdooInteger(odooName: 'last_day_to_invoice') int? get lastDayToInvoice;// ============ External ID ============
@OdooString(odooName: 'external_id') String? get externalId;// ============ Geolocation ============
@OdooFloat(odooName: 'partner_latitude') double? get partnerLatitude;@OdooFloat(odooName: 'partner_longitude') double? get partnerLongitude;// ============ Custom Payments ============
@OdooBoolean(odooName: 'can_use_custom_payments') bool get canUseCustomPayments;// ============ Metadata ============
@OdooDateTime(odooName: 'write_date') DateTime? get writeDate;@OdooLocalOnly() DateTime? get creditLastSyncDate;
/// Create a copy of Client
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClientCopyWith<Client> get copyWith => _$ClientCopyWithImpl<Client>(this as Client, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Client&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.vat, vat) || other.vat == vat)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.street, street) || other.street == street)&&(identical(other.street2, street2) || other.street2 == street2)&&(identical(other.city, city) || other.city == city)&&(identical(other.zip, zip) || other.zip == zip)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.countryName, countryName) || other.countryName == countryName)&&(identical(other.stateId, stateId) || other.stateId == stateId)&&(identical(other.stateName, stateName) || other.stateName == stateName)&&(identical(other.avatar128, avatar128) || other.avatar128 == avatar128)&&(identical(other.isCompany, isCompany) || other.isCompany == isCompany)&&(identical(other.active, active) || other.active == active)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.parentName, parentName) || other.parentName == parentName)&&(identical(other.commercialPartnerName, commercialPartnerName) || other.commercialPartnerName == commercialPartnerName)&&(identical(other.propertyProductPricelistId, propertyProductPricelistId) || other.propertyProductPricelistId == propertyProductPricelistId)&&(identical(other.propertyProductPricelistName, propertyProductPricelistName) || other.propertyProductPricelistName == propertyProductPricelistName)&&(identical(other.propertyPaymentTermId, propertyPaymentTermId) || other.propertyPaymentTermId == propertyPaymentTermId)&&(identical(other.propertyPaymentTermName, propertyPaymentTermName) || other.propertyPaymentTermName == propertyPaymentTermName)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.creditLimit, creditLimit) || other.creditLimit == creditLimit)&&(identical(other.credit, credit) || other.credit == credit)&&(identical(other.creditToInvoice, creditToInvoice) || other.creditToInvoice == creditToInvoice)&&(identical(other.allowOverCredit, allowOverCredit) || other.allowOverCredit == allowOverCredit)&&(identical(other.usePartnerCreditLimit, usePartnerCreditLimit) || other.usePartnerCreditLimit == usePartnerCreditLimit)&&(identical(other.totalOverdue, totalOverdue) || other.totalOverdue == totalOverdue)&&(identical(other.overdueInvoicesCount, overdueInvoicesCount) || other.overdueInvoicesCount == overdueInvoicesCount)&&(identical(other.oldestOverdueDays, oldestOverdueDays) || other.oldestOverdueDays == oldestOverdueDays)&&(identical(other.diasMaxFacturaPosterior, diasMaxFacturaPosterior) || other.diasMaxFacturaPosterior == diasMaxFacturaPosterior)&&(identical(other.tipoCliente, tipoCliente) || other.tipoCliente == tipoCliente)&&(identical(other.canalCliente, canalCliente) || other.canalCliente == canalCliente)&&(identical(other.customerRank, customerRank) || other.customerRank == customerRank)&&(identical(other.supplierRank, supplierRank) || other.supplierRank == supplierRank)&&(identical(other.aceptaCheques, aceptaCheques) || other.aceptaCheques == aceptaCheques)&&(identical(other.emitirFacturaFechaPosterior, emitirFacturaFechaPosterior) || other.emitirFacturaFechaPosterior == emitirFacturaFechaPosterior)&&(identical(other.noInvoice, noInvoice) || other.noInvoice == noInvoice)&&(identical(other.lastDayToInvoice, lastDayToInvoice) || other.lastDayToInvoice == lastDayToInvoice)&&(identical(other.externalId, externalId) || other.externalId == externalId)&&(identical(other.partnerLatitude, partnerLatitude) || other.partnerLatitude == partnerLatitude)&&(identical(other.partnerLongitude, partnerLongitude) || other.partnerLongitude == partnerLongitude)&&(identical(other.canUseCustomPayments, canUseCustomPayments) || other.canUseCustomPayments == canUseCustomPayments)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.creditLastSyncDate, creditLastSyncDate) || other.creditLastSyncDate == creditLastSyncDate));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,uuid,isSynced,name,displayName,ref,vat,email,phone,mobile,street,street2,city,zip,countryId,countryName,stateId,stateName,avatar128,isCompany,active,parentId,parentName,commercialPartnerName,propertyProductPricelistId,propertyProductPricelistName,propertyPaymentTermId,propertyPaymentTermName,lang,comment,creditLimit,credit,creditToInvoice,allowOverCredit,usePartnerCreditLimit,totalOverdue,overdueInvoicesCount,oldestOverdueDays,diasMaxFacturaPosterior,tipoCliente,canalCliente,customerRank,supplierRank,aceptaCheques,emitirFacturaFechaPosterior,noInvoice,lastDayToInvoice,externalId,partnerLatitude,partnerLongitude,canUseCustomPayments,writeDate,creditLastSyncDate]);

@override
String toString() {
  return 'Client(id: $id, uuid: $uuid, isSynced: $isSynced, name: $name, displayName: $displayName, ref: $ref, vat: $vat, email: $email, phone: $phone, mobile: $mobile, street: $street, street2: $street2, city: $city, zip: $zip, countryId: $countryId, countryName: $countryName, stateId: $stateId, stateName: $stateName, avatar128: $avatar128, isCompany: $isCompany, active: $active, parentId: $parentId, parentName: $parentName, commercialPartnerName: $commercialPartnerName, propertyProductPricelistId: $propertyProductPricelistId, propertyProductPricelistName: $propertyProductPricelistName, propertyPaymentTermId: $propertyPaymentTermId, propertyPaymentTermName: $propertyPaymentTermName, lang: $lang, comment: $comment, creditLimit: $creditLimit, credit: $credit, creditToInvoice: $creditToInvoice, allowOverCredit: $allowOverCredit, usePartnerCreditLimit: $usePartnerCreditLimit, totalOverdue: $totalOverdue, overdueInvoicesCount: $overdueInvoicesCount, oldestOverdueDays: $oldestOverdueDays, diasMaxFacturaPosterior: $diasMaxFacturaPosterior, tipoCliente: $tipoCliente, canalCliente: $canalCliente, customerRank: $customerRank, supplierRank: $supplierRank, aceptaCheques: $aceptaCheques, emitirFacturaFechaPosterior: $emitirFacturaFechaPosterior, noInvoice: $noInvoice, lastDayToInvoice: $lastDayToInvoice, externalId: $externalId, partnerLatitude: $partnerLatitude, partnerLongitude: $partnerLongitude, canUseCustomPayments: $canUseCustomPayments, writeDate: $writeDate, creditLastSyncDate: $creditLastSyncDate)';
}


}

/// @nodoc
abstract mixin class $ClientCopyWith<$Res>  {
  factory $ClientCopyWith(Client value, $Res Function(Client) _then) = _$ClientCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooLocalOnly() bool isSynced,@OdooString() String name,@OdooString(odooName: 'display_name') String? displayName,@OdooString() String? ref,@OdooString() String? vat,@OdooString() String? email,@OdooString() String? phone,@OdooString() String? mobile,@OdooString() String? street,@OdooString() String? street2,@OdooString() String? city,@OdooString() String? zip,@OdooMany2One('res.country', odooName: 'country_id') int? countryId,@OdooMany2OneName(sourceField: 'country_id') String? countryName,@OdooMany2One('res.country.state', odooName: 'state_id') int? stateId,@OdooMany2OneName(sourceField: 'state_id') String? stateName,@OdooString(odooName: 'avatar_128') String? avatar128,@OdooBoolean(odooName: 'is_company') bool isCompany,@OdooBoolean() bool active,@OdooMany2One('res.partner', odooName: 'parent_id') int? parentId,@OdooMany2OneName(sourceField: 'parent_id') String? parentName,@OdooMany2OneName(sourceField: 'commercial_partner_id') String? commercialPartnerName,@OdooMany2One('product.pricelist', odooName: 'property_product_pricelist') int? propertyProductPricelistId,@OdooMany2OneName(sourceField: 'property_product_pricelist') String? propertyProductPricelistName,@OdooMany2One('account.payment.term', odooName: 'property_payment_term_id') int? propertyPaymentTermId,@OdooMany2OneName(sourceField: 'property_payment_term_id') String? propertyPaymentTermName,@OdooString() String? lang,@OdooString() String? comment,@OdooFloat(odooName: 'credit_limit') double? creditLimit,@OdooFloat() double? credit,@OdooFloat(odooName: 'credit_to_invoice') double? creditToInvoice,@OdooBoolean(odooName: 'allow_over_credit') bool allowOverCredit,@OdooBoolean(odooName: 'use_partner_credit_limit') bool usePartnerCreditLimit,@OdooFloat(odooName: 'total_overdue') double? totalOverdue,@OdooInteger(odooName: 'unpaid_invoices_count') int? overdueInvoicesCount,@OdooInteger(odooName: 'oldest_overdue_days') int? oldestOverdueDays,@OdooInteger(odooName: 'dias_max_factura_posterior') int? diasMaxFacturaPosterior,@OdooSelection(odooName: 'tipo_cliente') String? tipoCliente,@OdooSelection(odooName: 'canal_cliente') String? canalCliente,@OdooInteger(odooName: 'customer_rank') int? customerRank,@OdooInteger(odooName: 'supplier_rank') int? supplierRank,@OdooBoolean(odooName: 'acepta_cheques') bool aceptaCheques,@OdooBoolean(odooName: 'emitir_factura_fecha_posterior') bool emitirFacturaFechaPosterior,@OdooBoolean(odooName: 'no_invoice') bool noInvoice,@OdooInteger(odooName: 'last_day_to_invoice') int? lastDayToInvoice,@OdooString(odooName: 'external_id') String? externalId,@OdooFloat(odooName: 'partner_latitude') double? partnerLatitude,@OdooFloat(odooName: 'partner_longitude') double? partnerLongitude,@OdooBoolean(odooName: 'can_use_custom_payments') bool canUseCustomPayments,@OdooDateTime(odooName: 'write_date') DateTime? writeDate,@OdooLocalOnly() DateTime? creditLastSyncDate
});




}
/// @nodoc
class _$ClientCopyWithImpl<$Res>
    implements $ClientCopyWith<$Res> {
  _$ClientCopyWithImpl(this._self, this._then);

  final Client _self;
  final $Res Function(Client) _then;

/// Create a copy of Client
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uuid = freezed,Object? isSynced = null,Object? name = null,Object? displayName = freezed,Object? ref = freezed,Object? vat = freezed,Object? email = freezed,Object? phone = freezed,Object? mobile = freezed,Object? street = freezed,Object? street2 = freezed,Object? city = freezed,Object? zip = freezed,Object? countryId = freezed,Object? countryName = freezed,Object? stateId = freezed,Object? stateName = freezed,Object? avatar128 = freezed,Object? isCompany = null,Object? active = null,Object? parentId = freezed,Object? parentName = freezed,Object? commercialPartnerName = freezed,Object? propertyProductPricelistId = freezed,Object? propertyProductPricelistName = freezed,Object? propertyPaymentTermId = freezed,Object? propertyPaymentTermName = freezed,Object? lang = freezed,Object? comment = freezed,Object? creditLimit = freezed,Object? credit = freezed,Object? creditToInvoice = freezed,Object? allowOverCredit = null,Object? usePartnerCreditLimit = null,Object? totalOverdue = freezed,Object? overdueInvoicesCount = freezed,Object? oldestOverdueDays = freezed,Object? diasMaxFacturaPosterior = freezed,Object? tipoCliente = freezed,Object? canalCliente = freezed,Object? customerRank = freezed,Object? supplierRank = freezed,Object? aceptaCheques = null,Object? emitirFacturaFechaPosterior = null,Object? noInvoice = null,Object? lastDayToInvoice = freezed,Object? externalId = freezed,Object? partnerLatitude = freezed,Object? partnerLongitude = freezed,Object? canUseCustomPayments = null,Object? writeDate = freezed,Object? creditLastSyncDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,ref: freezed == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String?,vat: freezed == vat ? _self.vat : vat // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,street: freezed == street ? _self.street : street // ignore: cast_nullable_to_non_nullable
as String?,street2: freezed == street2 ? _self.street2 : street2 // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,zip: freezed == zip ? _self.zip : zip // ignore: cast_nullable_to_non_nullable
as String?,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as int?,countryName: freezed == countryName ? _self.countryName : countryName // ignore: cast_nullable_to_non_nullable
as String?,stateId: freezed == stateId ? _self.stateId : stateId // ignore: cast_nullable_to_non_nullable
as int?,stateName: freezed == stateName ? _self.stateName : stateName // ignore: cast_nullable_to_non_nullable
as String?,avatar128: freezed == avatar128 ? _self.avatar128 : avatar128 // ignore: cast_nullable_to_non_nullable
as String?,isCompany: null == isCompany ? _self.isCompany : isCompany // ignore: cast_nullable_to_non_nullable
as bool,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as int?,parentName: freezed == parentName ? _self.parentName : parentName // ignore: cast_nullable_to_non_nullable
as String?,commercialPartnerName: freezed == commercialPartnerName ? _self.commercialPartnerName : commercialPartnerName // ignore: cast_nullable_to_non_nullable
as String?,propertyProductPricelistId: freezed == propertyProductPricelistId ? _self.propertyProductPricelistId : propertyProductPricelistId // ignore: cast_nullable_to_non_nullable
as int?,propertyProductPricelistName: freezed == propertyProductPricelistName ? _self.propertyProductPricelistName : propertyProductPricelistName // ignore: cast_nullable_to_non_nullable
as String?,propertyPaymentTermId: freezed == propertyPaymentTermId ? _self.propertyPaymentTermId : propertyPaymentTermId // ignore: cast_nullable_to_non_nullable
as int?,propertyPaymentTermName: freezed == propertyPaymentTermName ? _self.propertyPaymentTermName : propertyPaymentTermName // ignore: cast_nullable_to_non_nullable
as String?,lang: freezed == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String?,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,creditLimit: freezed == creditLimit ? _self.creditLimit : creditLimit // ignore: cast_nullable_to_non_nullable
as double?,credit: freezed == credit ? _self.credit : credit // ignore: cast_nullable_to_non_nullable
as double?,creditToInvoice: freezed == creditToInvoice ? _self.creditToInvoice : creditToInvoice // ignore: cast_nullable_to_non_nullable
as double?,allowOverCredit: null == allowOverCredit ? _self.allowOverCredit : allowOverCredit // ignore: cast_nullable_to_non_nullable
as bool,usePartnerCreditLimit: null == usePartnerCreditLimit ? _self.usePartnerCreditLimit : usePartnerCreditLimit // ignore: cast_nullable_to_non_nullable
as bool,totalOverdue: freezed == totalOverdue ? _self.totalOverdue : totalOverdue // ignore: cast_nullable_to_non_nullable
as double?,overdueInvoicesCount: freezed == overdueInvoicesCount ? _self.overdueInvoicesCount : overdueInvoicesCount // ignore: cast_nullable_to_non_nullable
as int?,oldestOverdueDays: freezed == oldestOverdueDays ? _self.oldestOverdueDays : oldestOverdueDays // ignore: cast_nullable_to_non_nullable
as int?,diasMaxFacturaPosterior: freezed == diasMaxFacturaPosterior ? _self.diasMaxFacturaPosterior : diasMaxFacturaPosterior // ignore: cast_nullable_to_non_nullable
as int?,tipoCliente: freezed == tipoCliente ? _self.tipoCliente : tipoCliente // ignore: cast_nullable_to_non_nullable
as String?,canalCliente: freezed == canalCliente ? _self.canalCliente : canalCliente // ignore: cast_nullable_to_non_nullable
as String?,customerRank: freezed == customerRank ? _self.customerRank : customerRank // ignore: cast_nullable_to_non_nullable
as int?,supplierRank: freezed == supplierRank ? _self.supplierRank : supplierRank // ignore: cast_nullable_to_non_nullable
as int?,aceptaCheques: null == aceptaCheques ? _self.aceptaCheques : aceptaCheques // ignore: cast_nullable_to_non_nullable
as bool,emitirFacturaFechaPosterior: null == emitirFacturaFechaPosterior ? _self.emitirFacturaFechaPosterior : emitirFacturaFechaPosterior // ignore: cast_nullable_to_non_nullable
as bool,noInvoice: null == noInvoice ? _self.noInvoice : noInvoice // ignore: cast_nullable_to_non_nullable
as bool,lastDayToInvoice: freezed == lastDayToInvoice ? _self.lastDayToInvoice : lastDayToInvoice // ignore: cast_nullable_to_non_nullable
as int?,externalId: freezed == externalId ? _self.externalId : externalId // ignore: cast_nullable_to_non_nullable
as String?,partnerLatitude: freezed == partnerLatitude ? _self.partnerLatitude : partnerLatitude // ignore: cast_nullable_to_non_nullable
as double?,partnerLongitude: freezed == partnerLongitude ? _self.partnerLongitude : partnerLongitude // ignore: cast_nullable_to_non_nullable
as double?,canUseCustomPayments: null == canUseCustomPayments ? _self.canUseCustomPayments : canUseCustomPayments // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,creditLastSyncDate: freezed == creditLastSyncDate ? _self.creditLastSyncDate : creditLastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Client].
extension ClientPatterns on Client {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Client value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Client() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Client value)  $default,){
final _that = this;
switch (_that) {
case _Client():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Client value)?  $default,){
final _that = this;
switch (_that) {
case _Client() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooString()  String name, @OdooString(odooName: 'display_name')  String? displayName, @OdooString()  String? ref, @OdooString()  String? vat, @OdooString()  String? email, @OdooString()  String? phone, @OdooString()  String? mobile, @OdooString()  String? street, @OdooString()  String? street2, @OdooString()  String? city, @OdooString()  String? zip, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooMany2One('res.country.state', odooName: 'state_id')  int? stateId, @OdooMany2OneName(sourceField: 'state_id')  String? stateName, @OdooString(odooName: 'avatar_128')  String? avatar128, @OdooBoolean(odooName: 'is_company')  bool isCompany, @OdooBoolean()  bool active, @OdooMany2One('res.partner', odooName: 'parent_id')  int? parentId, @OdooMany2OneName(sourceField: 'parent_id')  String? parentName, @OdooMany2OneName(sourceField: 'commercial_partner_id')  String? commercialPartnerName, @OdooMany2One('product.pricelist', odooName: 'property_product_pricelist')  int? propertyProductPricelistId, @OdooMany2OneName(sourceField: 'property_product_pricelist')  String? propertyProductPricelistName, @OdooMany2One('account.payment.term', odooName: 'property_payment_term_id')  int? propertyPaymentTermId, @OdooMany2OneName(sourceField: 'property_payment_term_id')  String? propertyPaymentTermName, @OdooString()  String? lang, @OdooString()  String? comment, @OdooFloat(odooName: 'credit_limit')  double? creditLimit, @OdooFloat()  double? credit, @OdooFloat(odooName: 'credit_to_invoice')  double? creditToInvoice, @OdooBoolean(odooName: 'allow_over_credit')  bool allowOverCredit, @OdooBoolean(odooName: 'use_partner_credit_limit')  bool usePartnerCreditLimit, @OdooFloat(odooName: 'total_overdue')  double? totalOverdue, @OdooInteger(odooName: 'unpaid_invoices_count')  int? overdueInvoicesCount, @OdooInteger(odooName: 'oldest_overdue_days')  int? oldestOverdueDays, @OdooInteger(odooName: 'dias_max_factura_posterior')  int? diasMaxFacturaPosterior, @OdooSelection(odooName: 'tipo_cliente')  String? tipoCliente, @OdooSelection(odooName: 'canal_cliente')  String? canalCliente, @OdooInteger(odooName: 'customer_rank')  int? customerRank, @OdooInteger(odooName: 'supplier_rank')  int? supplierRank, @OdooBoolean(odooName: 'acepta_cheques')  bool aceptaCheques, @OdooBoolean(odooName: 'emitir_factura_fecha_posterior')  bool emitirFacturaFechaPosterior, @OdooBoolean(odooName: 'no_invoice')  bool noInvoice, @OdooInteger(odooName: 'last_day_to_invoice')  int? lastDayToInvoice, @OdooString(odooName: 'external_id')  String? externalId, @OdooFloat(odooName: 'partner_latitude')  double? partnerLatitude, @OdooFloat(odooName: 'partner_longitude')  double? partnerLongitude, @OdooBoolean(odooName: 'can_use_custom_payments')  bool canUseCustomPayments, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooLocalOnly()  DateTime? creditLastSyncDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Client() when $default != null:
return $default(_that.id,_that.uuid,_that.isSynced,_that.name,_that.displayName,_that.ref,_that.vat,_that.email,_that.phone,_that.mobile,_that.street,_that.street2,_that.city,_that.zip,_that.countryId,_that.countryName,_that.stateId,_that.stateName,_that.avatar128,_that.isCompany,_that.active,_that.parentId,_that.parentName,_that.commercialPartnerName,_that.propertyProductPricelistId,_that.propertyProductPricelistName,_that.propertyPaymentTermId,_that.propertyPaymentTermName,_that.lang,_that.comment,_that.creditLimit,_that.credit,_that.creditToInvoice,_that.allowOverCredit,_that.usePartnerCreditLimit,_that.totalOverdue,_that.overdueInvoicesCount,_that.oldestOverdueDays,_that.diasMaxFacturaPosterior,_that.tipoCliente,_that.canalCliente,_that.customerRank,_that.supplierRank,_that.aceptaCheques,_that.emitirFacturaFechaPosterior,_that.noInvoice,_that.lastDayToInvoice,_that.externalId,_that.partnerLatitude,_that.partnerLongitude,_that.canUseCustomPayments,_that.writeDate,_that.creditLastSyncDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooString()  String name, @OdooString(odooName: 'display_name')  String? displayName, @OdooString()  String? ref, @OdooString()  String? vat, @OdooString()  String? email, @OdooString()  String? phone, @OdooString()  String? mobile, @OdooString()  String? street, @OdooString()  String? street2, @OdooString()  String? city, @OdooString()  String? zip, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooMany2One('res.country.state', odooName: 'state_id')  int? stateId, @OdooMany2OneName(sourceField: 'state_id')  String? stateName, @OdooString(odooName: 'avatar_128')  String? avatar128, @OdooBoolean(odooName: 'is_company')  bool isCompany, @OdooBoolean()  bool active, @OdooMany2One('res.partner', odooName: 'parent_id')  int? parentId, @OdooMany2OneName(sourceField: 'parent_id')  String? parentName, @OdooMany2OneName(sourceField: 'commercial_partner_id')  String? commercialPartnerName, @OdooMany2One('product.pricelist', odooName: 'property_product_pricelist')  int? propertyProductPricelistId, @OdooMany2OneName(sourceField: 'property_product_pricelist')  String? propertyProductPricelistName, @OdooMany2One('account.payment.term', odooName: 'property_payment_term_id')  int? propertyPaymentTermId, @OdooMany2OneName(sourceField: 'property_payment_term_id')  String? propertyPaymentTermName, @OdooString()  String? lang, @OdooString()  String? comment, @OdooFloat(odooName: 'credit_limit')  double? creditLimit, @OdooFloat()  double? credit, @OdooFloat(odooName: 'credit_to_invoice')  double? creditToInvoice, @OdooBoolean(odooName: 'allow_over_credit')  bool allowOverCredit, @OdooBoolean(odooName: 'use_partner_credit_limit')  bool usePartnerCreditLimit, @OdooFloat(odooName: 'total_overdue')  double? totalOverdue, @OdooInteger(odooName: 'unpaid_invoices_count')  int? overdueInvoicesCount, @OdooInteger(odooName: 'oldest_overdue_days')  int? oldestOverdueDays, @OdooInteger(odooName: 'dias_max_factura_posterior')  int? diasMaxFacturaPosterior, @OdooSelection(odooName: 'tipo_cliente')  String? tipoCliente, @OdooSelection(odooName: 'canal_cliente')  String? canalCliente, @OdooInteger(odooName: 'customer_rank')  int? customerRank, @OdooInteger(odooName: 'supplier_rank')  int? supplierRank, @OdooBoolean(odooName: 'acepta_cheques')  bool aceptaCheques, @OdooBoolean(odooName: 'emitir_factura_fecha_posterior')  bool emitirFacturaFechaPosterior, @OdooBoolean(odooName: 'no_invoice')  bool noInvoice, @OdooInteger(odooName: 'last_day_to_invoice')  int? lastDayToInvoice, @OdooString(odooName: 'external_id')  String? externalId, @OdooFloat(odooName: 'partner_latitude')  double? partnerLatitude, @OdooFloat(odooName: 'partner_longitude')  double? partnerLongitude, @OdooBoolean(odooName: 'can_use_custom_payments')  bool canUseCustomPayments, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooLocalOnly()  DateTime? creditLastSyncDate)  $default,) {final _that = this;
switch (_that) {
case _Client():
return $default(_that.id,_that.uuid,_that.isSynced,_that.name,_that.displayName,_that.ref,_that.vat,_that.email,_that.phone,_that.mobile,_that.street,_that.street2,_that.city,_that.zip,_that.countryId,_that.countryName,_that.stateId,_that.stateName,_that.avatar128,_that.isCompany,_that.active,_that.parentId,_that.parentName,_that.commercialPartnerName,_that.propertyProductPricelistId,_that.propertyProductPricelistName,_that.propertyPaymentTermId,_that.propertyPaymentTermName,_that.lang,_that.comment,_that.creditLimit,_that.credit,_that.creditToInvoice,_that.allowOverCredit,_that.usePartnerCreditLimit,_that.totalOverdue,_that.overdueInvoicesCount,_that.oldestOverdueDays,_that.diasMaxFacturaPosterior,_that.tipoCliente,_that.canalCliente,_that.customerRank,_that.supplierRank,_that.aceptaCheques,_that.emitirFacturaFechaPosterior,_that.noInvoice,_that.lastDayToInvoice,_that.externalId,_that.partnerLatitude,_that.partnerLongitude,_that.canUseCustomPayments,_that.writeDate,_that.creditLastSyncDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooString()  String name, @OdooString(odooName: 'display_name')  String? displayName, @OdooString()  String? ref, @OdooString()  String? vat, @OdooString()  String? email, @OdooString()  String? phone, @OdooString()  String? mobile, @OdooString()  String? street, @OdooString()  String? street2, @OdooString()  String? city, @OdooString()  String? zip, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooMany2One('res.country.state', odooName: 'state_id')  int? stateId, @OdooMany2OneName(sourceField: 'state_id')  String? stateName, @OdooString(odooName: 'avatar_128')  String? avatar128, @OdooBoolean(odooName: 'is_company')  bool isCompany, @OdooBoolean()  bool active, @OdooMany2One('res.partner', odooName: 'parent_id')  int? parentId, @OdooMany2OneName(sourceField: 'parent_id')  String? parentName, @OdooMany2OneName(sourceField: 'commercial_partner_id')  String? commercialPartnerName, @OdooMany2One('product.pricelist', odooName: 'property_product_pricelist')  int? propertyProductPricelistId, @OdooMany2OneName(sourceField: 'property_product_pricelist')  String? propertyProductPricelistName, @OdooMany2One('account.payment.term', odooName: 'property_payment_term_id')  int? propertyPaymentTermId, @OdooMany2OneName(sourceField: 'property_payment_term_id')  String? propertyPaymentTermName, @OdooString()  String? lang, @OdooString()  String? comment, @OdooFloat(odooName: 'credit_limit')  double? creditLimit, @OdooFloat()  double? credit, @OdooFloat(odooName: 'credit_to_invoice')  double? creditToInvoice, @OdooBoolean(odooName: 'allow_over_credit')  bool allowOverCredit, @OdooBoolean(odooName: 'use_partner_credit_limit')  bool usePartnerCreditLimit, @OdooFloat(odooName: 'total_overdue')  double? totalOverdue, @OdooInteger(odooName: 'unpaid_invoices_count')  int? overdueInvoicesCount, @OdooInteger(odooName: 'oldest_overdue_days')  int? oldestOverdueDays, @OdooInteger(odooName: 'dias_max_factura_posterior')  int? diasMaxFacturaPosterior, @OdooSelection(odooName: 'tipo_cliente')  String? tipoCliente, @OdooSelection(odooName: 'canal_cliente')  String? canalCliente, @OdooInteger(odooName: 'customer_rank')  int? customerRank, @OdooInteger(odooName: 'supplier_rank')  int? supplierRank, @OdooBoolean(odooName: 'acepta_cheques')  bool aceptaCheques, @OdooBoolean(odooName: 'emitir_factura_fecha_posterior')  bool emitirFacturaFechaPosterior, @OdooBoolean(odooName: 'no_invoice')  bool noInvoice, @OdooInteger(odooName: 'last_day_to_invoice')  int? lastDayToInvoice, @OdooString(odooName: 'external_id')  String? externalId, @OdooFloat(odooName: 'partner_latitude')  double? partnerLatitude, @OdooFloat(odooName: 'partner_longitude')  double? partnerLongitude, @OdooBoolean(odooName: 'can_use_custom_payments')  bool canUseCustomPayments, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooLocalOnly()  DateTime? creditLastSyncDate)?  $default,) {final _that = this;
switch (_that) {
case _Client() when $default != null:
return $default(_that.id,_that.uuid,_that.isSynced,_that.name,_that.displayName,_that.ref,_that.vat,_that.email,_that.phone,_that.mobile,_that.street,_that.street2,_that.city,_that.zip,_that.countryId,_that.countryName,_that.stateId,_that.stateName,_that.avatar128,_that.isCompany,_that.active,_that.parentId,_that.parentName,_that.commercialPartnerName,_that.propertyProductPricelistId,_that.propertyProductPricelistName,_that.propertyPaymentTermId,_that.propertyPaymentTermName,_that.lang,_that.comment,_that.creditLimit,_that.credit,_that.creditToInvoice,_that.allowOverCredit,_that.usePartnerCreditLimit,_that.totalOverdue,_that.overdueInvoicesCount,_that.oldestOverdueDays,_that.diasMaxFacturaPosterior,_that.tipoCliente,_that.canalCliente,_that.customerRank,_that.supplierRank,_that.aceptaCheques,_that.emitirFacturaFechaPosterior,_that.noInvoice,_that.lastDayToInvoice,_that.externalId,_that.partnerLatitude,_that.partnerLongitude,_that.canUseCustomPayments,_that.writeDate,_that.creditLastSyncDate);case _:
  return null;

}
}

}

/// @nodoc


class _Client extends Client {
  const _Client({@OdooId() required this.id, @OdooLocalOnly() this.uuid, @OdooLocalOnly() this.isSynced = true, @OdooString() required this.name, @OdooString(odooName: 'display_name') this.displayName, @OdooString() this.ref, @OdooString() this.vat, @OdooString() this.email, @OdooString() this.phone, @OdooString() this.mobile, @OdooString() this.street, @OdooString() this.street2, @OdooString() this.city, @OdooString() this.zip, @OdooMany2One('res.country', odooName: 'country_id') this.countryId, @OdooMany2OneName(sourceField: 'country_id') this.countryName, @OdooMany2One('res.country.state', odooName: 'state_id') this.stateId, @OdooMany2OneName(sourceField: 'state_id') this.stateName, @OdooString(odooName: 'avatar_128') this.avatar128, @OdooBoolean(odooName: 'is_company') this.isCompany = false, @OdooBoolean() this.active = true, @OdooMany2One('res.partner', odooName: 'parent_id') this.parentId, @OdooMany2OneName(sourceField: 'parent_id') this.parentName, @OdooMany2OneName(sourceField: 'commercial_partner_id') this.commercialPartnerName, @OdooMany2One('product.pricelist', odooName: 'property_product_pricelist') this.propertyProductPricelistId, @OdooMany2OneName(sourceField: 'property_product_pricelist') this.propertyProductPricelistName, @OdooMany2One('account.payment.term', odooName: 'property_payment_term_id') this.propertyPaymentTermId, @OdooMany2OneName(sourceField: 'property_payment_term_id') this.propertyPaymentTermName, @OdooString() this.lang, @OdooString() this.comment, @OdooFloat(odooName: 'credit_limit') this.creditLimit, @OdooFloat() this.credit, @OdooFloat(odooName: 'credit_to_invoice') this.creditToInvoice, @OdooBoolean(odooName: 'allow_over_credit') this.allowOverCredit = false, @OdooBoolean(odooName: 'use_partner_credit_limit') this.usePartnerCreditLimit = false, @OdooFloat(odooName: 'total_overdue') this.totalOverdue, @OdooInteger(odooName: 'unpaid_invoices_count') this.overdueInvoicesCount, @OdooInteger(odooName: 'oldest_overdue_days') this.oldestOverdueDays, @OdooInteger(odooName: 'dias_max_factura_posterior') this.diasMaxFacturaPosterior, @OdooSelection(odooName: 'tipo_cliente') this.tipoCliente, @OdooSelection(odooName: 'canal_cliente') this.canalCliente, @OdooInteger(odooName: 'customer_rank') this.customerRank, @OdooInteger(odooName: 'supplier_rank') this.supplierRank, @OdooBoolean(odooName: 'acepta_cheques') this.aceptaCheques = true, @OdooBoolean(odooName: 'emitir_factura_fecha_posterior') this.emitirFacturaFechaPosterior = false, @OdooBoolean(odooName: 'no_invoice') this.noInvoice = false, @OdooInteger(odooName: 'last_day_to_invoice') this.lastDayToInvoice, @OdooString(odooName: 'external_id') this.externalId, @OdooFloat(odooName: 'partner_latitude') this.partnerLatitude, @OdooFloat(odooName: 'partner_longitude') this.partnerLongitude, @OdooBoolean(odooName: 'can_use_custom_payments') this.canUseCustomPayments = true, @OdooDateTime(odooName: 'write_date') this.writeDate, @OdooLocalOnly() this.creditLastSyncDate}): super._();
  

// ============ Identifiers ============
@override@OdooId() final  int id;
@override@OdooLocalOnly() final  String? uuid;
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
// ============ Basic Data ============
@override@OdooString() final  String name;
@override@OdooString(odooName: 'display_name') final  String? displayName;
@override@OdooString() final  String? ref;
@override@OdooString() final  String? vat;
@override@OdooString() final  String? email;
@override@OdooString() final  String? phone;
@override@OdooString() final  String? mobile;
@override@OdooString() final  String? street;
@override@OdooString() final  String? street2;
@override@OdooString() final  String? city;
@override@OdooString() final  String? zip;
@override@OdooMany2One('res.country', odooName: 'country_id') final  int? countryId;
@override@OdooMany2OneName(sourceField: 'country_id') final  String? countryName;
@override@OdooMany2One('res.country.state', odooName: 'state_id') final  int? stateId;
@override@OdooMany2OneName(sourceField: 'state_id') final  String? stateName;
@override@OdooString(odooName: 'avatar_128') final  String? avatar128;
@override@JsonKey()@OdooBoolean(odooName: 'is_company') final  bool isCompany;
@override@JsonKey()@OdooBoolean() final  bool active;
// ============ Relations ============
@override@OdooMany2One('res.partner', odooName: 'parent_id') final  int? parentId;
@override@OdooMany2OneName(sourceField: 'parent_id') final  String? parentName;
@override@OdooMany2OneName(sourceField: 'commercial_partner_id') final  String? commercialPartnerName;
@override@OdooMany2One('product.pricelist', odooName: 'property_product_pricelist') final  int? propertyProductPricelistId;
@override@OdooMany2OneName(sourceField: 'property_product_pricelist') final  String? propertyProductPricelistName;
@override@OdooMany2One('account.payment.term', odooName: 'property_payment_term_id') final  int? propertyPaymentTermId;
@override@OdooMany2OneName(sourceField: 'property_payment_term_id') final  String? propertyPaymentTermName;
@override@OdooString() final  String? lang;
@override@OdooString() final  String? comment;
// ============ Credit Control Fields (l10n_ec_sale_credit) ============
@override@OdooFloat(odooName: 'credit_limit') final  double? creditLimit;
@override@OdooFloat() final  double? credit;
@override@OdooFloat(odooName: 'credit_to_invoice') final  double? creditToInvoice;
@override@JsonKey()@OdooBoolean(odooName: 'allow_over_credit') final  bool allowOverCredit;
@override@JsonKey()@OdooBoolean(odooName: 'use_partner_credit_limit') final  bool usePartnerCreditLimit;
// ============ Overdue Debt Fields ============
@override@OdooFloat(odooName: 'total_overdue') final  double? totalOverdue;
@override@OdooInteger(odooName: 'unpaid_invoices_count') final  int? overdueInvoicesCount;
@override@OdooInteger(odooName: 'oldest_overdue_days') final  int? oldestOverdueDays;
// ============ Ecuador Fields ============
@override@OdooInteger(odooName: 'dias_max_factura_posterior') final  int? diasMaxFacturaPosterior;
// ============ Customer Classification (l10n_ec_sale_base) ============
@override@OdooSelection(odooName: 'tipo_cliente') final  String? tipoCliente;
@override@OdooSelection(odooName: 'canal_cliente') final  String? canalCliente;
// ============ Ranking ============
@override@OdooInteger(odooName: 'customer_rank') final  int? customerRank;
@override@OdooInteger(odooName: 'supplier_rank') final  int? supplierRank;
// ============ Check Acceptance ============
@override@JsonKey()@OdooBoolean(odooName: 'acepta_cheques') final  bool aceptaCheques;
// ============ Invoice Configuration ============
@override@JsonKey()@OdooBoolean(odooName: 'emitir_factura_fecha_posterior') final  bool emitirFacturaFechaPosterior;
@override@JsonKey()@OdooBoolean(odooName: 'no_invoice') final  bool noInvoice;
@override@OdooInteger(odooName: 'last_day_to_invoice') final  int? lastDayToInvoice;
// ============ External ID ============
@override@OdooString(odooName: 'external_id') final  String? externalId;
// ============ Geolocation ============
@override@OdooFloat(odooName: 'partner_latitude') final  double? partnerLatitude;
@override@OdooFloat(odooName: 'partner_longitude') final  double? partnerLongitude;
// ============ Custom Payments ============
@override@JsonKey()@OdooBoolean(odooName: 'can_use_custom_payments') final  bool canUseCustomPayments;
// ============ Metadata ============
@override@OdooDateTime(odooName: 'write_date') final  DateTime? writeDate;
@override@OdooLocalOnly() final  DateTime? creditLastSyncDate;

/// Create a copy of Client
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClientCopyWith<_Client> get copyWith => __$ClientCopyWithImpl<_Client>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Client&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.vat, vat) || other.vat == vat)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.mobile, mobile) || other.mobile == mobile)&&(identical(other.street, street) || other.street == street)&&(identical(other.street2, street2) || other.street2 == street2)&&(identical(other.city, city) || other.city == city)&&(identical(other.zip, zip) || other.zip == zip)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.countryName, countryName) || other.countryName == countryName)&&(identical(other.stateId, stateId) || other.stateId == stateId)&&(identical(other.stateName, stateName) || other.stateName == stateName)&&(identical(other.avatar128, avatar128) || other.avatar128 == avatar128)&&(identical(other.isCompany, isCompany) || other.isCompany == isCompany)&&(identical(other.active, active) || other.active == active)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.parentName, parentName) || other.parentName == parentName)&&(identical(other.commercialPartnerName, commercialPartnerName) || other.commercialPartnerName == commercialPartnerName)&&(identical(other.propertyProductPricelistId, propertyProductPricelistId) || other.propertyProductPricelistId == propertyProductPricelistId)&&(identical(other.propertyProductPricelistName, propertyProductPricelistName) || other.propertyProductPricelistName == propertyProductPricelistName)&&(identical(other.propertyPaymentTermId, propertyPaymentTermId) || other.propertyPaymentTermId == propertyPaymentTermId)&&(identical(other.propertyPaymentTermName, propertyPaymentTermName) || other.propertyPaymentTermName == propertyPaymentTermName)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.comment, comment) || other.comment == comment)&&(identical(other.creditLimit, creditLimit) || other.creditLimit == creditLimit)&&(identical(other.credit, credit) || other.credit == credit)&&(identical(other.creditToInvoice, creditToInvoice) || other.creditToInvoice == creditToInvoice)&&(identical(other.allowOverCredit, allowOverCredit) || other.allowOverCredit == allowOverCredit)&&(identical(other.usePartnerCreditLimit, usePartnerCreditLimit) || other.usePartnerCreditLimit == usePartnerCreditLimit)&&(identical(other.totalOverdue, totalOverdue) || other.totalOverdue == totalOverdue)&&(identical(other.overdueInvoicesCount, overdueInvoicesCount) || other.overdueInvoicesCount == overdueInvoicesCount)&&(identical(other.oldestOverdueDays, oldestOverdueDays) || other.oldestOverdueDays == oldestOverdueDays)&&(identical(other.diasMaxFacturaPosterior, diasMaxFacturaPosterior) || other.diasMaxFacturaPosterior == diasMaxFacturaPosterior)&&(identical(other.tipoCliente, tipoCliente) || other.tipoCliente == tipoCliente)&&(identical(other.canalCliente, canalCliente) || other.canalCliente == canalCliente)&&(identical(other.customerRank, customerRank) || other.customerRank == customerRank)&&(identical(other.supplierRank, supplierRank) || other.supplierRank == supplierRank)&&(identical(other.aceptaCheques, aceptaCheques) || other.aceptaCheques == aceptaCheques)&&(identical(other.emitirFacturaFechaPosterior, emitirFacturaFechaPosterior) || other.emitirFacturaFechaPosterior == emitirFacturaFechaPosterior)&&(identical(other.noInvoice, noInvoice) || other.noInvoice == noInvoice)&&(identical(other.lastDayToInvoice, lastDayToInvoice) || other.lastDayToInvoice == lastDayToInvoice)&&(identical(other.externalId, externalId) || other.externalId == externalId)&&(identical(other.partnerLatitude, partnerLatitude) || other.partnerLatitude == partnerLatitude)&&(identical(other.partnerLongitude, partnerLongitude) || other.partnerLongitude == partnerLongitude)&&(identical(other.canUseCustomPayments, canUseCustomPayments) || other.canUseCustomPayments == canUseCustomPayments)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.creditLastSyncDate, creditLastSyncDate) || other.creditLastSyncDate == creditLastSyncDate));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,uuid,isSynced,name,displayName,ref,vat,email,phone,mobile,street,street2,city,zip,countryId,countryName,stateId,stateName,avatar128,isCompany,active,parentId,parentName,commercialPartnerName,propertyProductPricelistId,propertyProductPricelistName,propertyPaymentTermId,propertyPaymentTermName,lang,comment,creditLimit,credit,creditToInvoice,allowOverCredit,usePartnerCreditLimit,totalOverdue,overdueInvoicesCount,oldestOverdueDays,diasMaxFacturaPosterior,tipoCliente,canalCliente,customerRank,supplierRank,aceptaCheques,emitirFacturaFechaPosterior,noInvoice,lastDayToInvoice,externalId,partnerLatitude,partnerLongitude,canUseCustomPayments,writeDate,creditLastSyncDate]);

@override
String toString() {
  return 'Client(id: $id, uuid: $uuid, isSynced: $isSynced, name: $name, displayName: $displayName, ref: $ref, vat: $vat, email: $email, phone: $phone, mobile: $mobile, street: $street, street2: $street2, city: $city, zip: $zip, countryId: $countryId, countryName: $countryName, stateId: $stateId, stateName: $stateName, avatar128: $avatar128, isCompany: $isCompany, active: $active, parentId: $parentId, parentName: $parentName, commercialPartnerName: $commercialPartnerName, propertyProductPricelistId: $propertyProductPricelistId, propertyProductPricelistName: $propertyProductPricelistName, propertyPaymentTermId: $propertyPaymentTermId, propertyPaymentTermName: $propertyPaymentTermName, lang: $lang, comment: $comment, creditLimit: $creditLimit, credit: $credit, creditToInvoice: $creditToInvoice, allowOverCredit: $allowOverCredit, usePartnerCreditLimit: $usePartnerCreditLimit, totalOverdue: $totalOverdue, overdueInvoicesCount: $overdueInvoicesCount, oldestOverdueDays: $oldestOverdueDays, diasMaxFacturaPosterior: $diasMaxFacturaPosterior, tipoCliente: $tipoCliente, canalCliente: $canalCliente, customerRank: $customerRank, supplierRank: $supplierRank, aceptaCheques: $aceptaCheques, emitirFacturaFechaPosterior: $emitirFacturaFechaPosterior, noInvoice: $noInvoice, lastDayToInvoice: $lastDayToInvoice, externalId: $externalId, partnerLatitude: $partnerLatitude, partnerLongitude: $partnerLongitude, canUseCustomPayments: $canUseCustomPayments, writeDate: $writeDate, creditLastSyncDate: $creditLastSyncDate)';
}


}

/// @nodoc
abstract mixin class _$ClientCopyWith<$Res> implements $ClientCopyWith<$Res> {
  factory _$ClientCopyWith(_Client value, $Res Function(_Client) _then) = __$ClientCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooLocalOnly() bool isSynced,@OdooString() String name,@OdooString(odooName: 'display_name') String? displayName,@OdooString() String? ref,@OdooString() String? vat,@OdooString() String? email,@OdooString() String? phone,@OdooString() String? mobile,@OdooString() String? street,@OdooString() String? street2,@OdooString() String? city,@OdooString() String? zip,@OdooMany2One('res.country', odooName: 'country_id') int? countryId,@OdooMany2OneName(sourceField: 'country_id') String? countryName,@OdooMany2One('res.country.state', odooName: 'state_id') int? stateId,@OdooMany2OneName(sourceField: 'state_id') String? stateName,@OdooString(odooName: 'avatar_128') String? avatar128,@OdooBoolean(odooName: 'is_company') bool isCompany,@OdooBoolean() bool active,@OdooMany2One('res.partner', odooName: 'parent_id') int? parentId,@OdooMany2OneName(sourceField: 'parent_id') String? parentName,@OdooMany2OneName(sourceField: 'commercial_partner_id') String? commercialPartnerName,@OdooMany2One('product.pricelist', odooName: 'property_product_pricelist') int? propertyProductPricelistId,@OdooMany2OneName(sourceField: 'property_product_pricelist') String? propertyProductPricelistName,@OdooMany2One('account.payment.term', odooName: 'property_payment_term_id') int? propertyPaymentTermId,@OdooMany2OneName(sourceField: 'property_payment_term_id') String? propertyPaymentTermName,@OdooString() String? lang,@OdooString() String? comment,@OdooFloat(odooName: 'credit_limit') double? creditLimit,@OdooFloat() double? credit,@OdooFloat(odooName: 'credit_to_invoice') double? creditToInvoice,@OdooBoolean(odooName: 'allow_over_credit') bool allowOverCredit,@OdooBoolean(odooName: 'use_partner_credit_limit') bool usePartnerCreditLimit,@OdooFloat(odooName: 'total_overdue') double? totalOverdue,@OdooInteger(odooName: 'unpaid_invoices_count') int? overdueInvoicesCount,@OdooInteger(odooName: 'oldest_overdue_days') int? oldestOverdueDays,@OdooInteger(odooName: 'dias_max_factura_posterior') int? diasMaxFacturaPosterior,@OdooSelection(odooName: 'tipo_cliente') String? tipoCliente,@OdooSelection(odooName: 'canal_cliente') String? canalCliente,@OdooInteger(odooName: 'customer_rank') int? customerRank,@OdooInteger(odooName: 'supplier_rank') int? supplierRank,@OdooBoolean(odooName: 'acepta_cheques') bool aceptaCheques,@OdooBoolean(odooName: 'emitir_factura_fecha_posterior') bool emitirFacturaFechaPosterior,@OdooBoolean(odooName: 'no_invoice') bool noInvoice,@OdooInteger(odooName: 'last_day_to_invoice') int? lastDayToInvoice,@OdooString(odooName: 'external_id') String? externalId,@OdooFloat(odooName: 'partner_latitude') double? partnerLatitude,@OdooFloat(odooName: 'partner_longitude') double? partnerLongitude,@OdooBoolean(odooName: 'can_use_custom_payments') bool canUseCustomPayments,@OdooDateTime(odooName: 'write_date') DateTime? writeDate,@OdooLocalOnly() DateTime? creditLastSyncDate
});




}
/// @nodoc
class __$ClientCopyWithImpl<$Res>
    implements _$ClientCopyWith<$Res> {
  __$ClientCopyWithImpl(this._self, this._then);

  final _Client _self;
  final $Res Function(_Client) _then;

/// Create a copy of Client
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uuid = freezed,Object? isSynced = null,Object? name = null,Object? displayName = freezed,Object? ref = freezed,Object? vat = freezed,Object? email = freezed,Object? phone = freezed,Object? mobile = freezed,Object? street = freezed,Object? street2 = freezed,Object? city = freezed,Object? zip = freezed,Object? countryId = freezed,Object? countryName = freezed,Object? stateId = freezed,Object? stateName = freezed,Object? avatar128 = freezed,Object? isCompany = null,Object? active = null,Object? parentId = freezed,Object? parentName = freezed,Object? commercialPartnerName = freezed,Object? propertyProductPricelistId = freezed,Object? propertyProductPricelistName = freezed,Object? propertyPaymentTermId = freezed,Object? propertyPaymentTermName = freezed,Object? lang = freezed,Object? comment = freezed,Object? creditLimit = freezed,Object? credit = freezed,Object? creditToInvoice = freezed,Object? allowOverCredit = null,Object? usePartnerCreditLimit = null,Object? totalOverdue = freezed,Object? overdueInvoicesCount = freezed,Object? oldestOverdueDays = freezed,Object? diasMaxFacturaPosterior = freezed,Object? tipoCliente = freezed,Object? canalCliente = freezed,Object? customerRank = freezed,Object? supplierRank = freezed,Object? aceptaCheques = null,Object? emitirFacturaFechaPosterior = null,Object? noInvoice = null,Object? lastDayToInvoice = freezed,Object? externalId = freezed,Object? partnerLatitude = freezed,Object? partnerLongitude = freezed,Object? canUseCustomPayments = null,Object? writeDate = freezed,Object? creditLastSyncDate = freezed,}) {
  return _then(_Client(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,ref: freezed == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String?,vat: freezed == vat ? _self.vat : vat // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,mobile: freezed == mobile ? _self.mobile : mobile // ignore: cast_nullable_to_non_nullable
as String?,street: freezed == street ? _self.street : street // ignore: cast_nullable_to_non_nullable
as String?,street2: freezed == street2 ? _self.street2 : street2 // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,zip: freezed == zip ? _self.zip : zip // ignore: cast_nullable_to_non_nullable
as String?,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as int?,countryName: freezed == countryName ? _self.countryName : countryName // ignore: cast_nullable_to_non_nullable
as String?,stateId: freezed == stateId ? _self.stateId : stateId // ignore: cast_nullable_to_non_nullable
as int?,stateName: freezed == stateName ? _self.stateName : stateName // ignore: cast_nullable_to_non_nullable
as String?,avatar128: freezed == avatar128 ? _self.avatar128 : avatar128 // ignore: cast_nullable_to_non_nullable
as String?,isCompany: null == isCompany ? _self.isCompany : isCompany // ignore: cast_nullable_to_non_nullable
as bool,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as int?,parentName: freezed == parentName ? _self.parentName : parentName // ignore: cast_nullable_to_non_nullable
as String?,commercialPartnerName: freezed == commercialPartnerName ? _self.commercialPartnerName : commercialPartnerName // ignore: cast_nullable_to_non_nullable
as String?,propertyProductPricelistId: freezed == propertyProductPricelistId ? _self.propertyProductPricelistId : propertyProductPricelistId // ignore: cast_nullable_to_non_nullable
as int?,propertyProductPricelistName: freezed == propertyProductPricelistName ? _self.propertyProductPricelistName : propertyProductPricelistName // ignore: cast_nullable_to_non_nullable
as String?,propertyPaymentTermId: freezed == propertyPaymentTermId ? _self.propertyPaymentTermId : propertyPaymentTermId // ignore: cast_nullable_to_non_nullable
as int?,propertyPaymentTermName: freezed == propertyPaymentTermName ? _self.propertyPaymentTermName : propertyPaymentTermName // ignore: cast_nullable_to_non_nullable
as String?,lang: freezed == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String?,comment: freezed == comment ? _self.comment : comment // ignore: cast_nullable_to_non_nullable
as String?,creditLimit: freezed == creditLimit ? _self.creditLimit : creditLimit // ignore: cast_nullable_to_non_nullable
as double?,credit: freezed == credit ? _self.credit : credit // ignore: cast_nullable_to_non_nullable
as double?,creditToInvoice: freezed == creditToInvoice ? _self.creditToInvoice : creditToInvoice // ignore: cast_nullable_to_non_nullable
as double?,allowOverCredit: null == allowOverCredit ? _self.allowOverCredit : allowOverCredit // ignore: cast_nullable_to_non_nullable
as bool,usePartnerCreditLimit: null == usePartnerCreditLimit ? _self.usePartnerCreditLimit : usePartnerCreditLimit // ignore: cast_nullable_to_non_nullable
as bool,totalOverdue: freezed == totalOverdue ? _self.totalOverdue : totalOverdue // ignore: cast_nullable_to_non_nullable
as double?,overdueInvoicesCount: freezed == overdueInvoicesCount ? _self.overdueInvoicesCount : overdueInvoicesCount // ignore: cast_nullable_to_non_nullable
as int?,oldestOverdueDays: freezed == oldestOverdueDays ? _self.oldestOverdueDays : oldestOverdueDays // ignore: cast_nullable_to_non_nullable
as int?,diasMaxFacturaPosterior: freezed == diasMaxFacturaPosterior ? _self.diasMaxFacturaPosterior : diasMaxFacturaPosterior // ignore: cast_nullable_to_non_nullable
as int?,tipoCliente: freezed == tipoCliente ? _self.tipoCliente : tipoCliente // ignore: cast_nullable_to_non_nullable
as String?,canalCliente: freezed == canalCliente ? _self.canalCliente : canalCliente // ignore: cast_nullable_to_non_nullable
as String?,customerRank: freezed == customerRank ? _self.customerRank : customerRank // ignore: cast_nullable_to_non_nullable
as int?,supplierRank: freezed == supplierRank ? _self.supplierRank : supplierRank // ignore: cast_nullable_to_non_nullable
as int?,aceptaCheques: null == aceptaCheques ? _self.aceptaCheques : aceptaCheques // ignore: cast_nullable_to_non_nullable
as bool,emitirFacturaFechaPosterior: null == emitirFacturaFechaPosterior ? _self.emitirFacturaFechaPosterior : emitirFacturaFechaPosterior // ignore: cast_nullable_to_non_nullable
as bool,noInvoice: null == noInvoice ? _self.noInvoice : noInvoice // ignore: cast_nullable_to_non_nullable
as bool,lastDayToInvoice: freezed == lastDayToInvoice ? _self.lastDayToInvoice : lastDayToInvoice // ignore: cast_nullable_to_non_nullable
as int?,externalId: freezed == externalId ? _self.externalId : externalId // ignore: cast_nullable_to_non_nullable
as String?,partnerLatitude: freezed == partnerLatitude ? _self.partnerLatitude : partnerLatitude // ignore: cast_nullable_to_non_nullable
as double?,partnerLongitude: freezed == partnerLongitude ? _self.partnerLongitude : partnerLongitude // ignore: cast_nullable_to_non_nullable
as double?,canUseCustomPayments: null == canUseCustomPayments ? _self.canUseCustomPayments : canUseCustomPayments // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,creditLastSyncDate: freezed == creditLastSyncDate ? _self.creditLastSyncDate : creditLastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
