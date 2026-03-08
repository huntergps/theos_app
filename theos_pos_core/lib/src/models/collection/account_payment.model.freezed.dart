// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_payment.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountPayment {

// ============ Identifiers ============
@OdooId() int get id;@OdooLocalOnly() String? get paymentUuid;@OdooLocalOnly() bool get isSynced;// ============ Relations ============
@OdooMany2One('collection.session', odooName: 'collection_session_id') int? get collectionSessionId;@OdooMany2One('account.move', odooName: 'reconciled_invoice_ids') int? get invoiceId;@OdooMany2One('res.partner', odooName: 'partner_id') int? get partnerId;@OdooMany2OneName(sourceField: 'partner_id') String? get partnerName;@OdooMany2One('account.journal', odooName: 'journal_id') int? get journalId;@OdooMany2OneName(sourceField: 'journal_id') String? get journalName;@OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') int? get paymentMethodLineId;@OdooMany2OneName(sourceField: 'payment_method_line_id') String? get paymentMethodLineName;// ============ Economic Data ============
@OdooFloat() double get amount;@OdooSelection(odooName: 'payment_type') String get paymentType;@OdooSelection() String get state;// ============ Classification ============
@OdooSelection(odooName: 'payment_origin_type') String? get paymentOriginType;@OdooSelection(odooName: 'payment_method_category') String? get paymentMethodCategory;// ============ Bank (res.bank) ============
@OdooMany2One('res.bank', odooName: 'bank_id') int? get bankId;@OdooMany2OneName(sourceField: 'bank_id') String? get bankName;// ============ Check Fields (l10n_ec_collection_box) ============
@OdooString(odooName: 'check_number') String? get checkNumber;@OdooString(odooName: 'check_amount_in_words') String? get checkAmountInWords;@OdooDate(odooName: 'bank_reference_date') DateTime? get bankReferenceDate;@OdooBoolean(odooName: 'es_posfechado') bool get esPosfechado;@OdooMany2One('account.cheque.recibido', odooName: 'cheque_recibido_id') int? get chequeRecibidoId;// ============ Card Fields (l10n_ec_collection_box) ============
@OdooMany2One('account.card.brand', odooName: 'card_brand_id') int? get cardBrandId;@OdooMany2OneName(sourceField: 'card_brand_id') String? get cardBrandName;@OdooSelection(odooName: 'card_type') String? get cardType;@OdooMany2One('account.card.lote', odooName: 'lote_id') int? get loteId;@OdooString(odooName: 'card_holder_name') String? get cardHolderName;@OdooString(odooName: 'card_last_4') String? get cardLast4;@OdooString(odooName: 'authorization_code') String? get authorizationCode;// ============ Payment Classification (computed flags) ============
@OdooBoolean(odooName: 'is_card_payment') bool get isCardPayment;@OdooBoolean(odooName: 'is_transfer_payment') bool get isTransferPayment;@OdooBoolean(odooName: 'is_check_payment') bool get isCheckPayment;@OdooBoolean(odooName: 'is_cash_payment') bool get isCashPayment;// ============ Sale Order Link ============
@OdooMany2One('sale.order', odooName: 'sale_id') int? get saleId;@OdooMany2One('account.payment', odooName: 'advance_id') int? get advanceId;@OdooMany2One('res.users', odooName: 'collection_user_id') int? get collectionUserId;// ============ Metadata ============
@OdooDate() DateTime? get date;@OdooString() String? get name;@OdooString() String? get ref;// ============ Sync ============
@OdooLocalOnly() DateTime? get lastSyncDate;@OdooDateTime(odooName: 'write_date') DateTime? get writeDate;
/// Create a copy of AccountPayment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountPaymentCopyWith<AccountPayment> get copyWith => _$AccountPaymentCopyWithImpl<AccountPayment>(this as AccountPayment, _$identity);

  /// Serializes this AccountPayment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountPayment&&(identical(other.id, id) || other.id == id)&&(identical(other.paymentUuid, paymentUuid) || other.paymentUuid == paymentUuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.paymentMethodLineId, paymentMethodLineId) || other.paymentMethodLineId == paymentMethodLineId)&&(identical(other.paymentMethodLineName, paymentMethodLineName) || other.paymentMethodLineName == paymentMethodLineName)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.paymentType, paymentType) || other.paymentType == paymentType)&&(identical(other.state, state) || other.state == state)&&(identical(other.paymentOriginType, paymentOriginType) || other.paymentOriginType == paymentOriginType)&&(identical(other.paymentMethodCategory, paymentMethodCategory) || other.paymentMethodCategory == paymentMethodCategory)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.checkNumber, checkNumber) || other.checkNumber == checkNumber)&&(identical(other.checkAmountInWords, checkAmountInWords) || other.checkAmountInWords == checkAmountInWords)&&(identical(other.bankReferenceDate, bankReferenceDate) || other.bankReferenceDate == bankReferenceDate)&&(identical(other.esPosfechado, esPosfechado) || other.esPosfechado == esPosfechado)&&(identical(other.chequeRecibidoId, chequeRecibidoId) || other.chequeRecibidoId == chequeRecibidoId)&&(identical(other.cardBrandId, cardBrandId) || other.cardBrandId == cardBrandId)&&(identical(other.cardBrandName, cardBrandName) || other.cardBrandName == cardBrandName)&&(identical(other.cardType, cardType) || other.cardType == cardType)&&(identical(other.loteId, loteId) || other.loteId == loteId)&&(identical(other.cardHolderName, cardHolderName) || other.cardHolderName == cardHolderName)&&(identical(other.cardLast4, cardLast4) || other.cardLast4 == cardLast4)&&(identical(other.authorizationCode, authorizationCode) || other.authorizationCode == authorizationCode)&&(identical(other.isCardPayment, isCardPayment) || other.isCardPayment == isCardPayment)&&(identical(other.isTransferPayment, isTransferPayment) || other.isTransferPayment == isTransferPayment)&&(identical(other.isCheckPayment, isCheckPayment) || other.isCheckPayment == isCheckPayment)&&(identical(other.isCashPayment, isCashPayment) || other.isCashPayment == isCashPayment)&&(identical(other.saleId, saleId) || other.saleId == saleId)&&(identical(other.advanceId, advanceId) || other.advanceId == advanceId)&&(identical(other.collectionUserId, collectionUserId) || other.collectionUserId == collectionUserId)&&(identical(other.date, date) || other.date == date)&&(identical(other.name, name) || other.name == name)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,paymentUuid,isSynced,collectionSessionId,invoiceId,partnerId,partnerName,journalId,journalName,paymentMethodLineId,paymentMethodLineName,amount,paymentType,state,paymentOriginType,paymentMethodCategory,bankId,bankName,checkNumber,checkAmountInWords,bankReferenceDate,esPosfechado,chequeRecibidoId,cardBrandId,cardBrandName,cardType,loteId,cardHolderName,cardLast4,authorizationCode,isCardPayment,isTransferPayment,isCheckPayment,isCashPayment,saleId,advanceId,collectionUserId,date,name,ref,lastSyncDate,writeDate]);

