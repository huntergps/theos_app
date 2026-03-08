// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'collection_session_deposit.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CollectionSessionDeposit {

// ============ Identifiers ============
@OdooId() int get id;@OdooLocalOnly() String? get uuid;@OdooLocalOnly() bool get isSynced;@OdooLocalOnly() DateTime? get lastSyncDate;// ============ Basic Data ============
@OdooString() String? get name;@OdooString() String? get number;// ============ Relations ============
@OdooMany2One('collection.session', odooName: 'collection_session_id') int? get collectionSessionId;/// UUID of the parent session (for offline linking)
@OdooString(odooName: 'session_uuid') String? get sessionUuid;@OdooMany2One('res.users', odooName: 'user_id') int? get userId;@OdooMany2OneName(sourceField: 'user_id') String? get userName;// ============ Date Fields ============
@OdooDateTime(odooName: 'deposit_date') DateTime? get depositDate;@OdooDate(odooName: 'accounting_date') DateTime? get accountingDate;// ============ Amount Fields ============
@OdooFloat() double get amount;@OdooSelection(odooName: 'deposit_type') DepositType get depositType;@OdooFloat(odooName: 'cash_amount') double get cashAmount;@OdooFloat(odooName: 'check_amount') double get checkAmount;@OdooInteger(odooName: 'check_count') int get checkCount;// ============ Bank Fields ============
@OdooMany2One('account.journal', odooName: 'bank_journal_id') int? get bankJournalId;@OdooMany2OneName(sourceField: 'bank_journal_id') String? get bankJournalName;// Alias fields for table compatibility
@OdooMany2One('res.bank', odooName: 'bank_id') int? get bankId;@OdooMany2OneName(sourceField: 'bank_id') String? get bankName;// ============ State & References ============
@OdooSelection() String? get state;@OdooDateTime(odooName: 'write_date') DateTime? get writeDate;@OdooString(odooName: 'deposit_slip_number') String? get depositSlipNumber;@OdooString(odooName: 'bank_reference') String? get bankReference;@OdooMany2One('account.move', odooName: 'move_id') int? get moveId;@OdooString(odooName: 'depositor_name') String? get depositorName;@OdooString() String? get notes;
/// Create a copy of CollectionSessionDeposit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CollectionSessionDepositCopyWith<CollectionSessionDeposit> get copyWith => _$CollectionSessionDepositCopyWithImpl<CollectionSessionDeposit>(this as CollectionSessionDeposit, _$identity);

  /// Serializes this CollectionSessionDeposit to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CollectionSessionDeposit&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.name, name) || other.name == name)&&(identical(other.number, number) || other.number == number)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.sessionUuid, sessionUuid) || other.sessionUuid == sessionUuid)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.depositDate, depositDate) || other.depositDate == depositDate)&&(identical(other.accountingDate, accountingDate) || other.accountingDate == accountingDate)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.depositType, depositType) || other.depositType == depositType)&&(identical(other.cashAmount, cashAmount) || other.cashAmount == cashAmount)&&(identical(other.checkAmount, checkAmount) || other.checkAmount == checkAmount)&&(identical(other.checkCount, checkCount) || other.checkCount == checkCount)&&(identical(other.bankJournalId, bankJournalId) || other.bankJournalId == bankJournalId)&&(identical(other.bankJournalName, bankJournalName) || other.bankJournalName == bankJournalName)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.state, state) || other.state == state)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.depositSlipNumber, depositSlipNumber) || other.depositSlipNumber == depositSlipNumber)&&(identical(other.bankReference, bankReference) || other.bankReference == bankReference)&&(identical(other.moveId, moveId) || other.moveId == moveId)&&(identical(other.depositorName, depositorName) || other.depositorName == depositorName)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,uuid,isSynced,lastSyncDate,name,number,collectionSessionId,sessionUuid,userId,userName,depositDate,accountingDate,amount,depositType,cashAmount,checkAmount,checkCount,bankJournalId,bankJournalName,bankId,bankName,state,writeDate,depositSlipNumber,bankReference,moveId,depositorName,notes]);

