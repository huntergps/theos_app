// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_example.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Product {

// ═══════════════════ Identifiers ═══════════════════
@OdooId() int get id;@OdooLocalOnly() String? get uuid;@OdooLocalOnly() bool get isSynced;// ═══════════════════ Basic Data ═══════════════════
@OdooString() String get name;@OdooString(odooName: 'display_name') String? get displayNameOdoo;@OdooString(odooName: 'default_code') String? get defaultCode;@OdooString() String? get barcode;@OdooSelection(options: {'consu' : 'Consumable', 'service' : 'Service', 'product' : 'Storable'}) String get type;@OdooBoolean(odooName: 'sale_ok') bool get saleOk;@OdooBoolean(odooName: 'purchase_ok') bool get purchaseOk;@OdooBoolean() bool get active;// ═══════════════════ Pricing ═══════════════════
@OdooMonetary(odooName: 'list_price') double get listPrice;@OdooMonetary(odooName: 'standard_price') double get standardPrice;// ═══════════════════ Category ═══════════════════
@OdooMany2One('product.category', odooName: 'categ_id') int? get categId;@OdooMany2OneName(sourceField: 'categ_id') String? get categName;// ═══════════════════ Unit of Measure ═══════════════════
@OdooMany2One('uom.uom', odooName: 'uom_id') int? get uomId;@OdooMany2OneName(sourceField: 'uom_id') String? get uomName;@OdooMany2One('uom.uom', odooName: 'uom_po_id') int? get uomPoId;@OdooMany2OneName(sourceField: 'uom_po_id') String? get uomPoName;// ═══════════════════ Taxes ═══════════════════
@OdooMany2Many('account.tax', odooName: 'taxes_id') List<int>? get taxesId;@OdooMany2Many('account.tax', odooName: 'supplier_taxes_id') List<int>? get supplierTaxesId;// ═══════════════════ Description ═══════════════════
@OdooHtml() String? get description;@OdooString(odooName: 'description_sale') String? get descriptionSale;// ═══════════════════ Template Reference ═══════════════════
@OdooMany2One('product.template', odooName: 'product_tmpl_id') int? get productTmplId;// ═══════════════════ Image ═══════════════════
@OdooBinary(odooName: 'image_128', fetchByDefault: false) String? get image128;// ═══════════════════ Inventory ═══════════════════
@OdooFloat(odooName: 'qty_available') double get qtyAvailable;@OdooFloat(odooName: 'virtual_available') double get virtualAvailable;@OdooSelection(options: {'none' : 'No Tracking', 'serial' : 'By Serial Number', 'lot' : 'By Lot'}) String get tracking;@OdooBoolean(odooName: 'is_storable') bool get isStorable;// ═══════════════════ Ecuador Localization ═══════════════════
@OdooString(odooName: 'l10n_ec_auxiliary_code') String? get l10nEcAuxiliaryCode;@OdooBoolean(odooName: 'is_unit_product') bool get isUnitProduct;@OdooBoolean(odooName: 'temporal_no_despachar') bool get temporalNoDespachar;// ═══════════════════ Metadata ═══════════════════
@OdooDateTime(odooName: 'write_date') DateTime? get writeDate;
/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductCopyWith<Product> get copyWith => _$ProductCopyWithImpl<Product>(this as Product, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Product&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayNameOdoo, displayNameOdoo) || other.displayNameOdoo == displayNameOdoo)&&(identical(other.defaultCode, defaultCode) || other.defaultCode == defaultCode)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.type, type) || other.type == type)&&(identical(other.saleOk, saleOk) || other.saleOk == saleOk)&&(identical(other.purchaseOk, purchaseOk) || other.purchaseOk == purchaseOk)&&(identical(other.active, active) || other.active == active)&&(identical(other.listPrice, listPrice) || other.listPrice == listPrice)&&(identical(other.standardPrice, standardPrice) || other.standardPrice == standardPrice)&&(identical(other.categId, categId) || other.categId == categId)&&(identical(other.categName, categName) || other.categName == categName)&&(identical(other.uomId, uomId) || other.uomId == uomId)&&(identical(other.uomName, uomName) || other.uomName == uomName)&&(identical(other.uomPoId, uomPoId) || other.uomPoId == uomPoId)&&(identical(other.uomPoName, uomPoName) || other.uomPoName == uomPoName)&&const DeepCollectionEquality().equals(other.taxesId, taxesId)&&const DeepCollectionEquality().equals(other.supplierTaxesId, supplierTaxesId)&&(identical(other.description, description) || other.description == description)&&(identical(other.descriptionSale, descriptionSale) || other.descriptionSale == descriptionSale)&&(identical(other.productTmplId, productTmplId) || other.productTmplId == productTmplId)&&(identical(other.image128, image128) || other.image128 == image128)&&(identical(other.qtyAvailable, qtyAvailable) || other.qtyAvailable == qtyAvailable)&&(identical(other.virtualAvailable, virtualAvailable) || other.virtualAvailable == virtualAvailable)&&(identical(other.tracking, tracking) || other.tracking == tracking)&&(identical(other.isStorable, isStorable) || other.isStorable == isStorable)&&(identical(other.l10nEcAuxiliaryCode, l10nEcAuxiliaryCode) || other.l10nEcAuxiliaryCode == l10nEcAuxiliaryCode)&&(identical(other.isUnitProduct, isUnitProduct) || other.isUnitProduct == isUnitProduct)&&(identical(other.temporalNoDespachar, temporalNoDespachar) || other.temporalNoDespachar == temporalNoDespachar)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,uuid,isSynced,name,displayNameOdoo,defaultCode,barcode,type,saleOk,purchaseOk,active,listPrice,standardPrice,categId,categName,uomId,uomName,uomPoId,uomPoName,const DeepCollectionEquality().hash(taxesId),const DeepCollectionEquality().hash(supplierTaxesId),description,descriptionSale,productTmplId,image128,qtyAvailable,virtualAvailable,tracking,isStorable,l10nEcAuxiliaryCode,isUnitProduct,temporalNoDespachar,writeDate]);

