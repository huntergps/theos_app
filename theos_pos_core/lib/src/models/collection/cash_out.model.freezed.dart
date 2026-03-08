// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cash_out.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CashOut {

// ============ Identifiers ============
@OdooId() int get id;@OdooLocalOnly() String? get uuid;@OdooLocalOnly() bool get isSynced;@OdooLocalOnly() DateTime? get lastSyncDate;// ============ Basic Data ============
@OdooString() String? get name;@OdooDate() DateTime get date;@OdooSelection() CashOutState get state;@OdooSelection(odooName: 'cash_flow') CashFlow get cashFlow;// ============ Relations ============
@OdooMany2One('account.journal', odooName: 'journal_id') int get journalId;@OdooMany2OneName(sourceField: 'journal_id') String? get journalName;@OdooMany2One('res.partner', odooName: 'partner_id') int? get partnerId;@OdooMany2OneName(sourceField: 'partner_id') String? get partnerName;@OdooMany2One('account.account', odooName: 'account_id_manual') int? get accountIdManual;@OdooMany2One('collection.session', odooName: 'collection_session_id') int? get collectionSessionId;@OdooMany2One('account.move', odooName: 'move_id') int? get moveId;// ============ Amount ============
@OdooFloat() double get amount;// ============ Notes ============
@OdooString() String? get note;// ============ Type Info ============
@OdooSelection(odooName: 'cash_out_type') String get typeCode;@OdooMany2One('l10n_ec_collection_box.cash_out_type', odooName: 'cash_out_type_id') int? get typeId;@OdooMany2OneName(sourceField: 'cash_out_type_id') String? get typeName;
/// Create a copy of CashOut
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CashOutCopyWith<CashOut> get copyWith => _$CashOutCopyWithImpl<CashOut>(this as CashOut, _$identity);

  /// Serializes this CashOut to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CashOut&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.name, name) || other.name == name)&&(identical(other.date, date) || other.date == date)&&(identical(other.state, state) || other.state == state)&&(identical(other.cashFlow, cashFlow) || other.cashFlow == cashFlow)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.accountIdManual, accountIdManual) || other.accountIdManual == accountIdManual)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.moveId, moveId) || other.moveId == moveId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.note, note) || other.note == note)&&(identical(other.typeCode, typeCode) || other.typeCode == typeCode)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.typeName, typeName) || other.typeName == typeName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,uuid,isSynced,lastSyncDate,name,date,state,cashFlow,journalId,journalName,partnerId,partnerName,accountIdManual,collectionSessionId,moveId,amount,note,typeCode,typeId,typeName]);

@override
String toString() {
  return 'CashOut(id: $id, uuid: $uuid, isSynced: $isSynced, lastSyncDate: $lastSyncDate, name: $name, date: $date, state: $state, cashFlow: $cashFlow, journalId: $journalId, journalName: $journalName, partnerId: $partnerId, partnerName: $partnerName, accountIdManual: $accountIdManual, collectionSessionId: $collectionSessionId, moveId: $moveId, amount: $amount, note: $note, typeCode: $typeCode, typeId: $typeId, typeName: $typeName)';
}


}

