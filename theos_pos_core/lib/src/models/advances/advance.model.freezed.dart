// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'advance.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Advance {

@OdooId() int get id;@OdooLocalOnly() String? get advanceUuid;@OdooString() String? get name;@OdooDate() DateTime get date;@OdooDate(odooName: 'date_estimated') DateTime get dateEstimated;@OdooDate(odooName: 'date_due') DateTime? get dateDue;@OdooSelection() AdvanceState get state;@OdooSelection(odooName: 'advance_type') AdvanceType get advanceType;@OdooMany2One('res.partner', odooName: 'partner_id') int get partnerId;@OdooMany2OneName(sourceField: 'partner_id') String? get partnerName;@OdooString() String get reference;@OdooFloat() double get amount;@OdooFloat(odooName: 'amount_used') double get amountUsed;@OdooFloat(odooName: 'amount_available') double get amountAvailable;@OdooFloat(odooName: 'amount_returned') double get amountReturned;@OdooFloat(odooName: 'usage_percentage') double get usagePercentage;@OdooInteger(odooName: 'days_to_expire') int? get daysToExpire;@OdooBoolean(odooName: 'is_expired') bool get isExpired;@OdooMany2One('collection.session', odooName: 'collection_session_id') int? get collectionSessionId;@OdooMany2One('sale.order', odooName: 'sale_order_id') int? get saleOrderId;@OdooLocalOnly() List<AdvanceLine> get lines;
/// Create a copy of Advance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdvanceCopyWith<Advance> get copyWith => _$AdvanceCopyWithImpl<Advance>(this as Advance, _$identity);

  /// Serializes this Advance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Advance&&(identical(other.id, id) || other.id == id)&&(identical(other.advanceUuid, advanceUuid) || other.advanceUuid == advanceUuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.date, date) || other.date == date)&&(identical(other.dateEstimated, dateEstimated) || other.dateEstimated == dateEstimated)&&(identical(other.dateDue, dateDue) || other.dateDue == dateDue)&&(identical(other.state, state) || other.state == state)&&(identical(other.advanceType, advanceType) || other.advanceType == advanceType)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.amountUsed, amountUsed) || other.amountUsed == amountUsed)&&(identical(other.amountAvailable, amountAvailable) || other.amountAvailable == amountAvailable)&&(identical(other.amountReturned, amountReturned) || other.amountReturned == amountReturned)&&(identical(other.usagePercentage, usagePercentage) || other.usagePercentage == usagePercentage)&&(identical(other.daysToExpire, daysToExpire) || other.daysToExpire == daysToExpire)&&(identical(other.isExpired, isExpired) || other.isExpired == isExpired)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.saleOrderId, saleOrderId) || other.saleOrderId == saleOrderId)&&const DeepCollectionEquality().equals(other.lines, lines));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,advanceUuid,name,date,dateEstimated,dateDue,state,advanceType,partnerId,partnerName,reference,amount,amountUsed,amountAvailable,amountReturned,usagePercentage,daysToExpire,isExpired,collectionSessionId,saleOrderId,const DeepCollectionEquality().hash(lines)]);

@override
String toString() {
  return 'Advance(id: $id, advanceUuid: $advanceUuid, name: $name, date: $date, dateEstimated: $dateEstimated, dateDue: $dateDue, state: $state, advanceType: $advanceType, partnerId: $partnerId, partnerName: $partnerName, reference: $reference, amount: $amount, amountUsed: $amountUsed, amountAvailable: $amountAvailable, amountReturned: $amountReturned, usagePercentage: $usagePercentage, daysToExpire: $daysToExpire, isExpired: $isExpired, collectionSessionId: $collectionSessionId, saleOrderId: $saleOrderId, lines: $lines)';
}


}

