// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_line.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentLine {

// ============ Identifiers ============
@OdooId() int get id;@OdooLocalOnly() String? get lineUuid;@OdooLocalOnly() String? get uuid;@OdooLocalOnly() bool get isSynced;// ============ Core Fields ============
@OdooLocalOnly() PaymentLineType get type;@OdooDate() DateTime get date;@OdooFloat() double get amount;@OdooString(odooName: 'payment_reference') String? get reference;// ============ Order Reference ============
@OdooLocalOnly() int? get orderId;@OdooSelection() String get state;// ============ Payment Journal ============
@OdooMany2One('account.journal', odooName: 'journal_id') int? get journalId;@OdooMany2OneName(sourceField: 'journal_id') String? get journalName;@OdooLocalOnly() String? get journalType;@OdooLocalOnly() int? get paymentMethodId;@OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') int? get paymentMethodLineId;@OdooLocalOnly() String? get paymentMethodCode;@OdooLocalOnly() String? get paymentMethodName;// ============ Card Fields ============
@OdooMany2One('res.bank', odooName: 'bank_id') int? get bankId;@OdooMany2OneName(sourceField: 'bank_id') String? get bankName;@OdooLocalOnly() CardType? get cardType;@OdooMany2One('account.card.brand', odooName: 'card_brand_id') int? get cardBrandId;@OdooMany2OneName(sourceField: 'card_brand_id') String? get cardBrandName;@OdooMany2One('account.card.deadline', odooName: 'card_deadline_id') int? get cardDeadlineId;@OdooMany2OneName(sourceField: 'card_deadline_id') String? get cardDeadlineName;@OdooMany2One('account.card.lote', odooName: 'lote_id') int? get loteId;@OdooMany2OneName(sourceField: 'lote_id') String? get loteName;@OdooDate(odooName: 'bank_reference_date') DateTime? get voucherDate;// ============ Check Fields ============
@OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') int? get partnerBankId;@OdooMany2OneName(sourceField: 'partner_bank_id') String? get partnerBankName;@OdooDate(odooName: 'effective_date') DateTime? get effectiveDate;// ============ Advance Fields ============
@OdooMany2One('account.payment', odooName: 'advance_id') int? get advanceId;@OdooMany2OneName(sourceField: 'advance_id') String? get advanceName;@OdooLocalOnly() double? get advanceAvailable;// ============ Credit Note Fields ============
@OdooMany2One('account.move', odooName: 'credit_note_id') int? get creditNoteId;@OdooMany2OneName(sourceField: 'credit_note_id') String? get creditNoteName;@OdooLocalOnly() double? get creditNoteAvailable;
/// Create a copy of PaymentLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentLineCopyWith<PaymentLine> get copyWith => _$PaymentLineCopyWithImpl<PaymentLine>(this as PaymentLine, _$identity);

  /// Serializes this PaymentLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentLine&&(identical(other.id, id) || other.id == id)&&(identical(other.lineUuid, lineUuid) || other.lineUuid == lineUuid)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.type, type) || other.type == type)&&(identical(other.date, date) || other.date == date)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.state, state) || other.state == state)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.journalType, journalType) || other.journalType == journalType)&&(identical(other.paymentMethodId, paymentMethodId) || other.paymentMethodId == paymentMethodId)&&(identical(other.paymentMethodLineId, paymentMethodLineId) || other.paymentMethodLineId == paymentMethodLineId)&&(identical(other.paymentMethodCode, paymentMethodCode) || other.paymentMethodCode == paymentMethodCode)&&(identical(other.paymentMethodName, paymentMethodName) || other.paymentMethodName == paymentMethodName)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.cardType, cardType) || other.cardType == cardType)&&(identical(other.cardBrandId, cardBrandId) || other.cardBrandId == cardBrandId)&&(identical(other.cardBrandName, cardBrandName) || other.cardBrandName == cardBrandName)&&(identical(other.cardDeadlineId, cardDeadlineId) || other.cardDeadlineId == cardDeadlineId)&&(identical(other.cardDeadlineName, cardDeadlineName) || other.cardDeadlineName == cardDeadlineName)&&(identical(other.loteId, loteId) || other.loteId == loteId)&&(identical(other.loteName, loteName) || other.loteName == loteName)&&(identical(other.voucherDate, voucherDate) || other.voucherDate == voucherDate)&&(identical(other.partnerBankId, partnerBankId) || other.partnerBankId == partnerBankId)&&(identical(other.partnerBankName, partnerBankName) || other.partnerBankName == partnerBankName)&&(identical(other.effectiveDate, effectiveDate) || other.effectiveDate == effectiveDate)&&(identical(other.advanceId, advanceId) || other.advanceId == advanceId)&&(identical(other.advanceName, advanceName) || other.advanceName == advanceName)&&(identical(other.advanceAvailable, advanceAvailable) || other.advanceAvailable == advanceAvailable)&&(identical(other.creditNoteId, creditNoteId) || other.creditNoteId == creditNoteId)&&(identical(other.creditNoteName, creditNoteName) || other.creditNoteName == creditNoteName)&&(identical(other.creditNoteAvailable, creditNoteAvailable) || other.creditNoteAvailable == creditNoteAvailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,lineUuid,uuid,isSynced,type,date,amount,reference,orderId,state,journalId,journalName,journalType,paymentMethodId,paymentMethodLineId,paymentMethodCode,paymentMethodName,bankId,bankName,cardType,cardBrandId,cardBrandName,cardDeadlineId,cardDeadlineName,loteId,loteName,voucherDate,partnerBankId,partnerBankName,effectiveDate,advanceId,advanceName,advanceAvailable,creditNoteId,creditNoteName,creditNoteAvailable]);

@override
String toString() {
  return 'PaymentLine(id: $id, lineUuid: $lineUuid, uuid: $uuid, isSynced: $isSynced, type: $type, date: $date, amount: $amount, reference: $reference, orderId: $orderId, state: $state, journalId: $journalId, journalName: $journalName, journalType: $journalType, paymentMethodId: $paymentMethodId, paymentMethodLineId: $paymentMethodLineId, paymentMethodCode: $paymentMethodCode, paymentMethodName: $paymentMethodName, bankId: $bankId, bankName: $bankName, cardType: $cardType, cardBrandId: $cardBrandId, cardBrandName: $cardBrandName, cardDeadlineId: $cardDeadlineId, cardDeadlineName: $cardDeadlineName, loteId: $loteId, loteName: $loteName, voucherDate: $voucherDate, partnerBankId: $partnerBankId, partnerBankName: $partnerBankName, effectiveDate: $effectiveDate, advanceId: $advanceId, advanceName: $advanceName, advanceAvailable: $advanceAvailable, creditNoteId: $creditNoteId, creditNoteName: $creditNoteName, creditNoteAvailable: $creditNoteAvailable)';
}


}

