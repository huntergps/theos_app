// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'uom.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Uom {

// ============ Identifiers ============
@OdooId() int get id;// ============ Basic Data ============
@OdooString() String get name;@OdooMany2One('uom.category', odooName: 'category_id') int? get categoryId;@OdooMany2OneName(sourceField: 'category_id') String? get categoryName;@OdooSelection(odooName: 'uom_type') UomType get uomType;@OdooFloat() double get factor;@OdooFloat(odooName: 'factor_inv') double get factorInv;@OdooFloat() double get rounding;@OdooBoolean() bool get active;// ============ Metadata ============
@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of Uom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UomCopyWith<Uom> get copyWith => _$UomCopyWithImpl<Uom>(this as Uom, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Uom&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.uomType, uomType) || other.uomType == uomType)&&(identical(other.factor, factor) || other.factor == factor)&&(identical(other.factorInv, factorInv) || other.factorInv == factorInv)&&(identical(other.rounding, rounding) || other.rounding == rounding)&&(identical(other.active, active) || other.active == active)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,categoryId,categoryName,uomType,factor,factorInv,rounding,active,writeDate);

@override
String toString() {
  return 'Uom(id: $id, name: $name, categoryId: $categoryId, categoryName: $categoryName, uomType: $uomType, factor: $factor, factorInv: $factorInv, rounding: $rounding, active: $active, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $UomCopyWith<$Res>  {
  factory $UomCopyWith(Uom value, $Res Function(Uom) _then) = _$UomCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooMany2One('uom.category', odooName: 'category_id') int? categoryId,@OdooMany2OneName(sourceField: 'category_id') String? categoryName,@OdooSelection(odooName: 'uom_type') UomType uomType,@OdooFloat() double factor,@OdooFloat(odooName: 'factor_inv') double factorInv,@OdooFloat() double rounding,@OdooBoolean() bool active,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$UomCopyWithImpl<$Res>
    implements $UomCopyWith<$Res> {
  _$UomCopyWithImpl(this._self, this._then);

  final Uom _self;
  final $Res Function(Uom) _then;

/// Create a copy of Uom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? categoryId = freezed,Object? categoryName = freezed,Object? uomType = null,Object? factor = null,Object? factorInv = null,Object? rounding = null,Object? active = null,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,uomType: null == uomType ? _self.uomType : uomType // ignore: cast_nullable_to_non_nullable
as UomType,factor: null == factor ? _self.factor : factor // ignore: cast_nullable_to_non_nullable
as double,factorInv: null == factorInv ? _self.factorInv : factorInv // ignore: cast_nullable_to_non_nullable
as double,rounding: null == rounding ? _self.rounding : rounding // ignore: cast_nullable_to_non_nullable
as double,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Uom].
extension UomPatterns on Uom {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Uom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Uom() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Uom value)  $default,){
final _that = this;
switch (_that) {
case _Uom():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Uom value)?  $default,){
final _that = this;
switch (_that) {
case _Uom() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooMany2One('uom.category', odooName: 'category_id')  int? categoryId, @OdooMany2OneName(sourceField: 'category_id')  String? categoryName, @OdooSelection(odooName: 'uom_type')  UomType uomType, @OdooFloat()  double factor, @OdooFloat(odooName: 'factor_inv')  double factorInv, @OdooFloat()  double rounding, @OdooBoolean()  bool active, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Uom() when $default != null:
return $default(_that.id,_that.name,_that.categoryId,_that.categoryName,_that.uomType,_that.factor,_that.factorInv,_that.rounding,_that.active,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooString()  String name, @OdooMany2One('uom.category', odooName: 'category_id')  int? categoryId, @OdooMany2OneName(sourceField: 'category_id')  String? categoryName, @OdooSelection(odooName: 'uom_type')  UomType uomType, @OdooFloat()  double factor, @OdooFloat(odooName: 'factor_inv')  double factorInv, @OdooFloat()  double rounding, @OdooBoolean()  bool active, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _Uom():
return $default(_that.id,_that.name,_that.categoryId,_that.categoryName,_that.uomType,_that.factor,_that.factorInv,_that.rounding,_that.active,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooString()  String name, @OdooMany2One('uom.category', odooName: 'category_id')  int? categoryId, @OdooMany2OneName(sourceField: 'category_id')  String? categoryName, @OdooSelection(odooName: 'uom_type')  UomType uomType, @OdooFloat()  double factor, @OdooFloat(odooName: 'factor_inv')  double factorInv, @OdooFloat()  double rounding, @OdooBoolean()  bool active, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _Uom() when $default != null:
return $default(_that.id,_that.name,_that.categoryId,_that.categoryName,_that.uomType,_that.factor,_that.factorInv,_that.rounding,_that.active,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _Uom extends Uom {
  const _Uom({@OdooId() required this.id, @OdooString() required this.name, @OdooMany2One('uom.category', odooName: 'category_id') this.categoryId, @OdooMany2OneName(sourceField: 'category_id') this.categoryName, @OdooSelection(odooName: 'uom_type') this.uomType = UomType.reference, @OdooFloat() this.factor = 1.0, @OdooFloat(odooName: 'factor_inv') this.factorInv = 1.0, @OdooFloat() this.rounding = 0.01, @OdooBoolean() this.active = true, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  

// ============ Identifiers ============
@override@OdooId() final  int id;
// ============ Basic Data ============
@override@OdooString() final  String name;
@override@OdooMany2One('uom.category', odooName: 'category_id') final  int? categoryId;
@override@OdooMany2OneName(sourceField: 'category_id') final  String? categoryName;
@override@JsonKey()@OdooSelection(odooName: 'uom_type') final  UomType uomType;
@override@JsonKey()@OdooFloat() final  double factor;
@override@JsonKey()@OdooFloat(odooName: 'factor_inv') final  double factorInv;
@override@JsonKey()@OdooFloat() final  double rounding;
@override@JsonKey()@OdooBoolean() final  bool active;
// ============ Metadata ============
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of Uom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UomCopyWith<_Uom> get copyWith => __$UomCopyWithImpl<_Uom>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Uom&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.uomType, uomType) || other.uomType == uomType)&&(identical(other.factor, factor) || other.factor == factor)&&(identical(other.factorInv, factorInv) || other.factorInv == factorInv)&&(identical(other.rounding, rounding) || other.rounding == rounding)&&(identical(other.active, active) || other.active == active)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,categoryId,categoryName,uomType,factor,factorInv,rounding,active,writeDate);

@override
String toString() {
  return 'Uom(id: $id, name: $name, categoryId: $categoryId, categoryName: $categoryName, uomType: $uomType, factor: $factor, factorInv: $factorInv, rounding: $rounding, active: $active, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$UomCopyWith<$Res> implements $UomCopyWith<$Res> {
  factory _$UomCopyWith(_Uom value, $Res Function(_Uom) _then) = __$UomCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooString() String name,@OdooMany2One('uom.category', odooName: 'category_id') int? categoryId,@OdooMany2OneName(sourceField: 'category_id') String? categoryName,@OdooSelection(odooName: 'uom_type') UomType uomType,@OdooFloat() double factor,@OdooFloat(odooName: 'factor_inv') double factorInv,@OdooFloat() double rounding,@OdooBoolean() bool active,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$UomCopyWithImpl<$Res>
    implements _$UomCopyWith<$Res> {
  __$UomCopyWithImpl(this._self, this._then);

  final _Uom _self;
  final $Res Function(_Uom) _then;

/// Create a copy of Uom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? categoryId = freezed,Object? categoryName = freezed,Object? uomType = null,Object? factor = null,Object? factorInv = null,Object? rounding = null,Object? active = null,Object? writeDate = freezed,}) {
  return _then(_Uom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,uomType: null == uomType ? _self.uomType : uomType // ignore: cast_nullable_to_non_nullable
as UomType,factor: null == factor ? _self.factor : factor // ignore: cast_nullable_to_non_nullable
as double,factorInv: null == factorInv ? _self.factorInv : factorInv // ignore: cast_nullable_to_non_nullable
as double,rounding: null == rounding ? _self.rounding : rounding // ignore: cast_nullable_to_non_nullable
as double,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$UomCategory {

 int get id; int get odooId; String get name; DateTime? get writeDate;
/// Create a copy of UomCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UomCategoryCopyWith<UomCategory> get copyWith => _$UomCategoryCopyWithImpl<UomCategory>(this as UomCategory, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UomCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.odooId, odooId) || other.odooId == odooId)&&(identical(other.name, name) || other.name == name)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,odooId,name,writeDate);

@override
String toString() {
  return 'UomCategory(id: $id, odooId: $odooId, name: $name, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $UomCategoryCopyWith<$Res>  {
  factory $UomCategoryCopyWith(UomCategory value, $Res Function(UomCategory) _then) = _$UomCategoryCopyWithImpl;
@useResult
$Res call({
 int id, int odooId, String name, DateTime? writeDate
});




}
/// @nodoc
class _$UomCategoryCopyWithImpl<$Res>
    implements $UomCategoryCopyWith<$Res> {
  _$UomCategoryCopyWithImpl(this._self, this._then);

  final UomCategory _self;
  final $Res Function(UomCategory) _then;

/// Create a copy of UomCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? odooId = null,Object? name = null,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,odooId: null == odooId ? _self.odooId : odooId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [UomCategory].
extension UomCategoryPatterns on UomCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UomCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UomCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UomCategory value)  $default,){
final _that = this;
switch (_that) {
case _UomCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UomCategory value)?  $default,){
final _that = this;
switch (_that) {
case _UomCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int odooId,  String name,  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UomCategory() when $default != null:
return $default(_that.id,_that.odooId,_that.name,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int odooId,  String name,  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _UomCategory():
return $default(_that.id,_that.odooId,_that.name,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int odooId,  String name,  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _UomCategory() when $default != null:
return $default(_that.id,_that.odooId,_that.name,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _UomCategory extends UomCategory {
  const _UomCategory({required this.id, required this.odooId, required this.name, this.writeDate}): super._();
  

@override final  int id;
@override final  int odooId;
@override final  String name;
@override final  DateTime? writeDate;

/// Create a copy of UomCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UomCategoryCopyWith<_UomCategory> get copyWith => __$UomCategoryCopyWithImpl<_UomCategory>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UomCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.odooId, odooId) || other.odooId == odooId)&&(identical(other.name, name) || other.name == name)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,odooId,name,writeDate);

@override
String toString() {
  return 'UomCategory(id: $id, odooId: $odooId, name: $name, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$UomCategoryCopyWith<$Res> implements $UomCategoryCopyWith<$Res> {
  factory _$UomCategoryCopyWith(_UomCategory value, $Res Function(_UomCategory) _then) = __$UomCategoryCopyWithImpl;
@override @useResult
$Res call({
 int id, int odooId, String name, DateTime? writeDate
});




}
/// @nodoc
class __$UomCategoryCopyWithImpl<$Res>
    implements _$UomCategoryCopyWith<$Res> {
  __$UomCategoryCopyWithImpl(this._self, this._then);

  final _UomCategory _self;
  final $Res Function(_UomCategory) _then;

/// Create a copy of UomCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? odooId = null,Object? name = null,Object? writeDate = freezed,}) {
  return _then(_UomCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,odooId: null == odooId ? _self.odooId : odooId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
