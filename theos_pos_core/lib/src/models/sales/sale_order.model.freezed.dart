// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sale_order.model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SaleOrder {

@OdooId() int get id;@OdooLocalOnly() String? get orderUuid;// UUID local para sincronizacion offline-first
@OdooString() String get name;// Referencia (SO001)
@OdooSelection() SaleOrderState get state;// Fechas
@OdooDateTime(odooName: 'date_order') DateTime? get dateOrder;@OdooDate(odooName: 'validity_date') DateTime? get validityDate;@OdooDateTime(odooName: 'commitment_date') DateTime? get commitmentDate;@OdooDateTime(odooName: 'expected_date') DateTime? get expectedDate;// Cliente y direcciones
@OdooMany2One('res.partner', odooName: 'partner_id') int? get partnerId;@OdooMany2OneName(sourceField: 'partner_id') String? get partnerName;@OdooString(odooName: 'partner_vat') String? get partnerVat;@OdooString(odooName: 'partner_street') String? get partnerStreet;@OdooString(odooName: 'partner_phone') String? get partnerPhone;@OdooString(odooName: 'partner_email') String? get partnerEmail;@OdooString(odooName: 'partner_avatar') String? get partnerAvatar;@OdooMany2One('res.partner', odooName: 'partner_invoice_id') int? get partnerInvoiceId;@OdooMany2OneName(sourceField: 'partner_invoice_id') String? get partnerInvoiceAddress;@OdooMany2One('res.partner', odooName: 'partner_shipping_id') int? get partnerShippingId;@OdooMany2OneName(sourceField: 'partner_shipping_id') String? get partnerShippingAddress;// Vendedor y equipo
@OdooMany2One('res.users', odooName: 'user_id') int? get userId;@OdooMany2OneName(sourceField: 'user_id') String? get userName;@OdooMany2One('crm.team', odooName: 'team_id') int? get teamId;@OdooMany2OneName(sourceField: 'team_id') String? get teamName;// Compania
@OdooMany2One('res.company', odooName: 'company_id') int? get companyId;@OdooMany2OneName(sourceField: 'company_id') String? get companyName;// Almacen (sale_stock)
@OdooMany2One('stock.warehouse', odooName: 'warehouse_id') int? get warehouseId;@OdooMany2OneName(sourceField: 'warehouse_id') String? get warehouseName;// Lista de precios y moneda
@OdooMany2One('product.pricelist', odooName: 'pricelist_id') int? get pricelistId;@OdooMany2OneName(sourceField: 'pricelist_id') String? get pricelistName;@OdooMany2One('res.currency', odooName: 'currency_id') int? get currencyId;@OdooString(odooName: 'currency_symbol') String? get currencySymbol;@OdooFloat(odooName: 'currency_rate') double get currencyRate;// Condiciones comerciales
@OdooMany2One('account.payment.term', odooName: 'payment_term_id') int? get paymentTermId;@OdooMany2OneName(sourceField: 'payment_term_id') String? get paymentTermName;// Payment type (synced from Odoo: payment_term_id.is_cash / is_credit)
/// True if payment term is cash/immediate payment
@OdooBoolean(odooName: 'is_cash') bool get isCash;/// True if payment term is credit (has payment days > 0)
@OdooBoolean(odooName: 'is_credit') bool get isCredit;@OdooMany2One('account.fiscal.position', odooName: 'fiscal_position_id') int? get fiscalPositionId;@OdooMany2OneName(sourceField: 'fiscal_position_id') String? get fiscalPositionName;// Montos
@OdooFloat(odooName: 'amount_untaxed') double get amountUntaxed;@OdooFloat(odooName: 'amount_tax') double get amountTax;@OdooFloat(odooName: 'amount_total') double get amountTotal;@OdooFloat(odooName: 'amount_to_invoice') double get amountToInvoice;@OdooFloat(odooName: 'amount_invoiced') double get amountInvoiced;// Estado de facturacion
@OdooSelection(odooName: 'invoice_status') InvoiceStatus get invoiceStatus;@OdooInteger(odooName: 'invoice_count') int get invoiceCount;// Notas y referencias
@OdooString(odooName: 'note') String? get note;@OdooString(odooName: 'client_order_ref') String? get clientOrderRef;// Firma digital
@OdooBoolean(odooName: 'require_signature') bool get requireSignature;@OdooString(odooName: 'signature') String? get signature;@OdooString(odooName: 'signed_by') String? get signedBy;@OdooDateTime(odooName: 'signed_on') DateTime? get signedOn;// Pago online
@OdooBoolean(odooName: 'require_payment') bool get requirePayment;@OdooFloat(odooName: 'prepayment_percent') double get prepaymentPercent;// Control
@OdooBoolean(odooName: 'locked') bool get locked;@OdooBoolean(odooName: 'is_expired') bool get isExpired;// Descuentos (l10n_ec_sale_discount)
@OdooFloat(odooName: 'total_discount_amount') double get totalDiscountAmount;@OdooFloat(odooName: 'total_amount_undiscounted') double get amountUntaxedUndiscounted;// Consumidor Final (l10n_ec_sale_base)
@OdooBoolean(odooName: 'is_final_consumer') bool get isFinalConsumer;@OdooString(odooName: 'end_customer_name') String? get endCustomerName;@OdooString(odooName: 'end_customer_phone') String? get endCustomerPhone;@OdooString(odooName: 'end_customer_email') String? get endCustomerEmail;@OdooBoolean(odooName: 'exceeds_final_consumer_limit') bool get exceedsFinalConsumerLimit;// Facturacion postfechada (l10n_ec_sale_base)
@OdooBoolean(odooName: 'emitir_factura_fecha_posterior') bool get emitirFacturaFechaPosterior;@OdooDate(odooName: 'fecha_facturar') DateTime? get fechaFacturar;// Referidor (l10n_ec_sale_base)
@OdooMany2One('res.partner', odooName: 'referrer_id') int? get referrerId;@OdooMany2OneName(sourceField: 'referrer_id') String? get referrerName;// Tipo y Canal de cliente (l10n_ec_sale_base)
@OdooString(odooName: 'tipo_cliente') String? get tipoCliente;@OdooString(odooName: 'canal_cliente') String? get canalCliente;// Entregas/Picking (sale_stock)
@OdooMany2Many('stock.picking', odooName: 'picking_ids') List<int> get pickingIds;@OdooString(odooName: 'delivery_status') String? get deliveryStatus;// Tax totals JSON para desglose de impuestos
@OdooJson(odooName: 'tax_totals') Map<String, dynamic>? get taxTotals;// Credit Control (l10n_ec_sale_credit)
@OdooBoolean(odooName: 'credit_exceeded') bool get creditExceeded;@OdooBoolean(odooName: 'credit_check_bypassed') bool get creditCheckBypassed;// Additional Amounts
@OdooFloat(odooName: 'amount_cash') double get amountCash;@OdooFloat(odooName: 'amount_unpaid') double get amountUnpaid;@OdooFloat(odooName: 'total_cost_amount') double get totalCostAmount;@OdooFloat(odooName: 'margin') double get margin;@OdooFloat(odooName: 'margin_percent') double get marginPercent;@OdooFloat(odooName: 'retenido_amount') double get retenidoAmount;// Approvals (l10n_ec_sale_credit)
@OdooInteger(odooName: 'approval_count') int get approvalCount;@OdooDateTime(odooName: 'approved_date') DateTime? get approvedDate;@OdooDateTime(odooName: 'rejected_date') DateTime? get rejectedDate;@OdooString(odooName: 'rejected_reason') String? get rejectedReason;// Collection Session (l10n_ec_collection_box)
@OdooMany2One('collection.session', odooName: 'collection_session_id') int? get collectionSessionId;@OdooMany2One('res.users', odooName: 'collection_user_id') int? get collectionUserId;@OdooMany2One('res.users', odooName: 'sale_created_user_id') int? get saleCreatedUserId;// Dispatch Control (l10n_ec_sale_base)
@OdooBoolean(odooName: 'entregar_solo_pagado') bool get entregarSoloPagado;@OdooBoolean(odooName: 'es_para_despacho') bool get esParaDespacho;@OdooString(odooName: 'nota_adicional') String? get notaAdicional;// UUID for offline sync (l10n_ec_collection_box_pos)
@OdooString(odooName: 'x_uuid') String? get xUuid;// Sync
@OdooLocalOnly() bool get isSynced;@OdooLocalOnly() DateTime? get lastSyncDate;@OdooLocalOnly() int get syncRetryCount;@OdooLocalOnly() DateTime? get lastSyncAttempt;@OdooDateTime(odooName: 'write_date', writable: false) DateTime? get writeDate;/// Indicates invoice creation was queued offline - prevents modifying payments/withholds
@OdooLocalOnly() bool get hasQueuedInvoice;
/// Create a copy of SaleOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SaleOrderCopyWith<SaleOrder> get copyWith => _$SaleOrderCopyWithImpl<SaleOrder>(this as SaleOrder, _$identity);

  /// Serializes this SaleOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SaleOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.orderUuid, orderUuid) || other.orderUuid == orderUuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.state, state) || other.state == state)&&(identical(other.dateOrder, dateOrder) || other.dateOrder == dateOrder)&&(identical(other.validityDate, validityDate) || other.validityDate == validityDate)&&(identical(other.commitmentDate, commitmentDate) || other.commitmentDate == commitmentDate)&&(identical(other.expectedDate, expectedDate) || other.expectedDate == expectedDate)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.partnerVat, partnerVat) || other.partnerVat == partnerVat)&&(identical(other.partnerStreet, partnerStreet) || other.partnerStreet == partnerStreet)&&(identical(other.partnerPhone, partnerPhone) || other.partnerPhone == partnerPhone)&&(identical(other.partnerEmail, partnerEmail) || other.partnerEmail == partnerEmail)&&(identical(other.partnerAvatar, partnerAvatar) || other.partnerAvatar == partnerAvatar)&&(identical(other.partnerInvoiceId, partnerInvoiceId) || other.partnerInvoiceId == partnerInvoiceId)&&(identical(other.partnerInvoiceAddress, partnerInvoiceAddress) || other.partnerInvoiceAddress == partnerInvoiceAddress)&&(identical(other.partnerShippingId, partnerShippingId) || other.partnerShippingId == partnerShippingId)&&(identical(other.partnerShippingAddress, partnerShippingAddress) || other.partnerShippingAddress == partnerShippingAddress)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.teamId, teamId) || other.teamId == teamId)&&(identical(other.teamName, teamName) || other.teamName == teamName)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.warehouseId, warehouseId) || other.warehouseId == warehouseId)&&(identical(other.warehouseName, warehouseName) || other.warehouseName == warehouseName)&&(identical(other.pricelistId, pricelistId) || other.pricelistId == pricelistId)&&(identical(other.pricelistName, pricelistName) || other.pricelistName == pricelistName)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.currencySymbol, currencySymbol) || other.currencySymbol == currencySymbol)&&(identical(other.currencyRate, currencyRate) || other.currencyRate == currencyRate)&&(identical(other.paymentTermId, paymentTermId) || other.paymentTermId == paymentTermId)&&(identical(other.paymentTermName, paymentTermName) || other.paymentTermName == paymentTermName)&&(identical(other.isCash, isCash) || other.isCash == isCash)&&(identical(other.isCredit, isCredit) || other.isCredit == isCredit)&&(identical(other.fiscalPositionId, fiscalPositionId) || other.fiscalPositionId == fiscalPositionId)&&(identical(other.fiscalPositionName, fiscalPositionName) || other.fiscalPositionName == fiscalPositionName)&&(identical(other.amountUntaxed, amountUntaxed) || other.amountUntaxed == amountUntaxed)&&(identical(other.amountTax, amountTax) || other.amountTax == amountTax)&&(identical(other.amountTotal, amountTotal) || other.amountTotal == amountTotal)&&(identical(other.amountToInvoice, amountToInvoice) || other.amountToInvoice == amountToInvoice)&&(identical(other.amountInvoiced, amountInvoiced) || other.amountInvoiced == amountInvoiced)&&(identical(other.invoiceStatus, invoiceStatus) || other.invoiceStatus == invoiceStatus)&&(identical(other.invoiceCount, invoiceCount) || other.invoiceCount == invoiceCount)&&(identical(other.note, note) || other.note == note)&&(identical(other.clientOrderRef, clientOrderRef) || other.clientOrderRef == clientOrderRef)&&(identical(other.requireSignature, requireSignature) || other.requireSignature == requireSignature)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.signedBy, signedBy) || other.signedBy == signedBy)&&(identical(other.signedOn, signedOn) || other.signedOn == signedOn)&&(identical(other.requirePayment, requirePayment) || other.requirePayment == requirePayment)&&(identical(other.prepaymentPercent, prepaymentPercent) || other.prepaymentPercent == prepaymentPercent)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.isExpired, isExpired) || other.isExpired == isExpired)&&(identical(other.totalDiscountAmount, totalDiscountAmount) || other.totalDiscountAmount == totalDiscountAmount)&&(identical(other.amountUntaxedUndiscounted, amountUntaxedUndiscounted) || other.amountUntaxedUndiscounted == amountUntaxedUndiscounted)&&(identical(other.isFinalConsumer, isFinalConsumer) || other.isFinalConsumer == isFinalConsumer)&&(identical(other.endCustomerName, endCustomerName) || other.endCustomerName == endCustomerName)&&(identical(other.endCustomerPhone, endCustomerPhone) || other.endCustomerPhone == endCustomerPhone)&&(identical(other.endCustomerEmail, endCustomerEmail) || other.endCustomerEmail == endCustomerEmail)&&(identical(other.exceedsFinalConsumerLimit, exceedsFinalConsumerLimit) || other.exceedsFinalConsumerLimit == exceedsFinalConsumerLimit)&&(identical(other.emitirFacturaFechaPosterior, emitirFacturaFechaPosterior) || other.emitirFacturaFechaPosterior == emitirFacturaFechaPosterior)&&(identical(other.fechaFacturar, fechaFacturar) || other.fechaFacturar == fechaFacturar)&&(identical(other.referrerId, referrerId) || other.referrerId == referrerId)&&(identical(other.referrerName, referrerName) || other.referrerName == referrerName)&&(identical(other.tipoCliente, tipoCliente) || other.tipoCliente == tipoCliente)&&(identical(other.canalCliente, canalCliente) || other.canalCliente == canalCliente)&&const DeepCollectionEquality().equals(other.pickingIds, pickingIds)&&(identical(other.deliveryStatus, deliveryStatus) || other.deliveryStatus == deliveryStatus)&&const DeepCollectionEquality().equals(other.taxTotals, taxTotals)&&(identical(other.creditExceeded, creditExceeded) || other.creditExceeded == creditExceeded)&&(identical(other.creditCheckBypassed, creditCheckBypassed) || other.creditCheckBypassed == creditCheckBypassed)&&(identical(other.amountCash, amountCash) || other.amountCash == amountCash)&&(identical(other.amountUnpaid, amountUnpaid) || other.amountUnpaid == amountUnpaid)&&(identical(other.totalCostAmount, totalCostAmount) || other.totalCostAmount == totalCostAmount)&&(identical(other.margin, margin) || other.margin == margin)&&(identical(other.marginPercent, marginPercent) || other.marginPercent == marginPercent)&&(identical(other.retenidoAmount, retenidoAmount) || other.retenidoAmount == retenidoAmount)&&(identical(other.approvalCount, approvalCount) || other.approvalCount == approvalCount)&&(identical(other.approvedDate, approvedDate) || other.approvedDate == approvedDate)&&(identical(other.rejectedDate, rejectedDate) || other.rejectedDate == rejectedDate)&&(identical(other.rejectedReason, rejectedReason) || other.rejectedReason == rejectedReason)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.collectionUserId, collectionUserId) || other.collectionUserId == collectionUserId)&&(identical(other.saleCreatedUserId, saleCreatedUserId) || other.saleCreatedUserId == saleCreatedUserId)&&(identical(other.entregarSoloPagado, entregarSoloPagado) || other.entregarSoloPagado == entregarSoloPagado)&&(identical(other.esParaDespacho, esParaDespacho) || other.esParaDespacho == esParaDespacho)&&(identical(other.notaAdicional, notaAdicional) || other.notaAdicional == notaAdicional)&&(identical(other.xUuid, xUuid) || other.xUuid == xUuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.syncRetryCount, syncRetryCount) || other.syncRetryCount == syncRetryCount)&&(identical(other.lastSyncAttempt, lastSyncAttempt) || other.lastSyncAttempt == lastSyncAttempt)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.hasQueuedInvoice, hasQueuedInvoice) || other.hasQueuedInvoice == hasQueuedInvoice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,orderUuid,name,state,dateOrder,validityDate,commitmentDate,expectedDate,partnerId,partnerName,partnerVat,partnerStreet,partnerPhone,partnerEmail,partnerAvatar,partnerInvoiceId,partnerInvoiceAddress,partnerShippingId,partnerShippingAddress,userId,userName,teamId,teamName,companyId,companyName,warehouseId,warehouseName,pricelistId,pricelistName,currencyId,currencySymbol,currencyRate,paymentTermId,paymentTermName,isCash,isCredit,fiscalPositionId,fiscalPositionName,amountUntaxed,amountTax,amountTotal,amountToInvoice,amountInvoiced,invoiceStatus,invoiceCount,note,clientOrderRef,requireSignature,signature,signedBy,signedOn,requirePayment,prepaymentPercent,locked,isExpired,totalDiscountAmount,amountUntaxedUndiscounted,isFinalConsumer,endCustomerName,endCustomerPhone,endCustomerEmail,exceedsFinalConsumerLimit,emitirFacturaFechaPosterior,fechaFacturar,referrerId,referrerName,tipoCliente,canalCliente,const DeepCollectionEquality().hash(pickingIds),deliveryStatus,const DeepCollectionEquality().hash(taxTotals),creditExceeded,creditCheckBypassed,amountCash,amountUnpaid,totalCostAmount,margin,marginPercent,retenidoAmount,approvalCount,approvedDate,rejectedDate,rejectedReason,collectionSessionId,collectionUserId,saleCreatedUserId,entregarSoloPagado,esParaDespacho,notaAdicional,xUuid,isSynced,lastSyncDate,syncRetryCount,lastSyncAttempt,writeDate,hasQueuedInvoice]);