/// @nodoc
abstract mixin class $PaymentLineCopyWith<$Res>  {
  factory $PaymentLineCopyWith(PaymentLine value, $Res Function(PaymentLine) _then) = _$PaymentLineCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? lineUuid,@OdooLocalOnly() String? uuid,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() PaymentLineType type,@OdooDate() DateTime date,@OdooFloat() double amount,@OdooString(odooName: 'payment_reference') String? reference,@OdooLocalOnly() int? orderId,@OdooSelection() String state,@OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooLocalOnly() String? journalType,@OdooLocalOnly() int? paymentMethodId,@OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') int? paymentMethodLineId,@OdooLocalOnly() String? paymentMethodCode,@OdooLocalOnly() String? paymentMethodName,@OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,@OdooMany2OneName(sourceField: 'bank_id') String? bankName,@OdooLocalOnly() CardType? cardType,@OdooMany2One('account.card.brand', odooName: 'card_brand_id') int? cardBrandId,@OdooMany2OneName(sourceField: 'card_brand_id') String? cardBrandName,@OdooMany2One('account.card.deadline', odooName: 'card_deadline_id') int? cardDeadlineId,@OdooMany2OneName(sourceField: 'card_deadline_id') String? cardDeadlineName,@OdooMany2One('account.card.lote', odooName: 'lote_id') int? loteId,@OdooMany2OneName(sourceField: 'lote_id') String? loteName,@OdooDate(odooName: 'bank_reference_date') DateTime? voucherDate,@OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') int? partnerBankId,@OdooMany2OneName(sourceField: 'partner_bank_id') String? partnerBankName,@OdooDate(odooName: 'effective_date') DateTime? effectiveDate,@OdooMany2One('account.payment', odooName: 'advance_id') int? advanceId,@OdooMany2OneName(sourceField: 'advance_id') String? advanceName,@OdooLocalOnly() double? advanceAvailable,@OdooMany2One('account.move', odooName: 'credit_note_id') int? creditNoteId,@OdooMany2OneName(sourceField: 'credit_note_id') String? creditNoteName,@OdooLocalOnly() double? creditNoteAvailable
});




}
/// @nodoc
class _$PaymentLineCopyWithImpl<$Res>
    implements $PaymentLineCopyWith<$Res> {
  _$PaymentLineCopyWithImpl(this._self, this._then);

  final PaymentLine _self;
  final $Res Function(PaymentLine) _then;

/// Create a copy of PaymentLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? lineUuid = freezed,Object? uuid = freezed,Object? isSynced = null,Object? type = null,Object? date = null,Object? amount = null,Object? reference = freezed,Object? orderId = freezed,Object? state = null,Object? journalId = freezed,Object? journalName = freezed,Object? journalType = freezed,Object? paymentMethodId = freezed,Object? paymentMethodLineId = freezed,Object? paymentMethodCode = freezed,Object? paymentMethodName = freezed,Object? bankId = freezed,Object? bankName = freezed,Object? cardType = freezed,Object? cardBrandId = freezed,Object? cardBrandName = freezed,Object? cardDeadlineId = freezed,Object? cardDeadlineName = freezed,Object? loteId = freezed,Object? loteName = freezed,Object? voucherDate = freezed,Object? partnerBankId = freezed,Object? partnerBankName = freezed,Object? effectiveDate = freezed,Object? advanceId = freezed,Object? advanceName = freezed,Object? advanceAvailable = freezed,Object? creditNoteId = freezed,Object? creditNoteName = freezed,Object? creditNoteAvailable = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,lineUuid: freezed == lineUuid ? _self.lineUuid : lineUuid // ignore: cast_nullable_to_non_nullable
as String?,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as PaymentLineType,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String?,orderId: freezed == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as int?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,journalId: freezed == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int?,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,journalType: freezed == journalType ? _self.journalType : journalType // ignore: cast_nullable_to_non_nullable
as String?,paymentMethodId: freezed == paymentMethodId ? _self.paymentMethodId : paymentMethodId // ignore: cast_nullable_to_non_nullable
as int?,paymentMethodLineId: freezed == paymentMethodLineId ? _self.paymentMethodLineId : paymentMethodLineId // ignore: cast_nullable_to_non_nullable
as int?,paymentMethodCode: freezed == paymentMethodCode ? _self.paymentMethodCode : paymentMethodCode // ignore: cast_nullable_to_non_nullable
as String?,paymentMethodName: freezed == paymentMethodName ? _self.paymentMethodName : paymentMethodName // ignore: cast_nullable_to_non_nullable
as String?,bankId: freezed == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as int?,bankName: freezed == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String?,cardType: freezed == cardType ? _self.cardType : cardType // ignore: cast_nullable_to_non_nullable
as CardType?,cardBrandId: freezed == cardBrandId ? _self.cardBrandId : cardBrandId // ignore: cast_nullable_to_non_nullable
as int?,cardBrandName: freezed == cardBrandName ? _self.cardBrandName : cardBrandName // ignore: cast_nullable_to_non_nullable
as String?,cardDeadlineId: freezed == cardDeadlineId ? _self.cardDeadlineId : cardDeadlineId // ignore: cast_nullable_to_non_nullable
as int?,cardDeadlineName: freezed == cardDeadlineName ? _self.cardDeadlineName : cardDeadlineName // ignore: cast_nullable_to_non_nullable
as String?,loteId: freezed == loteId ? _self.loteId : loteId // ignore: cast_nullable_to_non_nullable
as int?,loteName: freezed == loteName ? _self.loteName : loteName // ignore: cast_nullable_to_non_nullable
as String?,voucherDate: freezed == voucherDate ? _self.voucherDate : voucherDate // ignore: cast_nullable_to_non_nullable
as DateTime?,partnerBankId: freezed == partnerBankId ? _self.partnerBankId : partnerBankId // ignore: cast_nullable_to_non_nullable
as int?,partnerBankName: freezed == partnerBankName ? _self.partnerBankName : partnerBankName // ignore: cast_nullable_to_non_nullable
as String?,effectiveDate: freezed == effectiveDate ? _self.effectiveDate : effectiveDate // ignore: cast_nullable_to_non_nullable
as DateTime?,advanceId: freezed == advanceId ? _self.advanceId : advanceId // ignore: cast_nullable_to_non_nullable
as int?,advanceName: freezed == advanceName ? _self.advanceName : advanceName // ignore: cast_nullable_to_non_nullable
as String?,advanceAvailable: freezed == advanceAvailable ? _self.advanceAvailable : advanceAvailable // ignore: cast_nullable_to_non_nullable
as double?,creditNoteId: freezed == creditNoteId ? _self.creditNoteId : creditNoteId // ignore: cast_nullable_to_non_nullable
as int?,creditNoteName: freezed == creditNoteName ? _self.creditNoteName : creditNoteName // ignore: cast_nullable_to_non_nullable
as String?,creditNoteAvailable: freezed == creditNoteAvailable ? _self.creditNoteAvailable : creditNoteAvailable // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentLine].
extension PaymentLinePatterns on PaymentLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentLine value)  $default,){
final _that = this;
switch (_that) {
case _PaymentLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentLine value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? lineUuid, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  PaymentLineType type, @OdooDate()  DateTime date, @OdooFloat()  double amount, @OdooString(odooName: 'payment_reference')  String? reference, @OdooLocalOnly()  int? orderId, @OdooSelection()  String state, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooLocalOnly()  String? journalType, @OdooLocalOnly()  int? paymentMethodId, @OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id')  int? paymentMethodLineId, @OdooLocalOnly()  String? paymentMethodCode, @OdooLocalOnly()  String? paymentMethodName, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooMany2OneName(sourceField: 'bank_id')  String? bankName, @OdooLocalOnly()  CardType? cardType, @OdooMany2One('account.card.brand', odooName: 'card_brand_id')  int? cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id')  String? cardBrandName, @OdooMany2One('account.card.deadline', odooName: 'card_deadline_id')  int? cardDeadlineId, @OdooMany2OneName(sourceField: 'card_deadline_id')  String? cardDeadlineName, @OdooMany2One('account.card.lote', odooName: 'lote_id')  int? loteId, @OdooMany2OneName(sourceField: 'lote_id')  String? loteName, @OdooDate(odooName: 'bank_reference_date')  DateTime? voucherDate, @OdooMany2One('res.partner.bank', odooName: 'partner_bank_id')  int? partnerBankId, @OdooMany2OneName(sourceField: 'partner_bank_id')  String? partnerBankName, @OdooDate(odooName: 'effective_date')  DateTime? effectiveDate, @OdooMany2One('account.payment', odooName: 'advance_id')  int? advanceId, @OdooMany2OneName(sourceField: 'advance_id')  String? advanceName, @OdooLocalOnly()  double? advanceAvailable, @OdooMany2One('account.move', odooName: 'credit_note_id')  int? creditNoteId, @OdooMany2OneName(sourceField: 'credit_note_id')  String? creditNoteName, @OdooLocalOnly()  double? creditNoteAvailable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentLine() when $default != null:
return $default(_that.id,_that.lineUuid,_that.uuid,_that.isSynced,_that.type,_that.date,_that.amount,_that.reference,_that.orderId,_that.state,_that.journalId,_that.journalName,_that.journalType,_that.paymentMethodId,_that.paymentMethodLineId,_that.paymentMethodCode,_that.paymentMethodName,_that.bankId,_that.bankName,_that.cardType,_that.cardBrandId,_that.cardBrandName,_that.cardDeadlineId,_that.cardDeadlineName,_that.loteId,_that.loteName,_that.voucherDate,_that.partnerBankId,_that.partnerBankName,_that.effectiveDate,_that.advanceId,_that.advanceName,_that.advanceAvailable,_that.creditNoteId,_that.creditNoteName,_that.creditNoteAvailable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? lineUuid, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  PaymentLineType type, @OdooDate()  DateTime date, @OdooFloat()  double amount, @OdooString(odooName: 'payment_reference')  String? reference, @OdooLocalOnly()  int? orderId, @OdooSelection()  String state, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooLocalOnly()  String? journalType, @OdooLocalOnly()  int? paymentMethodId, @OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id')  int? paymentMethodLineId, @OdooLocalOnly()  String? paymentMethodCode, @OdooLocalOnly()  String? paymentMethodName, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooMany2OneName(sourceField: 'bank_id')  String? bankName, @OdooLocalOnly()  CardType? cardType, @OdooMany2One('account.card.brand', odooName: 'card_brand_id')  int? cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id')  String? cardBrandName, @OdooMany2One('account.card.deadline', odooName: 'card_deadline_id')  int? cardDeadlineId, @OdooMany2OneName(sourceField: 'card_deadline_id')  String? cardDeadlineName, @OdooMany2One('account.card.lote', odooName: 'lote_id')  int? loteId, @OdooMany2OneName(sourceField: 'lote_id')  String? loteName, @OdooDate(odooName: 'bank_reference_date')  DateTime? voucherDate, @OdooMany2One('res.partner.bank', odooName: 'partner_bank_id')  int? partnerBankId, @OdooMany2OneName(sourceField: 'partner_bank_id')  String? partnerBankName, @OdooDate(odooName: 'effective_date')  DateTime? effectiveDate, @OdooMany2One('account.payment', odooName: 'advance_id')  int? advanceId, @OdooMany2OneName(sourceField: 'advance_id')  String? advanceName, @OdooLocalOnly()  double? advanceAvailable, @OdooMany2One('account.move', odooName: 'credit_note_id')  int? creditNoteId, @OdooMany2OneName(sourceField: 'credit_note_id')  String? creditNoteName, @OdooLocalOnly()  double? creditNoteAvailable)  $default,) {final _that = this;
switch (_that) {
case _PaymentLine():
return $default(_that.id,_that.lineUuid,_that.uuid,_that.isSynced,_that.type,_that.date,_that.amount,_that.reference,_that.orderId,_that.state,_that.journalId,_that.journalName,_that.journalType,_that.paymentMethodId,_that.paymentMethodLineId,_that.paymentMethodCode,_that.paymentMethodName,_that.bankId,_that.bankName,_that.cardType,_that.cardBrandId,_that.cardBrandName,_that.cardDeadlineId,_that.cardDeadlineName,_that.loteId,_that.loteName,_that.voucherDate,_that.partnerBankId,_that.partnerBankName,_that.effectiveDate,_that.advanceId,_that.advanceName,_that.advanceAvailable,_that.creditNoteId,_that.creditNoteName,_that.creditNoteAvailable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? lineUuid, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  PaymentLineType type, @OdooDate()  DateTime date, @OdooFloat()  double amount, @OdooString(odooName: 'payment_reference')  String? reference, @OdooLocalOnly()  int? orderId, @OdooSelection()  String state, @OdooMany2One('account.journal', odooName: 'journal_id')  int? journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooLocalOnly()  String? journalType, @OdooLocalOnly()  int? paymentMethodId, @OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id')  int? paymentMethodLineId, @OdooLocalOnly()  String? paymentMethodCode, @OdooLocalOnly()  String? paymentMethodName, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooMany2OneName(sourceField: 'bank_id')  String? bankName, @OdooLocalOnly()  CardType? cardType, @OdooMany2One('account.card.brand', odooName: 'card_brand_id')  int? cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id')  String? cardBrandName, @OdooMany2One('account.card.deadline', odooName: 'card_deadline_id')  int? cardDeadlineId, @OdooMany2OneName(sourceField: 'card_deadline_id')  String? cardDeadlineName, @OdooMany2One('account.card.lote', odooName: 'lote_id')  int? loteId, @OdooMany2OneName(sourceField: 'lote_id')  String? loteName, @OdooDate(odooName: 'bank_reference_date')  DateTime? voucherDate, @OdooMany2One('res.partner.bank', odooName: 'partner_bank_id')  int? partnerBankId, @OdooMany2OneName(sourceField: 'partner_bank_id')  String? partnerBankName, @OdooDate(odooName: 'effective_date')  DateTime? effectiveDate, @OdooMany2One('account.payment', odooName: 'advance_id')  int? advanceId, @OdooMany2OneName(sourceField: 'advance_id')  String? advanceName, @OdooLocalOnly()  double? advanceAvailable, @OdooMany2One('account.move', odooName: 'credit_note_id')  int? creditNoteId, @OdooMany2OneName(sourceField: 'credit_note_id')  String? creditNoteName, @OdooLocalOnly()  double? creditNoteAvailable)?  $default,) {final _that = this;
switch (_that) {
case _PaymentLine() when $default != null:
return $default(_that.id,_that.lineUuid,_that.uuid,_that.isSynced,_that.type,_that.date,_that.amount,_that.reference,_that.orderId,_that.state,_that.journalId,_that.journalName,_that.journalType,_that.paymentMethodId,_that.paymentMethodLineId,_that.paymentMethodCode,_that.paymentMethodName,_that.bankId,_that.bankName,_that.cardType,_that.cardBrandId,_that.cardBrandName,_that.cardDeadlineId,_that.cardDeadlineName,_that.loteId,_that.loteName,_that.voucherDate,_that.partnerBankId,_that.partnerBankName,_that.effectiveDate,_that.advanceId,_that.advanceName,_that.advanceAvailable,_that.creditNoteId,_that.creditNoteName,_that.creditNoteAvailable);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentLine extends PaymentLine {
  const _PaymentLine({@OdooId() this.id = 0, @OdooLocalOnly() this.lineUuid, @OdooLocalOnly() this.uuid, @OdooLocalOnly() this.isSynced = false, @OdooLocalOnly() required this.type, @OdooDate() required this.date, @OdooFloat() required this.amount, @OdooString(odooName: 'payment_reference') this.reference, @OdooLocalOnly() this.orderId, @OdooSelection() this.state = 'draft', @OdooMany2One('account.journal', odooName: 'journal_id') this.journalId, @OdooMany2OneName(sourceField: 'journal_id') this.journalName, @OdooLocalOnly() this.journalType, @OdooLocalOnly() this.paymentMethodId, @OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') this.paymentMethodLineId, @OdooLocalOnly() this.paymentMethodCode, @OdooLocalOnly() this.paymentMethodName, @OdooMany2One('res.bank', odooName: 'bank_id') this.bankId, @OdooMany2OneName(sourceField: 'bank_id') this.bankName, @OdooLocalOnly() this.cardType, @OdooMany2One('account.card.brand', odooName: 'card_brand_id') this.cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id') this.cardBrandName, @OdooMany2One('account.card.deadline', odooName: 'card_deadline_id') this.cardDeadlineId, @OdooMany2OneName(sourceField: 'card_deadline_id') this.cardDeadlineName, @OdooMany2One('account.card.lote', odooName: 'lote_id') this.loteId, @OdooMany2OneName(sourceField: 'lote_id') this.loteName, @OdooDate(odooName: 'bank_reference_date') this.voucherDate, @OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') this.partnerBankId, @OdooMany2OneName(sourceField: 'partner_bank_id') this.partnerBankName, @OdooDate(odooName: 'effective_date') this.effectiveDate, @OdooMany2One('account.payment', odooName: 'advance_id') this.advanceId, @OdooMany2OneName(sourceField: 'advance_id') this.advanceName, @OdooLocalOnly() this.advanceAvailable, @OdooMany2One('account.move', odooName: 'credit_note_id') this.creditNoteId, @OdooMany2OneName(sourceField: 'credit_note_id') this.creditNoteName, @OdooLocalOnly() this.creditNoteAvailable}): super._();
  factory _PaymentLine.fromJson(Map<String, dynamic> json) => _$PaymentLineFromJson(json);

// ============ Identifiers ============
@override@JsonKey()@OdooId() final  int id;
@override@OdooLocalOnly() final  String? lineUuid;
@override@OdooLocalOnly() final  String? uuid;
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
// ============ Core Fields ============
@override@OdooLocalOnly() final  PaymentLineType type;
@override@OdooDate() final  DateTime date;
@override@OdooFloat() final  double amount;
@override@OdooString(odooName: 'payment_reference') final  String? reference;
// ============ Order Reference ============
@override@OdooLocalOnly() final  int? orderId;
@override@JsonKey()@OdooSelection() final  String state;
// ============ Payment Journal ============
@override@OdooMany2One('account.journal', odooName: 'journal_id') final  int? journalId;
@override@OdooMany2OneName(sourceField: 'journal_id') final  String? journalName;
@override@OdooLocalOnly() final  String? journalType;
@override@OdooLocalOnly() final  int? paymentMethodId;
@override@OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') final  int? paymentMethodLineId;
@override@OdooLocalOnly() final  String? paymentMethodCode;
@override@OdooLocalOnly() final  String? paymentMethodName;
// ============ Card Fields ============
@override@OdooMany2One('res.bank', odooName: 'bank_id') final  int? bankId;
@override@OdooMany2OneName(sourceField: 'bank_id') final  String? bankName;
@override@OdooLocalOnly() final  CardType? cardType;
@override@OdooMany2One('account.card.brand', odooName: 'card_brand_id') final  int? cardBrandId;
@override@OdooMany2OneName(sourceField: 'card_brand_id') final  String? cardBrandName;
@override@OdooMany2One('account.card.deadline', odooName: 'card_deadline_id') final  int? cardDeadlineId;
@override@OdooMany2OneName(sourceField: 'card_deadline_id') final  String? cardDeadlineName;
@override@OdooMany2One('account.card.lote', odooName: 'lote_id') final  int? loteId;
@override@OdooMany2OneName(sourceField: 'lote_id') final  String? loteName;
@override@OdooDate(odooName: 'bank_reference_date') final  DateTime? voucherDate;
// ============ Check Fields ============
@override@OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') final  int? partnerBankId;
@override@OdooMany2OneName(sourceField: 'partner_bank_id') final  String? partnerBankName;
@override@OdooDate(odooName: 'effective_date') final  DateTime? effectiveDate;
// ============ Advance Fields ============
@override@OdooMany2One('account.payment', odooName: 'advance_id') final  int? advanceId;
@override@OdooMany2OneName(sourceField: 'advance_id') final  String? advanceName;
@override@OdooLocalOnly() final  double? advanceAvailable;
// ============ Credit Note Fields ============
@override@OdooMany2One('account.move', odooName: 'credit_note_id') final  int? creditNoteId;
@override@OdooMany2OneName(sourceField: 'credit_note_id') final  String? creditNoteName;
@override@OdooLocalOnly() final  double? creditNoteAvailable;

/// Create a copy of PaymentLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentLineCopyWith<_PaymentLine> get copyWith => __$PaymentLineCopyWithImpl<_PaymentLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentLine&&(identical(other.id, id) || other.id == id)&&(identical(other.lineUuid, lineUuid) || other.lineUuid == lineUuid)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.type, type) || other.type == type)&&(identical(other.date, date) || other.date == date)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.state, state) || other.state == state)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.journalType, journalType) || other.journalType == journalType)&&(identical(other.paymentMethodId, paymentMethodId) || other.paymentMethodId == paymentMethodId)&&(identical(other.paymentMethodLineId, paymentMethodLineId) || other.paymentMethodLineId == paymentMethodLineId)&&(identical(other.paymentMethodCode, paymentMethodCode) || other.paymentMethodCode == paymentMethodCode)&&(identical(other.paymentMethodName, paymentMethodName) || other.paymentMethodName == paymentMethodName)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.cardType, cardType) || other.cardType == cardType)&&(identical(other.cardBrandId, cardBrandId) || other.cardBrandId == cardBrandId)&&(identical(other.cardBrandName, cardBrandName) || other.cardBrandName == cardBrandName)&&(identical(other.cardDeadlineId, cardDeadlineId) || other.cardDeadlineId == cardDeadlineId)&&(identical(other.cardDeadlineName, cardDeadlineName) || other.cardDeadlineName == cardDeadlineName)&&(identical(other.loteId, loteId) || other.loteId == loteId)&&(identical(other.loteName, loteName) || other.loteName == loteName)&&(identical(other.voucherDate, voucherDate) || other.voucherDate == voucherDate)&&(identical(other.partnerBankId, partnerBankId) || other.partnerBankId == partnerBankId)&&(identical(other.partnerBankName, partnerBankName) || other.partnerBankName == partnerBankName)&&(identical(other.effectiveDate, effectiveDate) || other.effectiveDate == effectiveDate)&&(identical(other.advanceId, advanceId) || other.advanceId == advanceId)&&(identical(other.advanceName, advanceName) || other.advanceName == advanceName)&&(identical(other.advanceAvailable, advanceAvailable) || other.advanceAvailable == advanceAvailable)&&(identical(other.creditNoteId, creditNoteId) || other.creditNoteId == creditNoteId)&&(identical(other.creditNoteName, creditNoteName) || other.creditNoteName == creditNoteName)&&(identical(other.creditNoteAvailable, creditNoteAvailable) || other.creditNoteAvailable == creditNoteAvailable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,lineUuid,uuid,isSynced,type,date,amount,reference,orderId,state,journalId,journalName,journalType,paymentMethodId,paymentMethodLineId,paymentMethodCode,paymentMethodName,bankId,bankName,cardType,cardBrandId,cardBrandName,cardDeadlineId,cardDeadlineName,loteId,loteName,voucherDate,partnerBankId,partnerBankName,effectiveDate,advanceId,advanceName,advanceAvailable,creditNoteId,creditNoteName,creditNoteAvailable]);

@override
String toString() {
  return 'PaymentLine(id: $id, lineUuid: $lineUuid, uuid: $uuid, isSynced: $isSynced, type: $type, date: $date, amount: $amount, reference: $reference, orderId: $orderId, state: $state, journalId: $journalId, journalName: $journalName, journalType: $journalType, paymentMethodId: $paymentMethodId, paymentMethodLineId: $paymentMethodLineId, paymentMethodCode: $paymentMethodCode, paymentMethodName: $paymentMethodName, bankId: $bankId, bankName: $bankName, cardType: $cardType, cardBrandId: $cardBrandId, cardBrandName: $cardBrandName, cardDeadlineId: $cardDeadlineId, cardDeadlineName: $cardDeadlineName, loteId: $loteId, loteName: $loteName, voucherDate: $voucherDate, partnerBankId: $partnerBankId, partnerBankName: $partnerBankName, effectiveDate: $effectiveDate, advanceId: $advanceId, advanceName: $advanceName, advanceAvailable: $advanceAvailable, creditNoteId: $creditNoteId, creditNoteName: $creditNoteName, creditNoteAvailable: $creditNoteAvailable)';
}


}

/// @nodoc
abstract mixin class _$PaymentLineCopyWith<$Res> implements $PaymentLineCopyWith<$Res> {
  factory _$PaymentLineCopyWith(_PaymentLine value, $Res Function(_PaymentLine) _then) = __$PaymentLineCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? lineUuid,@OdooLocalOnly() String? uuid,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() PaymentLineType type,@OdooDate() DateTime date,@OdooFloat() double amount,@OdooString(odooName: 'payment_reference') String? reference,@OdooLocalOnly() int? orderId,@OdooSelection() String state,@OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooLocalOnly() String? journalType,@OdooLocalOnly() int? paymentMethodId,@OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') int? paymentMethodLineId,@OdooLocalOnly() String? paymentMethodCode,@OdooLocalOnly() String? paymentMethodName,@OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,@OdooMany2OneName(sourceField: 'bank_id') String? bankName,@OdooLocalOnly() CardType? cardType,@OdooMany2One('account.card.brand', odooName: 'card_brand_id') int? cardBrandId,@OdooMany2OneName(sourceField: 'card_brand_id') String? cardBrandName,@OdooMany2One('account.card.deadline', odooName: 'card_deadline_id') int? cardDeadlineId,@OdooMany2OneName(sourceField: 'card_deadline_id') String? cardDeadlineName,@OdooMany2One('account.card.lote', odooName: 'lote_id') int? loteId,@OdooMany2OneName(sourceField: 'lote_id') String? loteName,@OdooDate(odooName: 'bank_reference_date') DateTime? voucherDate,@OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') int? partnerBankId,@OdooMany2OneName(sourceField: 'partner_bank_id') String? partnerBankName,@OdooDate(odooName: 'effective_date') DateTime? effectiveDate,@OdooMany2One('account.payment', odooName: 'advance_id') int? advanceId,@OdooMany2OneName(sourceField: 'advance_id') String? advanceName,@OdooLocalOnly() double? advanceAvailable,@OdooMany2One('account.move', odooName: 'credit_note_id') int? creditNoteId,@OdooMany2OneName(sourceField: 'credit_note_id') String? creditNoteName,@OdooLocalOnly() double? creditNoteAvailable
});




}
/// @nodoc
class __$PaymentLineCopyWithImpl<$Res>
    implements _$PaymentLineCopyWith<$Res> {
  __$PaymentLineCopyWithImpl(this._self, this._then);

  final _PaymentLine _self;
  final $Res Function(_PaymentLine) _then;

/// Create a copy of PaymentLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? lineUuid = freezed,Object? uuid = freezed,Object? isSynced = null,Object? type = null,Object? date = null,Object? amount = null,Object? reference = freezed,Object? orderId = freezed,Object? state = null,Object? journalId = freezed,Object? journalName = freezed,Object? journalType = freezed,Object? paymentMethodId = freezed,Object? paymentMethodLineId = freezed,Object? paymentMethodCode = freezed,Object? paymentMethodName = freezed,Object? bankId = freezed,Object? bankName = freezed,Object? cardType = freezed,Object? cardBrandId = freezed,Object? cardBrandName = freezed,Object? cardDeadlineId = freezed,Object? cardDeadlineName = freezed,Object? loteId = freezed,Object? loteName = freezed,Object? voucherDate = freezed,Object? partnerBankId = freezed,Object? partnerBankName = freezed,Object? effectiveDate = freezed,Object? advanceId = freezed,Object? advanceName = freezed,Object? advanceAvailable = freezed,Object? creditNoteId = freezed,Object? creditNoteName = freezed,Object? creditNoteAvailable = freezed,}) {
  return _then(_PaymentLine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,lineUuid: freezed == lineUuid ? _self.lineUuid : lineUuid // ignore: cast_nullable_to_non_nullable
as String?,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as PaymentLineType,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String?,orderId: freezed == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as int?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,journalId: freezed == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int?,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,journalType: freezed == journalType ? _self.journalType : journalType // ignore: cast_nullable_to_non_nullable
as String?,paymentMethodId: freezed == paymentMethodId ? _self.paymentMethodId : paymentMethodId // ignore: cast_nullable_to_non_nullable
as int?,paymentMethodLineId: freezed == paymentMethodLineId ? _self.paymentMethodLineId : paymentMethodLineId // ignore: cast_nullable_to_non_nullable
as int?,paymentMethodCode: freezed == paymentMethodCode ? _self.paymentMethodCode : paymentMethodCode // ignore: cast_nullable_to_non_nullable
as String?,paymentMethodName: freezed == paymentMethodName ? _self.paymentMethodName : paymentMethodName // ignore: cast_nullable_to_non_nullable
as String?,bankId: freezed == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as int?,bankName: freezed == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String?,cardType: freezed == cardType ? _self.cardType : cardType // ignore: cast_nullable_to_non_nullable
as CardType?,cardBrandId: freezed == cardBrandId ? _self.cardBrandId : cardBrandId // ignore: cast_nullable_to_non_nullable
as int?,cardBrandName: freezed == cardBrandName ? _self.cardBrandName : cardBrandName // ignore: cast_nullable_to_non_nullable
as String?,cardDeadlineId: freezed == cardDeadlineId ? _self.cardDeadlineId : cardDeadlineId // ignore: cast_nullable_to_non_nullable
as int?,cardDeadlineName: freezed == cardDeadlineName ? _self.cardDeadlineName : cardDeadlineName // ignore: cast_nullable_to_non_nullable
as String?,loteId: freezed == loteId ? _self.loteId : loteId // ignore: cast_nullable_to_non_nullable
as int?,loteName: freezed == loteName ? _self.loteName : loteName // ignore: cast_nullable_to_non_nullable
as String?,voucherDate: freezed == voucherDate ? _self.voucherDate : voucherDate // ignore: cast_nullable_to_non_nullable
as DateTime?,partnerBankId: freezed == partnerBankId ? _self.partnerBankId : partnerBankId // ignore: cast_nullable_to_non_nullable
as int?,partnerBankName: freezed == partnerBankName ? _self.partnerBankName : partnerBankName // ignore: cast_nullable_to_non_nullable
as String?,effectiveDate: freezed == effectiveDate ? _self.effectiveDate : effectiveDate // ignore: cast_nullable_to_non_nullable
as DateTime?,advanceId: freezed == advanceId ? _self.advanceId : advanceId // ignore: cast_nullable_to_non_nullable
as int?,advanceName: freezed == advanceName ? _self.advanceName : advanceName // ignore: cast_nullable_to_non_nullable
as String?,advanceAvailable: freezed == advanceAvailable ? _self.advanceAvailable : advanceAvailable // ignore: cast_nullable_to_non_nullable
as double?,creditNoteId: freezed == creditNoteId ? _self.creditNoteId : creditNoteId // ignore: cast_nullable_to_non_nullable
as int?,creditNoteName: freezed == creditNoteName ? _self.creditNoteName : creditNoteName // ignore: cast_nullable_to_non_nullable
as String?,creditNoteAvailable: freezed == creditNoteAvailable ? _self.creditNoteAvailable : creditNoteAvailable // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$AvailableJournal {

 int get id; String get name; String get type; bool get isCardJournal; List<PaymentMethod> get paymentMethods; List<int> get cardBrandIds; int? get defaultCardBrandId; List<int> get deadlineCreditIds; List<int> get deadlineDebitIds; int? get defaultDeadlineCreditId; int? get defaultDeadlineDebitId;
/// Create a copy of AvailableJournal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvailableJournalCopyWith<AvailableJournal> get copyWith => _$AvailableJournalCopyWithImpl<AvailableJournal>(this as AvailableJournal, _$identity);

  /// Serializes this AvailableJournal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvailableJournal&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.isCardJournal, isCardJournal) || other.isCardJournal == isCardJournal)&&const DeepCollectionEquality().equals(other.paymentMethods, paymentMethods)&&const DeepCollectionEquality().equals(other.cardBrandIds, cardBrandIds)&&(identical(other.defaultCardBrandId, defaultCardBrandId) || other.defaultCardBrandId == defaultCardBrandId)&&const DeepCollectionEquality().equals(other.deadlineCreditIds, deadlineCreditIds)&&const DeepCollectionEquality().equals(other.deadlineDebitIds, deadlineDebitIds)&&(identical(other.defaultDeadlineCreditId, defaultDeadlineCreditId) || other.defaultDeadlineCreditId == defaultDeadlineCreditId)&&(identical(other.defaultDeadlineDebitId, defaultDeadlineDebitId) || other.defaultDeadlineDebitId == defaultDeadlineDebitId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,isCardJournal,const DeepCollectionEquality().hash(paymentMethods),const DeepCollectionEquality().hash(cardBrandIds),defaultCardBrandId,const DeepCollectionEquality().hash(deadlineCreditIds),const DeepCollectionEquality().hash(deadlineDebitIds),defaultDeadlineCreditId,defaultDeadlineDebitId);

@override
String toString() {
  return 'AvailableJournal(id: $id, name: $name, type: $type, isCardJournal: $isCardJournal, paymentMethods: $paymentMethods, cardBrandIds: $cardBrandIds, defaultCardBrandId: $defaultCardBrandId, deadlineCreditIds: $deadlineCreditIds, deadlineDebitIds: $deadlineDebitIds, defaultDeadlineCreditId: $defaultDeadlineCreditId, defaultDeadlineDebitId: $defaultDeadlineDebitId)';
}


}

/// @nodoc
abstract mixin class $AvailableJournalCopyWith<$Res>  {
  factory $AvailableJournalCopyWith(AvailableJournal value, $Res Function(AvailableJournal) _then) = _$AvailableJournalCopyWithImpl;
@useResult
$Res call({
 int id, String name, String type, bool isCardJournal, List<PaymentMethod> paymentMethods, List<int> cardBrandIds, int? defaultCardBrandId, List<int> deadlineCreditIds, List<int> deadlineDebitIds, int? defaultDeadlineCreditId, int? defaultDeadlineDebitId
});




}
/// @nodoc
class _$AvailableJournalCopyWithImpl<$Res>
    implements $AvailableJournalCopyWith<$Res> {
  _$AvailableJournalCopyWithImpl(this._self, this._then);

  final AvailableJournal _self;
  final $Res Function(AvailableJournal) _then;

/// Create a copy of AvailableJournal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? isCardJournal = null,Object? paymentMethods = null,Object? cardBrandIds = null,Object? defaultCardBrandId = freezed,Object? deadlineCreditIds = null,Object? deadlineDebitIds = null,Object? defaultDeadlineCreditId = freezed,Object? defaultDeadlineDebitId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,isCardJournal: null == isCardJournal ? _self.isCardJournal : isCardJournal // ignore: cast_nullable_to_non_nullable
as bool,paymentMethods: null == paymentMethods ? _self.paymentMethods : paymentMethods // ignore: cast_nullable_to_non_nullable
as List<PaymentMethod>,cardBrandIds: null == cardBrandIds ? _self.cardBrandIds : cardBrandIds // ignore: cast_nullable_to_non_nullable
as List<int>,defaultCardBrandId: freezed == defaultCardBrandId ? _self.defaultCardBrandId : defaultCardBrandId // ignore: cast_nullable_to_non_nullable
as int?,deadlineCreditIds: null == deadlineCreditIds ? _self.deadlineCreditIds : deadlineCreditIds // ignore: cast_nullable_to_non_nullable
as List<int>,deadlineDebitIds: null == deadlineDebitIds ? _self.deadlineDebitIds : deadlineDebitIds // ignore: cast_nullable_to_non_nullable
as List<int>,defaultDeadlineCreditId: freezed == defaultDeadlineCreditId ? _self.defaultDeadlineCreditId : defaultDeadlineCreditId // ignore: cast_nullable_to_non_nullable
as int?,defaultDeadlineDebitId: freezed == defaultDeadlineDebitId ? _self.defaultDeadlineDebitId : defaultDeadlineDebitId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AvailableJournal].
extension AvailableJournalPatterns on AvailableJournal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AvailableJournal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AvailableJournal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AvailableJournal value)  $default,){
final _that = this;
switch (_that) {
case _AvailableJournal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AvailableJournal value)?  $default,){
final _that = this;
switch (_that) {
case _AvailableJournal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String type,  bool isCardJournal,  List<PaymentMethod> paymentMethods,  List<int> cardBrandIds,  int? defaultCardBrandId,  List<int> deadlineCreditIds,  List<int> deadlineDebitIds,  int? defaultDeadlineCreditId,  int? defaultDeadlineDebitId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AvailableJournal() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.isCardJournal,_that.paymentMethods,_that.cardBrandIds,_that.defaultCardBrandId,_that.deadlineCreditIds,_that.deadlineDebitIds,_that.defaultDeadlineCreditId,_that.defaultDeadlineDebitId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String type,  bool isCardJournal,  List<PaymentMethod> paymentMethods,  List<int> cardBrandIds,  int? defaultCardBrandId,  List<int> deadlineCreditIds,  List<int> deadlineDebitIds,  int? defaultDeadlineCreditId,  int? defaultDeadlineDebitId)  $default,) {final _that = this;
switch (_that) {
case _AvailableJournal():
return $default(_that.id,_that.name,_that.type,_that.isCardJournal,_that.paymentMethods,_that.cardBrandIds,_that.defaultCardBrandId,_that.deadlineCreditIds,_that.deadlineDebitIds,_that.defaultDeadlineCreditId,_that.defaultDeadlineDebitId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String type,  bool isCardJournal,  List<PaymentMethod> paymentMethods,  List<int> cardBrandIds,  int? defaultCardBrandId,  List<int> deadlineCreditIds,  List<int> deadlineDebitIds,  int? defaultDeadlineCreditId,  int? defaultDeadlineDebitId)?  $default,) {final _that = this;
switch (_that) {
case _AvailableJournal() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.isCardJournal,_that.paymentMethods,_that.cardBrandIds,_that.defaultCardBrandId,_that.deadlineCreditIds,_that.deadlineDebitIds,_that.defaultDeadlineCreditId,_that.defaultDeadlineDebitId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AvailableJournal extends AvailableJournal {
  const _AvailableJournal({required this.id, required this.name, required this.type, this.isCardJournal = false, final  List<PaymentMethod> paymentMethods = const [], final  List<int> cardBrandIds = const [], this.defaultCardBrandId, final  List<int> deadlineCreditIds = const [], final  List<int> deadlineDebitIds = const [], this.defaultDeadlineCreditId, this.defaultDeadlineDebitId}): _paymentMethods = paymentMethods,_cardBrandIds = cardBrandIds,_deadlineCreditIds = deadlineCreditIds,_deadlineDebitIds = deadlineDebitIds,super._();
  factory _AvailableJournal.fromJson(Map<String, dynamic> json) => _$AvailableJournalFromJson(json);

@override final  int id;
@override final  String name;
@override final  String type;
@override@JsonKey() final  bool isCardJournal;
 final  List<PaymentMethod> _paymentMethods;
@override@JsonKey() List<PaymentMethod> get paymentMethods {
  if (_paymentMethods is EqualUnmodifiableListView) return _paymentMethods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_paymentMethods);
}

 final  List<int> _cardBrandIds;
@override@JsonKey() List<int> get cardBrandIds {
  if (_cardBrandIds is EqualUnmodifiableListView) return _cardBrandIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cardBrandIds);
}

@override final  int? defaultCardBrandId;
 final  List<int> _deadlineCreditIds;
@override@JsonKey() List<int> get deadlineCreditIds {
  if (_deadlineCreditIds is EqualUnmodifiableListView) return _deadlineCreditIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_deadlineCreditIds);
}

 final  List<int> _deadlineDebitIds;
@override@JsonKey() List<int> get deadlineDebitIds {
  if (_deadlineDebitIds is EqualUnmodifiableListView) return _deadlineDebitIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_deadlineDebitIds);
}