@override
String toString() {
  return 'Product(id: $id, uuid: $uuid, isSynced: $isSynced, name: $name, displayNameOdoo: $displayNameOdoo, defaultCode: $defaultCode, barcode: $barcode, type: $type, saleOk: $saleOk, purchaseOk: $purchaseOk, active: $active, listPrice: $listPrice, standardPrice: $standardPrice, categId: $categId, categName: $categName, uomId: $uomId, uomName: $uomName, uomPoId: $uomPoId, uomPoName: $uomPoName, taxesId: $taxesId, supplierTaxesId: $supplierTaxesId, description: $description, descriptionSale: $descriptionSale, productTmplId: $productTmplId, image128: $image128, qtyAvailable: $qtyAvailable, virtualAvailable: $virtualAvailable, tracking: $tracking, isStorable: $isStorable, l10nEcAuxiliaryCode: $l10nEcAuxiliaryCode, isUnitProduct: $isUnitProduct, temporalNoDespachar: $temporalNoDespachar, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class $ProductCopyWith<$Res>  {
  factory $ProductCopyWith(Product value, $Res Function(Product) _then) = _$ProductCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooLocalOnly() bool isSynced,@OdooString() String name,@OdooString(odooName: 'display_name') String? displayNameOdoo,@OdooString(odooName: 'default_code') String? defaultCode,@OdooString() String? barcode,@OdooSelection(options: {'consu' : 'Consumable', 'service' : 'Service', 'product' : 'Storable'}) String type,@OdooBoolean(odooName: 'sale_ok') bool saleOk,@OdooBoolean(odooName: 'purchase_ok') bool purchaseOk,@OdooBoolean() bool active,@OdooMonetary(odooName: 'list_price') double listPrice,@OdooMonetary(odooName: 'standard_price') double standardPrice,@OdooMany2One('product.category', odooName: 'categ_id') int? categId,@OdooMany2OneName(sourceField: 'categ_id') String? categName,@OdooMany2One('uom.uom', odooName: 'uom_id') int? uomId,@OdooMany2OneName(sourceField: 'uom_id') String? uomName,@OdooMany2One('uom.uom', odooName: 'uom_po_id') int? uomPoId,@OdooMany2OneName(sourceField: 'uom_po_id') String? uomPoName,@OdooMany2Many('account.tax', odooName: 'taxes_id') List<int>? taxesId,@OdooMany2Many('account.tax', odooName: 'supplier_taxes_id') List<int>? supplierTaxesId,@OdooHtml() String? description,@OdooString(odooName: 'description_sale') String? descriptionSale,@OdooMany2One('product.template', odooName: 'product_tmpl_id') int? productTmplId,@OdooBinary(odooName: 'image_128', fetchByDefault: false) String? image128,@OdooFloat(odooName: 'qty_available') double qtyAvailable,@OdooFloat(odooName: 'virtual_available') double virtualAvailable,@OdooSelection(options: {'none' : 'No Tracking', 'serial' : 'By Serial Number', 'lot' : 'By Lot'}) String tracking,@OdooBoolean(odooName: 'is_storable') bool isStorable,@OdooString(odooName: 'l10n_ec_auxiliary_code') String? l10nEcAuxiliaryCode,@OdooBoolean(odooName: 'is_unit_product') bool isUnitProduct,@OdooBoolean(odooName: 'temporal_no_despachar') bool temporalNoDespachar,@OdooDateTime(odooName: 'write_date') DateTime? writeDate
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uuid = freezed,Object? isSynced = null,Object? name = null,Object? displayNameOdoo = freezed,Object? defaultCode = freezed,Object? barcode = freezed,Object? type = null,Object? saleOk = null,Object? purchaseOk = null,Object? active = null,Object? listPrice = null,Object? standardPrice = null,Object? categId = freezed,Object? categName = freezed,Object? uomId = freezed,Object? uomName = freezed,Object? uomPoId = freezed,Object? uomPoName = freezed,Object? taxesId = freezed,Object? supplierTaxesId = freezed,Object? description = freezed,Object? descriptionSale = freezed,Object? productTmplId = freezed,Object? image128 = freezed,Object? qtyAvailable = null,Object? virtualAvailable = null,Object? tracking = null,Object? isStorable = null,Object? l10nEcAuxiliaryCode = freezed,Object? isUnitProduct = null,Object? temporalNoDespachar = null,Object? writeDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayNameOdoo: freezed == displayNameOdoo ? _self.displayNameOdoo : displayNameOdoo // ignore: cast_nullable_to_non_nullable
as String?,defaultCode: freezed == defaultCode ? _self.defaultCode : defaultCode // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
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
as String?,taxesId: freezed == taxesId ? _self.taxesId : taxesId // ignore: cast_nullable_to_non_nullable
as List<int>?,supplierTaxesId: freezed == supplierTaxesId ? _self.supplierTaxesId : supplierTaxesId // ignore: cast_nullable_to_non_nullable
as List<int>?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,descriptionSale: freezed == descriptionSale ? _self.descriptionSale : descriptionSale // ignore: cast_nullable_to_non_nullable
as String?,productTmplId: freezed == productTmplId ? _self.productTmplId : productTmplId // ignore: cast_nullable_to_non_nullable
as int?,image128: freezed == image128 ? _self.image128 : image128 // ignore: cast_nullable_to_non_nullable
as String?,qtyAvailable: null == qtyAvailable ? _self.qtyAvailable : qtyAvailable // ignore: cast_nullable_to_non_nullable
as double,virtualAvailable: null == virtualAvailable ? _self.virtualAvailable : virtualAvailable // ignore: cast_nullable_to_non_nullable
as double,tracking: null == tracking ? _self.tracking : tracking // ignore: cast_nullable_to_non_nullable
as String,isStorable: null == isStorable ? _self.isStorable : isStorable // ignore: cast_nullable_to_non_nullable
as bool,l10nEcAuxiliaryCode: freezed == l10nEcAuxiliaryCode ? _self.l10nEcAuxiliaryCode : l10nEcAuxiliaryCode // ignore: cast_nullable_to_non_nullable
as String?,isUnitProduct: null == isUnitProduct ? _self.isUnitProduct : isUnitProduct // ignore: cast_nullable_to_non_nullable
as bool,temporalNoDespachar: null == temporalNoDespachar ? _self.temporalNoDespachar : temporalNoDespachar // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooString()  String name, @OdooString(odooName: 'display_name')  String? displayNameOdoo, @OdooString(odooName: 'default_code')  String? defaultCode, @OdooString()  String? barcode, @OdooSelection(options: {'consu' : 'Consumable', 'service' : 'Service', 'product' : 'Storable'})  String type, @OdooBoolean(odooName: 'sale_ok')  bool saleOk, @OdooBoolean(odooName: 'purchase_ok')  bool purchaseOk, @OdooBoolean()  bool active, @OdooMonetary(odooName: 'list_price')  double listPrice, @OdooMonetary(odooName: 'standard_price')  double standardPrice, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooMany2OneName(sourceField: 'categ_id')  String? categName, @OdooMany2One('uom.uom', odooName: 'uom_id')  int? uomId, @OdooMany2OneName(sourceField: 'uom_id')  String? uomName, @OdooMany2One('uom.uom', odooName: 'uom_po_id')  int? uomPoId, @OdooMany2OneName(sourceField: 'uom_po_id')  String? uomPoName, @OdooMany2Many('account.tax', odooName: 'taxes_id')  List<int>? taxesId, @OdooMany2Many('account.tax', odooName: 'supplier_taxes_id')  List<int>? supplierTaxesId, @OdooHtml()  String? description, @OdooString(odooName: 'description_sale')  String? descriptionSale, @OdooMany2One('product.template', odooName: 'product_tmpl_id')  int? productTmplId, @OdooBinary(odooName: 'image_128', fetchByDefault: false)  String? image128, @OdooFloat(odooName: 'qty_available')  double qtyAvailable, @OdooFloat(odooName: 'virtual_available')  double virtualAvailable, @OdooSelection(options: {'none' : 'No Tracking', 'serial' : 'By Serial Number', 'lot' : 'By Lot'})  String tracking, @OdooBoolean(odooName: 'is_storable')  bool isStorable, @OdooString(odooName: 'l10n_ec_auxiliary_code')  String? l10nEcAuxiliaryCode, @OdooBoolean(odooName: 'is_unit_product')  bool isUnitProduct, @OdooBoolean(odooName: 'temporal_no_despachar')  bool temporalNoDespachar, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.id,_that.uuid,_that.isSynced,_that.name,_that.displayNameOdoo,_that.defaultCode,_that.barcode,_that.type,_that.saleOk,_that.purchaseOk,_that.active,_that.listPrice,_that.standardPrice,_that.categId,_that.categName,_that.uomId,_that.uomName,_that.uomPoId,_that.uomPoName,_that.taxesId,_that.supplierTaxesId,_that.description,_that.descriptionSale,_that.productTmplId,_that.image128,_that.qtyAvailable,_that.virtualAvailable,_that.tracking,_that.isStorable,_that.l10nEcAuxiliaryCode,_that.isUnitProduct,_that.temporalNoDespachar,_that.writeDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooString()  String name, @OdooString(odooName: 'display_name')  String? displayNameOdoo, @OdooString(odooName: 'default_code')  String? defaultCode, @OdooString()  String? barcode, @OdooSelection(options: {'consu' : 'Consumable', 'service' : 'Service', 'product' : 'Storable'})  String type, @OdooBoolean(odooName: 'sale_ok')  bool saleOk, @OdooBoolean(odooName: 'purchase_ok')  bool purchaseOk, @OdooBoolean()  bool active, @OdooMonetary(odooName: 'list_price')  double listPrice, @OdooMonetary(odooName: 'standard_price')  double standardPrice, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooMany2OneName(sourceField: 'categ_id')  String? categName, @OdooMany2One('uom.uom', odooName: 'uom_id')  int? uomId, @OdooMany2OneName(sourceField: 'uom_id')  String? uomName, @OdooMany2One('uom.uom', odooName: 'uom_po_id')  int? uomPoId, @OdooMany2OneName(sourceField: 'uom_po_id')  String? uomPoName, @OdooMany2Many('account.tax', odooName: 'taxes_id')  List<int>? taxesId, @OdooMany2Many('account.tax', odooName: 'supplier_taxes_id')  List<int>? supplierTaxesId, @OdooHtml()  String? description, @OdooString(odooName: 'description_sale')  String? descriptionSale, @OdooMany2One('product.template', odooName: 'product_tmpl_id')  int? productTmplId, @OdooBinary(odooName: 'image_128', fetchByDefault: false)  String? image128, @OdooFloat(odooName: 'qty_available')  double qtyAvailable, @OdooFloat(odooName: 'virtual_available')  double virtualAvailable, @OdooSelection(options: {'none' : 'No Tracking', 'serial' : 'By Serial Number', 'lot' : 'By Lot'})  String tracking, @OdooBoolean(odooName: 'is_storable')  bool isStorable, @OdooString(odooName: 'l10n_ec_auxiliary_code')  String? l10nEcAuxiliaryCode, @OdooBoolean(odooName: 'is_unit_product')  bool isUnitProduct, @OdooBoolean(odooName: 'temporal_no_despachar')  bool temporalNoDespachar, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate)  $default,) {final _that = this;
switch (_that) {
case _Product():
return $default(_that.id,_that.uuid,_that.isSynced,_that.name,_that.displayNameOdoo,_that.defaultCode,_that.barcode,_that.type,_that.saleOk,_that.purchaseOk,_that.active,_that.listPrice,_that.standardPrice,_that.categId,_that.categName,_that.uomId,_that.uomName,_that.uomPoId,_that.uomPoName,_that.taxesId,_that.supplierTaxesId,_that.description,_that.descriptionSale,_that.productTmplId,_that.image128,_that.qtyAvailable,_that.virtualAvailable,_that.tracking,_that.isStorable,_that.l10nEcAuxiliaryCode,_that.isUnitProduct,_that.temporalNoDespachar,_that.writeDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? uuid, @OdooLocalOnly()  bool isSynced, @OdooString()  String name, @OdooString(odooName: 'display_name')  String? displayNameOdoo, @OdooString(odooName: 'default_code')  String? defaultCode, @OdooString()  String? barcode, @OdooSelection(options: {'consu' : 'Consumable', 'service' : 'Service', 'product' : 'Storable'})  String type, @OdooBoolean(odooName: 'sale_ok')  bool saleOk, @OdooBoolean(odooName: 'purchase_ok')  bool purchaseOk, @OdooBoolean()  bool active, @OdooMonetary(odooName: 'list_price')  double listPrice, @OdooMonetary(odooName: 'standard_price')  double standardPrice, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooMany2OneName(sourceField: 'categ_id')  String? categName, @OdooMany2One('uom.uom', odooName: 'uom_id')  int? uomId, @OdooMany2OneName(sourceField: 'uom_id')  String? uomName, @OdooMany2One('uom.uom', odooName: 'uom_po_id')  int? uomPoId, @OdooMany2OneName(sourceField: 'uom_po_id')  String? uomPoName, @OdooMany2Many('account.tax', odooName: 'taxes_id')  List<int>? taxesId, @OdooMany2Many('account.tax', odooName: 'supplier_taxes_id')  List<int>? supplierTaxesId, @OdooHtml()  String? description, @OdooString(odooName: 'description_sale')  String? descriptionSale, @OdooMany2One('product.template', odooName: 'product_tmpl_id')  int? productTmplId, @OdooBinary(odooName: 'image_128', fetchByDefault: false)  String? image128, @OdooFloat(odooName: 'qty_available')  double qtyAvailable, @OdooFloat(odooName: 'virtual_available')  double virtualAvailable, @OdooSelection(options: {'none' : 'No Tracking', 'serial' : 'By Serial Number', 'lot' : 'By Lot'})  String tracking, @OdooBoolean(odooName: 'is_storable')  bool isStorable, @OdooString(odooName: 'l10n_ec_auxiliary_code')  String? l10nEcAuxiliaryCode, @OdooBoolean(odooName: 'is_unit_product')  bool isUnitProduct, @OdooBoolean(odooName: 'temporal_no_despachar')  bool temporalNoDespachar, @OdooDateTime(odooName: 'write_date')  DateTime? writeDate)?  $default,) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.id,_that.uuid,_that.isSynced,_that.name,_that.displayNameOdoo,_that.defaultCode,_that.barcode,_that.type,_that.saleOk,_that.purchaseOk,_that.active,_that.listPrice,_that.standardPrice,_that.categId,_that.categName,_that.uomId,_that.uomName,_that.uomPoId,_that.uomPoName,_that.taxesId,_that.supplierTaxesId,_that.description,_that.descriptionSale,_that.productTmplId,_that.image128,_that.qtyAvailable,_that.virtualAvailable,_that.tracking,_that.isStorable,_that.l10nEcAuxiliaryCode,_that.isUnitProduct,_that.temporalNoDespachar,_that.writeDate);case _:
  return null;

}
}

}

