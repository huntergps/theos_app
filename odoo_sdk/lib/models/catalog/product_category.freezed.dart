// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_category.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProductCategory {

// ============ Identifiers ============
@OdooId() int get id;@OdooLocalOnly() String? get uuid;// ============ Basic Data ============
@OdooString() String get name;@OdooString(odooName: 'complete_name') String? get completeName;// ============ Hierarchy ============
@OdooMany2One('product.category', odooName: 'parent_id') int? get parentId;@OdooMany2OneName(sourceField: 'parent_id') String? get parentName;// ============ Sync Metadata ============
@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;@OdooLocalOnly() bool get isSynced;@OdooLocalOnly() DateTime? get localModifiedAt;
/// Create a copy of ProductCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductCategoryCopyWith<ProductCategory> get copyWith => _$ProductCategoryCopyWithImpl<ProductCategory>(this as ProductCategory, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.completeName, completeName) || other.completeName == completeName)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.parentName, parentName) || other.parentName == parentName)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.localModifiedAt, localModifiedAt) || other.localModifiedAt == localModifiedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,uuid,name,completeName,parentId,parentName,writeDate,isSynced,localModifiedAt);

@override
String toString() {
  return 'ProductCategory(id: $id, uuid: $uuid, name: $name, completeName: $completeName, parentId: $parentId, parentName: $parentName, writeDate: $writeDate, isSynced: $isSynced, localModifiedAt: $localModifiedAt)';
}


}

/// @nodoc
abstract mixin class $ProductCategoryCopyWith<$Res>  {
  factory $ProductCategoryCopyWith(ProductCategory value, $Res Function(ProductCategory) _then) = _$ProductCategoryCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooString() String name,@OdooString(odooName: 'complete_name') String? completeName,@OdooMany2One('product.category', odooName: 'parent_id') int? parentId,@OdooMany2OneName(sourceField: 'parent_id') String? parentName,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? localModifiedAt
});




}
/// @nodoc
class _$ProductCategoryCopyWithImpl<$Res>
    implements $ProductCategoryCopyWith<$Res> {
  _$ProductCategoryCopyWithImpl(this._self, this._then);

  final ProductCategory _self;
  final $Res Function(ProductCategory) _then;

/// Create a copy of ProductCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uuid = freezed,Object? name = null,Object? completeName = freezed,Object? parentId = freezed,Object? parentName = freezed,Object? writeDate = freezed,Object? isSynced = null,Object? localModifiedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,completeName: freezed == completeName ? _self.completeName : completeName // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as int?,parentName: freezed == parentName ? _self.parentName : parentName // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,localModifiedAt: freezed == localModifiedAt ? _self.localModifiedAt : localModifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductCategory].
extension ProductCategoryPatterns on ProductCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductCategory value)  $default,){
final _that = this;
switch (_that) {
case _ProductCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductCategory value)?  $default,){
final _that = this;
switch (_that) {
case _ProductCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooString(odooName: 'complete_name')  String? completeName, @OdooMany2One('product.category', odooName: 'parent_id')  int? parentId, @OdooMany2OneName(sourceField: 'parent_id')  String? parentName, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? localModifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductCategory() when $default != null:
return $default(_that.id,_that.uuid,_that.name,_that.completeName,_that.parentId,_that.parentName,_that.writeDate,_that.isSynced,_that.localModifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooString(odooName: 'complete_name')  String? completeName, @OdooMany2One('product.category', odooName: 'parent_id')  int? parentId, @OdooMany2OneName(sourceField: 'parent_id')  String? parentName, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? localModifiedAt)  $default,) {final _that = this;
switch (_that) {
case _ProductCategory():
return $default(_that.id,_that.uuid,_that.name,_that.completeName,_that.parentId,_that.parentName,_that.writeDate,_that.isSynced,_that.localModifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooString(odooName: 'complete_name')  String? completeName, @OdooMany2One('product.category', odooName: 'parent_id')  int? parentId, @OdooMany2OneName(sourceField: 'parent_id')  String? parentName, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? localModifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _ProductCategory() when $default != null:
return $default(_that.id,_that.uuid,_that.name,_that.completeName,_that.parentId,_that.parentName,_that.writeDate,_that.isSynced,_that.localModifiedAt);case _:
  return null;

}
}

}

/// @nodoc


class _ProductCategory extends ProductCategory {
  const _ProductCategory({@OdooId() required this.id, @OdooLocalOnly() this.uuid, @OdooString() required this.name, @OdooString(odooName: 'complete_name') this.completeName, @OdooMany2One('product.category', odooName: 'parent_id') this.parentId, @OdooMany2OneName(sourceField: 'parent_id') this.parentName, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate, @OdooLocalOnly() this.isSynced = false, @OdooLocalOnly() this.localModifiedAt}): super._();
  

// ============ Identifiers ============
@override@OdooId() final  int id;
@override@OdooLocalOnly() final  String? uuid;
// ============ Basic Data ============
@override@OdooString() final  String name;
@override@OdooString(odooName: 'complete_name') final  String? completeName;
// ============ Hierarchy ============
@override@OdooMany2One('product.category', odooName: 'parent_id') final  int? parentId;
@override@OdooMany2OneName(sourceField: 'parent_id') final  String? parentName;
// ============ Sync Metadata ============
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
@override@OdooLocalOnly() final  DateTime? localModifiedAt;

/// Create a copy of ProductCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductCategoryCopyWith<_ProductCategory> get copyWith => __$ProductCategoryCopyWithImpl<_ProductCategory>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.completeName, completeName) || other.completeName == completeName)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.parentName, parentName) || other.parentName == parentName)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.localModifiedAt, localModifiedAt) || other.localModifiedAt == localModifiedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,uuid,name,completeName,parentId,parentName,writeDate,isSynced,localModifiedAt);

@override
String toString() {
  return 'ProductCategory(id: $id, uuid: $uuid, name: $name, completeName: $completeName, parentId: $parentId, parentName: $parentName, writeDate: $writeDate, isSynced: $isSynced, localModifiedAt: $localModifiedAt)';
}


}

/// @nodoc
abstract mixin class _$ProductCategoryCopyWith<$Res> implements $ProductCategoryCopyWith<$Res> {
  factory _$ProductCategoryCopyWith(_ProductCategory value, $Res Function(_ProductCategory) _then) = __$ProductCategoryCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooString() String name,@OdooString(odooName: 'complete_name') String? completeName,@OdooMany2One('product.category', odooName: 'parent_id') int? parentId,@OdooMany2OneName(sourceField: 'parent_id') String? parentName,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? localModifiedAt
});




}
/// @nodoc
class __$ProductCategoryCopyWithImpl<$Res>
    implements _$ProductCategoryCopyWith<$Res> {
  __$ProductCategoryCopyWithImpl(this._self, this._then);

  final _ProductCategory _self;
  final $Res Function(_ProductCategory) _then;

/// Create a copy of ProductCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uuid = freezed,Object? name = null,Object? completeName = freezed,Object? parentId = freezed,Object? parentName = freezed,Object? writeDate = freezed,Object? isSynced = null,Object? localModifiedAt = freezed,}) {
  return _then(_ProductCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,completeName: freezed == completeName ? _self.completeName : completeName // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as int?,parentName: freezed == parentName ? _self.parentName : parentName // ignore: cast_nullable_to_non_nullable
as String?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,localModifiedAt: freezed == localModifiedAt ? _self.localModifiedAt : localModifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
