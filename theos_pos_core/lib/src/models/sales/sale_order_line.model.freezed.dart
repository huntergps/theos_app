// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sale_order_line.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SaleOrderLine {

@OdooId() int get id;@OdooLocalOnly() String? get lineUuid;// UUID local para sincronizacion offline-first
@OdooMany2One('sale.order', odooName: 'order_id') int get orderId;@OdooInteger() int get sequence;// Tipo de linea
@OdooSelection(odooName: 'display_type') LineDisplayType get displayType;@OdooBoolean(odooName: 'is_downpayment') bool get isDownpayment;// Producto
@OdooMany2One('product.product', odooName: 'product_id') int? get productId;@OdooMany2OneName(sourceField: 'product_id') String? get productName;@OdooString(odooName: 'product_default_code') String? get productCode;// default_code del producto
@OdooMany2One('product.template', odooName: 'product_template_id') int? get productTemplateId;@OdooMany2OneName(sourceField: 'product_template_id') String? get productTemplateName;@OdooString(odooName: 'product_type') String? get productType;// 'consu', 'service', 'product'
@OdooMany2One('product.category', odooName: 'categ_id') int? get categId;@OdooMany2OneName(sourceField: 'categ_id') String? get categName;// Descripcion
@OdooString() String get name;// Descripcion de la linea
// Cantidad y UoM
@OdooFloat(odooName: 'product_uom_qty') double get productUomQty;@OdooMany2One('uom.uom', odooName: 'product_uom_id') int? get productUomId;@OdooMany2OneName(sourceField: 'product_uom_id') String? get productUomName;// Precios
@OdooFloat(odooName: 'price_unit') double get priceUnit;@OdooFloat() double get discount;@OdooFloat(odooName: 'discount_amount') double get discountAmount;// Monto de descuento (campo computado de Odoo)
@OdooFloat(odooName: 'price_subtotal') double get priceSubtotal;@OdooFloat(odooName: 'price_tax') double get priceTax;@OdooFloat(odooName: 'price_total') double get priceTotal;@OdooFloat(odooName: 'price_reduce_taxexcl') double get priceReduce;// Precio con descuento
// Impuestos (JSON array de IDs)
@OdooString(odooName: 'tax_ids') String? get taxIds;// Nombres de impuestos (para mostrar en UI)
@OdooLocalOnly() String? get taxNames;// Entrega
@OdooFloat(odooName: 'qty_delivered') double get qtyDelivered;@OdooFloat(odooName: 'customer_lead') double get customerLead;// Lead time en dias
// Facturacion
@OdooFloat(odooName: 'qty_invoiced') double get qtyInvoiced;@OdooFloat(odooName: 'qty_to_invoice') double get qtyToInvoice;@OdooSelection(odooName: 'invoice_status') LineInvoiceStatus get invoiceStatus;// Estado de la orden (related)
@OdooString(odooName: 'state') String? get orderState;// Section settings (Odoo 19)
@OdooBoolean(odooName: 'collapse_prices') bool get collapsePrices;// Ocultar precios de lineas en esta seccion
@OdooBoolean(odooName: 'collapse_composition') bool get collapseComposition;// Ocultar lineas hijas (solo mostrar seccion)
@OdooBoolean(odooName: 'is_optional') bool get isOptional;// Linea opcional (cliente puede elegir en portal)
// Sync
@OdooLocalOnly() bool get isSynced;@OdooLocalOnly() DateTime? get lastSyncDate;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;// Product flags from catalog (for display purposes)
@OdooLocalOnly() bool get isUnitProduct;
/// Create a copy of SaleOrderLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SaleOrderLineCopyWith<SaleOrderLine> get copyWith => _$SaleOrderLineCopyWithImpl<SaleOrderLine>(this as SaleOrderLine, _$identity);

  /// Serializes this SaleOrderLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SaleOrderLine&&(identical(other.id, id) || other.id == id)&&(identical(other.lineUuid, lineUuid) || other.lineUuid == lineUuid)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.displayType, displayType) || other.displayType == displayType)&&(identical(other.isDownpayment, isDownpayment) || other.isDownpayment == isDownpayment)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.productCode, productCode) || other.productCode == productCode)&&(identical(other.productTemplateId, productTemplateId) || other.productTemplateId == productTemplateId)&&(identical(other.productTemplateName, productTemplateName) || other.productTemplateName == productTemplateName)&&(identical(other.productType, productType) || other.productType == productType)&&(identical(other.categId, categId) || other.categId == categId)&&(identical(other.categName, categName) || other.categName == categName)&&(identical(other.name, name) || other.name == name)&&(identical(other.productUomQty, productUomQty) || other.productUomQty == productUomQty)&&(identical(other.productUomId, productUomId) || other.productUomId == productUomId)&&(identical(other.productUomName, productUomName) || other.productUomName == productUomName)&&(identical(other.priceUnit, priceUnit) || other.priceUnit == priceUnit)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.discountAmount, discountAmount) || other.discountAmount == discountAmount)&&(identical(other.priceSubtotal, priceSubtotal) || other.priceSubtotal == priceSubtotal)&&(identical(other.priceTax, priceTax) || other.priceTax == priceTax)&&(identical(other.priceTotal, priceTotal) || other.priceTotal == priceTotal)&&(identical(other.priceReduce, priceReduce) || other.priceReduce == priceReduce)&&(identical(other.taxIds, taxIds) || other.taxIds == taxIds)&&(identical(other.taxNames, taxNames) || other.taxNames == taxNames)&&(identical(other.qtyDelivered, qtyDelivered) || other.qtyDelivered == qtyDelivered)&&(identical(other.customerLead, customerLead) || other.customerLead == customerLead)&&(identical(other.qtyInvoiced, qtyInvoiced) || other.qtyInvoiced == qtyInvoiced)&&(identical(other.qtyToInvoice, qtyToInvoice) || other.qtyToInvoice == qtyToInvoice)&&(identical(other.invoiceStatus, invoiceStatus) || other.invoiceStatus == invoiceStatus)&&(identical(other.orderState, orderState) || other.orderState == orderState)&&(identical(other.collapsePrices, collapsePrices) || other.collapsePrices == collapsePrices)&&(identical(other.collapseComposition, collapseComposition) || other.collapseComposition == collapseComposition)&&(identical(other.isOptional, isOptional) || other.isOptional == isOptional)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.isUnitProduct, isUnitProduct) || other.isUnitProduct == isUnitProduct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,lineUuid,orderId,sequence,displayType,isDownpayment,productId,productName,productCode,productTemplateId,productTemplateName,productType,categId,categName,name,productUomQty,productUomId,productUomName,priceUnit,discount,discountAmount,priceSubtotal,priceTax,priceTotal,priceReduce,taxIds,taxNames,qtyDelivered,customerLead,qtyInvoiced,qtyToInvoice,invoiceStatus,orderState,collapsePrices,collapseComposition,isOptional,isSynced,lastSyncDate,writeDate,isUnitProduct]);

