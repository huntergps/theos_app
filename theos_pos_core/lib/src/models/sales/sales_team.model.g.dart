// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_team.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for SalesTeam.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: crm.team
class SalesTeamManager extends OdooModelManager<SalesTeam>
    with GenericDriftOperations<SalesTeam> {
  @override
  String get odooModel => 'crm.team';

  @override
  String get tableName => 'crm_team';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'active',
    'company_id',
    'user_id',
    'sequence',
    'write_date',
  ];

  @override
  SalesTeam fromOdoo(Map<String, dynamic> data) {
    return SalesTeam(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      active: parseOdooBool(data['active']),
      companyId: extractMany2oneId(data['company_id']),
      companyName: extractMany2oneName(data['company_id']),
      userId: extractMany2oneId(data['user_id']),
      userName: extractMany2oneName(data['user_id']),
      sequence: parseOdooInt(data['sequence']) ?? 0,
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(SalesTeam record) {
    return {
      'name': record.name,
      'active': record.active,
      'company_id': record.companyId,
      'user_id': record.userId,
      'sequence': record.sequence,
    };
  }

  @override
  SalesTeam fromDrift(dynamic row) {
    return SalesTeam(
      id: row.odooId as int,
      name: row.name as String,
      active: row.active as bool,
      companyId: row.companyId as int?,
      companyName: row.companyName as String?,
      userId: row.userId as int?,
      userName: row.userName as String?,
      sequence: row.sequence as int,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(SalesTeam record) => record.id;

  @override
  String? getUuid(SalesTeam record) => null;

  @override
  SalesTeam withIdAndUuid(SalesTeam record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  SalesTeam withSyncStatus(SalesTeam record, bool isSynced) {
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
    'user_id': 'userId',
    'sequence': 'sequence',
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
      throw StateError('Table \'crm_team\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(SalesTeam record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'active': Variable<bool>(record.active),
      'company_id': driftVar<int>(record.companyId),
      'company_id_name': driftVar<String>(record.companyName),
      'user_id': driftVar<int>(record.userId),
      'user_id_name': driftVar<String>(record.userName),
      'sequence': Variable<int>(record.sequence),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'active',
    'companyId',
    'userId',
    'sequence',
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
    'userId': 'User Id',
    'userName': 'User Name',
    'sequence': 'Sequence',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(SalesTeam record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(SalesTeam record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(SalesTeam record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(SalesTeam record, String fieldName) {
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
      case 'userId':
        return record.userId;
      case 'userName':
        return record.userName;
      case 'sequence':
        return record.sequence;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  SalesTeam applyWebSocketChangesToRecord(
    SalesTeam record,
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
      case 'userId':
        return (obj as dynamic).userId;
      case 'userName':
        return (obj as dynamic).userName;
      case 'sequence':
        return (obj as dynamic).sequence;
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
    'userId',
    'userName',
    'sequence',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'active',
    'companyId',
    'userId',
    'sequence',
  ];
}

/// Global instance of SalesTeamManager.
final salesTeamManager = SalesTeamManager();
