// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_out.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CashOut _$CashOutFromJson(Map<String, dynamic> json) => _CashOut(
  id: (json['id'] as num?)?.toInt() ?? 0,
  uuid: json['uuid'] as String?,
  isSynced: json['isSynced'] as bool? ?? false,
  lastSyncDate: json['lastSyncDate'] == null
      ? null
      : DateTime.parse(json['lastSyncDate'] as String),
  name: json['name'] as String?,
  date: DateTime.parse(json['date'] as String),
  state:
      $enumDecodeNullable(_$CashOutStateEnumMap, json['state']) ??
      CashOutState.draft,
  cashFlow:
      $enumDecodeNullable(_$CashFlowEnumMap, json['cashFlow']) ?? CashFlow.out,
  journalId: (json['journalId'] as num).toInt(),
  journalName: json['journalName'] as String?,
  partnerId: (json['partnerId'] as num?)?.toInt(),
  partnerName: json['partnerName'] as String?,
  accountIdManual: (json['accountIdManual'] as num?)?.toInt(),
  collectionSessionId: (json['collectionSessionId'] as num?)?.toInt(),
  moveId: (json['moveId'] as num?)?.toInt(),
  amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
  note: json['note'] as String?,
  typeCode: json['typeCode'] as String? ?? 'other',
  typeId: (json['typeId'] as num?)?.toInt(),
  typeName: json['typeName'] as String?,
);

Map<String, dynamic> _$CashOutToJson(_CashOut instance) => <String, dynamic>{
  'id': instance.id,
  'uuid': instance.uuid,
  'isSynced': instance.isSynced,
  'lastSyncDate': instance.lastSyncDate?.toIso8601String(),
  'name': instance.name,
  'date': instance.date.toIso8601String(),
  'state': _$CashOutStateEnumMap[instance.state]!,
  'cashFlow': _$CashFlowEnumMap[instance.cashFlow]!,
  'journalId': instance.journalId,
  'journalName': instance.journalName,
  'partnerId': instance.partnerId,
  'partnerName': instance.partnerName,
  'accountIdManual': instance.accountIdManual,
  'collectionSessionId': instance.collectionSessionId,
  'moveId': instance.moveId,
  'amount': instance.amount,
  'note': instance.note,
  'typeCode': instance.typeCode,
  'typeId': instance.typeId,
  'typeName': instance.typeName,
};

const _$CashOutStateEnumMap = {
  CashOutState.draft: 'draft',
  CashOutState.posted: 'posted',
  CashOutState.cancelled: 'cancelled',
};

