// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_order_line.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SaleOrderLine _$SaleOrderLineFromJson(Map<String, dynamic> json) =>
    _SaleOrderLine(
      id: (json['id'] as num).toInt(),
      lineUuid: json['lineUuid'] as String?,
      orderId: (json['orderId'] as num).toInt(),
      sequence: (json['sequence'] as num?)?.toInt() ?? 10,
      displayType:
          $enumDecodeNullable(_$LineDisplayTypeEnumMap, json['displayType']) ??
          LineDisplayType.product,
      isDownpayment: json['isDownpayment'] as bool? ?? false,
      productId: (json['productId'] as num?)?.toInt(),
      productName: json['productName'] as String?,
      productCode: json['productCode'] as String?,
      productTemplateId: (json['productTemplateId'] as num?)?.toInt(),
      productTemplateName: json['productTemplateName'] as String?,
      productType: json['productType'] as String?,
      categId: (json['categId'] as num?)?.toInt(),
      categName: json['categName'] as String?,
      name: json['name'] as String,
      productUomQty: (json['productUomQty'] as num?)?.toDouble() ?? 1.0,
      productUomId: (json['productUomId'] as num?)?.toInt(),
      productUomName: json['productUomName'] as String?,
      priceUnit: (json['priceUnit'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      priceSubtotal: (json['priceSubtotal'] as num?)?.toDouble() ?? 0.0,
      priceTax: (json['priceTax'] as num?)?.toDouble() ?? 0.0,
      priceTotal: (json['priceTotal'] as num?)?.toDouble() ?? 0.0,
      priceReduce: (json['priceReduce'] as num?)?.toDouble() ?? 0.0,
      taxIds: json['taxIds'] as String?,
      taxNames: json['taxNames'] as String?,
      qtyDelivered: (json['qtyDelivered'] as num?)?.toDouble() ?? 0.0,
      customerLead: (json['customerLead'] as num?)?.toDouble() ?? 0.0,
      qtyInvoiced: (json['qtyInvoiced'] as num?)?.toDouble() ?? 0.0,
      qtyToInvoice: (json['qtyToInvoice'] as num?)?.toDouble() ?? 0.0,
      invoiceStatus:
          $enumDecodeNullable(
            _$LineInvoiceStatusEnumMap,
            json['invoiceStatus'],
          ) ??
          LineInvoiceStatus.no,
      orderState: json['orderState'] as String?,
      collapsePrices: json['collapsePrices'] as bool? ?? false,
      collapseComposition: json['collapseComposition'] as bool? ?? false,
      isOptional: json['isOptional'] as bool? ?? false,
      isSynced: json['isSynced'] as bool? ?? false,
      lastSyncDate: json['lastSyncDate'] == null
          ? null
          : DateTime.parse(json['lastSyncDate'] as String),
      writeDate: json['writeDate'] == null
          ? null
          : DateTime.parse(json['writeDate'] as String),
      isUnitProduct: json['isUnitProduct'] as bool? ?? true,
    );

Map<String, dynamic> _$SaleOrderLineToJson(_SaleOrderLine instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lineUuid': instance.lineUuid,
      'orderId': instance.orderId,
      'sequence': instance.sequence,
      'displayType': _$LineDisplayTypeEnumMap[instance.displayType]!,
      'isDownpayment': instance.isDownpayment,
      'productId': instance.productId,
      'productName': instance.productName,
      'productCode': instance.productCode,
      'productTemplateId': instance.productTemplateId,
      'productTemplateName': instance.productTemplateName,
      'productType': instance.productType,
      'categId': instance.categId,
      'categName': instance.categName,
      'name': instance.name,
      'productUomQty': instance.productUomQty,
      'productUomId': instance.productUomId,
      'productUomName': instance.productUomName,
      'priceUnit': instance.priceUnit,
      'discount': instance.discount,
      'discountAmount': instance.discountAmount,
      'priceSubtotal': instance.priceSubtotal,
      'priceTax': instance.priceTax,
      'priceTotal': instance.priceTotal,
      'priceReduce': instance.priceReduce,
      'taxIds': instance.taxIds,
      'taxNames': instance.taxNames,
      'qtyDelivered': instance.qtyDelivered,
      'customerLead': instance.customerLead,
      'qtyInvoiced': instance.qtyInvoiced,
      'qtyToInvoice': instance.qtyToInvoice,
      'invoiceStatus': _$LineInvoiceStatusEnumMap[instance.invoiceStatus]!,
      'orderState': instance.orderState,
      'collapsePrices': instance.collapsePrices,
      'collapseComposition': instance.collapseComposition,
      'isOptional': instance.isOptional,
      'isSynced': instance.isSynced,
      'lastSyncDate': instance.lastSyncDate?.toIso8601String(),
      'writeDate': instance.writeDate?.toIso8601String(),
      'isUnitProduct': instance.isUnitProduct,
    };

const _$LineDisplayTypeEnumMap = {
  LineDisplayType.product: '',
  LineDisplayType.lineSection: 'line_section',
  LineDisplayType.lineSubsection: 'line_subsection',
  LineDisplayType.lineNote: 'line_note',
};

const _$LineInvoiceStatusEnumMap = {
  LineInvoiceStatus.no: 'no',
  LineInvoiceStatus.toInvoice: 'to invoice',
  LineInvoiceStatus.invoiced: 'invoiced',
  LineInvoiceStatus.upselling: 'upselling',
};

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for SaleOrderLine.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: sale.order.line
class SaleOrderLineManager extends OdooModelManager<SaleOrderLine>
    with GenericDriftOperations<SaleOrderLine> {
  @override
  String get odooModel => 'sale.order.line';

  @override
  String get tableName => 'sale_order_line';

  @override
  List<String> get odooFields => [
    'id',
    'order_id',
    'sequence',
    'display_type',
    'is_downpayment',
    'product_id',
    'product_default_code',
    'product_template_id',
    'product_type',
    'categ_id',
    'name',
    'product_uom_qty',
    'product_uom_id',
    'price_unit',
    'discount',
    'discount_amount',
    'price_subtotal',
    'price_tax',
    'price_total',
    'price_reduce_taxexcl',
    'tax_ids',
    'qty_delivered',
    'customer_lead',
    'qty_invoiced',
    'qty_to_invoice',
    'invoice_status',
    'state',
    'collapse_prices',
    'collapse_composition',
    'is_optional',
    'write_date',
  ];

  @override
  SaleOrderLine fromOdoo(Map<String, dynamic> data) {
    return SaleOrderLine(
      id: data['id'] as int? ?? 0,
      orderId: extractMany2oneId(data['order_id']) ?? 0,
      sequence: parseOdooInt(data['sequence']) ?? 0,
      displayType: LineDisplayType.values.firstWhere(
        (e) => e.code == parseOdooSelection(data['display_type']),
        orElse: () => LineDisplayType.values.first,
      ),
      isDownpayment: parseOdooBool(data['is_downpayment']),
      productId: extractMany2oneId(data['product_id']),
      productName: extractMany2oneName(data['product_id']),
      productCode: parseOdooString(data['product_default_code']),
      productTemplateId: extractMany2oneId(data['product_template_id']),
      productTemplateName: extractMany2oneName(data['product_template_id']),
      productType: parseOdooString(data['product_type']),
      categId: extractMany2oneId(data['categ_id']),
      categName: extractMany2oneName(data['categ_id']),
      name: parseOdooStringRequired(data['name']),
      productUomQty: parseOdooDouble(data['product_uom_qty']) ?? 0.0,
      productUomId: extractMany2oneId(data['product_uom_id']),
      productUomName: extractMany2oneName(data['product_uom_id']),
      priceUnit: parseOdooDouble(data['price_unit']) ?? 0.0,
      discount: parseOdooDouble(data['discount']) ?? 0.0,
      discountAmount: parseOdooDouble(data['discount_amount']) ?? 0.0,
      priceSubtotal: parseOdooDouble(data['price_subtotal']) ?? 0.0,
      priceTax: parseOdooDouble(data['price_tax']) ?? 0.0,
      priceTotal: parseOdooDouble(data['price_total']) ?? 0.0,
      priceReduce: parseOdooDouble(data['price_reduce_taxexcl']) ?? 0.0,
      taxIds: parseOdooString(data['tax_ids']),
      qtyDelivered: parseOdooDouble(data['qty_delivered']) ?? 0.0,
      customerLead: parseOdooDouble(data['customer_lead']) ?? 0.0,
      qtyInvoiced: parseOdooDouble(data['qty_invoiced']) ?? 0.0,
      qtyToInvoice: parseOdooDouble(data['qty_to_invoice']) ?? 0.0,
      invoiceStatus: LineInvoiceStatus.values.firstWhere(
        (e) => e.code == parseOdooSelection(data['invoice_status']),
        orElse: () => LineInvoiceStatus.values.first,
      ),
      orderState: parseOdooString(data['state']),
      collapsePrices: parseOdooBool(data['collapse_prices']),
      collapseComposition: parseOdooBool(data['collapse_composition']),
      isOptional: parseOdooBool(data['is_optional']),
      isSynced: false,
      writeDate: parseOdooDateTime(data['write_date']),
      isUnitProduct: false,
    );
  }

  @override
  Map<String, dynamic> toOdoo(SaleOrderLine record) {
    return {
      'order_id': record.orderId,
      'sequence': record.sequence,
      'display_type': record.displayType.code,
      'is_downpayment': record.isDownpayment,
      'product_id': record.productId,
      'product_default_code': record.productCode,
      'product_template_id': record.productTemplateId,
      'product_type': record.productType,
      'categ_id': record.categId,
      'name': record.name,
      'product_uom_qty': record.productUomQty,
      'product_uom_id': record.productUomId,
      'price_unit': record.priceUnit,
      'discount': record.discount,
      'discount_amount': record.discountAmount,
      'price_subtotal': record.priceSubtotal,
      'price_tax': record.priceTax,
      'price_total': record.priceTotal,
      'price_reduce_taxexcl': record.priceReduce,
      'tax_ids': record.taxIds,
      'qty_delivered': record.qtyDelivered,
      'customer_lead': record.customerLead,
      'qty_invoiced': record.qtyInvoiced,
      'qty_to_invoice': record.qtyToInvoice,
      'invoice_status': record.invoiceStatus.code,
      'state': record.orderState,
      'collapse_prices': record.collapsePrices,
      'collapse_composition': record.collapseComposition,
      'is_optional': record.isOptional,
    };
  }

  @override
  SaleOrderLine fromDrift(dynamic row) {
    return SaleOrderLine(
      id: row.odooId as int,
      lineUuid: row.lineUuid as String?,
      orderId: row.orderId as int,
      sequence: row.sequence as int,
      displayType: LineDisplayType.values.firstWhere(
        (e) => e.code == (row.displayType as String?),
        orElse: () => LineDisplayType.values.first,
      ),
      isDownpayment: row.isDownpayment as bool,
      productId: row.productId as int?,
      productName: row.productName as String?,
      productCode: row.productDefaultCode as String?,
      productTemplateId: row.productTemplateId as int?,
      productTemplateName: row.productTemplateName as String?,
      productType: row.productType as String?,
      categId: row.categId as int?,
      categName: row.categName as String?,
      name: row.name as String,
      productUomQty: row.productUomQty as double,
      productUomId: row.productUomId as int?,
      productUomName: row.productUomName as String?,
      priceUnit: row.priceUnit as double,
      discount: row.discount as double,
      discountAmount: row.discountAmount as double,
      priceSubtotal: row.priceSubtotal as double,
      priceTax: row.priceTax as double,
      priceTotal: row.priceTotal as double,
      priceReduce: row.priceReduceTaxexcl as double,
      taxIds: row.taxIds as String?,
      taxNames: row.taxNames as String?,
      qtyDelivered: row.qtyDelivered as double,
      customerLead: row.customerLead as double,
      qtyInvoiced: row.qtyInvoiced as double,
      qtyToInvoice: row.qtyToInvoice as double,
      invoiceStatus: LineInvoiceStatus.values.firstWhere(
        (e) => e.code == (row.invoiceStatus as String?),
        orElse: () => LineInvoiceStatus.values.first,
      ),
      orderState: row.state as String?,
      collapsePrices: row.collapsePrices as bool,
      collapseComposition: row.collapseComposition as bool,
      isOptional: row.isOptional as bool,
      isSynced: row.isSynced as bool? ?? false,
      lastSyncDate: row.lastSyncDate as DateTime?,
      writeDate: row.writeDate as DateTime?,
      isUnitProduct: row.isUnitProduct as bool? ?? false,
    );
  }

  @override
  int getId(SaleOrderLine record) => record.id;

  @override
  String? getUuid(SaleOrderLine record) => null;

  @override
  SaleOrderLine withIdAndUuid(SaleOrderLine record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  SaleOrderLine withSyncStatus(SaleOrderLine record, bool isSynced) {
    return record.copyWith(isSynced: isSynced);
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'order_id': 'orderId',
    'sequence': 'sequence',
    'display_type': 'displayType',
    'is_downpayment': 'isDownpayment',
    'product_id': 'productId',
    'product_default_code': 'productCode',
    'product_template_id': 'productTemplateId',
    'product_type': 'productType',
    'categ_id': 'categId',
    'name': 'name',
    'product_uom_qty': 'productUomQty',
    'product_uom_id': 'productUomId',
    'price_unit': 'priceUnit',
    'discount': 'discount',
    'discount_amount': 'discountAmount',
    'price_subtotal': 'priceSubtotal',
    'price_tax': 'priceTax',
    'price_total': 'priceTotal',
    'price_reduce_taxexcl': 'priceReduce',
    'tax_ids': 'taxIds',
    'qty_delivered': 'qtyDelivered',
    'customer_lead': 'customerLead',
    'qty_invoiced': 'qtyInvoiced',
    'qty_to_invoice': 'qtyToInvoice',
    'invoice_status': 'invoiceStatus',
    'state': 'orderState',
    'collapse_prices': 'collapsePrices',
    'collapse_composition': 'collapseComposition',
    'is_optional': 'isOptional',
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
      throw StateError('Table \'sale_order_line\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(SaleOrderLine record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'order_id': Variable<int>(record.orderId),
      'sequence': Variable<int>(record.sequence),
      'display_type': Variable<String>(record.displayType.code),
      'is_downpayment': Variable<bool>(record.isDownpayment),
      'product_id': driftVar<int>(record.productId),
      'product_id_name': driftVar<String>(record.productName),
      'product_default_code': driftVar<String>(record.productCode),
      'product_template_id': driftVar<int>(record.productTemplateId),
      'product_template_id_name': driftVar<String>(record.productTemplateName),
      'product_type': driftVar<String>(record.productType),
      'categ_id': driftVar<int>(record.categId),
      'categ_id_name': driftVar<String>(record.categName),
      'name': Variable<String>(record.name),
      'product_uom_qty': Variable<double>(record.productUomQty),
      'product_uom_id': driftVar<int>(record.productUomId),
      'product_uom_id_name': driftVar<String>(record.productUomName),
      'price_unit': Variable<double>(record.priceUnit),
      'discount': Variable<double>(record.discount),
      'discount_amount': Variable<double>(record.discountAmount),
      'price_subtotal': Variable<double>(record.priceSubtotal),
      'price_tax': Variable<double>(record.priceTax),
      'price_total': Variable<double>(record.priceTotal),
      'price_reduce_taxexcl': Variable<double>(record.priceReduce),
      'tax_ids': driftVar<String>(record.taxIds),
      'qty_delivered': Variable<double>(record.qtyDelivered),
      'customer_lead': Variable<double>(record.customerLead),
      'qty_invoiced': Variable<double>(record.qtyInvoiced),
      'qty_to_invoice': Variable<double>(record.qtyToInvoice),
      'invoice_status': Variable<String>(record.invoiceStatus.code),
      'state': driftVar<String>(record.orderState),
      'collapse_prices': Variable<bool>(record.collapsePrices),
      'collapse_composition': Variable<bool>(record.collapseComposition),
      'is_optional': Variable<bool>(record.isOptional),
      'write_date': driftVar<DateTime>(record.writeDate),
      'line_uuid': driftVar<String>(record.lineUuid),
      'tax_names': driftVar<String>(record.taxNames),
      'is_synced': Variable<bool>(record.isSynced),
      'last_sync_date': driftVar<DateTime>(record.lastSyncDate),
      'is_unit_product': Variable<bool>(record.isUnitProduct),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'orderId',
    'sequence',
    'displayType',
    'isDownpayment',
    'productId',
    'productCode',
    'productTemplateId',
    'productType',
    'categId',
    'name',
    'productUomQty',
    'productUomId',
    'priceUnit',
    'discount',
    'discountAmount',
    'priceSubtotal',
    'priceTax',
    'priceTotal',
    'priceReduce',
    'taxIds',
    'qtyDelivered',
    'customerLead',
    'qtyInvoiced',
    'qtyToInvoice',
    'invoiceStatus',
    'orderState',
    'collapsePrices',
    'collapseComposition',
    'isOptional',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'lineUuid': 'Line Uuid',
    'orderId': 'Order Id',
    'sequence': 'Sequence',
    'displayType': 'Display Type',
    'isDownpayment': 'Is Downpayment',
    'productId': 'Product Id',
    'productName': 'Product Name',
    'productCode': 'Product Code',
    'productTemplateId': 'Product Template Id',
    'productTemplateName': 'Product Template Name',
    'productType': 'Product Type',
    'categId': 'Categ Id',
    'categName': 'Categ Name',
    'name': 'Name',
    'productUomQty': 'Product Uom Qty',
    'productUomId': 'Product Uom Id',
    'productUomName': 'Product Uom Name',
    'priceUnit': 'Price Unit',
    'discount': 'Discount',
    'discountAmount': 'Discount Amount',
    'priceSubtotal': 'Price Subtotal',
    'priceTax': 'Price Tax',
    'priceTotal': 'Price Total',
    'priceReduce': 'Price Reduce',
    'taxIds': 'Tax Ids',
    'taxNames': 'Tax Names',
    'qtyDelivered': 'Qty Delivered',
    'customerLead': 'Customer Lead',
    'qtyInvoiced': 'Qty Invoiced',
    'qtyToInvoice': 'Qty To Invoice',
    'invoiceStatus': 'Invoice Status',
    'orderState': 'Order State',
    'collapsePrices': 'Collapse Prices',
    'collapseComposition': 'Collapse Composition',
    'isOptional': 'Is Optional',
    'isSynced': 'Is Synced',
    'lastSyncDate': 'Last Sync Date',
    'writeDate': 'Write Date',
    'isUnitProduct': 'Is Unit Product',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(SaleOrderLine record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(SaleOrderLine record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(SaleOrderLine record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(SaleOrderLine record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'lineUuid':
        return record.lineUuid;
      case 'orderId':
        return record.orderId;
      case 'sequence':
        return record.sequence;
      case 'displayType':
        return record.displayType;
      case 'isDownpayment':
        return record.isDownpayment;
      case 'productId':
        return record.productId;
      case 'productName':
        return record.productName;
      case 'productCode':
        return record.productCode;
      case 'productTemplateId':
        return record.productTemplateId;
      case 'productTemplateName':
        return record.productTemplateName;
      case 'productType':
        return record.productType;
      case 'categId':
        return record.categId;
      case 'categName':
        return record.categName;
      case 'name':
        return record.name;
      case 'productUomQty':
        return record.productUomQty;
      case 'productUomId':
        return record.productUomId;
      case 'productUomName':
        return record.productUomName;
      case 'priceUnit':
        return record.priceUnit;
      case 'discount':
        return record.discount;
      case 'discountAmount':
        return record.discountAmount;
      case 'priceSubtotal':
        return record.priceSubtotal;
      case 'priceTax':
        return record.priceTax;
      case 'priceTotal':
        return record.priceTotal;
      case 'priceReduce':
        return record.priceReduce;
      case 'taxIds':
        return record.taxIds;
      case 'taxNames':
        return record.taxNames;
      case 'qtyDelivered':
        return record.qtyDelivered;
      case 'customerLead':
        return record.customerLead;
      case 'qtyInvoiced':
        return record.qtyInvoiced;
      case 'qtyToInvoice':
        return record.qtyToInvoice;
      case 'invoiceStatus':
        return record.invoiceStatus;
      case 'orderState':
        return record.orderState;
      case 'collapsePrices':
        return record.collapsePrices;
      case 'collapseComposition':
        return record.collapseComposition;
      case 'isOptional':
        return record.isOptional;
      case 'isSynced':
        return record.isSynced;
      case 'lastSyncDate':
        return record.lastSyncDate;
      case 'writeDate':
        return record.writeDate;
      case 'isUnitProduct':
        return record.isUnitProduct;
      default:
        return null;
    }
  }

  @override
  SaleOrderLine applyWebSocketChangesToRecord(
    SaleOrderLine record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      lineUuid: record.lineUuid,
      taxNames: record.taxNames,
      isSynced: record.isSynced,
      lastSyncDate: record.lastSyncDate,
      isUnitProduct: record.isUnitProduct,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'lineUuid':
        return (obj as dynamic).lineUuid;
      case 'orderId':
        return (obj as dynamic).orderId;
      case 'sequence':
        return (obj as dynamic).sequence;
      case 'displayType':
        return (obj as dynamic).displayType;
      case 'isDownpayment':
        return (obj as dynamic).isDownpayment;
      case 'productId':
        return (obj as dynamic).productId;
      case 'productName':
        return (obj as dynamic).productName;
      case 'productCode':
        return (obj as dynamic).productDefaultCode;
      case 'productTemplateId':
        return (obj as dynamic).productTemplateId;
      case 'productTemplateName':
        return (obj as dynamic).productTemplateName;
      case 'productType':
        return (obj as dynamic).productType;
      case 'categId':
        return (obj as dynamic).categId;
      case 'categName':
        return (obj as dynamic).categName;
      case 'name':
        return (obj as dynamic).name;
      case 'productUomQty':
        return (obj as dynamic).productUomQty;
      case 'productUomId':
        return (obj as dynamic).productUomId;
      case 'productUomName':
        return (obj as dynamic).productUomName;
      case 'priceUnit':
        return (obj as dynamic).priceUnit;
      case 'discount':
        return (obj as dynamic).discount;
      case 'discountAmount':
        return (obj as dynamic).discountAmount;
      case 'priceSubtotal':
        return (obj as dynamic).priceSubtotal;
      case 'priceTax':
        return (obj as dynamic).priceTax;
      case 'priceTotal':
        return (obj as dynamic).priceTotal;
      case 'priceReduce':
        return (obj as dynamic).priceReduceTaxexcl;
      case 'taxIds':
        return (obj as dynamic).taxIds;
      case 'taxNames':
        return (obj as dynamic).taxNames;
      case 'qtyDelivered':
        return (obj as dynamic).qtyDelivered;
      case 'customerLead':
        return (obj as dynamic).customerLead;
      case 'qtyInvoiced':
        return (obj as dynamic).qtyInvoiced;
      case 'qtyToInvoice':
        return (obj as dynamic).qtyToInvoice;
      case 'invoiceStatus':
        return (obj as dynamic).invoiceStatus;
      case 'orderState':
        return (obj as dynamic).state;
      case 'collapsePrices':
        return (obj as dynamic).collapsePrices;
      case 'collapseComposition':
        return (obj as dynamic).collapseComposition;
      case 'isOptional':
        return (obj as dynamic).isOptional;
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'lastSyncDate':
        return (obj as dynamic).lastSyncDate;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'isUnitProduct':
        return (obj as dynamic).isUnitProduct;
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
    'lineUuid',
    'orderId',
    'sequence',
    'displayType',
    'isDownpayment',
    'productId',
    'productName',
    'productCode',
    'productTemplateId',
    'productTemplateName',
    'productType',
    'categId',
    'categName',
    'name',
    'productUomQty',
    'productUomId',
    'productUomName',
    'priceUnit',
    'discount',
    'discountAmount',
    'priceSubtotal',
    'priceTax',
    'priceTotal',
    'priceReduce',
    'taxIds',
    'taxNames',
    'qtyDelivered',
    'customerLead',
    'qtyInvoiced',
    'qtyToInvoice',
    'invoiceStatus',
    'orderState',
    'collapsePrices',
    'collapseComposition',
    'isOptional',
    'isSynced',
    'lastSyncDate',
    'writeDate',
    'isUnitProduct',
  ];

  @override
  List<String> get writableFieldNames => const [
    'orderId',
    'sequence',
    'displayType',
    'isDownpayment',
    'productId',
    'productCode',
    'productTemplateId',
    'productType',
    'categId',
    'name',
    'productUomQty',
    'productUomId',
    'priceUnit',
    'discount',
    'discountAmount',
    'priceSubtotal',
    'priceTax',
    'priceTotal',
    'priceReduce',
    'taxIds',
    'qtyDelivered',
    'customerLead',
    'qtyInvoiced',
    'qtyToInvoice',
    'invoiceStatus',
    'orderState',
    'collapsePrices',
    'collapseComposition',
    'isOptional',
  ];
}

/// Global instance of SaleOrderLineManager.
final saleOrderLineManager = SaleOrderLineManager();