@override
String toString() {
  return 'AccountPayment(id: $id, paymentUuid: $paymentUuid, isSynced: $isSynced, collectionSessionId: $collectionSessionId, invoiceId: $invoiceId, partnerId: $partnerId, partnerName: $partnerName, journalId: $journalId, journalName: $journalName, paymentMethodLineId: $paymentMethodLineId, paymentMethodLineName: $paymentMethodLineName, amount: $amount, paymentType: $paymentType, state: $state, paymentOriginType: $paymentOriginType, paymentMethodCategory: $paymentMethodCategory, bankId: $bankId, bankName: $bankName, checkNumber: $checkNumber, checkAmountInWords: $checkAmountInWords, bankReferenceDate: $bankReferenceDate, esPosfechado: $esPosfechado, chequeRecibidoId: $chequeRecibidoId, cardBrandId: $cardBrandId, cardBrandName: $cardBrandName, cardType: $cardType, loteId: $loteId, cardHolderName: $cardHolderName, cardLast4: $cardLast4, authorizationCode: $authorizationCode, isCardPayment: $isCardPayment, isTransferPayment: $isTransferPayment, isCheckPayment: $isCheckPayment, isCashPayment: $isCashPayment, saleId: $saleId, advanceId: $advanceId, collectionUserId: $collectionUserId, date: $date, name: $name, ref: $ref, lastSyncDate: $lastSyncDate, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $AccountPaymentCopyWith<$Res>  {
  factory $AccountPaymentCopyWith(AccountPayment value, $Res Function(AccountPayment) _then) = _$AccountPaymentCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? paymentUuid,@OdooLocalOnly() bool isSynced,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooMany2One('account.move', odooName: 'reconciled_invoice_ids') int? invoiceId,@OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') int? paymentMethodLineId,@OdooMany2OneName(sourceField: 'payment_method_line_id') String? paymentMethodLineName,@OdooFloat() double amount,@OdooSelection(odooName: 'payment_type') String paymentType,@OdooSelection() String state,@OdooSelection(odooName: 'payment_origin_type') String? paymentOriginType,@OdooSelection(odooName: 'payment_method_category') String? paymentMethodCategory,@OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,@OdooMany2OneName(sourceField: 'bank_id') String? bankName,@OdooString(odooName: 'check_number') String? checkNumber,@OdooString(odooName: 'check_amount_in_words') String? checkAmountInWords,@OdooDate(odooName: 'bank_reference_date') DateTime? bankReferenceDate,@OdooBoolean(odooName: 'es_posfechado') bool esPosfechado,@OdooMany2One('account.cheque.recibido', odooName: 'cheque_recibido_id') int? chequeRecibidoId,@OdooMany2One('account.card.brand', odooName: 'card_brand_id') int? cardBrandId,@OdooMany2OneName(sourceField: 'card_brand_id') String? cardBrandName,@OdooSelection(odooName: 'card_type') String? cardType,@OdooMany2One('account.card.lote', odooName: 'lote_id') int? loteId,@OdooString(odooName: 'card_holder_name') String? cardHolderName,@OdooString(odooName: 'card_last_4') String? cardLast4,@OdooString(odooName: 'authorization_code') String? authorizationCode,@OdooBoolean(odooName: 'is_card_payment') bool isCardPayment,@OdooBoolean(odooName: 'is_transfer_payment') bool isTransferPayment,@OdooBoolean(odooName: 'is_check_payment') bool isCheckPayment,@OdooBoolean(odooName: 'is_cash_payment') bool isCashPayment,@OdooMany2One('sale.order', odooName: 'sale_id') int? saleId,@OdooMany2One('account.payment', odooName: 'advance_id') int? advanceId,@OdooMany2One('res.users', odooName: 'collection_user_id') int? collectionUserId,@OdooDate() DateTime? date,@OdooString() String? name,@OdooString() String? ref,@OdooLocalOnly() DateTime? lastSyncDate,@OdooDateTime(odooName: 'write_date') DateTime? writeDate
});




}
/// @nodoc
class _$AccountPaymentCopyWithImpl<$Res>
    implements $AccountPaymentCopyWith<$Res> {
  _$AccountPaymentCopyWithImpl(this._self, this._then);

  final AccountPayment _self;
  final $Res Function(AccountPayment) _then;

/// Create a copy of AccountPayment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? paymentUuid = freezed,Object? isSynced = null,Object? collectionSessionId = freezed,Object? invoiceId = freezed,Object? partnerId = freezed,Object? partnerName = freezed,Object? journalId = freezed,Object? journalName = freezed,Object? paymentMethodLineId = freezed,Object? paymentMethodLineName = freezed,Object? amount = null,Object? paymentType = null,Object? state = null,Object? paymentOriginType = freezed,Object? paymentMethodCategory = freezed,Object? bankId = freezed,Object? bankName = freezed,Object? checkNumber = freezed,Object? checkAmountInWords = freezed,Object? bankReferenceDate = freezed,Object? esPosfechado = null,Object? chequeRecibidoId = freezed,Object? cardBrandId = freezed,Object? cardBrandName = freezed,Object? cardType = freezed,Object? loteId = freezed,Object? cardHolderName = freezed,Object? cardLast4 = freezed,Object? authorizationCode = freezed,Object? isCardPayment = null,Object? isTransferPayment = null,Object? isCheckPayment = null,Object? isCashPayment = null,Object? saleId = freezed,Object? advanceId = freezed,Object? collectionUserId = freezed,Object? date = freezed,Object? name = freezed,Object? ref = freezed,Object? lastSyncDate = freezed,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,paymentUuid: freezed == paymentUuid ? _self.paymentUuid : paymentUuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as int?,partnerId: freezed == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int?,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,journalId: freezed == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int?,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,paymentMethodLineId: freezed == paymentMethodLineId ? _self.paymentMethodLineId : paymentMethodLineId // ignore: cast_nullable_to_non_nullable
as int?,paymentMethodLineName: freezed == paymentMethodLineName ? _self.paymentMethodLineName : paymentMethodLineName // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,paymentType: null == paymentType ? _self.paymentType : paymentType // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,paymentOriginType: freezed == paymentOriginType ? _self.paymentOriginType : paymentOriginType // ignore: cast_nullable_to_non_nullable
as String?,paymentMethodCategory: freezed == paymentMethodCategory ? _self.paymentMethodCategory : paymentMethodCategory // ignore: cast_nullable_to_non_nullable
as String?,bankId: freezed == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as int?,bankName: freezed == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String?,checkNumber: freezed == checkNumber ? _self.checkNumber : checkNumber // ignore: cast_nullable_to_non_nullable
as String?,checkAmountInWords: freezed == checkAmountInWords ? _self.checkAmountInWords : checkAmountInWords // ignore: cast_nullable_to_non_nullable
as String?,bankReferenceDate: freezed == bankReferenceDate ? _self.bankReferenceDate : bankReferenceDate // ignore: cast_nullable_to_non_nullable
as DateTime?,esPosfechado: null == esPosfechado ? _self.esPosfechado : esPosfechado // ignore: cast_nullable_to_non_nullable
as bool,chequeRecibidoId: freezed == chequeRecibidoId ? _self.chequeRecibidoId : chequeRecibidoId // ignore: cast_nullable_to_non_nullable
as int?,cardBrandId: freezed == cardBrandId ? _self.cardBrandId : cardBrandId // ignore: cast_nullable_to_non_nullable
as int?,cardBrandName: freezed == cardBrandName ? _self.cardBrandName : cardBrandName // ignore: cast_nullable_to_non_nullable
as String?,cardType: freezed == cardType ? _self.cardType : cardType // ignore: cast_nullable_to_non_nullable
as String?,loteId: freezed == loteId ? _self.loteId : loteId // ignore: cast_nullable_to_non_nullable
as int?,cardHolderName: freezed == cardHolderName ? _self.cardHolderName : cardHolderName // ignore: cast_nullable_to_non_nullable
as String?,cardLast4: freezed == cardLast4 ? _self.cardLast4 : cardLast4 // ignore: cast_nullable_to_non_nullable
as String?,authorizationCode: freezed == authorizationCode ? _self.authorizationCode : authorizationCode // ignore: cast_nullable_to_non_nullable
as String?,isCardPayment: null == isCardPayment ? _self.isCardPayment : isCardPayment // ignore: cast_nullable_to_non_nullable
as bool,isTransferPayment: null == isTransferPayment ? _self.isTransferPayment : isTransferPayment // ignore: cast_nullable_to_non_nullable
as bool,isCheckPayment: null == isCheckPayment ? _self.isCheckPayment : isCheckPayment // ignore: cast_nullable_to_non_nullable
as bool,isCashPayment: null == isCashPayment ? _self.isCashPayment : isCashPayment // ignore: cast_nullable_to_non_nullable
as bool,saleId: freezed == saleId ? _self.saleId : saleId // ignore: cast_nullable_to_non_nullable
as int?,advanceId: freezed == advanceId ? _self.advanceId : advanceId // ignore: cast_nullable_to_non_nullable
as int?,collectionUserId: freezed == collectionUserId ? _self.collectionUserId : collectionUserId // ignore: cast_nullable_to_non_nullable
as int?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,ref: freezed == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String?,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountPayment].
extension AccountPaymentPatterns on AccountPayment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountPayment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountPayment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountPayment value)  $default,){
final _that = this;
switch (_that) {
case _AccountPayment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountPayment value)?  $default,){
final _that = this;
switch (_that) {
case _AccountPayment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? paymentUuid, @OdooLocalOnly()  bool isSynced, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('account.move', odooName: 'reconciled_invoice_ids')  int? invoiceId, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id')  int? paymentMethodLineId, @OdooMany2OneName(sourceField: 'payment_method_line_id')  String? paymentMethodLineName, @OdooFloat()  double amount, @OdooSelection(odooName: 'payment_type')  String paymentType, @OdooSelection()  String state, @OdooSelection(odooName: 'payment_origin_type')  String? paymentOriginType, @OdooSelection(odooName: 'payment_method_category')  String? paymentMethodCategory, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooMany2OneName(sourceField: 'bank_id')  String? bankName, @OdooString(odooName: 'check_number')  String? checkNumber, @OdooString(odooName: 'check_amount_in_words')  String? checkAmountInWords, @OdooDate(odooName: 'bank_reference_date')  DateTime? bankReferenceDate, @OdooBoolean(odooName: 'es_posfechado')  bool esPosfechado, @OdooMany2One('account.cheque.recibido', odooName: 'cheque_recibido_id')  int? chequeRecibidoId, @OdooMany2One('account.card.brand', odooName: 'card_brand_id')  int? cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id')  String? cardBrandName, @OdooSelection(odooName: 'card_type')  String? cardType, @OdooMany2One('account.card.lote', odooName: 'lote_id')  int? loteId, @OdooString(odooName: 'card_holder_name')  String? cardHolderName, @OdooString(odooName: 'card_last_4')  String? cardLast4, @OdooString(odooName: 'authorization_code')  String? authorizationCode, @OdooBoolean(odooName: 'is_card_payment')  bool isCardPayment, @OdooBoolean(odooName: 'is_transfer_payment')  bool isTransferPayment, @OdooBoolean(odooName: 'is_check_payment')  bool isCheckPayment, @OdooBoolean(odooName: 'is_cash_payment')  bool isCashPayment, @OdooMany2One('sale.order', odooName: 'sale_id')  int? saleId, @OdooMany2One('account.payment', odooName: 'advance_id')  int? advanceId, @OdooMany2One('res.users', odooName: 'collection_user_id')  int? collectionUserId, @OdooDate()  DateTime? date, @OdooString()  String? name, @OdooString()  String? ref, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountPayment() when $default != null:
return $default(_that.id,_that.paymentUuid,_that.isSynced,_that.collectionSessionId,_that.invoiceId,_that.partnerId,_that.partnerName,_that.journalId,_that.journalName,_that.paymentMethodLineId,_that.paymentMethodLineName,_that.amount,_that.paymentType,_that.state,_that.paymentOriginType,_that.paymentMethodCategory,_that.bankId,_that.bankName,_that.checkNumber,_that.checkAmountInWords,_that.bankReferenceDate,_that.esPosfechado,_that.chequeRecibidoId,_that.cardBrandId,_that.cardBrandName,_that.cardType,_that.loteId,_that.cardHolderName,_that.cardLast4,_that.authorizationCode,_that.isCardPayment,_that.isTransferPayment,_that.isCheckPayment,_that.isCashPayment,_that.saleId,_that.advanceId,_that.collectionUserId,_that.date,_that.name,_that.ref,_that.lastSyncDate,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? paymentUuid, @OdooLocalOnly()  bool isSynced, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('account.move', odooName: 'reconciled_invoice_ids')  int? invoiceId, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id')  int? paymentMethodLineId, @OdooMany2OneName(sourceField: 'payment_method_line_id')  String? paymentMethodLineName, @OdooFloat()  double amount, @OdooSelection(odooName: 'payment_type')  String paymentType, @OdooSelection()  String state, @OdooSelection(odooName: 'payment_origin_type')  String? paymentOriginType, @OdooSelection(odooName: 'payment_method_category')  String? paymentMethodCategory, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooMany2OneName(sourceField: 'bank_id')  String? bankName, @OdooString(odooName: 'check_number')  String? checkNumber, @OdooString(odooName: 'check_amount_in_words')  String? checkAmountInWords, @OdooDate(odooName: 'bank_reference_date')  DateTime? bankReferenceDate, @OdooBoolean(odooName: 'es_posfechado')  bool esPosfechado, @OdooMany2One('account.cheque.recibido', odooName: 'cheque_recibido_id')  int? chequeRecibidoId, @OdooMany2One('account.card.brand', odooName: 'card_brand_id')  int? cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id')  String? cardBrandName, @OdooSelection(odooName: 'card_type')  String? cardType, @OdooMany2One('account.card.lote', odooName: 'lote_id')  int? loteId, @OdooString(odooName: 'card_holder_name')  String? cardHolderName, @OdooString(odooName: 'card_last_4')  String? cardLast4, @OdooString(odooName: 'authorization_code')  String? authorizationCode, @OdooBoolean(odooName: 'is_card_payment')  bool isCardPayment, @OdooBoolean(odooName: 'is_transfer_payment')  bool isTransferPayment, @OdooBoolean(odooName: 'is_check_payment')  bool isCheckPayment, @OdooBoolean(odooName: 'is_cash_payment')  bool isCashPayment, @OdooMany2One('sale.order', odooName: 'sale_id')  int? saleId, @OdooMany2One('account.payment', odooName: 'advance_id')  int? advanceId, @OdooMany2One('res.users', odooName: 'collection_user_id')  int? collectionUserId, @OdooDate()  DateTime? date, @OdooString()  String? name, @OdooString()  String? ref, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _AccountPayment():
return $default(_that.id,_that.paymentUuid,_that.isSynced,_that.collectionSessionId,_that.invoiceId,_that.partnerId,_that.partnerName,_that.journalId,_that.journalName,_that.paymentMethodLineId,_that.paymentMethodLineName,_that.amount,_that.paymentType,_that.state,_that.paymentOriginType,_that.paymentMethodCategory,_that.bankId,_that.bankName,_that.checkNumber,_that.checkAmountInWords,_that.bankReferenceDate,_that.esPosfechado,_that.chequeRecibidoId,_that.cardBrandId,_that.cardBrandName,_that.cardType,_that.loteId,_that.cardHolderName,_that.cardLast4,_that.authorizationCode,_that.isCardPayment,_that.isTransferPayment,_that.isCheckPayment,_that.isCashPayment,_that.saleId,_that.advanceId,_that.collectionUserId,_that.date,_that.name,_that.ref,_that.lastSyncDate,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? paymentUuid, @OdooLocalOnly()  bool isSynced, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('account.move', odooName: 'reconciled_invoice_ids')  int? invoiceId, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id')  int? paymentMethodLineId, @OdooMany2OneName(sourceField: 'payment_method_line_id')  String? paymentMethodLineName, @OdooFloat()  double amount, @OdooSelection(odooName: 'payment_type')  String paymentType, @OdooSelection()  String state, @OdooSelection(odooName: 'payment_origin_type')  String? paymentOriginType, @OdooSelection(odooName: 'payment_method_category')  String? paymentMethodCategory, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooMany2OneName(sourceField: 'bank_id')  String? bankName, @OdooString(odooName: 'check_number')  String? checkNumber, @OdooString(odooName: 'check_amount_in_words')  String? checkAmountInWords, @OdooDate(odooName: 'bank_reference_date')  DateTime? bankReferenceDate, @OdooBoolean(odooName: 'es_posfechado')  bool esPosfechado, @OdooMany2One('account.cheque.recibido', odooName: 'cheque_recibido_id')  int? chequeRecibidoId, @OdooMany2One('account.card.brand', odooName: 'card_brand_id')  int? cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id')  String? cardBrandName, @OdooSelection(odooName: 'card_type')  String? cardType, @OdooMany2One('account.card.lote', odooName: 'lote_id')  int? loteId, @OdooString(odooName: 'card_holder_name')  String? cardHolderName, @OdooString(odooName: 'card_last_4')  String? cardLast4, @OdooString(odooName: 'authorization_code')  String? authorizationCode, @OdooBoolean(odooName: 'is_card_payment')  bool isCardPayment, @OdooBoolean(odooName: 'is_transfer_payment')  bool isTransferPayment, @OdooBoolean(odooName: 'is_check_payment')  bool isCheckPayment, @OdooBoolean(odooName: 'is_cash_payment')  bool isCashPayment, @OdooMany2One('sale.order', odooName: 'sale_id')  int? saleId, @OdooMany2One('account.payment', odooName: 'advance_id')  int? advanceId, @OdooMany2One('res.users', odooName: 'collection_user_id')  int? collectionUserId, @OdooDate()  DateTime? date, @OdooString()  String? name, @OdooString()  String? ref, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _AccountPayment() when $default != null:
return $default(_that.id,_that.paymentUuid,_that.isSynced,_that.collectionSessionId,_that.invoiceId,_that.partnerId,_that.partnerName,_that.journalId,_that.journalName,_that.paymentMethodLineId,_that.paymentMethodLineName,_that.amount,_that.paymentType,_that.state,_that.paymentOriginType,_that.paymentMethodCategory,_that.bankId,_that.bankName,_that.checkNumber,_that.checkAmountInWords,_that.bankReferenceDate,_that.esPosfechado,_that.chequeRecibidoId,_that.cardBrandId,_that.cardBrandName,_that.cardType,_that.loteId,_that.cardHolderName,_that.cardLast4,_that.authorizationCode,_that.isCardPayment,_that.isTransferPayment,_that.isCheckPayment,_that.isCashPayment,_that.saleId,_that.advanceId,_that.collectionUserId,_that.date,_that.name,_that.ref,_that.lastSyncDate,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountPayment extends AccountPayment {
  const _AccountPayment({@OdooId() required this.id, @OdooLocalOnly() this.paymentUuid, @OdooLocalOnly() this.isSynced = false, @OdooMany2One('collection.session', odooName: 'collection_session_id') this.collectionSessionId, @OdooMany2One('account.move', odooName: 'reconciled_invoice_ids') this.invoiceId, @OdooMany2One('res.partner', odooName: 'partner_id') this.partnerId, @OdooMany2OneName(sourceField: 'partner_id') this.partnerName, @OdooMany2One('account.journal', odooName: 'journal_id') this.journalId, @OdooMany2OneName(sourceField: 'journal_id') this.journalName, @OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') this.paymentMethodLineId, @OdooMany2OneName(sourceField: 'payment_method_line_id') this.paymentMethodLineName, @OdooFloat() this.amount = 0.0, @OdooSelection(odooName: 'payment_type') this.paymentType = 'inbound', @OdooSelection() this.state = 'draft', @OdooSelection(odooName: 'payment_origin_type') this.paymentOriginType, @OdooSelection(odooName: 'payment_method_category') this.paymentMethodCategory, @OdooMany2One('res.bank', odooName: 'bank_id') this.bankId, @OdooMany2OneName(sourceField: 'bank_id') this.bankName, @OdooString(odooName: 'check_number') this.checkNumber, @OdooString(odooName: 'check_amount_in_words') this.checkAmountInWords, @OdooDate(odooName: 'bank_reference_date') this.bankReferenceDate, @OdooBoolean(odooName: 'es_posfechado') this.esPosfechado = false, @OdooMany2One('account.cheque.recibido', odooName: 'cheque_recibido_id') this.chequeRecibidoId, @OdooMany2One('account.card.brand', odooName: 'card_brand_id') this.cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id') this.cardBrandName, @OdooSelection(odooName: 'card_type') this.cardType, @OdooMany2One('account.card.lote', odooName: 'lote_id') this.loteId, @OdooString(odooName: 'card_holder_name') this.cardHolderName, @OdooString(odooName: 'card_last_4') this.cardLast4, @OdooString(odooName: 'authorization_code') this.authorizationCode, @OdooBoolean(odooName: 'is_card_payment') this.isCardPayment = false, @OdooBoolean(odooName: 'is_transfer_payment') this.isTransferPayment = false, @OdooBoolean(odooName: 'is_check_payment') this.isCheckPayment = false, @OdooBoolean(odooName: 'is_cash_payment') this.isCashPayment = false, @OdooMany2One('sale.order', odooName: 'sale_id') this.saleId, @OdooMany2One('account.payment', odooName: 'advance_id') this.advanceId, @OdooMany2One('res.users', odooName: 'collection_user_id') this.collectionUserId, @OdooDate() this.date, @OdooString() this.name, @OdooString() this.ref, @OdooLocalOnly() this.lastSyncDate, @OdooDateTime(odooName: 'write_date') this.writeDate}): super._();
  factory _AccountPayment.fromJson(Map<String, dynamic> json) => _$AccountPaymentFromJson(json);

// ============ Identifiers ============
@override@OdooId() final  int id;
@override@OdooLocalOnly() final  String? paymentUuid;
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
// ============ Relations ============
@override@OdooMany2One('collection.session', odooName: 'collection_session_id') final  int? collectionSessionId;
@override@OdooMany2One('account.move', odooName: 'reconciled_invoice_ids') final  int? invoiceId;
@override@OdooMany2One('res.partner', odooName: 'partner_id') final  int? partnerId;
@override@OdooMany2OneName(sourceField: 'partner_id') final  String? partnerName;
@override@OdooMany2One('account.journal', odooName: 'journal_id') final  int? journalId;
@override@OdooMany2OneName(sourceField: 'journal_id') final  String? journalName;
@override@OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') final  int? paymentMethodLineId;
@override@OdooMany2OneName(sourceField: 'payment_method_line_id') final  String? paymentMethodLineName;
// ============ Economic Data ============
@override@JsonKey()@OdooFloat() final  double amount;
@override@JsonKey()@OdooSelection(odooName: 'payment_type') final  String paymentType;
@override@JsonKey()@OdooSelection() final  String state;
// ============ Classification ============
@override@OdooSelection(odooName: 'payment_origin_type') final  String? paymentOriginType;
@override@OdooSelection(odooName: 'payment_method_category') final  String? paymentMethodCategory;
// ============ Bank (res.bank) ============
@override@OdooMany2One('res.bank', odooName: 'bank_id') final  int? bankId;
@override@OdooMany2OneName(sourceField: 'bank_id') final  String? bankName;
// ============ Check Fields (l10n_ec_collection_box) ============
@override@OdooString(odooName: 'check_number') final  String? checkNumber;
@override@OdooString(odooName: 'check_amount_in_words') final  String? checkAmountInWords;
@override@OdooDate(odooName: 'bank_reference_date') final  DateTime? bankReferenceDate;
@override@JsonKey()@OdooBoolean(odooName: 'es_posfechado') final  bool esPosfechado;
@override@OdooMany2One('account.cheque.recibido', odooName: 'cheque_recibido_id') final  int? chequeRecibidoId;
// ============ Card Fields (l10n_ec_collection_box) ============
@override@OdooMany2One('account.card.brand', odooName: 'card_brand_id') final  int? cardBrandId;
@override@OdooMany2OneName(sourceField: 'card_brand_id') final  String? cardBrandName;
@override@OdooSelection(odooName: 'card_type') final  String? cardType;
@override@OdooMany2One('account.card.lote', odooName: 'lote_id') final  int? loteId;
@override@OdooString(odooName: 'card_holder_name') final  String? cardHolderName;
@override@OdooString(odooName: 'card_last_4') final  String? cardLast4;
@override@OdooString(odooName: 'authorization_code') final  String? authorizationCode;
// ============ Payment Classification (computed flags) ============
@override@JsonKey()@OdooBoolean(odooName: 'is_card_payment') final  bool isCardPayment;
@override@JsonKey()@OdooBoolean(odooName: 'is_transfer_payment') final  bool isTransferPayment;
@override@JsonKey()@OdooBoolean(odooName: 'is_check_payment') final  bool isCheckPayment;
@override@JsonKey()@OdooBoolean(odooName: 'is_cash_payment') final  bool isCashPayment;
// ============ Sale Order Link ============
@override@OdooMany2One('sale.order', odooName: 'sale_id') final  int? saleId;
@override@OdooMany2One('account.payment', odooName: 'advance_id') final  int? advanceId;
@override@OdooMany2One('res.users', odooName: 'collection_user_id') final  int? collectionUserId;
// ============ Metadata ============
@override@OdooDate() final  DateTime? date;
@override@OdooString() final  String? name;
@override@OdooString() final  String? ref;
// ============ Sync ============
@override@OdooLocalOnly() final  DateTime? lastSyncDate;
@override@OdooDateTime(odooName: 'write_date') final  DateTime? writeDate;

/// Create a copy of AccountPayment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountPaymentCopyWith<_AccountPayment> get copyWith => __$AccountPaymentCopyWithImpl<_AccountPayment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountPaymentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountPayment&&(identical(other.id, id) || other.id == id)&&(identical(other.paymentUuid, paymentUuid) || other.paymentUuid == paymentUuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.paymentMethodLineId, paymentMethodLineId) || other.paymentMethodLineId == paymentMethodLineId)&&(identical(other.paymentMethodLineName, paymentMethodLineName) || other.paymentMethodLineName == paymentMethodLineName)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.paymentType, paymentType) || other.paymentType == paymentType)&&(identical(other.state, state) || other.state == state)&&(identical(other.paymentOriginType, paymentOriginType) || other.paymentOriginType == paymentOriginType)&&(identical(other.paymentMethodCategory, paymentMethodCategory) || other.paymentMethodCategory == paymentMethodCategory)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.checkNumber, checkNumber) || other.checkNumber == checkNumber)&&(identical(other.checkAmountInWords, checkAmountInWords) || other.checkAmountInWords == checkAmountInWords)&&(identical(other.bankReferenceDate, bankReferenceDate) || other.bankReferenceDate == bankReferenceDate)&&(identical(other.esPosfechado, esPosfechado) || other.esPosfechado == esPosfechado)&&(identical(other.chequeRecibidoId, chequeRecibidoId) || other.chequeRecibidoId == chequeRecibidoId)&&(identical(other.cardBrandId, cardBrandId) || other.cardBrandId == cardBrandId)&&(identical(other.cardBrandName, cardBrandName) || other.cardBrandName == cardBrandName)&&(identical(other.cardType, cardType) || other.cardType == cardType)&&(identical(other.loteId, loteId) || other.loteId == loteId)&&(identical(other.cardHolderName, cardHolderName) || other.cardHolderName == cardHolderName)&&(identical(other.cardLast4, cardLast4) || other.cardLast4 == cardLast4)&&(identical(other.authorizationCode, authorizationCode) || other.authorizationCode == authorizationCode)&&(identical(other.isCardPayment, isCardPayment) || other.isCardPayment == isCardPayment)&&(identical(other.isTransferPayment, isTransferPayment) || other.isTransferPayment == isTransferPayment)&&(identical(other.isCheckPayment, isCheckPayment) || other.isCheckPayment == isCheckPayment)&&(identical(other.isCashPayment, isCashPayment) || other.isCashPayment == isCashPayment)&&(identical(other.saleId, saleId) || other.saleId == saleId)&&(identical(other.advanceId, advanceId) || other.advanceId == advanceId)&&(identical(other.collectionUserId, collectionUserId) || other.collectionUserId == collectionUserId)&&(identical(other.date, date) || other.date == date)&&(identical(other.name, name) || other.name == name)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,paymentUuid,isSynced,collectionSessionId,invoiceId,partnerId,partnerName,journalId,journalName,paymentMethodLineId,paymentMethodLineName,amount,paymentType,state,paymentOriginType,paymentMethodCategory,bankId,bankName,checkNumber,checkAmountInWords,bankReferenceDate,esPosfechado,chequeRecibidoId,cardBrandId,cardBrandName,cardType,loteId,cardHolderName,cardLast4,authorizationCode,isCardPayment,isTransferPayment,isCheckPayment,isCashPayment,saleId,advanceId,collectionUserId,date,name,ref,lastSyncDate,writeDate]);

@override
String toString() {
  return 'AccountPayment(id: $id, paymentUuid: $paymentUuid, isSynced: $isSynced, collectionSessionId: $collectionSessionId, invoiceId: $invoiceId, partnerId: $partnerId, partnerName: $partnerName, journalId: $journalId, journalName: $journalName, paymentMethodLineId: $paymentMethodLineId, paymentMethodLineName: $paymentMethodLineName, amount: $amount, paymentType: $paymentType, state: $state, paymentOriginType: $paymentOriginType, paymentMethodCategory: $paymentMethodCategory, bankId: $bankId, bankName: $bankName, checkNumber: $checkNumber, checkAmountInWords: $checkAmountInWords, bankReferenceDate: $bankReferenceDate, esPosfechado: $esPosfechado, chequeRecibidoId: $chequeRecibidoId, cardBrandId: $cardBrandId, cardBrandName: $cardBrandName, cardType: $cardType, loteId: $loteId, cardHolderName: $cardHolderName, cardLast4: $cardLast4, authorizationCode: $authorizationCode, isCardPayment: $isCardPayment, isTransferPayment: $isTransferPayment, isCheckPayment: $isCheckPayment, isCashPayment: $isCashPayment, saleId: $saleId, advanceId: $advanceId, collectionUserId: $collectionUserId, date: $date, name: $name, ref: $ref, lastSyncDate: $lastSyncDate, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$AccountPaymentCopyWith<$Res> implements $AccountPaymentCopyWith<$Res> {
  factory _$AccountPaymentCopyWith(_AccountPayment value, $Res Function(_AccountPayment) _then) = __$AccountPaymentCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? paymentUuid,@OdooLocalOnly() bool isSynced,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooMany2One('account.move', odooName: 'reconciled_invoice_ids') int? invoiceId,@OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') int? paymentMethodLineId,@OdooMany2OneName(sourceField: 'payment_method_line_id') String? paymentMethodLineName,@OdooFloat() double amount,@OdooSelection(odooName: 'payment_type') String paymentType,@OdooSelection() String state,@OdooSelection(odooName: 'payment_origin_type') String? paymentOriginType,@OdooSelection(odooName: 'payment_method_category') String? paymentMethodCategory,@OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,@OdooMany2OneName(sourceField: 'bank_id') String? bankName,@OdooString(odooName: 'check_number') String? checkNumber,@OdooString(odooName: 'check_amount_in_words') String? checkAmountInWords,@OdooDate(odooName: 'bank_reference_date') DateTime? bankReferenceDate,@OdooBoolean(odooName: 'es_posfechado') bool esPosfechado,@OdooMany2One('account.cheque.recibido', odooName: 'cheque_recibido_id') int? chequeRecibidoId,@OdooMany2One('account.card.brand', odooName: 'card_brand_id') int? cardBrandId,@OdooMany2OneName(sourceField: 'card_brand_id') String? cardBrandName,@OdooSelection(odooName: 'card_type') String? cardType,@OdooMany2One('account.card.lote', odooName: 'lote_id') int? loteId,@OdooString(odooName: 'card_holder_name') String? cardHolderName,@OdooString(odooName: 'card_last_4') String? cardLast4,@OdooString(odooName: 'authorization_code') String? authorizationCode,@OdooBoolean(odooName: 'is_card_payment') bool isCardPayment,@OdooBoolean(odooName: 'is_transfer_payment') bool isTransferPayment,@OdooBoolean(odooName: 'is_check_payment') bool isCheckPayment,@OdooBoolean(odooName: 'is_cash_payment') bool isCashPayment,@OdooMany2One('sale.order', odooName: 'sale_id') int? saleId,@OdooMany2One('account.payment', odooName: 'advance_id') int? advanceId,@OdooMany2One('res.users', odooName: 'collection_user_id') int? collectionUserId,@OdooDate() DateTime? date,@OdooString() String? name,@OdooString() String? ref,@OdooLocalOnly() DateTime? lastSyncDate,@OdooDateTime(odooName: 'write_date') DateTime? writeDate
});




}
/// @nodoc
class __$AccountPaymentCopyWithImpl<$Res>
    implements _$AccountPaymentCopyWith<$Res> {
  __$AccountPaymentCopyWithImpl(this._self, this._then);

  final _AccountPayment _self;
  final $Res Function(_AccountPayment) _then;

/// Create a copy of AccountPayment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? paymentUuid = freezed,Object? isSynced = null,Object? collectionSessionId = freezed,Object? invoiceId = freezed,Object? partnerId = freezed,Object? partnerName = freezed,Object? journalId = freezed,Object? journalName = freezed,Object? paymentMethodLineId = freezed,Object? paymentMethodLineName = freezed,Object? amount = null,Object? paymentType = null,Object? state = null,Object? paymentOriginType = freezed,Object? paymentMethodCategory = freezed,Object? bankId = freezed,Object? bankName = freezed,Object? checkNumber = freezed,Object? checkAmountInWords = freezed,Object? bankReferenceDate = freezed,Object? esPosfechado = null,Object? chequeRecibidoId = freezed,Object? cardBrandId = freezed,Object? cardBrandName = freezed,Object? cardType = freezed,Object? loteId = freezed,Object? cardHolderName = freezed,Object? cardLast4 = freezed,Object? authorizationCode = freezed,Object? isCardPayment = null,Object? isTransferPayment = null,Object? isCheckPayment = null,Object? isCashPayment = null,Object? saleId = freezed,Object? advanceId = freezed,Object? collectionUserId = freezed,Object? date = freezed,Object? name = freezed,Object? ref = freezed,Object? lastSyncDate = freezed,Object? writeDate = freezed,}) {
  return _then(_AccountPayment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,paymentUuid: freezed == paymentUuid ? _self.paymentUuid : paymentUuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as int?,partnerId: freezed == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int?,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,journalId: freezed == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int?,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,paymentMethodLineId: freezed == paymentMethodLineId ? _self.paymentMethodLineId : paymentMethodLineId // ignore: cast_nullable_to_non_nullable
as int?,paymentMethodLineName: freezed == paymentMethodLineName ? _self.paymentMethodLineName : paymentMethodLineName // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,paymentType: null == paymentType ? _self.paymentType : paymentType // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,paymentOriginType: freezed == paymentOriginType ? _self.paymentOriginType : paymentOriginType // ignore: cast_nullable_to_non_nullable
as String?,paymentMethodCategory: freezed == paymentMethodCategory ? _self.paymentMethodCategory : paymentMethodCategory // ignore: cast_nullable_to_non_nullable
as String?,bankId: freezed == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as int?,bankName: freezed == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String?,checkNumber: freezed == checkNumber ? _self.checkNumber : checkNumber // ignore: cast_nullable_to_non_nullable
as String?,checkAmountInWords: freezed == checkAmountInWords ? _self.checkAmountInWords : checkAmountInWords // ignore: cast_nullable_to_non_nullable
as String?,bankReferenceDate: freezed == bankReferenceDate ? _self.bankReferenceDate : bankReferenceDate // ignore: cast_nullable_to_non_nullable
as DateTime?,esPosfechado: null == esPosfechado ? _self.esPosfechado : esPosfechado // ignore: cast_nullable_to_non_nullable
as bool,chequeRecibidoId: freezed == chequeRecibidoId ? _self.chequeRecibidoId : chequeRecibidoId // ignore: cast_nullable_to_non_nullable
as int?,cardBrandId: freezed == cardBrandId ? _self.cardBrandId : cardBrandId // ignore: cast_nullable_to_non_nullable
as int?,cardBrandName: freezed == cardBrandName ? _self.cardBrandName : cardBrandName // ignore: cast_nullable_to_non_nullable
as String?,cardType: freezed == cardType ? _self.cardType : cardType // ignore: cast_nullable_to_non_nullable
as String?,loteId: freezed == loteId ? _self.loteId : loteId // ignore: cast_nullable_to_non_nullable
as int?,cardHolderName: freezed == cardHolderName ? _self.cardHolderName : cardHolderName // ignore: cast_nullable_to_non_nullable
as String?,cardLast4: freezed == cardLast4 ? _self.cardLast4 : cardLast4 // ignore: cast_nullable_to_non_nullable
as String?,authorizationCode: freezed == authorizationCode ? _self.authorizationCode : authorizationCode // ignore: cast_nullable_to_non_nullable
as String?,isCardPayment: null == isCardPayment ? _self.isCardPayment : isCardPayment // ignore: cast_nullable_to_non_nullable
as bool,isTransferPayment: null == isTransferPayment ? _self.isTransferPayment : isTransferPayment // ignore: cast_nullable_to_non_nullable
as bool,isCheckPayment: null == isCheckPayment ? _self.isCheckPayment : isCheckPayment // ignore: cast_nullable_to_non_nullable
as bool,isCashPayment: null == isCashPayment ? _self.isCashPayment : isCashPayment // ignore: cast_nullable_to_non_nullable
as bool,saleId: freezed == saleId ? _self.saleId : saleId // ignore: cast_nullable_to_non_nullable
as int?,advanceId: freezed == advanceId ? _self.advanceId : advanceId // ignore: cast_nullable_to_non_nullable
as int?,collectionUserId: freezed == collectionUserId ? _self.collectionUserId : collectionUserId // ignore: cast_nullable_to_non_nullable
as int?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,ref: freezed == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String?,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
