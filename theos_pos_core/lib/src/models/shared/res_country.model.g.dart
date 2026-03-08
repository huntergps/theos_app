// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'res_country.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for ResCountry.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: res.country
class ResCountryManager extends OdooModelManager<ResCountry>
    with GenericDriftOperations<ResCountry> {
  @override
  String get odooModel => 'res.country';

  @override
  String get tableName => 'res_country';

  @override
  List<String> get odooFields => ['id', 'name', 'code', 'write_date'];

  @override
  ResCountry fromOdoo(Map<String, dynamic> data) {
    return ResCountry(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      code: parseOdooString(data['code']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(ResCountry record) {
    return {'name': record.name, 'code': record.code};
  }

  @override
  ResCountry fromDrift(dynamic row) {
    return ResCountry(
      id: row.odooId as int,
      name: row.name as String,
      code: row.code as String?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(ResCountry record) => record.id;

  @override
  String? getUuid(ResCountry record) => null;

  @override
  ResCountry withIdAndUuid(ResCountry record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  ResCountry withSyncStatus(ResCountry record, bool isSynced) {
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
      throw StateError('Table \'res_country\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(ResCountry record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'code': driftVar<String>(record.code),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = ['name', 'code'];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'code': 'Code',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(ResCountry record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(ResCountry record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(ResCountry record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(ResCountry record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'code':
        return record.code;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  ResCountry applyWebSocketChangesToRecord(
    ResCountry record,
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
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const ['name', 'code'];
}

/// Global instance of ResCountryManager.
final resCountryManager = ResCountryManager();
