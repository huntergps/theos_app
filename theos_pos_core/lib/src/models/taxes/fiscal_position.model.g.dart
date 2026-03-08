// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fiscal_position.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for FiscalPosition.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: account.fiscal.position
class FiscalPositionManager extends OdooModelManager<FiscalPosition>
    with GenericDriftOperations<FiscalPosition> {
  @override
  String get odooModel => 'account.fiscal.position';

  @override
  String get tableName => 'account_fiscal_position';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'active',
    'company_id',
    'sequence',
    'note',
    'auto_apply',
    'country_id',
    'write_date',
  ];

  @override
  FiscalPosition fromOdoo(Map<String, dynamic> data) {
    return FiscalPosition(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      active: parseOdooBool(data['active']),
      companyId: extractMany2oneId(data['company_id']),
      companyName: extractMany2oneName(data['company_id']),
      sequence: parseOdooInt(data['sequence']) ?? 0,
      note: parseOdooString(data['note']),
      autoApply: parseOdooBool(data['auto_apply']),
      countryId: extractMany2oneId(data['country_id']),
      countryName: extractMany2oneName(data['country_id']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(FiscalPosition record) {
    return {
      'name': record.name,
      'active': record.active,
      'company_id': record.companyId,
      'sequence': record.sequence,
      'note': record.note,
      'auto_apply': record.autoApply,
      'country_id': record.countryId,
    };
  }

  @override
  FiscalPosition fromDrift(dynamic row) {
    return FiscalPosition(
      id: row.odooId as int,
      name: row.name as String,
      active: row.active as bool,
      companyId: row.companyId as int?,
      companyName: row.companyName as String?,
      sequence: row.sequence as int,
      note: row.note as String?,
      autoApply: row.autoApply as bool,
      countryId: row.countryId as int?,
      countryName: row.countryName as String?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(FiscalPosition record) => record.id;

  @override
  String? getUuid(FiscalPosition record) => null;

  @override
  FiscalPosition withIdAndUuid(FiscalPosition record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  FiscalPosition withSyncStatus(FiscalPosition record, bool isSynced) {
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
    'active': 'active',
    'company_id': 'companyId',
    'sequence': 'sequence',
    'note': 'note',
    'auto_apply': 'autoApply',
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
      throw StateError(
        'Table \'account_fiscal_position\' not found in database.',
      );
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(FiscalPosition record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'active': Variable<bool>(record.active),
      'company_id': driftVar<int>(record.companyId),
      'company_id_name': driftVar<String>(record.companyName),
      'sequence': Variable<int>(record.sequence),
      'note': driftVar<String>(record.note),
      'auto_apply': Variable<bool>(record.autoApply),
      'country_id': driftVar<int>(record.countryId),
      'country_id_name': driftVar<String>(record.countryName),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'active',
    'companyId',
    'sequence',
    'note',
    'autoApply',
    'countryId',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'active': 'Active',
    'companyId': 'Company Id',
    'companyName': 'Company Name',
    'sequence': 'Sequence',
    'note': 'Note',
    'autoApply': 'Auto Apply',
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
  Map<String, String> validateRecord(FiscalPosition record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(FiscalPosition record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(FiscalPosition record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(FiscalPosition record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'active':
        return record.active;
      case 'companyId':
        return record.companyId;
      case 'companyName':
        return record.companyName;
      case 'sequence':
        return record.sequence;
      case 'note':
        return record.note;
      case 'autoApply':
        return record.autoApply;
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
  FiscalPosition applyWebSocketChangesToRecord(
    FiscalPosition record,
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
      case 'active':
        return (obj as dynamic).active;
      case 'companyId':
        return (obj as dynamic).companyId;
      case 'companyName':
        return (obj as dynamic).companyName;
      case 'sequence':
        return (obj as dynamic).sequence;
      case 'note':
        return (obj as dynamic).note;
      case 'autoApply':
        return (obj as dynamic).autoApply;
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
    'active',
    'companyId',
    'companyName',
    'sequence',
    'note',
    'autoApply',
    'countryId',
    'countryName',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'active',
    'companyId',
    'sequence',
    'note',
    'autoApply',
    'countryId',
  ];
}

/// Global instance of FiscalPositionManager.
final fiscalPositionManager = FiscalPositionManager();