/// @nodoc


class _Product extends Product {
  const _Product({@OdooId() required this.id, @OdooLocalOnly() this.uuid, @OdooLocalOnly() this.isSynced = false, @OdooString() required this.name, @OdooString(odooName: 'display_name') this.displayNameOdoo, @OdooString(odooName: 'default_code') this.defaultCode, @OdooString() this.barcode, @OdooSelection(options: {'consu' : 'Consumable', 'service' : 'Service', 'product' : 'Storable'}) this.type = 'consu', @OdooBoolean(odooName: 'sale_ok') this.saleOk = true, @OdooBoolean(odooName: 'purchase_ok') this.purchaseOk = true, @OdooBoolean() this.active = true, @OdooMonetary(odooName: 'list_price') this.listPrice = 0.0, @OdooMonetary(odooName: 'standard_price') this.standardPrice = 0.0, @OdooMany2One('product.category', odooName: 'categ_id') this.categId, @OdooMany2OneName(sourceField: 'categ_id') this.categName, @OdooMany2One('uom.uom', odooName: 'uom_id') this.uomId, @OdooMany2OneName(sourceField: 'uom_id') this.uomName, @OdooMany2One('uom.uom', odooName: 'uom_po_id') this.uomPoId, @OdooMany2OneName(sourceField: 'uom_po_id') this.uomPoName, @OdooMany2Many('account.tax', odooName: 'taxes_id') final  List<int>? taxesId, @OdooMany2Many('account.tax', odooName: 'supplier_taxes_id') final  List<int>? supplierTaxesId, @OdooHtml() this.description, @OdooString(odooName: 'description_sale') this.descriptionSale, @OdooMany2One('product.template', odooName: 'product_tmpl_id') this.productTmplId, @OdooBinary(odooName: 'image_128', fetchByDefault: false) this.image128, @OdooFloat(odooName: 'qty_available') this.qtyAvailable = 0.0, @OdooFloat(odooName: 'virtual_available') this.virtualAvailable = 0.0, @OdooSelection(options: {'none' : 'No Tracking', 'serial' : 'By Serial Number', 'lot' : 'By Lot'}) this.tracking = 'none', @OdooBoolean(odooName: 'is_storable') this.isStorable = false, @OdooString(odooName: 'l10n_ec_auxiliary_code') this.l10nEcAuxiliaryCode, @OdooBoolean(odooName: 'is_unit_product') this.isUnitProduct = true, @OdooBoolean(odooName: 'temporal_no_despachar') this.temporalNoDespachar = false, @OdooDateTime(odooName: 'write_date') this.writeDate}): _taxesId = taxesId,_supplierTaxesId = supplierTaxesId,super._();
  

// ═══════════════════ Identifiers ═══════════════════
@override@OdooId() final  int id;
@override@OdooLocalOnly() final  String? uuid;
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
// ═══════════════════ Basic Data ═══════════════════
@override@OdooString() final  String name;
@override@OdooString(odooName: 'display_name') final  String? displayNameOdoo;
@override@OdooString(odooName: 'default_code') final  String? defaultCode;
@override@OdooString() final  String? barcode;
@override@JsonKey()@OdooSelection(options: {'consu' : 'Consumable', 'service' : 'Service', 'product' : 'Storable'}) final  String type;
@override@JsonKey()@OdooBoolean(odooName: 'sale_ok') final  bool saleOk;
@override@JsonKey()@OdooBoolean(odooName: 'purchase_ok') final  bool purchaseOk;
@override@JsonKey()@OdooBoolean() final  bool active;
// ═══════════════════ Pricing ═══════════════════
@override@JsonKey()@OdooMonetary(odooName: 'list_price') final  double listPrice;
@override@JsonKey()@OdooMonetary(odooName: 'standard_price') final  double standardPrice;
// ═══════════════════ Category ═══════════════════
@override@OdooMany2One('product.category', odooName: 'categ_id') final  int? categId;
@override@OdooMany2OneName(sourceField: 'categ_id') final  String? categName;
// ═══════════════════ Unit of Measure ═══════════════════
@override@OdooMany2One('uom.uom', odooName: 'uom_id') final  int? uomId;
@override@OdooMany2OneName(sourceField: 'uom_id') final  String? uomName;
@override@OdooMany2One('uom.uom', odooName: 'uom_po_id') final  int? uomPoId;
@override@OdooMany2OneName(sourceField: 'uom_po_id') final  String? uomPoName;
// ═══════════════════ Taxes ═══════════════════
 final  List<int>? _taxesId;
// ═══════════════════ Taxes ═══════════════════
@override@OdooMany2Many('account.tax', odooName: 'taxes_id') List<int>? get taxesId {
  final value = _taxesId;
  if (value == null) return null;
  if (_taxesId is EqualUnmodifiableListView) return _taxesId;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<int>? _supplierTaxesId;
@override@OdooMany2Many('account.tax', odooName: 'supplier_taxes_id') List<int>? get supplierTaxesId {
  final value = _supplierTaxesId;
  if (value == null) return null;
  if (_supplierTaxesId is EqualUnmodifiableListView) return _supplierTaxesId;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// ═══════════════════ Description ═══════════════════
@override@OdooHtml() final  String? description;
@override@OdooString(odooName: 'description_sale') final  String? descriptionSale;
// ═══════════════════ Template Reference ═══════════════════
@override@OdooMany2One('product.template', odooName: 'product_tmpl_id') final  int? productTmplId;
// ═══════════════════ Image ═══════════════════
@override@OdooBinary(odooName: 'image_128', fetchByDefault: false) final  String? image128;
// ═══════════════════ Inventory ═══════════════════
@override@JsonKey()@OdooFloat(odooName: 'qty_available') final  double qtyAvailable;
@override@JsonKey()@OdooFloat(odooName: 'virtual_available') final  double virtualAvailable;
@override@JsonKey()@OdooSelection(options: {'none' : 'No Tracking', 'serial' : 'By Serial Number', 'lot' : 'By Lot'}) final  String tracking;
@override@JsonKey()@OdooBoolean(odooName: 'is_storable') final  bool isStorable;
// ═══════════════════ Ecuador Localization ═══════════════════
@override@OdooString(odooName: 'l10n_ec_auxiliary_code') final  String? l10nEcAuxiliaryCode;
@override@JsonKey()@OdooBoolean(odooName: 'is_unit_product') final  bool isUnitProduct;
@override@JsonKey()@OdooBoolean(odooName: 'temporal_no_despachar') final  bool temporalNoDespachar;
// ═══════════════════ Metadata ═══════════════════
@override@OdooDateTime(odooName: 'write_date') final  DateTime? writeDate;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductCopyWith<_Product> get copyWith => __$ProductCopyWithImpl<_Product>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Product&&(identical(other.id, id) || other.id == id)&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayNameOdoo, displayNameOdoo) || other.displayNameOdoo == displayNameOdoo)&&(identical(other.defaultCode, defaultCode) || other.defaultCode == defaultCode)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.type, type) || other.type == type)&&(identical(other.saleOk, saleOk) || other.saleOk == saleOk)&&(identical(other.purchaseOk, purchaseOk) || other.purchaseOk == purchaseOk)&&(identical(other.active, active) || other.active == active)&&(identical(other.listPrice, listPrice) || other.listPrice == listPrice)&&(identical(other.standardPrice, standardPrice) || other.standardPrice == standardPrice)&&(identical(other.categId, categId) || other.categId == categId)&&(identical(other.categName, categName) || other.categName == categName)&&(identical(other.uomId, uomId) || other.uomId == uomId)&&(identical(other.uomName, uomName) || other.uomName == uomName)&&(identical(other.uomPoId, uomPoId) || other.uomPoId == uomPoId)&&(identical(other.uomPoName, uomPoName) || other.uomPoName == uomPoName)&&const DeepCollectionEquality().equals(other._taxesId, _taxesId)&&const DeepCollectionEquality().equals(other._supplierTaxesId, _supplierTaxesId)&&(identical(other.description, description) || other.description == description)&&(identical(other.descriptionSale, descriptionSale) || other.descriptionSale == descriptionSale)&&(identical(other.productTmplId, productTmplId) || other.productTmplId == productTmplId)&&(identical(other.image128, image128) || other.image128 == image128)&&(identical(other.qtyAvailable, qtyAvailable) || other.qtyAvailable == qtyAvailable)&&(identical(other.virtualAvailable, virtualAvailable) || other.virtualAvailable == virtualAvailable)&&(identical(other.tracking, tracking) || other.tracking == tracking)&&(identical(other.isStorable, isStorable) || other.isStorable == isStorable)&&(identical(other.l10nEcAuxiliaryCode, l10nEcAuxiliaryCode) || other.l10nEcAuxiliaryCode == l10nEcAuxiliaryCode)&&(identical(other.isUnitProduct, isUnitProduct) || other.isUnitProduct == isUnitProduct)&&(identical(other.temporalNoDespachar, temporalNoDespachar) || other.temporalNoDespachar == temporalNoDespachar)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,uuid,isSynced,name,displayNameOdoo,defaultCode,barcode,type,saleOk,purchaseOk,active,listPrice,standardPrice,categId,categName,uomId,uomName,uomPoId,uomPoName,const DeepCollectionEquality().hash(_taxesId),const DeepCollectionEquality().hash(_supplierTaxesId),description,descriptionSale,productTmplId,image128,qtyAvailable,virtualAvailable,tracking,isStorable,l10nEcAuxiliaryCode,isUnitProduct,temporalNoDespachar,writeDate]);

