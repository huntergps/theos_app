// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_move.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountMove {

// ============ Identifiers ============
@OdooId() int get id;// ============ Basic Data ============
@OdooString() String get name;@OdooSelection(odooName: 'move_type') String get moveType;// ============ Ecuador SRI Fields ============
@OdooString(odooName: 'l10n_ec_authorization_number') String? get l10nEcAuthorizationNumber;@OdooDateTime(odooName: 'l10n_ec_authorization_date') DateTime? get l10nEcAuthorizationDate;@OdooString(odooName: 'l10n_latam_document_number') String? get l10nLatamDocumentNumber;@OdooMany2One('l10n_latam.document.type', odooName: 'l10n_latam_document_type_id') int? get l10nLatamDocumentTypeId;@OdooMany2OneName(sourceField: 'l10n_latam_document_type_id') String? get l10nLatamDocumentTypeName;@OdooMany2OneName(sourceField: 'l10n_ec_sri_payment_id') String? get l10nEcSriPaymentName;// ============ State ============
@OdooSelection() String get state;@OdooSelection(odooName: 'payment_state') String? get paymentState;// ============ Dates ============
@OdooDate(odooName: 'invoice_date') DateTime? get invoiceDate;@OdooDate(odooName: 'invoice_date_due') DateTime? get invoiceDateDue;@OdooDate() DateTime? get date;// ============ Partner ============
@OdooMany2One('res.partner', odooName: 'partner_id') int? get partnerId;@OdooMany2OneName(sourceField: 'partner_id') String? get partnerName;@OdooLocalOnly() String? get partnerVat;@OdooLocalOnly() String? get partnerStreet;@OdooLocalOnly() String? get partnerCity;@OdooLocalOnly() String? get partnerPhone;@OdooLocalOnly() String? get partnerEmail;// ============ Journal ============
@OdooMany2One('account.journal', odooName: 'journal_id') int? get journalId;@OdooMany2OneName(sourceField: 'journal_id') String? get journalName;// ============ Amounts ============
@OdooFloat(odooName: 'amount_untaxed') double get amountUntaxed;@OdooFloat(odooName: 'amount_tax') double get amountTax;@OdooFloat(odooName: 'amount_total') double get amountTotal;@OdooFloat(odooName: 'amount_residual') double get amountResidual;// ============ Company and Currency ============
@OdooMany2One('res.company', odooName: 'company_id') int? get companyId;@OdooMany2One('res.currency', odooName: 'currency_id') int? get currencyId;@OdooMany2OneName(sourceField: 'currency_id') String? get currencySymbol;// ============ Origin and Reference ============
@OdooString(odooName: 'invoice_origin') String? get invoiceOrigin;@OdooString() String? get ref;@OdooLocalOnly() int? get saleOrderId;// ============ Invoice Lines ============
@OdooLocalOnly() List<AccountMoveLine> get lines;// ============ Sync ============
@OdooDateTime(odooName: 'write_date') DateTime? get writeDate;@OdooLocalOnly() DateTime? get lastSyncDate;
/// Create a copy of AccountMove
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountMoveCopyWith<AccountMove> get copyWith => _$AccountMoveCopyWithImpl<AccountMove>(this as AccountMove, _$identity);

  /// Serializes this AccountMove to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountMove&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.moveType, moveType) || other.moveType == moveType)&&(identical(other.l10nEcAuthorizationNumber, l10nEcAuthorizationNumber) || other.l10nEcAuthorizationNumber == l10nEcAuthorizationNumber)&&(identical(other.l10nEcAuthorizationDate, l10nEcAuthorizationDate) || other.l10nEcAuthorizationDate == l10nEcAuthorizationDate)&&(identical(other.l10nLatamDocumentNumber, l10nLatamDocumentNumber) || other.l10nLatamDocumentNumber == l10nLatamDocumentNumber)&&(identical(other.l10nLatamDocumentTypeId, l10nLatamDocumentTypeId) || other.l10nLatamDocumentTypeId == l10nLatamDocumentTypeId)&&(identical(other.l10nLatamDocumentTypeName, l10nLatamDocumentTypeName) || other.l10nLatamDocumentTypeName == l10nLatamDocumentTypeName)&&(identical(other.l10nEcSriPaymentName, l10nEcSriPaymentName) || other.l10nEcSriPaymentName == l10nEcSriPaymentName)&&(identical(other.state, state) || other.state == state)&&(identical(other.paymentState, paymentState) || other.paymentState == paymentState)&&(identical(other.invoiceDate, invoiceDate) || other.invoiceDate == invoiceDate)&&(identical(other.invoiceDateDue, invoiceDateDue) || other.invoiceDateDue == invoiceDateDue)&&(identical(other.date, date) || other.date == date)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.partnerVat, partnerVat) || other.partnerVat == partnerVat)&&(identical(other.partnerStreet, partnerStreet) || other.partnerStreet == partnerStreet)&&(identical(other.partnerCity, partnerCity) || other.partnerCity == partnerCity)&&(identical(other.partnerPhone, partnerPhone) || other.partnerPhone == partnerPhone)&&(identical(other.partnerEmail, partnerEmail) || other.partnerEmail == partnerEmail)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.amountUntaxed, amountUntaxed) || other.amountUntaxed == amountUntaxed)&&(identical(other.amountTax, amountTax) || other.amountTax == amountTax)&&(identical(other.amountTotal, amountTotal) || other.amountTotal == amountTotal)&&(identical(other.amountResidual, amountResidual) || other.amountResidual == amountResidual)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.currencySymbol, currencySymbol) || other.currencySymbol == currencySymbol)&&(identical(other.invoiceOrigin, invoiceOrigin) || other.invoiceOrigin == invoiceOrigin)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.saleOrderId, saleOrderId) || other.saleOrderId == saleOrderId)&&const DeepCollectionEquality().equals(other.lines, lines)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,moveType,l10nEcAuthorizationNumber,l10nEcAuthorizationDate,l10nLatamDocumentNumber,l10nLatamDocumentTypeId,l10nLatamDocumentTypeName,l10nEcSriPaymentName,state,paymentState,invoiceDate,invoiceDateDue,date,partnerId,partnerName,partnerVat,partnerStreet,partnerCity,partnerPhone,partnerEmail,journalId,journalName,amountUntaxed,amountTax,amountTotal,amountResidual,companyId,currencyId,currencySymbol,invoiceOrigin,ref,saleOrderId,const DeepCollectionEquality().hash(lines),writeDate,lastSyncDate]);

