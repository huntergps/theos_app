// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'withhold_line.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WithholdLine _$WithholdLineFromJson(Map<String, dynamic> json) =>
    _WithholdLine(
      id: (json['id'] as num?)?.toInt() ?? 0,
      lineUuid: json['lineUuid'] as String,
      taxId: (json['taxId'] as num).toInt(),
      taxName: json['taxName'] as String,
      taxPercent: (json['taxPercent'] as num).toDouble(),
      withholdType: $enumDecode(_$WithholdTypeEnumMap, json['withholdType']),
      taxSupportCode: $enumDecodeNullable(
        _$TaxSupportCodeEnumMap,
        json['taxSupportCode'],
      ),
      base: (json['base'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$WithholdLineToJson(_WithholdLine instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lineUuid': instance.lineUuid,
      'taxId': instance.taxId,
      'taxName': instance.taxName,
      'taxPercent': instance.taxPercent,
      'withholdType': _$WithholdTypeEnumMap[instance.withholdType]!,
      'taxSupportCode': _$TaxSupportCodeEnumMap[instance.taxSupportCode],
      'base': instance.base,
      'amount': instance.amount,
      'notes': instance.notes,
    };

const _$WithholdTypeEnumMap = {
  WithholdType.vatSale: 'withhold_vat_sale',
  WithholdType.incomeSale: 'withhold_income_sale',
};

const _$TaxSupportCodeEnumMap = {
  TaxSupportCode.creditoTributario: '01',
  TaxSupportCode.costoGasto: '02',
  TaxSupportCode.activo: '03',
  TaxSupportCode.dividendos: '04',
  TaxSupportCode.otros: '05',
};

_AvailableWithholdTax _$AvailableWithholdTaxFromJson(
  Map<String, dynamic> json,
) => _AvailableWithholdTax(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  spanishName: json['spanishName'] as String?,
  amount: (json['amount'] as num).toDouble(),
  withholdType: $enumDecode(_$WithholdTypeEnumMap, json['withholdType']),
);

Map<String, dynamic> _$AvailableWithholdTaxToJson(
  _AvailableWithholdTax instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'spanishName': instance.spanishName,
  'amount': instance.amount,
  'withholdType': _$WithholdTypeEnumMap[instance.withholdType]!,
};

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for WithholdLine.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: account.withhold.line
class WithholdLineManager extends OdooModelManager<WithholdLine>
    with GenericDriftOperations<WithholdLine> {
  @override
  String get odooModel => 'account.withhold.line';

  @override
  String get tableName => 'sale_order_withhold_line';

  @override
  List<String> get odooFields => [
    'id',
    'tax_id',
    'tax_name',
    'tax_percent',
    'withhold_type',
    'taxsupport_code',
    'base',
    'amount',
    'notes',
  ];

  @override
  WithholdLine fromOdoo(Map<String, dynamic> data) {
    return WithholdLine(
      id: data['id'] as int? ?? 0,
      lineUuid: '',
      taxId: parseOdooInt(data['tax_id']) ?? 0,
      taxName: parseOdooStringRequired(data['tax_name']),
      taxPercent: parseOdooDouble(data['tax_percent']) ?? 0.0,
      withholdType: WithholdType.values.firstWhere(
        (e) => e.code == parseOdooSelection(data['withhold_type']),
        orElse: () => WithholdType.values.first,
      ),
      taxSupportCode: parseOdooSelection(data['taxsupport_code']) != null
          ? TaxSupportCode.values.firstWhere(
              (e) => e.code == parseOdooSelection(data['taxsupport_code']),
              orElse: () => TaxSupportCode.values.first,
            )
          : null,
      base: parseOdooDouble(data['base']) ?? 0.0,
      amount: parseOdooDouble(data['amount']) ?? 0.0,
      notes: parseOdooString(data['notes']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(WithholdLine record) {
    return {
      'tax_id': record.taxId,
      'tax_name': record.taxName,
      'tax_percent': record.taxPercent,
      'withhold_type': record.withholdType.code,
      'taxsupport_code': record.taxSupportCode?.code,
      'base': record.base,
      'amount': record.amount,
      'notes': record.notes,
    };
  }

  @override
  WithholdLine fromDrift(dynamic row) {
    return WithholdLine(
      id: row.odooId as int,
      lineUuid: row.lineUuid as String? ?? '',
      taxId: row.taxId as int,
      taxName: row.taxName as String,
      taxPercent: row.taxPercent as double,
      withholdType: WithholdType.values.firstWhere(
        (e) => e.code == (row.withholdType as String?),
        orElse: () => WithholdType.values.first,
      ),
      taxSupportCode: (row.taxSupportCode as String?) != null
          ? TaxSupportCode.values.firstWhere(
              (e) => e.code == (row.taxSupportCode as String?),
              orElse: () => TaxSupportCode.values.first,
            )
          : null,
      base: row.base as double,
      amount: row.amount as double,
      notes: row.notes as String?,
    );
  }

  @override
  int getId(WithholdLine record) => record.id;

  @override
  String? getUuid(WithholdLine record) => null;

  @override
  WithholdLine withIdAndUuid(WithholdLine record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  WithholdLine withSyncStatus(WithholdLine record, bool isSynced) {
    return record; // No sync status field
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'tax_id': 'taxId',
    'tax_name': 'taxName',
    'tax_percent': 'taxPercent',
    'withhold_type': 'withholdType',
    'taxsupport_code': 'taxSupportCode',
    'base': 'base',
    'amount': 'amount',
    'notes': 'notes',
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
        'Table \'sale_order_withhold_line\' not found in database.',
      );
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(WithholdLine record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'tax_id': Variable<int>(record.taxId),
      'tax_name': Variable<String>(record.taxName),
      'tax_percent': Variable<double>(record.taxPercent),
      'withhold_type': Variable<String>(record.withholdType.code),
      'taxsupport_code': driftVar<String>(record.taxSupportCode?.code),
      'base': Variable<double>(record.base),
      'amount': Variable<double>(record.amount),
      'notes': driftVar<String>(record.notes),
      'line_uuid': Variable<String>(record.lineUuid),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'taxId',
    'taxName',
    'taxPercent',
    'withholdType',
    'taxSupportCode',
    'base',
    'amount',
    'notes',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'lineUuid': 'Line Uuid',
    'taxId': 'Tax Id',
    'taxName': 'Tax Name',
    'taxPercent': 'Tax Percent',
    'withholdType': 'Withhold Type',
    'taxSupportCode': 'Tax Support Code',
    'base': 'Base',
    'amount': 'Amount',
    'notes': 'Notes',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(WithholdLine record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(WithholdLine record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(WithholdLine record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(WithholdLine record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'lineUuid':
        return record.lineUuid;
      case 'taxId':
        return record.taxId;
      case 'taxName':
        return record.taxName;
      case 'taxPercent':
        return record.taxPercent;
      case 'withholdType':
        return record.withholdType;
      case 'taxSupportCode':
        return record.taxSupportCode;
      case 'base':
        return record.base;
      case 'amount':
        return record.amount;
      case 'notes':
        return record.notes;
      default:
        return null;
    }
  }

  @override
  WithholdLine applyWebSocketChangesToRecord(
    WithholdLine record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(lineUuid: record.lineUuid);
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'lineUuid':
        return (obj as dynamic).lineUuid;
      case 'taxId':
        return (obj as dynamic).taxId;
      case 'taxName':
        return (obj as dynamic).taxName;
      case 'taxPercent':
        return (obj as dynamic).taxPercent;
      case 'withholdType':
        return (obj as dynamic).withholdType;
      case 'taxSupportCode':
        return (obj as dynamic).taxSupportCode;
      case 'base':
        return (obj as dynamic).base;
      case 'amount':
        return (obj as dynamic).amount;
      case 'notes':
        return (obj as dynamic).notes;
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
    'lineUuid',
    'taxId',
    'taxName',
    'taxPercent',
    'withholdType',
    'taxSupportCode',
    'base',
    'amount',
    'notes',
  ];

  @override
  List<String> get writableFieldNames => const [
    'taxId',
    'taxName',
    'taxPercent',
    'withholdType',
    'taxSupportCode',
    'base',
    'amount',
    'notes',
  ];
}

/// Global instance of WithholdLineManager.
final withholdLineManager = WithholdLineManager();
