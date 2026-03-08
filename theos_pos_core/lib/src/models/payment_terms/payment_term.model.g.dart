// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_term.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for PaymentTerm.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: account.payment.term
class PaymentTermManager extends OdooModelManager<PaymentTerm>
    with GenericDriftOperations<PaymentTerm> {
  @override
  String get odooModel => 'account.payment.term';

  @override
  String get tableName => 'account_payment_term';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'active',
    'note',
    'company_id',
    'sequence',
    'is_cash',
    'is_credit',
    'due_days',
    'write_date',
  ];

  @override
  PaymentTerm fromOdoo(Map<String, dynamic> data) {
    return PaymentTerm(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      active: parseOdooBool(data['active']),
      note: parseOdooString(data['note']),
      companyId: extractMany2oneId(data['company_id']),
      sequence: parseOdooInt(data['sequence']) ?? 0,
      isCash: parseOdooBool(data['is_cash']),
      isCredit: parseOdooBool(data['is_credit']),
      dueDays: parseOdooInt(data['due_days']) ?? 0,
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(PaymentTerm record) {
    return {
      'name': record.name,
      'active': record.active,
      'note': record.note,
      'company_id': record.companyId,
      'sequence': record.sequence,
      'is_cash': record.isCash,
      'is_credit': record.isCredit,
      'due_days': record.dueDays,
    };
  }

  @override
  PaymentTerm fromDrift(dynamic row) {
    return PaymentTerm(
      id: row.odooId as int,
      name: row.name as String,
      active: row.active as bool,
      note: row.note as String?,
      companyId: row.companyId as int?,
      sequence: row.sequence as int,
      isCash: row.isCash as bool,
      isCredit: row.isCredit as bool,
      dueDays: row.dueDays as int,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(PaymentTerm record) => record.id;

  @override
  String? getUuid(PaymentTerm record) => null;

  @override
  PaymentTerm withIdAndUuid(PaymentTerm record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  PaymentTerm withSyncStatus(PaymentTerm record, bool isSynced) {
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
    'note': 'note',
    'company_id': 'companyId',
    'sequence': 'sequence',
    'is_cash': 'isCash',
    'is_credit': 'isCredit',
    'due_days': 'dueDays',
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
      throw StateError('Table \'account_payment_term\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(PaymentTerm record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'active': Variable<bool>(record.active),
      'note': driftVar<String>(record.note),
      'company_id': driftVar<int>(record.companyId),
      'sequence': Variable<int>(record.sequence),
      'is_cash': Variable<bool>(record.isCash),
      'is_credit': Variable<bool>(record.isCredit),
      'due_days': Variable<int>(record.dueDays),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'active',
    'note',
    'companyId',
    'sequence',
    'isCash',
    'isCredit',
    'dueDays',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'active': 'Active',
    'note': 'Note',
    'companyId': 'Company Id',
    'sequence': 'Sequence',
    'isCash': 'Is Cash',
    'isCredit': 'Is Credit',
    'dueDays': 'Due Days',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(PaymentTerm record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(PaymentTerm record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(PaymentTerm record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(PaymentTerm record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'active':
        return record.active;
      case 'note':
        return record.note;
      case 'companyId':
        return record.companyId;
      case 'sequence':
        return record.sequence;
      case 'isCash':
        return record.isCash;
      case 'isCredit':
        return record.isCredit;
      case 'dueDays':
        return record.dueDays;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  PaymentTerm applyWebSocketChangesToRecord(
    PaymentTerm record,
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
      case 'note':
        return (obj as dynamic).note;
      case 'companyId':
        return (obj as dynamic).companyId;
      case 'sequence':
        return (obj as dynamic).sequence;
      case 'isCash':
        return (obj as dynamic).isCash;
      case 'isCredit':
        return (obj as dynamic).isCredit;
      case 'dueDays':
        return (obj as dynamic).dueDays;
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
    'note',
    'companyId',
    'sequence',
    'isCash',
    'isCredit',
    'dueDays',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'active',
    'note',
    'companyId',
    'sequence',
    'isCash',
    'isCredit',
    'dueDays',
  ];
}

/// Global instance of PaymentTermManager.
final paymentTermManager = PaymentTermManager();