const _$CashFlowEnumMap = {CashFlow.out: 'out', CashFlow.inFlow: 'in'};

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for CashOut.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: l10n_ec_collection_box.cash_out
class CashOutManager extends OdooModelManager<CashOut>
    with GenericDriftOperations<CashOut> {
  @override
  String get odooModel => 'l10n_ec_collection_box.cash_out';

  @override
  String get tableName => 'cash_out';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'date',
    'state',
    'cash_flow',
    'journal_id',
    'partner_id',
    'account_id_manual',
    'collection_session_id',
    'move_id',
    'amount',
    'note',
    'cash_out_type',
    'cash_out_type_id',
  ];

  @override
  CashOut fromOdoo(Map<String, dynamic> data) {
    return CashOut(
      id: data['id'] as int? ?? 0,
      isSynced: false,
      name: parseOdooString(data['name']),
      date: parseOdooDate(data['date']) ?? DateTime(1970),
      state: CashOutState.values.firstWhere(
        (e) => e.code == parseOdooSelection(data['state']),
        orElse: () => CashOutState.values.first,
      ),
      cashFlow: CashFlow.values.firstWhere(
        (e) => e.code == parseOdooSelection(data['cash_flow']),
        orElse: () => CashFlow.values.first,
      ),
      journalId: extractMany2oneId(data['journal_id']) ?? 0,
      journalName: extractMany2oneName(data['journal_id']),
      partnerId: extractMany2oneId(data['partner_id']),
      partnerName: extractMany2oneName(data['partner_id']),
      accountIdManual: extractMany2oneId(data['account_id_manual']),
      collectionSessionId: extractMany2oneId(data['collection_session_id']),
      moveId: extractMany2oneId(data['move_id']),
      amount: parseOdooDouble(data['amount']) ?? 0.0,
      note: parseOdooString(data['note']),
      typeCode: parseOdooSelection(data['cash_out_type']) ?? '',
      typeId: extractMany2oneId(data['cash_out_type_id']),
      typeName: extractMany2oneName(data['cash_out_type_id']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(CashOut record) {
    return {
      'name': record.name,
      'date': formatOdooDate(record.date),
      'state': record.state.code,
      'cash_flow': record.cashFlow.code,
      'journal_id': record.journalId,
      'partner_id': record.partnerId,
      'account_id_manual': record.accountIdManual,
      'collection_session_id': record.collectionSessionId,
      'move_id': record.moveId,
      'amount': record.amount,
      'note': record.note,
      'cash_out_type': record.typeCode,
      'cash_out_type_id': record.typeId,
    };
  }

  @override
  CashOut fromDrift(dynamic row) {
    return CashOut(
      id: row.odooId as int,
      uuid: row.uuid as String?,
      isSynced: row.isSynced as bool? ?? false,
      lastSyncDate: row.lastSyncDate as DateTime?,
      name: row.name as String?,
      date: row.date as DateTime,
      state: CashOutState.values.firstWhere(
        (e) => e.code == (row.state as String?),
        orElse: () => CashOutState.values.first,
      ),
      cashFlow: CashFlow.values.firstWhere(
        (e) => e.code == (row.cashFlow as String?),
        orElse: () => CashFlow.values.first,
      ),
      journalId: row.journalId as int,
      journalName: row.journalName as String?,
      partnerId: row.partnerId as int?,
      partnerName: row.partnerName as String?,
      accountIdManual: row.accountIdManual as int?,
      collectionSessionId: row.collectionSessionId as int?,
      moveId: row.moveId as int?,
      amount: row.amount as double,
      note: row.note as String?,
      typeCode: row.typeCode as String,
      typeId: row.typeId as int?,
      typeName: row.typeName as String?,
    );
  }

  @override
  int getId(CashOut record) => record.id;

  @override
  String? getUuid(CashOut record) => record.uuid;

  @override
  CashOut withIdAndUuid(CashOut record, int id, String uuid) {
    return record.copyWith(id: id, uuid: uuid);
  }

  @override
  CashOut withSyncStatus(CashOut record, bool isSynced) {
    return record.copyWith(isSynced: isSynced);
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
    'state': 'state',
    'cash_flow': 'cashFlow',
    'journal_id': 'journalId',
    'partner_id': 'partnerId',
    'account_id_manual': 'accountIdManual',
    'collection_session_id': 'collectionSessionId',
    'move_id': 'moveId',
    'amount': 'amount',
    'note': 'note',
    'cash_out_type': 'typeCode',
    'cash_out_type_id': 'typeId',
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
      throw StateError('Table \'cash_out\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(CashOut record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': driftVar<String>(record.name),
      'date': Variable<DateTime>(record.date),
      'state': Variable<String>(record.state.code),
      'cash_flow': Variable<String>(record.cashFlow.code),
      'journal_id': Variable<int>(record.journalId),
      'journal_id_name': driftVar<String>(record.journalName),
      'partner_id': driftVar<int>(record.partnerId),
      'partner_id_name': driftVar<String>(record.partnerName),
      'account_id_manual': driftVar<int>(record.accountIdManual),
      'collection_session_id': driftVar<int>(record.collectionSessionId),
      'move_id': driftVar<int>(record.moveId),
      'amount': Variable<double>(record.amount),
      'note': driftVar<String>(record.note),
      'cash_out_type': Variable<String>(record.typeCode),
      'cash_out_type_id': driftVar<int>(record.typeId),
      'cash_out_type_id_name': driftVar<String>(record.typeName),
      'uuid': driftVar<String>(record.uuid),
      'is_synced': Variable<bool>(record.isSynced),
      'last_sync_date': driftVar<DateTime>(record.lastSyncDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'date',
    'state',
    'cashFlow',
    'journalId',
    'partnerId',
    'accountIdManual',
    'collectionSessionId',
    'moveId',
    'amount',
    'note',
    'typeCode',
    'typeId',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'uuid': 'Uuid',
    'isSynced': 'Is Synced',
    'lastSyncDate': 'Last Sync Date',
    'name': 'Name',
    'date': 'Date',
    'state': 'State',
    'cashFlow': 'Cash Flow',
    'journalId': 'Journal Id',
    'journalName': 'Journal Name',
    'partnerId': 'Partner Id',
    'partnerName': 'Partner Name',
    'accountIdManual': 'Account Id Manual',
    'collectionSessionId': 'Collection Session Id',
    'moveId': 'Move Id',
    'amount': 'Amount',
    'note': 'Note',
    'typeCode': 'Type Code',
    'typeId': 'Type Id',
    'typeName': 'Type Name',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(CashOut record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(CashOut record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(CashOut record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(CashOut record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'uuid':
        return record.uuid;
      case 'isSynced':
        return record.isSynced;
      case 'lastSyncDate':
        return record.lastSyncDate;
      case 'name':
        return record.name;
      case 'date':
        return record.date;
      case 'state':
        return record.state;
      case 'cashFlow':
        return record.cashFlow;
      case 'journalId':
        return record.journalId;
      case 'journalName':
        return record.journalName;
      case 'partnerId':
        return record.partnerId;
      case 'partnerName':
        return record.partnerName;
      case 'accountIdManual':
        return record.accountIdManual;
      case 'collectionSessionId':
        return record.collectionSessionId;
      case 'moveId':
        return record.moveId;
      case 'amount':
        return record.amount;
      case 'note':
        return record.note;
      case 'typeCode':
        return record.typeCode;
      case 'typeId':
        return record.typeId;
      case 'typeName':
        return record.typeName;
      default:
        return null;
    }
  }

  @override
  CashOut applyWebSocketChangesToRecord(
    CashOut record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      uuid: record.uuid,
      isSynced: record.isSynced,
      lastSyncDate: record.lastSyncDate,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'uuid':
        return (obj as dynamic).uuid;
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'lastSyncDate':
        return (obj as dynamic).lastSyncDate;
      case 'name':
        return (obj as dynamic).name;
      case 'date':
        return (obj as dynamic).date;
      case 'state':
        return (obj as dynamic).state;
      case 'cashFlow':
        return (obj as dynamic).cashFlow;
      case 'journalId':
        return (obj as dynamic).journalId;
      case 'journalName':
        return (obj as dynamic).journalName;
      case 'partnerId':
        return (obj as dynamic).partnerId;
      case 'partnerName':
        return (obj as dynamic).partnerName;
      case 'accountIdManual':
        return (obj as dynamic).accountIdManual;
      case 'collectionSessionId':
        return (obj as dynamic).collectionSessionId;
      case 'moveId':
        return (obj as dynamic).moveId;
      case 'amount':
        return (obj as dynamic).amount;
      case 'note':
        return (obj as dynamic).note;
      case 'typeCode':
        return (obj as dynamic).typeCode;
      case 'typeId':
        return (obj as dynamic).typeId;
      case 'typeName':
        return (obj as dynamic).typeName;
      case 'writeDate':
        return (obj as dynamic).writeDate;
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
    'isSynced',
    'lastSyncDate',
    'name',
    'date',
    'state',
    'cashFlow',
    'journalId',
    'journalName',
    'partnerId',
    'partnerName',
    'accountIdManual',
    'collectionSessionId',
    'moveId',
    'amount',
    'note',
    'typeCode',
    'typeId',
    'typeName',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'date',
    'state',
    'cashFlow',
    'journalId',
    'partnerId',
    'accountIdManual',
    'collectionSessionId',
    'moveId',
    'amount',
    'note',
    'typeCode',
    'typeId',
  ];
}

/// Global instance of CashOutManager.
final cashOutManager = CashOutManager();