@override
String toString() {
  return 'AccountMove(id: $id, name: $name, moveType: $moveType, l10nEcAuthorizationNumber: $l10nEcAuthorizationNumber, l10nEcAuthorizationDate: $l10nEcAuthorizationDate, l10nLatamDocumentNumber: $l10nLatamDocumentNumber, l10nLatamDocumentTypeId: $l10nLatamDocumentTypeId, l10nLatamDocumentTypeName: $l10nLatamDocumentTypeName, l10nEcSriPaymentName: $l10nEcSriPaymentName, state: $state, paymentState: $paymentState, invoiceDate: $invoiceDate, invoiceDateDue: $invoiceDateDue, date: $date, partnerId: $partnerId, partnerName: $partnerName, partnerVat: $partnerVat, partnerStreet: $partnerStreet, partnerCity: $partnerCity, partnerPhone: $partnerPhone, partnerEmail: $partnerEmail, journalId: $journalId, journalName: $journalName, amountUntaxed: $amountUntaxed, amountTax: $amountTax, amountTotal: $amountTotal, amountResidual: $amountResidual, companyId: $companyId, currencyId: $currencyId, currencySymbol: $currencySymbol, invoiceOrigin: $invoiceOrigin, ref: $ref, saleOrderId: $saleOrderId, lines: $lines, writeDate: $writeDate, lastSyncDate: $lastSyncDate)';
}


}