/// @nodoc
abstract mixin class $AdvanceCopyWith<$Res>  {
  factory $AdvanceCopyWith(Advance value, $Res Function(Advance) _then) = _$AdvanceCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? advanceUuid,@OdooString() String? name,@OdooDate() DateTime date,@OdooDate(odooName: 'date_estimated') DateTime dateEstimated,@OdooDate(odooName: 'date_due') DateTime? dateDue,@OdooSelection() AdvanceState state,@OdooSelection(odooName: 'advance_type') AdvanceType advanceType,@OdooMany2One('res.partner', odooName: 'partner_id') int partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooString() String reference,@OdooFloat() double amount,@OdooFloat(odooName: 'amount_used') double amountUsed,@OdooFloat(odooName: 'amount_available') double amountAvailable,@OdooFloat(odooName: 'amount_returned') double amountReturned,@OdooFloat(odooName: 'usage_percentage') double usagePercentage,@OdooInteger(odooName: 'days_to_expire') int? daysToExpire,@OdooBoolean(odooName: 'is_expired') bool isExpired,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooMany2One('sale.order', odooName: 'sale_order_id') int? saleOrderId,@OdooLocalOnly() List<AdvanceLine> lines
});




}
/// @nodoc
class _$AdvanceCopyWithImpl<$Res>
    implements $AdvanceCopyWith<$Res> {
  _$AdvanceCopyWithImpl(this._self, this._then);

  final Advance _self;
  final $Res Function(Advance) _then;

/// Create a copy of Advance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? advanceUuid = freezed,Object? name = freezed,Object? date = null,Object? dateEstimated = null,Object? dateDue = freezed,Object? state = null,Object? advanceType = null,Object? partnerId = null,Object? partnerName = freezed,Object? reference = null,Object? amount = null,Object? amountUsed = null,Object? amountAvailable = null,Object? amountReturned = null,Object? usagePercentage = null,Object? daysToExpire = freezed,Object? isExpired = null,Object? collectionSessionId = freezed,Object? saleOrderId = freezed,Object? lines = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,advanceUuid: freezed == advanceUuid ? _self.advanceUuid : advanceUuid // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,dateEstimated: null == dateEstimated ? _self.dateEstimated : dateEstimated // ignore: cast_nullable_to_non_nullable
as DateTime,dateDue: freezed == dateDue ? _self.dateDue : dateDue // ignore: cast_nullable_to_non_nullable
as DateTime?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as AdvanceState,advanceType: null == advanceType ? _self.advanceType : advanceType // ignore: cast_nullable_to_non_nullable
as AdvanceType,partnerId: null == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,amountUsed: null == amountUsed ? _self.amountUsed : amountUsed // ignore: cast_nullable_to_non_nullable
as double,amountAvailable: null == amountAvailable ? _self.amountAvailable : amountAvailable // ignore: cast_nullable_to_non_nullable
as double,amountReturned: null == amountReturned ? _self.amountReturned : amountReturned // ignore: cast_nullable_to_non_nullable
as double,usagePercentage: null == usagePercentage ? _self.usagePercentage : usagePercentage // ignore: cast_nullable_to_non_nullable
as double,daysToExpire: freezed == daysToExpire ? _self.daysToExpire : daysToExpire // ignore: cast_nullable_to_non_nullable
as int?,isExpired: null == isExpired ? _self.isExpired : isExpired // ignore: cast_nullable_to_non_nullable
as bool,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,saleOrderId: freezed == saleOrderId ? _self.saleOrderId : saleOrderId // ignore: cast_nullable_to_non_nullable
as int?,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<AdvanceLine>,
  ));
}

}


