// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'res_lang.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for ResLang.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: res.lang
class ResLangManager extends OdooModelManager<ResLang>
    with GenericDriftOperations<ResLang> {
  @override
  String get odooModel => 'res.lang';

  @override
  String get tableName => 'res_lang';

  @override
  List<String> get odooFields => ['id', 'name', 'code', 'active', 'write_date'];

  @override
  ResLang fromOdoo(Map<String, dynamic> data) {
    return ResLang(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      code: parseOdooStringRequired(data['code']),
      active: parseOdooBool(data['active']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(ResLang record) {
    return {'name': record.name, 'code': record.code, 'active': record.active};
  }

  @override
  ResLang fromDrift(dynamic row) {
    return ResLang(
      id: row.odooId as int,
      name: row.name as String,
      code: row.code as String,
      active: row.active as bool,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(ResLang record) => record.id;

  @override
  String? getUuid(ResLang record) => null;

  @override
  ResLang withIdAndUuid(ResLang record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  ResLang withSyncStatus(ResLang record, bool isSynced) {
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
      throw StateError('Table \'res_lang\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(ResLang record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'code': Variable<String>(record.code),
      'active': Variable<bool>(record.active),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = ['name', 'code', 'active'];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'code': 'Code',
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
  Map<String, String> validateRecord(ResLang record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(ResLang record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(ResLang record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(ResLang record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'code':
        return record.code;
      case 'active':
        return record.active;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  ResLang applyWebSocketChangesToRecord(
    ResLang record,
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
    'code',
    'active',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const ['name', 'code', 'active'];
}

/// Global instance of ResLangManager.
final resLangManager = ResLangManager();
