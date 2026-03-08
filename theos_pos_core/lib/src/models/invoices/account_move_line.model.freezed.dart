// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_move_line.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountMoveLine {

// ============ Identifiers ============
@OdooId() int get id;// ============ Relations ============
@OdooMany2One('account.move', odooName: 'move_id') int get moveId;// ============ Basic Data ============
@OdooString() String get name;@OdooLocalOnly() InvoiceLineDisplayType get displayType;@OdooInteger() int get sequence;// ============ Product ============
@OdooMany2One('product.product', odooName: 'product_id') int? get productId;@OdooMany2OneName(sourceField: 'product_id') String? get productName;@OdooLocalOnly() String? get productCode;@OdooLocalOnly() String? get productBarcode;@OdooLocalOnly() String? get productL10nEcAuxiliaryCode;@OdooLocalOnly() String? get productType;// ============ Quantity and UoM ============
@OdooFloat() double get quantity;@OdooMany2One('uom.uom', odooName: 'product_uom_id') int? get productUomId;@OdooMany2OneName(sourceField: 'product_uom_id') String? get productUomName;// ============ Prices ============
@OdooFloat(odooName: 'price_unit') double get priceUnit;@OdooFloat() double get discount;@OdooFloat(odooName: 'price_subtotal') double get priceSubtotal;@OdooFloat(odooName: 'price_total') double get priceTotal;// ============ Taxes ============
@OdooLocalOnly() String? get taxIds;@OdooLocalOnly() String? get taxNames;@OdooMany2One('account.tax', odooName: 'tax_line_id') int? get taxLineId;@OdooMany2OneName(sourceField: 'tax_line_id') String? get taxLineName;// ============ Account ============
@OdooMany2One('account.account', odooName: 'account_id') int? get accountId;@OdooMany2OneName(sourceField: 'account_id') String? get accountName;// ============ Display Fields for Reports ============
@OdooBoolean(odooName: 'collapse_composition') bool get collapseComposition;@OdooBoolean(odooName: 'collapse_prices') bool get collapsePrices;
/// Create a copy of AccountMoveLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountMoveLineCopyWith<AccountMoveLine> get copyWith => _$AccountMoveLineCopyWithImpl<AccountMoveLine>(this as AccountMoveLine, _$identity);

  /// Serializes this AccountMoveLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountMoveLine&&(identical(other.id, id) || other.id == id)&&(identical(other.moveId, moveId) || other.moveId == moveId)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayType, displayType) || other.displayType == displayType)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.productCode, productCode) || other.productCode == productCode)&&(identical(other.productBarcode, productBarcode) || other.productBarcode == productBarcode)&&(identical(other.productL10nEcAuxiliaryCode, productL10nEcAuxiliaryCode) || other.productL10nEcAuxiliaryCode == productL10nEcAuxiliaryCode)&&(identical(other.productType, productType) || other.productType == productType)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.productUomId, productUomId) || other.productUomId == productUomId)&&(identical(other.productUomName, productUomName) || other.productUomName == productUomName)&&(identical(other.priceUnit, priceUnit) || other.priceUnit == priceUnit)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.priceSubtotal, priceSubtotal) || other.priceSubtotal == priceSubtotal)&&(identical(other.priceTotal, priceTotal) || other.priceTotal == priceTotal)&&(identical(other.taxIds, taxIds) || other.taxIds == taxIds)&&(identical(other.taxNames, taxNames) || other.taxNames == taxNames)&&(identical(other.taxLineId, taxLineId) || other.taxLineId == taxLineId)&&(identical(other.taxLineName, taxLineName) || other.taxLineName == taxLineName)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.accountName, accountName) || other.accountName == accountName)&&(identical(other.collapseComposition, collapseComposition) || other.collapseComposition == collapseComposition)&&(identical(other.collapsePrices, collapsePrices) || other.collapsePrices == collapsePrices));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,moveId,name,displayType,sequence,productId,productName,productCode,productBarcode,productL10nEcAuxiliaryCode,productType,quantity,productUomId,productUomName,priceUnit,discount,priceSubtotal,priceTotal,taxIds,taxNames,taxLineId,taxLineName,accountId,accountName,collapseComposition,collapsePrices]);

