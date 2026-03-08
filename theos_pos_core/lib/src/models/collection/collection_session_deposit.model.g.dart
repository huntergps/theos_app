// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_session_deposit.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CollectionSessionDeposit _$CollectionSessionDepositFromJson(
  Map<String, dynamic> json,
) => _CollectionSessionDeposit(
  id: (json['id'] as num?)?.toInt() ?? 0,
  uuid: json['uuid'] as String?,
  isSynced: json['isSynced'] as bool? ?? false,
  lastSyncDate: json['lastSyncDate'] == null
      ? null
      : DateTime.parse(json['lastSyncDate'] as String),
  name: json['name'] as String?,
  number: json['number'] as String?,
  collectionSessionId: (json['collectionSessionId'] as num?)?.toInt(),
  sessionUuid: json['sessionUuid'] as String?,
  userId: (json['userId'] as num?)?.toInt(),
  userName: json['userName'] as String?,
  depositDate: json['depositDate'] == null
      ? null
      : DateTime.parse(json['depositDate'] as String),
  accountingDate: json['accountingDate'] == null
      ? null
      : DateTime.parse(json['accountingDate'] as String),
  amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
  depositType:
      $enumDecodeNullable(_$DepositTypeEnumMap, json['depositType']) ??
      DepositType.cash,
  cashAmount: (json['cashAmount'] as num?)?.toDouble() ?? 0.0,
  checkAmount: (json['checkAmount'] as num?)?.toDouble() ?? 0.0,
  checkCount: (json['checkCount'] as num?)?.toInt() ?? 0,
  bankJournalId: (json['bankJournalId'] as num?)?.toInt(),
  bankJournalName: json['bankJournalName'] as String?,
  bankId: (json['bankId'] as num?)?.toInt(),
  bankName: json['bankName'] as String?,
  state: json['state'] as String?,
  writeDate: json['writeDate'] == null
      ? null
      : DateTime.parse(json['writeDate'] as String),
  depositSlipNumber: json['depositSlipNumber'] as String?,
  bankReference: json['bankReference'] as String?,
  moveId: (json['moveId'] as num?)?.toInt(),
  depositorName: json['depositorName'] as String?,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$CollectionSessionDepositToJson(
  _CollectionSessionDeposit instance,
) => <String, dynamic>{
  'id': instance.id,
  'uuid': instance.uuid,
  'isSynced': instance.isSynced,
  'lastSyncDate': instance.lastSyncDate?.toIso8601String(),
  'name': instance.name,
  'number': instance.number,
  'collectionSessionId': instance.collectionSessionId,
  'sessionUuid': instance.sessionUuid,
  'userId': instance.userId,
  'userName': instance.userName,
  'depositDate': instance.depositDate?.toIso8601String(),
  'accountingDate': instance.accountingDate?.toIso8601String(),
  'amount': instance.amount,
  'depositType': _$DepositTypeEnumMap[instance.depositType]!,
  'cashAmount': instance.cashAmount,
  'checkAmount': instance.checkAmount,
  'checkCount': instance.checkCount,
  'bankJournalId': instance.bankJournalId,
  'bankJournalName': instance.bankJournalName,
  'bankId': instance.bankId,
  'bankName': instance.bankName,
  'state': instance.state,
  'writeDate': instance.writeDate?.toIso8601String(),
  'depositSlipNumber': instance.depositSlipNumber,
  'bankReference': instance.bankReference,
  'moveId': instance.moveId,
  'depositorName': instance.depositorName,
  'notes': instance.notes,
};

const _$DepositTypeEnumMap = {
  DepositType.cash: 'cash',
  DepositType.check: 'check',
  DepositType.mixed: 'mixed',
};

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for CollectionSessionDeposit.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: collection.session.deposit
class CollectionSessionDepositManager
    extends OdooModelManager<CollectionSessionDeposit>
    with GenericDriftOperations<CollectionSessionDeposit> {
  @override
  String get odooModel => 'collection.session.deposit';

  @override
  String get tableName => 'collection_session_deposit';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'number',
    'collection_session_id',
    'session_uuid',
    'user_id',
    'deposit_date',
    'accounting_date',
    'amount',
    'deposit_type',
    'cash_amount',
    'check_amount',
    'check_count',
    'bank_journal_id',
    'bank_id',
    'state',
    'write_date',
    'deposit_slip_number',
    'bank_reference',
    'move_id',
    'depositor_name',
    'notes',
  ];

  @override
  CollectionSessionDeposit fromOdoo(Map<String, dynamic> data) {
    return CollectionSessionDeposit(
      id: data['id'] as int? ?? 0,
      isSynced: false,
      name: parseOdooString(data['name']),
      number: parseOdooString(data['number']),
      collectionSessionId: extractMany2oneId(data['collection_session_id']),
      sessionUuid: parseOdooString(data['session_uuid']),
      userId: extractMany2oneId(data['user_id']),
      userName: extractMany2oneName(data['user_id']),
      depositDate: parseOdooDateTime(data['deposit_date']),
      accountingDate: parseOdooDate(data['accounting_date']),
      amount: parseOdooDouble(data['amount']) ?? 0.0,
      depositType: DepositType.values.firstWhere(
        (e) => e.name == parseOdooSelection(data['deposit_type']),
        orElse: () => DepositType.values.first,
      ),
      cashAmount: parseOdooDouble(data['cash_amount']) ?? 0.0,
      checkAmount: parseOdooDouble(data['check_amount']) ?? 0.0,
      checkCount: parseOdooInt(data['check_count']) ?? 0,
      bankJournalId: extractMany2oneId(data['bank_journal_id']),
      bankJournalName: extractMany2oneName(data['bank_journal_id']),
      bankId: extractMany2oneId(data['bank_id']),
      bankName: extractMany2oneName(data['bank_id']),
      state: parseOdooSelection(data['state']),
      writeDate: parseOdooDateTime(data['write_date']),
      depositSlipNumber: parseOdooString(data['deposit_slip_number']),
      bankReference: parseOdooString(data['bank_reference']),
      moveId: extractMany2oneId(data['move_id']),
      depositorName: parseOdooString(data['depositor_name']),
      notes: parseOdooString(data['notes']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(CollectionSessionDeposit record) {
    return {
      'name': record.name,
      'number': record.number,
      'collection_session_id': record.collectionSessionId,
      'session_uuid': record.sessionUuid,
      'user_id': record.userId,
      'deposit_date': formatOdooDateTime(record.depositDate),
      'accounting_date': formatOdooDate(record.accountingDate),
      'amount': record.amount,
      'deposit_type': record.depositType.name,
      'cash_amount': record.cashAmount,
      'check_amount': record.checkAmount,
      'check_count': record.checkCount,
      'bank_journal_id': record.bankJournalId,
      'bank_id': record.bankId,
      'state': record.state,
      'write_date': formatOdooDateTime(record.writeDate),
      'deposit_slip_number': record.depositSlipNumber,
      'bank_reference': record.bankReference,
      'move_id': record.moveId,
      'depositor_name': record.depositorName,
      'notes': record.notes,
    };
  }

  @override
  CollectionSessionDeposit fromDrift(dynamic row) {
    return CollectionSessionDeposit(
      id: row.odooId as int,
      uuid: row.uuid as String?,
      isSynced: row.isSynced as bool? ?? false,
      lastSyncDate: row.lastSyncDate as DateTime?,
      name: row.name as String?,
      number: row.number as String?,
      collectionSessionId: row.collectionSessionId as int?,
      sessionUuid: row.sessionUuid as String?,
      userId: row.userId as int?,
      userName: row.userName as String?,
      depositDate: row.depositDate as DateTime?,
      accountingDate: row.accountingDate as DateTime?,
      amount: row.amount as double,
      depositType: DepositType.values.firstWhere(
        (e) => e.name == (row.depositType as String?),
        orElse: () => DepositType.values.first,
      ),
      cashAmount: row.cashAmount as double,
      checkAmount: row.checkAmount as double,
      checkCount: row.checkCount as int,
      bankJournalId: row.bankJournalId as int?,
      bankJournalName: row.bankJournalName as String?,
      bankId: row.bankId as int?,
      bankName: row.bankName as String?,
      state: row.state as String?,
      writeDate: row.writeDate as DateTime?,
      depositSlipNumber: row.depositSlipNumber as String?,
      bankReference: row.bankReference as String?,
      moveId: row.moveId as int?,
      depositorName: row.depositorName as String?,
      notes: row.notes as String?,
    );
  }

  @override
  int getId(CollectionSessionDeposit record) => record.id;

  @override
  String? getUuid(CollectionSessionDeposit record) => record.uuid;

  @override
  CollectionSessionDeposit withIdAndUuid(
    CollectionSessionDeposit record,
    int id,
    String uuid,
  ) {
    return record.copyWith(id: id, uuid: uuid);
  }

  @override
  CollectionSessionDeposit withSyncStatus(
    CollectionSessionDeposit record,
    bool isSynced,
  ) {
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
    'number': 'number',
    'collection_session_id': 'collectionSessionId',
    'session_uuid': 'sessionUuid',
    'user_id': 'userId',
    'deposit_date': 'depositDate',
    'accounting_date': 'accountingDate',
    'amount': 'amount',
    'deposit_type': 'depositType',
    'cash_amount': 'cashAmount',
    'check_amount': 'checkAmount',
    'check_count': 'checkCount',
    'bank_journal_id': 'bankJournalId',
    'bank_id': 'bankId',
    'state': 'state',
    'write_date': 'writeDate',
    'deposit_slip_number': 'depositSlipNumber',
    'bank_reference': 'bankReference',
    'move_id': 'moveId',
    'depositor_name': 'depositorName',
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
        'Table \'collection_session_deposit\' not found in database.',
      );
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(CollectionSessionDeposit record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': driftVar<String>(record.name),
      'number': driftVar<String>(record.number),
      'collection_session_id': driftVar<int>(record.collectionSessionId),
      'session_uuid': driftVar<String>(record.sessionUuid),
      'user_id': driftVar<int>(record.userId),
      'user_id_name': driftVar<String>(record.userName),
      'deposit_date': driftVar<DateTime>(record.depositDate),
      'accounting_date': driftVar<DateTime>(record.accountingDate),
      'amount': Variable<double>(record.amount),
      'deposit_type': Variable<String>(record.depositType.name),
      'cash_amount': Variable<double>(record.cashAmount),
      'check_amount': Variable<double>(record.checkAmount),
      'check_count': Variable<int>(record.checkCount),
      'bank_journal_id': driftVar<int>(record.bankJournalId),
      'bank_journal_id_name': driftVar<String>(record.bankJournalName),
      'bank_id': driftVar<int>(record.bankId),
      'bank_id_name': driftVar<String>(record.bankName),
      'state': driftVar<String>(record.state),
      'write_date': driftVar<DateTime>(record.writeDate),
      'deposit_slip_number': driftVar<String>(record.depositSlipNumber),
      'bank_reference': driftVar<String>(record.bankReference),
      'move_id': driftVar<int>(record.moveId),
      'depositor_name': driftVar<String>(record.depositorName),
      'notes': driftVar<String>(record.notes),
      'uuid': driftVar<String>(record.uuid),
      'is_synced': Variable<bool>(record.isSynced),
      'last_sync_date': driftVar<DateTime>(record.lastSyncDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'number',
    'collectionSessionId',
    'sessionUuid',
    'userId',
    'depositDate',
    'accountingDate',
    'amount',
    'depositType',
    'cashAmount',
    'checkAmount',
    'checkCount',
    'bankJournalId',
    'bankId',
    'state',
    'writeDate',
    'depositSlipNumber',
    'bankReference',
    'moveId',
    'depositorName',
    'notes',
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
    'number': 'Number',
    'collectionSessionId': 'Collection Session Id',
    'sessionUuid': 'Session Uuid',
    'userId': 'User Id',
    'userName': 'User Name',
    'depositDate': 'Deposit Date',
    'accountingDate': 'Accounting Date',
    'amount': 'Amount',
    'depositType': 'Deposit Type',
    'cashAmount': 'Cash Amount',
    'checkAmount': 'Check Amount',
    'checkCount': 'Check Count',
    'bankJournalId': 'Bank Journal Id',
    'bankJournalName': 'Bank Journal Name',
    'bankId': 'Bank Id',
    'bankName': 'Bank Name',
    'state': 'State',
    'writeDate': 'Write Date',
    'depositSlipNumber': 'Deposit Slip Number',
    'bankReference': 'Bank Reference',
    'moveId': 'Move Id',
    'depositorName': 'Depositor Name',
    'notes': 'Notes',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(CollectionSessionDeposit record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(CollectionSessionDeposit record) =>
      validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(CollectionSessionDeposit record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(
    CollectionSessionDeposit record,
    String fieldName,
  ) {
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
      case 'number':
        return record.number;
      case 'collectionSessionId':
        return record.collectionSessionId;
      case 'sessionUuid':
        return record.sessionUuid;
      case 'userId':
        return record.userId;
      case 'userName':
        return record.userName;
      case 'depositDate':
        return record.depositDate;
      case 'accountingDate':
        return record.accountingDate;
      case 'amount':
        return record.amount;
      case 'depositType':
        return record.depositType;
      case 'cashAmount':
        return record.cashAmount;
      case 'checkAmount':
        return record.checkAmount;
      case 'checkCount':
        return record.checkCount;
      case 'bankJournalId':
        return record.bankJournalId;
      case 'bankJournalName':
        return record.bankJournalName;
      case 'bankId':
        return record.bankId;
      case 'bankName':
        return record.bankName;
      case 'state':
        return record.state;
      case 'writeDate':
        return record.writeDate;
      case 'depositSlipNumber':
        return record.depositSlipNumber;
      case 'bankReference':
        return record.bankReference;
      case 'moveId':
        return record.moveId;
      case 'depositorName':
        return record.depositorName;
      case 'notes':
        return record.notes;
      default:
        return null;
    }
  }

  @override
  CollectionSessionDeposit applyWebSocketChangesToRecord(
    CollectionSessionDeposit record,
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
      case 'number':
        return (obj as dynamic).number;
      case 'collectionSessionId':
        return (obj as dynamic).collectionSessionId;
      case 'sessionUuid':
        return (obj as dynamic).sessionUuid;
      case 'userId':
        return (obj as dynamic).userId;
      case 'userName':
        return (obj as dynamic).userName;
      case 'depositDate':
        return (obj as dynamic).depositDate;
      case 'accountingDate':
        return (obj as dynamic).accountingDate;
      case 'amount':
        return (obj as dynamic).amount;
      case 'depositType':
        return (obj as dynamic).depositType;
      case 'cashAmount':
        return (obj as dynamic).cashAmount;
      case 'checkAmount':
        return (obj as dynamic).checkAmount;
      case 'checkCount':
        return (obj as dynamic).checkCount;
      case 'bankJournalId':
        return (obj as dynamic).bankJournalId;
      case 'bankJournalName':
        return (obj as dynamic).bankJournalName;
      case 'bankId':
        return (obj as dynamic).bankId;
      case 'bankName':
        return (obj as dynamic).bankName;
      case 'state':
        return (obj as dynamic).state;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'depositSlipNumber':
        return (obj as dynamic).depositSlipNumber;
      case 'bankReference':
        return (obj as dynamic).bankReference;
      case 'moveId':
        return (obj as dynamic).moveId;
      case 'depositorName':
        return (obj as dynamic).depositorName;
      case 'notes':
        return (obj as dynamic).notes;
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
    'number',
    'collectionSessionId',
    'sessionUuid',
    'userId',
    'userName',
    'depositDate',
    'accountingDate',
    'amount',
    'depositType',
    'cashAmount',
    'checkAmount',
    'checkCount',
    'bankJournalId',
    'bankJournalName',
    'bankId',
    'bankName',
    'state',
    'writeDate',
    'depositSlipNumber',
    'bankReference',
    'moveId',
    'depositorName',
    'notes',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'number',
    'collectionSessionId',
    'sessionUuid',
    'userId',
    'depositDate',
    'accountingDate',
    'amount',
    'depositType',
    'cashAmount',
    'checkAmount',
    'checkCount',
    'bankJournalId',
    'bankId',
    'state',
    'writeDate',
    'depositSlipNumber',
    'bankReference',
    'moveId',
    'depositorName',
    'notes',
  ];
}

/// Global instance of CollectionSessionDepositManager.
final collectionSessionDepositManager = CollectionSessionDepositManager();
