// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'res_country_state.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ResCountryState {

@OdooId() int get id;@OdooString() String get name;@OdooString() String? get code;@OdooMany2One('res.country', odooName: 'country_id') int? get countryId;@OdooMany2OneName(sourceField: 'country_id') String? get countryName;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of ResCountryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResCountryStateCopyWith<ResCountryState> get copyWith => _$ResCountryStateCopyWithImpl<ResCountryState>(this as ResCountryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResCountryState&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.countryName, countryName) || other.countryName == countryName)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,code,countryId,countryName,writeDate);

@override
String toString() {
  return 'ResCountryState(id: $id, name: $name, code: $code, countryId: $countryId, countryName: $countryName, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $ResCountryStateCopyWith<$Res>  {
  factory $ResCountryStateCopyWith(ResCountryState value, $Res Function(ResCountryState) _then) = _$ResCountryStateCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String? code,@OdooMany2One('res.country', odooName: 'country_id') int? countryId,@OdooMany2OneName(sourceField: 'country_id') String? countryName,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$ResCountryStateCopyWithImpl<$Res>
    implements $ResCountryStateCopyWith<$Res> {
  _$ResCountryStateCopyWithImpl(this._self, this._then);

  final ResCountryState _self;
  final $Res Function(ResCountryState) _then;

/// Create a copy of ResCountryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? code = freezed,Object? countryId = freezed,Object? countryName = freezed,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as int?,countryName: freezed == countryName ? _self.countryName : countryName // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ResCountryState].
extension ResCountryStatePatterns on ResCountryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResCountryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResCountryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResCountryState value)  $default,){
final _that = this;
switch (_that) {
case _ResCountryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResCountryState value)?  $default,){
final _that = this;
switch (_that) {
case _ResCountryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? code, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResCountryState() when $default != null:
return $default(_that.id,_that.name,_that.code,_that.countryId,_that.countryName,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? code, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _ResCountryState():
return $default(_that.id,_that.name,_that.code,_that.countryId,_that.countryName,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooString()  String? code, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _ResCountryState() when $default != null:
return $default(_that.id,_that.name,_that.code,_that.countryId,_that.countryName,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _ResCountryState extends ResCountryState {
  const _ResCountryState({@OdooId() required this.id, @OdooString() required this.name, @OdooString() this.code, @OdooMany2One('res.country', odooName: 'country_id') this.countryId, @OdooMany2OneName(sourceField: 'country_id') this.countryName, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  

@override@OdooId() final  int id;
@override@OdooString() final  String name;
@override@OdooString() final  String? code;
@override@OdooMany2One('res.country', odooName: 'country_id') final  int? countryId;
@override@OdooMany2OneName(sourceField: 'country_id') final  String? countryName;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of ResCountryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResCountryStateCopyWith<_ResCountryState> get copyWith => __$ResCountryStateCopyWithImpl<_ResCountryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResCountryState&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.countryName, countryName) || other.countryName == countryName)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,code,countryId,countryName,writeDate);

@override
String toString() {
  return 'ResCountryState(id: $id, name: $name, code: $code, countryId: $countryId, countryName: $countryName, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$ResCountryStateCopyWith<$Res> implements $ResCountryStateCopyWith<$Res> {
  factory _$ResCountryStateCopyWith(_ResCountryState value, $Res Function(_ResCountryState) _then) = __$ResCountryStateCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooString() String? code,@OdooMany2One('res.country', odooName: 'country_id') int? countryId,@OdooMany2OneName(sourceField: 'country_id') String? countryName,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$ResCountryStateCopyWithImpl<$Res>
    implements _$ResCountryStateCopyWith<$Res> {
  __$ResCountryStateCopyWithImpl(this._self, this._then);

  final _ResCountryState _self;
  final $Res Function(_ResCountryState) _then;

/// Create a copy of ResCountryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? code = freezed,Object? countryId = freezed,Object? countryName = freezed,Object? writeDate = freezed,}) {
  return _then(_ResCountryState(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as int?,countryName: freezed == countryName ? _self.countryName : countryName // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