@override final  int? defaultDeadlineCreditId;
@override final  int? defaultDeadlineDebitId;

/// Create a copy of AvailableJournal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvailableJournalCopyWith<_AvailableJournal> get copyWith => __$AvailableJournalCopyWithImpl<_AvailableJournal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AvailableJournalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AvailableJournal&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.isCardJournal, isCardJournal) || other.isCardJournal == isCardJournal)&&const DeepCollectionEquality().equals(other._paymentMethods, _paymentMethods)&&const DeepCollectionEquality().equals(other._cardBrandIds, _cardBrandIds)&&(identical(other.defaultCardBrandId, defaultCardBrandId) || other.defaultCardBrandId == defaultCardBrandId)&&const DeepCollectionEquality().equals(other._deadlineCreditIds, _deadlineCreditIds)&&const DeepCollectionEquality().equals(other._deadlineDebitIds, _deadlineDebitIds)&&(identical(other.defaultDeadlineCreditId, defaultDeadlineCreditId) || other.defaultDeadlineCreditId == defaultDeadlineCreditId)&&(identical(other.defaultDeadlineDebitId, defaultDeadlineDebitId) || other.defaultDeadlineDebitId == defaultDeadlineDebitId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,isCardJournal,const DeepCollectionEquality().hash(_paymentMethods),const DeepCollectionEquality().hash(_cardBrandIds),defaultCardBrandId,const DeepCollectionEquality().hash(_deadlineCreditIds),const DeepCollectionEquality().hash(_deadlineDebitIds),defaultDeadlineCreditId,defaultDeadlineDebitId);

