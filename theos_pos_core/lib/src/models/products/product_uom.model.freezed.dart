// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_uom.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProductUom {

@OdooId() int get id;@OdooMany2One('product.product', odooName: 'product_id') int get productId;@OdooMany2One('uom.uom', odooName: 'uom_id') int get uomId;@OdooMany2OneName(sourceField: 'uom_id') String? get uomName;@OdooString() String get barcode;@OdooMany2One('res.company', odooName: 'company_id') int? get companyId;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;
/// Create a copy of ProductUom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductUomCopyWith<ProductUom> get copyWith => _$ProductUomCopyWithImpl<ProductUom>(this as ProductUom, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductUom&&(identical(other.id, id) || other.id == id)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.uomId, uomId) || other.uomId == uomId)&&(identical(other.uomName, uomName) || other.uomName == uomName)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,productId,uomId,uomName,barcode,companyId,writeDate);

@override
String toString() {
  return 'ProductUom(id: $id, productId: $productId, uomId: $uomId, uomName: $uomName, barcode: $barcode, companyId: $companyId, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $ProductUomCopyWith<$Res>  {
  factory $ProductUomCopyWith(ProductUom value, $Res Function(ProductUom) _then) = _$ProductUomCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooMany2One('product.product', odooName: 'product_id') int productId,@OdooMany2One('uom.uom', odooName: 'uom_id') int uomId,@OdooMany2OneName(sourceField: 'uom_id') String? uomName,@OdooString() String barcode,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class _$ProductUomCopyWithImpl<$Res>
    implements $ProductUomCopyWith<$Res> {
  _$ProductUomCopyWithImpl(this._self, this._then);

  final ProductUom _self;
  final $Res Function(ProductUom) _then;

/// Create a copy of ProductUom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? productId = null,Object? uomId = null,Object? uomName = freezed,Object? barcode = null,Object? companyId = freezed,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as int,uomId: null == uomId ? _self.uomId : uomId // ignore: cast_nullable_to_non_nullable
as int,uomName: freezed == uomName ? _self.uomName : uomName // ignore: cast_nullable_to_non_nullable
as String?,barcode: null == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductUom].
extension ProductUomPatterns on ProductUom {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductUom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductUom() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductUom value)  $default,){
final _that = this;
switch (_that) {
case _ProductUom():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductUom value)?  $default,){
final _that = this;
switch (_that) {
case _ProductUom() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooMany2One('product.product', odooName: 'product_id')  int productId, @OdooMany2One('uom.uom', odooName: 'uom_id')  int uomId, @OdooMany2OneName(sourceField: 'uom_id')  String? uomName, @OdooString()  String barcode, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductUom() when $default != null:
return $default(_that.id,_that.productId,_that.uomId,_that.uomName,_that.barcode,_that.companyId,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooMany2One('product.product', odooName: 'product_id')  int productId, @OdooMany2One('uom.uom', odooName: 'uom_id')  int uomId, @OdooMany2OneName(sourceField: 'uom_id')  String? uomName, @OdooString()  String barcode, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _ProductUom():
return $default(_that.id,_that.productId,_that.uomId,_that.uomName,_that.barcode,_that.companyId,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooMany2One('product.product', odooName: 'product_id')  int productId, @OdooMany2One('uom.uom', odooName: 'uom_id')  int uomId, @OdooMany2OneName(sourceField: 'uom_id')  String? uomName, @OdooString()  String barcode, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _ProductUom() when $default != null:
return $default(_that.id,_that.productId,_that.uomId,_that.uomName,_that.barcode,_that.companyId,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _ProductUom extends ProductUom {
  const _ProductUom({@OdooId() required this.id, @OdooMany2One('product.product', odooName: 'product_id') required this.productId, @OdooMany2One('uom.uom', odooName: 'uom_id') required this.uomId, @OdooMany2OneName(sourceField: 'uom_id') this.uomName, @OdooString() required this.barcode, @OdooMany2One('res.company', odooName: 'company_id') this.companyId, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate}): super._();
  

@override@OdooId() final  int id;
@override@OdooMany2One('product.product', odooName: 'product_id') final  int productId;
@override@OdooMany2One('uom.uom', odooName: 'uom_id') final  int uomId;
@override@OdooMany2OneName(sourceField: 'uom_id') final  String? uomName;
@override@OdooString() final  String barcode;
@override@OdooMany2One('res.company', odooName: 'company_id') final  int? companyId;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;

/// Create a copy of ProductUom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductUomCopyWith<_ProductUom> get copyWith => __$ProductUomCopyWithImpl<_ProductUom>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductUom&&(identical(other.id, id) || other.id == id)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.uomId, uomId) || other.uomId == uomId)&&(identical(other.uomName, uomName) || other.uomName == uomName)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,productId,uomId,uomName,barcode,companyId,writeDate);

@override
String toString() {
  return 'ProductUom(id: $id, productId: $productId, uomId: $uomId, uomName: $uomName, barcode: $barcode, companyId: $companyId, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$ProductUomCopyWith<$Res> implements $ProductUomCopyWith<$Res> {
  factory _$ProductUomCopyWith(_ProductUom value, $Res Function(_ProductUom) _then) = __$ProductUomCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooMany2One('product.product', odooName: 'product_id') int productId,@OdooMany2One('uom.uom', odooName: 'uom_id') int uomId,@OdooMany2OneName(sourceField: 'uom_id') String? uomName,@OdooString() String barcode,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate
});




}
/// @nodoc
class __$ProductUomCopyWithImpl<$Res>
    implements _$ProductUomCopyWith<$Res> {
  __$ProductUomCopyWithImpl(this._self, this._then);

  final _ProductUom _self;
  final $Res Function(_ProductUom) _then;

/// Create a copy of ProductUom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? productId = null,Object? uomId = null,Object? uomName = freezed,Object? barcode = null,Object? companyId = freezed,Object? writeDate = freezed,}) {
  return _then(_ProductUom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as int,uomId: null == uomId ? _self.uomId : uomId // ignore: cast_nullable_to_non_nullable
as int,uomName: freezed == uomName ? _self.uomName : uomName // ignore: cast_nullable_to_non_nullable
as String?,barcode: null == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
