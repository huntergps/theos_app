// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Product {

// ============ Identifiers ============
@OdooId() int get id;@OdooLocalOnly() String? get uuid;// ============ Basic Data ============
@OdooString() String get name;@OdooString(odooName: 'display_name') String? get displayNameOdoo;@OdooString(odooName: 'default_code') String? get defaultCode;@OdooString() String? get barcode;@OdooSelection(odooName: 'type') String get typeStr;@OdooBoolean(odooName: 'sale_ok') bool get saleOk;@OdooBoolean(odooName: 'purchase_ok') bool get purchaseOk;@OdooBoolean() bool get active;// ============ Pricing ============
@OdooFloat(odooName: 'list_price', precision: 4) double get listPrice;@OdooFloat(odooName: 'standard_price', precision: 4) double get standardPrice;// ============ Category ============
@OdooMany2One('product.category', odooName: 'categ_id') int? get categId;@OdooMany2OneName(sourceField: 'categ_id') String? get categName;// ============ Unit of Measure ============
@OdooMany2One('uom.uom', odooName: 'uom_id') int? get uomId;@OdooMany2OneName(sourceField: 'uom_id') String? get uomName;@OdooMany2One('uom.uom', odooName: 'uom_po_id') int? get uomPoId;@OdooMany2OneName(sourceField: 'uom_po_id') String? get uomPoName;// ============ Taxes ============
@OdooMany2Many('account.tax', odooName: 'taxes_id') List<int> get taxIds;@OdooMany2Many('account.tax', odooName: 'supplier_taxes_id') List<int> get supplierTaxIds;// ============ Description ============
@OdooString() String? get description;@OdooString(odooName: 'description_sale') String? get descriptionSale;// ============ Template Reference ============
@OdooMany2One('product.template', odooName: 'product_tmpl_id') int? get productTmplId;// ============ Image ============
@OdooBinary(odooName: 'image_128', fetchByDefault: false) String? get image128;// ============ Inventory ============
@OdooFloat(odooName: 'qty_available', precision: 4, writable: false) double get qtyAvailable;@OdooFloat(odooName: 'virtual_available', precision: 4, writable: false) double get virtualAvailable;@OdooSelection() String get trackingStr;@OdooBoolean(odooName: 'is_storable', writable: false) bool get isStorable;// ============ Ecuador Localization ============
@OdooString(odooName: 'l10n_ec_auxiliary_code') String? get auxiliaryCode;@OdooBoolean(odooName: 'is_unit_product') bool get isUnitProduct;@OdooBoolean(odooName: 'temporal_no_despachar') bool get temporalNoDespachar;// ============ Sync Metadata ============
@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;@OdooLocalOnly() bool get isSynced;@OdooLocalOnly() DateTime? get localModifiedAt;
/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductCopyWith<Product> get copyWith => _$ProductCopyWithImpl<Product>(this as Product, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Product&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayNameOdoo, displayNameOdoo) || other.displayNameOdoo == displayNameOdoo)&&(identical(other.defaultCode, defaultCode) || other.defaultCode == defaultCode)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.typeStr, typeStr) || other.typeStr == typeStr)&&(identical(other.saleOk, saleOk) || other.saleOk == saleOk)&&(identical(other.purchaseOk, purchaseOk) || other.purchaseOk == purchaseOk)&&(identical(other.active, active) || other.active == active)&&(identical(other.listPrice, listPrice) || other.listPrice == listPrice)&&(identical(other.standardPrice, standardPrice) || other.standardPrice == standardPrice)&&(identical(other.categId, categId) || other.categId == categId)&&(identical(other.categName, categName) || other.categName == categName)&&(identical(other.uomId, uomId) || other.uomId == uomId)&&(identical(other.uomName, uomName) || other.uomName == uomName)&&(identical(other.uomPoId, uomPoId) || other.uomPoId == uomPoId)&&(identical(other.uomPoName, uomPoName) || other.uomPoName == uomPoName)&&const DeepCollectionEquality().equals(other.taxIds, taxIds)&&const DeepCollectionEquality().equals(other.supplierTaxIds, supplierTaxIds)&&(identical(other.description, description) || other.description == description)&&(identical(other.descriptionSale, descriptionSale) || other.descriptionSale == descriptionSale)&&(identical(other.productTmplId, productTmplId) || other.productTmplId == productTmplId)&&(identical(other.image128, image128) || other.image128 == image128)&&(identical(other.qtyAvailable, qtyAvailable) || other.qtyAvailable == qtyAvailable)&&(identical(other.virtualAvailable, virtualAvailable) || other.virtualAvailable == virtualAvailable)&&(identical(other.trackingStr, trackingStr) || other.trackingStr == trackingStr)&&(identical(other.isStorable, isStorable) || other.isStorable == isStorable)&&(identical(other.auxiliaryCode, auxiliaryCode) || other.auxiliaryCode == auxiliaryCode)&&(identical(other.isUnitProduct, isUnitProduct) || other.isUnitProduct == isUnitProduct)&&(identical(other.temporalNoDespachar, temporalNoDespachar) || other.temporalNoDespachar == temporalNoDespachar)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.localModifiedAt, localModifiedAt) || other.localModifiedAt == localModifiedAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,uuid,name,displayNameOdoo,defaultCode,barcode,typeStr,saleOk,purchaseOk,active,listPrice,standardPrice,categId,categName,uomId,uomName,uomPoId,uomPoName,const DeepCollectionEquality().hash(taxIds),const DeepCollectionEquality().hash(supplierTaxIds),description,descriptionSale,productTmplId,image128,qtyAvailable,virtualAvailable,trackingStr,isStorable,auxiliaryCode,isUnitProduct,temporalNoDespachar,writeDate,isSynced,localModifiedAt]);