@override
String toString() {
  return 'AvailableJournal(id: $id, name: $name, type: $type, isCardJournal: $isCardJournal, paymentMethods: $paymentMethods, cardBrandIds: $cardBrandIds, defaultCardBrandId: $defaultCardBrandId, deadlineCreditIds: $deadlineCreditIds, deadlineDebitIds: $deadlineDebitIds, defaultDeadlineCreditId: $defaultDeadlineCreditId, defaultDeadlineDebitId: $defaultDeadlineDebitId)';
}


}

/// @nodoc
abstract mixin class _$AvailableJournalCopyWith<$Res> implements $AvailableJournalCopyWith<$Res> {
  factory _$AvailableJournalCopyWith(_AvailableJournal value, $Res Function(_AvailableJournal) _then) = __$AvailableJournalCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String type, bool isCardJournal, List<PaymentMethod> paymentMethods, List<int> cardBrandIds, int? defaultCardBrandId, List<int> deadlineCreditIds, List<int> deadlineDebitIds, int? defaultDeadlineCreditId, int? defaultDeadlineDebitId
});




}
/// @nodoc
class __$AvailableJournalCopyWithImpl<$Res>
    implements _$AvailableJournalCopyWith<$Res> {
  __$AvailableJournalCopyWithImpl(this._self, this._then);

  final _AvailableJournal _self;
  final $Res Function(_AvailableJournal) _then;

/// Create a copy of AvailableJournal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? isCardJournal = null,Object? paymentMethods = null,Object? cardBrandIds = null,Object? defaultCardBrandId = freezed,Object? deadlineCreditIds = null,Object? deadlineDebitIds = null,Object? defaultDeadlineCreditId = freezed,Object? defaultDeadlineDebitId = freezed,}) {
  return _then(_AvailableJournal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,isCardJournal: null == isCardJournal ? _self.isCardJournal : isCardJournal // ignore: cast_nullable_to_non_nullable
as bool,paymentMethods: null == paymentMethods ? _self._paymentMethods : paymentMethods // ignore: cast_nullable_to_non_nullable
as List<PaymentMethod>,cardBrandIds: null == cardBrandIds ? _self._cardBrandIds : cardBrandIds // ignore: cast_nullable_to_non_nullable
as List<int>,defaultCardBrandId: freezed == defaultCardBrandId ? _self.defaultCardBrandId : defaultCardBrandId // ignore: cast_nullable_to_non_nullable
as int?,deadlineCreditIds: null == deadlineCreditIds ? _self._deadlineCreditIds : deadlineCreditIds // ignore: cast_nullable_to_non_nullable
as List<int>,deadlineDebitIds: null == deadlineDebitIds ? _self._deadlineDebitIds : deadlineDebitIds // ignore: cast_nullable_to_non_nullable
as List<int>,defaultDeadlineCreditId: freezed == defaultDeadlineCreditId ? _self.defaultDeadlineCreditId : defaultDeadlineCreditId // ignore: cast_nullable_to_non_nullable
as int?,defaultDeadlineDebitId: freezed == defaultDeadlineDebitId ? _self.defaultDeadlineDebitId : defaultDeadlineDebitId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$PaymentMethod {

 int get id; String get name; String? get spanishName; String get code;
/// Create a copy of PaymentMethod
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentMethodCopyWith<PaymentMethod> get copyWith => _$PaymentMethodCopyWithImpl<PaymentMethod>(this as PaymentMethod, _$identity);

  /// Serializes this PaymentMethod to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentMethod&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.spanishName, spanishName) || other.spanishName == spanishName)&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,spanishName,code);

@override
String toString() {
  return 'PaymentMethod(id: $id, name: $name, spanishName: $spanishName, code: $code)';
}


}

/// @nodoc
abstract mixin class $PaymentMethodCopyWith<$Res>  {
  factory $PaymentMethodCopyWith(PaymentMethod value, $Res Function(PaymentMethod) _then) = _$PaymentMethodCopyWithImpl;
@useResult
$Res call({
 int id, String name, String? spanishName, String code
});




}
/// @nodoc
class _$PaymentMethodCopyWithImpl<$Res>
    implements $PaymentMethodCopyWith<$Res> {
  _$PaymentMethodCopyWithImpl(this._self, this._then);

  final PaymentMethod _self;
  final $Res Function(PaymentMethod) _then;

/// Create a copy of PaymentMethod
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? spanishName = freezed,Object? code = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,spanishName: freezed == spanishName ? _self.spanishName : spanishName // ignore: cast_nullable_to_non_nullable
as String?,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentMethod].
extension PaymentMethodPatterns on PaymentMethod {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentMethod value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentMethod() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentMethod value)  $default,){
final _that = this;
switch (_that) {
case _PaymentMethod():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentMethod value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentMethod() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String? spanishName,  String code)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentMethod() when $default != null:
return $default(_that.id,_that.name,_that.spanishName,_that.code);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String? spanishName,  String code)  $default,) {final _that = this;
switch (_that) {
case _PaymentMethod():
return $default(_that.id,_that.name,_that.spanishName,_that.code);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String? spanishName,  String code)?  $default,) {final _that = this;
switch (_that) {
case _PaymentMethod() when $default != null:
return $default(_that.id,_that.name,_that.spanishName,_that.code);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentMethod extends PaymentMethod {
  const _PaymentMethod({required this.id, required this.name, this.spanishName, required this.code}): super._();
  factory _PaymentMethod.fromJson(Map<String, dynamic> json) => _$PaymentMethodFromJson(json);

@override final  int id;
@override final  String name;
@override final  String? spanishName;
@override final  String code;

/// Create a copy of PaymentMethod
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentMethodCopyWith<_PaymentMethod> get copyWith => __$PaymentMethodCopyWithImpl<_PaymentMethod>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentMethodToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentMethod&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.spanishName, spanishName) || other.spanishName == spanishName)&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,spanishName,code);