/// Adds pattern-matching-related methods to [Advance].
extension AdvancePatterns on Advance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Advance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Advance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Advance value)  $default,){
final _that = this;
switch (_that) {
case _Advance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Advance value)?  $default,){
final _that = this;
switch (_that) {
case _Advance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? advanceUuid, @OdooString()  String? name, @OdooDate()  DateTime date, @OdooDate(odooName: 'date_estimated')  DateTime dateEstimated, @OdooDate(odooName: 'date_due')  DateTime? dateDue, @OdooSelection()  AdvanceState state, @OdooSelection(odooName: 'advance_type')  AdvanceType advanceType, @OdooMany2One('res.partner', odooName: 'partner_id')  int partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooString()  String reference, @OdooFloat()  double amount, @OdooFloat(odooName: 'amount_used')  double amountUsed, @OdooFloat(odooName: 'amount_available')  double amountAvailable, @OdooFloat(odooName: 'amount_returned')  double amountReturned, @OdooFloat(odooName: 'usage_percentage')  double usagePercentage, @OdooInteger(odooName: 'days_to_expire')  int? daysToExpire, @OdooBoolean(odooName: 'is_expired')  bool isExpired, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('sale.order', odooName: 'sale_order_id')  int? saleOrderId, @OdooLocalOnly()  List<AdvanceLine> lines)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Advance() when $default != null:
return $default(_that.id,_that.advanceUuid,_that.name,_that.date,_that.dateEstimated,_that.dateDue,_that.state,_that.advanceType,_that.partnerId,_that.partnerName,_that.reference,_that.amount,_that.amountUsed,_that.amountAvailable,_that.amountReturned,_that.usagePercentage,_that.daysToExpire,_that.isExpired,_that.collectionSessionId,_that.saleOrderId,_that.lines);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? advanceUuid, @OdooString()  String? name, @OdooDate()  DateTime date, @OdooDate(odooName: 'date_estimated')  DateTime dateEstimated, @OdooDate(odooName: 'date_due')  DateTime? dateDue, @OdooSelection()  AdvanceState state, @OdooSelection(odooName: 'advance_type')  AdvanceType advanceType, @OdooMany2One('res.partner', odooName: 'partner_id')  int partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooString()  String reference, @OdooFloat()  double amount, @OdooFloat(odooName: 'amount_used')  double amountUsed, @OdooFloat(odooName: 'amount_available')  double amountAvailable, @OdooFloat(odooName: 'amount_returned')  double amountReturned, @OdooFloat(odooName: 'usage_percentage')  double usagePercentage, @OdooInteger(odooName: 'days_to_expire')  int? daysToExpire, @OdooBoolean(odooName: 'is_expired')  bool isExpired, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('sale.order', odooName: 'sale_order_id')  int? saleOrderId, @OdooLocalOnly()  List<AdvanceLine> lines)  $default,) {final _that = this;
switch (_that) {
case _Advance():
return $default(_that.id,_that.advanceUuid,_that.name,_that.date,_that.dateEstimated,_that.dateDue,_that.state,_that.advanceType,_that.partnerId,_that.partnerName,_that.reference,_that.amount,_that.amountUsed,_that.amountAvailable,_that.amountReturned,_that.usagePercentage,_that.daysToExpire,_that.isExpired,_that.collectionSessionId,_that.saleOrderId,_that.lines);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? advanceUuid, @OdooString()  String? name, @OdooDate()  DateTime date, @OdooDate(odooName: 'date_estimated')  DateTime dateEstimated, @OdooDate(odooName: 'date_due')  DateTime? dateDue, @OdooSelection()  AdvanceState state, @OdooSelection(odooName: 'advance_type')  AdvanceType advanceType, @OdooMany2One('res.partner', odooName: 'partner_id')  int partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooString()  String reference, @OdooFloat()  double amount, @OdooFloat(odooName: 'amount_used')  double amountUsed, @OdooFloat(odooName: 'amount_available')  double amountAvailable, @OdooFloat(odooName: 'amount_returned')  double amountReturned, @OdooFloat(odooName: 'usage_percentage')  double usagePercentage, @OdooInteger(odooName: 'days_to_expire')  int? daysToExpire, @OdooBoolean(odooName: 'is_expired')  bool isExpired, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('sale.order', odooName: 'sale_order_id')  int? saleOrderId, @OdooLocalOnly()  List<AdvanceLine> lines)?  $default,) {final _that = this;
switch (_that) {
case _Advance() when $default != null:
return $default(_that.id,_that.advanceUuid,_that.name,_that.date,_that.dateEstimated,_that.dateDue,_that.state,_that.advanceType,_that.partnerId,_that.partnerName,_that.reference,_that.amount,_that.amountUsed,_that.amountAvailable,_that.amountReturned,_that.usagePercentage,_that.daysToExpire,_that.isExpired,_that.collectionSessionId,_that.saleOrderId,_that.lines);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Advance extends Advance {
  const _Advance({@OdooId() this.id = 0, @OdooLocalOnly() this.advanceUuid, @OdooString() this.name, @OdooDate() required this.date, @OdooDate(odooName: 'date_estimated') required this.dateEstimated, @OdooDate(odooName: 'date_due') this.dateDue, @OdooSelection() this.state = AdvanceState.draft, @OdooSelection(odooName: 'advance_type') required this.advanceType, @OdooMany2One('res.partner', odooName: 'partner_id') required this.partnerId, @OdooMany2OneName(sourceField: 'partner_id') this.partnerName, @OdooString() required this.reference, @OdooFloat() this.amount = 0, @OdooFloat(odooName: 'amount_used') this.amountUsed = 0, @OdooFloat(odooName: 'amount_available') this.amountAvailable = 0, @OdooFloat(odooName: 'amount_returned') this.amountReturned = 0, @OdooFloat(odooName: 'usage_percentage') this.usagePercentage = 0, @OdooInteger(odooName: 'days_to_expire') this.daysToExpire, @OdooBoolean(odooName: 'is_expired') this.isExpired = false, @OdooMany2One('collection.session', odooName: 'collection_session_id') this.collectionSessionId, @OdooMany2One('sale.order', odooName: 'sale_order_id') this.saleOrderId, @OdooLocalOnly() final  List<AdvanceLine> lines = const []}): _lines = lines,super._();
  factory _Advance.fromJson(Map<String, dynamic> json) => _$AdvanceFromJson(json);

@override@JsonKey()@OdooId() final  int id;
@override@OdooLocalOnly() final  String? advanceUuid;
@override@OdooString() final  String? name;
@override@OdooDate() final  DateTime date;
@override@OdooDate(odooName: 'date_estimated') final  DateTime dateEstimated;
@override@OdooDate(odooName: 'date_due') final  DateTime? dateDue;
@override@JsonKey()@OdooSelection() final  AdvanceState state;
@override@OdooSelection(odooName: 'advance_type') final  AdvanceType advanceType;
@override@OdooMany2One('res.partner', odooName: 'partner_id') final  int partnerId;
@override@OdooMany2OneName(sourceField: 'partner_id') final  String? partnerName;
@override@OdooString() final  String reference;
@override@JsonKey()@OdooFloat() final  double amount;
@override@JsonKey()@OdooFloat(odooName: 'amount_used') final  double amountUsed;
@override@JsonKey()@OdooFloat(odooName: 'amount_available') final  double amountAvailable;
@override@JsonKey()@OdooFloat(odooName: 'amount_returned') final  double amountReturned;
@override@JsonKey()@OdooFloat(odooName: 'usage_percentage') final  double usagePercentage;
@override@OdooInteger(odooName: 'days_to_expire') final  int? daysToExpire;
@override@JsonKey()@OdooBoolean(odooName: 'is_expired') final  bool isExpired;
@override@OdooMany2One('collection.session', odooName: 'collection_session_id') final  int? collectionSessionId;
@override@OdooMany2One('sale.order', odooName: 'sale_order_id') final  int? saleOrderId;
 final  List<AdvanceLine> _lines;
@override@JsonKey()@OdooLocalOnly() List<AdvanceLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}


/// Create a copy of Advance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdvanceCopyWith<_Advance> get copyWith => __$AdvanceCopyWithImpl<_Advance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdvanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Advance&&(identical(other.id, id) || other.id == id)&&(identical(other.advanceUuid, advanceUuid) || other.advanceUuid == advanceUuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.date, date) || other.date == date)&&(identical(other.dateEstimated, dateEstimated) || other.dateEstimated == dateEstimated)&&(identical(other.dateDue, dateDue) || other.dateDue == dateDue)&&(identical(other.state, state) || other.state == state)&&(identical(other.advanceType, advanceType) || other.advanceType == advanceType)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.amountUsed, amountUsed) || other.amountUsed == amountUsed)&&(identical(other.amountAvailable, amountAvailable) || other.amountAvailable == amountAvailable)&&(identical(other.amountReturned, amountReturned) || other.amountReturned == amountReturned)&&(identical(other.usagePercentage, usagePercentage) || other.usagePercentage == usagePercentage)&&(identical(other.daysToExpire, daysToExpire) || other.daysToExpire == daysToExpire)&&(identical(other.isExpired, isExpired) || other.isExpired == isExpired)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.saleOrderId, saleOrderId) || other.saleOrderId == saleOrderId)&&const DeepCollectionEquality().equals(other._lines, _lines));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,advanceUuid,name,date,dateEstimated,dateDue,state,advanceType,partnerId,partnerName,reference,amount,amountUsed,amountAvailable,amountReturned,usagePercentage,daysToExpire,isExpired,collectionSessionId,saleOrderId,const DeepCollectionEquality().hash(_lines)]);

@override
String toString() {
  return 'Advance(id: $id, advanceUuid: $advanceUuid, name: $name, date: $date, dateEstimated: $dateEstimated, dateDue: $dateDue, state: $state, advanceType: $advanceType, partnerId: $partnerId, partnerName: $partnerName, reference: $reference, amount: $amount, amountUsed: $amountUsed, amountAvailable: $amountAvailable, amountReturned: $amountReturned, usagePercentage: $usagePercentage, daysToExpire: $daysToExpire, isExpired: $isExpired, collectionSessionId: $collectionSessionId, saleOrderId: $saleOrderId, lines: $lines)';
}


}

/// @nodoc
abstract mixin class _$AdvanceCopyWith<$Res> implements $AdvanceCopyWith<$Res> {
  factory _$AdvanceCopyWith(_Advance value, $Res Function(_Advance) _then) = __$AdvanceCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? advanceUuid,@OdooString() String? name,@OdooDate() DateTime date,@OdooDate(odooName: 'date_estimated') DateTime dateEstimated,@OdooDate(odooName: 'date_due') DateTime? dateDue,@OdooSelection() AdvanceState state,@OdooSelection(odooName: 'advance_type') AdvanceType advanceType,@OdooMany2One('res.partner', odooName: 'partner_id') int partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooString() String reference,@OdooFloat() double amount,@OdooFloat(odooName: 'amount_used') double amountUsed,@OdooFloat(odooName: 'amount_available') double amountAvailable,@OdooFloat(odooName: 'amount_returned') double amountReturned,@OdooFloat(odooName: 'usage_percentage') double usagePercentage,@OdooInteger(odooName: 'days_to_expire') int? daysToExpire,@OdooBoolean(odooName: 'is_expired') bool isExpired,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooMany2One('sale.order', odooName: 'sale_order_id') int? saleOrderId,@OdooLocalOnly() List<AdvanceLine> lines
});




}
/// @nodoc
class __$AdvanceCopyWithImpl<$Res>
    implements _$AdvanceCopyWith<$Res> {
  __$AdvanceCopyWithImpl(this._self, this._then);

  final _Advance _self;
  final $Res Function(_Advance) _then;

/// Create a copy of Advance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? advanceUuid = freezed,Object? name = freezed,Object? date = null,Object? dateEstimated = null,Object? dateDue = freezed,Object? state = null,Object? advanceType = null,Object? partnerId = null,Object? partnerName = freezed,Object? reference = null,Object? amount = null,Object? amountUsed = null,Object? amountAvailable = null,Object? amountReturned = null,Object? usagePercentage = null,Object? daysToExpire = freezed,Object? isExpired = null,Object? collectionSessionId = freezed,Object? saleOrderId = freezed,Object? lines = null,}) {
  return _then(_Advance(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,advanceUuid: freezed == advanceUuid ? _self.advanceUuid : advanceUuid // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,dateEstimated: null == dateEstimated ? _self.dateEstimated : dateEstimated // ignore: cast_nullable_to_non_nullable
as DateTime,dateDue: freezed == dateDue ? _self.dateDue : dateDue // ignore: cast_nullable_to_non_nullable
as DateTime?,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as AdvanceState,advanceType: null == advanceType ? _self.advanceType : advanceType // ignore: cast_nullable_to_non_nullable
as AdvanceType,partnerId: null == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,amountUsed: null == amountUsed ? _self.amountUsed : amountUsed // ignore: cast_nullable_to_non_nullable
as double,amountAvailable: null == amountAvailable ? _self.amountAvailable : amountAvailable // ignore: cast_nullable_to_non_nullable
as double,amountReturned: null == amountReturned ? _self.amountReturned : amountReturned // ignore: cast_nullable_to_non_nullable
as double,usagePercentage: null == usagePercentage ? _self.usagePercentage : usagePercentage // ignore: cast_nullable_to_non_nullable
as double,daysToExpire: freezed == daysToExpire ? _self.daysToExpire : daysToExpire // ignore: cast_nullable_to_non_nullable
as int?,isExpired: null == isExpired ? _self.isExpired : isExpired // ignore: cast_nullable_to_non_nullable
as bool,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,saleOrderId: freezed == saleOrderId ? _self.saleOrderId : saleOrderId // ignore: cast_nullable_to_non_nullable
as int?,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<AdvanceLine>,
  ));
}


}


