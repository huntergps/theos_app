// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pricelist.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for Pricelist.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: product.pricelist
class PricelistManager extends OdooModelManager<Pricelist>
    with GenericDriftOperations<Pricelist> {
  @override
  String get odooModel => 'product.pricelist';

  @override
  String get tableName => 'product_pricelist';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'active',
    'currency_id',
    'company_id',
    'sequence',
    'discount_policy',
    'write_date',
  ];

  @override
  Pricelist fromOdoo(Map<String, dynamic> data) {
    return Pricelist(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      active: parseOdooBool(data['active']),
      currencyId: extractMany2oneId(data['currency_id']),
      currencyName: extractMany2oneName(data['currency_id']),
      companyId: extractMany2oneId(data['company_id']),
      companyName: extractMany2oneName(data['company_id']),
      sequence: parseOdooInt(data['sequence']) ?? 0,
      discountPolicy: parseOdooSelection(data['discount_policy']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(Pricelist record) {
    return {
      'name': record.name,
      'active': record.active,
      'currency_id': record.currencyId,
      'company_id': record.companyId,
      'sequence': record.sequence,
      'discount_policy': record.discountPolicy,
    };
  }

  @override
  Pricelist fromDrift(dynamic row) {
    return Pricelist(
      id: row.odooId as int,
      name: row.name as String,
      active: row.active as bool,
      currencyId: row.currencyId as int?,
      currencyName: row.currencyName as String?,
      companyId: row.companyId as int?,
      companyName: row.companyName as String?,
      sequence: row.sequence as int,
      discountPolicy: row.discountPolicy as String?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(Pricelist record) => record.id;

  @override
  String? getUuid(Pricelist record) => null;

  @override
  Pricelist withIdAndUuid(Pricelist record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  Pricelist withSyncStatus(Pricelist record, bool isSynced) {
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
    'currency_id': 'currencyId',
    'company_id': 'companyId',
    'sequence': 'sequence',
    'discount_policy': 'discountPolicy',
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
      throw StateError('Table \'product_pricelist\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(Pricelist record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'active': Variable<bool>(record.active),
      'currency_id': driftVar<int>(record.currencyId),
      'currency_id_name': driftVar<String>(record.currencyName),
      'company_id': driftVar<int>(record.companyId),
      'company_id_name': driftVar<String>(record.companyName),
      'sequence': Variable<int>(record.sequence),
      'discount_policy': driftVar<String>(record.discountPolicy),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'active',
    'currencyId',
    'companyId',
    'sequence',
    'discountPolicy',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'active': 'Active',
    'currencyId': 'Currency Id',
    'currencyName': 'Currency Name',
    'companyId': 'Company Id',
    'companyName': 'Company Name',
    'sequence': 'Sequence',
    'discountPolicy': 'Discount Policy',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(Pricelist record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(Pricelist record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(Pricelist record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(Pricelist record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'active':
        return record.active;
      case 'currencyId':
        return record.currencyId;
      case 'currencyName':
        return record.currencyName;
      case 'companyId':
        return record.companyId;
      case 'companyName':
        return record.companyName;
      case 'sequence':
        return record.sequence;
      case 'discountPolicy':
        return record.discountPolicy;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  Pricelist applyWebSocketChangesToRecord(
    Pricelist record,
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
      case 'currencyId':
        return (obj as dynamic).currencyId;
      case 'currencyName':
        return (obj as dynamic).currencyName;
      case 'companyId':
        return (obj as dynamic).companyId;
      case 'companyName':
        return (obj as dynamic).companyName;
      case 'sequence':
        return (obj as dynamic).sequence;
      case 'discountPolicy':
        return (obj as dynamic).discountPolicy;
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
    'currencyId',
    'currencyName',
    'companyId',
    'companyName',
    'sequence',
    'discountPolicy',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'active',
    'currencyId',
    'companyId',
    'sequence',
    'discountPolicy',
  ];
}

/// Global instance of PricelistManager.
final pricelistManager = PricelistManager();