@override
String toString() {
  return 'SaleOrder(id: $id, orderUuid: $orderUuid, name: $name, state: $state, dateOrder: $dateOrder, validityDate: $validityDate, commitmentDate: $commitmentDate, expectedDate: $expectedDate, partnerId: $partnerId, partnerName: $partnerName, partnerVat: $partnerVat, partnerStreet: $partnerStreet, partnerPhone: $partnerPhone, partnerEmail: $partnerEmail, partnerAvatar: $partnerAvatar, partnerInvoiceId: $partnerInvoiceId, partnerInvoiceAddress: $partnerInvoiceAddress, partnerShippingId: $partnerShippingId, partnerShippingAddress: $partnerShippingAddress, userId: $userId, userName: $userName, teamId: $teamId, teamName: $teamName, companyId: $companyId, companyName: $companyName, warehouseId: $warehouseId, warehouseName: $warehouseName, pricelistId: $pricelistId, pricelistName: $pricelistName, currencyId: $currencyId, currencySymbol: $currencySymbol, currencyRate: $currencyRate, paymentTermId: $paymentTermId, paymentTermName: $paymentTermName, isCash: $isCash, isCredit: $isCredit, fiscalPositionId: $fiscalPositionId, fiscalPositionName: $fiscalPositionName, amountUntaxed: $amountUntaxed, amountTax: $amountTax, amountTotal: $amountTotal, amountToInvoice: $amountToInvoice, amountInvoiced: $amountInvoiced, invoiceStatus: $invoiceStatus, invoiceCount: $invoiceCount, note: $note, clientOrderRef: $clientOrderRef, requireSignature: $requireSignature, signature: $signature, signedBy: $signedBy, signedOn: $signedOn, requirePayment: $requirePayment, prepaymentPercent: $prepaymentPercent, locked: $locked, isExpired: $isExpired, totalDiscountAmount: $totalDiscountAmount, amountUntaxedUndiscounted: $amountUntaxedUndiscounted, isFinalConsumer: $isFinalConsumer, endCustomerName: $endCustomerName, endCustomerPhone: $endCustomerPhone, endCustomerEmail: $endCustomerEmail, exceedsFinalConsumerLimit: $exceedsFinalConsumerLimit, emitirFacturaFechaPosterior: $emitirFacturaFechaPosterior, fechaFacturar: $fechaFacturar, referrerId: $referrerId, referrerName: $referrerName, tipoCliente: $tipoCliente, canalCliente: $canalCliente, pickingIds: $pickingIds, deliveryStatus: $deliveryStatus, taxTotals: $taxTotals, creditExceeded: $creditExceeded, creditCheckBypassed: $creditCheckBypassed, amountCash: $amountCash, amountUnpaid: $amountUnpaid, totalCostAmount: $totalCostAmount, margin: $margin, marginPercent: $marginPercent, retenidoAmount: $retenidoAmount, approvalCount: $approvalCount, approvedDate: $approvedDate, rejectedDate: $rejectedDate, rejectedReason: $rejectedReason, collectionSessionId: $collectionSessionId, collectionUserId: $collectionUserId, saleCreatedUserId: $saleCreatedUserId, entregarSoloPagado: $entregarSoloPagado, esParaDespacho: $esParaDespacho, notaAdicional: $notaAdicional, xUuid: $xUuid, isSynced: $isSynced, lastSyncDate: $lastSyncDate, syncRetryCount: $syncRetryCount, lastSyncAttempt: $lastSyncAttempt, writeDate: $writeDate, hasQueuedInvoice: $hasQueuedInvoice)';
}


}