@override
String toString() {
  return 'CollectionSessionDeposit(id: $id, uuid: $uuid, isSynced: $isSynced, lastSyncDate: $lastSyncDate, name: $name, number: $number, collectionSessionId: $collectionSessionId, sessionUuid: $sessionUuid, userId: $userId, userName: $userName, depositDate: $depositDate, accountingDate: $accountingDate, amount: $amount, depositType: $depositType, cashAmount: $cashAmount, checkAmount: $checkAmount, checkCount: $checkCount, bankJournalId: $bankJournalId, bankJournalName: $bankJournalName, bankId: $bankId, bankName: $bankName, state: $state, writeDate: $writeDate, depositSlipNumber: $depositSlipNumber, bankReference: $bankReference, moveId: $moveId, depositorName: $depositorName, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $CollectionSessionDepositCopyWith<$Res>  {
  factory $CollectionSessionDepositCopyWith(CollectionSessionDeposit value, $Res Function(CollectionSessionDeposit) _then) = _$CollectionSessionDepositCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? lastSyncDate,@OdooString() String? name,@OdooString() String? number,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooString(odooName: 'session_uuid') String? sessionUuid,@OdooMany2One('res.users', odooName: 'user_id') int? userId,@OdooMany2OneName(sourceField: 'user_id') String? userName,@OdooDateTime(odooName: 'deposit_date') DateTime? depositDate,@OdooDate(odooName: 'accounting_date') DateTime? accountingDate,@OdooFloat() double amount,@OdooSelection(odooName: 'deposit_type') DepositType depositType,@OdooFloat(odooName: 'cash_amount') double cashAmount,@OdooFloat(odooName: 'check_amount') double checkAmount,@OdooInteger(odooName: 'check_count') int checkCount,@OdooMany2One('account.journal', odooName: 'bank_journal_id') int? bankJournalId,@OdooMany2OneName(sourceField: 'bank_journal_id') String? bankJournalName,@OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,@OdooMany2OneName(sourceField: 'bank_id') String? bankName,@OdooSelection() String? state,@OdooDateTime(odooName: 'write_date') DateTime? writeDate,@OdooString(odooName: 'deposit_slip_number') String? depositSlipNumber,@OdooString(odooName: 'bank_reference') String? bankReference,@OdooMany2One('account.move', odooName: 'move_id') int? moveId,@OdooString(odooName: 'depositor_name') String? depositorName,@OdooString() String? notes
});




}
/// @nodoc
class _$CollectionSessionDepositCopyWithImpl<$Res>
    implements $CollectionSessionDepositCopyWith<$Res> {
  _$CollectionSessionDepositCopyWithImpl(this._self, this._then);

  final CollectionSessionDeposit _self;
  final $Res Function(CollectionSessionDeposit) _then;

/// Create a copy of CollectionSessionDeposit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uuid = freezed,Object? isSynced = null,Object? lastSyncDate = freezed,Object? name = freezed,Object? number = freezed,Object? collectionSessionId = freezed,Object? sessionUuid = freezed,Object? userId = freezed,Object? userName = freezed,Object? depositDate = freezed,Object? accountingDate = freezed,Object? amount = null,Object? depositType = null,Object? cashAmount = null,Object? checkAmount = null,Object? checkCount = null,Object? bankJournalId = freezed,Object? bankJournalName = freezed,Object? bankId = freezed,Object? bankName = freezed,Object? state = freezed,Object? writeDate = freezed,Object? depositSlipNumber = freezed,Object? bankReference = freezed,Object? moveId = freezed,Object? depositorName = freezed,Object? notes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String?,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,sessionUuid: freezed == sessionUuid ? _self.sessionUuid : sessionUuid // ignore: cast_nullable_to_non_nullable
as String?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,depositDate: freezed == depositDate ? _self.depositDate : depositDate // ignore: cast_nullable_to_non_nullable
as DateTime?,accountingDate: freezed == accountingDate ? _self.accountingDate : accountingDate // ignore: cast_nullable_to_non_nullable
as DateTime?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,depositType: null == depositType ? _self.depositType : depositType // ignore: cast_nullable_to_non_nullable
as DepositType,cashAmount: null == cashAmount ? _self.cashAmount : cashAmount // ignore: cast_nullable_to_non_nullable
as double,checkAmount: null == checkAmount ? _self.checkAmount : checkAmount // ignore: cast_nullable_to_non_nullable
as double,checkCount: null == checkCount ? _self.checkCount : checkCount // ignore: cast_nullable_to_non_nullable
as int,bankJournalId: freezed == bankJournalId ? _self.bankJournalId : bankJournalId // ignore: cast_nullable_to_non_nullable
as int?,bankJournalName: freezed == bankJournalName ? _self.bankJournalName : bankJournalName // ignore: cast_nullable_to_non_nullable
as String?,bankId: freezed == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as int?,bankName: freezed == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,depositSlipNumber: freezed == depositSlipNumber ? _self.depositSlipNumber : depositSlipNumber // ignore: cast_nullable_to_non_nullable
as String?,bankReference: freezed == bankReference ? _self.bankReference : bankReference // ignore: cast_nullable_to_non_nullable
as String?,moveId: freezed == moveId ? _self.moveId : moveId // ignore: cast_nullable_to_non_nullable
as int?,depositorName: freezed == depositorName ? _self.depositorName : depositorName // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CollectionSessionDeposit].
extension CollectionSessionDepositPatterns on CollectionSessionDeposit {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CollectionSessionDeposit value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CollectionSessionDeposit() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CollectionSessionDeposit value)  $default,){
final _that = this;
switch (_that) {
case _CollectionSessionDeposit():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CollectionSessionDeposit value)?  $default,){
final _that = this;
switch (_that) {
case _CollectionSessionDeposit() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooString()  String? name, @OdooString()  String? number, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooString(odooName: 'session_uuid')  String? sessionUuid, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooDateTime(odooName: 'deposit_date')  DateTime? depositDate, @OdooDate(odooName: 'accounting_date')  DateTime? accountingDate, @OdooFloat()  double amount, @OdooSelection(odooName: 'deposit_type')  DepositType depositType, @OdooFloat(odooName: 'cash_amount')  double cashAmount, @OdooFloat(odooName: 'check_amount')  double checkAmount, @OdooInteger(odooName: 'check_count')  int checkCount, @OdooMany2One('account.journal', odooName: 'bank_journal_id')  int? bankJournalId, @OdooMany2OneName(sourceField: 'bank_journal_id')  String? bankJournalName, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooMany2OneName(sourceField: 'bank_id')  String? bankName, @OdooSelection()  String? state, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooString(odooName: 'deposit_slip_number')  String? depositSlipNumber, @OdooString(odooName: 'bank_reference')  String? bankReference, @OdooMany2One('account.move', odooName: 'move_id')  int? moveId, @OdooString(odooName: 'depositor_name')  String? depositorName, @OdooString()  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CollectionSessionDeposit() when $default != null:
return $default(_that.id,_that.uuid,_that.isSynced,_that.lastSyncDate,_that.name,_that.number,_that.collectionSessionId,_that.sessionUuid,_that.userId,_that.userName,_that.depositDate,_that.accountingDate,_that.amount,_that.depositType,_that.cashAmount,_that.checkAmount,_that.checkCount,_that.bankJournalId,_that.bankJournalName,_that.bankId,_that.bankName,_that.state,_that.writeDate,_that.depositSlipNumber,_that.bankReference,_that.moveId,_that.depositorName,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooString()  String? name, @OdooString()  String? number, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooString(odooName: 'session_uuid')  String? sessionUuid, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooDateTime(odooName: 'deposit_date')  DateTime? depositDate, @OdooDate(odooName: 'accounting_date')  DateTime? accountingDate, @OdooFloat()  double amount, @OdooSelection(odooName: 'deposit_type')  DepositType depositType, @OdooFloat(odooName: 'cash_amount')  double cashAmount, @OdooFloat(odooName: 'check_amount')  double checkAmount, @OdooInteger(odooName: 'check_count')  int checkCount, @OdooMany2One('account.journal', odooName: 'bank_journal_id')  int? bankJournalId, @OdooMany2OneName(sourceField: 'bank_journal_id')  String? bankJournalName, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooMany2OneName(sourceField: 'bank_id')  String? bankName, @OdooSelection()  String? state, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooString(odooName: 'deposit_slip_number')  String? depositSlipNumber, @OdooString(odooName: 'bank_reference')  String? bankReference, @OdooMany2One('account.move', odooName: 'move_id')  int? moveId, @OdooString(odooName: 'depositor_name')  String? depositorName, @OdooString()  String? notes)  $default,) {final _that = this;
switch (_that) {
case _CollectionSessionDeposit():
return $default(_that.id,_that.uuid,_that.isSynced,_that.lastSyncDate,_that.name,_that.number,_that.collectionSessionId,_that.sessionUuid,_that.userId,_that.userName,_that.depositDate,_that.accountingDate,_that.amount,_that.depositType,_that.cashAmount,_that.checkAmount,_that.checkCount,_that.bankJournalId,_that.bankJournalName,_that.bankId,_that.bankName,_that.state,_that.writeDate,_that.depositSlipNumber,_that.bankReference,_that.moveId,_that.depositorName,_that.notes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooString()  String? name, @OdooString()  String? number, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooString(odooName: 'session_uuid')  String? sessionUuid, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooDateTime(odooName: 'deposit_date')  DateTime? depositDate, @OdooDate(odooName: 'accounting_date')  DateTime? accountingDate, @OdooFloat()  double amount, @OdooSelection(odooName: 'deposit_type')  DepositType depositType, @OdooFloat(odooName: 'cash_amount')  double cashAmount, @OdooFloat(odooName: 'check_amount')  double checkAmount, @OdooInteger(odooName: 'check_count')  int checkCount, @OdooMany2One('account.journal', odooName: 'bank_journal_id')  int? bankJournalId, @OdooMany2OneName(sourceField: 'bank_journal_id')  String? bankJournalName, @OdooMany2One('res.bank', odooName: 'bank_id')  int? bankId, @OdooMany2OneName(sourceField: 'bank_id')  String? bankName, @OdooSelection()  String? state, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate, @OdooString(odooName: 'deposit_slip_number')  String? depositSlipNumber, @OdooString(odooName: 'bank_reference')  String? bankReference, @OdooMany2One('account.move', odooName: 'move_id')  int? moveId, @OdooString(odooName: 'depositor_name')  String? depositorName, @OdooString()  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _CollectionSessionDeposit() when $default != null:
return $default(_that.id,_that.uuid,_that.isSynced,_that.lastSyncDate,_that.name,_that.number,_that.collectionSessionId,_that.sessionUuid,_that.userId,_that.userName,_that.depositDate,_that.accountingDate,_that.amount,_that.depositType,_that.cashAmount,_that.checkAmount,_that.checkCount,_that.bankJournalId,_that.bankJournalName,_that.bankId,_that.bankName,_that.state,_that.writeDate,_that.depositSlipNumber,_that.bankReference,_that.moveId,_that.depositorName,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CollectionSessionDeposit extends CollectionSessionDeposit {
  const _CollectionSessionDeposit({@OdooId() this.id = 0, @OdooLocalOnly() this.uuid, @OdooLocalOnly() this.isSynced = false, @OdooLocalOnly() this.lastSyncDate, @OdooString() this.name, @OdooString() this.number, @OdooMany2One('collection.session', odooName: 'collection_session_id') this.collectionSessionId, @OdooString(odooName: 'session_uuid') this.sessionUuid, @OdooMany2One('res.users', odooName: 'user_id') this.userId, @OdooMany2OneName(sourceField: 'user_id') this.userName, @OdooDateTime(odooName: 'deposit_date') this.depositDate, @OdooDate(odooName: 'accounting_date') this.accountingDate, @OdooFloat() this.amount = 0.0, @OdooSelection(odooName: 'deposit_type') this.depositType = DepositType.cash, @OdooFloat(odooName: 'cash_amount') this.cashAmount = 0.0, @OdooFloat(odooName: 'check_amount') this.checkAmount = 0.0, @OdooInteger(odooName: 'check_count') this.checkCount = 0, @OdooMany2One('account.journal', odooName: 'bank_journal_id') this.bankJournalId, @OdooMany2OneName(sourceField: 'bank_journal_id') this.bankJournalName, @OdooMany2One('res.bank', odooName: 'bank_id') this.bankId, @OdooMany2OneName(sourceField: 'bank_id') this.bankName, @OdooSelection() this.state, @OdooDateTime(odooName: 'write_date') this.writeDate, @OdooString(odooName: 'deposit_slip_number') this.depositSlipNumber, @OdooString(odooName: 'bank_reference') this.bankReference, @OdooMany2One('account.move', odooName: 'move_id') this.moveId, @OdooString(odooName: 'depositor_name') this.depositorName, @OdooString() this.notes}): super._();
  factory _CollectionSessionDeposit.fromJson(Map<String, dynamic> json) => _$CollectionSessionDepositFromJson(json);

// ============ Identifiers ============
@override@JsonKey()@OdooId() final  int id;
@override@OdooLocalOnly() final  String? uuid;
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
@override@OdooLocalOnly() final  DateTime? lastSyncDate;
// ============ Basic Data ============
@override@OdooString() final  String? name;
@override@OdooString() final  String? number;
// ============ Relations ============
@override@OdooMany2One('collection.session', odooName: 'collection_session_id') final  int? collectionSessionId;
/// UUID of the parent session (for offline linking)
@override@OdooString(odooName: 'session_uuid') final  String? sessionUuid;
@override@OdooMany2One('res.users', odooName: 'user_id') final  int? userId;
@override@OdooMany2OneName(sourceField: 'user_id') final  String? userName;
// ============ Date Fields ============
@override@OdooDateTime(odooName: 'deposit_date') final  DateTime? depositDate;
@override@OdooDate(odooName: 'accounting_date') final  DateTime? accountingDate;
// ============ Amount Fields ============
@override@JsonKey()@OdooFloat() final  double amount;
@override@JsonKey()@OdooSelection(odooName: 'deposit_type') final  DepositType depositType;
@override@JsonKey()@OdooFloat(odooName: 'cash_amount') final  double cashAmount;
@override@JsonKey()@OdooFloat(odooName: 'check_amount') final  double checkAmount;
@override@JsonKey()@OdooInteger(odooName: 'check_count') final  int checkCount;
// ============ Bank Fields ============
@override@OdooMany2One('account.journal', odooName: 'bank_journal_id') final  int? bankJournalId;
@override@OdooMany2OneName(sourceField: 'bank_journal_id') final  String? bankJournalName;
// Alias fields for table compatibility
@override@OdooMany2One('res.bank', odooName: 'bank_id') final  int? bankId;
@override@OdooMany2OneName(sourceField: 'bank_id') final  String? bankName;
// ============ State & References ============
@override@OdooSelection() final  String? state;
@override@OdooDateTime(odooName: 'write_date') final  DateTime? writeDate;
@override@OdooString(odooName: 'deposit_slip_number') final  String? depositSlipNumber;
@override@OdooString(odooName: 'bank_reference') final  String? bankReference;
@override@OdooMany2One('account.move', odooName: 'move_id') final  int? moveId;
@override@OdooString(odooName: 'depositor_name') final  String? depositorName;
@override@OdooString() final  String? notes;

/// Create a copy of CollectionSessionDeposit
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CollectionSessionDepositCopyWith<_CollectionSessionDeposit> get copyWith => __$CollectionSessionDepositCopyWithImpl<_CollectionSessionDeposit>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CollectionSessionDepositToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CollectionSessionDeposit&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.name, name) || other.name == name)&&(identical(other.number, number) || other.number == number)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.sessionUuid, sessionUuid) || other.sessionUuid == sessionUuid)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.depositDate, depositDate) || other.depositDate == depositDate)&&(identical(other.accountingDate, accountingDate) || other.accountingDate == accountingDate)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.depositType, depositType) || other.depositType == depositType)&&(identical(other.cashAmount, cashAmount) || other.cashAmount == cashAmount)&&(identical(other.checkAmount, checkAmount) || other.checkAmount == checkAmount)&&(identical(other.checkCount, checkCount) || other.checkCount == checkCount)&&(identical(other.bankJournalId, bankJournalId) || other.bankJournalId == bankJournalId)&&(identical(other.bankJournalName, bankJournalName) || other.bankJournalName == bankJournalName)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.state, state) || other.state == state)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.depositSlipNumber, depositSlipNumber) || other.depositSlipNumber == depositSlipNumber)&&(identical(other.bankReference, bankReference) || other.bankReference == bankReference)&&(identical(other.moveId, moveId) || other.moveId == moveId)&&(identical(other.depositorName, depositorName) || other.depositorName == depositorName)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,uuid,isSynced,lastSyncDate,name,number,collectionSessionId,sessionUuid,userId,userName,depositDate,accountingDate,amount,depositType,cashAmount,checkAmount,checkCount,bankJournalId,bankJournalName,bankId,bankName,state,writeDate,depositSlipNumber,bankReference,moveId,depositorName,notes]);

