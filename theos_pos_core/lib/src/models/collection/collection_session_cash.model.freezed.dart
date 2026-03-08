// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'collection_session_cash.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CollectionSessionCash {

// ============ Identifiers ============
@OdooId() int get id;@OdooLocalOnly() bool get isSynced;@OdooLocalOnly() DateTime? get lastSyncDate;// ============ Relations ============
@OdooMany2One('collection.session', odooName: 'collection_session_id') int? get collectionSessionId;// ============ Type ============
@OdooSelection(odooName: 'cash_type') CashType get cashType;// ============ Bills (quantities) ============
@OdooInteger(odooName: 'bills_100') int get bills100;@OdooInteger(odooName: 'bills_50') int get bills50;@OdooInteger(odooName: 'bills_20') int get bills20;@OdooInteger(odooName: 'bills_10') int get bills10;@OdooInteger(odooName: 'bills_5') int get bills5;@OdooInteger(odooName: 'bills_1') int get bills1;// ============ Coins (quantities) ============
@OdooInteger(odooName: 'coins_1') int get coins1;@OdooInteger(odooName: 'coins_50') int get coins50;@OdooInteger(odooName: 'coins_25') int get coins25;@OdooInteger(odooName: 'coins_10') int get coins10;@OdooInteger(odooName: 'coins_5') int get coins5;@OdooInteger(odooName: 'coins_1_cent') int get coins1Cent;// ============ Notes ============
@OdooString() String? get notes;
/// Create a copy of CollectionSessionCash
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CollectionSessionCashCopyWith<CollectionSessionCash> get copyWith => _$CollectionSessionCashCopyWithImpl<CollectionSessionCash>(this as CollectionSessionCash, _$identity);

  /// Serializes this CollectionSessionCash to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CollectionSessionCash&&(identical(other.id, id) || other.id == id)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.cashType, cashType) || other.cashType == cashType)&&(identical(other.bills100, bills100) || other.bills100 == bills100)&&(identical(other.bills50, bills50) || other.bills50 == bills50)&&(identical(other.bills20, bills20) || other.bills20 == bills20)&&(identical(other.bills10, bills10) || other.bills10 == bills10)&&(identical(other.bills5, bills5) || other.bills5 == bills5)&&(identical(other.bills1, bills1) || other.bills1 == bills1)&&(identical(other.coins1, coins1) || other.coins1 == coins1)&&(identical(other.coins50, coins50) || other.coins50 == coins50)&&(identical(other.coins25, coins25) || other.coins25 == coins25)&&(identical(other.coins10, coins10) || other.coins10 == coins10)&&(identical(other.coins5, coins5) || other.coins5 == coins5)&&(identical(other.coins1Cent, coins1Cent) || other.coins1Cent == coins1Cent)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,isSynced,lastSyncDate,collectionSessionId,cashType,bills100,bills50,bills20,bills10,bills5,bills1,coins1,coins50,coins25,coins10,coins5,coins1Cent,notes);