@override
String toString() {
  return 'Product(id: $id, uuid: $uuid, name: $name, displayNameOdoo: $displayNameOdoo, defaultCode: $defaultCode, barcode: $barcode, typeStr: $typeStr, saleOk: $saleOk, purchaseOk: $purchaseOk, active: $active, listPrice: $listPrice, standardPrice: $standardPrice, categId: $categId, categName: $categName, uomId: $uomId, uomName: $uomName, uomPoId: $uomPoId, uomPoName: $uomPoName, taxIds: $taxIds, supplierTaxIds: $supplierTaxIds, description: $description, descriptionSale: $descriptionSale, productTmplId: $productTmplId, image128: $image128, qtyAvailable: $qtyAvailable, virtualAvailable: $virtualAvailable, trackingStr: $trackingStr, isStorable: $isStorable, auxiliaryCode: $auxiliaryCode, isUnitProduct: $isUnitProduct, temporalNoDespachar: $temporalNoDespachar, writeDate: $writeDate, isSynced: $isSynced, localModifiedAt: $localModifiedAt)';
}


}

/// @nodoc
abstract mixin class $ProductCopyWith<$Res>  {
  factory $ProductCopyWith(Product value, $Res Function(Product) _then) = _$ProductCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooString() String name,@OdooString(odooName: 'display_name') String? displayNameOdoo,@OdooString(odooName: 'default_code') String? defaultCode,@OdooString() String? barcode,@OdooSelection(odooName: 'type') String typeStr,@OdooBoolean(odooName: 'sale_ok') bool saleOk,@OdooBoolean(odooName: 'purchase_ok') bool purchaseOk,@OdooBoolean() bool active,@OdooFloat(odooName: 'list_price', precision: 4) double listPrice,@OdooFloat(odooName: 'standard_price', precision: 4) double standardPrice,@OdooMany2One('product.category', odooName: 'categ_id') int? categId,@OdooMany2OneName(sourceField: 'categ_id') String? categName,@OdooMany2One('uom.uom', odooName: 'uom_id') int? uomId,@OdooMany2OneName(sourceField: 'uom_id') String? uomName,@OdooMany2One('uom.uom', odooName: 'uom_po_id') int? uomPoId,@OdooMany2OneName(sourceField: 'uom_po_id') String? uomPoName,@OdooMany2Many('account.tax', odooName: 'taxes_id') List<int> taxIds,@OdooMany2Many('account.tax', odooName: 'supplier_taxes_id') List<int> supplierTaxIds,@OdooString() String? description,@OdooString(odooName: 'description_sale') String? descriptionSale,@OdooMany2One('product.template', odooName: 'product_tmpl_id') int? productTmplId,@OdooBinary(odooName: 'image_128', fetchByDefault: false) String? image128,@OdooFloat(odooName: 'qty_available', precision: 4, writable: false) double qtyAvailable,@OdooFloat(odooName: 'virtual_available', precision: 4, writable: false) double virtualAvailable,@OdooSelection() String trackingStr,@OdooBoolean(odooName: 'is_storable', writable: false) bool isStorable,@OdooString(odooName: 'l10n_ec_auxiliary_code') String? auxiliaryCode,@OdooBoolean(odooName: 'is_unit_product') bool isUnitProduct,@OdooBoolean(odooName: 'temporal_no_despachar') bool temporalNoDespachar,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? localModifiedAt
});




}
/// @nodoc
class _$ProductCopyWithImpl<$Res>
    implements $ProductCopyWith<$Res> {
  _$ProductCopyWithImpl(this._self, this._then);

  final Product _self;
  final $Res Function(Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uuid = freezed,Object? name = null,Object? displayNameOdoo = freezed,Object? defaultCode = freezed,Object? barcode = freezed,Object? typeStr = null,Object? saleOk = null,Object? purchaseOk = null,Object? active = null,Object? listPrice = null,Object? standardPrice = null,Object? categId = freezed,Object? categName = freezed,Object? uomId = freezed,Object? uomName = freezed,Object? uomPoId = freezed,Object? uomPoName = freezed,Object? taxIds = null,Object? supplierTaxIds = null,Object? description = freezed,Object? descriptionSale = freezed,Object? productTmplId = freezed,Object? image128 = freezed,Object? qtyAvailable = null,Object? virtualAvailable = null,Object? trackingStr = null,Object? isStorable = null,Object? auxiliaryCode = freezed,Object? isUnitProduct = null,Object? temporalNoDespachar = null,Object? writeDate = freezed,Object? isSynced = null,Object? localModifiedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayNameOdoo: freezed == displayNameOdoo ? _self.displayNameOdoo : displayNameOdoo // ignore: cast_nullable_to_non_nullable
as String?,defaultCode: freezed == defaultCode ? _self.defaultCode : defaultCode // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,typeStr: null == typeStr ? _self.typeStr : typeStr // ignore: cast_nullable_to_non_nullable
as String,saleOk: null == saleOk ? _self.saleOk : saleOk // ignore: cast_nullable_to_non_nullable
as bool,purchaseOk: null == purchaseOk ? _self.purchaseOk : purchaseOk // ignore: cast_nullable_to_non_nullable
as bool,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,listPrice: null == listPrice ? _self.listPrice : listPrice // ignore: cast_nullable_to_non_nullable
as double,standardPrice: null == standardPrice ? _self.standardPrice : standardPrice // ignore: cast_nullable_to_non_nullable
as double,categId: freezed == categId ? _self.categId : categId // ignore: cast_nullable_to_non_nullable
as int?,categName: freezed == categName ? _self.categName : categName // ignore: cast_nullable_to_non_nullable
as String?,uomId: freezed == uomId ? _self.uomId : uomId // ignore: cast_nullable_to_non_nullable
as int?,uomName: freezed == uomName ? _self.uomName : uomName // ignore: cast_nullable_to_non_nullable
as String?,uomPoId: freezed == uomPoId ? _self.uomPoId : uomPoId // ignore: cast_nullable_to_non_nullable
as int?,uomPoName: freezed == uomPoName ? _self.uomPoName : uomPoName // ignore: cast_nullable_to_non_nullable
as String?,taxIds: null == taxIds ? _self.taxIds : taxIds // ignore: cast_nullable_to_non_nullable
as List<int>,supplierTaxIds: null == supplierTaxIds ? _self.supplierTaxIds : supplierTaxIds // ignore: cast_nullable_to_non_nullable
as List<int>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,descriptionSale: freezed == descriptionSale ? _self.descriptionSale : descriptionSale // ignore: cast_nullable_to_non_nullable
as String?,productTmplId: freezed == productTmplId ? _self.productTmplId : productTmplId // ignore: cast_nullable_to_non_nullable
as int?,image128: freezed == image128 ? _self.image128 : image128 // ignore: cast_nullable_to_non_nullable
as String?,qtyAvailable: null == qtyAvailable ? _self.qtyAvailable : qtyAvailable // ignore: cast_nullable_to_non_nullable
as double,virtualAvailable: null == virtualAvailable ? _self.virtualAvailable : virtualAvailable // ignore: cast_nullable_to_non_nullable
as double,trackingStr: null == trackingStr ? _self.trackingStr : trackingStr // ignore: cast_nullable_to_non_nullable
as String,isStorable: null == isStorable ? _self.isStorable : isStorable // ignore: cast_nullable_to_non_nullable
as bool,auxiliaryCode: freezed == auxiliaryCode ? _self.auxiliaryCode : auxiliaryCode // ignore: cast_nullable_to_non_nullable
as String?,isUnitProduct: null == isUnitProduct ? _self.isUnitProduct : isUnitProduct // ignore: cast_nullable_to_non_nullable
as bool,temporalNoDespachar: null == temporalNoDespachar ? _self.temporalNoDespachar : temporalNoDespachar // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,localModifiedAt: freezed == localModifiedAt ? _self.localModifiedAt : localModifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Product].
extension ProductPatterns on Product {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Product value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Product() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Product value)  $default,){
final _that = this;
switch (_that) {
case _Product():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Product value)?  $default,){
final _that = this;
switch (_that) {
case _Product() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooString(odooName: 'display_name')  String? displayNameOdoo, @OdooString(odooName: 'default_code')  String? defaultCode, @OdooString()  String? barcode, @OdooSelection(odooName: 'type')  String typeStr, @OdooBoolean(odooName: 'sale_ok')  bool saleOk, @OdooBoolean(odooName: 'purchase_ok')  bool purchaseOk, @OdooBoolean()  bool active, @OdooFloat(odooName: 'list_price', precision: 4)  double listPrice, @OdooFloat(odooName: 'standard_price', precision: 4)  double standardPrice, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooMany2OneName(sourceField: 'categ_id')  String? categName, @OdooMany2One('uom.uom', odooName: 'uom_id')  int? uomId, @OdooMany2OneName(sourceField: 'uom_id')  String? uomName, @OdooMany2One('uom.uom', odooName: 'uom_po_id')  int? uomPoId, @OdooMany2OneName(sourceField: 'uom_po_id')  String? uomPoName, @OdooMany2Many('account.tax', odooName: 'taxes_id')  List<int> taxIds, @OdooMany2Many('account.tax', odooName: 'supplier_taxes_id')  List<int> supplierTaxIds, @OdooString()  String? description, @OdooString(odooName: 'description_sale')  String? descriptionSale, @OdooMany2One('product.template', odooName: 'product_tmpl_id')  int? productTmplId, @OdooBinary(odooName: 'image_128', fetchByDefault: false)  String? image128, @OdooFloat(odooName: 'qty_available', precision: 4, writable: false)  double qtyAvailable, @OdooFloat(odooName: 'virtual_available', precision: 4, writable: false)  double virtualAvailable, @OdooSelection()  String trackingStr, @OdooBoolean(odooName: 'is_storable', writable: false)  bool isStorable, @OdooString(odooName: 'l10n_ec_auxiliary_code')  String? auxiliaryCode, @OdooBoolean(odooName: 'is_unit_product')  bool isUnitProduct, @OdooBoolean(odooName: 'temporal_no_despachar')  bool temporalNoDespachar, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? localModifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.id,_that.uuid,_that.name,_that.displayNameOdoo,_that.defaultCode,_that.barcode,_that.typeStr,_that.saleOk,_that.purchaseOk,_that.active,_that.listPrice,_that.standardPrice,_that.categId,_that.categName,_that.uomId,_that.uomName,_that.uomPoId,_that.uomPoName,_that.taxIds,_that.supplierTaxIds,_that.description,_that.descriptionSale,_that.productTmplId,_that.image128,_that.qtyAvailable,_that.virtualAvailable,_that.trackingStr,_that.isStorable,_that.auxiliaryCode,_that.isUnitProduct,_that.temporalNoDespachar,_that.writeDate,_that.isSynced,_that.localModifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooString(odooName: 'display_name')  String? displayNameOdoo, @OdooString(odooName: 'default_code')  String? defaultCode, @OdooString()  String? barcode, @OdooSelection(odooName: 'type')  String typeStr, @OdooBoolean(odooName: 'sale_ok')  bool saleOk, @OdooBoolean(odooName: 'purchase_ok')  bool purchaseOk, @OdooBoolean()  bool active, @OdooFloat(odooName: 'list_price', precision: 4)  double listPrice, @OdooFloat(odooName: 'standard_price', precision: 4)  double standardPrice, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooMany2OneName(sourceField: 'categ_id')  String? categName, @OdooMany2One('uom.uom', odooName: 'uom_id')  int? uomId, @OdooMany2OneName(sourceField: 'uom_id')  String? uomName, @OdooMany2One('uom.uom', odooName: 'uom_po_id')  int? uomPoId, @OdooMany2OneName(sourceField: 'uom_po_id')  String? uomPoName, @OdooMany2Many('account.tax', odooName: 'taxes_id')  List<int> taxIds, @OdooMany2Many('account.tax', odooName: 'supplier_taxes_id')  List<int> supplierTaxIds, @OdooString()  String? description, @OdooString(odooName: 'description_sale')  String? descriptionSale, @OdooMany2One('product.template', odooName: 'product_tmpl_id')  int? productTmplId, @OdooBinary(odooName: 'image_128', fetchByDefault: false)  String? image128, @OdooFloat(odooName: 'qty_available', precision: 4, writable: false)  double qtyAvailable, @OdooFloat(odooName: 'virtual_available', precision: 4, writable: false)  double virtualAvailable, @OdooSelection()  String trackingStr, @OdooBoolean(odooName: 'is_storable', writable: false)  bool isStorable, @OdooString(odooName: 'l10n_ec_auxiliary_code')  String? auxiliaryCode, @OdooBoolean(odooName: 'is_unit_product')  bool isUnitProduct, @OdooBoolean(odooName: 'temporal_no_despachar')  bool temporalNoDespachar, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? localModifiedAt)  $default,) {final _that = this;
switch (_that) {
case _Product():
return $default(_that.id,_that.uuid,_that.name,_that.displayNameOdoo,_that.defaultCode,_that.barcode,_that.typeStr,_that.saleOk,_that.purchaseOk,_that.active,_that.listPrice,_that.standardPrice,_that.categId,_that.categName,_that.uomId,_that.uomName,_that.uomPoId,_that.uomPoName,_that.taxIds,_that.supplierTaxIds,_that.description,_that.descriptionSale,_that.productTmplId,_that.image128,_that.qtyAvailable,_that.virtualAvailable,_that.trackingStr,_that.isStorable,_that.auxiliaryCode,_that.isUnitProduct,_that.temporalNoDespachar,_that.writeDate,_that.isSynced,_that.localModifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooString()  String name, @OdooString(odooName: 'display_name')  String? displayNameOdoo, @OdooString(odooName: 'default_code')  String? defaultCode, @OdooString()  String? barcode, @OdooSelection(odooName: 'type')  String typeStr, @OdooBoolean(odooName: 'sale_ok')  bool saleOk, @OdooBoolean(odooName: 'purchase_ok')  bool purchaseOk, @OdooBoolean()  bool active, @OdooFloat(odooName: 'list_price', precision: 4)  double listPrice, @OdooFloat(odooName: 'standard_price', precision: 4)  double standardPrice, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooMany2OneName(sourceField: 'categ_id')  String? categName, @OdooMany2One('uom.uom', odooName: 'uom_id')  int? uomId, @OdooMany2OneName(sourceField: 'uom_id')  String? uomName, @OdooMany2One('uom.uom', odooName: 'uom_po_id')  int? uomPoId, @OdooMany2OneName(sourceField: 'uom_po_id')  String? uomPoName, @OdooMany2Many('account.tax', odooName: 'taxes_id')  List<int> taxIds, @OdooMany2Many('account.tax', odooName: 'supplier_taxes_id')  List<int> supplierTaxIds, @OdooString()  String? description, @OdooString(odooName: 'description_sale')  String? descriptionSale, @OdooMany2One('product.template', odooName: 'product_tmpl_id')  int? productTmplId, @OdooBinary(odooName: 'image_128', fetchByDefault: false)  String? image128, @OdooFloat(odooName: 'qty_available', precision: 4, writable: false)  double qtyAvailable, @OdooFloat(odooName: 'virtual_available', precision: 4, writable: false)  double virtualAvailable, @OdooSelection()  String trackingStr, @OdooBoolean(odooName: 'is_storable', writable: false)  bool isStorable, @OdooString(odooName: 'l10n_ec_auxiliary_code')  String? auxiliaryCode, @OdooBoolean(odooName: 'is_unit_product')  bool isUnitProduct, @OdooBoolean(odooName: 'temporal_no_despachar')  bool temporalNoDespachar, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? localModifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.id,_that.uuid,_that.name,_that.displayNameOdoo,_that.defaultCode,_that.barcode,_that.typeStr,_that.saleOk,_that.purchaseOk,_that.active,_that.listPrice,_that.standardPrice,_that.categId,_that.categName,_that.uomId,_that.uomName,_that.uomPoId,_that.uomPoName,_that.taxIds,_that.supplierTaxIds,_that.description,_that.descriptionSale,_that.productTmplId,_that.image128,_that.qtyAvailable,_that.virtualAvailable,_that.trackingStr,_that.isStorable,_that.auxiliaryCode,_that.isUnitProduct,_that.temporalNoDespachar,_that.writeDate,_that.isSynced,_that.localModifiedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Product extends Product {
  const _Product({@OdooId() required this.id, @OdooLocalOnly() this.uuid, @OdooString() required this.name, @OdooString(odooName: 'display_name') this.displayNameOdoo, @OdooString(odooName: 'default_code') this.defaultCode, @OdooString() this.barcode, @OdooSelection(odooName: 'type') this.typeStr = 'consu', @OdooBoolean(odooName: 'sale_ok') this.saleOk = true, @OdooBoolean(odooName: 'purchase_ok') this.purchaseOk = true, @OdooBoolean() this.active = true, @OdooFloat(odooName: 'list_price', precision: 4) this.listPrice = 0.0, @OdooFloat(odooName: 'standard_price', precision: 4) this.standardPrice = 0.0, @OdooMany2One('product.category', odooName: 'categ_id') this.categId, @OdooMany2OneName(sourceField: 'categ_id') this.categName, @OdooMany2One('uom.uom', odooName: 'uom_id') this.uomId, @OdooMany2OneName(sourceField: 'uom_id') this.uomName, @OdooMany2One('uom.uom', odooName: 'uom_po_id') this.uomPoId, @OdooMany2OneName(sourceField: 'uom_po_id') this.uomPoName, @OdooMany2Many('account.tax', odooName: 'taxes_id') final  List<int> taxIds = const [], @OdooMany2Many('account.tax', odooName: 'supplier_taxes_id') final  List<int> supplierTaxIds = const [], @OdooString() this.description, @OdooString(odooName: 'description_sale') this.descriptionSale, @OdooMany2One('product.template', odooName: 'product_tmpl_id') this.productTmplId, @OdooBinary(odooName: 'image_128', fetchByDefault: false) this.image128, @OdooFloat(odooName: 'qty_available', precision: 4, writable: false) this.qtyAvailable = 0.0, @OdooFloat(odooName: 'virtual_available', precision: 4, writable: false) this.virtualAvailable = 0.0, @OdooSelection() this.trackingStr = 'none', @OdooBoolean(odooName: 'is_storable', writable: false) this.isStorable = false, @OdooString(odooName: 'l10n_ec_auxiliary_code') this.auxiliaryCode, @OdooBoolean(odooName: 'is_unit_product') this.isUnitProduct = true, @OdooBoolean(odooName: 'temporal_no_despachar') this.temporalNoDespachar = false, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate, @OdooLocalOnly() this.isSynced = false, @OdooLocalOnly() this.localModifiedAt}): _taxIds = taxIds,_supplierTaxIds = supplierTaxIds,super._();
  

// ============ Identifiers ============
@override@OdooId() final  int id;
@override@OdooLocalOnly() final  String? uuid;
// ============ Basic Data ============
@override@OdooString() final  String name;
@override@OdooString(odooName: 'display_name') final  String? displayNameOdoo;
@override@OdooString(odooName: 'default_code') final  String? defaultCode;
@override@OdooString() final  String? barcode;
@override@JsonKey()@OdooSelection(odooName: 'type') final  String typeStr;
@override@JsonKey()@OdooBoolean(odooName: 'sale_ok') final  bool saleOk;
@override@JsonKey()@OdooBoolean(odooName: 'purchase_ok') final  bool purchaseOk;
@override@JsonKey()@OdooBoolean() final  bool active;
// ============ Pricing ============
@override@JsonKey()@OdooFloat(odooName: 'list_price', precision: 4) final  double listPrice;
@override@JsonKey()@OdooFloat(odooName: 'standard_price', precision: 4) final  double standardPrice;
// ============ Category ============
@override@OdooMany2One('product.category', odooName: 'categ_id') final  int? categId;
@override@OdooMany2OneName(sourceField: 'categ_id') final  String? categName;
// ============ Unit of Measure ============
@override@OdooMany2One('uom.uom', odooName: 'uom_id') final  int? uomId;
@override@OdooMany2OneName(sourceField: 'uom_id') final  String? uomName;
@override@OdooMany2One('uom.uom', odooName: 'uom_po_id') final  int? uomPoId;
@override@OdooMany2OneName(sourceField: 'uom_po_id') final  String? uomPoName;
// ============ Taxes ============
 final  List<int> _taxIds;
// ============ Taxes ============
@override@JsonKey()@OdooMany2Many('account.tax', odooName: 'taxes_id') List<int> get taxIds {
  if (_taxIds is EqualUnmodifiableListView) return _taxIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_taxIds);
}

 final  List<int> _supplierTaxIds;
@override@JsonKey()@OdooMany2Many('account.tax', odooName: 'supplier_taxes_id') List<int> get supplierTaxIds {
  if (_supplierTaxIds is EqualUnmodifiableListView) return _supplierTaxIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supplierTaxIds);
}

// ============ Description ============
@override@OdooString() final  String? description;
@override@OdooString(odooName: 'description_sale') final  String? descriptionSale;
// ============ Template Reference ============
@override@OdooMany2One('product.template', odooName: 'product_tmpl_id') final  int? productTmplId;
// ============ Image ============
@override@OdooBinary(odooName: 'image_128', fetchByDefault: false) final  String? image128;
// ============ Inventory ============
@override@JsonKey()@OdooFloat(odooName: 'qty_available', precision: 4, writable: false) final  double qtyAvailable;
@override@JsonKey()@OdooFloat(odooName: 'virtual_available', precision: 4, writable: false) final  double virtualAvailable;
@override@JsonKey()@OdooSelection() final  String trackingStr;
@override@JsonKey()@OdooBoolean(odooName: 'is_storable', writable: false) final  bool isStorable;
// ============ Ecuador Localization ============
@override@OdooString(odooName: 'l10n_ec_auxiliary_code') final  String? auxiliaryCode;
@override@JsonKey()@OdooBoolean(odooName: 'is_unit_product') final  bool isUnitProduct;
@override@JsonKey()@OdooBoolean(odooName: 'temporal_no_despachar') final  bool temporalNoDespachar;
// ============ Sync Metadata ============
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
@override@OdooLocalOnly() final  DateTime? localModifiedAt;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductCopyWith<_Product> get copyWith => __$ProductCopyWithImpl<_Product>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Product&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayNameOdoo, displayNameOdoo) || other.displayNameOdoo == displayNameOdoo)&&(identical(other.defaultCode, defaultCode) || other.defaultCode == defaultCode)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.typeStr, typeStr) || other.typeStr == typeStr)&&(identical(other.saleOk, saleOk) || other.saleOk == saleOk)&&(identical(other.purchaseOk, purchaseOk) || other.purchaseOk == purchaseOk)&&(identical(other.active, active) || other.active == active)&&(identical(other.listPrice, listPrice) || other.listPrice == listPrice)&&(identical(other.standardPrice, standardPrice) || other.standardPrice == standardPrice)&&(identical(other.categId, categId) || other.categId == categId)&&(identical(other.categName, categName) || other.categName == categName)&&(identical(other.uomId, uomId) || other.uomId == uomId)&&(identical(other.uomName, uomName) || other.uomName == uomName)&&(identical(other.uomPoId, uomPoId) || other.uomPoId == uomPoId)&&(identical(other.uomPoName, uomPoName) || other.uomPoName == uomPoName)&&const DeepCollectionEquality().equals(other._taxIds, _taxIds)&&const DeepCollectionEquality().equals(other._supplierTaxIds, _supplierTaxIds)&&(identical(other.description, description) || other.description == description)&&(identical(other.descriptionSale, descriptionSale) || other.descriptionSale == descriptionSale)&&(identical(other.productTmplId, productTmplId) || other.productTmplId == productTmplId)&&(identical(other.image128, image128) || other.image128 == image128)&&(identical(other.qtyAvailable, qtyAvailable) || other.qtyAvailable == qtyAvailable)&&(identical(other.virtualAvailable, virtualAvailable) || other.virtualAvailable == virtualAvailable)&&(identical(other.trackingStr, trackingStr) || other.trackingStr == trackingStr)&&(identical(other.isStorable, isStorable) || other.isStorable == isStorable)&&(identical(other.auxiliaryCode, auxiliaryCode) || other.auxiliaryCode == auxiliaryCode)&&(identical(other.isUnitProduct, isUnitProduct) || other.isUnitProduct == isUnitProduct)&&(identical(other.temporalNoDespachar, temporalNoDespachar) || other.temporalNoDespachar == temporalNoDespachar)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.localModifiedAt, localModifiedAt) || other.localModifiedAt == localModifiedAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,uuid,name,displayNameOdoo,defaultCode,barcode,typeStr,saleOk,purchaseOk,active,listPrice,standardPrice,categId,categName,uomId,uomName,uomPoId,uomPoName,const DeepCollectionEquality().hash(_taxIds),const DeepCollectionEquality().hash(_supplierTaxIds),description,descriptionSale,productTmplId,image128,qtyAvailable,virtualAvailable,trackingStr,isStorable,auxiliaryCode,isUnitProduct,temporalNoDespachar,writeDate,isSynced,localModifiedAt]);