@override
String toString() {
  return 'CollectionSessionDeposit(id: $id, uuid: $uuid, isSynced: $isSynced, lastSyncDate: $lastSyncDate, name: $name, number: $number, collectionSessionId: $collectionSessionId, sessionUuid: $sessionUuid, userId: $userId, userName: $userName, depositDate: $depositDate, accountingDate: $accountingDate, amount: $amount, depositType: $depositType, cashAmount: $cashAmount, checkAmount: $checkAmount, checkCount: $checkCount, bankJournalId: $bankJournalId, bankJournalName: $bankJournalName, bankId: $bankId, bankName: $bankName, state: $state, writeDate: $writeDate, depositSlipNumber: $depositSlipNumber, bankReference: $bankReference, moveId: $moveId, depositorName: $depositorName, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$CollectionSessionDepositCopyWith<$Res> implements $CollectionSessionDepositCopyWith<$Res> {
  factory _$CollectionSessionDepositCopyWith(_CollectionSessionDeposit value, $Res Function(_CollectionSessionDeposit) _then) = __$CollectionSessionDepositCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? lastSyncDate,@OdooString() String? name,@OdooString() String? number,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooString(odooName: 'session_uuid') String? sessionUuid,@OdooMany2One('res.users', odooName: 'user_id') int? userId,@OdooMany2OneName(sourceField: 'user_id') String? userName,@OdooDateTime(odooName: 'deposit_date') DateTime? depositDate,@OdooDate(odooName: 'accounting_date') DateTime? accountingDate,@OdooFloat() double amount,@OdooSelection(odooName: 'deposit_type') DepositType depositType,@OdooFloat(odooName: 'cash_amount') double cashAmount,@OdooFloat(odooName: 'check_amount') double checkAmount,@OdooInteger(odooName: 'check_count') int checkCount,@OdooMany2One('account.journal', odooName: 'bank_journal_id') int? bankJournalId,@OdooMany2OneName(sourceField: 'bank_journal_id') String? bankJournalName,@OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,@OdooMany2OneName(sourceField: 'bank_id') String? bankName,@OdooSelection() String? state,@OdooDateTime(odooName: 'write_date') DateTime? writeDate,@OdooString(odooName: 'deposit_slip_number') String? depositSlipNumber,@OdooString(odooName: 'bank_reference') String? bankReference,@OdooMany2One('account.move', odooName: 'move_id') int? moveId,@OdooString(odooName: 'depositor_name') String? depositorName,@OdooString() String? notes
});




}
/// @nodoc
class __$CollectionSessionDepositCopyWithImpl<$Res>
    implements _$CollectionSessionDepositCopyWith<$Res> {
  __$CollectionSessionDepositCopyWithImpl(this._self, this._then);

  final _CollectionSessionDeposit _self;
  final $Res Function(_CollectionSessionDeposit) _then;

/// Create a copy of CollectionSessionDeposit
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uuid = freezed,Object? isSynced = null,Object? lastSyncDate = freezed,Object? name = freezed,Object? number = freezed,Object? collectionSessionId = freezed,Object? sessionUuid = freezed,Object? userId = freezed,Object? userName = freezed,Object? depositDate = freezed,Object? accountingDate = freezed,Object? amount = null,Object? depositType = null,Object? cashAmount = null,Object? checkAmount = null,Object? checkCount = null,Object? bankJournalId = freezed,Object? bankJournalName = freezed,Object? bankId = freezed,Object? bankName = freezed,Object? state = freezed,Object? writeDate = freezed,Object? depositSlipNumber = freezed,Object? bankReference = freezed,Object? moveId = freezed,Object? depositorName = freezed,Object? notes = freezed,}) {
  return _then(_CollectionSessionDeposit(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String?,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,sessionUuid: freezed == sessionUuid ? _self.sessionUuid : sessionUuid // ignore: cast_nullable_to_non_nullable
as String?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,depositDate: freezed == depositDate ? _self.depositDate : depositDate // ignore: cast_nullable_to_non_nullable
as DateTime?,accountingDate: freezed == accountingDate ? _self.accountingDate : accountingDate // ignore: cast_nullable_to_non_nullable
as DateTime?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,depositType: null == depositType ? _self.depositType : depositType // ignore: cast_nullable_to_non_nullable
as DepositType,cashAmount: null == cashAmount ? _self.cashAmount : cashAmount // ignore: cast_nullable_to_non_nullable
as double,checkAmount: null == checkAmount ? _self.checkAmount : checkAmount // ignore: cast_nullable_to_non_nullable
as double,checkCount: null == checkCount ? _self.checkCount : checkCount // ignore: cast_nullable_to_non_nullable
as int,bankJournalId: freezed == bankJournalId ? _self.bankJournalId : bankJournalId // ignore: cast_nullable_to_non_nullable
as int?,bankJournalName: freezed == bankJournalName ? _self.bankJournalName : bankJournalName // ignore: cast_nullable_to_non_nullable
as String?,bankId: freezed == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as int?,bankName: freezed == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,depositSlipNumber: freezed == depositSlipNumber ? _self.depositSlipNumber : depositSlipNumber // ignore: cast_nullable_to_non_nullable
as String?,bankReference: freezed == bankReference ? _self.bankReference : bankReference // ignore: cast_nullable_to_non_nullable
as String?,moveId: freezed == moveId ? _self.moveId : moveId // ignore: cast_nullable_to_non_nullable
as int?,depositorName: freezed == depositorName ? _self.depositorName : depositorName // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