/// @nodoc
abstract mixin class $AccountMoveCopyWith<$Res>  {
  factory $AccountMoveCopyWith(AccountMove value, $Res Function(AccountMove) _then) = _$AccountMoveCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooSelection(odooName: 'move_type') String moveType,@OdooString(odooName: 'l10n_ec_authorization_number') String? l10nEcAuthorizationNumber,@OdooDateTime(odooName: 'l10n_ec_authorization_date') DateTime? l10nEcAuthorizationDate,@OdooString(odooName: 'l10n_latam_document_number') String? l10nLatamDocumentNumber,@OdooMany2One('l10n_latam.document.type', odooName: 'l10n_latam_document_type_id') int? l10nLatamDocumentTypeId,@OdooMany2OneName(sourceField: 'l10n_latam_document_type_id') String? l10nLatamDocumentTypeName,@OdooMany2OneName(sourceField: 'l10n_ec_sri_payment_id') String? l10nEcSriPaymentName,@OdooSelection() String state,@OdooSelection(odooName: 'payment_state') String? paymentState,@OdooDate(odooName: 'invoice_date') DateTime? invoiceDate,@OdooDate(odooName: 'invoice_date_due') DateTime? invoiceDateDue,@OdooDate() DateTime? date,@OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooLocalOnly() String? partnerVat,@OdooLocalOnly() String? partnerStreet,@OdooLocalOnly() String? partnerCity,@OdooLocalOnly() String? partnerPhone,@OdooLocalOnly() String? partnerEmail,@OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooFloat(odooName: 'amount_untaxed') double amountUntaxed,@OdooFloat(odooName: 'amount_tax') double amountTax,@OdooFloat(odooName: 'amount_total') double amountTotal,@OdooFloat(odooName: 'amount_residual') double amountResidual,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,@OdooMany2OneName(sourceField: 'currency_id') String? currencySymbol,@OdooString(odooName: 'invoice_origin') String? invoiceOrigin,@OdooString() String? ref,@OdooLocalOnly() int? saleOrderId,@OdooLocalOnly() List<AccountMoveLine> lines,@OdooDateTime(odooName: 'write_date') DateTime? writeDate,@OdooLocalOnly() DateTime? lastSyncDate
});




}
/// @nodoc
class _$AccountMoveCopyWithImpl<$Res>
    implements $AccountMoveCopyWith<$Res> {
  _$AccountMoveCopyWithImpl(this._self, this._then);

  final AccountMove _self;
  final $Res Function(AccountMove) _then;

/// Create a copy of AccountMove
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? moveType = null,Object? l10nEcAuthorizationNumber = freezed,Object? l10nEcAuthorizationDate = freezed,Object? l10nLatamDocumentNumber = freezed,Object? l10nLatamDocumentTypeId = freezed,Object? l10nLatamDocumentTypeName = freezed,Object? l10nEcSriPaymentName = freezed,Object? state = null,Object? paymentState = freezed,Object? invoiceDate = freezed,Object? invoiceDateDue = freezed,Object? date = freezed,Object? partnerId = freezed,Object? partnerName = freezed,Object? partnerVat = freezed,Object? partnerStreet = freezed,Object? partnerCity = freezed,Object? partnerPhone = freezed,Object? partnerEmail = freezed,Object? journalId = freezed,Object? journalName = freezed,Object? amountUntaxed = null,Object? amountTax = null,Object? amountTotal = null,Object? amountResidual = null,Object? companyId = freezed,Object? currencyId = freezed,Object? currencySymbol = freezed,Object? invoiceOrigin = freezed,Object? ref = freezed,Object? saleOrderId = freezed,Object? lines = null,Object? writeDate = freezed,Object? lastSyncDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,moveType: null == moveType ? _self.moveType : moveType // ignore: cast_nullable_to_non_nullable
as String,l10nEcAuthorizationNumber: freezed == l10nEcAuthorizationNumber ? _self.l10nEcAuthorizationNumber : l10nEcAuthorizationNumber // ignore: cast_nullable_to_non_nullable
as String?,l10nEcAuthorizationDate: freezed == l10nEcAuthorizationDate ? _self.l10nEcAuthorizationDate : l10nEcAuthorizationDate // ignore: cast_nullable_to_non_nullable
as DateTime?,l10nLatamDocumentNumber: freezed == l10nLatamDocumentNumber ? _self.l10nLatamDocumentNumber : l10nLatamDocumentNumber // ignore: cast_nullable_to_non_nullable
as String?,l10nLatamDocumentTypeId: freezed == l10nLatamDocumentTypeId ? _self.l10nLatamDocumentTypeId : l10nLatamDocumentTypeId // ignore: cast_nullable_to_non_nullable
as int?,l10nLatamDocumentTypeName: freezed == l10nLatamDocumentTypeName ? _self.l10nLatamDocumentTypeName : l10nLatamDocumentTypeName // ignore: cast_nullable_to_non_nullable
as String?,l10nEcSriPaymentName: freezed == l10nEcSriPaymentName ? _self.l10nEcSriPaymentName : l10nEcSriPaymentName // ignore: cast_nullable_to_non_nullable
as String?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,paymentState: freezed == paymentState ? _self.paymentState : paymentState // ignore: cast_nullable_to_non_nullable
as String?,invoiceDate: freezed == invoiceDate ? _self.invoiceDate : invoiceDate // ignore: cast_nullable_to_non_nullable
as DateTime?,invoiceDateDue: freezed == invoiceDateDue ? _self.invoiceDateDue : invoiceDateDue // ignore: cast_nullable_to_non_nullable
as DateTime?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime?,partnerId: freezed == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int?,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,partnerVat: freezed == partnerVat ? _self.partnerVat : partnerVat // ignore: cast_nullable_to_non_nullable
as String?,partnerStreet: freezed == partnerStreet ? _self.partnerStreet : partnerStreet // ignore: cast_nullable_to_non_nullable
as String?,partnerCity: freezed == partnerCity ? _self.partnerCity : partnerCity // ignore: cast_nullable_to_non_nullable
as String?,partnerPhone: freezed == partnerPhone ? _self.partnerPhone : partnerPhone // ignore: cast_nullable_to_non_nullable
as String?,partnerEmail: freezed == partnerEmail ? _self.partnerEmail : partnerEmail // ignore: cast_nullable_to_non_nullable
as String?,journalId: freezed == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int?,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,amountUntaxed: null == amountUntaxed ? _self.amountUntaxed : amountUntaxed // ignore: cast_nullable_to_non_nullable
as double,amountTax: null == amountTax ? _self.amountTax : amountTax // ignore: cast_nullable_to_non_nullable
as double,amountTotal: null == amountTotal ? _self.amountTotal : amountTotal // ignore: cast_nullable_to_non_nullable
as double,amountResidual: null == amountResidual ? _self.amountResidual : amountResidual // ignore: cast_nullable_to_non_nullable
as double,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,currencyId: freezed == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as int?,currencySymbol: freezed == currencySymbol ? _self.currencySymbol : currencySymbol // ignore: cast_nullable_to_non_nullable
as String?,invoiceOrigin: freezed == invoiceOrigin ? _self.invoiceOrigin : invoiceOrigin // ignore: cast_nullable_to_non_nullable
as String?,ref: freezed == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String?,saleOrderId: freezed == saleOrderId ? _self.saleOrderId : saleOrderId // ignore: cast_nullable_to_non_nullable
as int?,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<AccountMoveLine>,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountMove].
extension AccountMovePatterns on AccountMove {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountMove value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountMove() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountMove value)  $default,){
final _that = this;
switch (_that) {
case _AccountMove():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountMove value)?  $default,){
final _that = this;
switch (_that) {
case _AccountMove() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooSelection(odooName: 'move_type')  String moveType, @OdooString(odooName: 'l10n_ec_authorization_number')  String? l10nEcAuthorizationNumber, @OdooDateTime(odooName: 'l10n_ec_authorization_date')  DateTime? l10nEcAuthorizationDate, @OdooString(odooName: 'l10n_latam_document_number')  String? l10nLatamDocumentNumber, @OdooMany2One('l10n_latam.document.type', odooName: 'l10n_latam_document_type_id')  int? l10nLatamDocumentTypeId, @OdooMany2OneName(sourceField: 'l10n_latam_document_type_id')  String? l10nLatamDocumentTypeName, @OdooMany2OneName(sourceField: 'l10n_ec_sri_payment_id')  String? l10nEcSriPaymentName, @OdooSelection()  String state, @OdooSelection(odooName: 'payment_state')  String? paymentState, @OdooDate(odooName: 'invoice_date')  DateTime? invoiceDate, @OdooDate(odooName: 'invoice_date_due')  DateTime? invoiceDateDue, @OdooDate()  DateTime? date, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooLocalOnly()  String? partnerVat, @OdooLocalOnly()  String? partnerStreet, @OdooLocalOnly()  String? partnerCity, @OdooLocalOnly()  String? partnerPhone, @OdooLocalOnly()  String? partnerEmail, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooFloat(odooName: 'amount_untaxed')  double amountUntaxed, @OdooFloat(odooName: 'amount_tax')  double amountTax, @OdooFloat(odooName: 'amount_total')  double amountTotal, @OdooFloat(odooName: 'amount_residual')  double amountResidual, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencySymbol, @OdooString(odooName: 'invoice_origin')  String? invoiceOrigin, @OdooString()  String? ref, @OdooLocalOnly()  int? saleOrderId, @OdooLocalOnly()  List<AccountMoveLine> lines, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooLocalOnly()  DateTime? lastSyncDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountMove() when $default != null:
return $default(_that.id,_that.name,_that.moveType,_that.l10nEcAuthorizationNumber,_that.l10nEcAuthorizationDate,_that.l10nLatamDocumentNumber,_that.l10nLatamDocumentTypeId,_that.l10nLatamDocumentTypeName,_that.l10nEcSriPaymentName,_that.state,_that.paymentState,_that.invoiceDate,_that.invoiceDateDue,_that.date,_that.partnerId,_that.partnerName,_that.partnerVat,_that.partnerStreet,_that.partnerCity,_that.partnerPhone,_that.partnerEmail,_that.journalId,_that.journalName,_that.amountUntaxed,_that.amountTax,_that.amountTotal,_that.amountResidual,_that.companyId,_that.currencyId,_that.currencySymbol,_that.invoiceOrigin,_that.ref,_that.saleOrderId,_that.lines,_that.writeDate,_that.lastSyncDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooSelection(odooName: 'move_type')  String moveType, @OdooString(odooName: 'l10n_ec_authorization_number')  String? l10nEcAuthorizationNumber, @OdooDateTime(odooName: 'l10n_ec_authorization_date')  DateTime? l10nEcAuthorizationDate, @OdooString(odooName: 'l10n_latam_document_number')  String? l10nLatamDocumentNumber, @OdooMany2One('l10n_latam.document.type', odooName: 'l10n_latam_document_type_id')  int? l10nLatamDocumentTypeId, @OdooMany2OneName(sourceField: 'l10n_latam_document_type_id')  String? l10nLatamDocumentTypeName, @OdooMany2OneName(sourceField: 'l10n_ec_sri_payment_id')  String? l10nEcSriPaymentName, @OdooSelection()  String state, @OdooSelection(odooName: 'payment_state')  String? paymentState, @OdooDate(odooName: 'invoice_date')  DateTime? invoiceDate, @OdooDate(odooName: 'invoice_date_due')  DateTime? invoiceDateDue, @OdooDate()  DateTime? date, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooLocalOnly()  String? partnerVat, @OdooLocalOnly()  String? partnerStreet, @OdooLocalOnly()  String? partnerCity, @OdooLocalOnly()  String? partnerPhone, @OdooLocalOnly()  String? partnerEmail, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooFloat(odooName: 'amount_untaxed')  double amountUntaxed, @OdooFloat(odooName: 'amount_tax')  double amountTax, @OdooFloat(odooName: 'amount_total')  double amountTotal, @OdooFloat(odooName: 'amount_residual')  double amountResidual, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencySymbol, @OdooString(odooName: 'invoice_origin')  String? invoiceOrigin, @OdooString()  String? ref, @OdooLocalOnly()  int? saleOrderId, @OdooLocalOnly()  List<AccountMoveLine> lines, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooLocalOnly()  DateTime? lastSyncDate)  $default,) {final _that = this;
switch (_that) {
case _AccountMove():
return $default(_that.id,_that.name,_that.moveType,_that.l10nEcAuthorizationNumber,_that.l10nEcAuthorizationDate,_that.l10nLatamDocumentNumber,_that.l10nLatamDocumentTypeId,_that.l10nLatamDocumentTypeName,_that.l10nEcSriPaymentName,_that.state,_that.paymentState,_that.invoiceDate,_that.invoiceDateDue,_that.date,_that.partnerId,_that.partnerName,_that.partnerVat,_that.partnerStreet,_that.partnerCity,_that.partnerPhone,_that.partnerEmail,_that.journalId,_that.journalName,_that.amountUntaxed,_that.amountTax,_that.amountTotal,_that.amountResidual,_that.companyId,_that.currencyId,_that.currencySymbol,_that.invoiceOrigin,_that.ref,_that.saleOrderId,_that.lines,_that.writeDate,_that.lastSyncDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooSelection(odooName: 'move_type')  String moveType, @OdooString(odooName: 'l10n_ec_authorization_number')  String? l10nEcAuthorizationNumber, @OdooDateTime(odooName: 'l10n_ec_authorization_date')  DateTime? l10nEcAuthorizationDate, @OdooString(odooName: 'l10n_latam_document_number')  String? l10nLatamDocumentNumber, @OdooMany2One('l10n_latam.document.type', odooName: 'l10n_latam_document_type_id')  int? l10nLatamDocumentTypeId, @OdooMany2OneName(sourceField: 'l10n_latam_document_type_id')  String? l10nLatamDocumentTypeName, @OdooMany2OneName(sourceField: 'l10n_ec_sri_payment_id')  String? l10nEcSriPaymentName, @OdooSelection()  String state, @OdooSelection(odooName: 'payment_state')  String? paymentState, @OdooDate(odooName: 'invoice_date')  DateTime? invoiceDate, @OdooDate(odooName: 'invoice_date_due')  DateTime? invoiceDateDue, @OdooDate()  DateTime? date, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooLocalOnly()  String? partnerVat, @OdooLocalOnly()  String? partnerStreet, @OdooLocalOnly()  String? partnerCity, @OdooLocalOnly()  String? partnerPhone, @OdooLocalOnly()  String? partnerEmail, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooFloat(odooName: 'amount_untaxed')  double amountUntaxed, @OdooFloat(odooName: 'amount_tax')  double amountTax, @OdooFloat(odooName: 'amount_total')  double amountTotal, @OdooFloat(odooName: 'amount_residual')  double amountResidual, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooMany2OneName(sourceField: 'currency_id')  String? currencySymbol, @OdooString(odooName: 'invoice_origin')  String? invoiceOrigin, @OdooString()  String? ref, @OdooLocalOnly()  int? saleOrderId, @OdooLocalOnly()  List<AccountMoveLine> lines, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooLocalOnly()  DateTime? lastSyncDate)?  $default,) {final _that = this;
switch (_that) {
case _AccountMove() when $default != null:
return $default(_that.id,_that.name,_that.moveType,_that.l10nEcAuthorizationNumber,_that.l10nEcAuthorizationDate,_that.l10nLatamDocumentNumber,_that.l10nLatamDocumentTypeId,_that.l10nLatamDocumentTypeName,_that.l10nEcSriPaymentName,_that.state,_that.paymentState,_that.invoiceDate,_that.invoiceDateDue,_that.date,_that.partnerId,_that.partnerName,_that.partnerVat,_that.partnerStreet,_that.partnerCity,_that.partnerPhone,_that.partnerEmail,_that.journalId,_that.journalName,_that.amountUntaxed,_that.amountTax,_that.amountTotal,_that.amountResidual,_that.companyId,_that.currencyId,_that.currencySymbol,_that.invoiceOrigin,_that.ref,_that.saleOrderId,_that.lines,_that.writeDate,_that.lastSyncDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountMove extends AccountMove {
  const _AccountMove({@OdooId() this.id = 0, @OdooString() this.name = '', @OdooSelection(odooName: 'move_type') this.moveType = 'out_invoice', @OdooString(odooName: 'l10n_ec_authorization_number') this.l10nEcAuthorizationNumber, @OdooDateTime(odooName: 'l10n_ec_authorization_date') this.l10nEcAuthorizationDate, @OdooString(odooName: 'l10n_latam_document_number') this.l10nLatamDocumentNumber, @OdooMany2One('l10n_latam.document.type', odooName: 'l10n_latam_document_type_id') this.l10nLatamDocumentTypeId, @OdooMany2OneName(sourceField: 'l10n_latam_document_type_id') this.l10nLatamDocumentTypeName, @OdooMany2OneName(sourceField: 'l10n_ec_sri_payment_id') this.l10nEcSriPaymentName, @OdooSelection() this.state = 'draft', @OdooSelection(odooName: 'payment_state') this.paymentState, @OdooDate(odooName: 'invoice_date') this.invoiceDate, @OdooDate(odooName: 'invoice_date_due') this.invoiceDateDue, @OdooDate() this.date, @OdooMany2One('res.partner', odooName: 'partner_id') this.partnerId, @OdooMany2OneName(sourceField: 'partner_id') this.partnerName, @OdooLocalOnly() this.partnerVat, @OdooLocalOnly() this.partnerStreet, @OdooLocalOnly() this.partnerCity, @OdooLocalOnly() this.partnerPhone, @OdooLocalOnly() this.partnerEmail, @OdooMany2One('account.journal', odooName: 'journal_id') this.journalId, @OdooMany2OneName(sourceField: 'journal_id') this.journalName, @OdooFloat(odooName: 'amount_untaxed') this.amountUntaxed = 0.0, @OdooFloat(odooName: 'amount_tax') this.amountTax = 0.0, @OdooFloat(odooName: 'amount_total') this.amountTotal = 0.0, @OdooFloat(odooName: 'amount_residual') this.amountResidual = 0.0, @OdooMany2One('res.company', odooName: 'company_id') this.companyId, @OdooMany2One('res.currency', odooName: 'currency_id') this.currencyId, @OdooMany2OneName(sourceField: 'currency_id') this.currencySymbol, @OdooString(odooName: 'invoice_origin') this.invoiceOrigin, @OdooString() this.ref, @OdooLocalOnly() this.saleOrderId, @OdooLocalOnly() final  List<AccountMoveLine> lines = const [], @OdooDateTime(odooName: 'write_date') this.writeDate, @OdooLocalOnly() this.lastSyncDate}): _lines = lines,super._();
  factory _AccountMove.fromJson(Map<String, dynamic> json) => _$AccountMoveFromJson(json);

// ============ Identifiers ============
@override@JsonKey()@OdooId() final  int id;
// ============ Basic Data ============
@override@JsonKey()@OdooString() final  String name;
@override@JsonKey()@OdooSelection(odooName: 'move_type') final  String moveType;
// ============ Ecuador SRI Fields ============
@override@OdooString(odooName: 'l10n_ec_authorization_number') final  String? l10nEcAuthorizationNumber;
@override@OdooDateTime(odooName: 'l10n_ec_authorization_date') final  DateTime? l10nEcAuthorizationDate;
@override@OdooString(odooName: 'l10n_latam_document_number') final  String? l10nLatamDocumentNumber;
@override@OdooMany2One('l10n_latam.document.type', odooName: 'l10n_latam_document_type_id') final  int? l10nLatamDocumentTypeId;
@override@OdooMany2OneName(sourceField: 'l10n_latam_document_type_id') final  String? l10nLatamDocumentTypeName;
@override@OdooMany2OneName(sourceField: 'l10n_ec_sri_payment_id') final  String? l10nEcSriPaymentName;
// ============ State ============
@override@JsonKey()@OdooSelection() final  String state;
@override@OdooSelection(odooName: 'payment_state') final  String? paymentState;
// ============ Dates ============
@override@OdooDate(odooName: 'invoice_date') final  DateTime? invoiceDate;
@override@OdooDate(odooName: 'invoice_date_due') final  DateTime? invoiceDateDue;
@override@OdooDate() final  DateTime? date;
// ============ Partner ============
@override@OdooMany2One('res.partner', odooName: 'partner_id') final  int? partnerId;
@override@OdooMany2OneName(sourceField: 'partner_id') final  String? partnerName;
@override@OdooLocalOnly() final  String? partnerVat;
@override@OdooLocalOnly() final  String? partnerStreet;
@override@OdooLocalOnly() final  String? partnerCity;
@override@OdooLocalOnly() final  String? partnerPhone;
@override@OdooLocalOnly() final  String? partnerEmail;
// ============ Journal ============
@override@OdooMany2One('account.journal', odooName: 'journal_id') final  int? journalId;
@override@OdooMany2OneName(sourceField: 'journal_id') final  String? journalName;
// ============ Amounts ============
@override@JsonKey()@OdooFloat(odooName: 'amount_untaxed') final  double amountUntaxed;
@override@JsonKey()@OdooFloat(odooName: 'amount_tax') final  double amountTax;
@override@JsonKey()@OdooFloat(odooName: 'amount_total') final  double amountTotal;
@override@JsonKey()@OdooFloat(odooName: 'amount_residual') final  double amountResidual;
// ============ Company and Currency ============
@override@OdooMany2One('res.company', odooName: 'company_id') final  int? companyId;
@override@OdooMany2One('res.currency', odooName: 'currency_id') final  int? currencyId;
@override@OdooMany2OneName(sourceField: 'currency_id') final  String? currencySymbol;
// ============ Origin and Reference ============
@override@OdooString(odooName: 'invoice_origin') final  String? invoiceOrigin;
@override@OdooString() final  String? ref;
@override@OdooLocalOnly() final  int? saleOrderId;
// ============ Invoice Lines ============
 final  List<AccountMoveLine> _lines;
// ============ Invoice Lines ============
@override@JsonKey()@OdooLocalOnly() List<AccountMoveLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

// ============ Sync ============
@override@OdooDateTime(odooName: 'write_date') final  DateTime? writeDate;
@override@OdooLocalOnly() final  DateTime? lastSyncDate;

/// Create a copy of AccountMove
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountMoveCopyWith<_AccountMove> get copyWith => __$AccountMoveCopyWithImpl<_AccountMove>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountMoveToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountMove&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.moveType, moveType) || other.moveType == moveType)&&(identical(other.l10nEcAuthorizationNumber, l10nEcAuthorizationNumber) || other.l10nEcAuthorizationNumber == l10nEcAuthorizationNumber)&&(identical(other.l10nEcAuthorizationDate, l10nEcAuthorizationDate) || other.l10nEcAuthorizationDate == l10nEcAuthorizationDate)&&(identical(other.l10nLatamDocumentNumber, l10nLatamDocumentNumber) || other.l10nLatamDocumentNumber == l10nLatamDocumentNumber)&&(identical(other.l10nLatamDocumentTypeId, l10nLatamDocumentTypeId) || other.l10nLatamDocumentTypeId == l10nLatamDocumentTypeId)&&(identical(other.l10nLatamDocumentTypeName, l10nLatamDocumentTypeName) || other.l10nLatamDocumentTypeName == l10nLatamDocumentTypeName)&&(identical(other.l10nEcSriPaymentName, l10nEcSriPaymentName) || other.l10nEcSriPaymentName == l10nEcSriPaymentName)&&(identical(other.state, state) || other.state == state)&&(identical(other.paymentState, paymentState) || other.paymentState == paymentState)&&(identical(other.invoiceDate, invoiceDate) || other.invoiceDate == invoiceDate)&&(identical(other.invoiceDateDue, invoiceDateDue) || other.invoiceDateDue == invoiceDateDue)&&(identical(other.date, date) || other.date == date)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.partnerVat, partnerVat) || other.partnerVat == partnerVat)&&(identical(other.partnerStreet, partnerStreet) || other.partnerStreet == partnerStreet)&&(identical(other.partnerCity, partnerCity) || other.partnerCity == partnerCity)&&(identical(other.partnerPhone, partnerPhone) || other.partnerPhone == partnerPhone)&&(identical(other.partnerEmail, partnerEmail) || other.partnerEmail == partnerEmail)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.amountUntaxed, amountUntaxed) || other.amountUntaxed == amountUntaxed)&&(identical(other.amountTax, amountTax) || other.amountTax == amountTax)&&(identical(other.amountTotal, amountTotal) || other.amountTotal == amountTotal)&&(identical(other.amountResidual, amountResidual) || other.amountResidual == amountResidual)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.currencySymbol, currencySymbol) || other.currencySymbol == currencySymbol)&&(identical(other.invoiceOrigin, invoiceOrigin) || other.invoiceOrigin == invoiceOrigin)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.saleOrderId, saleOrderId) || other.saleOrderId == saleOrderId)&&const DeepCollectionEquality().equals(other._lines, _lines)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,moveType,l10nEcAuthorizationNumber,l10nEcAuthorizationDate,l10nLatamDocumentNumber,l10nLatamDocumentTypeId,l10nLatamDocumentTypeName,l10nEcSriPaymentName,state,paymentState,invoiceDate,invoiceDateDue,date,partnerId,partnerName,partnerVat,partnerStreet,partnerCity,partnerPhone,partnerEmail,journalId,journalName,amountUntaxed,amountTax,amountTotal,amountResidual,companyId,currencyId,currencySymbol,invoiceOrigin,ref,saleOrderId,const DeepCollectionEquality().hash(_lines),writeDate,lastSyncDate]);

