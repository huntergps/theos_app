// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'uom.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for Uom.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: uom.uom
class UomManager extends OdooModelManager<Uom>
    with GenericDriftOperations<Uom> {
  @override
  String get odooModel => 'uom.uom';

  @override
  String get tableName => 'uom_uom';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'category_id',
    'uom_type',
    'factor',
    'factor_inv',
    'rounding',
    'active',
    'write_date',
  ];

  @override
  Uom fromOdoo(Map<String, dynamic> data) {
    return Uom(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      categoryId: extractMany2oneId(data['category_id']),
      categoryName: extractMany2oneName(data['category_id']),
      uomType: UomType.values.firstWhere(
        (e) => e.name == parseOdooSelection(data['uom_type']),
        orElse: () => UomType.values.first,
      ),
      factor: parseOdooDouble(data['factor']) ?? 0.0,
      factorInv: parseOdooDouble(data['factor_inv']) ?? 0.0,
      rounding: parseOdooDouble(data['rounding']) ?? 0.0,
      active: parseOdooBool(data['active']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(Uom record) {
    return {
      'name': record.name,
      'category_id': record.categoryId,
      'uom_type': record.uomType.name,
      'factor': record.factor,
      'factor_inv': record.factorInv,
      'rounding': record.rounding,
      'active': record.active,
    };
  }

  @override
  Uom fromDrift(dynamic row) {
    return Uom(
      id: row.odooId as int,
      name: row.name as String,
      categoryId: row.categoryId as int?,
      categoryName: row.categoryName as String?,
      uomType: UomType.values.firstWhere(
        (e) => e.name == (row.uomType as String?),
        orElse: () => UomType.values.first,
      ),
      factor: row.factor as double,
      factorInv: row.factorInv as double,
      rounding: row.rounding as double,
      active: row.active as bool,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(Uom record) => record.id;

  @override
  String? getUuid(Uom record) => null;

  @override
  Uom withIdAndUuid(Uom record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  Uom withSyncStatus(Uom record, bool isSynced) {
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
    'category_id': 'categoryId',
    'uom_type': 'uomType',
    'factor': 'factor',
    'factor_inv': 'factorInv',
    'rounding': 'rounding',
    'active': 'active',
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
      throw StateError('Table \'uom_uom\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(Uom record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'category_id': driftVar<int>(record.categoryId),
      'category_id_name': driftVar<String>(record.categoryName),
      'uom_type': Variable<String>(record.uomType.name),
      'factor': Variable<double>(record.factor),
      'factor_inv': Variable<double>(record.factorInv),
      'rounding': Variable<double>(record.rounding),
      'active': Variable<bool>(record.active),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'categoryId',
    'uomType',
    'factor',
    'factorInv',
    'rounding',
    'active',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'categoryId': 'Category Id',
    'categoryName': 'Category Name',
    'uomType': 'Uom Type',
    'factor': 'Factor',
    'factorInv': 'Factor Inv',
    'rounding': 'Rounding',
    'active': 'Active',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(Uom record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(Uom record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(Uom record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(Uom record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'categoryId':
        return record.categoryId;
      case 'categoryName':
        return record.categoryName;
      case 'uomType':
        return record.uomType;
      case 'factor':
        return record.factor;
      case 'factorInv':
        return record.factorInv;
      case 'rounding':
        return record.rounding;
      case 'active':
        return record.active;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  Uom applyWebSocketChangesToRecord(Uom record, Map<String, dynamic> changes) {
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
      case 'categoryId':
        return (obj as dynamic).categoryId;
      case 'categoryName':
        return (obj as dynamic).categoryName;
      case 'uomType':
        return (obj as dynamic).uomType;
      case 'factor':
        return (obj as dynamic).factor;
      case 'factorInv':
        return (obj as dynamic).factorInv;
      case 'rounding':
        return (obj as dynamic).rounding;
      case 'active':
        return (obj as dynamic).active;
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
    'categoryId',
    'categoryName',
    'uomType',
    'factor',
    'factorInv',
    'rounding',
    'active',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'categoryId',
    'uomType',
    'factor',
    'factorInv',
    'rounding',
    'active',
  ];
}

/// Global instance of UomManager.
final uomManager = UomManager();