@override
String toString() {
  return 'Product(id: $id, uuid: $uuid, isSynced: $isSynced, name: $name, displayNameOdoo: $displayNameOdoo, defaultCode: $defaultCode, barcode: $barcode, type: $type, saleOk: $saleOk, purchaseOk: $purchaseOk, active: $active, listPrice: $listPrice, standardPrice: $standardPrice, categId: $categId, categName: $categName, uomId: $uomId, uomName: $uomName, uomPoId: $uomPoId, uomPoName: $uomPoName, taxesId: $taxesId, supplierTaxesId: $supplierTaxesId, description: $description, descriptionSale: $descriptionSale, productTmplId: $productTmplId, image128: $image128, qtyAvailable: $qtyAvailable, virtualAvailable: $virtualAvailable, tracking: $tracking, isStorable: $isStorable, l10nEcAuxiliaryCode: $l10nEcAuxiliaryCode, isUnitProduct: $isUnitProduct, temporalNoDespachar: $temporalNoDespachar, writeDate: $writeDate)';
}


}

/// @nodoc
abstract mixin class _$ProductCopyWith<$Res> implements $ProductCopyWith<$Res> {
  factory _$ProductCopyWith(_Product value, $Res Function(_Product) _then) = __$ProductCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? uuid,@OdooLocalOnly() bool isSynced,@OdooString() String name,@OdooString(odooName: 'display_name') String? displayNameOdoo,@OdooString(odooName: 'default_code') String? defaultCode,@OdooString() String? barcode,@OdooSelection(options: {'consu' : 'Consumable', 'service' : 'Service', 'product' : 'Storable'}) String type,@OdooBoolean(odooName: 'sale_ok') bool saleOk,@OdooBoolean(odooName: 'purchase_ok') bool purchaseOk,@OdooBoolean() bool active,@OdooMonetary(odooName: 'list_price') double listPrice,@OdooMonetary(odooName: 'standard_price') double standardPrice,@OdooMany2One('product.category', odooName: 'categ_id') int? categId,@OdooMany2OneName(sourceField: 'categ_id') String? categName,@OdooMany2One('uom.uom', odooName: 'uom_id') int? uomId,@OdooMany2OneName(sourceField: 'uom_id') String? uomName,@OdooMany2One('uom.uom', odooName: 'uom_po_id') int? uomPoId,@OdooMany2OneName(sourceField: 'uom_po_id') String? uomPoName,@OdooMany2Many('account.tax', odooName: 'taxes_id') List<int>? taxesId,@OdooMany2Many('account.tax', odooName: 'supplier_taxes_id') List<int>? supplierTaxesId,@OdooHtml() String? description,@OdooString(odooName: 'description_sale') String? descriptionSale,@OdooMany2One('product.template', odooName: 'product_tmpl_id') int? productTmplId,@OdooBinary(odooName: 'image_128', fetchByDefault: false) String? image128,@OdooFloat(odooName: 'qty_available') double qtyAvailable,@OdooFloat(odooName: 'virtual_available') double virtualAvailable,@OdooSelection(options: {'none' : 'No Tracking', 'serial' : 'By Serial Number', 'lot' : 'By Lot'}) String tracking,@OdooBoolean(odooName: 'is_storable') bool isStorable,@OdooString(odooName: 'l10n_ec_auxiliary_code') String? l10nEcAuxiliaryCode,@OdooBoolean(odooName: 'is_unit_product') bool isUnitProduct,@OdooBoolean(odooName: 'temporal_no_despachar') bool temporalNoDespachar,@OdooDateTime(odooName: 'write_date') DateTime? writeDate
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uuid = freezed,Object? isSynced = null,Object? name = null,Object? displayNameOdoo = freezed,Object? defaultCode = freezed,Object? barcode = freezed,Object? type = null,Object? saleOk = null,Object? purchaseOk = null,Object? active = null,Object? listPrice = null,Object? standardPrice = null,Object? categId = freezed,Object? categName = freezed,Object? uomId = freezed,Object? uomName = freezed,Object? uomPoId = freezed,Object? uomPoName = freezed,Object? taxesId = freezed,Object? supplierTaxesId = freezed,Object? description = freezed,Object? descriptionSale = freezed,Object? productTmplId = freezed,Object? image128 = freezed,Object? qtyAvailable = null,Object? virtualAvailable = null,Object? tracking = null,Object? isStorable = null,Object? l10nEcAuxiliaryCode = freezed,Object? isUnitProduct = null,Object? temporalNoDespachar = null,Object? writeDate = freezed,}) {
  return _then(_Product(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,uuid: freezed == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayNameOdoo: freezed == displayNameOdoo ? _self.displayNameOdoo : displayNameOdoo // ignore: cast_nullable_to_non_nullable
as String?,defaultCode: freezed == defaultCode ? _self.defaultCode : defaultCode // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
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
as String?,taxesId: freezed == taxesId ? _self._taxesId : taxesId // ignore: cast_nullable_to_non_nullable
as List<int>?,supplierTaxesId: freezed == supplierTaxesId ? _self._supplierTaxesId : supplierTaxesId // ignore: cast_nullable_to_non_nullable
as List<int>?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,descriptionSale: freezed == descriptionSale ? _self.descriptionSale : descriptionSale // ignore: cast_nullable_to_non_nullable
as String?,productTmplId: freezed == productTmplId ? _self.productTmplId : productTmplId // ignore: cast_nullable_to_non_nullable
as int?,image128: freezed == image128 ? _self.image128 : image128 // ignore: cast_nullable_to_non_nullable
as String?,qtyAvailable: null == qtyAvailable ? _self.qtyAvailable : qtyAvailable // ignore: cast_nullable_to_non_nullable
as double,virtualAvailable: null == virtualAvailable ? _self.virtualAvailable : virtualAvailable // ignore: cast_nullable_to_non_nullable
as double,tracking: null == tracking ? _self.tracking : tracking // ignore: cast_nullable_to_non_nullable
as String,isStorable: null == isStorable ? _self.isStorable : isStorable // ignore: cast_nullable_to_non_nullable
as bool,l10nEcAuxiliaryCode: freezed == l10nEcAuxiliaryCode ? _self.l10nEcAuxiliaryCode : l10nEcAuxiliaryCode // ignore: cast_nullable_to_non_nullable
as String?,isUnitProduct: null == isUnitProduct ? _self.isUnitProduct : isUnitProduct // ignore: cast_nullable_to_non_nullable
as bool,temporalNoDespachar: null == temporalNoDespachar ? _self.temporalNoDespachar : temporalNoDespachar // ignore: cast_nullable_to_non_nullable
as bool,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
