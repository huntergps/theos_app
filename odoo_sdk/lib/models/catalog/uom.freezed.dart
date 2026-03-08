// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'uom.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Uom {

// ============ Identifiers ============
@OdooId() int get id;@OdooLocalOnly() String? get uuid;// ============ Basic Data ============
@OdooString() String get name;@OdooMany2One('uom.category', odooName: 'category_id') int? get categoryId;@OdooMany2OneName(sourceField: 'category_id') String? get categoryName;@OdooSelection(odooName: 'uom_type') String get uomTypeStr;// ============ Conversion Factors ============
@OdooFloat(precision: 6) double get factor;@OdooFloat(odooName: 'factor_inv', precision: 6) double get factorInv;@OdooFloat(precision: 5) double get rounding;// ============ Status ============
@OdooBoolean() bool get active;// ============ Sync Metadata ============
@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;@OdooLocalOnly() bool get isSynced;@OdooLocalOnly() DateTime? get localModifiedAt;
/// Create a copy of Uom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UomCopyWith<Uom> get copyWith => _$UomCopyWithImpl<Uom>(this as Uom, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Uom&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.uomTypeStr, uomTypeStr) || other.uomTypeStr == uomTypeStr)&&(identical(other.factor, factor) || other.factor == factor)&&(identical(other.factorInv, factorInv) || other.factorInv == factorInv)&&(identical(other.rounding, rounding) || other.rounding == rounding)&&(identical(other.active, active) || other.active == active)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.localModifiedAt, localModifiedAt) || other.localModifiedAt == localModifiedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,uuid,name,categoryId,categoryName,uomTypeStr,factor,factorInv,rounding,active,writeDate,isSynced,localModifiedAt);

@override
String toString() {
  return 'Uom(id: $id, uuid: $uuid, name: $name, categoryId: $categoryId, categoryName: $categoryName, uomTypeStr: $uomTypeStr, factor: $factor, factorInv: $factorInv, rounding: $rounding, active: $active, writeDate: $writeDate, isSynced: $isSynced, localModifiedAt: $localModifiedAt)';
}


}

