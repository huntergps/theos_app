// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resource_calendar.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for ResourceCalendar.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: resource.calendar
class ResourceCalendarManager extends OdooModelManager<ResourceCalendar>
    with GenericDriftOperations<ResourceCalendar> {
  @override
  String get odooModel => 'resource.calendar';

  @override
  String get tableName => 'resource_calendar';

  @override
  List<String> get odooFields => ['id', 'name', 'company_id', 'write_date'];

  @override
  ResourceCalendar fromOdoo(Map<String, dynamic> data) {
    return ResourceCalendar(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      companyId: extractMany2oneId(data['company_id']),
      companyName: extractMany2oneName(data['company_id']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(ResourceCalendar record) {
    return {'name': record.name, 'company_id': record.companyId};
  }

  @override
  ResourceCalendar fromDrift(dynamic row) {
    return ResourceCalendar(
      id: row.odooId as int,
      name: row.name as String,
      companyId: row.companyId as int?,
      companyName: row.companyName as String?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(ResourceCalendar record) => record.id;

  @override
  String? getUuid(ResourceCalendar record) => null;

  @override
  ResourceCalendar withIdAndUuid(ResourceCalendar record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  ResourceCalendar withSyncStatus(ResourceCalendar record, bool isSynced) {
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
      throw StateError('Table \'resource_calendar\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(ResourceCalendar record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'company_id': driftVar<int>(record.companyId),
      'company_id_name': driftVar<String>(record.companyName),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = ['name', 'companyId'];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
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
  Map<String, String> validateRecord(ResourceCalendar record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(ResourceCalendar record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(ResourceCalendar record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(ResourceCalendar record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
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
  ResourceCalendar applyWebSocketChangesToRecord(
    ResourceCalendar record,
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
    'companyId',
    'companyName',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const ['name', 'companyId'];
}

/// Global instance of ResourceCalendarManager.
final resourceCalendarManager = ResourceCalendarManager();