@override
String toString() {
  return 'SaleOrderLine(id: $id, lineUuid: $lineUuid, orderId: $orderId, sequence: $sequence, displayType: $displayType, isDownpayment: $isDownpayment, productId: $productId, productName: $productName, productCode: $productCode, productTemplateId: $productTemplateId, productTemplateName: $productTemplateName, productType: $productType, categId: $categId, categName: $categName, name: $name, productUomQty: $productUomQty, productUomId: $productUomId, productUomName: $productUomName, priceUnit: $priceUnit, discount: $discount, discountAmount: $discountAmount, priceSubtotal: $priceSubtotal, priceTax: $priceTax, priceTotal: $priceTotal, priceReduce: $priceReduce, taxIds: $taxIds, taxNames: $taxNames, qtyDelivered: $qtyDelivered, customerLead: $customerLead, qtyInvoiced: $qtyInvoiced, qtyToInvoice: $qtyToInvoice, invoiceStatus: $invoiceStatus, orderState: $orderState, collapsePrices: $collapsePrices, collapseComposition: $collapseComposition, isOptional: $isOptional, isSynced: $isSynced, lastSyncDate: $lastSyncDate, writeDate: $writeDate, isUnitProduct: $isUnitProduct)';
}


}

/// @nodoc
abstract mixin class $SaleOrderLineCopyWith<$Res>  {
  factory $SaleOrderLineCopyWith(SaleOrderLine value, $Res Function(SaleOrderLine) _then) = _$SaleOrderLineCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? lineUuid,@OdooMany2One('sale.order', odooName: 'order_id') int orderId,@OdooInteger() int sequence,@OdooSelection(odooName: 'display_type') LineDisplayType displayType,@OdooBoolean(odooName: 'is_downpayment') bool isDownpayment,@OdooMany2One('product.product', odooName: 'product_id') int? productId,@OdooMany2OneName(sourceField: 'product_id') String? productName,@OdooString(odooName: 'product_default_code') String? productCode,@OdooMany2One('product.template', odooName: 'product_template_id') int? productTemplateId,@OdooMany2OneName(sourceField: 'product_template_id') String? productTemplateName,@OdooString(odooName: 'product_type') String? productType,@OdooMany2One('product.category', odooName: 'categ_id') int? categId,@OdooMany2OneName(sourceField: 'categ_id') String? categName,@OdooString() String name,@OdooFloat(odooName: 'product_uom_qty') double productUomQty,@OdooMany2One('uom.uom', odooName: 'product_uom_id') int? productUomId,@OdooMany2OneName(sourceField: 'product_uom_id') String? productUomName,@OdooFloat(odooName: 'price_unit') double priceUnit,@OdooFloat() double discount,@OdooFloat(odooName: 'discount_amount') double discountAmount,@OdooFloat(odooName: 'price_subtotal') double priceSubtotal,@OdooFloat(odooName: 'price_tax') double priceTax,@OdooFloat(odooName: 'price_total') double priceTotal,@OdooFloat(odooName: 'price_reduce_taxexcl') double priceReduce,@OdooString(odooName: 'tax_ids') String? taxIds,@OdooLocalOnly() String? taxNames,@OdooFloat(odooName: 'qty_delivered') double qtyDelivered,@OdooFloat(odooName: 'customer_lead') double customerLead,@OdooFloat(odooName: 'qty_invoiced') double qtyInvoiced,@OdooFloat(odooName: 'qty_to_invoice') double qtyToInvoice,@OdooSelection(odooName: 'invoice_status') LineInvoiceStatus invoiceStatus,@OdooString(odooName: 'state') String? orderState,@OdooBoolean(odooName: 'collapse_prices') bool collapsePrices,@OdooBoolean(odooName: 'collapse_composition') bool collapseComposition,@OdooBoolean(odooName: 'is_optional') bool isOptional,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? lastSyncDate,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool isUnitProduct
});




}
/// @nodoc
class _$SaleOrderLineCopyWithImpl<$Res>
    implements $SaleOrderLineCopyWith<$Res> {
  _$SaleOrderLineCopyWithImpl(this._self, this._then);

  final SaleOrderLine _self;
  final $Res Function(SaleOrderLine) _then;

/// Create a copy of SaleOrderLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? lineUuid = freezed,Object? orderId = null,Object? sequence = null,Object? displayType = null,Object? isDownpayment = null,Object? productId = freezed,Object? productName = freezed,Object? productCode = freezed,Object? productTemplateId = freezed,Object? productTemplateName = freezed,Object? productType = freezed,Object? categId = freezed,Object? categName = freezed,Object? name = null,Object? productUomQty = null,Object? productUomId = freezed,Object? productUomName = freezed,Object? priceUnit = null,Object? discount = null,Object? discountAmount = null,Object? priceSubtotal = null,Object? priceTax = null,Object? priceTotal = null,Object? priceReduce = null,Object? taxIds = freezed,Object? taxNames = freezed,Object? qtyDelivered = null,Object? customerLead = null,Object? qtyInvoiced = null,Object? qtyToInvoice = null,Object? invoiceStatus = null,Object? orderState = freezed,Object? collapsePrices = null,Object? collapseComposition = null,Object? isOptional = null,Object? isSynced = null,Object? lastSyncDate = freezed,Object? writeDate = freezed,Object? isUnitProduct = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,lineUuid: freezed == lineUuid ? _self.lineUuid : lineUuid // ignore: cast_nullable_to_non_nullable
as String?,orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as int,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,displayType: null == displayType ? _self.displayType : displayType // ignore: cast_nullable_to_non_nullable
as LineDisplayType,isDownpayment: null == isDownpayment ? _self.isDownpayment : isDownpayment // ignore: cast_nullable_to_non_nullable
as bool,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as int?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,productCode: freezed == productCode ? _self.productCode : productCode // ignore: cast_nullable_to_non_nullable
as String?,productTemplateId: freezed == productTemplateId ? _self.productTemplateId : productTemplateId // ignore: cast_nullable_to_non_nullable
as int?,productTemplateName: freezed == productTemplateName ? _self.productTemplateName : productTemplateName // ignore: cast_nullable_to_non_nullable
as String?,productType: freezed == productType ? _self.productType : productType // ignore: cast_nullable_to_non_nullable
as String?,categId: freezed == categId ? _self.categId : categId // ignore: cast_nullable_to_non_nullable
as int?,categName: freezed == categName ? _self.categName : categName // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,productUomQty: null == productUomQty ? _self.productUomQty : productUomQty // ignore: cast_nullable_to_non_nullable
as double,productUomId: freezed == productUomId ? _self.productUomId : productUomId // ignore: cast_nullable_to_non_nullable
as int?,productUomName: freezed == productUomName ? _self.productUomName : productUomName // ignore: cast_nullable_to_non_nullable
as String?,priceUnit: null == priceUnit ? _self.priceUnit : priceUnit // ignore: cast_nullable_to_non_nullable
as double,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as double,discountAmount: null == discountAmount ? _self.discountAmount : discountAmount // ignore: cast_nullable_to_non_nullable
as double,priceSubtotal: null == priceSubtotal ? _self.priceSubtotal : priceSubtotal // ignore: cast_nullable_to_non_nullable
as double,priceTax: null == priceTax ? _self.priceTax : priceTax // ignore: cast_nullable_to_non_nullable
as double,priceTotal: null == priceTotal ? _self.priceTotal : priceTotal // ignore: cast_nullable_to_non_nullable
as double,priceReduce: null == priceReduce ? _self.priceReduce : priceReduce // ignore: cast_nullable_to_non_nullable
as double,taxIds: freezed == taxIds ? _self.taxIds : taxIds // ignore: cast_nullable_to_non_nullable
as String?,taxNames: freezed == taxNames ? _self.taxNames : taxNames // ignore: cast_nullable_to_non_nullable
as String?,qtyDelivered: null == qtyDelivered ? _self.qtyDelivered : qtyDelivered // ignore: cast_nullable_to_non_nullable
as double,customerLead: null == customerLead ? _self.customerLead : customerLead // ignore: cast_nullable_to_non_nullable
as double,qtyInvoiced: null == qtyInvoiced ? _self.qtyInvoiced : qtyInvoiced // ignore: cast_nullable_to_non_nullable
as double,qtyToInvoice: null == qtyToInvoice ? _self.qtyToInvoice : qtyToInvoice // ignore: cast_nullable_to_non_nullable
as double,invoiceStatus: null == invoiceStatus ? _self.invoiceStatus : invoiceStatus // ignore: cast_nullable_to_non_nullable
as LineInvoiceStatus,orderState: freezed == orderState ? _self.orderState : orderState // ignore: cast_nullable_to_non_nullable
as String?,collapsePrices: null == collapsePrices ? _self.collapsePrices : collapsePrices // ignore: cast_nullable_to_non_nullable
as bool,collapseComposition: null == collapseComposition ? _self.collapseComposition : collapseComposition // ignore: cast_nullable_to_non_nullable
as bool,isOptional: null == isOptional ? _self.isOptional : isOptional // ignore: cast_nullable_to_non_nullable
as bool,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,isUnitProduct: null == isUnitProduct ? _self.isUnitProduct : isUnitProduct // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SaleOrderLine].
extension SaleOrderLinePatterns on SaleOrderLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SaleOrderLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SaleOrderLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SaleOrderLine value)  $default,){
final _that = this;
switch (_that) {
case _SaleOrderLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SaleOrderLine value)?  $default,){
final _that = this;
switch (_that) {
case _SaleOrderLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? lineUuid, @OdooMany2One('sale.order', odooName: 'order_id')  int orderId, @OdooInteger()  int sequence, @OdooSelection(odooName: 'display_type')  LineDisplayType displayType, @OdooBoolean(odooName: 'is_downpayment')  bool isDownpayment, @OdooMany2One('product.product', odooName: 'product_id')  int? productId, @OdooMany2OneName(sourceField: 'product_id')  String? productName, @OdooString(odooName: 'product_default_code')  String? productCode, @OdooMany2One('product.template', odooName: 'product_template_id')  int? productTemplateId, @OdooMany2OneName(sourceField: 'product_template_id')  String? productTemplateName, @OdooString(odooName: 'product_type')  String? productType, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooMany2OneName(sourceField: 'categ_id')  String? categName, @OdooString()  String name, @OdooFloat(odooName: 'product_uom_qty')  double productUomQty, @OdooMany2One('uom.uom', odooName: 'product_uom_id')  int? productUomId, @OdooMany2OneName(sourceField: 'product_uom_id')  String? productUomName, @OdooFloat(odooName: 'price_unit')  double priceUnit, @OdooFloat()  double discount, @OdooFloat(odooName: 'discount_amount')  double discountAmount, @OdooFloat(odooName: 'price_subtotal')  double priceSubtotal, @OdooFloat(odooName: 'price_tax')  double priceTax, @OdooFloat(odooName: 'price_total')  double priceTotal, @OdooFloat(odooName: 'price_reduce_taxexcl')  double priceReduce, @OdooString(odooName: 'tax_ids')  String? taxIds, @OdooLocalOnly()  String? taxNames, @OdooFloat(odooName: 'qty_delivered')  double qtyDelivered, @OdooFloat(odooName: 'customer_lead')  double customerLead, @OdooFloat(odooName: 'qty_invoiced')  double qtyInvoiced, @OdooFloat(odooName: 'qty_to_invoice')  double qtyToInvoice, @OdooSelection(odooName: 'invoice_status')  LineInvoiceStatus invoiceStatus, @OdooString(odooName: 'state')  String? orderState, @OdooBoolean(odooName: 'collapse_prices')  bool collapsePrices, @OdooBoolean(odooName: 'collapse_composition')  bool collapseComposition, @OdooBoolean(odooName: 'is_optional')  bool isOptional, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isUnitProduct)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SaleOrderLine() when $default != null:
return $default(_that.id,_that.lineUuid,_that.orderId,_that.sequence,_that.displayType,_that.isDownpayment,_that.productId,_that.productName,_that.productCode,_that.productTemplateId,_that.productTemplateName,_that.productType,_that.categId,_that.categName,_that.name,_that.productUomQty,_that.productUomId,_that.productUomName,_that.priceUnit,_that.discount,_that.discountAmount,_that.priceSubtotal,_that.priceTax,_that.priceTotal,_that.priceReduce,_that.taxIds,_that.taxNames,_that.qtyDelivered,_that.customerLead,_that.qtyInvoiced,_that.qtyToInvoice,_that.invoiceStatus,_that.orderState,_that.collapsePrices,_that.collapseComposition,_that.isOptional,_that.isSynced,_that.lastSyncDate,_that.writeDate,_that.isUnitProduct);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? lineUuid, @OdooMany2One('sale.order', odooName: 'order_id')  int orderId, @OdooInteger()  int sequence, @OdooSelection(odooName: 'display_type')  LineDisplayType displayType, @OdooBoolean(odooName: 'is_downpayment')  bool isDownpayment, @OdooMany2One('product.product', odooName: 'product_id')  int? productId, @OdooMany2OneName(sourceField: 'product_id')  String? productName, @OdooString(odooName: 'product_default_code')  String? productCode, @OdooMany2One('product.template', odooName: 'product_template_id')  int? productTemplateId, @OdooMany2OneName(sourceField: 'product_template_id')  String? productTemplateName, @OdooString(odooName: 'product_type')  String? productType, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooMany2OneName(sourceField: 'categ_id')  String? categName, @OdooString()  String name, @OdooFloat(odooName: 'product_uom_qty')  double productUomQty, @OdooMany2One('uom.uom', odooName: 'product_uom_id')  int? productUomId, @OdooMany2OneName(sourceField: 'product_uom_id')  String? productUomName, @OdooFloat(odooName: 'price_unit')  double priceUnit, @OdooFloat()  double discount, @OdooFloat(odooName: 'discount_amount')  double discountAmount, @OdooFloat(odooName: 'price_subtotal')  double priceSubtotal, @OdooFloat(odooName: 'price_tax')  double priceTax, @OdooFloat(odooName: 'price_total')  double priceTotal, @OdooFloat(odooName: 'price_reduce_taxexcl')  double priceReduce, @OdooString(odooName: 'tax_ids')  String? taxIds, @OdooLocalOnly()  String? taxNames, @OdooFloat(odooName: 'qty_delivered')  double qtyDelivered, @OdooFloat(odooName: 'customer_lead')  double customerLead, @OdooFloat(odooName: 'qty_invoiced')  double qtyInvoiced, @OdooFloat(odooName: 'qty_to_invoice')  double qtyToInvoice, @OdooSelection(odooName: 'invoice_status')  LineInvoiceStatus invoiceStatus, @OdooString(odooName: 'state')  String? orderState, @OdooBoolean(odooName: 'collapse_prices')  bool collapsePrices, @OdooBoolean(odooName: 'collapse_composition')  bool collapseComposition, @OdooBoolean(odooName: 'is_optional')  bool isOptional, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isUnitProduct)  $default,) {final _that = this;
switch (_that) {
case _SaleOrderLine():
return $default(_that.id,_that.lineUuid,_that.orderId,_that.sequence,_that.displayType,_that.isDownpayment,_that.productId,_that.productName,_that.productCode,_that.productTemplateId,_that.productTemplateName,_that.productType,_that.categId,_that.categName,_that.name,_that.productUomQty,_that.productUomId,_that.productUomName,_that.priceUnit,_that.discount,_that.discountAmount,_that.priceSubtotal,_that.priceTax,_that.priceTotal,_that.priceReduce,_that.taxIds,_that.taxNames,_that.qtyDelivered,_that.customerLead,_that.qtyInvoiced,_that.qtyToInvoice,_that.invoiceStatus,_that.orderState,_that.collapsePrices,_that.collapseComposition,_that.isOptional,_that.isSynced,_that.lastSyncDate,_that.writeDate,_that.isUnitProduct);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? lineUuid, @OdooMany2One('sale.order', odooName: 'order_id')  int orderId, @OdooInteger()  int sequence, @OdooSelection(odooName: 'display_type')  LineDisplayType displayType, @OdooBoolean(odooName: 'is_downpayment')  bool isDownpayment, @OdooMany2One('product.product', odooName: 'product_id')  int? productId, @OdooMany2OneName(sourceField: 'product_id')  String? productName, @OdooString(odooName: 'product_default_code')  String? productCode, @OdooMany2One('product.template', odooName: 'product_template_id')  int? productTemplateId, @OdooMany2OneName(sourceField: 'product_template_id')  String? productTemplateName, @OdooString(odooName: 'product_type')  String? productType, @OdooMany2One('product.category', odooName: 'categ_id')  int? categId, @OdooMany2OneName(sourceField: 'categ_id')  String? categName, @OdooString()  String name, @OdooFloat(odooName: 'product_uom_qty')  double productUomQty, @OdooMany2One('uom.uom', odooName: 'product_uom_id')  int? productUomId, @OdooMany2OneName(sourceField: 'product_uom_id')  String? productUomName, @OdooFloat(odooName: 'price_unit')  double priceUnit, @OdooFloat()  double discount, @OdooFloat(odooName: 'discount_amount')  double discountAmount, @OdooFloat(odooName: 'price_subtotal')  double priceSubtotal, @OdooFloat(odooName: 'price_tax')  double priceTax, @OdooFloat(odooName: 'price_total')  double priceTotal, @OdooFloat(odooName: 'price_reduce_taxexcl')  double priceReduce, @OdooString(odooName: 'tax_ids')  String? taxIds, @OdooLocalOnly()  String? taxNames, @OdooFloat(odooName: 'qty_delivered')  double qtyDelivered, @OdooFloat(odooName: 'customer_lead')  double customerLead, @OdooFloat(odooName: 'qty_invoiced')  double qtyInvoiced, @OdooFloat(odooName: 'qty_to_invoice')  double qtyToInvoice, @OdooSelection(odooName: 'invoice_status')  LineInvoiceStatus invoiceStatus, @OdooString(odooName: 'state')  String? orderState, @OdooBoolean(odooName: 'collapse_prices')  bool collapsePrices, @OdooBoolean(odooName: 'collapse_composition')  bool collapseComposition, @OdooBoolean(odooName: 'is_optional')  bool isOptional, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool isUnitProduct)?  $default,) {final _that = this;
switch (_that) {
case _SaleOrderLine() when $default != null:
return $default(_that.id,_that.lineUuid,_that.orderId,_that.sequence,_that.displayType,_that.isDownpayment,_that.productId,_that.productName,_that.productCode,_that.productTemplateId,_that.productTemplateName,_that.productType,_that.categId,_that.categName,_that.name,_that.productUomQty,_that.productUomId,_that.productUomName,_that.priceUnit,_that.discount,_that.discountAmount,_that.priceSubtotal,_that.priceTax,_that.priceTotal,_that.priceReduce,_that.taxIds,_that.taxNames,_that.qtyDelivered,_that.customerLead,_that.qtyInvoiced,_that.qtyToInvoice,_that.invoiceStatus,_that.orderState,_that.collapsePrices,_that.collapseComposition,_that.isOptional,_that.isSynced,_that.lastSyncDate,_that.writeDate,_that.isUnitProduct);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SaleOrderLine extends SaleOrderLine {
  const _SaleOrderLine({@OdooId() required this.id, @OdooLocalOnly() this.lineUuid, @OdooMany2One('sale.order', odooName: 'order_id') required this.orderId, @OdooInteger() this.sequence = 10, @OdooSelection(odooName: 'display_type') this.displayType = LineDisplayType.product, @OdooBoolean(odooName: 'is_downpayment') this.isDownpayment = false, @OdooMany2One('product.product', odooName: 'product_id') this.productId, @OdooMany2OneName(sourceField: 'product_id') this.productName, @OdooString(odooName: 'product_default_code') this.productCode, @OdooMany2One('product.template', odooName: 'product_template_id') this.productTemplateId, @OdooMany2OneName(sourceField: 'product_template_id') this.productTemplateName, @OdooString(odooName: 'product_type') this.productType, @OdooMany2One('product.category', odooName: 'categ_id') this.categId, @OdooMany2OneName(sourceField: 'categ_id') this.categName, @OdooString() required this.name, @OdooFloat(odooName: 'product_uom_qty') this.productUomQty = 1.0, @OdooMany2One('uom.uom', odooName: 'product_uom_id') this.productUomId, @OdooMany2OneName(sourceField: 'product_uom_id') this.productUomName, @OdooFloat(odooName: 'price_unit') this.priceUnit = 0.0, @OdooFloat() this.discount = 0.0, @OdooFloat(odooName: 'discount_amount') this.discountAmount = 0.0, @OdooFloat(odooName: 'price_subtotal') this.priceSubtotal = 0.0, @OdooFloat(odooName: 'price_tax') this.priceTax = 0.0, @OdooFloat(odooName: 'price_total') this.priceTotal = 0.0, @OdooFloat(odooName: 'price_reduce_taxexcl') this.priceReduce = 0.0, @OdooString(odooName: 'tax_ids') this.taxIds, @OdooLocalOnly() this.taxNames, @OdooFloat(odooName: 'qty_delivered') this.qtyDelivered = 0.0, @OdooFloat(odooName: 'customer_lead') this.customerLead = 0.0, @OdooFloat(odooName: 'qty_invoiced') this.qtyInvoiced = 0.0, @OdooFloat(odooName: 'qty_to_invoice') this.qtyToInvoice = 0.0, @OdooSelection(odooName: 'invoice_status') this.invoiceStatus = LineInvoiceStatus.no, @OdooString(odooName: 'state') this.orderState, @OdooBoolean(odooName: 'collapse_prices') this.collapsePrices = false, @OdooBoolean(odooName: 'collapse_composition') this.collapseComposition = false, @OdooBoolean(odooName: 'is_optional') this.isOptional = false, @OdooLocalOnly() this.isSynced = false, @OdooLocalOnly() this.lastSyncDate, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate, @OdooLocalOnly() this.isUnitProduct = true}): super._();
  factory _SaleOrderLine.fromJson(Map<String, dynamic> json) => _$SaleOrderLineFromJson(json);

@override@OdooId() final  int id;
@override@OdooLocalOnly() final  String? lineUuid;
// UUID local para sincronizacion offline-first
@override@OdooMany2One('sale.order', odooName: 'order_id') final  int orderId;
@override@JsonKey()@OdooInteger() final  int sequence;
// Tipo de linea
@override@JsonKey()@OdooSelection(odooName: 'display_type') final  LineDisplayType displayType;
@override@JsonKey()@OdooBoolean(odooName: 'is_downpayment') final  bool isDownpayment;
// Producto
@override@OdooMany2One('product.product', odooName: 'product_id') final  int? productId;
@override@OdooMany2OneName(sourceField: 'product_id') final  String? productName;
@override@OdooString(odooName: 'product_default_code') final  String? productCode;
// default_code del producto
@override@OdooMany2One('product.template', odooName: 'product_template_id') final  int? productTemplateId;
@override@OdooMany2OneName(sourceField: 'product_template_id') final  String? productTemplateName;
@override@OdooString(odooName: 'product_type') final  String? productType;
// 'consu', 'service', 'product'
@override@OdooMany2One('product.category', odooName: 'categ_id') final  int? categId;
@override@OdooMany2OneName(sourceField: 'categ_id') final  String? categName;
// Descripcion
@override@OdooString() final  String name;
// Descripcion de la linea
// Cantidad y UoM
@override@JsonKey()@OdooFloat(odooName: 'product_uom_qty') final  double productUomQty;
@override@OdooMany2One('uom.uom', odooName: 'product_uom_id') final  int? productUomId;
@override@OdooMany2OneName(sourceField: 'product_uom_id') final  String? productUomName;
// Precios
@override@JsonKey()@OdooFloat(odooName: 'price_unit') final  double priceUnit;
@override@JsonKey()@OdooFloat() final  double discount;
@override@JsonKey()@OdooFloat(odooName: 'discount_amount') final  double discountAmount;
// Monto de descuento (campo computado de Odoo)
@override@JsonKey()@OdooFloat(odooName: 'price_subtotal') final  double priceSubtotal;
@override@JsonKey()@OdooFloat(odooName: 'price_tax') final  double priceTax;
@override@JsonKey()@OdooFloat(odooName: 'price_total') final  double priceTotal;
@override@JsonKey()@OdooFloat(odooName: 'price_reduce_taxexcl') final  double priceReduce;
// Precio con descuento
// Impuestos (JSON array de IDs)
@override@OdooString(odooName: 'tax_ids') final  String? taxIds;
// Nombres de impuestos (para mostrar en UI)
@override@OdooLocalOnly() final  String? taxNames;
// Entrega
@override@JsonKey()@OdooFloat(odooName: 'qty_delivered') final  double qtyDelivered;
@override@JsonKey()@OdooFloat(odooName: 'customer_lead') final  double customerLead;
// Lead time en dias
// Facturacion
@override@JsonKey()@OdooFloat(odooName: 'qty_invoiced') final  double qtyInvoiced;
@override@JsonKey()@OdooFloat(odooName: 'qty_to_invoice') final  double qtyToInvoice;
@override@JsonKey()@OdooSelection(odooName: 'invoice_status') final  LineInvoiceStatus invoiceStatus;
// Estado de la orden (related)
@override@OdooString(odooName: 'state') final  String? orderState;
// Section settings (Odoo 19)
@override@JsonKey()@OdooBoolean(odooName: 'collapse_prices') final  bool collapsePrices;
// Ocultar precios de lineas en esta seccion
@override@JsonKey()@OdooBoolean(odooName: 'collapse_composition') final  bool collapseComposition;
// Ocultar lineas hijas (solo mostrar seccion)
@override@JsonKey()@OdooBoolean(odooName: 'is_optional') final  bool isOptional;
// Linea opcional (cliente puede elegir en portal)
// Sync
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
@override@OdooLocalOnly() final  DateTime? lastSyncDate;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;
// Product flags from catalog (for display purposes)
@override@JsonKey()@OdooLocalOnly() final  bool isUnitProduct;

/// Create a copy of SaleOrderLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SaleOrderLineCopyWith<_SaleOrderLine> get copyWith => __$SaleOrderLineCopyWithImpl<_SaleOrderLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SaleOrderLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SaleOrderLine&&(identical(other.id, id) || other.id == id)&&(identical(other.lineUuid, lineUuid) || other.lineUuid == lineUuid)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.displayType, displayType) || other.displayType == displayType)&&(identical(other.isDownpayment, isDownpayment) || other.isDownpayment == isDownpayment)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.productCode, productCode) || other.productCode == productCode)&&(identical(other.productTemplateId, productTemplateId) || other.productTemplateId == productTemplateId)&&(identical(other.productTemplateName, productTemplateName) || other.productTemplateName == productTemplateName)&&(identical(other.productType, productType) || other.productType == productType)&&(identical(other.categId, categId) || other.categId == categId)&&(identical(other.categName, categName) || other.categName == categName)&&(identical(other.name, name) || other.name == name)&&(identical(other.productUomQty, productUomQty) || other.productUomQty == productUomQty)&&(identical(other.productUomId, productUomId) || other.productUomId == productUomId)&&(identical(other.productUomName, productUomName) || other.productUomName == productUomName)&&(identical(other.priceUnit, priceUnit) || other.priceUnit == priceUnit)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.discountAmount, discountAmount) || other.discountAmount == discountAmount)&&(identical(other.priceSubtotal, priceSubtotal) || other.priceSubtotal == priceSubtotal)&&(identical(other.priceTax, priceTax) || other.priceTax == priceTax)&&(identical(other.priceTotal, priceTotal) || other.priceTotal == priceTotal)&&(identical(other.priceReduce, priceReduce) || other.priceReduce == priceReduce)&&(identical(other.taxIds, taxIds) || other.taxIds == taxIds)&&(identical(other.taxNames, taxNames) || other.taxNames == taxNames)&&(identical(other.qtyDelivered, qtyDelivered) || other.qtyDelivered == qtyDelivered)&&(identical(other.customerLead, customerLead) || other.customerLead == customerLead)&&(identical(other.qtyInvoiced, qtyInvoiced) || other.qtyInvoiced == qtyInvoiced)&&(identical(other.qtyToInvoice, qtyToInvoice) || other.qtyToInvoice == qtyToInvoice)&&(identical(other.invoiceStatus, invoiceStatus) || other.invoiceStatus == invoiceStatus)&&(identical(other.orderState, orderState) || other.orderState == orderState)&&(identical(other.collapsePrices, collapsePrices) || other.collapsePrices == collapsePrices)&&(identical(other.collapseComposition, collapseComposition) || other.collapseComposition == collapseComposition)&&(identical(other.isOptional, isOptional) || other.isOptional == isOptional)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.isUnitProduct, isUnitProduct) || other.isUnitProduct == isUnitProduct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,lineUuid,orderId,sequence,displayType,isDownpayment,productId,productName,productCode,productTemplateId,productTemplateName,productType,categId,categName,name,productUomQty,productUomId,productUomName,priceUnit,discount,discountAmount,priceSubtotal,priceTax,priceTotal,priceReduce,taxIds,taxNames,qtyDelivered,customerLead,qtyInvoiced,qtyToInvoice,invoiceStatus,orderState,collapsePrices,collapseComposition,isOptional,isSynced,lastSyncDate,writeDate,isUnitProduct]);

@override
String toString() {
  return 'SaleOrderLine(id: $id, lineUuid: $lineUuid, orderId: $orderId, sequence: $sequence, displayType: $displayType, isDownpayment: $isDownpayment, productId: $productId, productName: $productName, productCode: $productCode, productTemplateId: $productTemplateId, productTemplateName: $productTemplateName, productType: $productType, categId: $categId, categName: $categName, name: $name, productUomQty: $productUomQty, productUomId: $productUomId, productUomName: $productUomName, priceUnit: $priceUnit, discount: $discount, discountAmount: $discountAmount, priceSubtotal: $priceSubtotal, priceTax: $priceTax, priceTotal: $priceTotal, priceReduce: $priceReduce, taxIds: $taxIds, taxNames: $taxNames, qtyDelivered: $qtyDelivered, customerLead: $customerLead, qtyInvoiced: $qtyInvoiced, qtyToInvoice: $qtyToInvoice, invoiceStatus: $invoiceStatus, orderState: $orderState, collapsePrices: $collapsePrices, collapseComposition: $collapseComposition, isOptional: $isOptional, isSynced: $isSynced, lastSyncDate: $lastSyncDate, writeDate: $writeDate, isUnitProduct: $isUnitProduct)';
}


}

/// @nodoc
abstract mixin class _$SaleOrderLineCopyWith<$Res> implements $SaleOrderLineCopyWith<$Res> {
  factory _$SaleOrderLineCopyWith(_SaleOrderLine value, $Res Function(_SaleOrderLine) _then) = __$SaleOrderLineCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? lineUuid,@OdooMany2One('sale.order', odooName: 'order_id') int orderId,@OdooInteger() int sequence,@OdooSelection(odooName: 'display_type') LineDisplayType displayType,@OdooBoolean(odooName: 'is_downpayment') bool isDownpayment,@OdooMany2One('product.product', odooName: 'product_id') int? productId,@OdooMany2OneName(sourceField: 'product_id') String? productName,@OdooString(odooName: 'product_default_code') String? productCode,@OdooMany2One('product.template', odooName: 'product_template_id') int? productTemplateId,@OdooMany2OneName(sourceField: 'product_template_id') String? productTemplateName,@OdooString(odooName: 'product_type') String? productType,@OdooMany2One('product.category', odooName: 'categ_id') int? categId,@OdooMany2OneName(sourceField: 'categ_id') String? categName,@OdooString() String name,@OdooFloat(odooName: 'product_uom_qty') double productUomQty,@OdooMany2One('uom.uom', odooName: 'product_uom_id') int? productUomId,@OdooMany2OneName(sourceField: 'product_uom_id') String? productUomName,@OdooFloat(odooName: 'price_unit') double priceUnit,@OdooFloat() double discount,@OdooFloat(odooName: 'discount_amount') double discountAmount,@OdooFloat(odooName: 'price_subtotal') double priceSubtotal,@OdooFloat(odooName: 'price_tax') double priceTax,@OdooFloat(odooName: 'price_total') double priceTotal,@OdooFloat(odooName: 'price_reduce_taxexcl') double priceReduce,@OdooString(odooName: 'tax_ids') String? taxIds,@OdooLocalOnly() String? taxNames,@OdooFloat(odooName: 'qty_delivered') double qtyDelivered,@OdooFloat(odooName: 'customer_lead') double customerLead,@OdooFloat(odooName: 'qty_invoiced') double qtyInvoiced,@OdooFloat(odooName: 'qty_to_invoice') double qtyToInvoice,@OdooSelection(odooName: 'invoice_status') LineInvoiceStatus invoiceStatus,@OdooString(odooName: 'state') String? orderState,@OdooBoolean(odooName: 'collapse_prices') bool collapsePrices,@OdooBoolean(odooName: 'collapse_composition') bool collapseComposition,@OdooBoolean(odooName: 'is_optional') bool isOptional,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? lastSyncDate,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool isUnitProduct
});




}
/// @nodoc
class __$SaleOrderLineCopyWithImpl<$Res>
    implements _$SaleOrderLineCopyWith<$Res> {
  __$SaleOrderLineCopyWithImpl(this._self, this._then);

  final _SaleOrderLine _self;
  final $Res Function(_SaleOrderLine) _then;

/// Create a copy of SaleOrderLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? lineUuid = freezed,Object? orderId = null,Object? sequence = null,Object? displayType = null,Object? isDownpayment = null,Object? productId = freezed,Object? productName = freezed,Object? productCode = freezed,Object? productTemplateId = freezed,Object? productTemplateName = freezed,Object? productType = freezed,Object? categId = freezed,Object? categName = freezed,Object? name = null,Object? productUomQty = null,Object? productUomId = freezed,Object? productUomName = freezed,Object? priceUnit = null,Object? discount = null,Object? discountAmount = null,Object? priceSubtotal = null,Object? priceTax = null,Object? priceTotal = null,Object? priceReduce = null,Object? taxIds = freezed,Object? taxNames = freezed,Object? qtyDelivered = null,Object? customerLead = null,Object? qtyInvoiced = null,Object? qtyToInvoice = null,Object? invoiceStatus = null,Object? orderState = freezed,Object? collapsePrices = null,Object? collapseComposition = null,Object? isOptional = null,Object? isSynced = null,Object? lastSyncDate = freezed,Object? writeDate = freezed,Object? isUnitProduct = null,}) {
  return _then(_SaleOrderLine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,lineUuid: freezed == lineUuid ? _self.lineUuid : lineUuid // ignore: cast_nullable_to_non_nullable
as String?,orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as int,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,displayType: null == displayType ? _self.displayType : displayType // ignore: cast_nullable_to_non_nullable
as LineDisplayType,isDownpayment: null == isDownpayment ? _self.isDownpayment : isDownpayment // ignore: cast_nullable_to_non_nullable
as bool,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as int?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,productCode: freezed == productCode ? _self.productCode : productCode // ignore: cast_nullable_to_non_nullable
as String?,productTemplateId: freezed == productTemplateId ? _self.productTemplateId : productTemplateId // ignore: cast_nullable_to_non_nullable
as int?,productTemplateName: freezed == productTemplateName ? _self.productTemplateName : productTemplateName // ignore: cast_nullable_to_non_nullable
as String?,productType: freezed == productType ? _self.productType : productType // ignore: cast_nullable_to_non_nullable
as String?,categId: freezed == categId ? _self.categId : categId // ignore: cast_nullable_to_non_nullable
as int?,categName: freezed == categName ? _self.categName : categName // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,productUomQty: null == productUomQty ? _self.productUomQty : productUomQty // ignore: cast_nullable_to_non_nullable
as double,productUomId: freezed == productUomId ? _self.productUomId : productUomId // ignore: cast_nullable_to_non_nullable
as int?,productUomName: freezed == productUomName ? _self.productUomName : productUomName // ignore: cast_nullable_to_non_nullable
as String?,priceUnit: null == priceUnit ? _self.priceUnit : priceUnit // ignore: cast_nullable_to_non_nullable
as double,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as double,discountAmount: null == discountAmount ? _self.discountAmount : discountAmount // ignore: cast_nullable_to_non_nullable
as double,priceSubtotal: null == priceSubtotal ? _self.priceSubtotal : priceSubtotal // ignore: cast_nullable_to_non_nullable
as double,priceTax: null == priceTax ? _self.priceTax : priceTax // ignore: cast_nullable_to_non_nullable
as double,priceTotal: null == priceTotal ? _self.priceTotal : priceTotal // ignore: cast_nullable_to_non_nullable
as double,priceReduce: null == priceReduce ? _self.priceReduce : priceReduce // ignore: cast_nullable_to_non_nullable
as double,taxIds: freezed == taxIds ? _self.taxIds : taxIds // ignore: cast_nullable_to_non_nullable
as String?,taxNames: freezed == taxNames ? _self.taxNames : taxNames // ignore: cast_nullable_to_non_nullable
as String?,qtyDelivered: null == qtyDelivered ? _self.qtyDelivered : qtyDelivered // ignore: cast_nullable_to_non_nullable
as double,customerLead: null == customerLead ? _self.customerLead : customerLead // ignore: cast_nullable_to_non_nullable
as double,qtyInvoiced: null == qtyInvoiced ? _self.qtyInvoiced : qtyInvoiced // ignore: cast_nullable_to_non_nullable
as double,qtyToInvoice: null == qtyToInvoice ? _self.qtyToInvoice : qtyToInvoice // ignore: cast_nullable_to_non_nullable
as double,invoiceStatus: null == invoiceStatus ? _self.invoiceStatus : invoiceStatus // ignore: cast_nullable_to_non_nullable
as LineInvoiceStatus,orderState: freezed == orderState ? _self.orderState : orderState // ignore: cast_nullable_to_non_nullable
as String?,collapsePrices: null == collapsePrices ? _self.collapsePrices : collapsePrices // ignore: cast_nullable_to_non_nullable
as bool,collapseComposition: null == collapseComposition ? _self.collapseComposition : collapseComposition // ignore: cast_nullable_to_non_nullable
as bool,isOptional: null == isOptional ? _self.isOptional : isOptional // ignore: cast_nullable_to_non_nullable
as bool,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,isUnitProduct: null == isUnitProduct ? _self.isUnitProduct : isUnitProduct // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
