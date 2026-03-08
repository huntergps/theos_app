// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_category.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for ProductCategory.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: product.category
class ProductCategoryManager extends OdooModelManager<ProductCategory>
    with GenericDriftOperations<ProductCategory> {
  @override
  String get odooModel => 'product.category';

  @override
  String get tableName => 'product_category';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'complete_name',
    'parent_id',
    'write_date',
  ];

  @override
  ProductCategory fromOdoo(Map<String, dynamic> data) {
    return ProductCategory(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      completeName: parseOdooString(data['complete_name']),
      parentId: extractMany2oneId(data['parent_id']),
      parentName: extractMany2oneName(data['parent_id']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(ProductCategory record) {
    return {
      'name': record.name,
      'complete_name': record.completeName,
      'parent_id': record.parentId,
    };
  }

  @override
  ProductCategory fromDrift(dynamic row) {
    return ProductCategory(
      id: row.odooId as int,
      name: row.name as String,
      completeName: row.completeName as String?,
      parentId: row.parentId as int?,
      parentName: row.parentName as String?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(ProductCategory record) => record.id;

  @override
  String? getUuid(ProductCategory record) => null;

  @override
  ProductCategory withIdAndUuid(ProductCategory record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  ProductCategory withSyncStatus(ProductCategory record, bool isSynced) {
    return record; // No sync status field
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'name': 'name',
    'complete_name': 'completeName',
    'parent_id': 'parentId',
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
      throw StateError('Table \'product_category\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(ProductCategory record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'complete_name': driftVar<String>(record.completeName),
      'parent_id': driftVar<int>(record.parentId),
      'parent_id_name': driftVar<String>(record.parentName),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'completeName',
    'parentId',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'completeName': 'Complete Name',
    'parentId': 'Parent Id',
    'parentName': 'Parent Name',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(ProductCategory record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(ProductCategory record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(ProductCategory record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(ProductCategory record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'completeName':
        return record.completeName;
      case 'parentId':
        return record.parentId;
      case 'parentName':
        return record.parentName;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  ProductCategory applyWebSocketChangesToRecord(
    ProductCategory record,
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
      case 'name':
        return (obj as dynamic).name;
      case 'completeName':
        return (obj as dynamic).completeName;
      case 'parentId':
        return (obj as dynamic).parentId;
      case 'parentName':
        return (obj as dynamic).parentName;
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
    'name',
    'completeName',
    'parentId',
    'parentName',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'completeName',
    'parentId',
  ];
}

/// Global instance of ProductCategoryManager.
final productCategoryManager = ProductCategoryManager();
