// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for Currency.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: res.currency
class CurrencyManager extends OdooModelManager<Currency>
    with GenericDriftOperations<Currency> {
  @override
  String get odooModel => 'res.currency';

  @override
  String get tableName => 'res_currency';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'symbol',
    'decimal_places',
    'rounding',
    'active',
    'write_date',
  ];

  @override
  Currency fromOdoo(Map<String, dynamic> data) {
    return Currency(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      symbol: parseOdooStringRequired(data['symbol']),
      decimalPlaces: parseOdooInt(data['decimal_places']) ?? 0,
      rounding: parseOdooDouble(data['rounding']) ?? 0.0,
      active: parseOdooBool(data['active']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(Currency record) {
    return {
      'name': record.name,
      'symbol': record.symbol,
      'decimal_places': record.decimalPlaces,
      'rounding': record.rounding,
      'active': record.active,
    };
  }

  @override
  Currency fromDrift(dynamic row) {
    return Currency(
      id: row.odooId as int,
      uuid: row.uuid as String?,
      name: row.name as String,
      symbol: row.symbol as String,
      decimalPlaces: row.decimalPlaces as int,
      rounding: row.rounding as double,
      active: row.active as bool,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(Currency record) => record.id;

  @override
  String? getUuid(Currency record) => record.uuid;

  @override
  Currency withIdAndUuid(Currency record, int id, String uuid) {
    return record.copyWith(id: id, uuid: uuid);
  }

  @override
  Currency withSyncStatus(Currency record, bool isSynced) {
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
    'symbol': 'symbol',
    'decimal_places': 'decimalPlaces',
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
      throw StateError('Table \'res_currency\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(Currency record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'symbol': Variable<String>(record.symbol),
      'decimal_places': Variable<int>(record.decimalPlaces),
      'rounding': Variable<double>(record.rounding),
      'active': Variable<bool>(record.active),
      'write_date': driftVar<DateTime>(record.writeDate),
      'uuid': driftVar<String>(record.uuid),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'symbol',
    'decimalPlaces',
    'rounding',
    'active',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'uuid': 'Uuid',
    'name': 'Name',
    'symbol': 'Symbol',
    'decimalPlaces': 'Decimal Places',
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
  Map<String, String> validateRecord(Currency record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(Currency record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(Currency record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(Currency record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'uuid':
        return record.uuid;
      case 'name':
        return record.name;
      case 'symbol':
        return record.symbol;
      case 'decimalPlaces':
        return record.decimalPlaces;
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
  Currency applyWebSocketChangesToRecord(
    Currency record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(uuid: record.uuid);
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'uuid':
        return (obj as dynamic).uuid;
      case 'name':
        return (obj as dynamic).name;
      case 'symbol':
        return (obj as dynamic).symbol;
      case 'decimalPlaces':
        return (obj as dynamic).decimalPlaces;
      case 'rounding':
        return (obj as dynamic).rounding;
      case 'active':
        return (obj as dynamic).active;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'isSynced':
        return (obj as dynamic).isSynced;
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
    'uuid',
    'name',
    'symbol',
    'decimalPlaces',
    'rounding',
    'active',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'symbol',
    'decimalPlaces',
    'rounding',
    'active',
  ];
}

/// Global instance of CurrencyManager.
final currencyManager = CurrencyManager();

/// Generated manager for DecimalPrecision.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: decimal.precision
class DecimalPrecisionManager extends OdooModelManager<DecimalPrecision>
    with GenericDriftOperations<DecimalPrecision> {
  @override
  String get odooModel => 'decimal.precision';

  @override
  String get tableName => 'decimal_precision';

  @override
  List<String> get odooFields => ['id', 'name', 'digits', 'write_date'];

  @override
  DecimalPrecision fromOdoo(Map<String, dynamic> data) {
    return DecimalPrecision(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      digits: parseOdooInt(data['digits']) ?? 0,
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(DecimalPrecision record) {
    return {'name': record.name, 'digits': record.digits};
  }

  @override
  DecimalPrecision fromDrift(dynamic row) {
    return DecimalPrecision(
      id: row.odooId as int,
      uuid: row.uuid as String?,
      name: row.name as String,
      digits: row.digits as int,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(DecimalPrecision record) => record.id;

  @override
  String? getUuid(DecimalPrecision record) => record.uuid;

  @override
  DecimalPrecision withIdAndUuid(DecimalPrecision record, int id, String uuid) {
    return record.copyWith(id: id, uuid: uuid);
  }

  @override
  DecimalPrecision withSyncStatus(DecimalPrecision record, bool isSynced) {
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
    'digits': 'digits',
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
      throw StateError('Table \'decimal_precision\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(DecimalPrecision record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'digits': Variable<int>(record.digits),
      'write_date': driftVar<DateTime>(record.writeDate),
      'uuid': driftVar<String>(record.uuid),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = ['name', 'digits'];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'uuid': 'Uuid',
    'name': 'Name',
    'digits': 'Digits',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(DecimalPrecision record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(DecimalPrecision record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(DecimalPrecision record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(DecimalPrecision record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'uuid':
        return record.uuid;
      case 'name':
        return record.name;
      case 'digits':
        return record.digits;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  DecimalPrecision applyWebSocketChangesToRecord(
    DecimalPrecision record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(uuid: record.uuid);
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'uuid':
        return (obj as dynamic).uuid;
      case 'name':
        return (obj as dynamic).name;
      case 'digits':
        return (obj as dynamic).digits;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'isSynced':
        return (obj as dynamic).isSynced;
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
    'uuid',
    'name',
    'digits',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const ['name', 'digits'];
}

/// Global instance of DecimalPrecisionManager.
final decimalPrecisionManager = DecimalPrecisionManager();
