// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for Tax.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: account.tax
class TaxManager extends OdooModelManager<Tax>
    with GenericDriftOperations<Tax> {
  @override
  String get odooModel => 'account.tax';

  @override
  String get tableName => 'account_tax';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'description',
    'type_tax_use',
    'amount_type',
    'amount',
    'active',
    'price_include',
    'include_base_amount',
    'sequence',
    'company_id',
    'tax_group_id',
    'tax_group_l10n_ec_type',
    'write_date',
  ];

  @override
  Tax fromOdoo(Map<String, dynamic> data) {
    return Tax(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      description: parseOdooString(data['description']),
      typeTaxUse: TaxTypeUse.values.firstWhere(
        (e) => e.name == parseOdooSelection(data['type_tax_use']),
        orElse: () => TaxTypeUse.values.first,
      ),
      amountType: TaxAmountType.values.firstWhere(
        (e) => e.name == parseOdooSelection(data['amount_type']),
        orElse: () => TaxAmountType.values.first,
      ),
      amount: parseOdooDouble(data['amount']) ?? 0.0,
      active: parseOdooBool(data['active']),
      priceInclude: parseOdooBool(data['price_include']),
      includeBaseAmount: parseOdooBool(data['include_base_amount']),
      sequence: parseOdooInt(data['sequence']) ?? 0,
      companyId: extractMany2oneId(data['company_id']),
      companyName: extractMany2oneName(data['company_id']),
      taxGroupId: extractMany2oneId(data['tax_group_id']),
      taxGroupName: extractMany2oneName(data['tax_group_id']),
      taxGroupL10nEcType: parseOdooString(data['tax_group_l10n_ec_type']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(Tax record) {
    return {
      'name': record.name,
      'description': record.description,
      'type_tax_use': record.typeTaxUse.name,
      'amount_type': record.amountType.name,
      'amount': record.amount,
      'active': record.active,
      'price_include': record.priceInclude,
      'include_base_amount': record.includeBaseAmount,
      'sequence': record.sequence,
      'company_id': record.companyId,
      'tax_group_id': record.taxGroupId,
      'tax_group_l10n_ec_type': record.taxGroupL10nEcType,
    };
  }

  @override
  Tax fromDrift(dynamic row) {
    return Tax(
      id: row.odooId as int,
      name: row.name as String,
      description: row.description as String?,
      typeTaxUse: TaxTypeUse.values.firstWhere(
        (e) => e.name == (row.typeTaxUse as String?),
        orElse: () => TaxTypeUse.values.first,
      ),
      amountType: TaxAmountType.values.firstWhere(
        (e) => e.name == (row.amountType as String?),
        orElse: () => TaxAmountType.values.first,
      ),
      amount: row.amount as double,
      active: row.active as bool,
      priceInclude: row.priceInclude as bool,
      includeBaseAmount: row.includeBaseAmount as bool,
      sequence: row.sequence as int,
      companyId: row.companyId as int?,
      companyName: row.companyName as String?,
      taxGroupId: row.taxGroupId as int?,
      taxGroupName: row.taxGroupIdName as String?,
      taxGroupL10nEcType: row.taxGroupL10nEcType as String?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(Tax record) => record.id;

  @override
  String? getUuid(Tax record) => null;

  @override
  Tax withIdAndUuid(Tax record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  Tax withSyncStatus(Tax record, bool isSynced) {
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
    'description': 'description',
    'type_tax_use': 'typeTaxUse',
    'amount_type': 'amountType',
    'amount': 'amount',
    'active': 'active',
    'price_include': 'priceInclude',
    'include_base_amount': 'includeBaseAmount',
    'sequence': 'sequence',
    'company_id': 'companyId',
    'tax_group_id': 'taxGroupId',
    'tax_group_l10n_ec_type': 'taxGroupL10nEcType',
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
      throw StateError('Table \'account_tax\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(Tax record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'description': driftVar<String>(record.description),
      'type_tax_use': Variable<String>(record.typeTaxUse.name),
      'amount_type': Variable<String>(record.amountType.name),
      'amount': Variable<double>(record.amount),
      'active': Variable<bool>(record.active),
      'price_include': Variable<bool>(record.priceInclude),
      'include_base_amount': Variable<bool>(record.includeBaseAmount),
      'sequence': Variable<int>(record.sequence),
      'company_id': driftVar<int>(record.companyId),
      'company_id_name': driftVar<String>(record.companyName),
      'tax_group_id': driftVar<int>(record.taxGroupId),
      'tax_group_id_name': driftVar<String>(record.taxGroupName),
      'tax_group_l10n_ec_type': driftVar<String>(record.taxGroupL10nEcType),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'description',
    'typeTaxUse',
    'amountType',
    'amount',
    'active',
    'priceInclude',
    'includeBaseAmount',
    'sequence',
    'companyId',
    'taxGroupId',
    'taxGroupL10nEcType',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'description': 'Description',
    'typeTaxUse': 'Type Tax Use',
    'amountType': 'Amount Type',
    'amount': 'Amount',
    'active': 'Active',
    'priceInclude': 'Price Include',
    'includeBaseAmount': 'Include Base Amount',
    'sequence': 'Sequence',
    'companyId': 'Company Id',
    'companyName': 'Company Name',
    'taxGroupId': 'Tax Group Id',
    'taxGroupName': 'Tax Group Name',
    'taxGroupL10nEcType': 'Tax Group L10n Ec Type',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(Tax record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(Tax record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(Tax record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(Tax record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'description':
        return record.description;
      case 'typeTaxUse':
        return record.typeTaxUse;
      case 'amountType':
        return record.amountType;
      case 'amount':
        return record.amount;
      case 'active':
        return record.active;
      case 'priceInclude':
        return record.priceInclude;
      case 'includeBaseAmount':
        return record.includeBaseAmount;
      case 'sequence':
        return record.sequence;
      case 'companyId':
        return record.companyId;
      case 'companyName':
        return record.companyName;
      case 'taxGroupId':
        return record.taxGroupId;
      case 'taxGroupName':
        return record.taxGroupName;
      case 'taxGroupL10nEcType':
        return record.taxGroupL10nEcType;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  Tax applyWebSocketChangesToRecord(Tax record, Map<String, dynamic> changes) {
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
      case 'description':
        return (obj as dynamic).description;
      case 'typeTaxUse':
        return (obj as dynamic).typeTaxUse;
      case 'amountType':
        return (obj as dynamic).amountType;
      case 'amount':
        return (obj as dynamic).amount;
      case 'active':
        return (obj as dynamic).active;
      case 'priceInclude':
        return (obj as dynamic).priceInclude;
      case 'includeBaseAmount':
        return (obj as dynamic).includeBaseAmount;
      case 'sequence':
        return (obj as dynamic).sequence;
      case 'companyId':
        return (obj as dynamic).companyId;
      case 'companyName':
        return (obj as dynamic).companyName;
      case 'taxGroupId':
        return (obj as dynamic).taxGroupId;
      case 'taxGroupName':
        return (obj as dynamic).taxGroupName;
      case 'taxGroupL10nEcType':
        return (obj as dynamic).taxGroupL10nEcType;
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
    'description',
    'typeTaxUse',
    'amountType',
    'amount',
    'active',
    'priceInclude',
    'includeBaseAmount',
    'sequence',
    'companyId',
    'companyName',
    'taxGroupId',
    'taxGroupName',
    'taxGroupL10nEcType',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'description',
    'typeTaxUse',
    'amountType',
    'amount',
    'active',
    'priceInclude',
    'includeBaseAmount',
    'sequence',
    'companyId',
    'taxGroupId',
    'taxGroupL10nEcType',
  ];
}

/// Global instance of TaxManager.
final taxManager = TaxManager();