/// @nodoc
mixin _$AdvanceLine {

@OdooId() int get id;@OdooLocalOnly() String? get lineUuid;@OdooMany2One('account.journal', odooName: 'journal_id') int get journalId;@OdooMany2OneName(sourceField: 'journal_id') String? get journalName;@OdooString(odooName: 'journal_type') String? get journalType;@OdooMany2One('account.advance.method.line', odooName: 'advance_method_line_id') int? get advanceMethodLineId;@OdooMany2OneName(sourceField: 'advance_method_line_id') String? get advanceMethodName;@OdooFloat() double get amount;@OdooString(odooName: 'nro_document') String? get documentNumber;@OdooDate(odooName: 'date_document') DateTime? get documentDate;@OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') int? get partnerBankId;@OdooMany2OneName(sourceField: 'partner_bank_id') String? get partnerBankName;@OdooDate(odooName: 'check_due_date') DateTime? get checkDueDate;@OdooMany2One('card.brand', odooName: 'card_brand_id') int? get cardBrandId;@OdooMany2OneName(sourceField: 'card_brand_id') String? get cardBrandName;@OdooMany2One('card.deadline', odooName: 'card_deadline_id') int? get cardDeadlineId;@OdooMany2OneName(sourceField: 'card_deadline_id') String? get cardDeadlineName;
/// Create a copy of AdvanceLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdvanceLineCopyWith<AdvanceLine> get copyWith => _$AdvanceLineCopyWithImpl<AdvanceLine>(this as AdvanceLine, _$identity);

  /// Serializes this AdvanceLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdvanceLine&&(identical(other.id, id) || other.id == id)&&(identical(other.lineUuid, lineUuid) || other.lineUuid == lineUuid)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.journalType, journalType) || other.journalType == journalType)&&(identical(other.advanceMethodLineId, advanceMethodLineId) || other.advanceMethodLineId == advanceMethodLineId)&&(identical(other.advanceMethodName, advanceMethodName) || other.advanceMethodName == advanceMethodName)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.documentNumber, documentNumber) || other.documentNumber == documentNumber)&&(identical(other.documentDate, documentDate) || other.documentDate == documentDate)&&(identical(other.partnerBankId, partnerBankId) || other.partnerBankId == partnerBankId)&&(identical(other.partnerBankName, partnerBankName) || other.partnerBankName == partnerBankName)&&(identical(other.checkDueDate, checkDueDate) || other.checkDueDate == checkDueDate)&&(identical(other.cardBrandId, cardBrandId) || other.cardBrandId == cardBrandId)&&(identical(other.cardBrandName, cardBrandName) || other.cardBrandName == cardBrandName)&&(identical(other.cardDeadlineId, cardDeadlineId) || other.cardDeadlineId == cardDeadlineId)&&(identical(other.cardDeadlineName, cardDeadlineName) || other.cardDeadlineName == cardDeadlineName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lineUuid,journalId,journalName,journalType,advanceMethodLineId,advanceMethodName,amount,documentNumber,documentDate,partnerBankId,partnerBankName,checkDueDate,cardBrandId,cardBrandName,cardDeadlineId,cardDeadlineName);

@override
String toString() {
  return 'AdvanceLine(id: $id, lineUuid: $lineUuid, journalId: $journalId, journalName: $journalName, journalType: $journalType, advanceMethodLineId: $advanceMethodLineId, advanceMethodName: $advanceMethodName, amount: $amount, documentNumber: $documentNumber, documentDate: $documentDate, partnerBankId: $partnerBankId, partnerBankName: $partnerBankName, checkDueDate: $checkDueDate, cardBrandId: $cardBrandId, cardBrandName: $cardBrandName, cardDeadlineId: $cardDeadlineId, cardDeadlineName: $cardDeadlineName)';
}


}