@override
String toString() {
  return 'Product(id: $id, uuid: $uuid, name: $name, displayNameOdoo: $displayNameOdoo, defaultCode: $defaultCode, barcode: $barcode, typeStr: $typeStr, saleOk: $saleOk, purchaseOk: $purchaseOk, active: $active, listPrice: $listPrice, standardPrice: $standardPrice, categId: $categId, categName: $categName, uomId: $uomId, uomName: $uomName, uomPoId: $uomPoId, uomPoName: $uomPoName, taxIds: $taxIds, supplierTaxIds: $supplierTaxIds, description: $description, descriptionSale: $descriptionSale, productTmplId: $productTmplId, image128: $image128, qtyAvailable: $qtyAvailable, virtualAvailable: $virtualAvailable, trackingStr: $trackingStr, isStorable: $isStorable, auxiliaryCode: $auxiliaryCode, isUnitProduct: $isUnitProduct, temporalNoDespachar: $temporalNoDespachar, writeDate: $writeDate, isSynced: $isSynced, localModifiedAt: $localModifiedAt)';
}


}

/// @nodoc
abstract mixin class _$ProductCopyWith<$Res> implements $ProductCopyWith<$Res> {
  factory _$ProductCopyWith(_Product value, $Res Function(_Product) _then) = __$ProductCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooString() String name,@OdooString(odooName: 'display_name') String? displayNameOdoo,@OdooString(odooName: 'default_code') String? defaultCode,@OdooString() String? barcode,@OdooSelection(odooName: 'type') String typeStr,@OdooBoolean(odooName: 'sale_ok') bool saleOk,@OdooBoolean(odooName: 'purchase_ok') bool purchaseOk,@OdooBoolean() bool active,@OdooFloat(odooName: 'list_price', precision: 4) double listPrice,@OdooFloat(odooName: 'standard_price', precision: 4) double standardPrice,@OdooMany2One('product.category', odooName: 'categ_id') int? categId,@OdooMany2OneName(sourceField: 'categ_id') String? categName,@OdooMany2One('uom.uom', odooName: 'uom_id') int? uomId,@OdooMany2OneName(sourceField: 'uom_id') String? uomName,@OdooMany2One('uom.uom', odooName: 'uom_po_id') int? uomPoId,@OdooMany2OneName(sourceField: 'uom_po_id') String? uomPoName,@OdooMany2Many('account.tax', odooName: 'taxes_id') List<int> taxIds,@OdooMany2Many('account.tax', odooName: 'supplier_taxes_id') List<int> supplierTaxIds,@OdooString() String? description,@OdooString(odooName: 'description_sale') String? descriptionSale,@OdooMany2One('product.template', odooName: 'product_tmpl_id') int? productTmplId,@OdooBinary(odooName: 'image_128', fetchByDefault: false) String? image128,@OdooFloat(odooName: 'qty_available', precision: 4, writable: false) double qtyAvailable,@OdooFloat(odooName: 'virtual_available', precision: 4, writable: false) double virtualAvailable,@OdooSelection() String trackingStr,@OdooBoolean(odooName: 'is_storable', writable: false) bool isStorable,@OdooString(odooName: 'l10n_ec_auxiliary_code') String? auxiliaryCode,@OdooBoolean(odooName: 'is_unit_product') bool isUnitProduct,@OdooBoolean(odooName: 'temporal_no_despachar') bool temporalNoDespachar,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? localModifiedAt
});




}
/// @nodoc
class __$ProductCopyWithImpl<$Res>
    implements _$ProductCopyWith<$Res> {
  __$ProductCopyWithImpl(this._self, this._then);

  final _Product _self;
  final $Res Function(_Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uuid = freezed,Object? name = null,Object? displayNameOdoo = freezed,Object? defaultCode = freezed,Object? barcode = freezed,Object? typeStr = null,Object? saleOk = null,Object? purchaseOk = null,Object? active = null,Object? listPrice = null,Object? standardPrice = null,Object? categId = freezed,Object? categName = freezed,Object? uomId = freezed,Object? uomName = freezed,Object? uomPoId = freezed,Object? uomPoName = freezed,Object? taxIds = null,Object? supplierTaxIds = null,Object? description = freezed,Object? descriptionSale = freezed,Object? productTmplId = freezed,Object? image128 = freezed,Object? qtyAvailable = null,Object? virtualAvailable = null,Object? trackingStr = null,Object? isStorable = null,Object? auxiliaryCode = freezed,Object? isUnitProduct = null,Object? temporalNoDespachar = null,Object? writeDate = freezed,Object? isSynced = null,Object? localModifiedAt = freezed,}) {
  return _then(_Product(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayNameOdoo: freezed == displayNameOdoo ? _self.displayNameOdoo : displayNameOdoo // ignore: cast_nullable_to_non_nullable
as String?,defaultCode: freezed == defaultCode ? _self.defaultCode : defaultCode // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,typeStr: null == typeStr ? _self.typeStr : typeStr // ignore: cast_nullable_to_non_nullable
as String,saleOk: null == saleOk ? _self.saleOk : saleOk // ignore: cast_nullable_to_non_nullable
as bool,purchaseOk: null == purchaseOk ? _self.purchaseOk : purchaseOk // ignore: cast_nullable_to_non_nullable
as bool,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,listPrice: null == listPrice ? _self.listPrice : listPrice // ignore: cast_nullable_to_non_nullable
as double,standardPrice: null == standardPrice ? _self.standardPrice : standardPrice // ignore: cast_nullable_to_non_nullable
as double,categId: freezed == categId ? _self.categId : categId // ignore: cast_nullable_to_non_nullable
as int?,categName: freezed == categName ? _self.categName : categName // ignore: cast_nullable_to_non_nullable
as String?,uomId: freezed == uomId ? _self.uomId : uomId // ignore: cast_nullable_to_non_nullable
as int?,uomName: freezed == uomName ? _self.uomName : uomName // ignore: cast_nullable_to_non_nullable
as String?,uomPoId: freezed == uomPoId ? _self.uomPoId : uomPoId // ignore: cast_nullable_to_non_nullable
as int?,uomPoName: freezed == uomPoName ? _self.uomPoName : uomPoName // ignore: cast_nullable_to_non_nullable
as String?,taxIds: null == taxIds ? _self._taxIds : taxIds // ignore: cast_nullable_to_non_nullable
as List<int>,supplierTaxIds: null == supplierTaxIds ? _self._supplierTaxIds : supplierTaxIds // ignore: cast_nullable_to_non_nullable
as List<int>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,descriptionSale: freezed == descriptionSale ? _self.descriptionSale : descriptionSale // ignore: cast_nullable_to_non_nullable
as String?,productTmplId: freezed == productTmplId ? _self.productTmplId : productTmplId // ignore: cast_nullable_to_non_nullable
as int?,image128: freezed == image128 ? _self.image128 : image128 // ignore: cast_nullable_to_non_nullable
as String?,qtyAvailable: null == qtyAvailable ? _self.qtyAvailable : qtyAvailable // ignore: cast_nullable_to_non_nullable
as double,virtualAvailable: null == virtualAvailable ? _self.virtualAvailable : virtualAvailable // ignore: cast_nullable_to_non_nullable
as double,trackingStr: null == trackingStr ? _self.trackingStr : trackingStr // ignore: cast_nullable_to_non_nullable
as String,isStorable: null == isStorable ? _self.isStorable : isStorable // ignore: cast_nullable_to_non_nullable
as bool,auxiliaryCode: freezed == auxiliaryCode ? _self.auxiliaryCode : auxiliaryCode // ignore: cast_nullable_to_non_nullable
as String?,isUnitProduct: null == isUnitProduct ? _self.isUnitProduct : isUnitProduct // ignore: cast_nullable_to_non_nullable
as bool,temporalNoDespachar: null == temporalNoDespachar ? _self.temporalNoDespachar : temporalNoDespachar // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,localModifiedAt: freezed == localModifiedAt ? _self.localModifiedAt : localModifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
