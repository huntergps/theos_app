// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advance.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Advance _$AdvanceFromJson(Map<String, dynamic> json) => _Advance(
  id: (json['id'] as num?)?.toInt() ?? 0,
  advanceUuid: json['advanceUuid'] as String?,
  name: json['name'] as String?,
  date: DateTime.parse(json['date'] as String),
  dateEstimated: DateTime.parse(json['dateEstimated'] as String),
  dateDue: json['dateDue'] == null
      ? null
      : DateTime.parse(json['dateDue'] as String),
  state:
      $enumDecodeNullable(_$AdvanceStateEnumMap, json['state']) ??
      AdvanceState.draft,
  advanceType: $enumDecode(_$AdvanceTypeEnumMap, json['advanceType']),
  partnerId: (json['partnerId'] as num).toInt(),
  partnerName: json['partnerName'] as String?,
  reference: json['reference'] as String,
  amount: (json['amount'] as num?)?.toDouble() ?? 0,
  amountUsed: (json['amountUsed'] as num?)?.toDouble() ?? 0,
  amountAvailable: (json['amountAvailable'] as num?)?.toDouble() ?? 0,
  amountReturned: (json['amountReturned'] as num?)?.toDouble() ?? 0,
  usagePercentage: (json['usagePercentage'] as num?)?.toDouble() ?? 0,
  daysToExpire: (json['daysToExpire'] as num?)?.toInt(),
  isExpired: json['isExpired'] as bool? ?? false,
  collectionSessionId: (json['collectionSessionId'] as num?)?.toInt(),
  saleOrderId: (json['saleOrderId'] as num?)?.toInt(),
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => AdvanceLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$AdvanceToJson(_Advance instance) => <String, dynamic>{
  'id': instance.id,
  'advanceUuid': instance.advanceUuid,
  'name': instance.name,
  'date': instance.date.toIso8601String(),
  'dateEstimated': instance.dateEstimated.toIso8601String(),
  'dateDue': instance.dateDue?.toIso8601String(),
  'state': _$AdvanceStateEnumMap[instance.state]!,
  'advanceType': _$AdvanceTypeEnumMap[instance.advanceType]!,
  'partnerId': instance.partnerId,
  'partnerName': instance.partnerName,
  'reference': instance.reference,
  'amount': instance.amount,
  'amountUsed': instance.amountUsed,
  'amountAvailable': instance.amountAvailable,
  'amountReturned': instance.amountReturned,
  'usagePercentage': instance.usagePercentage,
  'daysToExpire': instance.daysToExpire,
  'isExpired': instance.isExpired,
  'collectionSessionId': instance.collectionSessionId,
  'saleOrderId': instance.saleOrderId,
  'lines': instance.lines,
};

const _$AdvanceStateEnumMap = {
  AdvanceState.draft: 'draft',
  AdvanceState.posted: 'posted',
  AdvanceState.inUse: 'in_use',
  AdvanceState.used: 'used',
  AdvanceState.expired: 'expired',
  AdvanceState.canceled: 'canceled',
  AdvanceState.rejected: 'rejected',
};

const _$AdvanceTypeEnumMap = {
  AdvanceType.inbound: 'inbound',
  AdvanceType.outbound: 'outbound',
};

_AdvanceLine _$AdvanceLineFromJson(Map<String, dynamic> json) => _AdvanceLine(
  id: (json['id'] as num?)?.toInt() ?? 0,
  lineUuid: json['lineUuid'] as String?,
  journalId: (json['journalId'] as num).toInt(),
  journalName: json['journalName'] as String?,
  journalType: json['journalType'] as String?,
  advanceMethodLineId: (json['advanceMethodLineId'] as num?)?.toInt(),
  advanceMethodName: json['advanceMethodName'] as String?,
  amount: (json['amount'] as num).toDouble(),
  documentNumber: json['documentNumber'] as String?,
  documentDate: json['documentDate'] == null
      ? null
      : DateTime.parse(json['documentDate'] as String),
  partnerBankId: (json['partnerBankId'] as num?)?.toInt(),
  partnerBankName: json['partnerBankName'] as String?,
  checkDueDate: json['checkDueDate'] == null
      ? null
      : DateTime.parse(json['checkDueDate'] as String),
  cardBrandId: (json['cardBrandId'] as num?)?.toInt(),
  cardBrandName: json['cardBrandName'] as String?,
  cardDeadlineId: (json['cardDeadlineId'] as num?)?.toInt(),
  cardDeadlineName: json['cardDeadlineName'] as String?,
);

