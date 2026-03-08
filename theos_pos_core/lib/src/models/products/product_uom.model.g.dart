// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_uom.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for ProductUom.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: product.uom
class ProductUomManager extends OdooModelManager<ProductUom>
    with GenericDriftOperations<ProductUom> {
  @override
  String get odooModel => 'product.uom';

  @override
  String get tableName => 'product_uom';

  @override
  List<String> get odooFields => [
    'id',
    'product_id',
    'uom_id',
    'barcode',
    'company_id',
    'write_date',
  ];

  @override
  ProductUom fromOdoo(Map<String, dynamic> data) {
    return ProductUom(
      id: data['id'] as int? ?? 0,
      productId: extractMany2oneId(data['product_id']) ?? 0,
      uomId: extractMany2oneId(data['uom_id']) ?? 0,
      uomName: extractMany2oneName(data['uom_id']),
      barcode: parseOdooStringRequired(data['barcode']),
      companyId: extractMany2oneId(data['company_id']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(ProductUom record) {
    return {
      'product_id': record.productId,
      'uom_id': record.uomId,
      'barcode': record.barcode,
      'company_id': record.companyId,
    };
  }

  @override
  ProductUom fromDrift(dynamic row) {
    return ProductUom(
      id: row.odooId as int,
      productId: row.productId as int,
      uomId: row.uomId as int,
      uomName: row.uomName as String?,
      barcode: row.barcode as String,
      companyId: row.companyId as int?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(ProductUom record) => record.id;

  @override
  String? getUuid(ProductUom record) => null;

  @override
  ProductUom withIdAndUuid(ProductUom record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  ProductUom withSyncStatus(ProductUom record, bool isSynced) {
    return record; // No sync status field
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'product_id': 'productId',
    'uom_id': 'uomId',
    'barcode': 'barcode',
    'company_id': 'companyId',
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
      throw StateError('Table \'product_uom\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(ProductUom record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'product_id': Variable<int>(record.productId),
      'uom_id': Variable<int>(record.uomId),
      'uom_id_name': driftVar<String>(record.uomName),
      'barcode': Variable<String>(record.barcode),
      'company_id': driftVar<int>(record.companyId),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'productId',
    'uomId',
    'barcode',
    'companyId',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'productId': 'Product Id',
    'uomId': 'Uom Id',
    'uomName': 'Uom Name',
    'barcode': 'Barcode',
    'companyId': 'Company Id',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(ProductUom record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(ProductUom record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(ProductUom record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(ProductUom record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'productId':
        return record.productId;
      case 'uomId':
        return record.uomId;
      case 'uomName':
        return record.uomName;
      case 'barcode':
        return record.barcode;
      case 'companyId':
        return record.companyId;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  ProductUom applyWebSocketChangesToRecord(
    ProductUom record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'productId':
        return (obj as dynamic).productId;
      case 'uomId':
        return (obj as dynamic).uomId;
      case 'uomName':
        return (obj as dynamic).uomName;
      case 'barcode':
        return (obj as dynamic).barcode;
      case 'companyId':
        return (obj as dynamic).companyId;
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
    'productId',
    'uomId',
    'uomName',
    'barcode',
    'companyId',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'productId',
    'uomId',
    'barcode',
    'companyId',
  ];
}

/// Global instance of ProductUomManager.
final productUomManager = ProductUomManager();