@override
String toString() {
  return 'AccountMove(id: $id, name: $name, moveType: $moveType, l10nEcAuthorizationNumber: $l10nEcAuthorizationNumber, l10nEcAuthorizationDate: $l10nEcAuthorizationDate, l10nLatamDocumentNumber: $l10nLatamDocumentNumber, l10nLatamDocumentTypeId: $l10nLatamDocumentTypeId, l10nLatamDocumentTypeName: $l10nLatamDocumentTypeName, l10nEcSriPaymentName: $l10nEcSriPaymentName, state: $state, paymentState: $paymentState, invoiceDate: $invoiceDate, invoiceDateDue: $invoiceDateDue, date: $date, partnerId: $partnerId, partnerName: $partnerName, partnerVat: $partnerVat, partnerStreet: $partnerStreet, partnerCity: $partnerCity, partnerPhone: $partnerPhone, partnerEmail: $partnerEmail, journalId: $journalId, journalName: $journalName, amountUntaxed: $amountUntaxed, amountTax: $amountTax, amountTotal: $amountTotal, amountResidual: $amountResidual, companyId: $companyId, currencyId: $currencyId, currencySymbol: $currencySymbol, invoiceOrigin: $invoiceOrigin, ref: $ref, saleOrderId: $saleOrderId, lines: $lines, writeDate: $writeDate, lastSyncDate: $lastSyncDate)';
}


}