Map<String, dynamic> _$AdvanceLineToJson(_AdvanceLine instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lineUuid': instance.lineUuid,
      'journalId': instance.journalId,
      'journalName': instance.journalName,
      'journalType': instance.journalType,
      'advanceMethodLineId': instance.advanceMethodLineId,
      'advanceMethodName': instance.advanceMethodName,
      'amount': instance.amount,
      'documentNumber': instance.documentNumber,
      'documentDate': instance.documentDate?.toIso8601String(),
      'partnerBankId': instance.partnerBankId,
      'partnerBankName': instance.partnerBankName,
      'checkDueDate': instance.checkDueDate?.toIso8601String(),
      'cardBrandId': instance.cardBrandId,
      'cardBrandName': instance.cardBrandName,
      'cardDeadlineId': instance.cardDeadlineId,
      'cardDeadlineName': instance.cardDeadlineName,
    };

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for Advance.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: account.advance
class AdvanceManager extends OdooModelManager<Advance>
    with GenericDriftOperations<Advance> {
  @override
  String get odooModel => 'account.advance';

  @override
  String get tableName => 'account_advance';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'date',
    'date_estimated',
    'date_due',
    'state',
    'advance_type',
    'partner_id',
    'reference',
    'amount',
    'amount_used',
    'amount_available',
    'amount_returned',
    'usage_percentage',
    'days_to_expire',
    'is_expired',
    'collection_session_id',
    'sale_order_id',
  ];

  @override
  Advance fromOdoo(Map<String, dynamic> data) {
    return Advance(
      id: data['id'] as int? ?? 0,
      name: parseOdooString(data['name']),
      date: parseOdooDate(data['date']) ?? DateTime(1970),
      dateEstimated: parseOdooDate(data['date_estimated']) ?? DateTime(1970),
      dateDue: parseOdooDate(data['date_due']),
      state: AdvanceState.values.firstWhere(
        (e) => e.code == parseOdooSelection(data['state']),
        orElse: () => AdvanceState.values.first,
      ),
      advanceType: AdvanceType.values.firstWhere(
        (e) => e.code == parseOdooSelection(data['advance_type']),
        orElse: () => AdvanceType.values.first,
      ),
      partnerId: extractMany2oneId(data['partner_id']) ?? 0,
      partnerName: extractMany2oneName(data['partner_id']),
      reference: parseOdooStringRequired(data['reference']),
      amount: parseOdooDouble(data['amount']) ?? 0.0,
      amountUsed: parseOdooDouble(data['amount_used']) ?? 0.0,
      amountAvailable: parseOdooDouble(data['amount_available']) ?? 0.0,
      amountReturned: parseOdooDouble(data['amount_returned']) ?? 0.0,
      usagePercentage: parseOdooDouble(data['usage_percentage']) ?? 0.0,
      daysToExpire: parseOdooInt(data['days_to_expire']),
      isExpired: parseOdooBool(data['is_expired']),
      collectionSessionId: extractMany2oneId(data['collection_session_id']),
      saleOrderId: extractMany2oneId(data['sale_order_id']),
      lines: const [],
    );
  }

  @override
  Map<String, dynamic> toOdoo(Advance record) {
    return {
      'name': record.name,
      'date': formatOdooDate(record.date),
      'date_estimated': formatOdooDate(record.dateEstimated),
      'date_due': formatOdooDate(record.dateDue),
      'state': record.state.code,
      'advance_type': record.advanceType.code,
      'partner_id': record.partnerId,
      'reference': record.reference,
      'amount': record.amount,
      'amount_used': record.amountUsed,
      'amount_available': record.amountAvailable,
      'amount_returned': record.amountReturned,
      'usage_percentage': record.usagePercentage,
      'days_to_expire': record.daysToExpire,
      'is_expired': record.isExpired,
      'collection_session_id': record.collectionSessionId,
      'sale_order_id': record.saleOrderId,
    };
  }

  @override
  Advance fromDrift(dynamic row) {
    return Advance(
      id: row.odooId as int,
      advanceUuid: row.advanceUuid as String?,
      name: row.name as String?,
      date: row.date as DateTime,
      dateEstimated: row.dateEstimated as DateTime,
      dateDue: row.dateDue as DateTime?,
      state: AdvanceState.values.firstWhere(
        (e) => e.code == (row.state as String?),
        orElse: () => AdvanceState.values.first,
      ),
      advanceType: AdvanceType.values.firstWhere(
        (e) => e.code == (row.advanceType as String?),
        orElse: () => AdvanceType.values.first,
      ),
      partnerId: row.partnerId as int,
      partnerName: row.partnerName as String?,
      reference: row.reference as String,
      amount: row.amount as double,
      amountUsed: row.amountUsed as double,
      amountAvailable: row.amountAvailable as double,
      amountReturned: row.amountReturned as double,
      usagePercentage: row.usagePercentage as double,
      daysToExpire: row.daysToExpire as int?,
      isExpired: row.isExpired as bool,
      collectionSessionId: row.collectionSessionId as int?,
      saleOrderId: row.saleOrderId as int?,
    );
  }

  @override
  int getId(Advance record) => record.id;

  @override
  String? getUuid(Advance record) => null;

  @override
  Advance withIdAndUuid(Advance record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  Advance withSyncStatus(Advance record, bool isSynced) {
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
    'date': 'date',
    'date_estimated': 'dateEstimated',
    'date_due': 'dateDue',
    'state': 'state',
    'advance_type': 'advanceType',
    'partner_id': 'partnerId',
    'reference': 'reference',
    'amount': 'amount',
    'amount_used': 'amountUsed',
    'amount_available': 'amountAvailable',
    'amount_returned': 'amountReturned',
    'usage_percentage': 'usagePercentage',
    'days_to_expire': 'daysToExpire',
    'is_expired': 'isExpired',
    'collection_session_id': 'collectionSessionId',
    'sale_order_id': 'saleOrderId',
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
      throw StateError('Table \'account_advance\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(Advance record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': driftVar<String>(record.name),
      'date': Variable<DateTime>(record.date),
      'date_estimated': Variable<DateTime>(record.dateEstimated),
      'date_due': driftVar<DateTime>(record.dateDue),
      'state': Variable<String>(record.state.code),
      'advance_type': Variable<String>(record.advanceType.code),
      'partner_id': Variable<int>(record.partnerId),
      'partner_id_name': driftVar<String>(record.partnerName),
      'reference': Variable<String>(record.reference),
      'amount': Variable<double>(record.amount),
      'amount_used': Variable<double>(record.amountUsed),
      'amount_available': Variable<double>(record.amountAvailable),
      'amount_returned': Variable<double>(record.amountReturned),
      'usage_percentage': Variable<double>(record.usagePercentage),
      'days_to_expire': driftVar<int>(record.daysToExpire),
      'is_expired': Variable<bool>(record.isExpired),
      'collection_session_id': driftVar<int>(record.collectionSessionId),
      'sale_order_id': driftVar<int>(record.saleOrderId),
      'advance_uuid': driftVar<String>(record.advanceUuid),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'date',
    'dateEstimated',
    'dateDue',
    'state',
    'advanceType',
    'partnerId',
    'reference',
    'amount',
    'amountUsed',
    'amountAvailable',
    'amountReturned',
    'usagePercentage',
    'daysToExpire',
    'isExpired',
    'collectionSessionId',
    'saleOrderId',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'advanceUuid': 'Advance Uuid',
    'name': 'Name',
    'date': 'Date',
    'dateEstimated': 'Date Estimated',
    'dateDue': 'Date Due',
    'state': 'State',
    'advanceType': 'Advance Type',
    'partnerId': 'Partner Id',
    'partnerName': 'Partner Name',
    'reference': 'Reference',
    'amount': 'Amount',
    'amountUsed': 'Amount Used',
    'amountAvailable': 'Amount Available',
    'amountReturned': 'Amount Returned',
    'usagePercentage': 'Usage Percentage',
    'daysToExpire': 'Days To Expire',
    'isExpired': 'Is Expired',
    'collectionSessionId': 'Collection Session Id',
    'saleOrderId': 'Sale Order Id',
    'lines': 'Lines',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(Advance record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(Advance record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(Advance record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(Advance record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'advanceUuid':
        return record.advanceUuid;
      case 'name':
        return record.name;
      case 'date':
        return record.date;
      case 'dateEstimated':
        return record.dateEstimated;
      case 'dateDue':
        return record.dateDue;
      case 'state':
        return record.state;
      case 'advanceType':
        return record.advanceType;
      case 'partnerId':
        return record.partnerId;
      case 'partnerName':
        return record.partnerName;
      case 'reference':
        return record.reference;
      case 'amount':
        return record.amount;
      case 'amountUsed':
        return record.amountUsed;
      case 'amountAvailable':
        return record.amountAvailable;
      case 'amountReturned':
        return record.amountReturned;
      case 'usagePercentage':
        return record.usagePercentage;
      case 'daysToExpire':
        return record.daysToExpire;
      case 'isExpired':
        return record.isExpired;
      case 'collectionSessionId':
        return record.collectionSessionId;
      case 'saleOrderId':
        return record.saleOrderId;
      case 'lines':
        return record.lines;
      default:
        return null;
    }
  }

  @override
  Advance applyWebSocketChangesToRecord(
    Advance record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      advanceUuid: record.advanceUuid,
      lines: record.lines,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'advanceUuid':
        return (obj as dynamic).advanceUuid;
      case 'name':
        return (obj as dynamic).name;
      case 'date':
        return (obj as dynamic).date;
      case 'dateEstimated':
        return (obj as dynamic).dateEstimated;
      case 'dateDue':
        return (obj as dynamic).dateDue;
      case 'state':
        return (obj as dynamic).state;
      case 'advanceType':
        return (obj as dynamic).advanceType;
      case 'partnerId':
        return (obj as dynamic).partnerId;
      case 'partnerName':
        return (obj as dynamic).partnerName;
      case 'reference':
        return (obj as dynamic).reference;
      case 'amount':
        return (obj as dynamic).amount;
      case 'amountUsed':
        return (obj as dynamic).amountUsed;
      case 'amountAvailable':
        return (obj as dynamic).amountAvailable;
      case 'amountReturned':
        return (obj as dynamic).amountReturned;
      case 'usagePercentage':
        return (obj as dynamic).usagePercentage;
      case 'daysToExpire':
        return (obj as dynamic).daysToExpire;
      case 'isExpired':
        return (obj as dynamic).isExpired;
      case 'collectionSessionId':
        return (obj as dynamic).collectionSessionId;
      case 'saleOrderId':
        return (obj as dynamic).saleOrderId;
      case 'lines':
        return (obj as dynamic).lines;
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
    'advanceUuid',
    'name',
    'date',
    'dateEstimated',
    'dateDue',
    'state',
    'advanceType',
    'partnerId',
    'partnerName',
    'reference',
    'amount',
    'amountUsed',
    'amountAvailable',
    'amountReturned',
    'usagePercentage',
    'daysToExpire',
    'isExpired',
    'collectionSessionId',
    'saleOrderId',
    'lines',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'date',
    'dateEstimated',
    'dateDue',
    'state',
    'advanceType',
    'partnerId',
    'reference',
    'amount',
    'amountUsed',
    'amountAvailable',
    'amountReturned',
    'usagePercentage',
    'daysToExpire',
    'isExpired',
    'collectionSessionId',
    'saleOrderId',
  ];
}

/// Global instance of AdvanceManager.
final advanceManager = AdvanceManager();

/// Generated manager for AdvanceLine.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: account.advance.line
class AdvanceLineManager extends OdooModelManager<AdvanceLine>
    with GenericDriftOperations<AdvanceLine> {
  @override
  String get odooModel => 'account.advance.line';

  @override
  String get tableName => 'advance_lines';

  @override
  List<String> get odooFields => [
    'id',
    'journal_id',
    'journal_type',
    'advance_method_line_id',
    'amount',
    'nro_document',
    'date_document',
    'partner_bank_id',
    'check_due_date',
    'card_brand_id',
    'card_deadline_id',
  ];

  @override
  AdvanceLine fromOdoo(Map<String, dynamic> data) {
    return AdvanceLine(
      id: data['id'] as int? ?? 0,
      journalId: extractMany2oneId(data['journal_id']) ?? 0,
      journalName: extractMany2oneName(data['journal_id']),
      journalType: parseOdooString(data['journal_type']),
      advanceMethodLineId: extractMany2oneId(data['advance_method_line_id']),
      advanceMethodName: extractMany2oneName(data['advance_method_line_id']),
      amount: parseOdooDouble(data['amount']) ?? 0.0,
      documentNumber: parseOdooString(data['nro_document']),
      documentDate: parseOdooDate(data['date_document']),
      partnerBankId: extractMany2oneId(data['partner_bank_id']),
      partnerBankName: extractMany2oneName(data['partner_bank_id']),
      checkDueDate: parseOdooDate(data['check_due_date']),
      cardBrandId: extractMany2oneId(data['card_brand_id']),
      cardBrandName: extractMany2oneName(data['card_brand_id']),
      cardDeadlineId: extractMany2oneId(data['card_deadline_id']),
      cardDeadlineName: extractMany2oneName(data['card_deadline_id']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(AdvanceLine record) {
    return {
      'journal_id': record.journalId,
      'journal_type': record.journalType,
      'advance_method_line_id': record.advanceMethodLineId,
      'amount': record.amount,
      'nro_document': record.documentNumber,
      'date_document': formatOdooDate(record.documentDate),
      'partner_bank_id': record.partnerBankId,
      'check_due_date': formatOdooDate(record.checkDueDate),
      'card_brand_id': record.cardBrandId,
      'card_deadline_id': record.cardDeadlineId,
    };
  }

  @override
  AdvanceLine fromDrift(dynamic row) {
    return AdvanceLine(
      id: row.odooId as int,
      lineUuid: row.lineUuid as String?,
      journalId: row.journalId as int,
      journalName: row.journalName as String?,
      journalType: row.journalType as String?,
      advanceMethodLineId: row.advanceMethodLineId as int?,
      advanceMethodName: row.advanceMethodName as String?,
      amount: row.amount as double,
      documentNumber: row.nroDocument as String?,
      documentDate: row.dateDocument as DateTime?,
      partnerBankId: row.partnerBankId as int?,
      partnerBankName: row.partnerBankName as String?,
      checkDueDate: row.checkDueDate as DateTime?,
      cardBrandId: row.cardBrandId as int?,
      cardBrandName: row.cardBrandName as String?,
      cardDeadlineId: row.cardDeadlineId as int?,
      cardDeadlineName: row.cardDeadlineName as String?,
    );
  }

  @override
  int getId(AdvanceLine record) => record.id;

  @override
  String? getUuid(AdvanceLine record) => null;

  @override
  AdvanceLine withIdAndUuid(AdvanceLine record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  AdvanceLine withSyncStatus(AdvanceLine record, bool isSynced) {
    return record; // No sync status field
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'journal_id': 'journalId',
    'journal_type': 'journalType',
    'advance_method_line_id': 'advanceMethodLineId',
    'amount': 'amount',
    'nro_document': 'documentNumber',
    'date_document': 'documentDate',
    'partner_bank_id': 'partnerBankId',
    'check_due_date': 'checkDueDate',
    'card_brand_id': 'cardBrandId',
    'card_deadline_id': 'cardDeadlineId',
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
      throw StateError('Table \'advance_lines\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(AdvanceLine record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'journal_id': Variable<int>(record.journalId),
      'journal_id_name': driftVar<String>(record.journalName),
      'journal_type': driftVar<String>(record.journalType),
      'advance_method_line_id': driftVar<int>(record.advanceMethodLineId),
      'advance_method_line_id_name': driftVar<String>(record.advanceMethodName),
      'amount': Variable<double>(record.amount),
      'nro_document': driftVar<String>(record.documentNumber),
      'date_document': driftVar<DateTime>(record.documentDate),
      'partner_bank_id': driftVar<int>(record.partnerBankId),
      'partner_bank_id_name': driftVar<String>(record.partnerBankName),
      'check_due_date': driftVar<DateTime>(record.checkDueDate),
      'card_brand_id': driftVar<int>(record.cardBrandId),
      'card_brand_id_name': driftVar<String>(record.cardBrandName),
      'card_deadline_id': driftVar<int>(record.cardDeadlineId),
      'card_deadline_id_name': driftVar<String>(record.cardDeadlineName),
      'line_uuid': driftVar<String>(record.lineUuid),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'journalId',
    'journalType',
    'advanceMethodLineId',
    'amount',
    'documentNumber',
    'documentDate',
    'partnerBankId',
    'checkDueDate',
    'cardBrandId',
    'cardDeadlineId',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'lineUuid': 'Line Uuid',
    'journalId': 'Journal Id',
    'journalName': 'Journal Name',
    'journalType': 'Journal Type',
    'advanceMethodLineId': 'Advance Method Line Id',
    'advanceMethodName': 'Advance Method Name',
    'amount': 'Amount',
    'documentNumber': 'Document Number',
    'documentDate': 'Document Date',
    'partnerBankId': 'Partner Bank Id',
    'partnerBankName': 'Partner Bank Name',
    'checkDueDate': 'Check Due Date',
    'cardBrandId': 'Card Brand Id',
    'cardBrandName': 'Card Brand Name',
    'cardDeadlineId': 'Card Deadline Id',
    'cardDeadlineName': 'Card Deadline Name',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(AdvanceLine record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(AdvanceLine record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(AdvanceLine record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(AdvanceLine record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'lineUuid':
        return record.lineUuid;
      case 'journalId':
        return record.journalId;
      case 'journalName':
        return record.journalName;
      case 'journalType':
        return record.journalType;
      case 'advanceMethodLineId':
        return record.advanceMethodLineId;
      case 'advanceMethodName':
        return record.advanceMethodName;
      case 'amount':
        return record.amount;
      case 'documentNumber':
        return record.documentNumber;
      case 'documentDate':
        return record.documentDate;
      case 'partnerBankId':
        return record.partnerBankId;
      case 'partnerBankName':
        return record.partnerBankName;
      case 'checkDueDate':
        return record.checkDueDate;
      case 'cardBrandId':
        return record.cardBrandId;
      case 'cardBrandName':
        return record.cardBrandName;
      case 'cardDeadlineId':
        return record.cardDeadlineId;
      case 'cardDeadlineName':
        return record.cardDeadlineName;
      default:
        return null;
    }
  }

  @override
  AdvanceLine applyWebSocketChangesToRecord(
    AdvanceLine record,
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
      case 'journalId':
        return (obj as dynamic).journalId;
      case 'journalName':
        return (obj as dynamic).journalName;
      case 'journalType':
        return (obj as dynamic).journalType;
      case 'advanceMethodLineId':
        return (obj as dynamic).advanceMethodLineId;
      case 'advanceMethodName':
        return (obj as dynamic).advanceMethodName;
      case 'amount':
        return (obj as dynamic).amount;
      case 'documentNumber':
        return (obj as dynamic).nroDocument;
      case 'documentDate':
        return (obj as dynamic).dateDocument;
      case 'partnerBankId':
        return (obj as dynamic).partnerBankId;
      case 'partnerBankName':
        return (obj as dynamic).partnerBankName;
      case 'checkDueDate':
        return (obj as dynamic).checkDueDate;
      case 'cardBrandId':
        return (obj as dynamic).cardBrandId;
      case 'cardBrandName':
        return (obj as dynamic).cardBrandName;
      case 'cardDeadlineId':
        return (obj as dynamic).cardDeadlineId;
      case 'cardDeadlineName':
        return (obj as dynamic).cardDeadlineName;
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
    'journalId',
    'journalName',
    'journalType',
    'advanceMethodLineId',
    'advanceMethodName',
    'amount',
    'documentNumber',
    'documentDate',
    'partnerBankId',
    'partnerBankName',
    'checkDueDate',
    'cardBrandId',
    'cardBrandName',
    'cardDeadlineId',
    'cardDeadlineName',
  ];

  @override
  List<String> get writableFieldNames => const [
    'journalId',
    'journalType',
    'advanceMethodLineId',
    'amount',
    'documentNumber',
    'documentDate',
    'partnerBankId',
    'checkDueDate',
    'cardBrandId',
    'cardDeadlineId',
  ];
}

/// Global instance of AdvanceLineManager.
final advanceLineManager = AdvanceLineManager();
