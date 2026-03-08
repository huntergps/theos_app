// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_move_line.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountMoveLine _$AccountMoveLineFromJson(Map<String, dynamic> json) =>
    _AccountMoveLine(
      id: (json['id'] as num?)?.toInt() ?? 0,
      moveId: (json['moveId'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      displayType:
          $enumDecodeNullable(
            _$InvoiceLineDisplayTypeEnumMap,
            json['displayType'],
          ) ??
          InvoiceLineDisplayType.product,
      sequence: (json['sequence'] as num?)?.toInt() ?? 10,
      productId: (json['productId'] as num?)?.toInt(),
      productName: json['productName'] as String?,
      productCode: json['productCode'] as String?,
      productBarcode: json['productBarcode'] as String?,
      productL10nEcAuxiliaryCode: json['productL10nEcAuxiliaryCode'] as String?,
      productType: json['productType'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      productUomId: (json['productUomId'] as num?)?.toInt(),
      productUomName: json['productUomName'] as String?,
      priceUnit: (json['priceUnit'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      priceSubtotal: (json['priceSubtotal'] as num?)?.toDouble() ?? 0.0,
      priceTotal: (json['priceTotal'] as num?)?.toDouble() ?? 0.0,
      taxIds: json['taxIds'] as String?,
      taxNames: json['taxNames'] as String?,
      taxLineId: (json['taxLineId'] as num?)?.toInt(),
      taxLineName: json['taxLineName'] as String?,
      accountId: (json['accountId'] as num?)?.toInt(),
      accountName: json['accountName'] as String?,
      collapseComposition: json['collapseComposition'] as bool? ?? false,
      collapsePrices: json['collapsePrices'] as bool? ?? false,
    );

Map<String, dynamic> _$AccountMoveLineToJson(_AccountMoveLine instance) =>
    <String, dynamic>{
      'id': instance.id,
      'moveId': instance.moveId,
      'name': instance.name,
      'displayType': _$InvoiceLineDisplayTypeEnumMap[instance.displayType]!,
      'sequence': instance.sequence,
      'productId': instance.productId,
      'productName': instance.productName,
      'productCode': instance.productCode,
      'productBarcode': instance.productBarcode,
      'productL10nEcAuxiliaryCode': instance.productL10nEcAuxiliaryCode,
      'productType': instance.productType,
      'quantity': instance.quantity,
      'productUomId': instance.productUomId,
      'productUomName': instance.productUomName,
      'priceUnit': instance.priceUnit,
      'discount': instance.discount,
      'priceSubtotal': instance.priceSubtotal,
      'priceTotal': instance.priceTotal,
      'taxIds': instance.taxIds,
      'taxNames': instance.taxNames,
      'taxLineId': instance.taxLineId,
      'taxLineName': instance.taxLineName,
      'accountId': instance.accountId,
      'accountName': instance.accountName,
      'collapseComposition': instance.collapseComposition,
      'collapsePrices': instance.collapsePrices,
    };

const _$InvoiceLineDisplayTypeEnumMap = {
  InvoiceLineDisplayType.product: 'product',
  InvoiceLineDisplayType.lineSection: 'lineSection',
  InvoiceLineDisplayType.lineNote: 'lineNote',
  InvoiceLineDisplayType.tax: 'tax',
  InvoiceLineDisplayType.paymentTerm: 'paymentTerm',
  InvoiceLineDisplayType.cogs: 'cogs',
};

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for AccountMoveLine.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: account.move.line
class AccountMoveLineManager extends OdooModelManager<AccountMoveLine>
    with GenericDriftOperations<AccountMoveLine> {
  @override
  String get odooModel => 'account.move.line';

  @override
  String get tableName => 'account_move_line';

  @override
  List<String> get odooFields => [
    'id',
    'move_id',
    'name',
    'sequence',
    'product_id',
    'quantity',
    'product_uom_id',
    'price_unit',
    'discount',
    'price_subtotal',
    'price_total',
    'tax_line_id',
    'account_id',
    'collapse_composition',
    'collapse_prices',
  ];

  @override
  AccountMoveLine fromOdoo(Map<String, dynamic> data) {
    return AccountMoveLine(
      id: data['id'] as int? ?? 0,
      moveId: extractMany2oneId(data['move_id']) ?? 0,
      name: parseOdooStringRequired(data['name']),
      displayType: InvoiceLineDisplayType.values.first,
      sequence: parseOdooInt(data['sequence']) ?? 0,
      productId: extractMany2oneId(data['product_id']),
      productName: extractMany2oneName(data['product_id']),
      quantity: parseOdooDouble(data['quantity']) ?? 0.0,
      productUomId: extractMany2oneId(data['product_uom_id']),
      productUomName: extractMany2oneName(data['product_uom_id']),
      priceUnit: parseOdooDouble(data['price_unit']) ?? 0.0,
      discount: parseOdooDouble(data['discount']) ?? 0.0,
      priceSubtotal: parseOdooDouble(data['price_subtotal']) ?? 0.0,
      priceTotal: parseOdooDouble(data['price_total']) ?? 0.0,
      taxLineId: extractMany2oneId(data['tax_line_id']),
      taxLineName: extractMany2oneName(data['tax_line_id']),
      accountId: extractMany2oneId(data['account_id']),
      accountName: extractMany2oneName(data['account_id']),
      collapseComposition: parseOdooBool(data['collapse_composition']),
      collapsePrices: parseOdooBool(data['collapse_prices']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(AccountMoveLine record) {
    return {
      'move_id': record.moveId,
      'name': record.name,
      'sequence': record.sequence,
      'product_id': record.productId,
      'quantity': record.quantity,
      'product_uom_id': record.productUomId,
      'price_unit': record.priceUnit,
      'discount': record.discount,
      'price_subtotal': record.priceSubtotal,
      'price_total': record.priceTotal,
      'tax_line_id': record.taxLineId,
      'account_id': record.accountId,
      'collapse_composition': record.collapseComposition,
      'collapse_prices': record.collapsePrices,
    };
  }

  @override
  AccountMoveLine fromDrift(dynamic row) {
    return AccountMoveLine(
      id: row.odooId as int,
      moveId: row.moveId as int,
      name: row.name as String,
      displayType: (row.displayType as String?) != null
          ? InvoiceLineDisplayType.values.firstWhere(
              (e) => e.name == (row.displayType as String?),
              orElse: () => InvoiceLineDisplayType.values.first,
            )
          : InvoiceLineDisplayType.values.first,
      sequence: row.sequence as int,
      productId: row.productId as int?,
      productName: row.productName as String?,
      productCode: row.productCode as String?,
      productBarcode: row.productBarcode as String?,
      productL10nEcAuxiliaryCode: row.productL10nEcAuxiliaryCode as String?,
      productType: row.productType as String?,
      quantity: row.quantity as double,
      productUomId: row.productUomId as int?,
      productUomName: row.productUomName as String?,
      priceUnit: row.priceUnit as double,
      discount: row.discount as double,
      priceSubtotal: row.priceSubtotal as double,
      priceTotal: row.priceTotal as double,
      taxIds: row.taxIds as String?,
      taxNames: row.taxNames as String?,
      taxLineId: row.taxLineId as int?,
      taxLineName: row.taxLineName as String?,
      accountId: row.accountId as int?,
      accountName: row.accountName as String?,
      collapseComposition: row.collapseComposition as bool,
      collapsePrices: row.collapsePrices as bool,
    );
  }

  @override
  int getId(AccountMoveLine record) => record.id;

  @override
  String? getUuid(AccountMoveLine record) => null;

  @override
  AccountMoveLine withIdAndUuid(AccountMoveLine record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  AccountMoveLine withSyncStatus(AccountMoveLine record, bool isSynced) {
    return record; // No sync status field
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'move_id': 'moveId',
    'name': 'name',
    'sequence': 'sequence',
    'product_id': 'productId',
    'quantity': 'quantity',
    'product_uom_id': 'productUomId',
    'price_unit': 'priceUnit',
    'discount': 'discount',
    'price_subtotal': 'priceSubtotal',
    'price_total': 'priceTotal',
    'tax_line_id': 'taxLineId',
    'account_id': 'accountId',
    'collapse_composition': 'collapseComposition',
    'collapse_prices': 'collapsePrices',
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
      throw StateError('Table \'account_move_line\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(AccountMoveLine record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'move_id': Variable<int>(record.moveId),
      'name': Variable<String>(record.name),
      'sequence': Variable<int>(record.sequence),
      'product_id': driftVar<int>(record.productId),
      'product_id_name': driftVar<String>(record.productName),
      'quantity': Variable<double>(record.quantity),
      'product_uom_id': driftVar<int>(record.productUomId),
      'product_uom_id_name': driftVar<String>(record.productUomName),
      'price_unit': Variable<double>(record.priceUnit),
      'discount': Variable<double>(record.discount),
      'price_subtotal': Variable<double>(record.priceSubtotal),
      'price_total': Variable<double>(record.priceTotal),
      'tax_line_id': driftVar<int>(record.taxLineId),
      'tax_line_id_name': driftVar<String>(record.taxLineName),
      'account_id': driftVar<int>(record.accountId),
      'account_id_name': driftVar<String>(record.accountName),
      'collapse_composition': Variable<bool>(record.collapseComposition),
      'collapse_prices': Variable<bool>(record.collapsePrices),
      'display_type': Variable<String>(record.displayType.name),
      'product_code': driftVar<String>(record.productCode),
      'product_barcode': driftVar<String>(record.productBarcode),
      'product_l10n_ec_auxiliary_code': driftVar<String>(
        record.productL10nEcAuxiliaryCode,
      ),
      'product_type': driftVar<String>(record.productType),
      'tax_ids': driftVar<String>(record.taxIds),
      'tax_names': driftVar<String>(record.taxNames),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'moveId',
    'name',
    'sequence',
    'productId',
    'quantity',
    'productUomId',
    'priceUnit',
    'discount',
    'priceSubtotal',
    'priceTotal',
    'taxLineId',
    'accountId',
    'collapseComposition',
    'collapsePrices',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'moveId': 'Move Id',
    'name': 'Name',
    'displayType': 'Display Type',
    'sequence': 'Sequence',
    'productId': 'Product Id',
    'productName': 'Product Name',
    'productCode': 'Product Code',
    'productBarcode': 'Product Barcode',
    'productL10nEcAuxiliaryCode': 'Product L10n Ec Auxiliary Code',
    'productType': 'Product Type',
    'quantity': 'Quantity',
    'productUomId': 'Product Uom Id',
    'productUomName': 'Product Uom Name',
    'priceUnit': 'Price Unit',
    'discount': 'Discount',
    'priceSubtotal': 'Price Subtotal',
    'priceTotal': 'Price Total',
    'taxIds': 'Tax Ids',
    'taxNames': 'Tax Names',
    'taxLineId': 'Tax Line Id',
    'taxLineName': 'Tax Line Name',
    'accountId': 'Account Id',
    'accountName': 'Account Name',
    'collapseComposition': 'Collapse Composition',
    'collapsePrices': 'Collapse Prices',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(AccountMoveLine record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(AccountMoveLine record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(AccountMoveLine record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(AccountMoveLine record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'moveId':
        return record.moveId;
      case 'name':
        return record.name;
      case 'displayType':
        return record.displayType;
      case 'sequence':
        return record.sequence;
      case 'productId':
        return record.productId;
      case 'productName':
        return record.productName;
      case 'productCode':
        return record.productCode;
      case 'productBarcode':
        return record.productBarcode;
      case 'productL10nEcAuxiliaryCode':
        return record.productL10nEcAuxiliaryCode;
      case 'productType':
        return record.productType;
      case 'quantity':
        return record.quantity;
      case 'productUomId':
        return record.productUomId;
      case 'productUomName':
        return record.productUomName;
      case 'priceUnit':
        return record.priceUnit;
      case 'discount':
        return record.discount;
      case 'priceSubtotal':
        return record.priceSubtotal;
      case 'priceTotal':
        return record.priceTotal;
      case 'taxIds':
        return record.taxIds;
      case 'taxNames':
        return record.taxNames;
      case 'taxLineId':
        return record.taxLineId;
      case 'taxLineName':
        return record.taxLineName;
      case 'accountId':
        return record.accountId;
      case 'accountName':
        return record.accountName;
      case 'collapseComposition':
        return record.collapseComposition;
      case 'collapsePrices':
        return record.collapsePrices;
      default:
        return null;
    }
  }

  @override
  AccountMoveLine applyWebSocketChangesToRecord(
    AccountMoveLine record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      displayType: record.displayType,
      productCode: record.productCode,
      productBarcode: record.productBarcode,
      productL10nEcAuxiliaryCode: record.productL10nEcAuxiliaryCode,
      productType: record.productType,
      taxIds: record.taxIds,
      taxNames: record.taxNames,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'moveId':
        return (obj as dynamic).moveId;
      case 'name':
        return (obj as dynamic).name;
      case 'displayType':
        return (obj as dynamic).displayType;
      case 'sequence':
        return (obj as dynamic).sequence;
      case 'productId':
        return (obj as dynamic).productId;
      case 'productName':
        return (obj as dynamic).productName;
      case 'productCode':
        return (obj as dynamic).productCode;
      case 'productBarcode':
        return (obj as dynamic).productBarcode;
      case 'productL10nEcAuxiliaryCode':
        return (obj as dynamic).productL10nEcAuxiliaryCode;
      case 'productType':
        return (obj as dynamic).productType;
      case 'quantity':
        return (obj as dynamic).quantity;
      case 'productUomId':
        return (obj as dynamic).productUomId;
      case 'productUomName':
        return (obj as dynamic).productUomName;
      case 'priceUnit':
        return (obj as dynamic).priceUnit;
      case 'discount':
        return (obj as dynamic).discount;
      case 'priceSubtotal':
        return (obj as dynamic).priceSubtotal;
      case 'priceTotal':
        return (obj as dynamic).priceTotal;
      case 'taxIds':
        return (obj as dynamic).taxIds;
      case 'taxNames':
        return (obj as dynamic).taxNames;
      case 'taxLineId':
        return (obj as dynamic).taxLineId;
      case 'taxLineName':
        return (obj as dynamic).taxLineName;
      case 'accountId':
        return (obj as dynamic).accountId;
      case 'accountName':
        return (obj as dynamic).accountName;
      case 'collapseComposition':
        return (obj as dynamic).collapseComposition;
      case 'collapsePrices':
        return (obj as dynamic).collapsePrices;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'isSynced':
        return (obj as dynamic).isSynced;
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
    'moveId',
    'name',
    'displayType',
    'sequence',
    'productId',
    'productName',
    'productCode',
    'productBarcode',
    'productL10nEcAuxiliaryCode',
    'productType',
    'quantity',
    'productUomId',
    'productUomName',
    'priceUnit',
    'discount',
    'priceSubtotal',
    'priceTotal',
    'taxIds',
    'taxNames',
    'taxLineId',
    'taxLineName',
    'accountId',
    'accountName',
    'collapseComposition',
    'collapsePrices',
  ];

  @override
  List<String> get writableFieldNames => const [
    'moveId',
    'name',
    'sequence',
    'productId',
    'quantity',
    'productUomId',
    'priceUnit',
    'discount',
    'priceSubtotal',
    'priceTotal',
    'taxLineId',
    'accountId',
    'collapseComposition',
    'collapsePrices',
  ];
}

/// Global instance of AccountMoveLineManager.
final accountMoveLineManager = AccountMoveLineManager();