/// @nodoc
abstract mixin class $SaleOrderCopyWith<$Res>  {
  factory $SaleOrderCopyWith(SaleOrder value, $Res Function(SaleOrder) _then) = _$SaleOrderCopyWithImpl;
@useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? orderUuid,@OdooString() String name,@OdooSelection() SaleOrderState state,@OdooDateTime(odooName: 'date_order') DateTime? dateOrder,@OdooDate(odooName: 'validity_date') DateTime? validityDate,@OdooDateTime(odooName: 'commitment_date') DateTime? commitmentDate,@OdooDateTime(odooName: 'expected_date') DateTime? expectedDate,@OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooString(odooName: 'partner_vat') String? partnerVat,@OdooString(odooName: 'partner_street') String? partnerStreet,@OdooString(odooName: 'partner_phone') String? partnerPhone,@OdooString(odooName: 'partner_email') String? partnerEmail,@OdooString(odooName: 'partner_avatar') String? partnerAvatar,@OdooMany2One('res.partner', odooName: 'partner_invoice_id') int? partnerInvoiceId,@OdooMany2OneName(sourceField: 'partner_invoice_id') String? partnerInvoiceAddress,@OdooMany2One('res.partner', odooName: 'partner_shipping_id') int? partnerShippingId,@OdooMany2OneName(sourceField: 'partner_shipping_id') String? partnerShippingAddress,@OdooMany2One('res.users', odooName: 'user_id') int? userId,@OdooMany2OneName(sourceField: 'user_id') String? userName,@OdooMany2One('crm.team', odooName: 'team_id') int? teamId,@OdooMany2OneName(sourceField: 'team_id') String? teamName,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooMany2One('stock.warehouse', odooName: 'warehouse_id') int? warehouseId,@OdooMany2OneName(sourceField: 'warehouse_id') String? warehouseName,@OdooMany2One('product.pricelist', odooName: 'pricelist_id') int? pricelistId,@OdooMany2OneName(sourceField: 'pricelist_id') String? pricelistName,@OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,@OdooString(odooName: 'currency_symbol') String? currencySymbol,@OdooFloat(odooName: 'currency_rate') double currencyRate,@OdooMany2One('account.payment.term', odooName: 'payment_term_id') int? paymentTermId,@OdooMany2OneName(sourceField: 'payment_term_id') String? paymentTermName,@OdooBoolean(odooName: 'is_cash') bool isCash,@OdooBoolean(odooName: 'is_credit') bool isCredit,@OdooMany2One('account.fiscal.position', odooName: 'fiscal_position_id') int? fiscalPositionId,@OdooMany2OneName(sourceField: 'fiscal_position_id') String? fiscalPositionName,@OdooFloat(odooName: 'amount_untaxed') double amountUntaxed,@OdooFloat(odooName: 'amount_tax') double amountTax,@OdooFloat(odooName: 'amount_total') double amountTotal,@OdooFloat(odooName: 'amount_to_invoice') double amountToInvoice,@OdooFloat(odooName: 'amount_invoiced') double amountInvoiced,@OdooSelection(odooName: 'invoice_status') InvoiceStatus invoiceStatus,@OdooInteger(odooName: 'invoice_count') int invoiceCount,@OdooString(odooName: 'note') String? note,@OdooString(odooName: 'client_order_ref') String? clientOrderRef,@OdooBoolean(odooName: 'require_signature') bool requireSignature,@OdooString(odooName: 'signature') String? signature,@OdooString(odooName: 'signed_by') String? signedBy,@OdooDateTime(odooName: 'signed_on') DateTime? signedOn,@OdooBoolean(odooName: 'require_payment') bool requirePayment,@OdooFloat(odooName: 'prepayment_percent') double prepaymentPercent,@OdooBoolean(odooName: 'locked') bool locked,@OdooBoolean(odooName: 'is_expired') bool isExpired,@OdooFloat(odooName: 'total_discount_amount') double totalDiscountAmount,@OdooFloat(odooName: 'total_amount_undiscounted') double amountUntaxedUndiscounted,@OdooBoolean(odooName: 'is_final_consumer') bool isFinalConsumer,@OdooString(odooName: 'end_customer_name') String? endCustomerName,@OdooString(odooName: 'end_customer_phone') String? endCustomerPhone,@OdooString(odooName: 'end_customer_email') String? endCustomerEmail,@OdooBoolean(odooName: 'exceeds_final_consumer_limit') bool exceedsFinalConsumerLimit,@OdooBoolean(odooName: 'emitir_factura_fecha_posterior') bool emitirFacturaFechaPosterior,@OdooDate(odooName: 'fecha_facturar') DateTime? fechaFacturar,@OdooMany2One('res.partner', odooName: 'referrer_id') int? referrerId,@OdooMany2OneName(sourceField: 'referrer_id') String? referrerName,@OdooString(odooName: 'tipo_cliente') String? tipoCliente,@OdooString(odooName: 'canal_cliente') String? canalCliente,@OdooMany2Many('stock.picking', odooName: 'picking_ids') List<int> pickingIds,@OdooString(odooName: 'delivery_status') String? deliveryStatus,@OdooJson(odooName: 'tax_totals') Map<String, dynamic>? taxTotals,@OdooBoolean(odooName: 'credit_exceeded') bool creditExceeded,@OdooBoolean(odooName: 'credit_check_bypassed') bool creditCheckBypassed,@OdooFloat(odooName: 'amount_cash') double amountCash,@OdooFloat(odooName: 'amount_unpaid') double amountUnpaid,@OdooFloat(odooName: 'total_cost_amount') double totalCostAmount,@OdooFloat(odooName: 'margin') double margin,@OdooFloat(odooName: 'margin_percent') double marginPercent,@OdooFloat(odooName: 'retenido_amount') double retenidoAmount,@OdooInteger(odooName: 'approval_count') int approvalCount,@OdooDateTime(odooName: 'approved_date') DateTime? approvedDate,@OdooDateTime(odooName: 'rejected_date') DateTime? rejectedDate,@OdooString(odooName: 'rejected_reason') String? rejectedReason,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooMany2One('res.users', odooName: 'collection_user_id') int? collectionUserId,@OdooMany2One('res.users', odooName: 'sale_created_user_id') int? saleCreatedUserId,@OdooBoolean(odooName: 'entregar_solo_pagado') bool entregarSoloPagado,@OdooBoolean(odooName: 'es_para_despacho') bool esParaDespacho,@OdooString(odooName: 'nota_adicional') String? notaAdicional,@OdooString(odooName: 'x_uuid') String? xUuid,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? lastSyncDate,@OdooLocalOnly() int syncRetryCount,@OdooLocalOnly() DateTime? lastSyncAttempt,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool hasQueuedInvoice
});




}
/// @nodoc
class _$SaleOrderCopyWithImpl<$Res>
    implements $SaleOrderCopyWith<$Res> {
  _$SaleOrderCopyWithImpl(this._self, this._then);

  final SaleOrder _self;
  final $Res Function(SaleOrder) _then;

/// Create a copy of SaleOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? orderUuid = freezed,Object? name = null,Object? state = null,Object? dateOrder = freezed,Object? validityDate = freezed,Object? commitmentDate = freezed,Object? expectedDate = freezed,Object? partnerId = freezed,Object? partnerName = freezed,Object? partnerVat = freezed,Object? partnerStreet = freezed,Object? partnerPhone = freezed,Object? partnerEmail = freezed,Object? partnerAvatar = freezed,Object? partnerInvoiceId = freezed,Object? partnerInvoiceAddress = freezed,Object? partnerShippingId = freezed,Object? partnerShippingAddress = freezed,Object? userId = freezed,Object? userName = freezed,Object? teamId = freezed,Object? teamName = freezed,Object? companyId = freezed,Object? companyName = freezed,Object? warehouseId = freezed,Object? warehouseName = freezed,Object? pricelistId = freezed,Object? pricelistName = freezed,Object? currencyId = freezed,Object? currencySymbol = freezed,Object? currencyRate = null,Object? paymentTermId = freezed,Object? paymentTermName = freezed,Object? isCash = null,Object? isCredit = null,Object? fiscalPositionId = freezed,Object? fiscalPositionName = freezed,Object? amountUntaxed = null,Object? amountTax = null,Object? amountTotal = null,Object? amountToInvoice = null,Object? amountInvoiced = null,Object? invoiceStatus = null,Object? invoiceCount = null,Object? note = freezed,Object? clientOrderRef = freezed,Object? requireSignature = null,Object? signature = freezed,Object? signedBy = freezed,Object? signedOn = freezed,Object? requirePayment = null,Object? prepaymentPercent = null,Object? locked = null,Object? isExpired = null,Object? totalDiscountAmount = null,Object? amountUntaxedUndiscounted = null,Object? isFinalConsumer = null,Object? endCustomerName = freezed,Object? endCustomerPhone = freezed,Object? endCustomerEmail = freezed,Object? exceedsFinalConsumerLimit = null,Object? emitirFacturaFechaPosterior = null,Object? fechaFacturar = freezed,Object? referrerId = freezed,Object? referrerName = freezed,Object? tipoCliente = freezed,Object? canalCliente = freezed,Object? pickingIds = null,Object? deliveryStatus = freezed,Object? taxTotals = freezed,Object? creditExceeded = null,Object? creditCheckBypassed = null,Object? amountCash = null,Object? amountUnpaid = null,Object? totalCostAmount = null,Object? margin = null,Object? marginPercent = null,Object? retenidoAmount = null,Object? approvalCount = null,Object? approvedDate = freezed,Object? rejectedDate = freezed,Object? rejectedReason = freezed,Object? collectionSessionId = freezed,Object? collectionUserId = freezed,Object? saleCreatedUserId = freezed,Object? entregarSoloPagado = null,Object? esParaDespacho = null,Object? notaAdicional = freezed,Object? xUuid = freezed,Object? isSynced = null,Object? lastSyncDate = freezed,Object? syncRetryCount = null,Object? lastSyncAttempt = freezed,Object? writeDate = freezed,Object? hasQueuedInvoice = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderUuid: freezed == orderUuid ? _self.orderUuid : orderUuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as SaleOrderState,dateOrder: freezed == dateOrder ? _self.dateOrder : dateOrder // ignore: cast_nullable_to_non_nullable
as DateTime?,validityDate: freezed == validityDate ? _self.validityDate : validityDate // ignore: cast_nullable_to_non_nullable
as DateTime?,commitmentDate: freezed == commitmentDate ? _self.commitmentDate : commitmentDate // ignore: cast_nullable_to_non_nullable
as DateTime?,expectedDate: freezed == expectedDate ? _self.expectedDate : expectedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,partnerId: freezed == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int?,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,partnerVat: freezed == partnerVat ? _self.partnerVat : partnerVat // ignore: cast_nullable_to_non_nullable
as String?,partnerStreet: freezed == partnerStreet ? _self.partnerStreet : partnerStreet // ignore: cast_nullable_to_non_nullable
as String?,partnerPhone: freezed == partnerPhone ? _self.partnerPhone : partnerPhone // ignore: cast_nullable_to_non_nullable
as String?,partnerEmail: freezed == partnerEmail ? _self.partnerEmail : partnerEmail // ignore: cast_nullable_to_non_nullable
as String?,partnerAvatar: freezed == partnerAvatar ? _self.partnerAvatar : partnerAvatar // ignore: cast_nullable_to_non_nullable
as String?,partnerInvoiceId: freezed == partnerInvoiceId ? _self.partnerInvoiceId : partnerInvoiceId // ignore: cast_nullable_to_non_nullable
as int?,partnerInvoiceAddress: freezed == partnerInvoiceAddress ? _self.partnerInvoiceAddress : partnerInvoiceAddress // ignore: cast_nullable_to_non_nullable
as String?,partnerShippingId: freezed == partnerShippingId ? _self.partnerShippingId : partnerShippingId // ignore: cast_nullable_to_non_nullable
as int?,partnerShippingAddress: freezed == partnerShippingAddress ? _self.partnerShippingAddress : partnerShippingAddress // ignore: cast_nullable_to_non_nullable
as String?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,teamId: freezed == teamId ? _self.teamId : teamId // ignore: cast_nullable_to_non_nullable
as int?,teamName: freezed == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String?,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,warehouseId: freezed == warehouseId ? _self.warehouseId : warehouseId // ignore: cast_nullable_to_non_nullable
as int?,warehouseName: freezed == warehouseName ? _self.warehouseName : warehouseName // ignore: cast_nullable_to_non_nullable
as String?,pricelistId: freezed == pricelistId ? _self.pricelistId : pricelistId // ignore: cast_nullable_to_non_nullable
as int?,pricelistName: freezed == pricelistName ? _self.pricelistName : pricelistName // ignore: cast_nullable_to_non_nullable
as String?,currencyId: freezed == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as int?,currencySymbol: freezed == currencySymbol ? _self.currencySymbol : currencySymbol // ignore: cast_nullable_to_non_nullable
as String?,currencyRate: null == currencyRate ? _self.currencyRate : currencyRate // ignore: cast_nullable_to_non_nullable
as double,paymentTermId: freezed == paymentTermId ? _self.paymentTermId : paymentTermId // ignore: cast_nullable_to_non_nullable
as int?,paymentTermName: freezed == paymentTermName ? _self.paymentTermName : paymentTermName // ignore: cast_nullable_to_non_nullable
as String?,isCash: null == isCash ? _self.isCash : isCash // ignore: cast_nullable_to_non_nullable
as bool,isCredit: null == isCredit ? _self.isCredit : isCredit // ignore: cast_nullable_to_non_nullable
as bool,fiscalPositionId: freezed == fiscalPositionId ? _self.fiscalPositionId : fiscalPositionId // ignore: cast_nullable_to_non_nullable
as int?,fiscalPositionName: freezed == fiscalPositionName ? _self.fiscalPositionName : fiscalPositionName // ignore: cast_nullable_to_non_nullable
as String?,amountUntaxed: null == amountUntaxed ? _self.amountUntaxed : amountUntaxed // ignore: cast_nullable_to_non_nullable
as double,amountTax: null == amountTax ? _self.amountTax : amountTax // ignore: cast_nullable_to_non_nullable
as double,amountTotal: null == amountTotal ? _self.amountTotal : amountTotal // ignore: cast_nullable_to_non_nullable
as double,amountToInvoice: null == amountToInvoice ? _self.amountToInvoice : amountToInvoice // ignore: cast_nullable_to_non_nullable
as double,amountInvoiced: null == amountInvoiced ? _self.amountInvoiced : amountInvoiced // ignore: cast_nullable_to_non_nullable
as double,invoiceStatus: null == invoiceStatus ? _self.invoiceStatus : invoiceStatus // ignore: cast_nullable_to_non_nullable
as InvoiceStatus,invoiceCount: null == invoiceCount ? _self.invoiceCount : invoiceCount // ignore: cast_nullable_to_non_nullable
as int,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,clientOrderRef: freezed == clientOrderRef ? _self.clientOrderRef : clientOrderRef // ignore: cast_nullable_to_non_nullable
as String?,requireSignature: null == requireSignature ? _self.requireSignature : requireSignature // ignore: cast_nullable_to_non_nullable
as bool,signature: freezed == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String?,signedBy: freezed == signedBy ? _self.signedBy : signedBy // ignore: cast_nullable_to_non_nullable
as String?,signedOn: freezed == signedOn ? _self.signedOn : signedOn // ignore: cast_nullable_to_non_nullable
as DateTime?,requirePayment: null == requirePayment ? _self.requirePayment : requirePayment // ignore: cast_nullable_to_non_nullable
as bool,prepaymentPercent: null == prepaymentPercent ? _self.prepaymentPercent : prepaymentPercent // ignore: cast_nullable_to_non_nullable
as double,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,isExpired: null == isExpired ? _self.isExpired : isExpired // ignore: cast_nullable_to_non_nullable
as bool,totalDiscountAmount: null == totalDiscountAmount ? _self.totalDiscountAmount : totalDiscountAmount // ignore: cast_nullable_to_non_nullable
as double,amountUntaxedUndiscounted: null == amountUntaxedUndiscounted ? _self.amountUntaxedUndiscounted : amountUntaxedUndiscounted // ignore: cast_nullable_to_non_nullable
as double,isFinalConsumer: null == isFinalConsumer ? _self.isFinalConsumer : isFinalConsumer // ignore: cast_nullable_to_non_nullable
as bool,endCustomerName: freezed == endCustomerName ? _self.endCustomerName : endCustomerName // ignore: cast_nullable_to_non_nullable
as String?,endCustomerPhone: freezed == endCustomerPhone ? _self.endCustomerPhone : endCustomerPhone // ignore: cast_nullable_to_non_nullable
as String?,endCustomerEmail: freezed == endCustomerEmail ? _self.endCustomerEmail : endCustomerEmail // ignore: cast_nullable_to_non_nullable
as String?,exceedsFinalConsumerLimit: null == exceedsFinalConsumerLimit ? _self.exceedsFinalConsumerLimit : exceedsFinalConsumerLimit // ignore: cast_nullable_to_non_nullable
as bool,emitirFacturaFechaPosterior: null == emitirFacturaFechaPosterior ? _self.emitirFacturaFechaPosterior : emitirFacturaFechaPosterior // ignore: cast_nullable_to_non_nullable
as bool,fechaFacturar: freezed == fechaFacturar ? _self.fechaFacturar : fechaFacturar // ignore: cast_nullable_to_non_nullable
as DateTime?,referrerId: freezed == referrerId ? _self.referrerId : referrerId // ignore: cast_nullable_to_non_nullable
as int?,referrerName: freezed == referrerName ? _self.referrerName : referrerName // ignore: cast_nullable_to_non_nullable
as String?,tipoCliente: freezed == tipoCliente ? _self.tipoCliente : tipoCliente // ignore: cast_nullable_to_non_nullable
as String?,canalCliente: freezed == canalCliente ? _self.canalCliente : canalCliente // ignore: cast_nullable_to_non_nullable
as String?,pickingIds: null == pickingIds ? _self.pickingIds : pickingIds // ignore: cast_nullable_to_non_nullable
as List<int>,deliveryStatus: freezed == deliveryStatus ? _self.deliveryStatus : deliveryStatus // ignore: cast_nullable_to_non_nullable
as String?,taxTotals: freezed == taxTotals ? _self.taxTotals : taxTotals // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,creditExceeded: null == creditExceeded ? _self.creditExceeded : creditExceeded // ignore: cast_nullable_to_non_nullable
as bool,creditCheckBypassed: null == creditCheckBypassed ? _self.creditCheckBypassed : creditCheckBypassed // ignore: cast_nullable_to_non_nullable
as bool,amountCash: null == amountCash ? _self.amountCash : amountCash // ignore: cast_nullable_to_non_nullable
as double,amountUnpaid: null == amountUnpaid ? _self.amountUnpaid : amountUnpaid // ignore: cast_nullable_to_non_nullable
as double,totalCostAmount: null == totalCostAmount ? _self.totalCostAmount : totalCostAmount // ignore: cast_nullable_to_non_nullable
as double,margin: null == margin ? _self.margin : margin // ignore: cast_nullable_to_non_nullable
as double,marginPercent: null == marginPercent ? _self.marginPercent : marginPercent // ignore: cast_nullable_to_non_nullable
as double,retenidoAmount: null == retenidoAmount ? _self.retenidoAmount : retenidoAmount // ignore: cast_nullable_to_non_nullable
as double,approvalCount: null == approvalCount ? _self.approvalCount : approvalCount // ignore: cast_nullable_to_non_nullable
as int,approvedDate: freezed == approvedDate ? _self.approvedDate : approvedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedDate: freezed == rejectedDate ? _self.rejectedDate : rejectedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,collectionUserId: freezed == collectionUserId ? _self.collectionUserId : collectionUserId // ignore: cast_nullable_to_non_nullable
as int?,saleCreatedUserId: freezed == saleCreatedUserId ? _self.saleCreatedUserId : saleCreatedUserId // ignore: cast_nullable_to_non_nullable
as int?,entregarSoloPagado: null == entregarSoloPagado ? _self.entregarSoloPagado : entregarSoloPagado // ignore: cast_nullable_to_non_nullable
as bool,esParaDespacho: null == esParaDespacho ? _self.esParaDespacho : esParaDespacho // ignore: cast_nullable_to_non_nullable
as bool,notaAdicional: freezed == notaAdicional ? _self.notaAdicional : notaAdicional // ignore: cast_nullable_to_non_nullable
as String?,xUuid: freezed == xUuid ? _self.xUuid : xUuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,syncRetryCount: null == syncRetryCount ? _self.syncRetryCount : syncRetryCount // ignore: cast_nullable_to_non_nullable
as int,lastSyncAttempt: freezed == lastSyncAttempt ? _self.lastSyncAttempt : lastSyncAttempt // ignore: cast_nullable_to_non_nullable
as DateTime?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,hasQueuedInvoice: null == hasQueuedInvoice ? _self.hasQueuedInvoice : hasQueuedInvoice // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SaleOrder].
extension SaleOrderPatterns on SaleOrder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SaleOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SaleOrder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SaleOrder value)  $default,){
final _that = this;
switch (_that) {
case _SaleOrder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SaleOrder value)?  $default,){
final _that = this;
switch (_that) {
case _SaleOrder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? orderUuid, @OdooString()  String name, @OdooSelection()  SaleOrderState state, @OdooDateTime(odooName: 'date_order')  DateTime? dateOrder, @OdooDate(odooName: 'validity_date')  DateTime? validityDate, @OdooDateTime(odooName: 'commitment_date')  DateTime? commitmentDate, @OdooDateTime(odooName: 'expected_date')  DateTime? expectedDate, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooString(odooName: 'partner_vat')  String? partnerVat, @OdooString(odooName: 'partner_street')  String? partnerStreet, @OdooString(odooName: 'partner_phone')  String? partnerPhone, @OdooString(odooName: 'partner_email')  String? partnerEmail, @OdooString(odooName: 'partner_avatar')  String? partnerAvatar, @OdooMany2One('res.partner', odooName: 'partner_invoice_id')  int? partnerInvoiceId, @OdooMany2OneName(sourceField: 'partner_invoice_id')  String? partnerInvoiceAddress, @OdooMany2One('res.partner', odooName: 'partner_shipping_id')  int? partnerShippingId, @OdooMany2OneName(sourceField: 'partner_shipping_id')  String? partnerShippingAddress, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooMany2One('crm.team', odooName: 'team_id')  int? teamId, @OdooMany2OneName(sourceField: 'team_id')  String? teamName, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('stock.warehouse', odooName: 'warehouse_id')  int? warehouseId, @OdooMany2OneName(sourceField: 'warehouse_id')  String? warehouseName, @OdooMany2One('product.pricelist', odooName: 'pricelist_id')  int? pricelistId, @OdooMany2OneName(sourceField: 'pricelist_id')  String? pricelistName, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooString(odooName: 'currency_symbol')  String? currencySymbol, @OdooFloat(odooName: 'currency_rate')  double currencyRate, @OdooMany2One('account.payment.term', odooName: 'payment_term_id')  int? paymentTermId, @OdooMany2OneName(sourceField: 'payment_term_id')  String? paymentTermName, @OdooBoolean(odooName: 'is_cash')  bool isCash, @OdooBoolean(odooName: 'is_credit')  bool isCredit, @OdooMany2One('account.fiscal.position', odooName: 'fiscal_position_id')  int? fiscalPositionId, @OdooMany2OneName(sourceField: 'fiscal_position_id')  String? fiscalPositionName, @OdooFloat(odooName: 'amount_untaxed')  double amountUntaxed, @OdooFloat(odooName: 'amount_tax')  double amountTax, @OdooFloat(odooName: 'amount_total')  double amountTotal, @OdooFloat(odooName: 'amount_to_invoice')  double amountToInvoice, @OdooFloat(odooName: 'amount_invoiced')  double amountInvoiced, @OdooSelection(odooName: 'invoice_status')  InvoiceStatus invoiceStatus, @OdooInteger(odooName: 'invoice_count')  int invoiceCount, @OdooString(odooName: 'note')  String? note, @OdooString(odooName: 'client_order_ref')  String? clientOrderRef, @OdooBoolean(odooName: 'require_signature')  bool requireSignature, @OdooString(odooName: 'signature')  String? signature, @OdooString(odooName: 'signed_by')  String? signedBy, @OdooDateTime(odooName: 'signed_on')  DateTime? signedOn, @OdooBoolean(odooName: 'require_payment')  bool requirePayment, @OdooFloat(odooName: 'prepayment_percent')  double prepaymentPercent, @OdooBoolean(odooName: 'locked')  bool locked, @OdooBoolean(odooName: 'is_expired')  bool isExpired, @OdooFloat(odooName: 'total_discount_amount')  double totalDiscountAmount, @OdooFloat(odooName: 'total_amount_undiscounted')  double amountUntaxedUndiscounted, @OdooBoolean(odooName: 'is_final_consumer')  bool isFinalConsumer, @OdooString(odooName: 'end_customer_name')  String? endCustomerName, @OdooString(odooName: 'end_customer_phone')  String? endCustomerPhone, @OdooString(odooName: 'end_customer_email')  String? endCustomerEmail, @OdooBoolean(odooName: 'exceeds_final_consumer_limit')  bool exceedsFinalConsumerLimit, @OdooBoolean(odooName: 'emitir_factura_fecha_posterior')  bool emitirFacturaFechaPosterior, @OdooDate(odooName: 'fecha_facturar')  DateTime? fechaFacturar, @OdooMany2One('res.partner', odooName: 'referrer_id')  int? referrerId, @OdooMany2OneName(sourceField: 'referrer_id')  String? referrerName, @OdooString(odooName: 'tipo_cliente')  String? tipoCliente, @OdooString(odooName: 'canal_cliente')  String? canalCliente, @OdooMany2Many('stock.picking', odooName: 'picking_ids')  List<int> pickingIds, @OdooString(odooName: 'delivery_status')  String? deliveryStatus, @OdooJson(odooName: 'tax_totals')  Map<String, dynamic>? taxTotals, @OdooBoolean(odooName: 'credit_exceeded')  bool creditExceeded, @OdooBoolean(odooName: 'credit_check_bypassed')  bool creditCheckBypassed, @OdooFloat(odooName: 'amount_cash')  double amountCash, @OdooFloat(odooName: 'amount_unpaid')  double amountUnpaid, @OdooFloat(odooName: 'total_cost_amount')  double totalCostAmount, @OdooFloat(odooName: 'margin')  double margin, @OdooFloat(odooName: 'margin_percent')  double marginPercent, @OdooFloat(odooName: 'retenido_amount')  double retenidoAmount, @OdooInteger(odooName: 'approval_count')  int approvalCount, @OdooDateTime(odooName: 'approved_date')  DateTime? approvedDate, @OdooDateTime(odooName: 'rejected_date')  DateTime? rejectedDate, @OdooString(odooName: 'rejected_reason')  String? rejectedReason, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('res.users', odooName: 'collection_user_id')  int? collectionUserId, @OdooMany2One('res.users', odooName: 'sale_created_user_id')  int? saleCreatedUserId, @OdooBoolean(odooName: 'entregar_solo_pagado')  bool entregarSoloPagado, @OdooBoolean(odooName: 'es_para_despacho')  bool esParaDespacho, @OdooString(odooName: 'nota_adicional')  String? notaAdicional, @OdooString(odooName: 'x_uuid')  String? xUuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooLocalOnly()  int syncRetryCount, @OdooLocalOnly()  DateTime? lastSyncAttempt, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool hasQueuedInvoice)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SaleOrder() when $default != null:
return $default(_that.id,_that.orderUuid,_that.name,_that.state,_that.dateOrder,_that.validityDate,_that.commitmentDate,_that.expectedDate,_that.partnerId,_that.partnerName,_that.partnerVat,_that.partnerStreet,_that.partnerPhone,_that.partnerEmail,_that.partnerAvatar,_that.partnerInvoiceId,_that.partnerInvoiceAddress,_that.partnerShippingId,_that.partnerShippingAddress,_that.userId,_that.userName,_that.teamId,_that.teamName,_that.companyId,_that.companyName,_that.warehouseId,_that.warehouseName,_that.pricelistId,_that.pricelistName,_that.currencyId,_that.currencySymbol,_that.currencyRate,_that.paymentTermId,_that.paymentTermName,_that.isCash,_that.isCredit,_that.fiscalPositionId,_that.fiscalPositionName,_that.amountUntaxed,_that.amountTax,_that.amountTotal,_that.amountToInvoice,_that.amountInvoiced,_that.invoiceStatus,_that.invoiceCount,_that.note,_that.clientOrderRef,_that.requireSignature,_that.signature,_that.signedBy,_that.signedOn,_that.requirePayment,_that.prepaymentPercent,_that.locked,_that.isExpired,_that.totalDiscountAmount,_that.amountUntaxedUndiscounted,_that.isFinalConsumer,_that.endCustomerName,_that.endCustomerPhone,_that.endCustomerEmail,_that.exceedsFinalConsumerLimit,_that.emitirFacturaFechaPosterior,_that.fechaFacturar,_that.referrerId,_that.referrerName,_that.tipoCliente,_that.canalCliente,_that.pickingIds,_that.deliveryStatus,_that.taxTotals,_that.creditExceeded,_that.creditCheckBypassed,_that.amountCash,_that.amountUnpaid,_that.totalCostAmount,_that.margin,_that.marginPercent,_that.retenidoAmount,_that.approvalCount,_that.approvedDate,_that.rejectedDate,_that.rejectedReason,_that.collectionSessionId,_that.collectionUserId,_that.saleCreatedUserId,_that.entregarSoloPagado,_that.esParaDespacho,_that.notaAdicional,_that.xUuid,_that.isSynced,_that.lastSyncDate,_that.syncRetryCount,_that.lastSyncAttempt,_that.writeDate,_that.hasQueuedInvoice);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OdooId()  int id, @OdooLocalOnly()  String? orderUuid, @OdooString()  String name, @OdooSelection()  SaleOrderState state, @OdooDateTime(odooName: 'date_order')  DateTime? dateOrder, @OdooDate(odooName: 'validity_date')  DateTime? validityDate, @OdooDateTime(odooName: 'commitment_date')  DateTime? commitmentDate, @OdooDateTime(odooName: 'expected_date')  DateTime? expectedDate, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooString(odooName: 'partner_vat')  String? partnerVat, @OdooString(odooName: 'partner_street')  String? partnerStreet, @OdooString(odooName: 'partner_phone')  String? partnerPhone, @OdooString(odooName: 'partner_email')  String? partnerEmail, @OdooString(odooName: 'partner_avatar')  String? partnerAvatar, @OdooMany2One('res.partner', odooName: 'partner_invoice_id')  int? partnerInvoiceId, @OdooMany2OneName(sourceField: 'partner_invoice_id')  String? partnerInvoiceAddress, @OdooMany2One('res.partner', odooName: 'partner_shipping_id')  int? partnerShippingId, @OdooMany2OneName(sourceField: 'partner_shipping_id')  String? partnerShippingAddress, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooMany2One('crm.team', odooName: 'team_id')  int? teamId, @OdooMany2OneName(sourceField: 'team_id')  String? teamName, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('stock.warehouse', odooName: 'warehouse_id')  int? warehouseId, @OdooMany2OneName(sourceField: 'warehouse_id')  String? warehouseName, @OdooMany2One('product.pricelist', odooName: 'pricelist_id')  int? pricelistId, @OdooMany2OneName(sourceField: 'pricelist_id')  String? pricelistName, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooString(odooName: 'currency_symbol')  String? currencySymbol, @OdooFloat(odooName: 'currency_rate')  double currencyRate, @OdooMany2One('account.payment.term', odooName: 'payment_term_id')  int? paymentTermId, @OdooMany2OneName(sourceField: 'payment_term_id')  String? paymentTermName, @OdooBoolean(odooName: 'is_cash')  bool isCash, @OdooBoolean(odooName: 'is_credit')  bool isCredit, @OdooMany2One('account.fiscal.position', odooName: 'fiscal_position_id')  int? fiscalPositionId, @OdooMany2OneName(sourceField: 'fiscal_position_id')  String? fiscalPositionName, @OdooFloat(odooName: 'amount_untaxed')  double amountUntaxed, @OdooFloat(odooName: 'amount_tax')  double amountTax, @OdooFloat(odooName: 'amount_total')  double amountTotal, @OdooFloat(odooName: 'amount_to_invoice')  double amountToInvoice, @OdooFloat(odooName: 'amount_invoiced')  double amountInvoiced, @OdooSelection(odooName: 'invoice_status')  InvoiceStatus invoiceStatus, @OdooInteger(odooName: 'invoice_count')  int invoiceCount, @OdooString(odooName: 'note')  String? note, @OdooString(odooName: 'client_order_ref')  String? clientOrderRef, @OdooBoolean(odooName: 'require_signature')  bool requireSignature, @OdooString(odooName: 'signature')  String? signature, @OdooString(odooName: 'signed_by')  String? signedBy, @OdooDateTime(odooName: 'signed_on')  DateTime? signedOn, @OdooBoolean(odooName: 'require_payment')  bool requirePayment, @OdooFloat(odooName: 'prepayment_percent')  double prepaymentPercent, @OdooBoolean(odooName: 'locked')  bool locked, @OdooBoolean(odooName: 'is_expired')  bool isExpired, @OdooFloat(odooName: 'total_discount_amount')  double totalDiscountAmount, @OdooFloat(odooName: 'total_amount_undiscounted')  double amountUntaxedUndiscounted, @OdooBoolean(odooName: 'is_final_consumer')  bool isFinalConsumer, @OdooString(odooName: 'end_customer_name')  String? endCustomerName, @OdooString(odooName: 'end_customer_phone')  String? endCustomerPhone, @OdooString(odooName: 'end_customer_email')  String? endCustomerEmail, @OdooBoolean(odooName: 'exceeds_final_consumer_limit')  bool exceedsFinalConsumerLimit, @OdooBoolean(odooName: 'emitir_factura_fecha_posterior')  bool emitirFacturaFechaPosterior, @OdooDate(odooName: 'fecha_facturar')  DateTime? fechaFacturar, @OdooMany2One('res.partner', odooName: 'referrer_id')  int? referrerId, @OdooMany2OneName(sourceField: 'referrer_id')  String? referrerName, @OdooString(odooName: 'tipo_cliente')  String? tipoCliente, @OdooString(odooName: 'canal_cliente')  String? canalCliente, @OdooMany2Many('stock.picking', odooName: 'picking_ids')  List<int> pickingIds, @OdooString(odooName: 'delivery_status')  String? deliveryStatus, @OdooJson(odooName: 'tax_totals')  Map<String, dynamic>? taxTotals, @OdooBoolean(odooName: 'credit_exceeded')  bool creditExceeded, @OdooBoolean(odooName: 'credit_check_bypassed')  bool creditCheckBypassed, @OdooFloat(odooName: 'amount_cash')  double amountCash, @OdooFloat(odooName: 'amount_unpaid')  double amountUnpaid, @OdooFloat(odooName: 'total_cost_amount')  double totalCostAmount, @OdooFloat(odooName: 'margin')  double margin, @OdooFloat(odooName: 'margin_percent')  double marginPercent, @OdooFloat(odooName: 'retenido_amount')  double retenidoAmount, @OdooInteger(odooName: 'approval_count')  int approvalCount, @OdooDateTime(odooName: 'approved_date')  DateTime? approvedDate, @OdooDateTime(odooName: 'rejected_date')  DateTime? rejectedDate, @OdooString(odooName: 'rejected_reason')  String? rejectedReason, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('res.users', odooName: 'collection_user_id')  int? collectionUserId, @OdooMany2One('res.users', odooName: 'sale_created_user_id')  int? saleCreatedUserId, @OdooBoolean(odooName: 'entregar_solo_pagado')  bool entregarSoloPagado, @OdooBoolean(odooName: 'es_para_despacho')  bool esParaDespacho, @OdooString(odooName: 'nota_adicional')  String? notaAdicional, @OdooString(odooName: 'x_uuid')  String? xUuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooLocalOnly()  int syncRetryCount, @OdooLocalOnly()  DateTime? lastSyncAttempt, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool hasQueuedInvoice)  $default,) {final _that = this;
switch (_that) {
case _SaleOrder():
return $default(_that.id,_that.orderUuid,_that.name,_that.state,_that.dateOrder,_that.validityDate,_that.commitmentDate,_that.expectedDate,_that.partnerId,_that.partnerName,_that.partnerVat,_that.partnerStreet,_that.partnerPhone,_that.partnerEmail,_that.partnerAvatar,_that.partnerInvoiceId,_that.partnerInvoiceAddress,_that.partnerShippingId,_that.partnerShippingAddress,_that.userId,_that.userName,_that.teamId,_that.teamName,_that.companyId,_that.companyName,_that.warehouseId,_that.warehouseName,_that.pricelistId,_that.pricelistName,_that.currencyId,_that.currencySymbol,_that.currencyRate,_that.paymentTermId,_that.paymentTermName,_that.isCash,_that.isCredit,_that.fiscalPositionId,_that.fiscalPositionName,_that.amountUntaxed,_that.amountTax,_that.amountTotal,_that.amountToInvoice,_that.amountInvoiced,_that.invoiceStatus,_that.invoiceCount,_that.note,_that.clientOrderRef,_that.requireSignature,_that.signature,_that.signedBy,_that.signedOn,_that.requirePayment,_that.prepaymentPercent,_that.locked,_that.isExpired,_that.totalDiscountAmount,_that.amountUntaxedUndiscounted,_that.isFinalConsumer,_that.endCustomerName,_that.endCustomerPhone,_that.endCustomerEmail,_that.exceedsFinalConsumerLimit,_that.emitirFacturaFechaPosterior,_that.fechaFacturar,_that.referrerId,_that.referrerName,_that.tipoCliente,_that.canalCliente,_that.pickingIds,_that.deliveryStatus,_that.taxTotals,_that.creditExceeded,_that.creditCheckBypassed,_that.amountCash,_that.amountUnpaid,_that.totalCostAmount,_that.margin,_that.marginPercent,_that.retenidoAmount,_that.approvalCount,_that.approvedDate,_that.rejectedDate,_that.rejectedReason,_that.collectionSessionId,_that.collectionUserId,_that.saleCreatedUserId,_that.entregarSoloPagado,_that.esParaDespacho,_that.notaAdicional,_that.xUuid,_that.isSynced,_that.lastSyncDate,_that.syncRetryCount,_that.lastSyncAttempt,_that.writeDate,_that.hasQueuedInvoice);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OdooId()  int id, @OdooLocalOnly()  String? orderUuid, @OdooString()  String name, @OdooSelection()  SaleOrderState state, @OdooDateTime(odooName: 'date_order')  DateTime? dateOrder, @OdooDate(odooName: 'validity_date')  DateTime? validityDate, @OdooDateTime(odooName: 'commitment_date')  DateTime? commitmentDate, @OdooDateTime(odooName: 'expected_date')  DateTime? expectedDate, @OdooMany2One('res.partner', odooName: 'partner_id')  int? partnerId, @OdooMany2OneName(sourceField: 'partner_id')  String? partnerName, @OdooString(odooName: 'partner_vat')  String? partnerVat, @OdooString(odooName: 'partner_street')  String? partnerStreet, @OdooString(odooName: 'partner_phone')  String? partnerPhone, @OdooString(odooName: 'partner_email')  String? partnerEmail, @OdooString(odooName: 'partner_avatar')  String? partnerAvatar, @OdooMany2One('res.partner', odooName: 'partner_invoice_id')  int? partnerInvoiceId, @OdooMany2OneName(sourceField: 'partner_invoice_id')  String? partnerInvoiceAddress, @OdooMany2One('res.partner', odooName: 'partner_shipping_id')  int? partnerShippingId, @OdooMany2OneName(sourceField: 'partner_shipping_id')  String? partnerShippingAddress, @OdooMany2One('res.users', odooName: 'user_id')  int? userId, @OdooMany2OneName(sourceField: 'user_id')  String? userName, @OdooMany2One('crm.team', odooName: 'team_id')  int? teamId, @OdooMany2OneName(sourceField: 'team_id')  String? teamName, @OdooMany2One('res.company', odooName: 'company_id')  int? companyId, @OdooMany2OneName(sourceField: 'company_id')  String? companyName, @OdooMany2One('stock.warehouse', odooName: 'warehouse_id')  int? warehouseId, @OdooMany2OneName(sourceField: 'warehouse_id')  String? warehouseName, @OdooMany2One('product.pricelist', odooName: 'pricelist_id')  int? pricelistId, @OdooMany2OneName(sourceField: 'pricelist_id')  String? pricelistName, @OdooMany2One('res.currency', odooName: 'currency_id')  int? currencyId, @OdooString(odooName: 'currency_symbol')  String? currencySymbol, @OdooFloat(odooName: 'currency_rate')  double currencyRate, @OdooMany2One('account.payment.term', odooName: 'payment_term_id')  int? paymentTermId, @OdooMany2OneName(sourceField: 'payment_term_id')  String? paymentTermName, @OdooBoolean(odooName: 'is_cash')  bool isCash, @OdooBoolean(odooName: 'is_credit')  bool isCredit, @OdooMany2One('account.fiscal.position', odooName: 'fiscal_position_id')  int? fiscalPositionId, @OdooMany2OneName(sourceField: 'fiscal_position_id')  String? fiscalPositionName, @OdooFloat(odooName: 'amount_untaxed')  double amountUntaxed, @OdooFloat(odooName: 'amount_tax')  double amountTax, @OdooFloat(odooName: 'amount_total')  double amountTotal, @OdooFloat(odooName: 'amount_to_invoice')  double amountToInvoice, @OdooFloat(odooName: 'amount_invoiced')  double amountInvoiced, @OdooSelection(odooName: 'invoice_status')  InvoiceStatus invoiceStatus, @OdooInteger(odooName: 'invoice_count')  int invoiceCount, @OdooString(odooName: 'note')  String? note, @OdooString(odooName: 'client_order_ref')  String? clientOrderRef, @OdooBoolean(odooName: 'require_signature')  bool requireSignature, @OdooString(odooName: 'signature')  String? signature, @OdooString(odooName: 'signed_by')  String? signedBy, @OdooDateTime(odooName: 'signed_on')  DateTime? signedOn, @OdooBoolean(odooName: 'require_payment')  bool requirePayment, @OdooFloat(odooName: 'prepayment_percent')  double prepaymentPercent, @OdooBoolean(odooName: 'locked')  bool locked, @OdooBoolean(odooName: 'is_expired')  bool isExpired, @OdooFloat(odooName: 'total_discount_amount')  double totalDiscountAmount, @OdooFloat(odooName: 'total_amount_undiscounted')  double amountUntaxedUndiscounted, @OdooBoolean(odooName: 'is_final_consumer')  bool isFinalConsumer, @OdooString(odooName: 'end_customer_name')  String? endCustomerName, @OdooString(odooName: 'end_customer_phone')  String? endCustomerPhone, @OdooString(odooName: 'end_customer_email')  String? endCustomerEmail, @OdooBoolean(odooName: 'exceeds_final_consumer_limit')  bool exceedsFinalConsumerLimit, @OdooBoolean(odooName: 'emitir_factura_fecha_posterior')  bool emitirFacturaFechaPosterior, @OdooDate(odooName: 'fecha_facturar')  DateTime? fechaFacturar, @OdooMany2One('res.partner', odooName: 'referrer_id')  int? referrerId, @OdooMany2OneName(sourceField: 'referrer_id')  String? referrerName, @OdooString(odooName: 'tipo_cliente')  String? tipoCliente, @OdooString(odooName: 'canal_cliente')  String? canalCliente, @OdooMany2Many('stock.picking', odooName: 'picking_ids')  List<int> pickingIds, @OdooString(odooName: 'delivery_status')  String? deliveryStatus, @OdooJson(odooName: 'tax_totals')  Map<String, dynamic>? taxTotals, @OdooBoolean(odooName: 'credit_exceeded')  bool creditExceeded, @OdooBoolean(odooName: 'credit_check_bypassed')  bool creditCheckBypassed, @OdooFloat(odooName: 'amount_cash')  double amountCash, @OdooFloat(odooName: 'amount_unpaid')  double amountUnpaid, @OdooFloat(odooName: 'total_cost_amount')  double totalCostAmount, @OdooFloat(odooName: 'margin')  double margin, @OdooFloat(odooName: 'margin_percent')  double marginPercent, @OdooFloat(odooName: 'retenido_amount')  double retenidoAmount, @OdooInteger(odooName: 'approval_count')  int approvalCount, @OdooDateTime(odooName: 'approved_date')  DateTime? approvedDate, @OdooDateTime(odooName: 'rejected_date')  DateTime? rejectedDate, @OdooString(odooName: 'rejected_reason')  String? rejectedReason, @OdooMany2One('collection.session', odooName: 'collection_session_id')  int? collectionSessionId, @OdooMany2One('res.users', odooName: 'collection_user_id')  int? collectionUserId, @OdooMany2One('res.users', odooName: 'sale_created_user_id')  int? saleCreatedUserId, @OdooBoolean(odooName: 'entregar_solo_pagado')  bool entregarSoloPagado, @OdooBoolean(odooName: 'es_para_despacho')  bool esParaDespacho, @OdooString(odooName: 'nota_adicional')  String? notaAdicional, @OdooString(odooName: 'x_uuid')  String? xUuid, @OdooLocalOnly()  bool isSynced, @OdooLocalOnly()  DateTime? lastSyncDate, @OdooLocalOnly()  int syncRetryCount, @OdooLocalOnly()  DateTime? lastSyncAttempt, @OdooDateTime(odooName: 'write_date', writable: false)  DateTime? writeDate, @OdooLocalOnly()  bool hasQueuedInvoice)?  $default,) {final _that = this;
switch (_that) {
case _SaleOrder() when $default != null:
return $default(_that.id,_that.orderUuid,_that.name,_that.state,_that.dateOrder,_that.validityDate,_that.commitmentDate,_that.expectedDate,_that.partnerId,_that.partnerName,_that.partnerVat,_that.partnerStreet,_that.partnerPhone,_that.partnerEmail,_that.partnerAvatar,_that.partnerInvoiceId,_that.partnerInvoiceAddress,_that.partnerShippingId,_that.partnerShippingAddress,_that.userId,_that.userName,_that.teamId,_that.teamName,_that.companyId,_that.companyName,_that.warehouseId,_that.warehouseName,_that.pricelistId,_that.pricelistName,_that.currencyId,_that.currencySymbol,_that.currencyRate,_that.paymentTermId,_that.paymentTermName,_that.isCash,_that.isCredit,_that.fiscalPositionId,_that.fiscalPositionName,_that.amountUntaxed,_that.amountTax,_that.amountTotal,_that.amountToInvoice,_that.amountInvoiced,_that.invoiceStatus,_that.invoiceCount,_that.note,_that.clientOrderRef,_that.requireSignature,_that.signature,_that.signedBy,_that.signedOn,_that.requirePayment,_that.prepaymentPercent,_that.locked,_that.isExpired,_that.totalDiscountAmount,_that.amountUntaxedUndiscounted,_that.isFinalConsumer,_that.endCustomerName,_that.endCustomerPhone,_that.endCustomerEmail,_that.exceedsFinalConsumerLimit,_that.emitirFacturaFechaPosterior,_that.fechaFacturar,_that.referrerId,_that.referrerName,_that.tipoCliente,_that.canalCliente,_that.pickingIds,_that.deliveryStatus,_that.taxTotals,_that.creditExceeded,_that.creditCheckBypassed,_that.amountCash,_that.amountUnpaid,_that.totalCostAmount,_that.margin,_that.marginPercent,_that.retenidoAmount,_that.approvalCount,_that.approvedDate,_that.rejectedDate,_that.rejectedReason,_that.collectionSessionId,_that.collectionUserId,_that.saleCreatedUserId,_that.entregarSoloPagado,_that.esParaDespacho,_that.notaAdicional,_that.xUuid,_that.isSynced,_that.lastSyncDate,_that.syncRetryCount,_that.lastSyncAttempt,_that.writeDate,_that.hasQueuedInvoice);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SaleOrder extends SaleOrder {
  const _SaleOrder({@OdooId() required this.id, @OdooLocalOnly() this.orderUuid, @OdooString() required this.name, @OdooSelection() required this.state, @OdooDateTime(odooName: 'date_order') this.dateOrder, @OdooDate(odooName: 'validity_date') this.validityDate, @OdooDateTime(odooName: 'commitment_date') this.commitmentDate, @OdooDateTime(odooName: 'expected_date') this.expectedDate, @OdooMany2One('res.partner', odooName: 'partner_id') this.partnerId, @OdooMany2OneName(sourceField: 'partner_id') this.partnerName, @OdooString(odooName: 'partner_vat') this.partnerVat, @OdooString(odooName: 'partner_street') this.partnerStreet, @OdooString(odooName: 'partner_phone') this.partnerPhone, @OdooString(odooName: 'partner_email') this.partnerEmail, @OdooString(odooName: 'partner_avatar') this.partnerAvatar, @OdooMany2One('res.partner', odooName: 'partner_invoice_id') this.partnerInvoiceId, @OdooMany2OneName(sourceField: 'partner_invoice_id') this.partnerInvoiceAddress, @OdooMany2One('res.partner', odooName: 'partner_shipping_id') this.partnerShippingId, @OdooMany2OneName(sourceField: 'partner_shipping_id') this.partnerShippingAddress, @OdooMany2One('res.users', odooName: 'user_id') this.userId, @OdooMany2OneName(sourceField: 'user_id') this.userName, @OdooMany2One('crm.team', odooName: 'team_id') this.teamId, @OdooMany2OneName(sourceField: 'team_id') this.teamName, @OdooMany2One('res.company', odooName: 'company_id') this.companyId, @OdooMany2OneName(sourceField: 'company_id') this.companyName, @OdooMany2One('stock.warehouse', odooName: 'warehouse_id') this.warehouseId, @OdooMany2OneName(sourceField: 'warehouse_id') this.warehouseName, @OdooMany2One('product.pricelist', odooName: 'pricelist_id') this.pricelistId, @OdooMany2OneName(sourceField: 'pricelist_id') this.pricelistName, @OdooMany2One('res.currency', odooName: 'currency_id') this.currencyId, @OdooString(odooName: 'currency_symbol') this.currencySymbol, @OdooFloat(odooName: 'currency_rate') this.currencyRate = 1.0, @OdooMany2One('account.payment.term', odooName: 'payment_term_id') this.paymentTermId, @OdooMany2OneName(sourceField: 'payment_term_id') this.paymentTermName, @OdooBoolean(odooName: 'is_cash') this.isCash = true, @OdooBoolean(odooName: 'is_credit') this.isCredit = false, @OdooMany2One('account.fiscal.position', odooName: 'fiscal_position_id') this.fiscalPositionId, @OdooMany2OneName(sourceField: 'fiscal_position_id') this.fiscalPositionName, @OdooFloat(odooName: 'amount_untaxed') this.amountUntaxed = 0.0, @OdooFloat(odooName: 'amount_tax') this.amountTax = 0.0, @OdooFloat(odooName: 'amount_total') this.amountTotal = 0.0, @OdooFloat(odooName: 'amount_to_invoice') this.amountToInvoice = 0.0, @OdooFloat(odooName: 'amount_invoiced') this.amountInvoiced = 0.0, @OdooSelection(odooName: 'invoice_status') this.invoiceStatus = InvoiceStatus.no, @OdooInteger(odooName: 'invoice_count') this.invoiceCount = 0, @OdooString(odooName: 'note') this.note, @OdooString(odooName: 'client_order_ref') this.clientOrderRef, @OdooBoolean(odooName: 'require_signature') this.requireSignature = false, @OdooString(odooName: 'signature') this.signature, @OdooString(odooName: 'signed_by') this.signedBy, @OdooDateTime(odooName: 'signed_on') this.signedOn, @OdooBoolean(odooName: 'require_payment') this.requirePayment = false, @OdooFloat(odooName: 'prepayment_percent') this.prepaymentPercent = 0.0, @OdooBoolean(odooName: 'locked') this.locked = false, @OdooBoolean(odooName: 'is_expired') this.isExpired = false, @OdooFloat(odooName: 'total_discount_amount') this.totalDiscountAmount = 0.0, @OdooFloat(odooName: 'total_amount_undiscounted') this.amountUntaxedUndiscounted = 0.0, @OdooBoolean(odooName: 'is_final_consumer') this.isFinalConsumer = false, @OdooString(odooName: 'end_customer_name') this.endCustomerName, @OdooString(odooName: 'end_customer_phone') this.endCustomerPhone, @OdooString(odooName: 'end_customer_email') this.endCustomerEmail, @OdooBoolean(odooName: 'exceeds_final_consumer_limit') this.exceedsFinalConsumerLimit = false, @OdooBoolean(odooName: 'emitir_factura_fecha_posterior') this.emitirFacturaFechaPosterior = false, @OdooDate(odooName: 'fecha_facturar') this.fechaFacturar, @OdooMany2One('res.partner', odooName: 'referrer_id') this.referrerId, @OdooMany2OneName(sourceField: 'referrer_id') this.referrerName, @OdooString(odooName: 'tipo_cliente') this.tipoCliente, @OdooString(odooName: 'canal_cliente') this.canalCliente, @OdooMany2Many('stock.picking', odooName: 'picking_ids') final  List<int> pickingIds = const <int>[], @OdooString(odooName: 'delivery_status') this.deliveryStatus, @OdooJson(odooName: 'tax_totals') final  Map<String, dynamic>? taxTotals, @OdooBoolean(odooName: 'credit_exceeded') this.creditExceeded = false, @OdooBoolean(odooName: 'credit_check_bypassed') this.creditCheckBypassed = false, @OdooFloat(odooName: 'amount_cash') this.amountCash = 0.0, @OdooFloat(odooName: 'amount_unpaid') this.amountUnpaid = 0.0, @OdooFloat(odooName: 'total_cost_amount') this.totalCostAmount = 0.0, @OdooFloat(odooName: 'margin') this.margin = 0.0, @OdooFloat(odooName: 'margin_percent') this.marginPercent = 0.0, @OdooFloat(odooName: 'retenido_amount') this.retenidoAmount = 0.0, @OdooInteger(odooName: 'approval_count') this.approvalCount = 0, @OdooDateTime(odooName: 'approved_date') this.approvedDate, @OdooDateTime(odooName: 'rejected_date') this.rejectedDate, @OdooString(odooName: 'rejected_reason') this.rejectedReason, @OdooMany2One('collection.session', odooName: 'collection_session_id') this.collectionSessionId, @OdooMany2One('res.users', odooName: 'collection_user_id') this.collectionUserId, @OdooMany2One('res.users', odooName: 'sale_created_user_id') this.saleCreatedUserId, @OdooBoolean(odooName: 'entregar_solo_pagado') this.entregarSoloPagado = false, @OdooBoolean(odooName: 'es_para_despacho') this.esParaDespacho = false, @OdooString(odooName: 'nota_adicional') this.notaAdicional, @OdooString(odooName: 'x_uuid') this.xUuid, @OdooLocalOnly() this.isSynced = false, @OdooLocalOnly() this.lastSyncDate, @OdooLocalOnly() this.syncRetryCount = 0, @OdooLocalOnly() this.lastSyncAttempt, @OdooDateTime(odooName: 'write_date', writable: false) this.writeDate, @OdooLocalOnly() this.hasQueuedInvoice = false}): _pickingIds = pickingIds,_taxTotals = taxTotals,super._();
  factory _SaleOrder.fromJson(Map<String, dynamic> json) => _$SaleOrderFromJson(json);

@override@OdooId() final  int id;
@override@OdooLocalOnly() final  String? orderUuid;
// UUID local para sincronizacion offline-first
@override@OdooString() final  String name;
// Referencia (SO001)
@override@OdooSelection() final  SaleOrderState state;
// Fechas
@override@OdooDateTime(odooName: 'date_order') final  DateTime? dateOrder;
@override@OdooDate(odooName: 'validity_date') final  DateTime? validityDate;
@override@OdooDateTime(odooName: 'commitment_date') final  DateTime? commitmentDate;
@override@OdooDateTime(odooName: 'expected_date') final  DateTime? expectedDate;
// Cliente y direcciones
@override@OdooMany2One('res.partner', odooName: 'partner_id') final  int? partnerId;
@override@OdooMany2OneName(sourceField: 'partner_id') final  String? partnerName;
@override@OdooString(odooName: 'partner_vat') final  String? partnerVat;
@override@OdooString(odooName: 'partner_street') final  String? partnerStreet;
@override@OdooString(odooName: 'partner_phone') final  String? partnerPhone;
@override@OdooString(odooName: 'partner_email') final  String? partnerEmail;
@override@OdooString(odooName: 'partner_avatar') final  String? partnerAvatar;
@override@OdooMany2One('res.partner', odooName: 'partner_invoice_id') final  int? partnerInvoiceId;
@override@OdooMany2OneName(sourceField: 'partner_invoice_id') final  String? partnerInvoiceAddress;
@override@OdooMany2One('res.partner', odooName: 'partner_shipping_id') final  int? partnerShippingId;
@override@OdooMany2OneName(sourceField: 'partner_shipping_id') final  String? partnerShippingAddress;
// Vendedor y equipo
@override@OdooMany2One('res.users', odooName: 'user_id') final  int? userId;
@override@OdooMany2OneName(sourceField: 'user_id') final  String? userName;
@override@OdooMany2One('crm.team', odooName: 'team_id') final  int? teamId;
@override@OdooMany2OneName(sourceField: 'team_id') final  String? teamName;
// Compania
@override@OdooMany2One('res.company', odooName: 'company_id') final  int? companyId;
@override@OdooMany2OneName(sourceField: 'company_id') final  String? companyName;
// Almacen (sale_stock)
@override@OdooMany2One('stock.warehouse', odooName: 'warehouse_id') final  int? warehouseId;
@override@OdooMany2OneName(sourceField: 'warehouse_id') final  String? warehouseName;
// Lista de precios y moneda
@override@OdooMany2One('product.pricelist', odooName: 'pricelist_id') final  int? pricelistId;
@override@OdooMany2OneName(sourceField: 'pricelist_id') final  String? pricelistName;
@override@OdooMany2One('res.currency', odooName: 'currency_id') final  int? currencyId;
@override@OdooString(odooName: 'currency_symbol') final  String? currencySymbol;
@override@JsonKey()@OdooFloat(odooName: 'currency_rate') final  double currencyRate;
// Condiciones comerciales
@override@OdooMany2One('account.payment.term', odooName: 'payment_term_id') final  int? paymentTermId;
@override@OdooMany2OneName(sourceField: 'payment_term_id') final  String? paymentTermName;
// Payment type (synced from Odoo: payment_term_id.is_cash / is_credit)
/// True if payment term is cash/immediate payment
@override@JsonKey()@OdooBoolean(odooName: 'is_cash') final  bool isCash;
/// True if payment term is credit (has payment days > 0)
@override@JsonKey()@OdooBoolean(odooName: 'is_credit') final  bool isCredit;
@override@OdooMany2One('account.fiscal.position', odooName: 'fiscal_position_id') final  int? fiscalPositionId;
@override@OdooMany2OneName(sourceField: 'fiscal_position_id') final  String? fiscalPositionName;
// Montos
@override@JsonKey()@OdooFloat(odooName: 'amount_untaxed') final  double amountUntaxed;
@override@JsonKey()@OdooFloat(odooName: 'amount_tax') final  double amountTax;
@override@JsonKey()@OdooFloat(odooName: 'amount_total') final  double amountTotal;
@override@JsonKey()@OdooFloat(odooName: 'amount_to_invoice') final  double amountToInvoice;
@override@JsonKey()@OdooFloat(odooName: 'amount_invoiced') final  double amountInvoiced;
// Estado de facturacion
@override@JsonKey()@OdooSelection(odooName: 'invoice_status') final  InvoiceStatus invoiceStatus;
@override@JsonKey()@OdooInteger(odooName: 'invoice_count') final  int invoiceCount;
// Notas y referencias
@override@OdooString(odooName: 'note') final  String? note;
@override@OdooString(odooName: 'client_order_ref') final  String? clientOrderRef;
// Firma digital
@override@JsonKey()@OdooBoolean(odooName: 'require_signature') final  bool requireSignature;
@override@OdooString(odooName: 'signature') final  String? signature;
@override@OdooString(odooName: 'signed_by') final  String? signedBy;
@override@OdooDateTime(odooName: 'signed_on') final  DateTime? signedOn;
// Pago online
@override@JsonKey()@OdooBoolean(odooName: 'require_payment') final  bool requirePayment;
@override@JsonKey()@OdooFloat(odooName: 'prepayment_percent') final  double prepaymentPercent;
// Control
@override@JsonKey()@OdooBoolean(odooName: 'locked') final  bool locked;
@override@JsonKey()@OdooBoolean(odooName: 'is_expired') final  bool isExpired;
// Descuentos (l10n_ec_sale_discount)
@override@JsonKey()@OdooFloat(odooName: 'total_discount_amount') final  double totalDiscountAmount;
@override@JsonKey()@OdooFloat(odooName: 'total_amount_undiscounted') final  double amountUntaxedUndiscounted;
// Consumidor Final (l10n_ec_sale_base)
@override@JsonKey()@OdooBoolean(odooName: 'is_final_consumer') final  bool isFinalConsumer;
@override@OdooString(odooName: 'end_customer_name') final  String? endCustomerName;
@override@OdooString(odooName: 'end_customer_phone') final  String? endCustomerPhone;
@override@OdooString(odooName: 'end_customer_email') final  String? endCustomerEmail;
@override@JsonKey()@OdooBoolean(odooName: 'exceeds_final_consumer_limit') final  bool exceedsFinalConsumerLimit;
// Facturacion postfechada (l10n_ec_sale_base)
@override@JsonKey()@OdooBoolean(odooName: 'emitir_factura_fecha_posterior') final  bool emitirFacturaFechaPosterior;
@override@OdooDate(odooName: 'fecha_facturar') final  DateTime? fechaFacturar;
// Referidor (l10n_ec_sale_base)
@override@OdooMany2One('res.partner', odooName: 'referrer_id') final  int? referrerId;
@override@OdooMany2OneName(sourceField: 'referrer_id') final  String? referrerName;
// Tipo y Canal de cliente (l10n_ec_sale_base)
@override@OdooString(odooName: 'tipo_cliente') final  String? tipoCliente;
@override@OdooString(odooName: 'canal_cliente') final  String? canalCliente;
// Entregas/Picking (sale_stock)
 final  List<int> _pickingIds;
// Entregas/Picking (sale_stock)
@override@JsonKey()@OdooMany2Many('stock.picking', odooName: 'picking_ids') List<int> get pickingIds {
  if (_pickingIds is EqualUnmodifiableListView) return _pickingIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pickingIds);
}

@override@OdooString(odooName: 'delivery_status') final  String? deliveryStatus;
// Tax totals JSON para desglose de impuestos
 final  Map<String, dynamic>? _taxTotals;
// Tax totals JSON para desglose de impuestos
@override@OdooJson(odooName: 'tax_totals') Map<String, dynamic>? get taxTotals {
  final value = _taxTotals;
  if (value == null) return null;
  if (_taxTotals is EqualUnmodifiableMapView) return _taxTotals;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

// Credit Control (l10n_ec_sale_credit)
@override@JsonKey()@OdooBoolean(odooName: 'credit_exceeded') final  bool creditExceeded;
@override@JsonKey()@OdooBoolean(odooName: 'credit_check_bypassed') final  bool creditCheckBypassed;
// Additional Amounts
@override@JsonKey()@OdooFloat(odooName: 'amount_cash') final  double amountCash;
@override@JsonKey()@OdooFloat(odooName: 'amount_unpaid') final  double amountUnpaid;
@override@JsonKey()@OdooFloat(odooName: 'total_cost_amount') final  double totalCostAmount;
@override@JsonKey()@OdooFloat(odooName: 'margin') final  double margin;
@override@JsonKey()@OdooFloat(odooName: 'margin_percent') final  double marginPercent;
@override@JsonKey()@OdooFloat(odooName: 'retenido_amount') final  double retenidoAmount;
// Approvals (l10n_ec_sale_credit)
@override@JsonKey()@OdooInteger(odooName: 'approval_count') final  int approvalCount;
@override@OdooDateTime(odooName: 'approved_date') final  DateTime? approvedDate;
@override@OdooDateTime(odooName: 'rejected_date') final  DateTime? rejectedDate;
@override@OdooString(odooName: 'rejected_reason') final  String? rejectedReason;
// Collection Session (l10n_ec_collection_box)
@override@OdooMany2One('collection.session', odooName: 'collection_session_id') final  int? collectionSessionId;
@override@OdooMany2One('res.users', odooName: 'collection_user_id') final  int? collectionUserId;
@override@OdooMany2One('res.users', odooName: 'sale_created_user_id') final  int? saleCreatedUserId;
// Dispatch Control (l10n_ec_sale_base)
@override@JsonKey()@OdooBoolean(odooName: 'entregar_solo_pagado') final  bool entregarSoloPagado;
@override@JsonKey()@OdooBoolean(odooName: 'es_para_despacho') final  bool esParaDespacho;
@override@OdooString(odooName: 'nota_adicional') final  String? notaAdicional;
// UUID for offline sync (l10n_ec_collection_box_pos)
@override@OdooString(odooName: 'x_uuid') final  String? xUuid;
// Sync
@override@JsonKey()@OdooLocalOnly() final  bool isSynced;
@override@OdooLocalOnly() final  DateTime? lastSyncDate;
@override@JsonKey()@OdooLocalOnly() final  int syncRetryCount;
@override@OdooLocalOnly() final  DateTime? lastSyncAttempt;
@override@OdooDateTime(odooName: 'write_date', writable: false) final  DateTime? writeDate;
/// Indicates invoice creation was queued offline - prevents modifying payments/withholds
@override@JsonKey()@OdooLocalOnly() final  bool hasQueuedInvoice;

/// Create a copy of SaleOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SaleOrderCopyWith<_SaleOrder> get copyWith => __$SaleOrderCopyWithImpl<_SaleOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SaleOrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SaleOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.orderUuid, orderUuid) || other.orderUuid == orderUuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.state, state) || other.state == state)&&(identical(other.dateOrder, dateOrder) || other.dateOrder == dateOrder)&&(identical(other.validityDate, validityDate) || other.validityDate == validityDate)&&(identical(other.commitmentDate, commitmentDate) || other.commitmentDate == commitmentDate)&&(identical(other.expectedDate, expectedDate) || other.expectedDate == expectedDate)&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.partnerName, partnerName) || other.partnerName == partnerName)&&(identical(other.partnerVat, partnerVat) || other.partnerVat == partnerVat)&&(identical(other.partnerStreet, partnerStreet) || other.partnerStreet == partnerStreet)&&(identical(other.partnerPhone, partnerPhone) || other.partnerPhone == partnerPhone)&&(identical(other.partnerEmail, partnerEmail) || other.partnerEmail == partnerEmail)&&(identical(other.partnerAvatar, partnerAvatar) || other.partnerAvatar == partnerAvatar)&&(identical(other.partnerInvoiceId, partnerInvoiceId) || other.partnerInvoiceId == partnerInvoiceId)&&(identical(other.partnerInvoiceAddress, partnerInvoiceAddress) || other.partnerInvoiceAddress == partnerInvoiceAddress)&&(identical(other.partnerShippingId, partnerShippingId) || other.partnerShippingId == partnerShippingId)&&(identical(other.partnerShippingAddress, partnerShippingAddress) || other.partnerShippingAddress == partnerShippingAddress)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.teamId, teamId) || other.teamId == teamId)&&(identical(other.teamName, teamName) || other.teamName == teamName)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.warehouseId, warehouseId) || other.warehouseId == warehouseId)&&(identical(other.warehouseName, warehouseName) || other.warehouseName == warehouseName)&&(identical(other.pricelistId, pricelistId) || other.pricelistId == pricelistId)&&(identical(other.pricelistName, pricelistName) || other.pricelistName == pricelistName)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.currencySymbol, currencySymbol) || other.currencySymbol == currencySymbol)&&(identical(other.currencyRate, currencyRate) || other.currencyRate == currencyRate)&&(identical(other.paymentTermId, paymentTermId) || other.paymentTermId == paymentTermId)&&(identical(other.paymentTermName, paymentTermName) || other.paymentTermName == paymentTermName)&&(identical(other.isCash, isCash) || other.isCash == isCash)&&(identical(other.isCredit, isCredit) || other.isCredit == isCredit)&&(identical(other.fiscalPositionId, fiscalPositionId) || other.fiscalPositionId == fiscalPositionId)&&(identical(other.fiscalPositionName, fiscalPositionName) || other.fiscalPositionName == fiscalPositionName)&&(identical(other.amountUntaxed, amountUntaxed) || other.amountUntaxed == amountUntaxed)&&(identical(other.amountTax, amountTax) || other.amountTax == amountTax)&&(identical(other.amountTotal, amountTotal) || other.amountTotal == amountTotal)&&(identical(other.amountToInvoice, amountToInvoice) || other.amountToInvoice == amountToInvoice)&&(identical(other.amountInvoiced, amountInvoiced) || other.amountInvoiced == amountInvoiced)&&(identical(other.invoiceStatus, invoiceStatus) || other.invoiceStatus == invoiceStatus)&&(identical(other.invoiceCount, invoiceCount) || other.invoiceCount == invoiceCount)&&(identical(other.note, note) || other.note == note)&&(identical(other.clientOrderRef, clientOrderRef) || other.clientOrderRef == clientOrderRef)&&(identical(other.requireSignature, requireSignature) || other.requireSignature == requireSignature)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.signedBy, signedBy) || other.signedBy == signedBy)&&(identical(other.signedOn, signedOn) || other.signedOn == signedOn)&&(identical(other.requirePayment, requirePayment) || other.requirePayment == requirePayment)&&(identical(other.prepaymentPercent, prepaymentPercent) || other.prepaymentPercent == prepaymentPercent)&&(identical(other.locked, locked) || other.locked == locked)&&(identical(other.isExpired, isExpired) || other.isExpired == isExpired)&&(identical(other.totalDiscountAmount, totalDiscountAmount) || other.totalDiscountAmount == totalDiscountAmount)&&(identical(other.amountUntaxedUndiscounted, amountUntaxedUndiscounted) || other.amountUntaxedUndiscounted == amountUntaxedUndiscounted)&&(identical(other.isFinalConsumer, isFinalConsumer) || other.isFinalConsumer == isFinalConsumer)&&(identical(other.endCustomerName, endCustomerName) || other.endCustomerName == endCustomerName)&&(identical(other.endCustomerPhone, endCustomerPhone) || other.endCustomerPhone == endCustomerPhone)&&(identical(other.endCustomerEmail, endCustomerEmail) || other.endCustomerEmail == endCustomerEmail)&&(identical(other.exceedsFinalConsumerLimit, exceedsFinalConsumerLimit) || other.exceedsFinalConsumerLimit == exceedsFinalConsumerLimit)&&(identical(other.emitirFacturaFechaPosterior, emitirFacturaFechaPosterior) || other.emitirFacturaFechaPosterior == emitirFacturaFechaPosterior)&&(identical(other.fechaFacturar, fechaFacturar) || other.fechaFacturar == fechaFacturar)&&(identical(other.referrerId, referrerId) || other.referrerId == referrerId)&&(identical(other.referrerName, referrerName) || other.referrerName == referrerName)&&(identical(other.tipoCliente, tipoCliente) || other.tipoCliente == tipoCliente)&&(identical(other.canalCliente, canalCliente) || other.canalCliente == canalCliente)&&const DeepCollectionEquality().equals(other._pickingIds, _pickingIds)&&(identical(other.deliveryStatus, deliveryStatus) || other.deliveryStatus == deliveryStatus)&&const DeepCollectionEquality().equals(other._taxTotals, _taxTotals)&&(identical(other.creditExceeded, creditExceeded) || other.creditExceeded == creditExceeded)&&(identical(other.creditCheckBypassed, creditCheckBypassed) || other.creditCheckBypassed == creditCheckBypassed)&&(identical(other.amountCash, amountCash) || other.amountCash == amountCash)&&(identical(other.amountUnpaid, amountUnpaid) || other.amountUnpaid == amountUnpaid)&&(identical(other.totalCostAmount, totalCostAmount) || other.totalCostAmount == totalCostAmount)&&(identical(other.margin, margin) || other.margin == margin)&&(identical(other.marginPercent, marginPercent) || other.marginPercent == marginPercent)&&(identical(other.retenidoAmount, retenidoAmount) || other.retenidoAmount == retenidoAmount)&&(identical(other.approvalCount, approvalCount) || other.approvalCount == approvalCount)&&(identical(other.approvedDate, approvedDate) || other.approvedDate == approvedDate)&&(identical(other.rejectedDate, rejectedDate) || other.rejectedDate == rejectedDate)&&(identical(other.rejectedReason, rejectedReason) || other.rejectedReason == rejectedReason)&&(identical(other.collectionSessionId, collectionSessionId) || other.collectionSessionId == collectionSessionId)&&(identical(other.collectionUserId, collectionUserId) || other.collectionUserId == collectionUserId)&&(identical(other.saleCreatedUserId, saleCreatedUserId) || other.saleCreatedUserId == saleCreatedUserId)&&(identical(other.entregarSoloPagado, entregarSoloPagado) || other.entregarSoloPagado == entregarSoloPagado)&&(identical(other.esParaDespacho, esParaDespacho) || other.esParaDespacho == esParaDespacho)&&(identical(other.notaAdicional, notaAdicional) || other.notaAdicional == notaAdicional)&&(identical(other.xUuid, xUuid) || other.xUuid == xUuid)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.lastSyncDate, lastSyncDate) || other.lastSyncDate == lastSyncDate)&&(identical(other.syncRetryCount, syncRetryCount) || other.syncRetryCount == syncRetryCount)&&(identical(other.lastSyncAttempt, lastSyncAttempt) || other.lastSyncAttempt == lastSyncAttempt)&&(identical(other.writeDate, writeDate) || other.writeDate == writeDate)&&(identical(other.hasQueuedInvoice, hasQueuedInvoice) || other.hasQueuedInvoice == hasQueuedInvoice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,orderUuid,name,state,dateOrder,validityDate,commitmentDate,expectedDate,partnerId,partnerName,partnerVat,partnerStreet,partnerPhone,partnerEmail,partnerAvatar,partnerInvoiceId,partnerInvoiceAddress,partnerShippingId,partnerShippingAddress,userId,userName,teamId,teamName,companyId,companyName,warehouseId,warehouseName,pricelistId,pricelistName,currencyId,currencySymbol,currencyRate,paymentTermId,paymentTermName,isCash,isCredit,fiscalPositionId,fiscalPositionName,amountUntaxed,amountTax,amountTotal,amountToInvoice,amountInvoiced,invoiceStatus,invoiceCount,note,clientOrderRef,requireSignature,signature,signedBy,signedOn,requirePayment,prepaymentPercent,locked,isExpired,totalDiscountAmount,amountUntaxedUndiscounted,isFinalConsumer,endCustomerName,endCustomerPhone,endCustomerEmail,exceedsFinalConsumerLimit,emitirFacturaFechaPosterior,fechaFacturar,referrerId,referrerName,tipoCliente,canalCliente,const DeepCollectionEquality().hash(_pickingIds),deliveryStatus,const DeepCollectionEquality().hash(_taxTotals),creditExceeded,creditCheckBypassed,amountCash,amountUnpaid,totalCostAmount,margin,marginPercent,retenidoAmount,approvalCount,approvedDate,rejectedDate,rejectedReason,collectionSessionId,collectionUserId,saleCreatedUserId,entregarSoloPagado,esParaDespacho,notaAdicional,xUuid,isSynced,lastSyncDate,syncRetryCount,lastSyncAttempt,writeDate,hasQueuedInvoice]);

@override
String toString() {
  return 'SaleOrder(id: $id, orderUuid: $orderUuid, name: $name, state: $state, dateOrder: $dateOrder, validityDate: $validityDate, commitmentDate: $commitmentDate, expectedDate: $expectedDate, partnerId: $partnerId, partnerName: $partnerName, partnerVat: $partnerVat, partnerStreet: $partnerStreet, partnerPhone: $partnerPhone, partnerEmail: $partnerEmail, partnerAvatar: $partnerAvatar, partnerInvoiceId: $partnerInvoiceId, partnerInvoiceAddress: $partnerInvoiceAddress, partnerShippingId: $partnerShippingId, partnerShippingAddress: $partnerShippingAddress, userId: $userId, userName: $userName, teamId: $teamId, teamName: $teamName, companyId: $companyId, companyName: $companyName, warehouseId: $warehouseId, warehouseName: $warehouseName, pricelistId: $pricelistId, pricelistName: $pricelistName, currencyId: $currencyId, currencySymbol: $currencySymbol, currencyRate: $currencyRate, paymentTermId: $paymentTermId, paymentTermName: $paymentTermName, isCash: $isCash, isCredit: $isCredit, fiscalPositionId: $fiscalPositionId, fiscalPositionName: $fiscalPositionName, amountUntaxed: $amountUntaxed, amountTax: $amountTax, amountTotal: $amountTotal, amountToInvoice: $amountToInvoice, amountInvoiced: $amountInvoiced, invoiceStatus: $invoiceStatus, invoiceCount: $invoiceCount, note: $note, clientOrderRef: $clientOrderRef, requireSignature: $requireSignature, signature: $signature, signedBy: $signedBy, signedOn: $signedOn, requirePayment: $requirePayment, prepaymentPercent: $prepaymentPercent, locked: $locked, isExpired: $isExpired, totalDiscountAmount: $totalDiscountAmount, amountUntaxedUndiscounted: $amountUntaxedUndiscounted, isFinalConsumer: $isFinalConsumer, endCustomerName: $endCustomerName, endCustomerPhone: $endCustomerPhone, endCustomerEmail: $endCustomerEmail, exceedsFinalConsumerLimit: $exceedsFinalConsumerLimit, emitirFacturaFechaPosterior: $emitirFacturaFechaPosterior, fechaFacturar: $fechaFacturar, referrerId: $referrerId, referrerName: $referrerName, tipoCliente: $tipoCliente, canalCliente: $canalCliente, pickingIds: $pickingIds, deliveryStatus: $deliveryStatus, taxTotals: $taxTotals, creditExceeded: $creditExceeded, creditCheckBypassed: $creditCheckBypassed, amountCash: $amountCash, amountUnpaid: $amountUnpaid, totalCostAmount: $totalCostAmount, margin: $margin, marginPercent: $marginPercent, retenidoAmount: $retenidoAmount, approvalCount: $approvalCount, approvedDate: $approvedDate, rejectedDate: $rejectedDate, rejectedReason: $rejectedReason, collectionSessionId: $collectionSessionId, collectionUserId: $collectionUserId, saleCreatedUserId: $saleCreatedUserId, entregarSoloPagado: $entregarSoloPagado, esParaDespacho: $esParaDespacho, notaAdicional: $notaAdicional, xUuid: $xUuid, isSynced: $isSynced, lastSyncDate: $lastSyncDate, syncRetryCount: $syncRetryCount, lastSyncAttempt: $lastSyncAttempt, writeDate: $writeDate, hasQueuedInvoice: $hasQueuedInvoice)';
}


}

/// @nodoc
abstract mixin class _$SaleOrderCopyWith<$Res> implements $SaleOrderCopyWith<$Res> {
  factory _$SaleOrderCopyWith(_SaleOrder value, $Res Function(_SaleOrder) _then) = __$SaleOrderCopyWithImpl;
@override @useResult
$Res call({
@OdooId() int id,@OdooLocalOnly() String? orderUuid,@OdooString() String name,@OdooSelection() SaleOrderState state,@OdooDateTime(odooName: 'date_order') DateTime? dateOrder,@OdooDate(odooName: 'validity_date') DateTime? validityDate,@OdooDateTime(odooName: 'commitment_date') DateTime? commitmentDate,@OdooDateTime(odooName: 'expected_date') DateTime? expectedDate,@OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,@OdooMany2OneName(sourceField: 'partner_id') String? partnerName,@OdooString(odooName: 'partner_vat') String? partnerVat,@OdooString(odooName: 'partner_street') String? partnerStreet,@OdooString(odooName: 'partner_phone') String? partnerPhone,@OdooString(odooName: 'partner_email') String? partnerEmail,@OdooString(odooName: 'partner_avatar') String? partnerAvatar,@OdooMany2One('res.partner', odooName: 'partner_invoice_id') int? partnerInvoiceId,@OdooMany2OneName(sourceField: 'partner_invoice_id') String? partnerInvoiceAddress,@OdooMany2One('res.partner', odooName: 'partner_shipping_id') int? partnerShippingId,@OdooMany2OneName(sourceField: 'partner_shipping_id') String? partnerShippingAddress,@OdooMany2One('res.users', odooName: 'user_id') int? userId,@OdooMany2OneName(sourceField: 'user_id') String? userName,@OdooMany2One('crm.team', odooName: 'team_id') int? teamId,@OdooMany2OneName(sourceField: 'team_id') String? teamName,@OdooMany2One('res.company', odooName: 'company_id') int? companyId,@OdooMany2OneName(sourceField: 'company_id') String? companyName,@OdooMany2One('stock.warehouse', odooName: 'warehouse_id') int? warehouseId,@OdooMany2OneName(sourceField: 'warehouse_id') String? warehouseName,@OdooMany2One('product.pricelist', odooName: 'pricelist_id') int? pricelistId,@OdooMany2OneName(sourceField: 'pricelist_id') String? pricelistName,@OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,@OdooString(odooName: 'currency_symbol') String? currencySymbol,@OdooFloat(odooName: 'currency_rate') double currencyRate,@OdooMany2One('account.payment.term', odooName: 'payment_term_id') int? paymentTermId,@OdooMany2OneName(sourceField: 'payment_term_id') String? paymentTermName,@OdooBoolean(odooName: 'is_cash') bool isCash,@OdooBoolean(odooName: 'is_credit') bool isCredit,@OdooMany2One('account.fiscal.position', odooName: 'fiscal_position_id') int? fiscalPositionId,@OdooMany2OneName(sourceField: 'fiscal_position_id') String? fiscalPositionName,@OdooFloat(odooName: 'amount_untaxed') double amountUntaxed,@OdooFloat(odooName: 'amount_tax') double amountTax,@OdooFloat(odooName: 'amount_total') double amountTotal,@OdooFloat(odooName: 'amount_to_invoice') double amountToInvoice,@OdooFloat(odooName: 'amount_invoiced') double amountInvoiced,@OdooSelection(odooName: 'invoice_status') InvoiceStatus invoiceStatus,@OdooInteger(odooName: 'invoice_count') int invoiceCount,@OdooString(odooName: 'note') String? note,@OdooString(odooName: 'client_order_ref') String? clientOrderRef,@OdooBoolean(odooName: 'require_signature') bool requireSignature,@OdooString(odooName: 'signature') String? signature,@OdooString(odooName: 'signed_by') String? signedBy,@OdooDateTime(odooName: 'signed_on') DateTime? signedOn,@OdooBoolean(odooName: 'require_payment') bool requirePayment,@OdooFloat(odooName: 'prepayment_percent') double prepaymentPercent,@OdooBoolean(odooName: 'locked') bool locked,@OdooBoolean(odooName: 'is_expired') bool isExpired,@OdooFloat(odooName: 'total_discount_amount') double totalDiscountAmount,@OdooFloat(odooName: 'total_amount_undiscounted') double amountUntaxedUndiscounted,@OdooBoolean(odooName: 'is_final_consumer') bool isFinalConsumer,@OdooString(odooName: 'end_customer_name') String? endCustomerName,@OdooString(odooName: 'end_customer_phone') String? endCustomerPhone,@OdooString(odooName: 'end_customer_email') String? endCustomerEmail,@OdooBoolean(odooName: 'exceeds_final_consumer_limit') bool exceedsFinalConsumerLimit,@OdooBoolean(odooName: 'emitir_factura_fecha_posterior') bool emitirFacturaFechaPosterior,@OdooDate(odooName: 'fecha_facturar') DateTime? fechaFacturar,@OdooMany2One('res.partner', odooName: 'referrer_id') int? referrerId,@OdooMany2OneName(sourceField: 'referrer_id') String? referrerName,@OdooString(odooName: 'tipo_cliente') String? tipoCliente,@OdooString(odooName: 'canal_cliente') String? canalCliente,@OdooMany2Many('stock.picking', odooName: 'picking_ids') List<int> pickingIds,@OdooString(odooName: 'delivery_status') String? deliveryStatus,@OdooJson(odooName: 'tax_totals') Map<String, dynamic>? taxTotals,@OdooBoolean(odooName: 'credit_exceeded') bool creditExceeded,@OdooBoolean(odooName: 'credit_check_bypassed') bool creditCheckBypassed,@OdooFloat(odooName: 'amount_cash') double amountCash,@OdooFloat(odooName: 'amount_unpaid') double amountUnpaid,@OdooFloat(odooName: 'total_cost_amount') double totalCostAmount,@OdooFloat(odooName: 'margin') double margin,@OdooFloat(odooName: 'margin_percent') double marginPercent,@OdooFloat(odooName: 'retenido_amount') double retenidoAmount,@OdooInteger(odooName: 'approval_count') int approvalCount,@OdooDateTime(odooName: 'approved_date') DateTime? approvedDate,@OdooDateTime(odooName: 'rejected_date') DateTime? rejectedDate,@OdooString(odooName: 'rejected_reason') String? rejectedReason,@OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,@OdooMany2One('res.users', odooName: 'collection_user_id') int? collectionUserId,@OdooMany2One('res.users', odooName: 'sale_created_user_id') int? saleCreatedUserId,@OdooBoolean(odooName: 'entregar_solo_pagado') bool entregarSoloPagado,@OdooBoolean(odooName: 'es_para_despacho') bool esParaDespacho,@OdooString(odooName: 'nota_adicional') String? notaAdicional,@OdooString(odooName: 'x_uuid') String? xUuid,@OdooLocalOnly() bool isSynced,@OdooLocalOnly() DateTime? lastSyncDate,@OdooLocalOnly() int syncRetryCount,@OdooLocalOnly() DateTime? lastSyncAttempt,@OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,@OdooLocalOnly() bool hasQueuedInvoice
});




}
/// @nodoc
class __$SaleOrderCopyWithImpl<$Res>
    implements _$SaleOrderCopyWith<$Res> {
  __$SaleOrderCopyWithImpl(this._self, this._then);

  final _SaleOrder _self;
  final $Res Function(_SaleOrder) _then;

/// Create a copy of SaleOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? orderUuid = freezed,Object? name = null,Object? state = null,Object? dateOrder = freezed,Object? validityDate = freezed,Object? commitmentDate = freezed,Object? expectedDate = freezed,Object? partnerId = freezed,Object? partnerName = freezed,Object? partnerVat = freezed,Object? partnerStreet = freezed,Object? partnerPhone = freezed,Object? partnerEmail = freezed,Object? partnerAvatar = freezed,Object? partnerInvoiceId = freezed,Object? partnerInvoiceAddress = freezed,Object? partnerShippingId = freezed,Object? partnerShippingAddress = freezed,Object? userId = freezed,Object? userName = freezed,Object? teamId = freezed,Object? teamName = freezed,Object? companyId = freezed,Object? companyName = freezed,Object? warehouseId = freezed,Object? warehouseName = freezed,Object? pricelistId = freezed,Object? pricelistName = freezed,Object? currencyId = freezed,Object? currencySymbol = freezed,Object? currencyRate = null,Object? paymentTermId = freezed,Object? paymentTermName = freezed,Object? isCash = null,Object? isCredit = null,Object? fiscalPositionId = freezed,Object? fiscalPositionName = freezed,Object? amountUntaxed = null,Object? amountTax = null,Object? amountTotal = null,Object? amountToInvoice = null,Object? amountInvoiced = null,Object? invoiceStatus = null,Object? invoiceCount = null,Object? note = freezed,Object? clientOrderRef = freezed,Object? requireSignature = null,Object? signature = freezed,Object? signedBy = freezed,Object? signedOn = freezed,Object? requirePayment = null,Object? prepaymentPercent = null,Object? locked = null,Object? isExpired = null,Object? totalDiscountAmount = null,Object? amountUntaxedUndiscounted = null,Object? isFinalConsumer = null,Object? endCustomerName = freezed,Object? endCustomerPhone = freezed,Object? endCustomerEmail = freezed,Object? exceedsFinalConsumerLimit = null,Object? emitirFacturaFechaPosterior = null,Object? fechaFacturar = freezed,Object? referrerId = freezed,Object? referrerName = freezed,Object? tipoCliente = freezed,Object? canalCliente = freezed,Object? pickingIds = null,Object? deliveryStatus = freezed,Object? taxTotals = freezed,Object? creditExceeded = null,Object? creditCheckBypassed = null,Object? amountCash = null,Object? amountUnpaid = null,Object? totalCostAmount = null,Object? margin = null,Object? marginPercent = null,Object? retenidoAmount = null,Object? approvalCount = null,Object? approvedDate = freezed,Object? rejectedDate = freezed,Object? rejectedReason = freezed,Object? collectionSessionId = freezed,Object? collectionUserId = freezed,Object? saleCreatedUserId = freezed,Object? entregarSoloPagado = null,Object? esParaDespacho = null,Object? notaAdicional = freezed,Object? xUuid = freezed,Object? isSynced = null,Object? lastSyncDate = freezed,Object? syncRetryCount = null,Object? lastSyncAttempt = freezed,Object? writeDate = freezed,Object? hasQueuedInvoice = null,}) {
  return _then(_SaleOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderUuid: freezed == orderUuid ? _self.orderUuid : orderUuid // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as SaleOrderState,dateOrder: freezed == dateOrder ? _self.dateOrder : dateOrder // ignore: cast_nullable_to_non_nullable
as DateTime?,validityDate: freezed == validityDate ? _self.validityDate : validityDate // ignore: cast_nullable_to_non_nullable
as DateTime?,commitmentDate: freezed == commitmentDate ? _self.commitmentDate : commitmentDate // ignore: cast_nullable_to_non_nullable
as DateTime?,expectedDate: freezed == expectedDate ? _self.expectedDate : expectedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,partnerId: freezed == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as int?,partnerName: freezed == partnerName ? _self.partnerName : partnerName // ignore: cast_nullable_to_non_nullable
as String?,partnerVat: freezed == partnerVat ? _self.partnerVat : partnerVat // ignore: cast_nullable_to_non_nullable
as String?,partnerStreet: freezed == partnerStreet ? _self.partnerStreet : partnerStreet // ignore: cast_nullable_to_non_nullable
as String?,partnerPhone: freezed == partnerPhone ? _self.partnerPhone : partnerPhone // ignore: cast_nullable_to_non_nullable
as String?,partnerEmail: freezed == partnerEmail ? _self.partnerEmail : partnerEmail // ignore: cast_nullable_to_non_nullable
as String?,partnerAvatar: freezed == partnerAvatar ? _self.partnerAvatar : partnerAvatar // ignore: cast_nullable_to_non_nullable
as String?,partnerInvoiceId: freezed == partnerInvoiceId ? _self.partnerInvoiceId : partnerInvoiceId // ignore: cast_nullable_to_non_nullable
as int?,partnerInvoiceAddress: freezed == partnerInvoiceAddress ? _self.partnerInvoiceAddress : partnerInvoiceAddress // ignore: cast_nullable_to_non_nullable
as String?,partnerShippingId: freezed == partnerShippingId ? _self.partnerShippingId : partnerShippingId // ignore: cast_nullable_to_non_nullable
as int?,partnerShippingAddress: freezed == partnerShippingAddress ? _self.partnerShippingAddress : partnerShippingAddress // ignore: cast_nullable_to_non_nullable
as String?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int?,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,teamId: freezed == teamId ? _self.teamId : teamId // ignore: cast_nullable_to_non_nullable
as int?,teamName: freezed == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String?,companyId: freezed == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int?,companyName: freezed == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String?,warehouseId: freezed == warehouseId ? _self.warehouseId : warehouseId // ignore: cast_nullable_to_non_nullable
as int?,warehouseName: freezed == warehouseName ? _self.warehouseName : warehouseName // ignore: cast_nullable_to_non_nullable
as String?,pricelistId: freezed == pricelistId ? _self.pricelistId : pricelistId // ignore: cast_nullable_to_non_nullable
as int?,pricelistName: freezed == pricelistName ? _self.pricelistName : pricelistName // ignore: cast_nullable_to_non_nullable
as String?,currencyId: freezed == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as int?,currencySymbol: freezed == currencySymbol ? _self.currencySymbol : currencySymbol // ignore: cast_nullable_to_non_nullable
as String?,currencyRate: null == currencyRate ? _self.currencyRate : currencyRate // ignore: cast_nullable_to_non_nullable
as double,paymentTermId: freezed == paymentTermId ? _self.paymentTermId : paymentTermId // ignore: cast_nullable_to_non_nullable
as int?,paymentTermName: freezed == paymentTermName ? _self.paymentTermName : paymentTermName // ignore: cast_nullable_to_non_nullable
as String?,isCash: null == isCash ? _self.isCash : isCash // ignore: cast_nullable_to_non_nullable
as bool,isCredit: null == isCredit ? _self.isCredit : isCredit // ignore: cast_nullable_to_non_nullable
as bool,fiscalPositionId: freezed == fiscalPositionId ? _self.fiscalPositionId : fiscalPositionId // ignore: cast_nullable_to_non_nullable
as int?,fiscalPositionName: freezed == fiscalPositionName ? _self.fiscalPositionName : fiscalPositionName // ignore: cast_nullable_to_non_nullable
as String?,amountUntaxed: null == amountUntaxed ? _self.amountUntaxed : amountUntaxed // ignore: cast_nullable_to_non_nullable
as double,amountTax: null == amountTax ? _self.amountTax : amountTax // ignore: cast_nullable_to_non_nullable
as double,amountTotal: null == amountTotal ? _self.amountTotal : amountTotal // ignore: cast_nullable_to_non_nullable
as double,amountToInvoice: null == amountToInvoice ? _self.amountToInvoice : amountToInvoice // ignore: cast_nullable_to_non_nullable
as double,amountInvoiced: null == amountInvoiced ? _self.amountInvoiced : amountInvoiced // ignore: cast_nullable_to_non_nullable
as double,invoiceStatus: null == invoiceStatus ? _self.invoiceStatus : invoiceStatus // ignore: cast_nullable_to_non_nullable
as InvoiceStatus,invoiceCount: null == invoiceCount ? _self.invoiceCount : invoiceCount // ignore: cast_nullable_to_non_nullable
as int,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,clientOrderRef: freezed == clientOrderRef ? _self.clientOrderRef : clientOrderRef // ignore: cast_nullable_to_non_nullable
as String?,requireSignature: null == requireSignature ? _self.requireSignature : requireSignature // ignore: cast_nullable_to_non_nullable
as bool,signature: freezed == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String?,signedBy: freezed == signedBy ? _self.signedBy : signedBy // ignore: cast_nullable_to_non_nullable
as String?,signedOn: freezed == signedOn ? _self.signedOn : signedOn // ignore: cast_nullable_to_non_nullable
as DateTime?,requirePayment: null == requirePayment ? _self.requirePayment : requirePayment // ignore: cast_nullable_to_non_nullable
as bool,prepaymentPercent: null == prepaymentPercent ? _self.prepaymentPercent : prepaymentPercent // ignore: cast_nullable_to_non_nullable
as double,locked: null == locked ? _self.locked : locked // ignore: cast_nullable_to_non_nullable
as bool,isExpired: null == isExpired ? _self.isExpired : isExpired // ignore: cast_nullable_to_non_nullable
as bool,totalDiscountAmount: null == totalDiscountAmount ? _self.totalDiscountAmount : totalDiscountAmount // ignore: cast_nullable_to_non_nullable
as double,amountUntaxedUndiscounted: null == amountUntaxedUndiscounted ? _self.amountUntaxedUndiscounted : amountUntaxedUndiscounted // ignore: cast_nullable_to_non_nullable
as double,isFinalConsumer: null == isFinalConsumer ? _self.isFinalConsumer : isFinalConsumer // ignore: cast_nullable_to_non_nullable
as bool,endCustomerName: freezed == endCustomerName ? _self.endCustomerName : endCustomerName // ignore: cast_nullable_to_non_nullable
as String?,endCustomerPhone: freezed == endCustomerPhone ? _self.endCustomerPhone : endCustomerPhone // ignore: cast_nullable_to_non_nullable
as String?,endCustomerEmail: freezed == endCustomerEmail ? _self.endCustomerEmail : endCustomerEmail // ignore: cast_nullable_to_non_nullable
as String?,exceedsFinalConsumerLimit: null == exceedsFinalConsumerLimit ? _self.exceedsFinalConsumerLimit : exceedsFinalConsumerLimit // ignore: cast_nullable_to_non_nullable
as bool,emitirFacturaFechaPosterior: null == emitirFacturaFechaPosterior ? _self.emitirFacturaFechaPosterior : emitirFacturaFechaPosterior // ignore: cast_nullable_to_non_nullable
as bool,fechaFacturar: freezed == fechaFacturar ? _self.fechaFacturar : fechaFacturar // ignore: cast_nullable_to_non_nullable
as DateTime?,referrerId: freezed == referrerId ? _self.referrerId : referrerId // ignore: cast_nullable_to_non_nullable
as int?,referrerName: freezed == referrerName ? _self.referrerName : referrerName // ignore: cast_nullable_to_non_nullable
as String?,tipoCliente: freezed == tipoCliente ? _self.tipoCliente : tipoCliente // ignore: cast_nullable_to_non_nullable
as String?,canalCliente: freezed == canalCliente ? _self.canalCliente : canalCliente // ignore: cast_nullable_to_non_nullable
as String?,pickingIds: null == pickingIds ? _self._pickingIds : pickingIds // ignore: cast_nullable_to_non_nullable
as List<int>,deliveryStatus: freezed == deliveryStatus ? _self.deliveryStatus : deliveryStatus // ignore: cast_nullable_to_non_nullable
as String?,taxTotals: freezed == taxTotals ? _self._taxTotals : taxTotals // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,creditExceeded: null == creditExceeded ? _self.creditExceeded : creditExceeded // ignore: cast_nullable_to_non_nullable
as bool,creditCheckBypassed: null == creditCheckBypassed ? _self.creditCheckBypassed : creditCheckBypassed // ignore: cast_nullable_to_non_nullable
as bool,amountCash: null == amountCash ? _self.amountCash : amountCash // ignore: cast_nullable_to_non_nullable
as double,amountUnpaid: null == amountUnpaid ? _self.amountUnpaid : amountUnpaid // ignore: cast_nullable_to_non_nullable
as double,totalCostAmount: null == totalCostAmount ? _self.totalCostAmount : totalCostAmount // ignore: cast_nullable_to_non_nullable
as double,margin: null == margin ? _self.margin : margin // ignore: cast_nullable_to_non_nullable
as double,marginPercent: null == marginPercent ? _self.marginPercent : marginPercent // ignore: cast_nullable_to_non_nullable
as double,retenidoAmount: null == retenidoAmount ? _self.retenidoAmount : retenidoAmount // ignore: cast_nullable_to_non_nullable
as double,approvalCount: null == approvalCount ? _self.approvalCount : approvalCount // ignore: cast_nullable_to_non_nullable
as int,approvedDate: freezed == approvedDate ? _self.approvedDate : approvedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedDate: freezed == rejectedDate ? _self.rejectedDate : rejectedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rejectedReason: freezed == rejectedReason ? _self.rejectedReason : rejectedReason // ignore: cast_nullable_to_non_nullable
as String?,collectionSessionId: freezed == collectionSessionId ? _self.collectionSessionId : collectionSessionId // ignore: cast_nullable_to_non_nullable
as int?,collectionUserId: freezed == collectionUserId ? _self.collectionUserId : collectionUserId // ignore: cast_nullable_to_non_nullable
as int?,saleCreatedUserId: freezed == saleCreatedUserId ? _self.saleCreatedUserId : saleCreatedUserId // ignore: cast_nullable_to_non_nullable
as int?,entregarSoloPagado: null == entregarSoloPagado ? _self.entregarSoloPagado : entregarSoloPagado // ignore: cast_nullable_to_non_nullable
as bool,esParaDespacho: null == esParaDespacho ? _self.esParaDespacho : esParaDespacho // ignore: cast_nullable_to_non_nullable
as bool,notaAdicional: freezed == notaAdicional ? _self.notaAdicional : notaAdicional // ignore: cast_nullable_to_non_nullable
as String?,xUuid: freezed == xUuid ? _self.xUuid : xUuid // ignore: cast_nullable_to_non_nullable
as String?,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncDate: freezed == lastSyncDate ? _self.lastSyncDate : lastSyncDate // ignore: cast_nullable_to_non_nullable
as DateTime?,syncRetryCount: null == syncRetryCount ? _self.syncRetryCount : syncRetryCount // ignore: cast_nullable_to_non_nullable
as int,lastSyncAttempt: freezed == lastSyncAttempt ? _self.lastSyncAttempt : lastSyncAttempt // ignore: cast_nullable_to_non_nullable
as DateTime?,writeDate: freezed == writeDate ? _self.writeDate : writeDate // ignore: cast_nullable_to_non_nullable
as DateTime?,hasQueuedInvoice: null == hasQueuedInvoice ? _self.hasQueuedInvoice : hasQueuedInvoice // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
