// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bank.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for Bank.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: res.bank
class BankManager extends OdooModelManager<Bank>
    with GenericDriftOperations<Bank> {
  @override
  String get odooModel => 'res.bank';

  @override
  String get tableName => 'res_bank';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'bic',
    'country',
    'active',
    'write_date',
  ];

  @override
  Bank fromOdoo(Map<String, dynamic> data) {
    return Bank(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      bic: parseOdooString(data['bic']),
      countryId: extractMany2oneId(data['country']),
      active: parseOdooBool(data['active']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(Bank record) {
    return {
      'name': record.name,
      'bic': record.bic,
      'country': record.countryId,
      'active': record.active,
    };
  }

  @override
  Bank fromDrift(dynamic row) {
    return Bank(
      id: row.odooId as int,
      name: row.name as String,
      bic: row.bic as String?,
      countryId: row.countryId as int?,
      active: row.active as bool,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(Bank record) => record.id;

  @override
  String? getUuid(Bank record) => null;

  @override
  Bank withIdAndUuid(Bank record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  Bank withSyncStatus(Bank record, bool isSynced) {
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
    'bic': 'bic',
    'country': 'countryId',
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
      throw StateError('Table \'res_bank\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(Bank record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'bic': driftVar<String>(record.bic),
      'country': driftVar<int>(record.countryId),
      'active': Variable<bool>(record.active),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'bic',
    'countryId',
    'active',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'bic': 'Bic',
    'countryId': 'Country Id',
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
  Map<String, String> validateRecord(Bank record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(Bank record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(Bank record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(Bank record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'bic':
        return record.bic;
      case 'countryId':
        return record.countryId;
      case 'active':
        return record.active;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  Bank applyWebSocketChangesToRecord(
    Bank record,
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
      case 'bic':
        return (obj as dynamic).bic;
      case 'countryId':
        return (obj as dynamic).countryId;
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
    'bic',
    'countryId',
    'active',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'bic',
    'countryId',
    'active',
  ];
}

/// Global instance of BankManager.
final bankManager = BankManager();

/// Generated manager for PartnerBank.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: res.partner.bank
class PartnerBankManager extends OdooModelManager<PartnerBank>
    with GenericDriftOperations<PartnerBank> {
  @override
  String get odooModel => 'res.partner.bank';

  @override
  String get tableName => 'res_partner_bank';

  @override
  List<String> get odooFields => [
    'id',
    'partner_id',
    'bank_id',
    'acc_number',
    'write_date',
  ];

  @override
  PartnerBank fromOdoo(Map<String, dynamic> data) {
    return PartnerBank(
      id: data['id'] as int? ?? 0,
      partnerId: extractMany2oneId(data['partner_id']) ?? 0,
      bankId: extractMany2oneId(data['bank_id']),
      accNumber: parseOdooStringRequired(data['acc_number']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(PartnerBank record) {
    return {
      'partner_id': record.partnerId,
      'bank_id': record.bankId,
      'acc_number': record.accNumber,
    };
  }

  @override
  PartnerBank fromDrift(dynamic row) {
    return PartnerBank(
      id: row.odooId as int,
      partnerId: row.partnerId as int,
      bankId: row.bankId as int?,
      accNumber: row.accNumber as String,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(PartnerBank record) => record.id;

  @override
  String? getUuid(PartnerBank record) => null;

  @override
  PartnerBank withIdAndUuid(PartnerBank record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  PartnerBank withSyncStatus(PartnerBank record, bool isSynced) {
    return record; // No sync status field
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'partner_id': 'partnerId',
    'bank_id': 'bankId',
    'acc_number': 'accNumber',
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
      throw StateError('Table \'res_partner_bank\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(PartnerBank record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'partner_id': Variable<int>(record.partnerId),
      'bank_id': driftVar<int>(record.bankId),
      'acc_number': Variable<String>(record.accNumber),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'partnerId',
    'bankId',
    'accNumber',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'partnerId': 'Partner Id',
    'bankId': 'Bank Id',
    'accNumber': 'Acc Number',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(PartnerBank record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(PartnerBank record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(PartnerBank record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(PartnerBank record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'partnerId':
        return record.partnerId;
      case 'bankId':
        return record.bankId;
      case 'accNumber':
        return record.accNumber;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  PartnerBank applyWebSocketChangesToRecord(
    PartnerBank record,
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
      case 'partnerId':
        return (obj as dynamic).partnerId;
      case 'bankId':
        return (obj as dynamic).bankId;
      case 'accNumber':
        return (obj as dynamic).accNumber;
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
    'partnerId',
    'bankId',
    'accNumber',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'partnerId',
    'bankId',
    'accNumber',
  ];
}

/// Global instance of PartnerBankManager.
final partnerBankManager = PartnerBankManager();
