// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_term.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PaymentTerm {

@OdooId() int get id;@OdooString() String get name;@OdooBoolean() bool get active;@OdooString() String? get note;@OdooMany2One('res.company', odooName: 'company_id') int? get companyId;@OdooInteger() int get sequence;@OdooBoolean(odooName: 'is_cash') bool get isCash;@OdooBoolean(odooName: 'is_credit') bool get isCredit;@OdooInteger(odooName: 'due_days') int get dueDays;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of PaymentTerm
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentTermCopyWith<PaymentTerm> get copyWith => _$PaymentTermCopyWithImpl<PaymentTerm>(this as PaymentTerm, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentTerm&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.active, active) || other.active == active)&&(identical(other.note, note) || other.note == note)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.isCash, isCash) || other.isCash == isCash)&&(identical(other.isCredit, isCredit) || other.isCredit == isCredit)&&(identical(other.dueDays, dueDays) || other.dueDays == dueDays)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,active,note,companyId,sequence,isCash,isCredit,dueDays,writeDate);

@override
String toString() {
  return 'PaymentTerm(id: $id, name: $name, active: $active, note: $note, companyId: $companyId, sequence: $sequence, isCash: $isCash, isCredit: $isCredit, dueDays: $dueDays, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $PaymentTermCopyWith<$Res>  {
  factory $PaymentTermCopyWith(PaymentTerm value, $Res Function(PaymentTerm) _then) = _$PaymentTermCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooBoolean() bool active,@OdooString() String? note,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooInteger() int sequence,@OdooBoolean(odooName: 'is_cash') bool isCash,@OdooBoolean(odooName: 'is_credit') bool isCredit,@OdooInteger(odooName: 'due_days') int dueDays,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$PaymentTermCopyWithImpl<$Res>
    implements $PaymentTermCopyWith<$Res> {
  _$PaymentTermCopyWithImpl(this._self, this._then);

  final PaymentTerm _self;
  final $Res Function(PaymentTerm) _then;

/// Create a copy of PaymentTerm
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? active = null,Object? note = freezed,Object? companyId = freezed,Object? sequence = null,Object? isCash = null,Object? isCredit = null,Object? dueDays = null,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,isCash: null == isCash ? _self.isCash : isCash // ignore: cast_nullable_to_non_nullable
as bool,isCredit: null == isCredit ? _self.isCredit : isCredit // ignore: cast_nullable_to_non_nullable
as bool,dueDays: null == dueDays ? _self.dueDays : dueDays // ignore: cast_nullable_to_non_nullable
as int,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentTerm].
extension PaymentTermPatterns on PaymentTerm {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentTerm value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentTerm() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentTerm value)  $default,){
final _that = this;
switch (_that) {
case _PaymentTerm():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentTerm value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentTerm() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooString()  String? note, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooInteger()  int sequence, @OdooBoolean(odooName: 'is_cash')  bool isCash, @OdooBoolean(odooName: 'is_credit')  bool isCredit, @OdooInteger(odooName: 'due_days')  int dueDays, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentTerm() when $default != null:
return $default(_that.id,_that.name,_that.active,_that.note,_that.companyId,_that.sequence,_that.isCash,_that.isCredit,_that.dueDays,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooString()  String? note, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooInteger()  int sequence, @OdooBoolean(odooName: 'is_cash')  bool isCash, @OdooBoolean(odooName: 'is_credit')  bool isCredit, @OdooInteger(odooName: 'due_days')  int dueDays, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _PaymentTerm():
return $default(_that.id,_that.name,_that.active,_that.note,_that.companyId,_that.sequence,_that.isCash,_that.isCredit,_that.dueDays,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooString()  String? note, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooInteger()  int sequence, @OdooBoolean(odooName: 'is_cash')  bool isCash, @OdooBoolean(odooName: 'is_credit')  bool isCredit, @OdooInteger(odooName: 'due_days')  int dueDays, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _PaymentTerm() when $default != null:
return $default(_that.id,_that.name,_that.active,_that.note,_that.companyId,_that.sequence,_that.isCash,_that.isCredit,_that.dueDays,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _PaymentTerm extends PaymentTerm {
  const _PaymentTerm({@OdooId() required this.id, @OdooString() required this.name, @OdooBoolean() this.active = true, @OdooString() this.note, @OdooMany2One('res.company', odooName: 'company_id') this.companyId, @OdooInteger() this.sequence = 10, @OdooBoolean(odooName: 'is_cash') this.isCash = true, @OdooBoolean(odooName: 'is_credit') this.isCredit = false, @OdooInteger(odooName: 'due_days') this.dueDays = 0, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  

@override@OdooId() final  int id;
@override@OdooString() final  String name;
@override@JsonKey()@OdooBoolean() final  bool active;
@override@OdooString() final  String? note;
@override@OdooMany2One('res.company', odooName: 'company_id') final  int? companyId;
@override@JsonKey()@OdooInteger() final  int sequence;
@override@JsonKey()@OdooBoolean(odooName: 'is_cash') final  bool isCash;
@override@JsonKey()@OdooBoolean(odooName: 'is_credit') final  bool isCredit;
@override@JsonKey()@OdooInteger(odooName: 'due_days') final  int dueDays;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of PaymentTerm
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentTermCopyWith<_PaymentTerm> get copyWith => __$PaymentTermCopyWithImpl<_PaymentTerm>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentTerm&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.active, active) || other.active == active)&&(identical(other.note, note) || other.note == note)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.isCash, isCash) || other.isCash == isCash)&&(identical(other.isCredit, isCredit) || other.isCredit == isCredit)&&(identical(other.dueDays, dueDays) || other.dueDays == dueDays)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,active,note,companyId,sequence,isCash,isCredit,dueDays,writeDate);

@override
String toString() {
  return 'PaymentTerm(id: $id, name: $name, active: $active, note: $note, companyId: $companyId, sequence: $sequence, isCash: $isCash, isCredit: $isCredit, dueDays: $dueDays, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$PaymentTermCopyWith<$Res> implements $PaymentTermCopyWith<$Res> {
  factory _$PaymentTermCopyWith(_PaymentTerm value, $Res Function(_PaymentTerm) _then) = __$PaymentTermCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooBoolean() bool active,@OdooString() String? note,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooInteger() int sequence,@OdooBoolean(odooName: 'is_cash') bool isCash,@OdooBoolean(odooName: 'is_credit') bool isCredit,@OdooInteger(odooName: 'due_days') int dueDays,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$PaymentTermCopyWithImpl<$Res>
    implements _$PaymentTermCopyWith<$Res> {
  __$PaymentTermCopyWithImpl(this._self, this._then);

  final _PaymentTerm _self;
  final $Res Function(_PaymentTerm) _then;

/// Create a copy of PaymentTerm
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? active = null,Object? note = freezed,Object? companyId = freezed,Object? sequence = null,Object? isCash = null,Object? isCredit = null,Object? dueDays = null,Object? writeDate = freezed,}) {
  return _then(_PaymentTerm(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,isCash: null == isCash ? _self.isCash : isCash // ignore: cast_nullable_to_non_nullable
as bool,isCredit: null == isCredit ? _self.isCredit : isCredit // ignore: cast_nullable_to_non_nullable
as bool,dueDays: null == dueDays ? _self.dueDays : dueDays // ignore: cast_nullable_to_non_nullable
as int,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