@override
String toString() {
  return 'CollectionSessionCash(id: $id, isSynced: $isSynced, lastSyncDate: $lastSyncDate, collectionSessionId: $collectionSessionId, cashType: $cashType, bills100: $bills100, bills50: $bills50, bills20: $bills20, bills10: $bills10, bills5: $bills5, bills1: $bills1, coins1: $coins1, coins50: $coins50, coins25: $coins25, coins10: $coins10, coins5: $coins5, coins1Cent: $coins1Cent, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $CollectionSessionCashCopyWith<$Res>  {
  factory $CollectionSessionCashCopyWith(CollectionSessionCash value, $Res Function(CollectionSessionCash) _then) = _$CollectionSessionCashCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? lastSyncDate,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooSelection(odooName: 'cash_type') CashType cashType,@OdooInteger(odooName: 'bills_100') int bills100,@OdooInteger(odooName: 'bills_50') int bills50,@OdooInteger(odooName: 'bills_20') int bills20,@OdooInteger(odooName: 'bills_10') int bills10,@OdooInteger(odooName: 'bills_5') int bills5,@OdooInteger(odooName: 'bills_1') int bills1,@OdooInteger(odooName: 'coins_1') int coins1,@OdooInteger(odooName: 'coins_50') int coins50,@OdooInteger(odooName: 'coins_25') int coins25,@OdooInteger(odooName: 'coins_10') int coins10,@OdooInteger(odooName: 'coins_5') int coins5,@OdooInteger(odooName: 'coins_1_cent') int coins1Cent,@OdooString() String? notes
});




}
/// @nodoc
class _$CollectionSessionCashCopyWithImpl<$Res>
    implements $CollectionSessionCashCopyWith<$Res> {
  _$CollectionSessionCashCopyWithImpl(this._self, this._then);

  final CollectionSessionCash _self;
  final $Res Function(CollectionSessionCash) _then;

/// Create a copy of CollectionSessionCash
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? isSynced = null,Object? lastSyncDate = freezed,Object? collectionSessionId = freezed,Object? cashType = null,Object? bills100 = null,Object? bills50 = null,Object? bills20 = null,Object? bills10 = null,Object? bills5 = null,Object? bills1 = null,Object? coins1 = null,Object? coins50 = null,Object? coins25 = null,Object? coins10 = null,Object? coins5 = null,Object? coins1Cent = null,Object? notes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,cashType: null == cashType ? _self.cashType : cashType // ignore: cast_nullable_to_non_nullable
as CashType,bills100: null == bills100 ? _self.bills100 : bills100 // ignore: cast_nullable_to_non_nullable
as int,bills50: null == bills50 ? _self.bills50 : bills50 // ignore: cast_nullable_to_non_nullable
as int,bills20: null == bills20 ? _self.bills20 : bills20 // ignore: cast_nullable_to_non_nullable
as int,bills10: null == bills10 ? _self.bills10 : bills10 // ignore: cast_nullable_to_non_nullable
as int,bills5: null == bills5 ? _self.bills5 : bills5 // ignore: cast_nullable_to_non_nullable
as int,bills1: null == bills1 ? _self.bills1 : bills1 // ignore: cast_nullable_to_non_nullable
as int,coins1: null == coins1 ? _self.coins1 : coins1 // ignore: cast_nullable_to_non_nullable
as int,coins50: null == coins50 ? _self.coins50 : coins50 // ignore: cast_nullable_to_non_nullable
as int,coins25: null == coins25 ? _self.coins25 : coins25 // ignore: cast_nullable_to_non_nullable
as int,coins10: null == coins10 ? _self.coins10 : coins10 // ignore: cast_nullable_to_non_nullable
as int,coins5: null == coins5 ? _self.coins5 : coins5 // ignore: cast_nullable_to_non_nullable
as int,coins1Cent: null == coins1Cent ? _self.coins1Cent : coins1Cent // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CollectionSessionCash].
extension CollectionSessionCashPatterns on CollectionSessionCash {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CollectionSessionCash value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CollectionSessionCash() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CollectionSessionCash value)  $default,){
final _that = this;
switch (_that) {
case _CollectionSessionCash():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CollectionSessionCash value)?  $default,){
final _that = this;
switch (_that) {
case _CollectionSessionCash() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooSelection(odooName: 'cash_type')  CashType cashType, @OdooInteger(odooName: 'bills_100')  int bills100, @OdooInteger(odooName: 'bills_50')  int bills50, @OdooInteger(odooName: 'bills_20')  int bills20, @OdooInteger(odooName: 'bills_10')  int bills10, @OdooInteger(odooName: 'bills_5')  int bills5, @OdooInteger(odooName: 'bills_1')  int bills1, @OdooInteger(odooName: 'coins_1')  int coins1, @OdooInteger(odooName: 'coins_50')  int coins50, @OdooInteger(odooName: 'coins_25')  int coins25, @OdooInteger(odooName: 'coins_10')  int coins10, @OdooInteger(odooName: 'coins_5')  int coins5, @OdooInteger(odooName: 'coins_1_cent')  int coins1Cent, @OdooString()  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CollectionSessionCash() when $default != null:
return $default(_that.id,_that.isSynced,_that.lastSyncDate,_that.collectionSessionId,_that.cashType,_that.bills100,_that.bills50,_that.bills20,_that.bills10,_that.bills5,_that.bills1,_that.coins1,_that.coins50,_that.coins25,_that.coins10,_that.coins5,_that.coins1Cent,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooSelection(odooName: 'cash_type')  CashType cashType, @OdooInteger(odooName: 'bills_100')  int bills100, @OdooInteger(odooName: 'bills_50')  int bills50, @OdooInteger(odooName: 'bills_20')  int bills20, @OdooInteger(odooName: 'bills_10')  int bills10, @OdooInteger(odooName: 'bills_5')  int bills5, @OdooInteger(odooName: 'bills_1')  int bills1, @OdooInteger(odooName: 'coins_1')  int coins1, @OdooInteger(odooName: 'coins_50')  int coins50, @OdooInteger(odooName: 'coins_25')  int coins25, @OdooInteger(odooName: 'coins_10')  int coins10, @OdooInteger(odooName: 'coins_5')  int coins5, @OdooInteger(odooName: 'coins_1_cent')  int coins1Cent, @OdooString()  String? notes)  $default,) {final _that = this;
switch (_that) {
case _CollectionSessionCash():
return $default(_that.id,_that.isSynced,_that.lastSyncDate,_that.collectionSessionId,_that.cashType,_that.bills100,_that.bills50,_that.bills20,_that.bills10,_that.bills5,_that.bills1,_that.coins1,_that.coins50,_that.coins25,_that.coins10,_that.coins5,_that.coins1Cent,_that.notes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooSelection(odooName: 'cash_type')  CashType cashType, @OdooInteger(odooName: 'bills_100')  int bills100, @OdooInteger(odooName: 'bills_50')  int bills50, @OdooInteger(odooName: 'bills_20')  int bills20, @OdooInteger(odooName: 'bills_10')  int bills10, @OdooInteger(odooName: 'bills_5')  int bills5, @OdooInteger(odooName: 'bills_1')  int bills1, @OdooInteger(odooName: 'coins_1')  int coins1, @OdooInteger(odooName: 'coins_50')  int coins50, @OdooInteger(odooName: 'coins_25')  int coins25, @OdooInteger(odooName: 'coins_10')  int coins10, @OdooInteger(odooName: 'coins_5')  int coins5, @OdooInteger(odooName: 'coins_1_cent')  int coins1Cent, @OdooString()  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _CollectionSessionCash() when $default != null:
return $default(_that.id,_that.isSynced,_that.lastSyncDate,_that.collectionSessionId,_that.cashType,_that.bills100,_that.bills50,_that.bills20,_that.bills10,_that.bills5,_that.bills1,_that.coins1,_that.coins50,_that.coins25,_that.coins10,_that.coins5,_that.coins1Cent,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CollectionSessionCash extends CollectionSessionCash {
  const _CollectionSessionCash({@OdooId() this.id = 0, @OdooLocalOnly() this.isSynced = false, @OdooLocalOnly() this.lastSyncDate, @OdooMany2One('collection.session', odooName: 'collection_session_id') this.collectionSessionId, @OdooSelection(odooName: 'cash_type') this.cashType = CashType.opening, @OdooInteger(odooName: 'bills_100') this.bills100 = 0, @OdooInteger(odooName: 'bills_50') this.bills50 = 0, @OdooInteger(odooName: 'bills_20') this.bills20 = 0, @OdooInteger(odooName: 'bills_10') this.bills10 = 0, @OdooInteger(odooName: 'bills_5') this.bills5 = 0, @OdooInteger(odooName: 'bills_1') this.bills1 = 0, @OdooInteger(odooName: 'coins_1') this.coins1 = 0, @OdooInteger(odooName: 'coins_50') this.coins50 = 0, @OdooInteger(odooName: 'coins_25') this.coins25 = 0, @OdooInteger(odooName: 'coins_10') this.coins10 = 0, @OdooInteger(odooName: 'coins_5') this.coins5 = 0, @OdooInteger(odooName: 'coins_1_cent') this.coins1Cent = 0, @OdooString() this.notes}): super._();
  factory _CollectionSessionCash.fromJson(Map<String, dynamic> json) => _$CollectionSessionCashFromJson(json);

// ============ Identifiers ============
@override@JsonKey()@OdooId() final  int id;
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
@override@OdooLocalOnly() final  DateTime? lastSyncDate;
// ============ Relations ============
@override@OdooMany2One('collection.session', odooName: 'collection_session_id') final  int? collectionSessionId;
// ============ Type ============
@override@JsonKey()@OdooSelection(odooName: 'cash_type') final  CashType cashType;
// ============ Bills (quantities) ============
@override@JsonKey()@OdooInteger(odooName: 'bills_100') final  int bills100;
@override@JsonKey()@OdooInteger(odooName: 'bills_50') final  int bills50;
@override@JsonKey()@OdooInteger(odooName: 'bills_20') final  int bills20;
@override@JsonKey()@OdooInteger(odooName: 'bills_10') final  int bills10;
@override@JsonKey()@OdooInteger(odooName: 'bills_5') final  int bills5;
@override@JsonKey()@OdooInteger(odooName: 'bills_1') final  int bills1;
// ============ Coins (quantities) ============
@override@JsonKey()@OdooInteger(odooName: 'coins_1') final  int coins1;
@override@JsonKey()@OdooInteger(odooName: 'coins_50') final  int coins50;
@override@JsonKey()@OdooInteger(odooName: 'coins_25') final  int coins25;
@override@JsonKey()@OdooInteger(odooName: 'coins_10') final  int coins10;
@override@JsonKey()@OdooInteger(odooName: 'coins_5') final  int coins5;
@override@JsonKey()@OdooInteger(odooName: 'coins_1_cent') final  int coins1Cent;
// ============ Notes ============
@override@OdooString() final  String? notes;

/// Create a copy of CollectionSessionCash
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CollectionSessionCashCopyWith<_CollectionSessionCash> get copyWith => __$CollectionSessionCashCopyWithImpl<_CollectionSessionCash>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CollectionSessionCashToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CollectionSessionCash&&(identical(other.id, id) || other.id == id)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.cashType, cashType) || other.cashType == cashType)&&(identical(other.bills100, bills100) || other.bills100 == bills100)&&(identical(other.bills50, bills50) || other.bills50 == bills50)&&(identical(other.bills20, bills20) || other.bills20 == bills20)&&(identical(other.bills10, bills10) || other.bills10 == bills10)&&(identical(other.bills5, bills5) || other.bills5 == bills5)&&(identical(other.bills1, bills1) || other.bills1 == bills1)&&(identical(other.coins1, coins1) || other.coins1 == coins1)&&(identical(other.coins50, coins50) || other.coins50 == coins50)&&(identical(other.coins25, coins25) || other.coins25 == coins25)&&(identical(other.coins10, coins10) || other.coins10 == coins10)&&(identical(other.coins5, coins5) || other.coins5 == coins5)&&(identical(other.coins1Cent, coins1Cent) || other.coins1Cent == coins1Cent)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,isSynced,lastSyncDate,collectionSessionId,cashType,bills100,bills50,bills20,bills10,bills5,bills1,coins1,coins50,coins25,coins10,coins5,coins1Cent,notes);

@override
String toString() {
  return 'CollectionSessionCash(id: $id, isSynced: $isSynced, lastSyncDate: $lastSyncDate, collectionSessionId: $collectionSessionId, cashType: $cashType, bills100: $bills100, bills50: $bills50, bills20: $bills20, bills10: $bills10, bills5: $bills5, bills1: $bills1, coins1: $coins1, coins50: $coins50, coins25: $coins25, coins10: $coins10, coins5: $coins5, coins1Cent: $coins1Cent, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$CollectionSessionCashCopyWith<$Res> implements $CollectionSessionCashCopyWith<$Res> {
  factory _$CollectionSessionCashCopyWith(_CollectionSessionCash value, $Res Function(_CollectionSessionCash) _then) = __$CollectionSessionCashCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? lastSyncDate,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooSelection(odooName: 'cash_type') CashType cashType,@OdooInteger(odooName: 'bills_100') int bills100,@OdooInteger(odooName: 'bills_50') int bills50,@OdooInteger(odooName: 'bills_20') int bills20,@OdooInteger(odooName: 'bills_10') int bills10,@OdooInteger(odooName: 'bills_5') int bills5,@OdooInteger(odooName: 'bills_1') int bills1,@OdooInteger(odooName: 'coins_1') int coins1,@OdooInteger(odooName: 'coins_50') int coins50,@OdooInteger(odooName: 'coins_25') int coins25,@OdooInteger(odooName: 'coins_10') int coins10,@OdooInteger(odooName: 'coins_5') int coins5,@OdooInteger(odooName: 'coins_1_cent') int coins1Cent,@OdooString() String? notes
});




}
/// @nodoc
class __$CollectionSessionCashCopyWithImpl<$Res>
    implements _$CollectionSessionCashCopyWith<$Res> {
  __$CollectionSessionCashCopyWithImpl(this._self, this._then);

  final _CollectionSessionCash _self;
  final $Res Function(_CollectionSessionCash) _then;

/// Create a copy of CollectionSessionCash
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? isSynced = null,Object? lastSyncDate = freezed,Object? collectionSessionId = freezed,Object? cashType = null,Object? bills100 = null,Object? bills50 = null,Object? bills20 = null,Object? bills10 = null,Object? bills5 = null,Object? bills1 = null,Object? coins1 = null,Object? coins50 = null,Object? coins25 = null,Object? coins10 = null,Object? coins5 = null,Object? coins1Cent = null,Object? notes = freezed,}) {
  return _then(_CollectionSessionCash(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,cashType: null == cashType ? _self.cashType : cashType // ignore: cast_nullable_to_non_nullable
as CashType,bills100: null == bills100 ? _self.bills100 : bills100 // ignore: cast_nullable_to_non_nullable
as int,bills50: null == bills50 ? _self.bills50 : bills50 // ignore: cast_nullable_to_non_nullable
as int,bills20: null == bills20 ? _self.bills20 : bills20 // ignore: cast_nullable_to_non_nullable
as int,bills10: null == bills10 ? _self.bills10 : bills10 // ignore: cast_nullable_to_non_nullable
as int,bills5: null == bills5 ? _self.bills5 : bills5 // ignore: cast_nullable_to_non_nullable
as int,bills1: null == bills1 ? _self.bills1 : bills1 // ignore: cast_nullable_to_non_nullable
as int,coins1: null == coins1 ? _self.coins1 : coins1 // ignore: cast_nullable_to_non_nullable
as int,coins50: null == coins50 ? _self.coins50 : coins50 // ignore: cast_nullable_to_non_nullable
as int,coins25: null == coins25 ? _self.coins25 : coins25 // ignore: cast_nullable_to_non_nullable
as int,coins10: null == coins10 ? _self.coins10 : coins10 // ignore: cast_nullable_to_non_nullable
as int,coins5: null == coins5 ? _self.coins5 : coins5 // ignore: cast_nullable_to_non_nullable
as int,coins1Cent: null == coins1Cent ? _self.coins1Cent : coins1Cent // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