@override
String toString() {
  return 'PaymentMethod(id: $id, name: $name, spanishName: $spanishName, code: $code)';
}


}

/// @nodoc
abstract mixin class _$PaymentMethodCopyWith<$Res> implements $PaymentMethodCopyWith<$Res> {
  factory _$PaymentMethodCopyWith(_PaymentMethod value, $Res Function(_PaymentMethod) _then) = __$PaymentMethodCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String? spanishName, String code
});




}
/// @nodoc
class __$PaymentMethodCopyWithImpl<$Res>
    implements _$PaymentMethodCopyWith<$Res> {
  __$PaymentMethodCopyWithImpl(this._self, this._then);

  final _PaymentMethod _self;
  final $Res Function(_PaymentMethod) _then;

/// Create a copy of PaymentMethod
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? spanishName = freezed,Object? code = null,}) {
  return _then(_PaymentMethod(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,spanishName: freezed == spanishName ? _self.spanishName : spanishName // ignore: cast_nullable_to_non_nullable
as String?,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AvailableAdvance {

 int get id; String get name; double get amountAvailable; DateTime get date; String? get reference;
/// Create a copy of AvailableAdvance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvailableAdvanceCopyWith<AvailableAdvance> get copyWith => _$AvailableAdvanceCopyWithImpl<AvailableAdvance>(this as AvailableAdvance, _$identity);

  /// Serializes this AvailableAdvance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvailableAdvance&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.amountAvailable, amountAvailable) || other.amountAvailable == amountAvailable)&&(identical(other.date, date) || other.date == date)&&(identical(other.reference, reference) || other.reference == reference));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,amountAvailable,date,reference);

@override
String toString() {
  return 'AvailableAdvance(id: $id, name: $name, amountAvailable: $amountAvailable, date: $date, reference: $reference)';
}


}

/// @nodoc
abstract mixin class $AvailableAdvanceCopyWith<$Res>  {
  factory $AvailableAdvanceCopyWith(AvailableAdvance value, $Res Function(AvailableAdvance) _then) = _$AvailableAdvanceCopyWithImpl;
@useResult
$Res call({
 int id, String name, double amountAvailable, DateTime date, String? reference
});




}
/// @nodoc
class _$AvailableAdvanceCopyWithImpl<$Res>
    implements $AvailableAdvanceCopyWith<$Res> {
  _$AvailableAdvanceCopyWithImpl(this._self, this._then);

  final AvailableAdvance _self;
  final $Res Function(AvailableAdvance) _then;

/// Create a copy of AvailableAdvance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? amountAvailable = null,Object? date = null,Object? reference = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,amountAvailable: null == amountAvailable ? _self.amountAvailable : amountAvailable // ignore: cast_nullable_to_non_nullable
as double,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AvailableAdvance].
extension AvailableAdvancePatterns on AvailableAdvance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AvailableAdvance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AvailableAdvance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AvailableAdvance value)  $default,){
final _that = this;
switch (_that) {
case _AvailableAdvance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AvailableAdvance value)?  $default,){
final _that = this;
switch (_that) {
case _AvailableAdvance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  double amountAvailable,  DateTime date,  String? reference)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AvailableAdvance() when $default != null:
return $default(_that.id,_that.name,_that.amountAvailable,_that.date,_that.reference);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  double amountAvailable,  DateTime date,  String? reference)  $default,) {final _that = this;
switch (_that) {
case _AvailableAdvance():
return $default(_that.id,_that.name,_that.amountAvailable,_that.date,_that.reference);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  double amountAvailable,  DateTime date,  String? reference)?  $default,) {final _that = this;
switch (_that) {
case _AvailableAdvance() when $default != null:
return $default(_that.id,_that.name,_that.amountAvailable,_that.date,_that.reference);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AvailableAdvance extends AvailableAdvance {
  const _AvailableAdvance({required this.id, required this.name, required this.amountAvailable, required this.date, this.reference}): super._();
  factory _AvailableAdvance.fromJson(Map<String, dynamic> json) => _$AvailableAdvanceFromJson(json);

@override final  int id;
@override final  String name;
@override final  double amountAvailable;
@override final  DateTime date;
@override final  String? reference;

/// Create a copy of AvailableAdvance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvailableAdvanceCopyWith<_AvailableAdvance> get copyWith => __$AvailableAdvanceCopyWithImpl<_AvailableAdvance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AvailableAdvanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AvailableAdvance&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.amountAvailable, amountAvailable) || other.amountAvailable == amountAvailable)&&(identical(other.date, date) || other.date == date)&&(identical(other.reference, reference) || other.reference == reference));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,amountAvailable,date,reference);

@override
String toString() {
  return 'AvailableAdvance(id: $id, name: $name, amountAvailable: $amountAvailable, date: $date, reference: $reference)';
}


}

/// @nodoc
abstract mixin class _$AvailableAdvanceCopyWith<$Res> implements $AvailableAdvanceCopyWith<$Res> {
  factory _$AvailableAdvanceCopyWith(_AvailableAdvance value, $Res Function(_AvailableAdvance) _then) = __$AvailableAdvanceCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, double amountAvailable, DateTime date, String? reference
});




}
/// @nodoc
class __$AvailableAdvanceCopyWithImpl<$Res>
    implements _$AvailableAdvanceCopyWith<$Res> {
  __$AvailableAdvanceCopyWithImpl(this._self, this._then);

  final _AvailableAdvance _self;
  final $Res Function(_AvailableAdvance) _then;

/// Create a copy of AvailableAdvance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? amountAvailable = null,Object? date = null,Object? reference = freezed,}) {
  return _then(_AvailableAdvance(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,amountAvailable: null == amountAvailable ? _self.amountAvailable : amountAvailable // ignore: cast_nullable_to_non_nullable
as double,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AvailableCreditNote {

 int get id; String get name; double get amountResidual; DateTime? get invoiceDate; String? get ref;
/// Create a copy of AvailableCreditNote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvailableCreditNoteCopyWith<AvailableCreditNote> get copyWith => _$AvailableCreditNoteCopyWithImpl<AvailableCreditNote>(this as AvailableCreditNote, _$identity);

  /// Serializes this AvailableCreditNote to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvailableCreditNote&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.amountResidual, amountResidual) || other.amountResidual == amountResidual)&&(identical(other.invoiceDate, invoiceDate) || other.invoiceDate == invoiceDate)&&(identical(other.ref, ref) || other.ref == ref));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,amountResidual,invoiceDate,ref);

@override
String toString() {
  return 'AvailableCreditNote(id: $id, name: $name, amountResidual: $amountResidual, invoiceDate: $invoiceDate, ref: $ref)';
}


}

/// @nodoc
abstract mixin class $AvailableCreditNoteCopyWith<$Res>  {
  factory $AvailableCreditNoteCopyWith(AvailableCreditNote value, $Res Function(AvailableCreditNote) _then) = _$AvailableCreditNoteCopyWithImpl;
@useResult
$Res call({
 int id, String name, double amountResidual, DateTime? invoiceDate, String? ref
});




}
/// @nodoc
class _$AvailableCreditNoteCopyWithImpl<$Res>
    implements $AvailableCreditNoteCopyWith<$Res> {
  _$AvailableCreditNoteCopyWithImpl(this._self, this._then);

  final AvailableCreditNote _self;
  final $Res Function(AvailableCreditNote) _then;

/// Create a copy of AvailableCreditNote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? amountResidual = null,Object? invoiceDate = freezed,Object? ref = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,amountResidual: null == amountResidual ? _self.amountResidual : amountResidual // ignore: cast_nullable_to_non_nullable
as double,invoiceDate: freezed == invoiceDate ? _self.invoiceDate : invoiceDate // ignore: cast_nullable_to_non_nullable
as DateTime?,ref: freezed == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AvailableCreditNote].
extension AvailableCreditNotePatterns on AvailableCreditNote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AvailableCreditNote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AvailableCreditNote() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AvailableCreditNote value)  $default,){
final _that = this;
switch (_that) {
case _AvailableCreditNote():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AvailableCreditNote value)?  $default,){
final _that = this;
switch (_that) {
case _AvailableCreditNote() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  double amountResidual,  DateTime? invoiceDate,  String? ref)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AvailableCreditNote() when $default != null:
return $default(_that.id,_that.name,_that.amountResidual,_that.invoiceDate,_that.ref);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  double amountResidual,  DateTime? invoiceDate,  String? ref)  $default,) {final _that = this;
switch (_that) {
case _AvailableCreditNote():
return $default(_that.id,_that.name,_that.amountResidual,_that.invoiceDate,_that.ref);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  double amountResidual,  DateTime? invoiceDate,  String? ref)?  $default,) {final _that = this;
switch (_that) {
case _AvailableCreditNote() when $default != null:
return $default(_that.id,_that.name,_that.amountResidual,_that.invoiceDate,_that.ref);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AvailableCreditNote extends AvailableCreditNote {
  const _AvailableCreditNote({required this.id, required this.name, required this.amountResidual, this.invoiceDate, this.ref}): super._();
  factory _AvailableCreditNote.fromJson(Map<String, dynamic> json) => _$AvailableCreditNoteFromJson(json);

@override final  int id;
@override final  String name;
@override final  double amountResidual;
@override final  DateTime? invoiceDate;
@override final  String? ref;

/// Create a copy of AvailableCreditNote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvailableCreditNoteCopyWith<_AvailableCreditNote> get copyWith => __$AvailableCreditNoteCopyWithImpl<_AvailableCreditNote>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AvailableCreditNoteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AvailableCreditNote&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.amountResidual, amountResidual) || other.amountResidual == amountResidual)&&(identical(other.invoiceDate, invoiceDate) || other.invoiceDate == invoiceDate)&&(identical(other.ref, ref) || other.ref == ref));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,amountResidual,invoiceDate,ref);

@override
String toString() {
  return 'AvailableCreditNote(id: $id, name: $name, amountResidual: $amountResidual, invoiceDate: $invoiceDate, ref: $ref)';
}


}

/// @nodoc
abstract mixin class _$AvailableCreditNoteCopyWith<$Res> implements $AvailableCreditNoteCopyWith<$Res> {
  factory _$AvailableCreditNoteCopyWith(_AvailableCreditNote value, $Res Function(_AvailableCreditNote) _then) = __$AvailableCreditNoteCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, double amountResidual, DateTime? invoiceDate, String? ref
});




}
/// @nodoc
class __$AvailableCreditNoteCopyWithImpl<$Res>
    implements _$AvailableCreditNoteCopyWith<$Res> {
  __$AvailableCreditNoteCopyWithImpl(this._self, this._then);

  final _AvailableCreditNote _self;
  final $Res Function(_AvailableCreditNote) _then;

/// Create a copy of AvailableCreditNote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? amountResidual = null,Object? invoiceDate = freezed,Object? ref = freezed,}) {
  return _then(_AvailableCreditNote(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,amountResidual: null == amountResidual ? _self.amountResidual : amountResidual // ignore: cast_nullable_to_non_nullable
as double,invoiceDate: freezed == invoiceDate ? _self.invoiceDate : invoiceDate // ignore: cast_nullable_to_non_nullable
as DateTime?,ref: freezed == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AvailableBank {

 int get id; String get name;
/// Create a copy of AvailableBank
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvailableBankCopyWith<AvailableBank> get copyWith => _$AvailableBankCopyWithImpl<AvailableBank>(this as AvailableBank, _$identity);

  /// Serializes this AvailableBank to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvailableBank&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'AvailableBank(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $AvailableBankCopyWith<$Res>  {
  factory $AvailableBankCopyWith(AvailableBank value, $Res Function(AvailableBank) _then) = _$AvailableBankCopyWithImpl;
@useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class _$AvailableBankCopyWithImpl<$Res>
    implements $AvailableBankCopyWith<$Res> {
  _$AvailableBankCopyWithImpl(this._self, this._then);

  final AvailableBank _self;
  final $Res Function(AvailableBank) _then;

/// Create a copy of AvailableBank
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AvailableBank].
extension AvailableBankPatterns on AvailableBank {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AvailableBank value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AvailableBank() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AvailableBank value)  $default,){
final _that = this;
switch (_that) {
case _AvailableBank():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AvailableBank value)?  $default,){
final _that = this;
switch (_that) {
case _AvailableBank() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AvailableBank() when $default != null:
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name)  $default,) {final _that = this;
switch (_that) {
case _AvailableBank():
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _AvailableBank() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AvailableBank implements AvailableBank {
  const _AvailableBank({required this.id, required this.name});
  factory _AvailableBank.fromJson(Map<String, dynamic> json) => _$AvailableBankFromJson(json);

@override final  int id;
@override final  String name;

/// Create a copy of AvailableBank
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvailableBankCopyWith<_AvailableBank> get copyWith => __$AvailableBankCopyWithImpl<_AvailableBank>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AvailableBankToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AvailableBank&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'AvailableBank(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$AvailableBankCopyWith<$Res> implements $AvailableBankCopyWith<$Res> {
  factory _$AvailableBankCopyWith(_AvailableBank value, $Res Function(_AvailableBank) _then) = __$AvailableBankCopyWithImpl;
@override @useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class __$AvailableBankCopyWithImpl<$Res>
    implements _$AvailableBankCopyWith<$Res> {
  __$AvailableBankCopyWithImpl(this._self, this._then);

  final _AvailableBank _self;
  final $Res Function(_AvailableBank) _then;

/// Create a copy of AvailableBank
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_AvailableBank(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CardBrand {

 int get id; String get name;
/// Create a copy of CardBrand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardBrandCopyWith<CardBrand> get copyWith => _$CardBrandCopyWithImpl<CardBrand>(this as CardBrand, _$identity);

  /// Serializes this CardBrand to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardBrand&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'CardBrand(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $CardBrandCopyWith<$Res>  {
  factory $CardBrandCopyWith(CardBrand value, $Res Function(CardBrand) _then) = _$CardBrandCopyWithImpl;
@useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class _$CardBrandCopyWithImpl<$Res>
    implements $CardBrandCopyWith<$Res> {
  _$CardBrandCopyWithImpl(this._self, this._then);

  final CardBrand _self;
  final $Res Function(CardBrand) _then;

/// Create a copy of CardBrand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CardBrand].
extension CardBrandPatterns on CardBrand {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CardBrand value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CardBrand() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CardBrand value)  $default,){
final _that = this;
switch (_that) {
case _CardBrand():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CardBrand value)?  $default,){
final _that = this;
switch (_that) {
case _CardBrand() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CardBrand() when $default != null:
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name)  $default,) {final _that = this;
switch (_that) {
case _CardBrand():
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _CardBrand() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CardBrand implements CardBrand {
  const _CardBrand({required this.id, required this.name});
  factory _CardBrand.fromJson(Map<String, dynamic> json) => _$CardBrandFromJson(json);

@override final  int id;
@override final  String name;

/// Create a copy of CardBrand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CardBrandCopyWith<_CardBrand> get copyWith => __$CardBrandCopyWithImpl<_CardBrand>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CardBrandToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CardBrand&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'CardBrand(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$CardBrandCopyWith<$Res> implements $CardBrandCopyWith<$Res> {
  factory _$CardBrandCopyWith(_CardBrand value, $Res Function(_CardBrand) _then) = __$CardBrandCopyWithImpl;
@override @useResult
$Res call({
 int id, String name
});




}
/// @nodoc
class __$CardBrandCopyWithImpl<$Res>
    implements _$CardBrandCopyWith<$Res> {
  __$CardBrandCopyWithImpl(this._self, this._then);

  final _CardBrand _self;
  final $Res Function(_CardBrand) _then;

/// Create a copy of CardBrand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_CardBrand(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CardDeadline {

 int get id; String get name; int get deadlineDays; double get percentage;
/// Create a copy of CardDeadline
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardDeadlineCopyWith<CardDeadline> get copyWith => _$CardDeadlineCopyWithImpl<CardDeadline>(this as CardDeadline, _$identity);

  /// Serializes this CardDeadline to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardDeadline&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.deadlineDays, deadlineDays) || other.deadlineDays == deadlineDays)&&(identical(other.percentage, percentage) || other.percentage == percentage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,deadlineDays,percentage);

@override
String toString() {
  return 'CardDeadline(id: $id, name: $name, deadlineDays: $deadlineDays, percentage: $percentage)';
}


}

/// @nodoc
abstract mixin class $CardDeadlineCopyWith<$Res>  {
  factory $CardDeadlineCopyWith(CardDeadline value, $Res Function(CardDeadline) _then) = _$CardDeadlineCopyWithImpl;
@useResult
$Res call({
 int id, String name, int deadlineDays, double percentage
});




}
/// @nodoc
class _$CardDeadlineCopyWithImpl<$Res>
    implements $CardDeadlineCopyWith<$Res> {
  _$CardDeadlineCopyWithImpl(this._self, this._then);

  final CardDeadline _self;
  final $Res Function(CardDeadline) _then;

/// Create a copy of CardDeadline
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? deadlineDays = null,Object? percentage = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,deadlineDays: null == deadlineDays ? _self.deadlineDays : deadlineDays // ignore: cast_nullable_to_non_nullable
as int,percentage: null == percentage ? _self.percentage : percentage // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [CardDeadline].
extension CardDeadlinePatterns on CardDeadline {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CardDeadline value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CardDeadline() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CardDeadline value)  $default,){
final _that = this;
switch (_that) {
case _CardDeadline():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CardDeadline value)?  $default,){
final _that = this;
switch (_that) {
case _CardDeadline() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  int deadlineDays,  double percentage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CardDeadline() when $default != null:
return $default(_that.id,_that.name,_that.deadlineDays,_that.percentage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  int deadlineDays,  double percentage)  $default,) {final _that = this;
switch (_that) {
case _CardDeadline():
return $default(_that.id,_that.name,_that.deadlineDays,_that.percentage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  int deadlineDays,  double percentage)?  $default,) {final _that = this;
switch (_that) {
case _CardDeadline() when $default != null:
return $default(_that.id,_that.name,_that.deadlineDays,_that.percentage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CardDeadline extends CardDeadline {
  const _CardDeadline({required this.id, required this.name, this.deadlineDays = 0, this.percentage = 0.0}): super._();
  factory _CardDeadline.fromJson(Map<String, dynamic> json) => _$CardDeadlineFromJson(json);

@override final  int id;
@override final  String name;
@override@JsonKey() final  int deadlineDays;
@override@JsonKey() final  double percentage;

/// Create a copy of CardDeadline
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CardDeadlineCopyWith<_CardDeadline> get copyWith => __$CardDeadlineCopyWithImpl<_CardDeadline>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CardDeadlineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CardDeadline&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.deadlineDays, deadlineDays) || other.deadlineDays == deadlineDays)&&(identical(other.percentage, percentage) || other.percentage == percentage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,deadlineDays,percentage);

@override
String toString() {
  return 'CardDeadline(id: $id, name: $name, deadlineDays: $deadlineDays, percentage: $percentage)';
}


}

/// @nodoc
abstract mixin class _$CardDeadlineCopyWith<$Res> implements $CardDeadlineCopyWith<$Res> {
  factory _$CardDeadlineCopyWith(_CardDeadline value, $Res Function(_CardDeadline) _then) = __$CardDeadlineCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, int deadlineDays, double percentage
});




}
/// @nodoc
class __$CardDeadlineCopyWithImpl<$Res>
    implements _$CardDeadlineCopyWith<$Res> {
  __$CardDeadlineCopyWithImpl(this._self, this._then);

  final _CardDeadline _self;
  final $Res Function(_CardDeadline) _then;

/// Create a copy of CardDeadline
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? deadlineDays = null,Object? percentage = null,}) {
  return _then(_CardDeadline(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,deadlineDays: null == deadlineDays ? _self.deadlineDays : deadlineDays // ignore: cast_nullable_to_non_nullable
as int,percentage: null == percentage ? _self.percentage : percentage // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$CardLote {

// ============ Identifiers ============
@OdooId() int get id;@OdooLocalOnly() int? get localId;@OdooLocalOnly() String? get loteUuid;// ============ Basic Data ============
@OdooString() String get name;@OdooMany2One('account.journal', odooName: 'journal_id') int get journalId;@OdooMany2OneName(sourceField: 'journal_id') String? get journalName;@OdooSelection() String get state;@OdooDate() DateTime? get date;@OdooString(odooName: 'numero_lote') String? get numeroLote;// ============ Amounts ============
@OdooFloat(odooName: 'amount_total') double get amountTotal;@OdooFloat(odooName: 'amount_balance') double get amountBalance;@OdooInteger(odooName: 'payment_count') int get paymentCount;// ============ Flags ============
@OdooBoolean(odooName: 'is_pos_lote') bool get isPosLote;
/// Create a copy of CardLote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardLoteCopyWith<CardLote> get copyWith => _$CardLoteCopyWithImpl<CardLote>(this as CardLote, _$identity);

  /// Serializes this CardLote to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardLote&&(identical(other.id, id) || other.id == id)&&(identical(other.localId, localId) || other.localId == localId)&&(identical(other.loteUuid, loteUuid) || other.loteUuid == loteUuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.state, state) || other.state == state)&&(identical(other.date, date) || other.date == date)&&(identical(other.numeroLote, numeroLote) || other.numeroLote == numeroLote)&&(identical(other.amountTotal, amountTotal) || other.amountTotal == amountTotal)&&(identical(other.amountBalance, amountBalance) || other.amountBalance == amountBalance)&&(identical(other.paymentCount, paymentCount) || other.paymentCount == paymentCount)&&(identical(other.isPosLote, isPosLote) || other.isPosLote == isPosLote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,localId,loteUuid,name,journalId,journalName,state,date,numeroLote,amountTotal,amountBalance,paymentCount,isPosLote);

@override
String toString() {
  return 'CardLote(id: $id, localId: $localId, loteUuid: $loteUuid, name: $name, journalId: $journalId, journalName: $journalName, state: $state, date: $date, numeroLote: $numeroLote, amountTotal: $amountTotal, amountBalance: $amountBalance, paymentCount: $paymentCount, isPosLote: $isPosLote)';
}


}

/// @nodoc
abstract mixin class $CardLoteCopyWith<$Res>  {
  factory $CardLoteCopyWith(CardLote value, $Res Function(CardLote) _then) = _$CardLoteCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() int? localId,@OdooLocalOnly() String? loteUuid,@OdooString() String name,@OdooMany2One('account.journal', odooName: 'journal_id') int journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooSelection() String state,@OdooDate() DateTime? date,@OdooString(odooName: 'numero_lote') String? numeroLote,@OdooFloat(odooName: 'amount_total') double amountTotal,@OdooFloat(odooName: 'amount_balance') double amountBalance,@OdooInteger(odooName: 'payment_count') int paymentCount,@OdooBoolean(odooName: 'is_pos_lote') bool isPosLote
});




}
/// @nodoc
class _$CardLoteCopyWithImpl<$Res>
    implements $CardLoteCopyWith<$Res> {
  _$CardLoteCopyWithImpl(this._self, this._then);

  final CardLote _self;
  final $Res Function(CardLote) _then;

/// Create a copy of CardLote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? localId = freezed,Object? loteUuid = freezed,Object? name = null,Object? journalId = null,Object? journalName = freezed,Object? state = null,Object? date = freezed,Object? numeroLote = freezed,Object? amountTotal = null,Object? amountBalance = null,Object? paymentCount = null,Object? isPosLote = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,localId: freezed == localId ? _self.localId : localId // ignore: cast_nullable_to_non_nullable
as int?,loteUuid: freezed == loteUuid ? _self.loteUuid : loteUuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime?,numeroLote: freezed == numeroLote ? _self.numeroLote : numeroLote // ignore: cast_nullable_to_non_nullable
as String?,amountTotal: null == amountTotal ? _self.amountTotal : amountTotal // ignore: cast_nullable_to_non_nullable
as double,amountBalance: null == amountBalance ? _self.amountBalance : amountBalance // ignore: cast_nullable_to_non_nullable
as double,paymentCount: null == paymentCount ? _self.paymentCount : paymentCount // ignore: cast_nullable_to_non_nullable
as int,isPosLote: null == isPosLote ? _self.isPosLote : isPosLote // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CardLote].
extension CardLotePatterns on CardLote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CardLote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CardLote() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CardLote value)  $default,){
final _that = this;
switch (_that) {
case _CardLote():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CardLote value)?  $default,){
final _that = this;
switch (_that) {
case _CardLote() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  int? localId, @OdooLocalOnly()  String? loteUuid, @OdooString()  String name, @OdooMany2One('account.journal', odooName: 'journal_id')  int journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooSelection()  String state, @OdooDate()  DateTime? date, @OdooString(odooName: 'numero_lote')  String? numeroLote, @OdooFloat(odooName: 'amount_total')  double amountTotal, @OdooFloat(odooName: 'amount_balance')  double amountBalance, @OdooInteger(odooName: 'payment_count')  int paymentCount, @OdooBoolean(odooName: 'is_pos_lote')  bool isPosLote)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CardLote() when $default != null:
return $default(_that.id,_that.localId,_that.loteUuid,_that.name,_that.journalId,_that.journalName,_that.state,_that.date,_that.numeroLote,_that.amountTotal,_that.amountBalance,_that.paymentCount,_that.isPosLote);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  int? localId, @OdooLocalOnly()  String? loteUuid, @OdooString()  String name, @OdooMany2One('account.journal', odooName: 'journal_id')  int journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooSelection()  String state, @OdooDate()  DateTime? date, @OdooString(odooName: 'numero_lote')  String? numeroLote, @OdooFloat(odooName: 'amount_total')  double amountTotal, @OdooFloat(odooName: 'amount_balance')  double amountBalance, @OdooInteger(odooName: 'payment_count')  int paymentCount, @OdooBoolean(odooName: 'is_pos_lote')  bool isPosLote)  $default,) {final _that = this;
switch (_that) {
case _CardLote():
return $default(_that.id,_that.localId,_that.loteUuid,_that.name,_that.journalId,_that.journalName,_that.state,_that.date,_that.numeroLote,_that.amountTotal,_that.amountBalance,_that.paymentCount,_that.isPosLote);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  int? localId, @OdooLocalOnly()  String? loteUuid, @OdooString()  String name, @OdooMany2One('account.journal', odooName: 'journal_id')  int journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooSelection()  String state, @OdooDate()  DateTime? date, @OdooString(odooName: 'numero_lote')  String? numeroLote, @OdooFloat(odooName: 'amount_total')  double amountTotal, @OdooFloat(odooName: 'amount_balance')  double amountBalance, @OdooInteger(odooName: 'payment_count')  int paymentCount, @OdooBoolean(odooName: 'is_pos_lote')  bool isPosLote)?  $default,) {final _that = this;
switch (_that) {
case _CardLote() when $default != null:
return $default(_that.id,_that.localId,_that.loteUuid,_that.name,_that.journalId,_that.journalName,_that.state,_that.date,_that.numeroLote,_that.amountTotal,_that.amountBalance,_that.paymentCount,_that.isPosLote);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CardLote extends CardLote {
  const _CardLote({@OdooId() this.id = 0, @OdooLocalOnly() this.localId, @OdooLocalOnly() this.loteUuid, @OdooString() required this.name, @OdooMany2One('account.journal', odooName: 'journal_id') required this.journalId, @OdooMany2OneName(sourceField: 'journal_id') this.journalName, @OdooSelection() this.state = 'open', @OdooDate() this.date, @OdooString(odooName: 'numero_lote') this.numeroLote, @OdooFloat(odooName: 'amount_total') this.amountTotal = 0, @OdooFloat(odooName: 'amount_balance') this.amountBalance = 0, @OdooInteger(odooName: 'payment_count') this.paymentCount = 0, @OdooBoolean(odooName: 'is_pos_lote') this.isPosLote = false}): super._();
  factory _CardLote.fromJson(Map<String, dynamic> json) => _$CardLoteFromJson(json);

// ============ Identifiers ============
@override@JsonKey()@OdooId() final  int id;
@override@OdooLocalOnly() final  int? localId;
@override@OdooLocalOnly() final  String? loteUuid;
// ============ Basic Data ============
@override@OdooString() final  String name;
@override@OdooMany2One('account.journal', odooName: 'journal_id') final  int journalId;
@override@OdooMany2OneName(sourceField: 'journal_id') final  String? journalName;
@override@JsonKey()@OdooSelection() final  String state;
@override@OdooDate() final  DateTime? date;
@override@OdooString(odooName: 'numero_lote') final  String? numeroLote;
// ============ Amounts ============
@override@JsonKey()@OdooFloat(odooName: 'amount_total') final  double amountTotal;
@override@JsonKey()@OdooFloat(odooName: 'amount_balance') final  double amountBalance;
@override@JsonKey()@OdooInteger(odooName: 'payment_count') final  int paymentCount;
// ============ Flags ============
@override@JsonKey()@OdooBoolean(odooName: 'is_pos_lote') final  bool isPosLote;

/// Create a copy of CardLote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CardLoteCopyWith<_CardLote> get copyWith => __$CardLoteCopyWithImpl<_CardLote>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CardLoteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CardLote&&(identical(other.id, id) || other.id == id)&&(identical(other.localId, localId) || other.localId == localId)&&(identical(other.loteUuid, loteUuid) || other.loteUuid == loteUuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.state, state) || other.state == state)&&(identical(other.date, date) || other.date == date)&&(identical(other.numeroLote, numeroLote) || other.numeroLote == numeroLote)&&(identical(other.amountTotal, amountTotal) || other.amountTotal == amountTotal)&&(identical(other.amountBalance, amountBalance) || other.amountBalance == amountBalance)&&(identical(other.paymentCount, paymentCount) || other.paymentCount == paymentCount)&&(identical(other.isPosLote, isPosLote) || other.isPosLote == isPosLote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,localId,loteUuid,name,journalId,journalName,state,date,numeroLote,amountTotal,amountBalance,paymentCount,isPosLote);

@override
String toString() {
  return 'CardLote(id: $id, localId: $localId, loteUuid: $loteUuid, name: $name, journalId: $journalId, journalName: $journalName, state: $state, date: $date, numeroLote: $numeroLote, amountTotal: $amountTotal, amountBalance: $amountBalance, paymentCount: $paymentCount, isPosLote: $isPosLote)';
}


}

/// @nodoc
abstract mixin class _$CardLoteCopyWith<$Res> implements $CardLoteCopyWith<$Res> {
  factory _$CardLoteCopyWith(_CardLote value, $Res Function(_CardLote) _then) = __$CardLoteCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() int? localId,@OdooLocalOnly() String? loteUuid,@OdooString() String name,@OdooMany2One('account.journal', odooName: 'journal_id') int journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooSelection() String state,@OdooDate() DateTime? date,@OdooString(odooName: 'numero_lote') String? numeroLote,@OdooFloat(odooName: 'amount_total') double amountTotal,@OdooFloat(odooName: 'amount_balance') double amountBalance,@OdooInteger(odooName: 'payment_count') int paymentCount,@OdooBoolean(odooName: 'is_pos_lote') bool isPosLote
});




}
/// @nodoc
class __$CardLoteCopyWithImpl<$Res>
    implements _$CardLoteCopyWith<$Res> {
  __$CardLoteCopyWithImpl(this._self, this._then);

  final _CardLote _self;
  final $Res Function(_CardLote) _then;

/// Create a copy of CardLote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? localId = freezed,Object? loteUuid = freezed,Object? name = null,Object? journalId = null,Object? journalName = freezed,Object? state = null,Object? date = freezed,Object? numeroLote = freezed,Object? amountTotal = null,Object? amountBalance = null,Object? paymentCount = null,Object? isPosLote = null,}) {
  return _then(_CardLote(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,localId: freezed == localId ? _self.localId : localId // ignore: cast_nullable_to_non_nullable
as int?,loteUuid: freezed == loteUuid ? _self.loteUuid : loteUuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime?,numeroLote: freezed == numeroLote ? _self.numeroLote : numeroLote // ignore: cast_nullable_to_non_nullable
as String?,amountTotal: null == amountTotal ? _self.amountTotal : amountTotal // ignore: cast_nullable_to_non_nullable
as double,amountBalance: null == amountBalance ? _self.amountBalance : amountBalance // ignore: cast_nullable_to_non_nullable
as double,paymentCount: null == paymentCount ? _self.paymentCount : paymentCount // ignore: cast_nullable_to_non_nullable
as int,isPosLote: null == isPosLote ? _self.isPosLote : isPosLote // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