/// @nodoc
abstract mixin class $UomCopyWith<$Res>  {
  factory $UomCopyWith(Uom value, $Res Function(Uom) _then) = _$UomCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooString() String name,@OdooMany2One('uom.category', odooName: 'category_id') int? categoryId,@OdooMany2OneName(sourceField: 'category_id') String? categoryName,@OdooSelection(odooName: 'uom_type') String uomTypeStr,@OdooFloat(precision: 6) double factor,@OdooFloat(odooName: 'factor_inv', precision: 6) double factorInv,@OdooFloat(precision: 5) double rounding,@OdooBoolean() bool active,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? localModifiedAt
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uuid = freezed,Object? name = null,Object? categoryId = freezed,Object? categoryName = freezed,Object? uomTypeStr = null,Object? factor = null,Object? factorInv = null,Object? rounding = null,Object? active = null,Object? writeDate = freezed,Object? isSynced = null,Object? localModifiedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,uomTypeStr: null == uomTypeStr ? _self.uomTypeStr : uomTypeStr // ignore: cast_nullable_to_non_nullable
as String,factor: null == factor ? _self.factor : factor // ignore: cast_nullable_to_non_nullable
as double,factorInv: null == factorInv ? _self.factorInv : factorInv // ignore: cast_nullable_to_non_nullable
as double,rounding: null == rounding ? _self.rounding : rounding // ignore: cast_nullable_to_non_nullable
as double,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,localModifiedAt: freezed == localModifiedAt ? _self.localModifiedAt : localModifiedAt // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooMany2One('uom.category', odooName: 'category_id')  int? categoryId, @OdooMany2OneName(sourceField: 'category_id')  String? categoryName, @OdooSelection(odooName: 'uom_type')  String uomTypeStr, @OdooFloat(precision: 6)  double factor, @OdooFloat(odooName: 'factor_inv', precision: 6)  double factorInv, @OdooFloat(precision: 5)  double rounding, @OdooBoolean()  bool active, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? localModifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Uom() when $default != null:
return $default(_that.id,_that.uuid,_that.name,_that.categoryId,_that.categoryName,_that.uomTypeStr,_that.factor,_that.factorInv,_that.rounding,_that.active,_that.writeDate,_that.isSynced,_that.localModifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooMany2One('uom.category', odooName: 'category_id')  int? categoryId, @OdooMany2OneName(sourceField: 'category_id')  String? categoryName, @OdooSelection(odooName: 'uom_type')  String uomTypeStr, @OdooFloat(precision: 6)  double factor, @OdooFloat(odooName: 'factor_inv', precision: 6)  double factorInv, @OdooFloat(precision: 5)  double rounding, @OdooBoolean()  bool active, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? localModifiedAt)  $default,) {final _that = this;
switch (_that) {
case _Uom():
return $default(_that.id,_that.uuid,_that.name,_that.categoryId,_that.categoryName,_that.uomTypeStr,_that.factor,_that.factorInv,_that.rounding,_that.active,_that.writeDate,_that.isSynced,_that.localModifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooMany2One('uom.category', odooName: 'category_id')  int? categoryId, @OdooMany2OneName(sourceField: 'category_id')  String? categoryName, @OdooSelection(odooName: 'uom_type')  String uomTypeStr, @OdooFloat(precision: 6)  double factor, @OdooFloat(odooName: 'factor_inv', precision: 6)  double factorInv, @OdooFloat(precision: 5)  double rounding, @OdooBoolean()  bool active, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? localModifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _Uom() when $default != null:
return $default(_that.id,_that.uuid,_that.name,_that.categoryId,_that.categoryName,_that.uomTypeStr,_that.factor,_that.factorInv,_that.rounding,_that.active,_that.writeDate,_that.isSynced,_that.localModifiedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Uom extends Uom {
  const _Uom({@OdooId() required this.id, @OdooLocalOnly() this.uuid, @OdooString() required this.name, @OdooMany2One('uom.category', odooName: 'category_id') this.categoryId, @OdooMany2OneName(sourceField: 'category_id') this.categoryName, @OdooSelection(odooName: 'uom_type') this.uomTypeStr = 'reference', @OdooFloat(precision: 6) this.factor = 1.0, @OdooFloat(odooName: 'factor_inv', precision: 6) this.factorInv = 1.0, @OdooFloat(precision: 5) this.rounding = 0.01, @OdooBoolean() this.active = true, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate, @OdooLocalOnly() this.isSynced = false, @OdooLocalOnly() this.localModifiedAt}): super._();
  

// ============ Identifiers ============
@override@OdooId() final  int id;
@override@OdooLocalOnly() final  String? uuid;
// ============ Basic Data ============
@override@OdooString() final  String name;
@override@OdooMany2One('uom.category', odooName: 'category_id') final  int? categoryId;
@override@OdooMany2OneName(sourceField: 'category_id') final  String? categoryName;
@override@JsonKey()@OdooSelection(odooName: 'uom_type') final  String uomTypeStr;
// ============ Conversion Factors ============
@override@JsonKey()@OdooFloat(precision: 6) final  double factor;
@override@JsonKey()@OdooFloat(odooName: 'factor_inv', precision: 6) final  double factorInv;
@override@JsonKey()@OdooFloat(precision: 5) final  double rounding;
// ============ Status ============
@override@JsonKey()@OdooBoolean() final  bool active;
// ============ Sync Metadata ============
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
@override@OdooLocalOnly() final  DateTime? localModifiedAt;

/// Create a copy of Uom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UomCopyWith<_Uom> get copyWith => __$UomCopyWithImpl<_Uom>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Uom&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.uomTypeStr, uomTypeStr) || other.uomTypeStr == uomTypeStr)&&(identical(other.factor, factor) || other.factor == factor)&&(identical(other.factorInv, factorInv) || other.factorInv == factorInv)&&(identical(other.rounding, rounding) || other.rounding == rounding)&&(identical(other.active, active) || other.active == active)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.localModifiedAt, localModifiedAt) || other.localModifiedAt == localModifiedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,uuid,name,categoryId,categoryName,uomTypeStr,factor,factorInv,rounding,active,writeDate,isSynced,localModifiedAt);

@override
String toString() {
  return 'Uom(id: $id, uuid: $uuid, name: $name, categoryId: $categoryId, categoryName: $categoryName, uomTypeStr: $uomTypeStr, factor: $factor, factorInv: $factorInv, rounding: $rounding, active: $active, writeDate: $writeDate, isSynced: $isSynced, localModifiedAt: $localModifiedAt)';
}


}

/// @nodoc
abstract mixin class _$UomCopyWith<$Res> implements $UomCopyWith<$Res> {
  factory _$UomCopyWith(_Uom value, $Res Function(_Uom) _then) = __$UomCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooString() String name,@OdooMany2One('uom.category', odooName: 'category_id') int? categoryId,@OdooMany2OneName(sourceField: 'category_id') String? categoryName,@OdooSelection(odooName: 'uom_type') String uomTypeStr,@OdooFloat(precision: 6) double factor,@OdooFloat(odooName: 'factor_inv', precision: 6) double factorInv,@OdooFloat(precision: 5) double rounding,@OdooBoolean() bool active,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? localModifiedAt
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uuid = freezed,Object? name = null,Object? categoryId = freezed,Object? categoryName = freezed,Object? uomTypeStr = null,Object? factor = null,Object? factorInv = null,Object? rounding = null,Object? active = null,Object? writeDate = freezed,Object? isSynced = null,Object? localModifiedAt = freezed,}) {
  return _then(_Uom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,uomTypeStr: null == uomTypeStr ? _self.uomTypeStr : uomTypeStr // ignore: cast_nullable_to_non_nullable
as String,factor: null == factor ? _self.factor : factor // ignore: cast_nullable_to_non_nullable
as double,factorInv: null == factorInv ? _self.factorInv : factorInv // ignore: cast_nullable_to_non_nullable
as double,rounding: null == rounding ? _self.rounding : rounding // ignore: cast_nullable_to_non_nullable
as double,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,localModifiedAt: freezed == localModifiedAt ? _self.localModifiedAt : localModifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$UomCategory {

@OdooId() int get id;@OdooLocalOnly() String? get uuid;@OdooString() String get name;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;@OdooLocalOnly() bool get isSynced;
/// Create a copy of UomCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UomCategoryCopyWith<UomCategory> get copyWith => _$UomCategoryCopyWithImpl<UomCategory>(this as UomCategory, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UomCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced));
}


@override
int get hashCode => Object.hash(runtimeType,id,uuid,name,writeDate,isSynced);

@override
String toString() {
  return 'UomCategory(id: $id, uuid: $uuid, name: $name, writeDate: $writeDate, isSynced: $isSynced)';
}


}

/// @nodoc
abstract mixin class $UomCategoryCopyWith<$Res>  {
  factory $UomCategoryCopyWith(UomCategory value, $Res Function(UomCategory) _then) = _$UomCategoryCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooString() String name,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool isSynced
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uuid = freezed,Object? name = null,Object? writeDate = freezed,Object? isSynced = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UomCategory() when $default != null:
return $default(_that.id,_that.uuid,_that.name,_that.writeDate,_that.isSynced);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced)  $default,) {final _that = this;
switch (_that) {
case _UomCategory():
return $default(_that.id,_that.uuid,_that.name,_that.writeDate,_that.isSynced);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced)?  $default,) {final _that = this;
switch (_that) {
case _UomCategory() when $default != null:
return $default(_that.id,_that.uuid,_that.name,_that.writeDate,_that.isSynced);case _:
  return null;

}
}

}

/// @nodoc


class _UomCategory extends UomCategory {
  const _UomCategory({@OdooId() required this.id, @OdooLocalOnly() this.uuid, @OdooString() required this.name, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate, @OdooLocalOnly() this.isSynced = false}): super._();
  

@override@OdooId() final  int id;
@override@OdooLocalOnly() final  String? uuid;
@override@OdooString() final  String name;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;

/// Create a copy of UomCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UomCategoryCopyWith<_UomCategory> get copyWith => __$UomCategoryCopyWithImpl<_UomCategory>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UomCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced));
}


@override
int get hashCode => Object.hash(runtimeType,id,uuid,name,writeDate,isSynced);

@override
String toString() {
  return 'UomCategory(id: $id, uuid: $uuid, name: $name, writeDate: $writeDate, isSynced: $isSynced)';
}


}

/// @nodoc
abstract mixin class _$UomCategoryCopyWith<$Res> implements $UomCategoryCopyWith<$Res> {
  factory _$UomCategoryCopyWith(_UomCategory value, $Res Function(_UomCategory) _then) = __$UomCategoryCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooString() String name,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool isSynced
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uuid = freezed,Object? name = null,Object? writeDate = freezed,Object? isSynced = null,}) {
  return _then(_UomCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