/// @nodoc
abstract mixin class $CashOutCopyWith<$Res>  {
  factory $CashOutCopyWith(CashOut value, $Res Function(CashOut) _then) = _$CashOutCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? lastSyncDate,@OdooString() String? name,@OdooDate() DateTime date,@OdooSelection() CashOutState state,@OdooSelection(odooName: 'cash_flow') CashFlow cashFlow,@OdooMany2One('account.journal', odooName: 'journal_id') int journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooMany2One('account.account', odooName: 'account_id_manual') int? accountIdManual,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooMany2One('account.move', odooName: 'move_id') int? moveId,@OdooFloat() double amount,@OdooString() String? note,@OdooSelection(odooName: 'cash_out_type') String typeCode,@OdooMany2One('l10n_ec_collection_box.cash_out_type', odooName: 'cash_out_type_id') int? typeId,@OdooMany2OneName(sourceField: 'cash_out_type_id') String? typeName
});




}
/// @nodoc
class _$CashOutCopyWithImpl<$Res>
    implements $CashOutCopyWith<$Res> {
  _$CashOutCopyWithImpl(this._self, this._then);

  final CashOut _self;
  final $Res Function(CashOut) _then;

/// Create a copy of CashOut
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uuid = freezed,Object? isSynced = null,Object? lastSyncDate = freezed,Object? name = freezed,Object? date = null,Object? state = null,Object? cashFlow = null,Object? journalId = null,Object? journalName = freezed,Object? partnerId = freezed,Object? partnerName = freezed,Object? accountIdManual = freezed,Object? collectionSessionId = freezed,Object? moveId = freezed,Object? amount = null,Object? note = freezed,Object? typeCode = null,Object? typeId = freezed,Object? typeName = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as CashOutState,cashFlow: null == cashFlow ? _self.cashFlow : cashFlow // ignore: cast_nullable_to_non_nullable
as CashFlow,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,partnerId: freezed == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int?,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,accountIdManual: freezed == accountIdManual ? _self.accountIdManual : accountIdManual // ignore: cast_nullable_to_non_nullable
as int?,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,moveId: freezed == moveId ? _self.moveId : moveId // ignore: cast_nullable_to_non_nullable
as int?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,typeCode: null == typeCode ? _self.typeCode : typeCode // ignore: cast_nullable_to_non_nullable
as String,typeId: freezed == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int?,typeName: freezed == typeName ? _self.typeName : typeName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CashOut].
extension CashOutPatterns on CashOut {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CashOut value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CashOut() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CashOut value)  $default,){
final _that = this;
switch (_that) {
case _CashOut():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CashOut value)?  $default,){
final _that = this;
switch (_that) {
case _CashOut() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooString()  String? name, @OdooDate()  DateTime date, @OdooSelection()  CashOutState state, @OdooSelection(odooName: 'cash_flow')  CashFlow cashFlow, @OdooMany2One('account.journal', odooName: 'journal_id')  int journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooMany2One('account.account', odooName: 'account_id_manual')  int? accountIdManual, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('account.move', odooName: 'move_id')  int? moveId, @OdooFloat()  double amount, @OdooString()  String? note, @OdooSelection(odooName: 'cash_out_type')  String typeCode, @OdooMany2One('l10n_ec_collection_box.cash_out_type', odooName: 'cash_out_type_id')  int? typeId, @OdooMany2OneName(sourceField: 'cash_out_type_id')  String? typeName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CashOut() when $default != null:
return $default(_that.id,_that.uuid,_that.isSynced,_that.lastSyncDate,_that.name,_that.date,_that.state,_that.cashFlow,_that.journalId,_that.journalName,_that.partnerId,_that.partnerName,_that.accountIdManual,_that.collectionSessionId,_that.moveId,_that.amount,_that.note,_that.typeCode,_that.typeId,_that.typeName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooString()  String? name, @OdooDate()  DateTime date, @OdooSelection()  CashOutState state, @OdooSelection(odooName: 'cash_flow')  CashFlow cashFlow, @OdooMany2One('account.journal', odooName: 'journal_id')  int journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooMany2One('account.account', odooName: 'account_id_manual')  int? accountIdManual, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('account.move', odooName: 'move_id')  int? moveId, @OdooFloat()  double amount, @OdooString()  String? note, @OdooSelection(odooName: 'cash_out_type')  String typeCode, @OdooMany2One('l10n_ec_collection_box.cash_out_type', odooName: 'cash_out_type_id')  int? typeId, @OdooMany2OneName(sourceField: 'cash_out_type_id')  String? typeName)  $default,) {final _that = this;
switch (_that) {
case _CashOut():
return $default(_that.id,_that.uuid,_that.isSynced,_that.lastSyncDate,_that.name,_that.date,_that.state,_that.cashFlow,_that.journalId,_that.journalName,_that.partnerId,_that.partnerName,_that.accountIdManual,_that.collectionSessionId,_that.moveId,_that.amount,_that.note,_that.typeCode,_that.typeId,_that.typeName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooString()  String? name, @OdooDate()  DateTime date, @OdooSelection()  CashOutState state, @OdooSelection(odooName: 'cash_flow')  CashFlow cashFlow, @OdooMany2One('account.journal', odooName: 'journal_id')  int journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooMany2One('account.account', odooName: 'account_id_manual')  int? accountIdManual, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('account.move', odooName: 'move_id')  int? moveId, @OdooFloat()  double amount, @OdooString()  String? note, @OdooSelection(odooName: 'cash_out_type')  String typeCode, @OdooMany2One('l10n_ec_collection_box.cash_out_type', odooName: 'cash_out_type_id')  int? typeId, @OdooMany2OneName(sourceField: 'cash_out_type_id')  String? typeName)?  $default,) {final _that = this;
switch (_that) {
case _CashOut() when $default != null:
return $default(_that.id,_that.uuid,_that.isSynced,_that.lastSyncDate,_that.name,_that.date,_that.state,_that.cashFlow,_that.journalId,_that.journalName,_that.partnerId,_that.partnerName,_that.accountIdManual,_that.collectionSessionId,_that.moveId,_that.amount,_that.note,_that.typeCode,_that.typeId,_that.typeName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CashOut extends CashOut {
  const _CashOut({@OdooId() this.id = 0, @OdooLocalOnly() this.uuid, @OdooLocalOnly() this.isSynced = false, @OdooLocalOnly() this.lastSyncDate, @OdooString() this.name, @OdooDate() required this.date, @OdooSelection() this.state = CashOutState.draft, @OdooSelection(odooName: 'cash_flow') this.cashFlow = CashFlow.out, @OdooMany2One('account.journal', odooName: 'journal_id') required this.journalId, @OdooMany2OneName(sourceField: 'journal_id') this.journalName, @OdooMany2One('res.partner', odooName: 'partner_id') this.partnerId, @OdooMany2OneName(sourceField: 'partner_id') this.partnerName, @OdooMany2One('account.account', odooName: 'account_id_manual') this.accountIdManual, @OdooMany2One('collection.session', odooName: 'collection_session_id') this.collectionSessionId, @OdooMany2One('account.move', odooName: 'move_id') this.moveId, @OdooFloat() this.amount = 0.0, @OdooString() this.note, @OdooSelection(odooName: 'cash_out_type') this.typeCode = 'other', @OdooMany2One('l10n_ec_collection_box.cash_out_type', odooName: 'cash_out_type_id') this.typeId, @OdooMany2OneName(sourceField: 'cash_out_type_id') this.typeName}): super._();
  factory _CashOut.fromJson(Map<String, dynamic> json) => _$CashOutFromJson(json);

// ============ Identifiers ============
@override@JsonKey()@OdooId() final  int id;
@override@OdooLocalOnly() final  String? uuid;
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
@override@OdooLocalOnly() final  DateTime? lastSyncDate;
// ============ Basic Data ============
@override@OdooString() final  String? name;
@override@OdooDate() final  DateTime date;
@override@JsonKey()@OdooSelection() final  CashOutState state;
@override@JsonKey()@OdooSelection(odooName: 'cash_flow') final  CashFlow cashFlow;
// ============ Relations ============
@override@OdooMany2One('account.journal', odooName: 'journal_id') final  int journalId;
@override@OdooMany2OneName(sourceField: 'journal_id') final  String? journalName;
@override@OdooMany2One('res.partner', odooName: 'partner_id') final  int? partnerId;
@override@OdooMany2OneName(sourceField: 'partner_id') final  String? partnerName;
@override@OdooMany2One('account.account', odooName: 'account_id_manual') final  int? accountIdManual;
@override@OdooMany2One('collection.session', odooName: 'collection_session_id') final  int? collectionSessionId;
@override@OdooMany2One('account.move', odooName: 'move_id') final  int? moveId;
// ============ Amount ============
@override@JsonKey()@OdooFloat() final  double amount;
// ============ Notes ============
@override@OdooString() final  String? note;
// ============ Type Info ============
@override@JsonKey()@OdooSelection(odooName: 'cash_out_type') final  String typeCode;
@override@OdooMany2One('l10n_ec_collection_box.cash_out_type', odooName: 'cash_out_type_id') final  int? typeId;
@override@OdooMany2OneName(sourceField: 'cash_out_type_id') final  String? typeName;

/// Create a copy of CashOut
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CashOutCopyWith<_CashOut> get copyWith => __$CashOutCopyWithImpl<_CashOut>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CashOutToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CashOut&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.name, name) || other.name == name)&&(identical(other.date, date) || other.date == date)&&(identical(other.state, state) || other.state == state)&&(identical(other.cashFlow, cashFlow) || other.cashFlow == cashFlow)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.accountIdManual, accountIdManual) || other.accountIdManual == accountIdManual)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.moveId, moveId) || other.moveId == moveId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.note, note) || other.note == note)&&(identical(other.typeCode, typeCode) || other.typeCode == typeCode)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.typeName, typeName) || other.typeName == typeName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,uuid,isSynced,lastSyncDate,name,date,state,cashFlow,journalId,journalName,partnerId,partnerName,accountIdManual,collectionSessionId,moveId,amount,note,typeCode,typeId,typeName]);