/// @nodoc
abstract mixin class $AdvanceLineCopyWith<$Res>  {
  factory $AdvanceLineCopyWith(AdvanceLine value, $Res Function(AdvanceLine) _then) = _$AdvanceLineCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? lineUuid,@OdooMany2One('account.journal', odooName: 'journal_id') int journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooString(odooName: 'journal_type') String? journalType,@OdooMany2One('account.advance.method.line', odooName: 'advance_method_line_id') int? advanceMethodLineId,@OdooMany2OneName(sourceField: 'advance_method_line_id') String? advanceMethodName,@OdooFloat() double amount,@OdooString(odooName: 'nro_document') String? documentNumber,@OdooDate(odooName: 'date_document') DateTime? documentDate,@OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') int? partnerBankId,@OdooMany2OneName(sourceField: 'partner_bank_id') String? partnerBankName,@OdooDate(odooName: 'check_due_date') DateTime? checkDueDate,@OdooMany2One('card.brand', odooName: 'card_brand_id') int? cardBrandId,@OdooMany2OneName(sourceField: 'card_brand_id') String? cardBrandName,@OdooMany2One('card.deadline', odooName: 'card_deadline_id') int? cardDeadlineId,@OdooMany2OneName(sourceField: 'card_deadline_id') String? cardDeadlineName
});




}
/// @nodoc
class _$AdvanceLineCopyWithImpl<$Res>
    implements $AdvanceLineCopyWith<$Res> {
  _$AdvanceLineCopyWithImpl(this._self, this._then);

  final AdvanceLine _self;
  final $Res Function(AdvanceLine) _then;

/// Create a copy of AdvanceLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? lineUuid = freezed,Object? journalId = null,Object? journalName = freezed,Object? journalType = freezed,Object? advanceMethodLineId = freezed,Object? advanceMethodName = freezed,Object? amount = null,Object? documentNumber = freezed,Object? documentDate = freezed,Object? partnerBankId = freezed,Object? partnerBankName = freezed,Object? checkDueDate = freezed,Object? cardBrandId = freezed,Object? cardBrandName = freezed,Object? cardDeadlineId = freezed,Object? cardDeadlineName = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,lineUuid: freezed == lineUuid ? _self.lineUuid : lineUuid // ignore: cast_nullable_to_non_nullable
as String?,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,journalType: freezed == journalType ? _self.journalType : journalType // ignore: cast_nullable_to_non_nullable
as String?,advanceMethodLineId: freezed == advanceMethodLineId ? _self.advanceMethodLineId : advanceMethodLineId // ignore: cast_nullable_to_non_nullable
as int?,advanceMethodName: freezed == advanceMethodName ? _self.advanceMethodName : advanceMethodName // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,documentNumber: freezed == documentNumber ? _self.documentNumber : documentNumber // ignore: cast_nullable_to_non_nullable
as String?,documentDate: freezed == documentDate ? _self.documentDate : documentDate // ignore: cast_nullable_to_non_nullable
as DateTime?,partnerBankId: freezed == partnerBankId ? _self.partnerBankId : partnerBankId // ignore: cast_nullable_to_non_nullable
as int?,partnerBankName: freezed == partnerBankName ? _self.partnerBankName : partnerBankName // ignore: cast_nullable_to_non_nullable
as String?,checkDueDate: freezed == checkDueDate ? _self.checkDueDate : checkDueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,cardBrandId: freezed == cardBrandId ? _self.cardBrandId : cardBrandId // ignore: cast_nullable_to_non_nullable
as int?,cardBrandName: freezed == cardBrandName ? _self.cardBrandName : cardBrandName // ignore: cast_nullable_to_non_nullable
as String?,cardDeadlineId: freezed == cardDeadlineId ? _self.cardDeadlineId : cardDeadlineId // ignore: cast_nullable_to_non_nullable
as int?,cardDeadlineName: freezed == cardDeadlineName ? _self.cardDeadlineName : cardDeadlineName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AdvanceLine].
extension AdvanceLinePatterns on AdvanceLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdvanceLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdvanceLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdvanceLine value)  $default,){
final _that = this;
switch (_that) {
case _AdvanceLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdvanceLine value)?  $default,){
final _that = this;
switch (_that) {
case _AdvanceLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? lineUuid, @OdooMany2One('account.journal', odooName: 'journal_id')  int journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooString(odooName: 'journal_type')  String? journalType, @OdooMany2One('account.advance.method.line', odooName: 'advance_method_line_id')  int? advanceMethodLineId, @OdooMany2OneName(sourceField: 'advance_method_line_id')  String? advanceMethodName, @OdooFloat()  double amount, @OdooString(odooName: 'nro_document')  String? documentNumber, @OdooDate(odooName: 'date_document')  DateTime? documentDate, @OdooMany2One('res.partner.bank', odooName: 'partner_bank_id')  int? partnerBankId, @OdooMany2OneName(sourceField: 'partner_bank_id')  String? partnerBankName, @OdooDate(odooName: 'check_due_date')  DateTime? checkDueDate, @OdooMany2One('card.brand', odooName: 'card_brand_id')  int? cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id')  String? cardBrandName, @OdooMany2One('card.deadline', odooName: 'card_deadline_id')  int? cardDeadlineId, @OdooMany2OneName(sourceField: 'card_deadline_id')  String? cardDeadlineName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdvanceLine() when $default != null:
return $default(_that.id,_that.lineUuid,_that.journalId,_that.journalName,_that.journalType,_that.advanceMethodLineId,_that.advanceMethodName,_that.amount,_that.documentNumber,_that.documentDate,_that.partnerBankId,_that.partnerBankName,_that.checkDueDate,_that.cardBrandId,_that.cardBrandName,_that.cardDeadlineId,_that.cardDeadlineName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? lineUuid, @OdooMany2One('account.journal', odooName: 'journal_id')  int journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooString(odooName: 'journal_type')  String? journalType, @OdooMany2One('account.advance.method.line', odooName: 'advance_method_line_id')  int? advanceMethodLineId, @OdooMany2OneName(sourceField: 'advance_method_line_id')  String? advanceMethodName, @OdooFloat()  double amount, @OdooString(odooName: 'nro_document')  String? documentNumber, @OdooDate(odooName: 'date_document')  DateTime? documentDate, @OdooMany2One('res.partner.bank', odooName: 'partner_bank_id')  int? partnerBankId, @OdooMany2OneName(sourceField: 'partner_bank_id')  String? partnerBankName, @OdooDate(odooName: 'check_due_date')  DateTime? checkDueDate, @OdooMany2One('card.brand', odooName: 'card_brand_id')  int? cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id')  String? cardBrandName, @OdooMany2One('card.deadline', odooName: 'card_deadline_id')  int? cardDeadlineId, @OdooMany2OneName(sourceField: 'card_deadline_id')  String? cardDeadlineName)  $default,) {final _that = this;
switch (_that) {
case _AdvanceLine():
return $default(_that.id,_that.lineUuid,_that.journalId,_that.journalName,_that.journalType,_that.advanceMethodLineId,_that.advanceMethodName,_that.amount,_that.documentNumber,_that.documentDate,_that.partnerBankId,_that.partnerBankName,_that.checkDueDate,_that.cardBrandId,_that.cardBrandName,_that.cardDeadlineId,_that.cardDeadlineName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? lineUuid, @OdooMany2One('account.journal', odooName: 'journal_id')  int journalId, @OdooMany2OneName(sourceField: 'journal_id')  String? journalName, @OdooString(odooName: 'journal_type')  String? journalType, @OdooMany2One('account.advance.method.line', odooName: 'advance_method_line_id')  int? advanceMethodLineId, @OdooMany2OneName(sourceField: 'advance_method_line_id')  String? advanceMethodName, @OdooFloat()  double amount, @OdooString(odooName: 'nro_document')  String? documentNumber, @OdooDate(odooName: 'date_document')  DateTime? documentDate, @OdooMany2One('res.partner.bank', odooName: 'partner_bank_id')  int? partnerBankId, @OdooMany2OneName(sourceField: 'partner_bank_id')  String? partnerBankName, @OdooDate(odooName: 'check_due_date')  DateTime? checkDueDate, @OdooMany2One('card.brand', odooName: 'card_brand_id')  int? cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id')  String? cardBrandName, @OdooMany2One('card.deadline', odooName: 'card_deadline_id')  int? cardDeadlineId, @OdooMany2OneName(sourceField: 'card_deadline_id')  String? cardDeadlineName)?  $default,) {final _that = this;
switch (_that) {
case _AdvanceLine() when $default != null:
return $default(_that.id,_that.lineUuid,_that.journalId,_that.journalName,_that.journalType,_that.advanceMethodLineId,_that.advanceMethodName,_that.amount,_that.documentNumber,_that.documentDate,_that.partnerBankId,_that.partnerBankName,_that.checkDueDate,_that.cardBrandId,_that.cardBrandName,_that.cardDeadlineId,_that.cardDeadlineName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdvanceLine extends AdvanceLine {
  const _AdvanceLine({@OdooId() this.id = 0, @OdooLocalOnly() this.lineUuid, @OdooMany2One('account.journal', odooName: 'journal_id') required this.journalId, @OdooMany2OneName(sourceField: 'journal_id') this.journalName, @OdooString(odooName: 'journal_type') this.journalType, @OdooMany2One('account.advance.method.line', odooName: 'advance_method_line_id') this.advanceMethodLineId, @OdooMany2OneName(sourceField: 'advance_method_line_id') this.advanceMethodName, @OdooFloat() required this.amount, @OdooString(odooName: 'nro_document') this.documentNumber, @OdooDate(odooName: 'date_document') this.documentDate, @OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') this.partnerBankId, @OdooMany2OneName(sourceField: 'partner_bank_id') this.partnerBankName, @OdooDate(odooName: 'check_due_date') this.checkDueDate, @OdooMany2One('card.brand', odooName: 'card_brand_id') this.cardBrandId, @OdooMany2OneName(sourceField: 'card_brand_id') this.cardBrandName, @OdooMany2One('card.deadline', odooName: 'card_deadline_id') this.cardDeadlineId, @OdooMany2OneName(sourceField: 'card_deadline_id') this.cardDeadlineName}): super._();
  factory _AdvanceLine.fromJson(Map<String, dynamic> json) => _$AdvanceLineFromJson(json);

@override@JsonKey()@OdooId() final  int id;
@override@OdooLocalOnly() final  String? lineUuid;
@override@OdooMany2One('account.journal', odooName: 'journal_id') final  int journalId;
@override@OdooMany2OneName(sourceField: 'journal_id') final  String? journalName;
@override@OdooString(odooName: 'journal_type') final  String? journalType;
@override@OdooMany2One('account.advance.method.line', odooName: 'advance_method_line_id') final  int? advanceMethodLineId;
@override@OdooMany2OneName(sourceField: 'advance_method_line_id') final  String? advanceMethodName;
@override@OdooFloat() final  double amount;
@override@OdooString(odooName: 'nro_document') final  String? documentNumber;
@override@OdooDate(odooName: 'date_document') final  DateTime? documentDate;
@override@OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') final  int? partnerBankId;
@override@OdooMany2OneName(sourceField: 'partner_bank_id') final  String? partnerBankName;
@override@OdooDate(odooName: 'check_due_date') final  DateTime? checkDueDate;
@override@OdooMany2One('card.brand', odooName: 'card_brand_id') final  int? cardBrandId;
@override@OdooMany2OneName(sourceField: 'card_brand_id') final  String? cardBrandName;
@override@OdooMany2One('card.deadline', odooName: 'card_deadline_id') final  int? cardDeadlineId;
@override@OdooMany2OneName(sourceField: 'card_deadline_id') final  String? cardDeadlineName;

/// Create a copy of AdvanceLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdvanceLineCopyWith<_AdvanceLine> get copyWith => __$AdvanceLineCopyWithImpl<_AdvanceLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdvanceLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdvanceLine&&(identical(other.id, id) || other.id == id)&&(identical(other.lineUuid, lineUuid) || other.lineUuid == lineUuid)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.journalName, journalName) || other.journalName == journalName)&&(identical(other.journalType, journalType) || other.journalType == journalType)&&(identical(other.advanceMethodLineId, advanceMethodLineId) || other.advanceMethodLineId == advanceMethodLineId)&&(identical(other.advanceMethodName, advanceMethodName) || other.advanceMethodName == advanceMethodName)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.documentNumber, documentNumber) || other.documentNumber == documentNumber)&&(identical(other.documentDate, documentDate) || other.documentDate == documentDate)&&(identical(other.partnerBankId, partnerBankId) || other.partnerBankId == partnerBankId)&&(identical(other.partnerBankName, partnerBankName) || other.partnerBankName == partnerBankName)&&(identical(other.checkDueDate, checkDueDate) || other.checkDueDate == checkDueDate)&&(identical(other.cardBrandId, cardBrandId) || other.cardBrandId == cardBrandId)&&(identical(other.cardBrandName, cardBrandName) || other.cardBrandName == cardBrandName)&&(identical(other.cardDeadlineId, cardDeadlineId) || other.cardDeadlineId == cardDeadlineId)&&(identical(other.cardDeadlineName, cardDeadlineName) || other.cardDeadlineName == cardDeadlineName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lineUuid,journalId,journalName,journalType,advanceMethodLineId,advanceMethodName,amount,documentNumber,documentDate,partnerBankId,partnerBankName,checkDueDate,cardBrandId,cardBrandName,cardDeadlineId,cardDeadlineName);

@override
String toString() {
  return 'AdvanceLine(id: $id, lineUuid: $lineUuid, journalId: $journalId, journalName: $journalName, journalType: $journalType, advanceMethodLineId: $advanceMethodLineId, advanceMethodName: $advanceMethodName, amount: $amount, documentNumber: $documentNumber, documentDate: $documentDate, partnerBankId: $partnerBankId, partnerBankName: $partnerBankName, checkDueDate: $checkDueDate, cardBrandId: $cardBrandId, cardBrandName: $cardBrandName, cardDeadlineId: $cardDeadlineId, cardDeadlineName: $cardDeadlineName)';
}


}

/// @nodoc
abstract mixin class _$AdvanceLineCopyWith<$Res> implements $AdvanceLineCopyWith<$Res> {
  factory _$AdvanceLineCopyWith(_AdvanceLine value, $Res Function(_AdvanceLine) _then) = __$AdvanceLineCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? lineUuid,@OdooMany2One('account.journal', odooName: 'journal_id') int journalId,@OdooMany2OneName(sourceField: 'journal_id') String? journalName,@OdooString(odooName: 'journal_type') String? journalType,@OdooMany2One('account.advance.method.line', odooName: 'advance_method_line_id') int? advanceMethodLineId,@OdooMany2OneName(sourceField: 'advance_method_line_id') String? advanceMethodName,@OdooFloat() double amount,@OdooString(odooName: 'nro_document') String? documentNumber,@OdooDate(odooName: 'date_document') DateTime? documentDate,@OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') int? partnerBankId,@OdooMany2OneName(sourceField: 'partner_bank_id') String? partnerBankName,@OdooDate(odooName: 'check_due_date') DateTime? checkDueDate,@OdooMany2One('card.brand', odooName: 'card_brand_id') int? cardBrandId,@OdooMany2OneName(sourceField: 'card_brand_id') String? cardBrandName,@OdooMany2One('card.deadline', odooName: 'card_deadline_id') int? cardDeadlineId,@OdooMany2OneName(sourceField: 'card_deadline_id') String? cardDeadlineName
});




}
/// @nodoc
class __$AdvanceLineCopyWithImpl<$Res>
    implements _$AdvanceLineCopyWith<$Res> {
  __$AdvanceLineCopyWithImpl(this._self, this._then);

  final _AdvanceLine _self;
  final $Res Function(_AdvanceLine) _then;

/// Create a copy of AdvanceLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? lineUuid = freezed,Object? journalId = null,Object? journalName = freezed,Object? journalType = freezed,Object? advanceMethodLineId = freezed,Object? advanceMethodName = freezed,Object? amount = null,Object? documentNumber = freezed,Object? documentDate = freezed,Object? partnerBankId = freezed,Object? partnerBankName = freezed,Object? checkDueDate = freezed,Object? cardBrandId = freezed,Object? cardBrandName = freezed,Object? cardDeadlineId = freezed,Object? cardDeadlineName = freezed,}) {
  return _then(_AdvanceLine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,lineUuid: freezed == lineUuid ? _self.lineUuid : lineUuid // ignore: cast_nullable_to_non_nullable
as String?,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as int,journalName: freezed == journalName ? _self.journalName : journalName // ignore: cast_nullable_to_non_nullable
as String?,journalType: freezed == journalType ? _self.journalType : journalType // ignore: cast_nullable_to_non_nullable
as String?,advanceMethodLineId: freezed == advanceMethodLineId ? _self.advanceMethodLineId : advanceMethodLineId // ignore: cast_nullable_to_non_nullable
as int?,advanceMethodName: freezed == advanceMethodName ? _self.advanceMethodName : advanceMethodName // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,documentNumber: freezed == documentNumber ? _self.documentNumber : documentNumber // ignore: cast_nullable_to_non_nullable
as String?,documentDate: freezed == documentDate ? _self.documentDate : documentDate // ignore: cast_nullable_to_non_nullable
as DateTime?,partnerBankId: freezed == partnerBankId ? _self.partnerBankId : partnerBankId // ignore: cast_nullable_to_non_nullable
as int?,partnerBankName: freezed == partnerBankName ? _self.partnerBankName : partnerBankName // ignore: cast_nullable_to_non_nullable
as String?,checkDueDate: freezed == checkDueDate ? _self.checkDueDate : checkDueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,cardBrandId: freezed == cardBrandId ? _self.cardBrandId : cardBrandId // ignore: cast_nullable_to_non_nullable
as int?,cardBrandName: freezed == cardBrandName ? _self.cardBrandName : cardBrandName // ignore: cast_nullable_to_non_nullable
as String?,cardDeadlineId: freezed == cardDeadlineId ? _self.cardDeadlineId : cardDeadlineId // ignore: cast_nullable_to_non_nullable
as int?,cardDeadlineName: freezed == cardDeadlineName ? _self.cardDeadlineName : cardDeadlineName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
