// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fiscal_position.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FiscalPosition {

@OdooId() int get id;@OdooString() String get name;@OdooBoolean() bool get active;@OdooMany2One('res.company', odooName: 'company_id') int? get companyId;@OdooMany2OneName(sourceField: 'company_id') String? get companyName;@OdooInteger() int get sequence;@OdooString() String? get note;@OdooBoolean(odooName: 'auto_apply') bool get autoApply;@OdooMany2One('res.country', odooName: 'country_id') int? get countryId;@OdooMany2OneName(sourceField: 'country_id') String? get countryName;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of FiscalPosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FiscalPositionCopyWith<FiscalPosition> get copyWith => _$FiscalPositionCopyWithImpl<FiscalPosition>(this as FiscalPosition, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FiscalPosition&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.active, active) || other.active == active)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.note, note) || other.note == note)&&(identical(other.autoApply, autoApply) || other.autoApply == autoApply)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.countryName, countryName) || other.countryName == countryName)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,active,companyId,companyName,sequence,note,autoApply,countryId,countryName,writeDate);

@override
String toString() {
  return 'FiscalPosition(id: $id, name: $name, active: $active, companyId: $companyId, companyName: $companyName, sequence: $sequence, note: $note, autoApply: $autoApply, countryId: $countryId, countryName: $countryName, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $FiscalPositionCopyWith<$Res>  {
  factory $FiscalPositionCopyWith(FiscalPosition value, $Res Function(FiscalPosition) _then) = _$FiscalPositionCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooBoolean() bool active,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooInteger() int sequence,@OdooString() String? note,@OdooBoolean(odooName: 'auto_apply') bool autoApply,@OdooMany2One('res.country', odooName: 'country_id') int? countryId,@OdooMany2OneName(sourceField: 'country_id') String? countryName,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$FiscalPositionCopyWithImpl<$Res>
    implements $FiscalPositionCopyWith<$Res> {
  _$FiscalPositionCopyWithImpl(this._self, this._then);

  final FiscalPosition _self;
  final $Res Function(FiscalPosition) _then;

/// Create a copy of FiscalPosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? active = null,Object? companyId = freezed,Object? companyName = freezed,Object? sequence = null,Object? note = freezed,Object? autoApply = null,Object? countryId = freezed,Object? countryName = freezed,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,autoApply: null == autoApply ? _self.autoApply : autoApply // ignore: cast_nullable_to_non_nullable
as bool,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as int?,countryName: freezed == countryName ? _self.countryName : countryName // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [FiscalPosition].
extension FiscalPositionPatterns on FiscalPosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FiscalPosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FiscalPosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FiscalPosition value)  $default,){
final _that = this;
switch (_that) {
case _FiscalPosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FiscalPosition value)?  $default,){
final _that = this;
switch (_that) {
case _FiscalPosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooInteger()  int sequence, @OdooString()  String? note, @OdooBoolean(odooName: 'auto_apply')  bool autoApply, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FiscalPosition() when $default != null:
return $default(_that.id,_that.name,_that.active,_that.companyId,_that.companyName,_that.sequence,_that.note,_that.autoApply,_that.countryId,_that.countryName,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooInteger()  int sequence, @OdooString()  String? note, @OdooBoolean(odooName: 'auto_apply')  bool autoApply, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _FiscalPosition():
return $default(_that.id,_that.name,_that.active,_that.companyId,_that.companyName,_that.sequence,_that.note,_that.autoApply,_that.countryId,_that.countryName,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooBoolean()  bool active, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooInteger()  int sequence, @OdooString()  String? note, @OdooBoolean(odooName: 'auto_apply')  bool autoApply, @OdooMany2One('res.country', odooName: 'country_id')  int? countryId, @OdooMany2OneName(sourceField: 'country_id')  String? countryName, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _FiscalPosition() when $default != null:
return $default(_that.id,_that.name,_that.active,_that.companyId,_that.companyName,_that.sequence,_that.note,_that.autoApply,_that.countryId,_that.countryName,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _FiscalPosition extends FiscalPosition {
  const _FiscalPosition({@OdooId() required this.id, @OdooString() required this.name, @OdooBoolean() this.active = true, @OdooMany2One('res.company', odooName: 'company_id') this.companyId, @OdooMany2OneName(sourceField: 'company_id') this.companyName, @OdooInteger() this.sequence = 10, @OdooString() this.note, @OdooBoolean(odooName: 'auto_apply') this.autoApply = false, @OdooMany2One('res.country', odooName: 'country_id') this.countryId, @OdooMany2OneName(sourceField: 'country_id') this.countryName, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  

@override@OdooId() final  int id;
@override@OdooString() final  String name;
@override@JsonKey()@OdooBoolean() final  bool active;
@override@OdooMany2One('res.company', odooName: 'company_id') final  int? companyId;
@override@OdooMany2OneName(sourceField: 'company_id') final  String? companyName;
@override@JsonKey()@OdooInteger() final  int sequence;
@override@OdooString() final  String? note;
@override@JsonKey()@OdooBoolean(odooName: 'auto_apply') final  bool autoApply;
@override@OdooMany2One('res.country', odooName: 'country_id') final  int? countryId;
@override@OdooMany2OneName(sourceField: 'country_id') final  String? countryName;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of FiscalPosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FiscalPositionCopyWith<_FiscalPosition> get copyWith => __$FiscalPositionCopyWithImpl<_FiscalPosition>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FiscalPosition&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.active, active) || other.active == active)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.note, note) || other.note == note)&&(identical(other.autoApply, autoApply) || other.autoApply == autoApply)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.countryName, countryName) || other.countryName == countryName)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,active,companyId,companyName,sequence,note,autoApply,countryId,countryName,writeDate);

@override
String toString() {
  return 'FiscalPosition(id: $id, name: $name, active: $active, companyId: $companyId, companyName: $companyName, sequence: $sequence, note: $note, autoApply: $autoApply, countryId: $countryId, countryName: $countryName, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$FiscalPositionCopyWith<$Res> implements $FiscalPositionCopyWith<$Res> {
  factory _$FiscalPositionCopyWith(_FiscalPosition value, $Res Function(_FiscalPosition) _then) = __$FiscalPositionCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooBoolean() bool active,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooInteger() int sequence,@OdooString() String? note,@OdooBoolean(odooName: 'auto_apply') bool autoApply,@OdooMany2One('res.country', odooName: 'country_id') int? countryId,@OdooMany2OneName(sourceField: 'country_id') String? countryName,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$FiscalPositionCopyWithImpl<$Res>
    implements _$FiscalPositionCopyWith<$Res> {
  __$FiscalPositionCopyWithImpl(this._self, this._then);

  final _FiscalPosition _self;
  final $Res Function(_FiscalPosition) _then;

/// Create a copy of FiscalPosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? active = null,Object? companyId = freezed,Object? companyName = freezed,Object? sequence = null,Object? note = freezed,Object? autoApply = null,Object? countryId = freezed,Object? countryName = freezed,Object? writeDate = freezed,}) {
  return _then(_FiscalPosition(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,autoApply: null == autoApply ? _self.autoApply : autoApply // ignore: cast_nullable_to_non_nullable
as bool,countryId: freezed == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as int?,countryName: freezed == countryName ? _self.countryName : countryName // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$FiscalPositionTax {

 int get id; int get odooId; int get positionId; int get taxSrcId; String? get taxSrcName; int? get taxDestId; String? get taxDestName; DateTime? get writeDate;
/// Create a copy of FiscalPositionTax
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FiscalPositionTaxCopyWith<FiscalPositionTax> get copyWith => _$FiscalPositionTaxCopyWithImpl<FiscalPositionTax>(this as FiscalPositionTax, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FiscalPositionTax&&(identical(other.id, id) || other.id == id)&&(identical(other.odooId, odooId) || other.odooId == odooId)&&(identical(other.positionId, positionId) || other.positionId == positionId)&&(identical(other.taxSrcId, taxSrcId) || other.taxSrcId == taxSrcId)&&(identical(other.taxSrcName, taxSrcName) || other.taxSrcName == taxSrcName)&&(identical(other.taxDestId, taxDestId) || other.taxDestId == taxDestId)&&(identical(other.taxDestName, taxDestName) || other.taxDestName == taxDestName)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,odooId,positionId,taxSrcId,taxSrcName,taxDestId,taxDestName,writeDate);

@override
String toString() {
  return 'FiscalPositionTax(id: $id, odooId: $odooId, positionId: $positionId, taxSrcId: $taxSrcId, taxSrcName: $taxSrcName, taxDestId: $taxDestId, taxDestName: $taxDestName, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $FiscalPositionTaxCopyWith<$Res>  {
  factory $FiscalPositionTaxCopyWith(FiscalPositionTax value, $Res Function(FiscalPositionTax) _then) = _$FiscalPositionTaxCopyWithImpl;
@useResult
$Res call({
 int id, int odooId, int positionId, int taxSrcId, String? taxSrcName, int? taxDestId, String? taxDestName, DateTime? writeDate
});




}
/// @nodoc
class _$FiscalPositionTaxCopyWithImpl<$Res>
    implements $FiscalPositionTaxCopyWith<$Res> {
  _$FiscalPositionTaxCopyWithImpl(this._self, this._then);

  final FiscalPositionTax _self;
  final $Res Function(FiscalPositionTax) _then;

/// Create a copy of FiscalPositionTax
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? odooId = null,Object? positionId = null,Object? taxSrcId = null,Object? taxSrcName = freezed,Object? taxDestId = freezed,Object? taxDestName = freezed,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,odooId: null == odooId ? _self.odooId : odooId // ignore: cast_nullable_to_non_nullable
as int,positionId: null == positionId ? _self.positionId : positionId // ignore: cast_nullable_to_non_nullable
as int,taxSrcId: null == taxSrcId ? _self.taxSrcId : taxSrcId // ignore: cast_nullable_to_non_nullable
as int,taxSrcName: freezed == taxSrcName ? _self.taxSrcName : taxSrcName // ignore: cast_nullable_to_non_nullable
as String?,taxDestId: freezed == taxDestId ? _self.taxDestId : taxDestId // ignore: cast_nullable_to_non_nullable
as int?,taxDestName: freezed == taxDestName ? _self.taxDestName : taxDestName // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [FiscalPositionTax].
extension FiscalPositionTaxPatterns on FiscalPositionTax {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FiscalPositionTax value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FiscalPositionTax() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FiscalPositionTax value)  $default,){
final _that = this;
switch (_that) {
case _FiscalPositionTax():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FiscalPositionTax value)?  $default,){
final _that = this;
switch (_that) {
case _FiscalPositionTax() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int odooId,  int positionId,  int taxSrcId,  String? taxSrcName,  int? taxDestId,  String? taxDestName,  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FiscalPositionTax() when $default != null:
return $default(_that.id,_that.odooId,_that.positionId,_that.taxSrcId,_that.taxSrcName,_that.taxDestId,_that.taxDestName,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int odooId,  int positionId,  int taxSrcId,  String? taxSrcName,  int? taxDestId,  String? taxDestName,  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _FiscalPositionTax():
return $default(_that.id,_that.odooId,_that.positionId,_that.taxSrcId,_that.taxSrcName,_that.taxDestId,_that.taxDestName,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int odooId,  int positionId,  int taxSrcId,  String? taxSrcName,  int? taxDestId,  String? taxDestName,  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _FiscalPositionTax() when $default != null:
return $default(_that.id,_that.odooId,_that.positionId,_that.taxSrcId,_that.taxSrcName,_that.taxDestId,_that.taxDestName,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _FiscalPositionTax extends FiscalPositionTax {
  const _FiscalPositionTax({required this.id, required this.odooId, required this.positionId, required this.taxSrcId, this.taxSrcName, this.taxDestId, this.taxDestName, this.writeDate}): super._();
  

@override final  int id;
@override final  int odooId;
@override final  int positionId;
@override final  int taxSrcId;
@override final  String? taxSrcName;
@override final  int? taxDestId;
@override final  String? taxDestName;
@override final  DateTime? writeDate;

/// Create a copy of FiscalPositionTax
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FiscalPositionTaxCopyWith<_FiscalPositionTax> get copyWith => __$FiscalPositionTaxCopyWithImpl<_FiscalPositionTax>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FiscalPositionTax&&(identical(other.id, id) || other.id == id)&&(identical(other.odooId, odooId) || other.odooId == odooId)&&(identical(other.positionId, positionId) || other.positionId == positionId)&&(identical(other.taxSrcId, taxSrcId) || other.taxSrcId == taxSrcId)&&(identical(other.taxSrcName, taxSrcName) || other.taxSrcName == taxSrcName)&&(identical(other.taxDestId, taxDestId) || other.taxDestId == taxDestId)&&(identical(other.taxDestName, taxDestName) || other.taxDestName == taxDestName)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,odooId,positionId,taxSrcId,taxSrcName,taxDestId,taxDestName,writeDate);

@override
String toString() {
  return 'FiscalPositionTax(id: $id, odooId: $odooId, positionId: $positionId, taxSrcId: $taxSrcId, taxSrcName: $taxSrcName, taxDestId: $taxDestId, taxDestName: $taxDestName, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$FiscalPositionTaxCopyWith<$Res> implements $FiscalPositionTaxCopyWith<$Res> {
  factory _$FiscalPositionTaxCopyWith(_FiscalPositionTax value, $Res Function(_FiscalPositionTax) _then) = __$FiscalPositionTaxCopyWithImpl;
@override @useResult
$Res call({
 int id, int odooId, int positionId, int taxSrcId, String? taxSrcName, int? taxDestId, String? taxDestName, DateTime? writeDate
});




}
/// @nodoc
class __$FiscalPositionTaxCopyWithImpl<$Res>
    implements _$FiscalPositionTaxCopyWith<$Res> {
  __$FiscalPositionTaxCopyWithImpl(this._self, this._then);

  final _FiscalPositionTax _self;
  final $Res Function(_FiscalPositionTax) _then;

/// Create a copy of FiscalPositionTax
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? odooId = null,Object? positionId = null,Object? taxSrcId = null,Object? taxSrcName = freezed,Object? taxDestId = freezed,Object? taxDestName = freezed,Object? writeDate = freezed,}) {
  return _then(_FiscalPositionTax(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,odooId: null == odooId ? _self.odooId : odooId // ignore: cast_nullable_to_non_nullable
as int,positionId: null == positionId ? _self.positionId : positionId // ignore: cast_nullable_to_non_nullable
as int,taxSrcId: null == taxSrcId ? _self.taxSrcId : taxSrcId // ignore: cast_nullable_to_non_nullable
as int,taxSrcName: freezed == taxSrcName ? _self.taxSrcName : taxSrcName // ignore: cast_nullable_to_non_nullable
as String?,taxDestId: freezed == taxDestId ? _self.taxDestId : taxDestId // ignore: cast_nullable_to_non_nullable
as int?,taxDestName: freezed == taxDestName ? _self.taxDestName : taxDestName // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