@override
String toString() {
  return 'CashOut(id: $id, uuid: $uuid, isSynced: $isSynced, lastSyncDate: $lastSyncDate, name: $name, date: $date, state: $state, cashFlow: $cashFlow, journalId: $journalId, journalName: $journalName, partnerId: $partnerId, partnerName: $partnerName, accountIdManual: $accountIdManual, collectionSessionId: $collectionSessionId, moveId: $moveId, amount: $amount, note: $note, typeCode: $typeCode, typeId: $typeId, typeName: $typeName)';
}


}

/// @nodoc
abstract mixin class _$CashOutCopyWith<$Res> implements $CashOutCopyWith<$Res> {
  factory _$CashOutCopyWith(_CashOut value, $Res Function(_CashOut) _then) = __$CashOutCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? lastSyncDate,@OdooString() String? name,@OdooDate() DateTime date,@OdooSelection() CashOutState state,@OdooSelection(odooName: 'cash_flow') CashFlow cashFlow,@OdooMany2One('account.journal', odooName: 'journal_id') int journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooMany2One('account.account', odooName: 'account_id_manual') int? accountIdManual,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooMany2One('account.move', odooName: 'move_id') int? moveId,@OdooFloat() double amount,@OdooString() String? note,@OdooSelection(odooName: 'cash_out_type') String typeCode,@OdooMany2One('l10n_ec_collection_box.cash_out_type', odooName: 'cash_out_type_id') int? typeId,@OdooMany2OneName(sourceField: 'cash_out_type_id') String? typeName
});




}
/// @nodoc
class __$CashOutCopyWithImpl<$Res>
    implements _$CashOutCopyWith<$Res> {
  __$CashOutCopyWithImpl(this._self, this._then);

  final _CashOut _self;
  final $Res Function(_CashOut) _then;

/// Create a copy of CashOut
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uuid = freezed,Object? isSynced = null,Object? lastSyncDate = freezed,Object? name = freezed,Object? date = null,Object? state = null,Object? cashFlow = null,Object? journalId = null,Object? journalName = freezed,Object? partnerId = freezed,Object? partnerName = freezed,Object? accountIdManual = freezed,Object? collectionSessionId = freezed,Object? moveId = freezed,Object? amount = null,Object? note = freezed,Object? typeCode = null,Object? typeId = freezed,Object? typeName = freezed,}) {
  return _then(_CashOut(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as CashOutState,cashFlow: null == cashFlow ? _self.cashFlow : cashFlow // ignore: cast_nullable_to_non_nullable
as CashFlow,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,partnerId: freezed == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int?,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,accountIdManual: freezed == accountIdManual ? _self.accountIdManual : accountIdManual // ignore: cast_nullable_to_non_nullable
as int?,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,moveId: freezed == moveId ? _self.moveId : moveId // ignore: cast_nullable_to_non_nullable
as int?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,typeCode: null == typeCode ? _self.typeCode : typeCode // ignore: cast_nullable_to_non_nullable
as String,typeId: freezed == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int?,typeName: freezed == typeName ? _self.typeName : typeName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