/// @nodoc
abstract mixin class _$AccountMoveCopyWith<$Res> implements $AccountMoveCopyWith<$Res> {
  factory _$AccountMoveCopyWith(_AccountMove value, $Res Function(_AccountMove) _then) = __$AccountMoveCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooSelection(odooName: 'move_type') String moveType,@OdooString(odooName: 'l10n_ec_authorization_number') String? l10nEcAuthorizationNumber,@OdooDateTime(odooName: 'l10n_ec_authorization_date') DateTime? l10nEcAuthorizationDate,@OdooString(odooName: 'l10n_latam_document_number') String? l10nLatamDocumentNumber,@OdooMany2One('l10n_latam.document.type', odooName: 'l10n_latam_document_type_id') int? l10nLatamDocumentTypeId,@OdooMany2OneName(sourceField: 'l10n_latam_document_type_id') String? l10nLatamDocumentTypeName,@OdooMany2OneName(sourceField: 'l10n_ec_sri_payment_id') String? l10nEcSriPaymentName,@OdooSelection() String state,@OdooSelection(odooName: 'payment_state') String? paymentState,@OdooDate(odooName: 'invoice_date') DateTime? invoiceDate,@OdooDate(odooName: 'invoice_date_due') DateTime? invoiceDateDue,@OdooDate() DateTime? date,@OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooLocalOnly() String? partnerVat,@OdooLocalOnly() String? partnerStreet,@OdooLocalOnly() String? partnerCity,@OdooLocalOnly() String? partnerPhone,@OdooLocalOnly() String? partnerEmail,@OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooFloat(odooName: 'amount_untaxed') double amountUntaxed,@OdooFloat(odooName: 'amount_tax') double amountTax,@OdooFloat(odooName: 'amount_total') double amountTotal,@OdooFloat(odooName: 'amount_residual') double amountResidual,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,@OdooMany2OneName(sourceField: 'currency_id') String? currencySymbol,@OdooString(odooName: 'invoice_origin') String? invoiceOrigin,@OdooString() String? ref,@OdooLocalOnly() int? saleOrderId,@OdooLocalOnly() List<AccountMoveLine> lines,@OdooDateTime(odooName: 'write_date') DateTime? writeDate,@OdooLocalOnly() DateTime? lastSyncDate
});




}
/// @nodoc
class __$AccountMoveCopyWithImpl<$Res>
    implements _$AccountMoveCopyWith<$Res> {
  __$AccountMoveCopyWithImpl(this._self, this._then);

  final _AccountMove _self;
  final $Res Function(_AccountMove) _then;

/// Create a copy of AccountMove
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? moveType = null,Object? l10nEcAuthorizationNumber = freezed,Object? l10nEcAuthorizationDate = freezed,Object? l10nLatamDocumentNumber = freezed,Object? l10nLatamDocumentTypeId = freezed,Object? l10nLatamDocumentTypeName = freezed,Object? l10nEcSriPaymentName = freezed,Object? state = null,Object? paymentState = freezed,Object? invoiceDate = freezed,Object? invoiceDateDue = freezed,Object? date = freezed,Object? partnerId = freezed,Object? partnerName = freezed,Object? partnerVat = freezed,Object? partnerStreet = freezed,Object? partnerCity = freezed,Object? partnerPhone = freezed,Object? partnerEmail = freezed,Object? journalId = freezed,Object? journalName = freezed,Object? amountUntaxed = null,Object? amountTax = null,Object? amountTotal = null,Object? amountResidual = null,Object? companyId = freezed,Object? currencyId = freezed,Object? currencySymbol = freezed,Object? invoiceOrigin = freezed,Object? ref = freezed,Object? saleOrderId = freezed,Object? lines = null,Object? writeDate = freezed,Object? lastSyncDate = freezed,}) {
  return _then(_AccountMove(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,moveType: null == moveType ? _self.moveType : moveType // ignore: cast_nullable_to_non_nullable
as String,l10nEcAuthorizationNumber: freezed == l10nEcAuthorizationNumber ? _self.l10nEcAuthorizationNumber : l10nEcAuthorizationNumber // ignore: cast_nullable_to_non_nullable
as String?,l10nEcAuthorizationDate: freezed == l10nEcAuthorizationDate ? _self.l10nEcAuthorizationDate : l10nEcAuthorizationDate // ignore: cast_nullable_to_non_nullable
as DateTime?,l10nLatamDocumentNumber: freezed == l10nLatamDocumentNumber ? _self.l10nLatamDocumentNumber : l10nLatamDocumentNumber // ignore: cast_nullable_to_non_nullable
as String?,l10nLatamDocumentTypeId: freezed == l10nLatamDocumentTypeId ? _self.l10nLatamDocumentTypeId : l10nLatamDocumentTypeId // ignore: cast_nullable_to_non_nullable
as int?,l10nLatamDocumentTypeName: freezed == l10nLatamDocumentTypeName ? _self.l10nLatamDocumentTypeName : l10nLatamDocumentTypeName // ignore: cast_nullable_to_non_nullable
as String?,l10nEcSriPaymentName: freezed == l10nEcSriPaymentName ? _self.l10nEcSriPaymentName : l10nEcSriPaymentName // ignore: cast_nullable_to_non_nullable
as String?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,paymentState: freezed == paymentState ? _self.paymentState : paymentState // ignore: cast_nullable_to_non_nullable
as String?,invoiceDate: freezed == invoiceDate ? _self.invoiceDate : invoiceDate // ignore: cast_nullable_to_non_nullable
as DateTime?,invoiceDateDue: freezed == invoiceDateDue ? _self.invoiceDateDue : invoiceDateDue // ignore: cast_nullable_to_non_nullable
as DateTime?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime?,partnerId: freezed == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int?,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,partnerVat: freezed == partnerVat ? _self.partnerVat : partnerVat // ignore: cast_nullable_to_non_nullable
as String?,partnerStreet: freezed == partnerStreet ? _self.partnerStreet : partnerStreet // ignore: cast_nullable_to_non_nullable
as String?,partnerCity: freezed == partnerCity ? _self.partnerCity : partnerCity // ignore: cast_nullable_to_non_nullable
as String?,partnerPhone: freezed == partnerPhone ? _self.partnerPhone : partnerPhone // ignore: cast_nullable_to_non_nullable
as String?,partnerEmail: freezed == partnerEmail ? _self.partnerEmail : partnerEmail // ignore: cast_nullable_to_non_nullable
as String?,journalId: freezed == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int?,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,amountUntaxed: null == amountUntaxed ? _self.amountUntaxed : amountUntaxed // ignore: cast_nullable_to_non_nullable
as double,amountTax: null == amountTax ? _self.amountTax : amountTax // ignore: cast_nullable_to_non_nullable
as double,amountTotal: null == amountTotal ? _self.amountTotal : amountTotal // ignore: cast_nullable_to_non_nullable
as double,amountResidual: null == amountResidual ? _self.amountResidual : amountResidual // ignore: cast_nullable_to_non_nullable
as double,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,currencyId: freezed == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as int?,currencySymbol: freezed == currencySymbol ? _self.currencySymbol : currencySymbol // ignore: cast_nullable_to_non_nullable
as String?,invoiceOrigin: freezed == invoiceOrigin ? _self.invoiceOrigin : invoiceOrigin // ignore: cast_nullable_to_non_nullable
as String?,ref: freezed == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String?,saleOrderId: freezed == saleOrderId ? _self.saleOrderId : saleOrderId // ignore: cast_nullable_to_non_nullable
as int?,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<AccountMoveLine>,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
