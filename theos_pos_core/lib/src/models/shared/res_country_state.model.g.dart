// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'res_country_state.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for ResCountryState.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: res.country.state
class ResCountryStateManager extends OdooModelManager<ResCountryState>
    with GenericDriftOperations<ResCountryState> {
  @override
  String get odooModel => 'res.country.state';

  @override
  String get tableName => 'res_country_state';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'code',
    'country_id',
    'write_date',
  ];

  @override
  ResCountryState fromOdoo(Map<String, dynamic> data) {
    return ResCountryState(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      code: parseOdooString(data['code']),
      countryId: extractMany2oneId(data['country_id']),
      countryName: extractMany2oneName(data['country_id']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(ResCountryState record) {
    return {
      'name': record.name,
      'code': record.code,
      'country_id': record.countryId,
    };
  }

  @override
  ResCountryState fromDrift(dynamic row) {
    return ResCountryState(
      id: row.odooId as int,
      name: row.name as String,
      code: row.code as String?,
      countryId: row.countryId as int?,
      countryName: row.countryName as String?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(ResCountryState record) => record.id;

  @override
  String? getUuid(ResCountryState record) => null;

  @override
  ResCountryState withIdAndUuid(ResCountryState record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  ResCountryState withSyncStatus(ResCountryState record, bool isSynced) {
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
    'country_id': 'countryId',
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
      throw StateError('Table \'res_country_state\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(ResCountryState record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'code': driftVar<String>(record.code),
      'country_id': driftVar<int>(record.countryId),
      'country_id_name': driftVar<String>(record.countryName),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = ['name', 'code', 'countryId'];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'code': 'Code',
    'countryId': 'Country Id',
    'countryName': 'Country Name',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(ResCountryState record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(ResCountryState record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(ResCountryState record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(ResCountryState record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'code':
        return record.code;
      case 'countryId':
        return record.countryId;
      case 'countryName':
        return record.countryName;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  ResCountryState applyWebSocketChangesToRecord(
    ResCountryState record,
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
      case 'countryId':
        return (obj as dynamic).countryId;
      case 'countryName':
        return (obj as dynamic).countryName;
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
    'countryId',
    'countryName',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const ['name', 'code', 'countryId'];
}

/// Global instance of ResCountryStateManager.
final resCountryStateManager = ResCountryStateManager();