@override
String toString() {
  return 'AccountMoveLine(id: $id, moveId: $moveId, name: $name, displayType: $displayType, sequence: $sequence, productId: $productId, productName: $productName, productCode: $productCode, productBarcode: $productBarcode, productL10nEcAuxiliaryCode: $productL10nEcAuxiliaryCode, productType: $productType, quantity: $quantity, productUomId: $productUomId, productUomName: $productUomName, priceUnit: $priceUnit, discount: $discount, priceSubtotal: $priceSubtotal, priceTotal: $priceTotal, taxIds: $taxIds, taxNames: $taxNames, taxLineId: $taxLineId, taxLineName: $taxLineName, accountId: $accountId, accountName: $accountName, collapseComposition: $collapseComposition, collapsePrices: $collapsePrices)';
}


}

/// @nodoc
abstract mixin class $AccountMoveLineCopyWith<$Res>  {
  factory $AccountMoveLineCopyWith(AccountMoveLine value, $Res Function(AccountMoveLine) _then) = _$AccountMoveLineCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooMany2One('account.move', odooName: 'move_id') int moveId,@OdooString() String name,@OdooLocalOnly() InvoiceLineDisplayType displayType,@OdooInteger() int sequence,@OdooMany2One('product.product', odooName: 'product_id') int? productId,@OdooMany2OneName(sourceField: 'product_id') String? productName,@OdooLocalOnly() String? productCode,@OdooLocalOnly() String? productBarcode,@OdooLocalOnly() String? productL10nEcAuxiliaryCode,@OdooLocalOnly() String? productType,@OdooFloat() double quantity,@OdooMany2One('uom.uom', odooName: 'product_uom_id') int? productUomId,@OdooMany2OneName(sourceField: 'product_uom_id') String? productUomName,@OdooFloat(odooName: 'price_unit') double priceUnit,@OdooFloat() double discount,@OdooFloat(odooName: 'price_subtotal') double priceSubtotal,@OdooFloat(odooName: 'price_total') double priceTotal,@OdooLocalOnly() String? taxIds,@OdooLocalOnly() String? taxNames,@OdooMany2One('account.tax', odooName: 'tax_line_id') int? taxLineId,@OdooMany2OneName(sourceField: 'tax_line_id') String? taxLineName,@OdooMany2One('account.account', odooName: 'account_id') int? accountId,@OdooMany2OneName(sourceField: 'account_id') String? accountName,@OdooBoolean(odooName: 'collapse_composition') bool collapseComposition,@OdooBoolean(odooName: 'collapse_prices') bool collapsePrices
});




}
/// @nodoc
class _$AccountMoveLineCopyWithImpl<$Res>
    implements $AccountMoveLineCopyWith<$Res> {
  _$AccountMoveLineCopyWithImpl(this._self, this._then);

  final AccountMoveLine _self;
  final $Res Function(AccountMoveLine) _then;

/// Create a copy of AccountMoveLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? moveId = null,Object? name = null,Object? displayType = null,Object? sequence = null,Object? productId = freezed,Object? productName = freezed,Object? productCode = freezed,Object? productBarcode = freezed,Object? productL10nEcAuxiliaryCode = freezed,Object? productType = freezed,Object? quantity = null,Object? productUomId = freezed,Object? productUomName = freezed,Object? priceUnit = null,Object? discount = null,Object? priceSubtotal = null,Object? priceTotal = null,Object? taxIds = freezed,Object? taxNames = freezed,Object? taxLineId = freezed,Object? taxLineName = freezed,Object? accountId = freezed,Object? accountName = freezed,Object? collapseComposition = null,Object? collapsePrices = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,moveId: null == moveId ? _self.moveId : moveId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayType: null == displayType ? _self.displayType : displayType // ignore: cast_nullable_to_non_nullable
as InvoiceLineDisplayType,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as int?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,productCode: freezed == productCode ? _self.productCode : productCode // ignore: cast_nullable_to_non_nullable
as String?,productBarcode: freezed == productBarcode ? _self.productBarcode : productBarcode // ignore: cast_nullable_to_non_nullable
as String?,productL10nEcAuxiliaryCode: freezed == productL10nEcAuxiliaryCode ? _self.productL10nEcAuxiliaryCode : productL10nEcAuxiliaryCode // ignore: cast_nullable_to_non_nullable
as String?,productType: freezed == productType ? _self.productType : productType // ignore: cast_nullable_to_non_nullable
as String?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as double,productUomId: freezed == productUomId ? _self.productUomId : productUomId // ignore: cast_nullable_to_non_nullable
as int?,productUomName: freezed == productUomName ? _self.productUomName : productUomName // ignore: cast_nullable_to_non_nullable
as String?,priceUnit: null == priceUnit ? _self.priceUnit : priceUnit // ignore: cast_nullable_to_non_nullable
as double,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as double,priceSubtotal: null == priceSubtotal ? _self.priceSubtotal : priceSubtotal // ignore: cast_nullable_to_non_nullable
as double,priceTotal: null == priceTotal ? _self.priceTotal : priceTotal // ignore: cast_nullable_to_non_nullable
as double,taxIds: freezed == taxIds ? _self.taxIds : taxIds // ignore: cast_nullable_to_non_nullable
as String?,taxNames: freezed == taxNames ? _self.taxNames : taxNames // ignore: cast_nullable_to_non_nullable
as String?,taxLineId: freezed == taxLineId ? _self.taxLineId : taxLineId // ignore: cast_nullable_to_non_nullable
as int?,taxLineName: freezed == taxLineName ? _self.taxLineName : taxLineName // ignore: cast_nullable_to_non_nullable
as String?,accountId: freezed == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as int?,accountName: freezed == accountName ? _self.accountName : accountName // ignore: cast_nullable_to_non_nullable
as String?,collapseComposition: null == collapseComposition ? _self.collapseComposition : collapseComposition // ignore: cast_nullable_to_non_nullable
as bool,collapsePrices: null == collapsePrices ? _self.collapsePrices : collapsePrices // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountMoveLine].
extension AccountMoveLinePatterns on AccountMoveLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountMoveLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountMoveLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountMoveLine value)  $default,){
final _that = this;
switch (_that) {
case _AccountMoveLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountMoveLine value)?  $default,){
final _that = this;
switch (_that) {
case _AccountMoveLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooMany2One('account.move', odooName: 'move_id')  int moveId, @OdooString()  String name, @OdooLocalOnly()  InvoiceLineDisplayType displayType, @OdooInteger()  int sequence, @OdooMany2One('product.product', odooName: 'product_id')  int? productId, @OdooMany2OneName(sourceField: 'product_id')  String? productName, @OdooLocalOnly()  String? productCode, @OdooLocalOnly()  String? productBarcode, @OdooLocalOnly()  String? productL10nEcAuxiliaryCode, @OdooLocalOnly()  String? productType, @OdooFloat()  double quantity, @OdooMany2One('uom.uom', odooName: 'product_uom_id')  int? productUomId, @OdooMany2OneName(sourceField: 'product_uom_id')  String? productUomName, @OdooFloat(odooName: 'price_unit')  double priceUnit, @OdooFloat()  double discount, @OdooFloat(odooName: 'price_subtotal')  double priceSubtotal, @OdooFloat(odooName: 'price_total')  double priceTotal, @OdooLocalOnly()  String? taxIds, @OdooLocalOnly()  String? taxNames, @OdooMany2One('account.tax', odooName: 'tax_line_id')  int? taxLineId, @OdooMany2OneName(sourceField: 'tax_line_id')  String? taxLineName, @OdooMany2One('account.account', odooName: 'account_id')  int? accountId, @OdooMany2OneName(sourceField: 'account_id')  String? accountName, @OdooBoolean(odooName: 'collapse_composition')  bool collapseComposition, @OdooBoolean(odooName: 'collapse_prices')  bool collapsePrices)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountMoveLine() when $default != null:
return $default(_that.id,_that.moveId,_that.name,_that.displayType,_that.sequence,_that.productId,_that.productName,_that.productCode,_that.productBarcode,_that.productL10nEcAuxiliaryCode,_that.productType,_that.quantity,_that.productUomId,_that.productUomName,_that.priceUnit,_that.discount,_that.priceSubtotal,_that.priceTotal,_that.taxIds,_that.taxNames,_that.taxLineId,_that.taxLineName,_that.accountId,_that.accountName,_that.collapseComposition,_that.collapsePrices);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooMany2One('account.move', odooName: 'move_id')  int moveId, @OdooString()  String name, @OdooLocalOnly()  InvoiceLineDisplayType displayType, @OdooInteger()  int sequence, @OdooMany2One('product.product', odooName: 'product_id')  int? productId, @OdooMany2OneName(sourceField: 'product_id')  String? productName, @OdooLocalOnly()  String? productCode, @OdooLocalOnly()  String? productBarcode, @OdooLocalOnly()  String? productL10nEcAuxiliaryCode, @OdooLocalOnly()  String? productType, @OdooFloat()  double quantity, @OdooMany2One('uom.uom', odooName: 'product_uom_id')  int? productUomId, @OdooMany2OneName(sourceField: 'product_uom_id')  String? productUomName, @OdooFloat(odooName: 'price_unit')  double priceUnit, @OdooFloat()  double discount, @OdooFloat(odooName: 'price_subtotal')  double priceSubtotal, @OdooFloat(odooName: 'price_total')  double priceTotal, @OdooLocalOnly()  String? taxIds, @OdooLocalOnly()  String? taxNames, @OdooMany2One('account.tax', odooName: 'tax_line_id')  int? taxLineId, @OdooMany2OneName(sourceField: 'tax_line_id')  String? taxLineName, @OdooMany2One('account.account', odooName: 'account_id')  int? accountId, @OdooMany2OneName(sourceField: 'account_id')  String? accountName, @OdooBoolean(odooName: 'collapse_composition')  bool collapseComposition, @OdooBoolean(odooName: 'collapse_prices')  bool collapsePrices)  $default,) {final _that = this;
switch (_that) {
case _AccountMoveLine():
return $default(_that.id,_that.moveId,_that.name,_that.displayType,_that.sequence,_that.productId,_that.productName,_that.productCode,_that.productBarcode,_that.productL10nEcAuxiliaryCode,_that.productType,_that.quantity,_that.productUomId,_that.productUomName,_that.priceUnit,_that.discount,_that.priceSubtotal,_that.priceTotal,_that.taxIds,_that.taxNames,_that.taxLineId,_that.taxLineName,_that.accountId,_that.accountName,_that.collapseComposition,_that.collapsePrices);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooMany2One('account.move', odooName: 'move_id')  int moveId, @OdooString()  String name, @OdooLocalOnly()  InvoiceLineDisplayType displayType, @OdooInteger()  int sequence, @OdooMany2One('product.product', odooName: 'product_id')  int? productId, @OdooMany2OneName(sourceField: 'product_id')  String? productName, @OdooLocalOnly()  String? productCode, @OdooLocalOnly()  String? productBarcode, @OdooLocalOnly()  String? productL10nEcAuxiliaryCode, @OdooLocalOnly()  String? productType, @OdooFloat()  double quantity, @OdooMany2One('uom.uom', odooName: 'product_uom_id')  int? productUomId, @OdooMany2OneName(sourceField: 'product_uom_id')  String? productUomName, @OdooFloat(odooName: 'price_unit')  double priceUnit, @OdooFloat()  double discount, @OdooFloat(odooName: 'price_subtotal')  double priceSubtotal, @OdooFloat(odooName: 'price_total')  double priceTotal, @OdooLocalOnly()  String? taxIds, @OdooLocalOnly()  String? taxNames, @OdooMany2One('account.tax', odooName: 'tax_line_id')  int? taxLineId, @OdooMany2OneName(sourceField: 'tax_line_id')  String? taxLineName, @OdooMany2One('account.account', odooName: 'account_id')  int? accountId, @OdooMany2OneName(sourceField: 'account_id')  String? accountName, @OdooBoolean(odooName: 'collapse_composition')  bool collapseComposition, @OdooBoolean(odooName: 'collapse_prices')  bool collapsePrices)?  $default,) {final _that = this;
switch (_that) {
case _AccountMoveLine() when $default != null:
return $default(_that.id,_that.moveId,_that.name,_that.displayType,_that.sequence,_that.productId,_that.productName,_that.productCode,_that.productBarcode,_that.productL10nEcAuxiliaryCode,_that.productType,_that.quantity,_that.productUomId,_that.productUomName,_that.priceUnit,_that.discount,_that.priceSubtotal,_that.priceTotal,_that.taxIds,_that.taxNames,_that.taxLineId,_that.taxLineName,_that.accountId,_that.accountName,_that.collapseComposition,_that.collapsePrices);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountMoveLine extends AccountMoveLine {
  const _AccountMoveLine({@OdooId() this.id = 0, @OdooMany2One('account.move', odooName: 'move_id') this.moveId = 0, @OdooString() this.name = '', @OdooLocalOnly() this.displayType = InvoiceLineDisplayType.product, @OdooInteger() this.sequence = 10, @OdooMany2One('product.product', odooName: 'product_id') this.productId, @OdooMany2OneName(sourceField: 'product_id') this.productName, @OdooLocalOnly() this.productCode, @OdooLocalOnly() this.productBarcode, @OdooLocalOnly() this.productL10nEcAuxiliaryCode, @OdooLocalOnly() this.productType, @OdooFloat() this.quantity = 1.0, @OdooMany2One('uom.uom', odooName: 'product_uom_id') this.productUomId, @OdooMany2OneName(sourceField: 'product_uom_id') this.productUomName, @OdooFloat(odooName: 'price_unit') this.priceUnit = 0.0, @OdooFloat() this.discount = 0.0, @OdooFloat(odooName: 'price_subtotal') this.priceSubtotal = 0.0, @OdooFloat(odooName: 'price_total') this.priceTotal = 0.0, @OdooLocalOnly() this.taxIds, @OdooLocalOnly() this.taxNames, @OdooMany2One('account.tax', odooName: 'tax_line_id') this.taxLineId, @OdooMany2OneName(sourceField: 'tax_line_id') this.taxLineName, @OdooMany2One('account.account', odooName: 'account_id') this.accountId, @OdooMany2OneName(sourceField: 'account_id') this.accountName, @OdooBoolean(odooName: 'collapse_composition') this.collapseComposition = false, @OdooBoolean(odooName: 'collapse_prices') this.collapsePrices = false}): super._();
  factory _AccountMoveLine.fromJson(Map<String, dynamic> json) => _$AccountMoveLineFromJson(json);

// ============ Identifiers ============
@override@JsonKey()@OdooId() final  int id;
// ============ Relations ============
@override@JsonKey()@OdooMany2One('account.move', odooName: 'move_id') final  int moveId;
// ============ Basic Data ============
@override@JsonKey()@OdooString() final  String name;
@override@JsonKey()@OdooLocalOnly() final  InvoiceLineDisplayType displayType;
@override@JsonKey()@OdooInteger() final  int sequence;
// ============ Product ============
@override@OdooMany2One('product.product', odooName: 'product_id') final  int? productId;
@override@OdooMany2OneName(sourceField: 'product_id') final  String? productName;
@override@OdooLocalOnly() final  String? productCode;
@override@OdooLocalOnly() final  String? productBarcode;
@override@OdooLocalOnly() final  String? productL10nEcAuxiliaryCode;
@override@OdooLocalOnly() final  String? productType;
// ============ Quantity and UoM ============
@override@JsonKey()@OdooFloat() final  double quantity;
@override@OdooMany2One('uom.uom', odooName: 'product_uom_id') final  int? productUomId;
@override@OdooMany2OneName(sourceField: 'product_uom_id') final  String? productUomName;
// ============ Prices ============
@override@JsonKey()@OdooFloat(odooName: 'price_unit') final  double priceUnit;
@override@JsonKey()@OdooFloat() final  double discount;
@override@JsonKey()@OdooFloat(odooName: 'price_subtotal') final  double priceSubtotal;
@override@JsonKey()@OdooFloat(odooName: 'price_total') final  double priceTotal;
// ============ Taxes ============
@override@OdooLocalOnly() final  String? taxIds;
@override@OdooLocalOnly() final  String? taxNames;
@override@OdooMany2One('account.tax', odooName: 'tax_line_id') final  int? taxLineId;
@override@OdooMany2OneName(sourceField: 'tax_line_id') final  String? taxLineName;
// ============ Account ============
@override@OdooMany2One('account.account', odooName: 'account_id') final  int? accountId;
@override@OdooMany2OneName(sourceField: 'account_id') final  String? accountName;
// ============ Display Fields for Reports ============
@override@JsonKey()@OdooBoolean(odooName: 'collapse_composition') final  bool collapseComposition;
@override@JsonKey()@OdooBoolean(odooName: 'collapse_prices') final  bool collapsePrices;

/// Create a copy of AccountMoveLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountMoveLineCopyWith<_AccountMoveLine> get copyWith => __$AccountMoveLineCopyWithImpl<_AccountMoveLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountMoveLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountMoveLine&&(identical(other.id, id) || other.id == id)&&(identical(other.moveId, moveId) || other.moveId == moveId)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayType, displayType) || other.displayType == displayType)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.productCode, productCode) || other.productCode == productCode)&&(identical(other.productBarcode, productBarcode) || other.productBarcode == productBarcode)&&(identical(other.productL10nEcAuxiliaryCode, productL10nEcAuxiliaryCode) || other.productL10nEcAuxiliaryCode == productL10nEcAuxiliaryCode)&&(identical(other.productType, productType) || other.productType == productType)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.productUomId, productUomId) || other.productUomId == productUomId)&&(identical(other.productUomName, productUomName) || other.productUomName == productUomName)&&(identical(other.priceUnit, priceUnit) || other.priceUnit == priceUnit)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.priceSubtotal, priceSubtotal) || other.priceSubtotal == priceSubtotal)&&(identical(other.priceTotal, priceTotal) || other.priceTotal == priceTotal)&&(identical(other.taxIds, taxIds) || other.taxIds == taxIds)&&(identical(other.taxNames, taxNames) || other.taxNames == taxNames)&&(identical(other.taxLineId, taxLineId) || other.taxLineId == taxLineId)&&(identical(other.taxLineName, taxLineName) || other.taxLineName == taxLineName)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.accountName, accountName) || other.accountName == accountName)&&(identical(other.collapseComposition, collapseComposition) || other.collapseComposition == collapseComposition)&&(identical(other.collapsePrices, collapsePrices) || other.collapsePrices == collapsePrices));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,moveId,name,displayType,sequence,productId,productName,productCode,productBarcode,productL10nEcAuxiliaryCode,productType,quantity,productUomId,productUomName,priceUnit,discount,priceSubtotal,priceTotal,taxIds,taxNames,taxLineId,taxLineName,accountId,accountName,collapseComposition,collapsePrices]);

@override
String toString() {
  return 'AccountMoveLine(id: $id, moveId: $moveId, name: $name, displayType: $displayType, sequence: $sequence, productId: $productId, productName: $productName, productCode: $productCode, productBarcode: $productBarcode, productL10nEcAuxiliaryCode: $productL10nEcAuxiliaryCode, productType: $productType, quantity: $quantity, productUomId: $productUomId, productUomName: $productUomName, priceUnit: $priceUnit, discount: $discount, priceSubtotal: $priceSubtotal, priceTotal: $priceTotal, taxIds: $taxIds, taxNames: $taxNames, taxLineId: $taxLineId, taxLineName: $taxLineName, accountId: $accountId, accountName: $accountName, collapseComposition: $collapseComposition, collapsePrices: $collapsePrices)';
}


}

/// @nodoc
abstract mixin class _$AccountMoveLineCopyWith<$Res> implements $AccountMoveLineCopyWith<$Res> {
  factory _$AccountMoveLineCopyWith(_AccountMoveLine value, $Res Function(_AccountMoveLine) _then) = __$AccountMoveLineCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooMany2One('account.move', odooName: 'move_id') int moveId,@OdooString() String name,@OdooLocalOnly() InvoiceLineDisplayType displayType,@OdooInteger() int sequence,@OdooMany2One('product.product', odooName: 'product_id') int? productId,@OdooMany2OneName(sourceField: 'product_id') String? productName,@OdooLocalOnly() String? productCode,@OdooLocalOnly() String? productBarcode,@OdooLocalOnly() String? productL10nEcAuxiliaryCode,@OdooLocalOnly() String? productType,@OdooFloat() double quantity,@OdooMany2One('uom.uom', odooName: 'product_uom_id') int? productUomId,@OdooMany2OneName(sourceField: 'product_uom_id') String? productUomName,@OdooFloat(odooName: 'price_unit') double priceUnit,@OdooFloat() double discount,@OdooFloat(odooName: 'price_subtotal') double priceSubtotal,@OdooFloat(odooName: 'price_total') double priceTotal,@OdooLocalOnly() String? taxIds,@OdooLocalOnly() String? taxNames,@OdooMany2One('account.tax', odooName: 'tax_line_id') int? taxLineId,@OdooMany2OneName(sourceField: 'tax_line_id') String? taxLineName,@OdooMany2One('account.account', odooName: 'account_id') int? accountId,@OdooMany2OneName(sourceField: 'account_id') String? accountName,@OdooBoolean(odooName: 'collapse_composition') bool collapseComposition,@OdooBoolean(odooName: 'collapse_prices') bool collapsePrices
});




}
/// @nodoc
class __$AccountMoveLineCopyWithImpl<$Res>
    implements _$AccountMoveLineCopyWith<$Res> {
  __$AccountMoveLineCopyWithImpl(this._self, this._then);

  final _AccountMoveLine _self;
  final $Res Function(_AccountMoveLine) _then;

/// Create a copy of AccountMoveLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? moveId = null,Object? name = null,Object? displayType = null,Object? sequence = null,Object? productId = freezed,Object? productName = freezed,Object? productCode = freezed,Object? productBarcode = freezed,Object? productL10nEcAuxiliaryCode = freezed,Object? productType = freezed,Object? quantity = null,Object? productUomId = freezed,Object? productUomName = freezed,Object? priceUnit = null,Object? discount = null,Object? priceSubtotal = null,Object? priceTotal = null,Object? taxIds = freezed,Object? taxNames = freezed,Object? taxLineId = freezed,Object? taxLineName = freezed,Object? accountId = freezed,Object? accountName = freezed,Object? collapseComposition = null,Object? collapsePrices = null,}) {
  return _then(_AccountMoveLine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,moveId: null == moveId ? _self.moveId : moveId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayType: null == displayType ? _self.displayType : displayType // ignore: cast_nullable_to_non_nullable
as InvoiceLineDisplayType,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as int?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,productCode: freezed == productCode ? _self.productCode : productCode // ignore: cast_nullable_to_non_nullable
as String?,productBarcode: freezed == productBarcode ? _self.productBarcode : productBarcode // ignore: cast_nullable_to_non_nullable
as String?,productL10nEcAuxiliaryCode: freezed == productL10nEcAuxiliaryCode ? _self.productL10nEcAuxiliaryCode : productL10nEcAuxiliaryCode // ignore: cast_nullable_to_non_nullable
as String?,productType: freezed == productType ? _self.productType : productType // ignore: cast_nullable_to_non_nullable
as String?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as double,productUomId: freezed == productUomId ? _self.productUomId : productUomId // ignore: cast_nullable_to_non_nullable
as int?,productUomName: freezed == productUomName ? _self.productUomName : productUomName // ignore: cast_nullable_to_non_nullable
as String?,priceUnit: null == priceUnit ? _self.priceUnit : priceUnit // ignore: cast_nullable_to_non_nullable
as double,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as double,priceSubtotal: null == priceSubtotal ? _self.priceSubtotal : priceSubtotal // ignore: cast_nullable_to_non_nullable
as double,priceTotal: null == priceTotal ? _self.priceTotal : priceTotal // ignore: cast_nullable_to_non_nullable
as double,taxIds: freezed == taxIds ? _self.taxIds : taxIds // ignore: cast_nullable_to_non_nullable
as String?,taxNames: freezed == taxNames ? _self.taxNames : taxNames // ignore: cast_nullable_to_non_nullable
as String?,taxLineId: freezed == taxLineId ? _self.taxLineId : taxLineId // ignore: cast_nullable_to_non_nullable
as int?,taxLineName: freezed == taxLineName ? _self.taxLineName : taxLineName // ignore: cast_nullable_to_non_nullable
as String?,accountId: freezed == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as int?,accountName: freezed == accountName ? _self.accountName : accountName // ignore: cast_nullable_to_non_nullable
as String?,collapseComposition: null == collapseComposition ? _self.collapseComposition : collapseComposition // ignore: cast_nullable_to_non_nullable
as bool,collapsePrices: null == collapsePrices ? _self.collapsePrices : collapsePrices // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
