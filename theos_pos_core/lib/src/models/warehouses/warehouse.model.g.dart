// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'warehouse.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for Warehouse.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: stock.warehouse
class WarehouseManager extends OdooModelManager<Warehouse>
    with GenericDriftOperations<Warehouse> {
  @override
  String get odooModel => 'stock.warehouse';

  @override
  String get tableName => 'stock_warehouse';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'code',
    'company_id',
    'write_date',
  ];

  @override
  Warehouse fromOdoo(Map<String, dynamic> data) {
    return Warehouse(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      code: parseOdooString(data['code']),
      companyId: extractMany2oneId(data['company_id']),
      companyName: extractMany2oneName(data['company_id']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(Warehouse record) {
    return {
      'name': record.name,
      'code': record.code,
      'company_id': record.companyId,
    };
  }

  @override
  Warehouse fromDrift(dynamic row) {
    return Warehouse(
      id: row.odooId as int,
      name: row.name as String,
      code: row.code as String?,
      companyId: row.companyId as int?,
      companyName: row.companyName as String?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(Warehouse record) => record.id;

  @override
  String? getUuid(Warehouse record) => null;

  @override
  Warehouse withIdAndUuid(Warehouse record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  Warehouse withSyncStatus(Warehouse record, bool isSynced) {
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
    'code': 'code',
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
      throw StateError('Table \'stock_warehouse\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(Warehouse record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'code': driftVar<String>(record.code),
      'company_id': driftVar<int>(record.companyId),
      'company_id_name': driftVar<String>(record.companyName),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = ['name', 'code', 'companyId'];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'code': 'Code',
    'companyId': 'Company Id',
    'companyName': 'Company Name',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(Warehouse record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(Warehouse record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(Warehouse record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(Warehouse record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'code':
        return record.code;
      case 'companyId':
        return record.companyId;
      case 'companyName':
        return record.companyName;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  Warehouse applyWebSocketChangesToRecord(
    Warehouse record,
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
      case 'code':
        return (obj as dynamic).code;
      case 'companyId':
        return (obj as dynamic).companyId;
      case 'companyName':
        return (obj as dynamic).companyName;
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
    'code',
    'companyId',
    'companyName',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const ['name', 'code', 'companyId'];
}

/// Global instance of WarehouseManager.
final warehouseManager = WarehouseManager();
