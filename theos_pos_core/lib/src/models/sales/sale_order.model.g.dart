// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_order.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SaleOrder _$SaleOrderFromJson(Map<String, dynamic> json) => _SaleOrder(
  id: (json['id'] as num).toInt(),
  orderUuid: json['orderUuid'] as String?,
  name: json['name'] as String,
  state: $enumDecode(_$SaleOrderStateEnumMap, json['state']),
  dateOrder: json['dateOrder'] == null
      ? null
      : DateTime.parse(json['dateOrder'] as String),
  validityDate: json['validityDate'] == null
      ? null
      : DateTime.parse(json['validityDate'] as String),
  commitmentDate: json['commitmentDate'] == null
      ? null
      : DateTime.parse(json['commitmentDate'] as String),
  expectedDate: json['expectedDate'] == null
      ? null
      : DateTime.parse(json['expectedDate'] as String),
  partnerId: (json['partnerId'] as num?)?.toInt(),
  partnerName: json['partnerName'] as String?,
  partnerVat: json['partnerVat'] as String?,
  partnerStreet: json['partnerStreet'] as String?,
  partnerPhone: json['partnerPhone'] as String?,
  partnerEmail: json['partnerEmail'] as String?,
  partnerAvatar: json['partnerAvatar'] as String?,
  partnerInvoiceId: (json['partnerInvoiceId'] as num?)?.toInt(),
  partnerInvoiceAddress: json['partnerInvoiceAddress'] as String?,
  partnerShippingId: (json['partnerShippingId'] as num?)?.toInt(),
  partnerShippingAddress: json['partnerShippingAddress'] as String?,
  userId: (json['userId'] as num?)?.toInt(),
  userName: json['userName'] as String?,
  teamId: (json['teamId'] as num?)?.toInt(),
  teamName: json['teamName'] as String?,
  companyId: (json['companyId'] as num?)?.toInt(),
  companyName: json['companyName'] as String?,
  warehouseId: (json['warehouseId'] as num?)?.toInt(),
  warehouseName: json['warehouseName'] as String?,
  pricelistId: (json['pricelistId'] as num?)?.toInt(),
  pricelistName: json['pricelistName'] as String?,
  currencyId: (json['currencyId'] as num?)?.toInt(),
  currencySymbol: json['currencySymbol'] as String?,
  currencyRate: (json['currencyRate'] as num?)?.toDouble() ?? 1.0,
  paymentTermId: (json['paymentTermId'] as num?)?.toInt(),
  paymentTermName: json['paymentTermName'] as String?,
  isCash: json['isCash'] as bool? ?? true,
  isCredit: json['isCredit'] as bool? ?? false,
  fiscalPositionId: (json['fiscalPositionId'] as num?)?.toInt(),
  fiscalPositionName: json['fiscalPositionName'] as String?,
  amountUntaxed: (json['amountUntaxed'] as num?)?.toDouble() ?? 0.0,
  amountTax: (json['amountTax'] as num?)?.toDouble() ?? 0.0,
  amountTotal: (json['amountTotal'] as num?)?.toDouble() ?? 0.0,
  amountToInvoice: (json['amountToInvoice'] as num?)?.toDouble() ?? 0.0,
  amountInvoiced: (json['amountInvoiced'] as num?)?.toDouble() ?? 0.0,
  invoiceStatus:
      $enumDecodeNullable(_$InvoiceStatusEnumMap, json['invoiceStatus']) ??
      InvoiceStatus.no,
  invoiceCount: (json['invoiceCount'] as num?)?.toInt() ?? 0,
  note: json['note'] as String?,
  clientOrderRef: json['clientOrderRef'] as String?,
  requireSignature: json['requireSignature'] as bool? ?? false,
  signature: json['signature'] as String?,
  signedBy: json['signedBy'] as String?,
  signedOn: json['signedOn'] == null
      ? null
      : DateTime.parse(json['signedOn'] as String),
  requirePayment: json['requirePayment'] as bool? ?? false,
  prepaymentPercent: (json['prepaymentPercent'] as num?)?.toDouble() ?? 0.0,
  locked: json['locked'] as bool? ?? false,
  isExpired: json['isExpired'] as bool? ?? false,
  totalDiscountAmount: (json['totalDiscountAmount'] as num?)?.toDouble() ?? 0.0,
  amountUntaxedUndiscounted:
      (json['amountUntaxedUndiscounted'] as num?)?.toDouble() ?? 0.0,
  isFinalConsumer: json['isFinalConsumer'] as bool? ?? false,
  endCustomerName: json['endCustomerName'] as String?,
  endCustomerPhone: json['endCustomerPhone'] as String?,
  endCustomerEmail: json['endCustomerEmail'] as String?,
  exceedsFinalConsumerLimit:
      json['exceedsFinalConsumerLimit'] as bool? ?? false,
  emitirFacturaFechaPosterior:
      json['emitirFacturaFechaPosterior'] as bool? ?? false,
  fechaFacturar: json['fechaFacturar'] == null
      ? null
      : DateTime.parse(json['fechaFacturar'] as String),
  referrerId: (json['referrerId'] as num?)?.toInt(),
  referrerName: json['referrerName'] as String?,
  tipoCliente: json['tipoCliente'] as String?,
  canalCliente: json['canalCliente'] as String?,
  pickingIds:
      (json['pickingIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const <int>[],
  deliveryStatus: json['deliveryStatus'] as String?,
  taxTotals: json['taxTotals'] as Map<String, dynamic>?,
  creditExceeded: json['creditExceeded'] as bool? ?? false,
  creditCheckBypassed: json['creditCheckBypassed'] as bool? ?? false,
  amountCash: (json['amountCash'] as num?)?.toDouble() ?? 0.0,
  amountUnpaid: (json['amountUnpaid'] as num?)?.toDouble() ?? 0.0,
  totalCostAmount: (json['totalCostAmount'] as num?)?.toDouble() ?? 0.0,
  margin: (json['margin'] as num?)?.toDouble() ?? 0.0,
  marginPercent: (json['marginPercent'] as num?)?.toDouble() ?? 0.0,
  retenidoAmount: (json['retenidoAmount'] as num?)?.toDouble() ?? 0.0,
  approvalCount: (json['approvalCount'] as num?)?.toInt() ?? 0,
  approvedDate: json['approvedDate'] == null
      ? null
      : DateTime.parse(json['approvedDate'] as String),
  rejectedDate: json['rejectedDate'] == null
      ? null
      : DateTime.parse(json['rejectedDate'] as String),
  rejectedReason: json['rejectedReason'] as String?,
  collectionSessionId: (json['collectionSessionId'] as num?)?.toInt(),
  collectionUserId: (json['collectionUserId'] as num?)?.toInt(),
  saleCreatedUserId: (json['saleCreatedUserId'] as num?)?.toInt(),
  entregarSoloPagado: json['entregarSoloPagado'] as bool? ?? false,
  esParaDespacho: json['esParaDespacho'] as bool? ?? false,
  notaAdicional: json['notaAdicional'] as String?,
  xUuid: json['xUuid'] as String?,
  isSynced: json['isSynced'] as bool? ?? false,
  lastSyncDate: json['lastSyncDate'] == null
      ? null
      : DateTime.parse(json['lastSyncDate'] as String),
  syncRetryCount: (json['syncRetryCount'] as num?)?.toInt() ?? 0,
  lastSyncAttempt: json['lastSyncAttempt'] == null
      ? null
      : DateTime.parse(json['lastSyncAttempt'] as String),
  writeDate: json['writeDate'] == null
      ? null
      : DateTime.parse(json['writeDate'] as String),
  hasQueuedInvoice: json['hasQueuedInvoice'] as bool? ?? false,
);

Map<String, dynamic> _$SaleOrderToJson(_SaleOrder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'orderUuid': instance.orderUuid,
      'name': instance.name,
      'state': _$SaleOrderStateEnumMap[instance.state]!,
      'dateOrder': instance.dateOrder?.toIso8601String(),
      'validityDate': instance.validityDate?.toIso8601String(),
      'commitmentDate': instance.commitmentDate?.toIso8601String(),
      'expectedDate': instance.expectedDate?.toIso8601String(),
      'partnerId': instance.partnerId,
      'partnerName': instance.partnerName,
      'partnerVat': instance.partnerVat,
      'partnerStreet': instance.partnerStreet,
      'partnerPhone': instance.partnerPhone,
      'partnerEmail': instance.partnerEmail,
      'partnerAvatar': instance.partnerAvatar,
      'partnerInvoiceId': instance.partnerInvoiceId,
      'partnerInvoiceAddress': instance.partnerInvoiceAddress,
      'partnerShippingId': instance.partnerShippingId,
      'partnerShippingAddress': instance.partnerShippingAddress,
      'userId': instance.userId,
      'userName': instance.userName,
      'teamId': instance.teamId,
      'teamName': instance.teamName,
      'companyId': instance.companyId,
      'companyName': instance.companyName,
      'warehouseId': instance.warehouseId,
      'warehouseName': instance.warehouseName,
      'pricelistId': instance.pricelistId,
      'pricelistName': instance.pricelistName,
      'currencyId': instance.currencyId,
      'currencySymbol': instance.currencySymbol,
      'currencyRate': instance.currencyRate,
      'paymentTermId': instance.paymentTermId,
      'paymentTermName': instance.paymentTermName,
      'isCash': instance.isCash,
      'isCredit': instance.isCredit,
      'fiscalPositionId': instance.fiscalPositionId,
      'fiscalPositionName': instance.fiscalPositionName,
      'amountUntaxed': instance.amountUntaxed,
      'amountTax': instance.amountTax,
      'amountTotal': instance.amountTotal,
      'amountToInvoice': instance.amountToInvoice,
      'amountInvoiced': instance.amountInvoiced,
      'invoiceStatus': _$InvoiceStatusEnumMap[instance.invoiceStatus]!,
      'invoiceCount': instance.invoiceCount,
      'note': instance.note,
      'clientOrderRef': instance.clientOrderRef,
      'requireSignature': instance.requireSignature,
      'signature': instance.signature,
      'signedBy': instance.signedBy,
      'signedOn': instance.signedOn?.toIso8601String(),
      'requirePayment': instance.requirePayment,
      'prepaymentPercent': instance.prepaymentPercent,
      'locked': instance.locked,
      'isExpired': instance.isExpired,
      'totalDiscountAmount': instance.totalDiscountAmount,
      'amountUntaxedUndiscounted': instance.amountUntaxedUndiscounted,
      'isFinalConsumer': instance.isFinalConsumer,
      'endCustomerName': instance.endCustomerName,
      'endCustomerPhone': instance.endCustomerPhone,
      'endCustomerEmail': instance.endCustomerEmail,
      'exceedsFinalConsumerLimit': instance.exceedsFinalConsumerLimit,
      'emitirFacturaFechaPosterior': instance.emitirFacturaFechaPosterior,
      'fechaFacturar': instance.fechaFacturar?.toIso8601String(),
      'referrerId': instance.referrerId,
      'referrerName': instance.referrerName,
      'tipoCliente': instance.tipoCliente,
      'canalCliente': instance.canalCliente,
      'pickingIds': instance.pickingIds,
      'deliveryStatus': instance.deliveryStatus,
      'taxTotals': instance.taxTotals,
      'creditExceeded': instance.creditExceeded,
      'creditCheckBypassed': instance.creditCheckBypassed,
      'amountCash': instance.amountCash,
      'amountUnpaid': instance.amountUnpaid,
      'totalCostAmount': instance.totalCostAmount,
      'margin': instance.margin,
      'marginPercent': instance.marginPercent,
      'retenidoAmount': instance.retenidoAmount,
      'approvalCount': instance.approvalCount,
      'approvedDate': instance.approvedDate?.toIso8601String(),
      'rejectedDate': instance.rejectedDate?.toIso8601String(),
      'rejectedReason': instance.rejectedReason,
      'collectionSessionId': instance.collectionSessionId,
      'collectionUserId': instance.collectionUserId,
      'saleCreatedUserId': instance.saleCreatedUserId,
      'entregarSoloPagado': instance.entregarSoloPagado,
      'esParaDespacho': instance.esParaDespacho,
      'notaAdicional': instance.notaAdicional,
      'xUuid': instance.xUuid,
      'isSynced': instance.isSynced,
      'lastSyncDate': instance.lastSyncDate?.toIso8601String(),
      'syncRetryCount': instance.syncRetryCount,
      'lastSyncAttempt': instance.lastSyncAttempt?.toIso8601String(),
      'writeDate': instance.writeDate?.toIso8601String(),
      'hasQueuedInvoice': instance.hasQueuedInvoice,
    };

const _$SaleOrderStateEnumMap = {
  SaleOrderState.draft: 'draft',
  SaleOrderState.sent: 'sent',
  SaleOrderState.waitingApproval: 'waiting_approval',
  SaleOrderState.approved: 'approved',
  SaleOrderState.rejected: 'rejected',
  SaleOrderState.sale: 'sale',
  SaleOrderState.done: 'done',
  SaleOrderState.cancel: 'cancel',
};

const _$InvoiceStatusEnumMap = {
  InvoiceStatus.no: 'no',
  InvoiceStatus.toInvoice: 'to invoice',
  InvoiceStatus.invoiced: 'invoiced',
  InvoiceStatus.upselling: 'upselling',
};

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for SaleOrder.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: sale.order
class SaleOrderManager extends OdooModelManager<SaleOrder>
    with GenericDriftOperations<SaleOrder> {
  @override
  String get odooModel => 'sale.order';

  @override
  String get tableName => 'sale_order';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'state',
    'date_order',
    'validity_date',
    'commitment_date',
    'expected_date',
    'partner_id',
    'partner_vat',
    'partner_street',
    'partner_phone',
    'partner_email',
    'partner_avatar',
    'partner_invoice_id',
    'partner_shipping_id',
    'user_id',
    'team_id',
    'company_id',
    'warehouse_id',
    'pricelist_id',
    'currency_id',
    'currency_symbol',
    'currency_rate',
    'payment_term_id',
    'is_cash',
    'is_credit',
    'fiscal_position_id',
    'amount_untaxed',
    'amount_tax',
    'amount_total',
    'amount_to_invoice',
    'amount_invoiced',
    'invoice_status',
    'invoice_count',
    'note',
    'client_order_ref',
    'require_signature',
    'signature',
    'signed_by',
    'signed_on',
    'require_payment',
    'prepayment_percent',
    'locked',
    'is_expired',
    'total_discount_amount',
    'total_amount_undiscounted',
    'is_final_consumer',
    'end_customer_name',
    'end_customer_phone',
    'end_customer_email',
    'exceeds_final_consumer_limit',
    'emitir_factura_fecha_posterior',
    'fecha_facturar',
    'referrer_id',
    'tipo_cliente',
    'canal_cliente',
    'picking_ids',
    'delivery_status',
    'tax_totals',
    'credit_exceeded',
    'credit_check_bypassed',
    'amount_cash',
    'amount_unpaid',
    'total_cost_amount',
    'margin',
    'margin_percent',
    'retenido_amount',
    'approval_count',
    'approved_date',
    'rejected_date',
    'rejected_reason',
    'collection_session_id',
    'collection_user_id',
    'sale_created_user_id',
    'entregar_solo_pagado',
    'es_para_despacho',
    'nota_adicional',
    'x_uuid',
    'write_date',
  ];

  @override
  SaleOrder fromOdoo(Map<String, dynamic> data) {
    return SaleOrder(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      state: SaleOrderState.values.firstWhere(
        (e) => e.code == parseOdooSelection(data['state']),
        orElse: () => SaleOrderState.values.first,
      ),
      dateOrder: parseOdooDateTime(data['date_order']),
      validityDate: parseOdooDate(data['validity_date']),
      commitmentDate: parseOdooDateTime(data['commitment_date']),
      expectedDate: parseOdooDateTime(data['expected_date']),
      partnerId: extractMany2oneId(data['partner_id']),
      partnerName: extractMany2oneName(data['partner_id']),
      partnerVat: parseOdooString(data['partner_vat']),
      partnerStreet: parseOdooString(data['partner_street']),
      partnerPhone: parseOdooString(data['partner_phone']),
      partnerEmail: parseOdooString(data['partner_email']),
      partnerAvatar: parseOdooString(data['partner_avatar']),
      partnerInvoiceId: extractMany2oneId(data['partner_invoice_id']),
      partnerInvoiceAddress: extractMany2oneName(data['partner_invoice_id']),
      partnerShippingId: extractMany2oneId(data['partner_shipping_id']),
      partnerShippingAddress: extractMany2oneName(data['partner_shipping_id']),
      userId: extractMany2oneId(data['user_id']),
      userName: extractMany2oneName(data['user_id']),
      teamId: extractMany2oneId(data['team_id']),
      teamName: extractMany2oneName(data['team_id']),
      companyId: extractMany2oneId(data['company_id']),
      companyName: extractMany2oneName(data['company_id']),
      warehouseId: extractMany2oneId(data['warehouse_id']),
      warehouseName: extractMany2oneName(data['warehouse_id']),
      pricelistId: extractMany2oneId(data['pricelist_id']),
      pricelistName: extractMany2oneName(data['pricelist_id']),
      currencyId: extractMany2oneId(data['currency_id']),
      currencySymbol: parseOdooString(data['currency_symbol']),
      currencyRate: parseOdooDouble(data['currency_rate']) ?? 0.0,
      paymentTermId: extractMany2oneId(data['payment_term_id']),
      paymentTermName: extractMany2oneName(data['payment_term_id']),
      isCash: parseOdooBool(data['is_cash']),
      isCredit: parseOdooBool(data['is_credit']),
      fiscalPositionId: extractMany2oneId(data['fiscal_position_id']),
      fiscalPositionName: extractMany2oneName(data['fiscal_position_id']),
      amountUntaxed: parseOdooDouble(data['amount_untaxed']) ?? 0.0,
      amountTax: parseOdooDouble(data['amount_tax']) ?? 0.0,
      amountTotal: parseOdooDouble(data['amount_total']) ?? 0.0,
      amountToInvoice: parseOdooDouble(data['amount_to_invoice']) ?? 0.0,
      amountInvoiced: parseOdooDouble(data['amount_invoiced']) ?? 0.0,
      invoiceStatus: InvoiceStatus.values.firstWhere(
        (e) => e.code == parseOdooSelection(data['invoice_status']),
        orElse: () => InvoiceStatus.values.first,
      ),
      invoiceCount: parseOdooInt(data['invoice_count']) ?? 0,
      note: parseOdooString(data['note']),
      clientOrderRef: parseOdooString(data['client_order_ref']),
      requireSignature: parseOdooBool(data['require_signature']),
      signature: parseOdooString(data['signature']),
      signedBy: parseOdooString(data['signed_by']),
      signedOn: parseOdooDateTime(data['signed_on']),
      requirePayment: parseOdooBool(data['require_payment']),
      prepaymentPercent: parseOdooDouble(data['prepayment_percent']) ?? 0.0,
      locked: parseOdooBool(data['locked']),
      isExpired: parseOdooBool(data['is_expired']),
      totalDiscountAmount:
          parseOdooDouble(data['total_discount_amount']) ?? 0.0,
      amountUntaxedUndiscounted:
          parseOdooDouble(data['total_amount_undiscounted']) ?? 0.0,
      isFinalConsumer: parseOdooBool(data['is_final_consumer']),
      endCustomerName: parseOdooString(data['end_customer_name']),
      endCustomerPhone: parseOdooString(data['end_customer_phone']),
      endCustomerEmail: parseOdooString(data['end_customer_email']),
      exceedsFinalConsumerLimit: parseOdooBool(
        data['exceeds_final_consumer_limit'],
      ),
      emitirFacturaFechaPosterior: parseOdooBool(
        data['emitir_factura_fecha_posterior'],
      ),
      fechaFacturar: parseOdooDate(data['fecha_facturar']),
      referrerId: extractMany2oneId(data['referrer_id']),
      referrerName: extractMany2oneName(data['referrer_id']),
      tipoCliente: parseOdooString(data['tipo_cliente']),
      canalCliente: parseOdooString(data['canal_cliente']),
      pickingIds: extractMany2manyIds(data['picking_ids']),
      deliveryStatus: parseOdooString(data['delivery_status']),
      taxTotals: parseOdooJson(data['tax_totals']),
      creditExceeded: parseOdooBool(data['credit_exceeded']),
      creditCheckBypassed: parseOdooBool(data['credit_check_bypassed']),
      amountCash: parseOdooDouble(data['amount_cash']) ?? 0.0,
      amountUnpaid: parseOdooDouble(data['amount_unpaid']) ?? 0.0,
      totalCostAmount: parseOdooDouble(data['total_cost_amount']) ?? 0.0,
      margin: parseOdooDouble(data['margin']) ?? 0.0,
      marginPercent: parseOdooDouble(data['margin_percent']) ?? 0.0,
      retenidoAmount: parseOdooDouble(data['retenido_amount']) ?? 0.0,
      approvalCount: parseOdooInt(data['approval_count']) ?? 0,
      approvedDate: parseOdooDateTime(data['approved_date']),
      rejectedDate: parseOdooDateTime(data['rejected_date']),
      rejectedReason: parseOdooString(data['rejected_reason']),
      collectionSessionId: extractMany2oneId(data['collection_session_id']),
      collectionUserId: extractMany2oneId(data['collection_user_id']),
      saleCreatedUserId: extractMany2oneId(data['sale_created_user_id']),
      entregarSoloPagado: parseOdooBool(data['entregar_solo_pagado']),
      esParaDespacho: parseOdooBool(data['es_para_despacho']),
      notaAdicional: parseOdooString(data['nota_adicional']),
      xUuid: parseOdooString(data['x_uuid']),
      isSynced: false,
      syncRetryCount: 0,
      writeDate: parseOdooDateTime(data['write_date']),
      hasQueuedInvoice: false,
    );
  }

  @override
  Map<String, dynamic> toOdoo(SaleOrder record) {
    return {
      'name': record.name,
      'state': record.state.code,
      'date_order': formatOdooDateTime(record.dateOrder),
      'validity_date': formatOdooDate(record.validityDate),
      'commitment_date': formatOdooDateTime(record.commitmentDate),
      'expected_date': formatOdooDateTime(record.expectedDate),
      'partner_id': record.partnerId,
      'partner_vat': record.partnerVat,
      'partner_street': record.partnerStreet,
      'partner_phone': record.partnerPhone,
      'partner_email': record.partnerEmail,
      'partner_avatar': record.partnerAvatar,
      'partner_invoice_id': record.partnerInvoiceId,
      'partner_shipping_id': record.partnerShippingId,
      'user_id': record.userId,
      'team_id': record.teamId,
      'company_id': record.companyId,
      'warehouse_id': record.warehouseId,
      'pricelist_id': record.pricelistId,
      'currency_id': record.currencyId,
      'currency_symbol': record.currencySymbol,
      'currency_rate': record.currencyRate,
      'payment_term_id': record.paymentTermId,
      'is_cash': record.isCash,
      'is_credit': record.isCredit,
      'fiscal_position_id': record.fiscalPositionId,
      'amount_untaxed': record.amountUntaxed,
      'amount_tax': record.amountTax,
      'amount_total': record.amountTotal,
      'amount_to_invoice': record.amountToInvoice,
      'amount_invoiced': record.amountInvoiced,
      'invoice_status': record.invoiceStatus.code,
      'invoice_count': record.invoiceCount,
      'note': record.note,
      'client_order_ref': record.clientOrderRef,
      'require_signature': record.requireSignature,
      'signature': record.signature,
      'signed_by': record.signedBy,
      'signed_on': formatOdooDateTime(record.signedOn),
      'require_payment': record.requirePayment,
      'prepayment_percent': record.prepaymentPercent,
      'locked': record.locked,
      'is_expired': record.isExpired,
      'total_discount_amount': record.totalDiscountAmount,
      'total_amount_undiscounted': record.amountUntaxedUndiscounted,
      'is_final_consumer': record.isFinalConsumer,
      'end_customer_name': record.endCustomerName,
      'end_customer_phone': record.endCustomerPhone,
      'end_customer_email': record.endCustomerEmail,
      'exceeds_final_consumer_limit': record.exceedsFinalConsumerLimit,
      'emitir_factura_fecha_posterior': record.emitirFacturaFechaPosterior,
      'fecha_facturar': formatOdooDate(record.fechaFacturar),
      'referrer_id': record.referrerId,
      'tipo_cliente': record.tipoCliente,
      'canal_cliente': record.canalCliente,
      'picking_ids': buildMany2manyReplace(record.pickingIds ?? []),
      'delivery_status': record.deliveryStatus,
      'tax_totals': toJsonString(record.taxTotals),
      'credit_exceeded': record.creditExceeded,
      'credit_check_bypassed': record.creditCheckBypassed,
      'amount_cash': record.amountCash,
      'amount_unpaid': record.amountUnpaid,
      'total_cost_amount': record.totalCostAmount,
      'margin': record.margin,
      'margin_percent': record.marginPercent,
      'retenido_amount': record.retenidoAmount,
      'approval_count': record.approvalCount,
      'approved_date': formatOdooDateTime(record.approvedDate),
      'rejected_date': formatOdooDateTime(record.rejectedDate),
      'rejected_reason': record.rejectedReason,
      'collection_session_id': record.collectionSessionId,
      'collection_user_id': record.collectionUserId,
      'sale_created_user_id': record.saleCreatedUserId,
      'entregar_solo_pagado': record.entregarSoloPagado,
      'es_para_despacho': record.esParaDespacho,
      'nota_adicional': record.notaAdicional,
      'x_uuid': record.xUuid,
    };
  }

  @override
  SaleOrder fromDrift(dynamic row) {
    return SaleOrder(
      id: row.odooId as int,
      orderUuid: row.orderUuid as String?,
      name: row.name as String,
      state: SaleOrderState.values.firstWhere(
        (e) => e.code == (row.state as String?),
        orElse: () => SaleOrderState.values.first,
      ),
      dateOrder: row.dateOrder as DateTime?,
      validityDate: row.validityDate as DateTime?,
      commitmentDate: row.commitmentDate as DateTime?,
      expectedDate: row.expectedDate as DateTime?,
      partnerId: row.partnerId as int?,
      partnerName: row.partnerName as String?,
      partnerVat: row.partnerVat as String?,
      partnerStreet: row.partnerStreet as String?,
      partnerPhone: row.partnerPhone as String?,
      partnerEmail: row.partnerEmail as String?,
      partnerAvatar: row.partnerAvatar as String?,
      partnerInvoiceId: row.partnerInvoiceId as int?,
      partnerInvoiceAddress: row.partnerInvoiceAddress as String?,
      partnerShippingId: row.partnerShippingId as int?,
      partnerShippingAddress: row.partnerShippingAddress as String?,
      userId: row.userId as int?,
      userName: row.userName as String?,
      teamId: row.teamId as int?,
      teamName: row.teamName as String?,
      companyId: row.companyId as int?,
      companyName: row.companyName as String?,
      warehouseId: row.warehouseId as int?,
      warehouseName: row.warehouseName as String?,
      pricelistId: row.pricelistId as int?,
      pricelistName: row.pricelistName as String?,
      currencyId: row.currencyId as int?,
      currencySymbol: row.currencySymbol as String?,
      currencyRate: row.currencyRate as double,
      paymentTermId: row.paymentTermId as int?,
      paymentTermName: row.paymentTermName as String?,
      isCash: row.isCash as bool,
      isCredit: row.isCredit as bool,
      fiscalPositionId: row.fiscalPositionId as int?,
      fiscalPositionName: row.fiscalPositionName as String?,
      amountUntaxed: row.amountUntaxed as double,
      amountTax: row.amountTax as double,
      amountTotal: row.amountTotal as double,
      amountToInvoice: row.amountToInvoice as double,
      amountInvoiced: row.amountInvoiced as double,
      invoiceStatus: InvoiceStatus.values.firstWhere(
        (e) => e.code == (row.invoiceStatus as String?),
        orElse: () => InvoiceStatus.values.first,
      ),
      invoiceCount: row.invoiceCount as int,
      note: row.note as String?,
      clientOrderRef: row.clientOrderRef as String?,
      requireSignature: row.requireSignature as bool,
      signature: row.signature as String?,
      signedBy: row.signedBy as String?,
      signedOn: row.signedOn as DateTime?,
      requirePayment: row.requirePayment as bool,
      prepaymentPercent: row.prepaymentPercent as double,
      locked: row.locked as bool,
      isExpired: row.isExpired as bool,
      totalDiscountAmount: row.totalDiscountAmount as double,
      amountUntaxedUndiscounted: row.amountUntaxedUndiscounted as double,
      isFinalConsumer: row.isFinalConsumer as bool,
      endCustomerName: row.endCustomerName as String?,
      endCustomerPhone: row.endCustomerPhone as String?,
      endCustomerEmail: row.endCustomerEmail as String?,
      exceedsFinalConsumerLimit: row.exceedsFinalConsumerLimit as bool,
      emitirFacturaFechaPosterior: row.emitirFacturaFechaPosterior as bool,
      fechaFacturar: row.fechaFacturar as DateTime?,
      referrerId: row.referrerId as int?,
      referrerName: row.referrerName as String?,
      tipoCliente: row.tipoCliente as String?,
      canalCliente: row.canalCliente as String?,
      deliveryStatus: row.deliveryStatus as String?,
      taxTotals: parseOdooJson(row.taxTotals),
      creditExceeded: row.creditExceeded as bool,
      creditCheckBypassed: row.creditCheckBypassed as bool,
      amountCash: row.amountCash as double,
      amountUnpaid: row.amountUnpaid as double,
      totalCostAmount: row.totalCostAmount as double,
      margin: row.margin as double,
      marginPercent: row.marginPercent as double,
      retenidoAmount: row.retenidoAmount as double,
      approvalCount: row.approvalCount as int,
      approvedDate: row.approvedDate as DateTime?,
      rejectedDate: row.rejectedDate as DateTime?,
      rejectedReason: row.rejectedReason as String?,
      collectionSessionId: row.collectionSessionId as int?,
      collectionUserId: row.collectionUserId as int?,
      saleCreatedUserId: row.saleCreatedUserId as int?,
      entregarSoloPagado: row.entregarSoloPagado as bool,
      esParaDespacho: row.esParaDespacho as bool,
      notaAdicional: row.notaAdicional as String?,
      xUuid: row.xUuid as String?,
      isSynced: row.isSynced as bool? ?? false,
      lastSyncDate: row.lastSyncDate as DateTime?,
      syncRetryCount: row.syncRetryCount as int? ?? 0,
      lastSyncAttempt: row.lastSyncAttempt as DateTime?,
      writeDate: row.writeDate as DateTime?,
      hasQueuedInvoice: row.hasQueuedInvoice as bool? ?? false,
    );
  }

  @override
  int getId(SaleOrder record) => record.id;

  @override
  String? getUuid(SaleOrder record) => null;

  @override
  SaleOrder withIdAndUuid(SaleOrder record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  SaleOrder withSyncStatus(SaleOrder record, bool isSynced) {
    return record.copyWith(isSynced: isSynced);
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'name': 'name',
    'state': 'state',
    'date_order': 'dateOrder',
    'validity_date': 'validityDate',
    'commitment_date': 'commitmentDate',
    'expected_date': 'expectedDate',
    'partner_id': 'partnerId',
    'partner_vat': 'partnerVat',
    'partner_street': 'partnerStreet',
    'partner_phone': 'partnerPhone',
    'partner_email': 'partnerEmail',
    'partner_avatar': 'partnerAvatar',
    'partner_invoice_id': 'partnerInvoiceId',
    'partner_shipping_id': 'partnerShippingId',
    'user_id': 'userId',
    'team_id': 'teamId',
    'company_id': 'companyId',
    'warehouse_id': 'warehouseId',
    'pricelist_id': 'pricelistId',
    'currency_id': 'currencyId',
    'currency_symbol': 'currencySymbol',
    'currency_rate': 'currencyRate',
    'payment_term_id': 'paymentTermId',
    'is_cash': 'isCash',
    'is_credit': 'isCredit',
    'fiscal_position_id': 'fiscalPositionId',
    'amount_untaxed': 'amountUntaxed',
    'amount_tax': 'amountTax',
    'amount_total': 'amountTotal',
    'amount_to_invoice': 'amountToInvoice',
    'amount_invoiced': 'amountInvoiced',
    'invoice_status': 'invoiceStatus',
    'invoice_count': 'invoiceCount',
    'note': 'note',
    'client_order_ref': 'clientOrderRef',
    'require_signature': 'requireSignature',
    'signature': 'signature',
    'signed_by': 'signedBy',
    'signed_on': 'signedOn',
    'require_payment': 'requirePayment',
    'prepayment_percent': 'prepaymentPercent',
    'locked': 'locked',
    'is_expired': 'isExpired',
    'total_discount_amount': 'totalDiscountAmount',
    'total_amount_undiscounted': 'amountUntaxedUndiscounted',
    'is_final_consumer': 'isFinalConsumer',
    'end_customer_name': 'endCustomerName',
    'end_customer_phone': 'endCustomerPhone',
    'end_customer_email': 'endCustomerEmail',
    'exceeds_final_consumer_limit': 'exceedsFinalConsumerLimit',
    'emitir_factura_fecha_posterior': 'emitirFacturaFechaPosterior',
    'fecha_facturar': 'fechaFacturar',
    'referrer_id': 'referrerId',
    'tipo_cliente': 'tipoCliente',
    'canal_cliente': 'canalCliente',
    'picking_ids': 'pickingIds',
    'delivery_status': 'deliveryStatus',
    'tax_totals': 'taxTotals',
    'credit_exceeded': 'creditExceeded',
    'credit_check_bypassed': 'creditCheckBypassed',
    'amount_cash': 'amountCash',
    'amount_unpaid': 'amountUnpaid',
    'total_cost_amount': 'totalCostAmount',
    'margin': 'margin',
    'margin_percent': 'marginPercent',
    'retenido_amount': 'retenidoAmount',
    'approval_count': 'approvalCount',
    'approved_date': 'approvedDate',
    'rejected_date': 'rejectedDate',
    'rejected_reason': 'rejectedReason',
    'collection_session_id': 'collectionSessionId',
    'collection_user_id': 'collectionUserId',
    'sale_created_user_id': 'saleCreatedUserId',
    'entregar_solo_pagado': 'entregarSoloPagado',
    'es_para_despacho': 'esParaDespacho',
    'nota_adicional': 'notaAdicional',
    'x_uuid': 'xUuid',
    'write_date': 'writeDate',
  };

  /// Get Dart field name from Odoo field name.
  String? getDartFieldName(String odooField) => fieldMappings[odooField];

  /// Get Odoo field name from Dart field name.
  String? getOdooFieldName(String dartField) {
    for (final entry in fieldMappings.entries) {
      if (entry.value == dartField) return entry.key;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════
  // GenericDriftOperations — Database & Table
  // ═══════════════════════════════════════════════════

  @override
  GeneratedDatabase get database {
    final db = this.db;
    if (db == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return db;
  }

  @override
  TableInfo get table {
    final resolved = resolveTable();
    if (resolved == null) {
      throw StateError('Table \'sale_order\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(SaleOrder record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'state': Variable<String>(record.state.code),
      'date_order': driftVar<DateTime>(record.dateOrder),
      'validity_date': driftVar<DateTime>(record.validityDate),
      'commitment_date': driftVar<DateTime>(record.commitmentDate),
      'expected_date': driftVar<DateTime>(record.expectedDate),
      'partner_id': driftVar<int>(record.partnerId),
      'partner_id_name': driftVar<String>(record.partnerName),
      'partner_vat': driftVar<String>(record.partnerVat),
      'partner_street': driftVar<String>(record.partnerStreet),
      'partner_phone': driftVar<String>(record.partnerPhone),
      'partner_email': driftVar<String>(record.partnerEmail),
      'partner_avatar': driftVar<String>(record.partnerAvatar),
      'partner_invoice_id': driftVar<int>(record.partnerInvoiceId),
      'partner_invoice_id_name': driftVar<String>(record.partnerInvoiceAddress),
      'partner_shipping_id': driftVar<int>(record.partnerShippingId),
      'partner_shipping_id_name': driftVar<String>(
        record.partnerShippingAddress,
      ),
      'user_id': driftVar<int>(record.userId),
      'user_id_name': driftVar<String>(record.userName),
      'team_id': driftVar<int>(record.teamId),
      'team_id_name': driftVar<String>(record.teamName),
      'company_id': driftVar<int>(record.companyId),
      'company_id_name': driftVar<String>(record.companyName),
      'warehouse_id': driftVar<int>(record.warehouseId),
      'warehouse_id_name': driftVar<String>(record.warehouseName),
      'pricelist_id': driftVar<int>(record.pricelistId),
      'pricelist_id_name': driftVar<String>(record.pricelistName),
      'currency_id': driftVar<int>(record.currencyId),
      'currency_symbol': driftVar<String>(record.currencySymbol),
      'currency_rate': Variable<double>(record.currencyRate),
      'payment_term_id': driftVar<int>(record.paymentTermId),
      'payment_term_id_name': driftVar<String>(record.paymentTermName),
      'is_cash': Variable<bool>(record.isCash),
      'is_credit': Variable<bool>(record.isCredit),
      'fiscal_position_id': driftVar<int>(record.fiscalPositionId),
      'fiscal_position_id_name': driftVar<String>(record.fiscalPositionName),
      'amount_untaxed': Variable<double>(record.amountUntaxed),
      'amount_tax': Variable<double>(record.amountTax),
      'amount_total': Variable<double>(record.amountTotal),
      'amount_to_invoice': Variable<double>(record.amountToInvoice),
      'amount_invoiced': Variable<double>(record.amountInvoiced),
      'invoice_status': Variable<String>(record.invoiceStatus.code),
      'invoice_count': Variable<int>(record.invoiceCount),
      'note': driftVar<String>(record.note),
      'client_order_ref': driftVar<String>(record.clientOrderRef),
      'require_signature': Variable<bool>(record.requireSignature),
      'signature': driftVar<String>(record.signature),
      'signed_by': driftVar<String>(record.signedBy),
      'signed_on': driftVar<DateTime>(record.signedOn),
      'require_payment': Variable<bool>(record.requirePayment),
      'prepayment_percent': Variable<double>(record.prepaymentPercent),
      'locked': Variable<bool>(record.locked),
      'is_expired': Variable<bool>(record.isExpired),
      'total_discount_amount': Variable<double>(record.totalDiscountAmount),
      'total_amount_undiscounted': Variable<double>(
        record.amountUntaxedUndiscounted,
      ),
      'is_final_consumer': Variable<bool>(record.isFinalConsumer),
      'end_customer_name': driftVar<String>(record.endCustomerName),
      'end_customer_phone': driftVar<String>(record.endCustomerPhone),
      'end_customer_email': driftVar<String>(record.endCustomerEmail),
      'exceeds_final_consumer_limit': Variable<bool>(
        record.exceedsFinalConsumerLimit,
      ),
      'emitir_factura_fecha_posterior': Variable<bool>(
        record.emitirFacturaFechaPosterior,
      ),
      'fecha_facturar': driftVar<DateTime>(record.fechaFacturar),
      'referrer_id': driftVar<int>(record.referrerId),
      'referrer_id_name': driftVar<String>(record.referrerName),
      'tipo_cliente': driftVar<String>(record.tipoCliente),
      'canal_cliente': driftVar<String>(record.canalCliente),
      'delivery_status': driftVar<String>(record.deliveryStatus),
      'tax_totals': driftVar<String>(toJsonString(record.taxTotals)),
      'credit_exceeded': Variable<bool>(record.creditExceeded),
      'credit_check_bypassed': Variable<bool>(record.creditCheckBypassed),
      'amount_cash': Variable<double>(record.amountCash),
      'amount_unpaid': Variable<double>(record.amountUnpaid),
      'total_cost_amount': Variable<double>(record.totalCostAmount),
      'margin': Variable<double>(record.margin),
      'margin_percent': Variable<double>(record.marginPercent),
      'retenido_amount': Variable<double>(record.retenidoAmount),
      'approval_count': Variable<int>(record.approvalCount),
      'approved_date': driftVar<DateTime>(record.approvedDate),
      'rejected_date': driftVar<DateTime>(record.rejectedDate),
      'rejected_reason': driftVar<String>(record.rejectedReason),
      'collection_session_id': driftVar<int>(record.collectionSessionId),
      'collection_user_id': driftVar<int>(record.collectionUserId),
      'sale_created_user_id': driftVar<int>(record.saleCreatedUserId),
      'entregar_solo_pagado': Variable<bool>(record.entregarSoloPagado),
      'es_para_despacho': Variable<bool>(record.esParaDespacho),
      'nota_adicional': driftVar<String>(record.notaAdicional),
      'x_uuid': driftVar<String>(record.xUuid),
      'write_date': driftVar<DateTime>(record.writeDate),
      'order_uuid': driftVar<String>(record.orderUuid),
      'is_synced': Variable<bool>(record.isSynced),
      'last_sync_date': driftVar<DateTime>(record.lastSyncDate),
      'sync_retry_count': Variable<int>(record.syncRetryCount),
      'last_sync_attempt': driftVar<DateTime>(record.lastSyncAttempt),
      'has_queued_invoice': Variable<bool>(record.hasQueuedInvoice),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'state',
    'dateOrder',
    'validityDate',
    'commitmentDate',
    'expectedDate',
    'partnerId',
    'partnerVat',
    'partnerStreet',
    'partnerPhone',
    'partnerEmail',
    'partnerAvatar',
    'partnerInvoiceId',
    'partnerShippingId',
    'userId',
    'teamId',
    'companyId',
    'warehouseId',
    'pricelistId',
    'currencyId',
    'currencySymbol',
    'currencyRate',
    'paymentTermId',
    'isCash',
    'isCredit',
    'fiscalPositionId',
    'amountUntaxed',
    'amountTax',
    'amountTotal',
    'amountToInvoice',
    'amountInvoiced',
    'invoiceStatus',
    'invoiceCount',
    'note',
    'clientOrderRef',
    'requireSignature',
    'signature',
    'signedBy',
    'signedOn',
    'requirePayment',
    'prepaymentPercent',
    'locked',
    'isExpired',
    'totalDiscountAmount',
    'amountUntaxedUndiscounted',
    'isFinalConsumer',
    'endCustomerName',
    'endCustomerPhone',
    'endCustomerEmail',
    'exceedsFinalConsumerLimit',
    'emitirFacturaFechaPosterior',
    'fechaFacturar',
    'referrerId',
    'tipoCliente',
    'canalCliente',
    'pickingIds',
    'deliveryStatus',
    'taxTotals',
    'creditExceeded',
    'creditCheckBypassed',
    'amountCash',
    'amountUnpaid',
    'totalCostAmount',
    'margin',
    'marginPercent',
    'retenidoAmount',
    'approvalCount',
    'approvedDate',
    'rejectedDate',
    'rejectedReason',
    'collectionSessionId',
    'collectionUserId',
    'saleCreatedUserId',
    'entregarSoloPagado',
    'esParaDespacho',
    'notaAdicional',
    'xUuid',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'orderUuid': 'Order Uuid',
    'name': 'Name',
    'state': 'State',
    'dateOrder': 'Date Order',
    'validityDate': 'Validity Date',
    'commitmentDate': 'Commitment Date',
    'expectedDate': 'Expected Date',
    'partnerId': 'Partner Id',
    'partnerName': 'Partner Name',
    'partnerVat': 'Partner Vat',
    'partnerStreet': 'Partner Street',
    'partnerPhone': 'Partner Phone',
    'partnerEmail': 'Partner Email',
    'partnerAvatar': 'Partner Avatar',
    'partnerInvoiceId': 'Partner Invoice Id',
    'partnerInvoiceAddress': 'Partner Invoice Address',
    'partnerShippingId': 'Partner Shipping Id',
    'partnerShippingAddress': 'Partner Shipping Address',
    'userId': 'User Id',
    'userName': 'User Name',
    'teamId': 'Team Id',
    'teamName': 'Team Name',
    'companyId': 'Company Id',
    'companyName': 'Company Name',
    'warehouseId': 'Warehouse Id',
    'warehouseName': 'Warehouse Name',
    'pricelistId': 'Pricelist Id',
    'pricelistName': 'Pricelist Name',
    'currencyId': 'Currency Id',
    'currencySymbol': 'Currency Symbol',
    'currencyRate': 'Currency Rate',
    'paymentTermId': 'Payment Term Id',
    'paymentTermName': 'Payment Term Name',
    'isCash': 'Is Cash',
    'isCredit': 'Is Credit',
    'fiscalPositionId': 'Fiscal Position Id',
    'fiscalPositionName': 'Fiscal Position Name',
    'amountUntaxed': 'Amount Untaxed',
    'amountTax': 'Amount Tax',
    'amountTotal': 'Amount Total',
    'amountToInvoice': 'Amount To Invoice',
    'amountInvoiced': 'Amount Invoiced',
    'invoiceStatus': 'Invoice Status',
    'invoiceCount': 'Invoice Count',
    'note': 'Note',
    'clientOrderRef': 'Client Order Ref',
    'requireSignature': 'Require Signature',
    'signature': 'Signature',
    'signedBy': 'Signed By',
    'signedOn': 'Signed On',
    'requirePayment': 'Require Payment',
    'prepaymentPercent': 'Prepayment Percent',
    'locked': 'Locked',
    'isExpired': 'Is Expired',
    'totalDiscountAmount': 'Total Discount Amount',
    'amountUntaxedUndiscounted': 'Amount Untaxed Undiscounted',
    'isFinalConsumer': 'Is Final Consumer',
    'endCustomerName': 'End Customer Name',
    'endCustomerPhone': 'End Customer Phone',
    'endCustomerEmail': 'End Customer Email',
    'exceedsFinalConsumerLimit': 'Exceeds Final Consumer Limit',
    'emitirFacturaFechaPosterior': 'Emitir Factura Fecha Posterior',
    'fechaFacturar': 'Fecha Facturar',
    'referrerId': 'Referrer Id',
    'referrerName': 'Referrer Name',
    'tipoCliente': 'Tipo Cliente',
    'canalCliente': 'Canal Cliente',
    'pickingIds': 'Picking Ids',
    'deliveryStatus': 'Delivery Status',
    'taxTotals': 'Tax Totals',
    'creditExceeded': 'Credit Exceeded',
    'creditCheckBypassed': 'Credit Check Bypassed',
    'amountCash': 'Amount Cash',
    'amountUnpaid': 'Amount Unpaid',
    'totalCostAmount': 'Total Cost Amount',
    'margin': 'Margin',
    'marginPercent': 'Margin Percent',
    'retenidoAmount': 'Retenido Amount',
    'approvalCount': 'Approval Count',
    'approvedDate': 'Approved Date',
    'rejectedDate': 'Rejected Date',
    'rejectedReason': 'Rejected Reason',
    'collectionSessionId': 'Collection Session Id',
    'collectionUserId': 'Collection User Id',
    'saleCreatedUserId': 'Sale Created User Id',
    'entregarSoloPagado': 'Entregar Solo Pagado',
    'esParaDespacho': 'Es Para Despacho',
    'notaAdicional': 'Nota Adicional',
    'xUuid': 'X Uuid',
    'isSynced': 'Is Synced',
    'lastSyncDate': 'Last Sync Date',
    'syncRetryCount': 'Sync Retry Count',
    'lastSyncAttempt': 'Last Sync Attempt',
    'writeDate': 'Write Date',
    'hasQueuedInvoice': 'Has Queued Invoice',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(SaleOrder record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(SaleOrder record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(SaleOrder record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(SaleOrder record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'orderUuid':
        return record.orderUuid;
      case 'name':
        return record.name;
      case 'state':
        return record.state;
      case 'dateOrder':
        return record.dateOrder;
      case 'validityDate':
        return record.validityDate;
      case 'commitmentDate':
        return record.commitmentDate;
      case 'expectedDate':
        return record.expectedDate;
      case 'partnerId':
        return record.partnerId;
      case 'partnerName':
        return record.partnerName;
      case 'partnerVat':
        return record.partnerVat;
      case 'partnerStreet':
        return record.partnerStreet;
      case 'partnerPhone':
        return record.partnerPhone;
      case 'partnerEmail':
        return record.partnerEmail;
      case 'partnerAvatar':
        return record.partnerAvatar;
      case 'partnerInvoiceId':
        return record.partnerInvoiceId;
      case 'partnerInvoiceAddress':
        return record.partnerInvoiceAddress;
      case 'partnerShippingId':
        return record.partnerShippingId;
      case 'partnerShippingAddress':
        return record.partnerShippingAddress;
      case 'userId':
        return record.userId;
      case 'userName':
        return record.userName;
      case 'teamId':
        return record.teamId;
      case 'teamName':
        return record.teamName;
      case 'companyId':
        return record.companyId;
      case 'companyName':
        return record.companyName;
      case 'warehouseId':
        return record.warehouseId;
      case 'warehouseName':
        return record.warehouseName;
      case 'pricelistId':
        return record.pricelistId;
      case 'pricelistName':
        return record.pricelistName;
      case 'currencyId':
        return record.currencyId;
      case 'currencySymbol':
        return record.currencySymbol;
      case 'currencyRate':
        return record.currencyRate;
      case 'paymentTermId':
        return record.paymentTermId;
      case 'paymentTermName':
        return record.paymentTermName;
      case 'isCash':
        return record.isCash;
      case 'isCredit':
        return record.isCredit;
      case 'fiscalPositionId':
        return record.fiscalPositionId;
      case 'fiscalPositionName':
        return record.fiscalPositionName;
      case 'amountUntaxed':
        return record.amountUntaxed;
      case 'amountTax':
        return record.amountTax;
      case 'amountTotal':
        return record.amountTotal;
      case 'amountToInvoice':
        return record.amountToInvoice;
      case 'amountInvoiced':
        return record.amountInvoiced;
      case 'invoiceStatus':
        return record.invoiceStatus;
      case 'invoiceCount':
        return record.invoiceCount;
      case 'note':
        return record.note;
      case 'clientOrderRef':
        return record.clientOrderRef;
      case 'requireSignature':
        return record.requireSignature;
      case 'signature':
        return record.signature;
      case 'signedBy':
        return record.signedBy;
      case 'signedOn':
        return record.signedOn;
      case 'requirePayment':
        return record.requirePayment;
      case 'prepaymentPercent':
        return record.prepaymentPercent;
      case 'locked':
        return record.locked;
      case 'isExpired':
        return record.isExpired;
      case 'totalDiscountAmount':
        return record.totalDiscountAmount;
      case 'amountUntaxedUndiscounted':
        return record.amountUntaxedUndiscounted;
      case 'isFinalConsumer':
        return record.isFinalConsumer;
      case 'endCustomerName':
        return record.endCustomerName;
      case 'endCustomerPhone':
        return record.endCustomerPhone;
      case 'endCustomerEmail':
        return record.endCustomerEmail;
      case 'exceedsFinalConsumerLimit':
        return record.exceedsFinalConsumerLimit;
      case 'emitirFacturaFechaPosterior':
        return record.emitirFacturaFechaPosterior;
      case 'fechaFacturar':
        return record.fechaFacturar;
      case 'referrerId':
        return record.referrerId;
      case 'referrerName':
        return record.referrerName;
      case 'tipoCliente':
        return record.tipoCliente;
      case 'canalCliente':
        return record.canalCliente;
      case 'pickingIds':
        return record.pickingIds;
      case 'deliveryStatus':
        return record.deliveryStatus;
      case 'taxTotals':
        return record.taxTotals;
      case 'creditExceeded':
        return record.creditExceeded;
      case 'creditCheckBypassed':
        return record.creditCheckBypassed;
      case 'amountCash':
        return record.amountCash;
      case 'amountUnpaid':
        return record.amountUnpaid;
      case 'totalCostAmount':
        return record.totalCostAmount;
      case 'margin':
        return record.margin;
      case 'marginPercent':
        return record.marginPercent;
      case 'retenidoAmount':
        return record.retenidoAmount;
      case 'approvalCount':
        return record.approvalCount;
      case 'approvedDate':
        return record.approvedDate;
      case 'rejectedDate':
        return record.rejectedDate;
      case 'rejectedReason':
        return record.rejectedReason;
      case 'collectionSessionId':
        return record.collectionSessionId;
      case 'collectionUserId':
        return record.collectionUserId;
      case 'saleCreatedUserId':
        return record.saleCreatedUserId;
      case 'entregarSoloPagado':
        return record.entregarSoloPagado;
      case 'esParaDespacho':
        return record.esParaDespacho;
      case 'notaAdicional':
        return record.notaAdicional;
      case 'xUuid':
        return record.xUuid;
      case 'isSynced':
        return record.isSynced;
      case 'lastSyncDate':
        return record.lastSyncDate;
      case 'syncRetryCount':
        return record.syncRetryCount;
      case 'lastSyncAttempt':
        return record.lastSyncAttempt;
      case 'writeDate':
        return record.writeDate;
      case 'hasQueuedInvoice':
        return record.hasQueuedInvoice;
      default:
        return null;
    }
  }

  @override
  SaleOrder applyWebSocketChangesToRecord(
    SaleOrder record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      orderUuid: record.orderUuid,
      isSynced: record.isSynced,
      lastSyncDate: record.lastSyncDate,
      syncRetryCount: record.syncRetryCount,
      lastSyncAttempt: record.lastSyncAttempt,
      hasQueuedInvoice: record.hasQueuedInvoice,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'orderUuid':
        return (obj as dynamic).orderUuid;
      case 'name':
        return (obj as dynamic).name;
      case 'state':
        return (obj as dynamic).state;
      case 'dateOrder':
        return (obj as dynamic).dateOrder;
      case 'validityDate':
        return (obj as dynamic).validityDate;
      case 'commitmentDate':
        return (obj as dynamic).commitmentDate;
      case 'expectedDate':
        return (obj as dynamic).expectedDate;
      case 'partnerId':
        return (obj as dynamic).partnerId;
      case 'partnerName':
        return (obj as dynamic).partnerName;
      case 'partnerVat':
        return (obj as dynamic).partnerVat;
      case 'partnerStreet':
        return (obj as dynamic).partnerStreet;
      case 'partnerPhone':
        return (obj as dynamic).partnerPhone;
      case 'partnerEmail':
        return (obj as dynamic).partnerEmail;
      case 'partnerAvatar':
        return (obj as dynamic).partnerAvatar;
      case 'partnerInvoiceId':
        return (obj as dynamic).partnerInvoiceId;
      case 'partnerInvoiceAddress':
        return (obj as dynamic).partnerInvoiceAddress;
      case 'partnerShippingId':
        return (obj as dynamic).partnerShippingId;
      case 'partnerShippingAddress':
        return (obj as dynamic).partnerShippingAddress;
      case 'userId':
        return (obj as dynamic).userId;
      case 'userName':
        return (obj as dynamic).userName;
      case 'teamId':
        return (obj as dynamic).teamId;
      case 'teamName':
        return (obj as dynamic).teamName;
      case 'companyId':
        return (obj as dynamic).companyId;
      case 'companyName':
        return (obj as dynamic).companyName;
      case 'warehouseId':
        return (obj as dynamic).warehouseId;
      case 'warehouseName':
        return (obj as dynamic).warehouseName;
      case 'pricelistId':
        return (obj as dynamic).pricelistId;
      case 'pricelistName':
        return (obj as dynamic).pricelistName;
      case 'currencyId':
        return (obj as dynamic).currencyId;
      case 'currencySymbol':
        return (obj as dynamic).currencySymbol;
      case 'currencyRate':
        return (obj as dynamic).currencyRate;
      case 'paymentTermId':
        return (obj as dynamic).paymentTermId;
      case 'paymentTermName':
        return (obj as dynamic).paymentTermName;
      case 'isCash':
        return (obj as dynamic).isCash;
      case 'isCredit':
        return (obj as dynamic).isCredit;
      case 'fiscalPositionId':
        return (obj as dynamic).fiscalPositionId;
      case 'fiscalPositionName':
        return (obj as dynamic).fiscalPositionName;
      case 'amountUntaxed':
        return (obj as dynamic).amountUntaxed;
      case 'amountTax':
        return (obj as dynamic).amountTax;
      case 'amountTotal':
        return (obj as dynamic).amountTotal;
      case 'amountToInvoice':
        return (obj as dynamic).amountToInvoice;
      case 'amountInvoiced':
        return (obj as dynamic).amountInvoiced;
      case 'invoiceStatus':
        return (obj as dynamic).invoiceStatus;
      case 'invoiceCount':
        return (obj as dynamic).invoiceCount;
      case 'note':
        return (obj as dynamic).note;
      case 'clientOrderRef':
        return (obj as dynamic).clientOrderRef;
      case 'requireSignature':
        return (obj as dynamic).requireSignature;
      case 'signature':
        return (obj as dynamic).signature;
      case 'signedBy':
        return (obj as dynamic).signedBy;
      case 'signedOn':
        return (obj as dynamic).signedOn;
      case 'requirePayment':
        return (obj as dynamic).requirePayment;
      case 'prepaymentPercent':
        return (obj as dynamic).prepaymentPercent;
      case 'locked':
        return (obj as dynamic).locked;
      case 'isExpired':
        return (obj as dynamic).isExpired;
      case 'totalDiscountAmount':
        return (obj as dynamic).totalDiscountAmount;
      case 'amountUntaxedUndiscounted':
        return (obj as dynamic).amountUntaxedUndiscounted;
      case 'isFinalConsumer':
        return (obj as dynamic).isFinalConsumer;
      case 'endCustomerName':
        return (obj as dynamic).endCustomerName;
      case 'endCustomerPhone':
        return (obj as dynamic).endCustomerPhone;
      case 'endCustomerEmail':
        return (obj as dynamic).endCustomerEmail;
      case 'exceedsFinalConsumerLimit':
        return (obj as dynamic).exceedsFinalConsumerLimit;
      case 'emitirFacturaFechaPosterior':
        return (obj as dynamic).emitirFacturaFechaPosterior;
      case 'fechaFacturar':
        return (obj as dynamic).fechaFacturar;
      case 'referrerId':
        return (obj as dynamic).referrerId;
      case 'referrerName':
        return (obj as dynamic).referrerName;
      case 'tipoCliente':
        return (obj as dynamic).tipoCliente;
      case 'canalCliente':
        return (obj as dynamic).canalCliente;
      case 'pickingIds':
        return (obj as dynamic).pickingIds;
      case 'deliveryStatus':
        return (obj as dynamic).deliveryStatus;
      case 'taxTotals':
        return (obj as dynamic).taxTotals;
      case 'creditExceeded':
        return (obj as dynamic).creditExceeded;
      case 'creditCheckBypassed':
        return (obj as dynamic).creditCheckBypassed;
      case 'amountCash':
        return (obj as dynamic).amountCash;
      case 'amountUnpaid':
        return (obj as dynamic).amountUnpaid;
      case 'totalCostAmount':
        return (obj as dynamic).totalCostAmount;
      case 'margin':
        return (obj as dynamic).margin;
      case 'marginPercent':
        return (obj as dynamic).marginPercent;
      case 'retenidoAmount':
        return (obj as dynamic).retenidoAmount;
      case 'approvalCount':
        return (obj as dynamic).approvalCount;
      case 'approvedDate':
        return (obj as dynamic).approvedDate;
      case 'rejectedDate':
        return (obj as dynamic).rejectedDate;
      case 'rejectedReason':
        return (obj as dynamic).rejectedReason;
      case 'collectionSessionId':
        return (obj as dynamic).collectionSessionId;
      case 'collectionUserId':
        return (obj as dynamic).collectionUserId;
      case 'saleCreatedUserId':
        return (obj as dynamic).saleCreatedUserId;
      case 'entregarSoloPagado':
        return (obj as dynamic).entregarSoloPagado;
      case 'esParaDespacho':
        return (obj as dynamic).esParaDespacho;
      case 'notaAdicional':
        return (obj as dynamic).notaAdicional;
      case 'xUuid':
        return (obj as dynamic).xUuid;
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'lastSyncDate':
        return (obj as dynamic).lastSyncDate;
      case 'syncRetryCount':
        return (obj as dynamic).syncRetryCount;
      case 'lastSyncAttempt':
        return (obj as dynamic).lastSyncAttempt;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'hasQueuedInvoice':
        return (obj as dynamic).hasQueuedInvoice;
      case 'uuid':
        return (obj as dynamic).uuid;
      case 'localCreatedAt':
        return (obj as dynamic).localCreatedAt;
      default:
        return super.accessProperty(obj, name);
    }
  }

  @override
  List<String> get computedFieldNames => const [];

  @override
  List<String> get storedFieldNames => const [
    'id',
    'orderUuid',
    'name',
    'state',
    'dateOrder',
    'validityDate',
    'commitmentDate',
    'expectedDate',
    'partnerId',
    'partnerName',
    'partnerVat',
    'partnerStreet',
    'partnerPhone',
    'partnerEmail',
    'partnerAvatar',
    'partnerInvoiceId',
    'partnerInvoiceAddress',
    'partnerShippingId',
    'partnerShippingAddress',
    'userId',
    'userName',
    'teamId',
    'teamName',
    'companyId',
    'companyName',
    'warehouseId',
    'warehouseName',
    'pricelistId',
    'pricelistName',
    'currencyId',
    'currencySymbol',
    'currencyRate',
    'paymentTermId',
    'paymentTermName',
    'isCash',
    'isCredit',
    'fiscalPositionId',
    'fiscalPositionName',
    'amountUntaxed',
    'amountTax',
    'amountTotal',
    'amountToInvoice',
    'amountInvoiced',
    'invoiceStatus',
    'invoiceCount',
    'note',
    'clientOrderRef',
    'requireSignature',
    'signature',
    'signedBy',
    'signedOn',
    'requirePayment',
    'prepaymentPercent',
    'locked',
    'isExpired',
    'totalDiscountAmount',
    'amountUntaxedUndiscounted',
    'isFinalConsumer',
    'endCustomerName',
    'endCustomerPhone',
    'endCustomerEmail',
    'exceedsFinalConsumerLimit',
    'emitirFacturaFechaPosterior',
    'fechaFacturar',
    'referrerId',
    'referrerName',
    'tipoCliente',
    'canalCliente',
    'pickingIds',
    'deliveryStatus',
    'taxTotals',
    'creditExceeded',
    'creditCheckBypassed',
    'amountCash',
    'amountUnpaid',
    'totalCostAmount',
    'margin',
    'marginPercent',
    'retenidoAmount',
    'approvalCount',
    'approvedDate',
    'rejectedDate',
    'rejectedReason',
    'collectionSessionId',
    'collectionUserId',
    'saleCreatedUserId',
    'entregarSoloPagado',
    'esParaDespacho',
    'notaAdicional',
    'xUuid',
    'isSynced',
    'lastSyncDate',
    'syncRetryCount',
    'lastSyncAttempt',
    'writeDate',
    'hasQueuedInvoice',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'state',
    'dateOrder',
    'validityDate',
    'commitmentDate',
    'expectedDate',
    'partnerId',
    'partnerVat',
    'partnerStreet',
    'partnerPhone',
    'partnerEmail',
    'partnerAvatar',
    'partnerInvoiceId',
    'partnerShippingId',
    'userId',
    'teamId',
    'companyId',
    'warehouseId',
    'pricelistId',
    'currencyId',
    'currencySymbol',
    'currencyRate',
    'paymentTermId',
    'isCash',
    'isCredit',
    'fiscalPositionId',
    'amountUntaxed',
    'amountTax',
    'amountTotal',
    'amountToInvoice',
    'amountInvoiced',
    'invoiceStatus',
    'invoiceCount',
    'note',
    'clientOrderRef',
    'requireSignature',
    'signature',
    'signedBy',
    'signedOn',
    'requirePayment',
    'prepaymentPercent',
    'locked',
    'isExpired',
    'totalDiscountAmount',
    'amountUntaxedUndiscounted',
    'isFinalConsumer',
    'endCustomerName',
    'endCustomerPhone',
    'endCustomerEmail',
    'exceedsFinalConsumerLimit',
    'emitirFacturaFechaPosterior',
    'fechaFacturar',
    'referrerId',
    'tipoCliente',
    'canalCliente',
    'pickingIds',
    'deliveryStatus',
    'taxTotals',
    'creditExceeded',
    'creditCheckBypassed',
    'amountCash',
    'amountUnpaid',
    'totalCostAmount',
    'margin',
    'marginPercent',
    'retenidoAmount',
    'approvalCount',
    'approvedDate',
    'rejectedDate',
    'rejectedReason',
    'collectionSessionId',
    'collectionUserId',
    'saleCreatedUserId',
    'entregarSoloPagado',
    'esParaDespacho',
    'notaAdicional',
    'xUuid',
  ];
}

/// Global instance of SaleOrderManager.
final saleOrderManager = SaleOrderManager();
