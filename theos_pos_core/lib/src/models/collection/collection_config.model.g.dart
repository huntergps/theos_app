// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_config.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CollectionConfig _$CollectionConfigFromJson(
  Map<String, dynamic> json,
) => _CollectionConfig(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  code: json['code'] as String,
  active: json['active'] as bool? ?? true,
  companyId: (json['companyId'] as num?)?.toInt(),
  companyName: json['companyName'] as String?,
  journalId: (json['journalId'] as num?)?.toInt(),
  journalName: json['journalName'] as String?,
  cashJournalId: (json['cashJournalId'] as num?)?.toInt(),
  cashJournalName: json['cashJournalName'] as String?,
  allowedJournalIds: (json['allowedJournalIds'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  cashDifferenceAccountId: (json['cashDifferenceAccountId'] as num?)?.toInt(),
  currencyId: (json['currencyId'] as num?)?.toInt(),
  currencyName: json['currencyName'] as String?,
  setMaximumDifference: json['setMaximumDifference'] as bool? ?? false,
  amountAuthorizedDiff:
      (json['amountAuthorizedDiff'] as num?)?.toDouble() ?? 0.0,
  userIds: (json['userIds'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  currentSessionId: (json['currentSessionId'] as num?)?.toInt(),
  currentSessionState: json['currentSessionState'] as String?,
  currentSessionName: json['currentSessionName'] as String?,
  numberOfOpenedSession: (json['numberOfOpenedSession'] as num?)?.toInt() ?? 0,
  lastSessionClosingDate: json['lastSessionClosingDate'] == null
      ? null
      : DateTime.parse(json['lastSessionClosingDate'] as String),
  lastSessionClosingCash:
      (json['lastSessionClosingCash'] as num?)?.toDouble() ?? 0.0,
  currentSessionUserName: json['currentSessionUserName'] as String?,
  currentSessionStateDisplay: json['currentSessionStateDisplay'] as String?,
  numberOfRescueSession: (json['numberOfRescueSession'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CollectionConfigToJson(
  _CollectionConfig instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'code': instance.code,
  'active': instance.active,
  'companyId': instance.companyId,
  'companyName': instance.companyName,
  'journalId': instance.journalId,
  'journalName': instance.journalName,
  'cashJournalId': instance.cashJournalId,
  'cashJournalName': instance.cashJournalName,
  'allowedJournalIds': instance.allowedJournalIds,
  'cashDifferenceAccountId': instance.cashDifferenceAccountId,
  'currencyId': instance.currencyId,
  'currencyName': instance.currencyName,
  'setMaximumDifference': instance.setMaximumDifference,
  'amountAuthorizedDiff': instance.amountAuthorizedDiff,
  'userIds': instance.userIds,
  'currentSessionId': instance.currentSessionId,
  'currentSessionState': instance.currentSessionState,
  'currentSessionName': instance.currentSessionName,
  'numberOfOpenedSession': instance.numberOfOpenedSession,
  'lastSessionClosingDate': instance.lastSessionClosingDate?.toIso8601String(),
  'lastSessionClosingCash': instance.lastSessionClosingCash,
  'currentSessionUserName': instance.currentSessionUserName,
  'currentSessionStateDisplay': instance.currentSessionStateDisplay,
  'numberOfRescueSession': instance.numberOfRescueSession,
};

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for CollectionConfig.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: collection.config
class CollectionConfigManager extends OdooModelManager<CollectionConfig>
    with GenericDriftOperations<CollectionConfig> {
  @override
  String get odooModel => 'collection.config';

  @override
  String get tableName => 'collection_config';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'code',
    'active',
    'company_id',
    'journal_id',
    'cash_journal_id',
    'allowed_journal_ids',
    'cash_difference_account_id',
    'currency_id',
    'set_maximum_difference',
    'amount_authorized_diff',
    'user_ids',
    'current_session_id',
    'current_session_state',
    'current_session_name',
    'number_of_opened_session',
    'last_session_closing_date',
    'last_session_closing_cash',
    'collection_session_username',
    'current_session_state_display',
    'number_of_rescue_session',
  ];

  @override
  CollectionConfig fromOdoo(Map<String, dynamic> data) {
    return CollectionConfig(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      code: parseOdooStringRequired(data['code']),
      active: parseOdooBool(data['active']),
      companyId: extractMany2oneId(data['company_id']),
      companyName: extractMany2oneName(data['company_id']),
      journalId: extractMany2oneId(data['journal_id']),
      journalName: extractMany2oneName(data['journal_id']),
      cashJournalId: extractMany2oneId(data['cash_journal_id']),
      cashJournalName: extractMany2oneName(data['cash_journal_id']),
      allowedJournalIds: extractMany2manyIds(data['allowed_journal_ids']),
      cashDifferenceAccountId: extractMany2oneId(
        data['cash_difference_account_id'],
      ),
      currencyId: extractMany2oneId(data['currency_id']),
      currencyName: extractMany2oneName(data['currency_id']),
      setMaximumDifference: parseOdooBool(data['set_maximum_difference']),
      amountAuthorizedDiff:
          parseOdooDouble(data['amount_authorized_diff']) ?? 0.0,
      userIds: extractMany2manyIds(data['user_ids']),
      currentSessionId: extractMany2oneId(data['current_session_id']),
      currentSessionState: parseOdooSelection(data['current_session_state']),
      currentSessionName: parseOdooString(data['current_session_name']),
      numberOfOpenedSession:
          parseOdooInt(data['number_of_opened_session']) ?? 0,
      lastSessionClosingDate: parseOdooDateTime(
        data['last_session_closing_date'],
      ),
      lastSessionClosingCash:
          parseOdooDouble(data['last_session_closing_cash']) ?? 0.0,
      currentSessionUserName: parseOdooString(
        data['collection_session_username'],
      ),
      currentSessionStateDisplay: parseOdooString(
        data['current_session_state_display'],
      ),
      numberOfRescueSession:
          parseOdooInt(data['number_of_rescue_session']) ?? 0,
    );
  }

  @override
  Map<String, dynamic> toOdoo(CollectionConfig record) {
    return {
      'name': record.name,
      'code': record.code,
      'active': record.active,
      'company_id': record.companyId,
      'journal_id': record.journalId,
      'cash_journal_id': record.cashJournalId,
      'allowed_journal_ids': buildMany2manyReplace(
        record.allowedJournalIds ?? [],
      ),
      'cash_difference_account_id': record.cashDifferenceAccountId,
      'currency_id': record.currencyId,
      'set_maximum_difference': record.setMaximumDifference,
      'amount_authorized_diff': record.amountAuthorizedDiff,
      'user_ids': buildMany2manyReplace(record.userIds ?? []),
      'current_session_id': record.currentSessionId,
      'current_session_state': record.currentSessionState,
      'current_session_name': record.currentSessionName,
      'number_of_opened_session': record.numberOfOpenedSession,
      'last_session_closing_date': formatOdooDateTime(
        record.lastSessionClosingDate,
      ),
      'last_session_closing_cash': record.lastSessionClosingCash,
      'collection_session_username': record.currentSessionUserName,
      'current_session_state_display': record.currentSessionStateDisplay,
      'number_of_rescue_session': record.numberOfRescueSession,
    };
  }

  @override
  CollectionConfig fromDrift(dynamic row) {
    return CollectionConfig(
      id: row.odooId as int,
      name: row.name as String,
      code: row.code as String,
      active: row.active as bool,
      companyId: row.companyId as int?,
      companyName: row.companyName as String?,
      journalId: row.journalId as int?,
      journalName: row.journalName as String?,
      cashJournalId: row.cashJournalId as int?,
      cashJournalName: row.cashJournalName as String?,
      cashDifferenceAccountId: row.cashDifferenceAccountId as int?,
      currencyId: row.currencyId as int?,
      currencyName: row.currencyName as String?,
      setMaximumDifference: row.setMaximumDifference as bool,
      amountAuthorizedDiff: row.amountAuthorizedDiff as double,
      currentSessionId: row.currentSessionId as int?,
      currentSessionState: row.currentSessionState as String?,
      currentSessionName: row.currentSessionName as String?,
      numberOfOpenedSession: row.numberOfOpenedSession as int,
      lastSessionClosingDate: row.lastSessionClosingDate as DateTime?,
      lastSessionClosingCash: row.lastSessionClosingCash as double,
      currentSessionUserName: row.currentSessionUserName as String?,
      currentSessionStateDisplay: row.currentSessionStateDisplay as String?,
      numberOfRescueSession: row.numberOfRescueSession as int,
    );
  }

  @override
  int getId(CollectionConfig record) => record.id;

  @override
  String? getUuid(CollectionConfig record) => null;

  @override
  CollectionConfig withIdAndUuid(CollectionConfig record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  CollectionConfig withSyncStatus(CollectionConfig record, bool isSynced) {
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
    'code': 'code',
    'active': 'active',
    'company_id': 'companyId',
    'journal_id': 'journalId',
    'cash_journal_id': 'cashJournalId',
    'allowed_journal_ids': 'allowedJournalIds',
    'cash_difference_account_id': 'cashDifferenceAccountId',
    'currency_id': 'currencyId',
    'set_maximum_difference': 'setMaximumDifference',
    'amount_authorized_diff': 'amountAuthorizedDiff',
    'user_ids': 'userIds',
    'current_session_id': 'currentSessionId',
    'current_session_state': 'currentSessionState',
    'current_session_name': 'currentSessionName',
    'number_of_opened_session': 'numberOfOpenedSession',
    'last_session_closing_date': 'lastSessionClosingDate',
    'last_session_closing_cash': 'lastSessionClosingCash',
    'collection_session_username': 'currentSessionUserName',
    'current_session_state_display': 'currentSessionStateDisplay',
    'number_of_rescue_session': 'numberOfRescueSession',
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
      throw StateError('Table \'collection_config\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(CollectionConfig record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'code': Variable<String>(record.code),
      'active': Variable<bool>(record.active),
      'company_id': driftVar<int>(record.companyId),
      'company_id_name': driftVar<String>(record.companyName),
      'journal_id': driftVar<int>(record.journalId),
      'journal_id_name': driftVar<String>(record.journalName),
      'cash_journal_id': driftVar<int>(record.cashJournalId),
      'cash_journal_id_name': driftVar<String>(record.cashJournalName),
      'cash_difference_account_id': driftVar<int>(
        record.cashDifferenceAccountId,
      ),
      'currency_id': driftVar<int>(record.currencyId),
      'currency_id_name': driftVar<String>(record.currencyName),
      'set_maximum_difference': Variable<bool>(record.setMaximumDifference),
      'amount_authorized_diff': Variable<double>(record.amountAuthorizedDiff),
      'current_session_id': driftVar<int>(record.currentSessionId),
      'current_session_state': driftVar<String>(record.currentSessionState),
      'current_session_name': driftVar<String>(record.currentSessionName),
      'number_of_opened_session': Variable<int>(record.numberOfOpenedSession),
      'last_session_closing_date': driftVar<DateTime>(
        record.lastSessionClosingDate,
      ),
      'last_session_closing_cash': Variable<double>(
        record.lastSessionClosingCash,
      ),
      'collection_session_username': driftVar<String>(
        record.currentSessionUserName,
      ),
      'current_session_state_display': driftVar<String>(
        record.currentSessionStateDisplay,
      ),
      'number_of_rescue_session': Variable<int>(record.numberOfRescueSession),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'code',
    'active',
    'companyId',
    'journalId',
    'cashJournalId',
    'allowedJournalIds',
    'cashDifferenceAccountId',
    'currencyId',
    'setMaximumDifference',
    'amountAuthorizedDiff',
    'userIds',
    'currentSessionId',
    'currentSessionState',
    'currentSessionName',
    'numberOfOpenedSession',
    'lastSessionClosingDate',
    'lastSessionClosingCash',
    'currentSessionUserName',
    'currentSessionStateDisplay',
    'numberOfRescueSession',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'code': 'Code',
    'active': 'Active',
    'companyId': 'Company Id',
    'companyName': 'Company Name',
    'journalId': 'Journal Id',
    'journalName': 'Journal Name',
    'cashJournalId': 'Cash Journal Id',
    'cashJournalName': 'Cash Journal Name',
    'allowedJournalIds': 'Allowed Journal Ids',
    'cashDifferenceAccountId': 'Cash Difference Account Id',
    'currencyId': 'Currency Id',
    'currencyName': 'Currency Name',
    'setMaximumDifference': 'Set Maximum Difference',
    'amountAuthorizedDiff': 'Amount Authorized Diff',
    'userIds': 'User Ids',
    'currentSessionId': 'Current Session Id',
    'currentSessionState': 'Current Session State',
    'currentSessionName': 'Current Session Name',
    'numberOfOpenedSession': 'Number Of Opened Session',
    'lastSessionClosingDate': 'Last Session Closing Date',
    'lastSessionClosingCash': 'Last Session Closing Cash',
    'currentSessionUserName': 'Current Session User Name',
    'currentSessionStateDisplay': 'Current Session State Display',
    'numberOfRescueSession': 'Number Of Rescue Session',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(CollectionConfig record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(CollectionConfig record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(CollectionConfig record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(CollectionConfig record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'code':
        return record.code;
      case 'active':
        return record.active;
      case 'companyId':
        return record.companyId;
      case 'companyName':
        return record.companyName;
      case 'journalId':
        return record.journalId;
      case 'journalName':
        return record.journalName;
      case 'cashJournalId':
        return record.cashJournalId;
      case 'cashJournalName':
        return record.cashJournalName;
      case 'allowedJournalIds':
        return record.allowedJournalIds;
      case 'cashDifferenceAccountId':
        return record.cashDifferenceAccountId;
      case 'currencyId':
        return record.currencyId;
      case 'currencyName':
        return record.currencyName;
      case 'setMaximumDifference':
        return record.setMaximumDifference;
      case 'amountAuthorizedDiff':
        return record.amountAuthorizedDiff;
      case 'userIds':
        return record.userIds;
      case 'currentSessionId':
        return record.currentSessionId;
      case 'currentSessionState':
        return record.currentSessionState;
      case 'currentSessionName':
        return record.currentSessionName;
      case 'numberOfOpenedSession':
        return record.numberOfOpenedSession;
      case 'lastSessionClosingDate':
        return record.lastSessionClosingDate;
      case 'lastSessionClosingCash':
        return record.lastSessionClosingCash;
      case 'currentSessionUserName':
        return record.currentSessionUserName;
      case 'currentSessionStateDisplay':
        return record.currentSessionStateDisplay;
      case 'numberOfRescueSession':
        return record.numberOfRescueSession;
      default:
        return null;
    }
  }

  @override
  CollectionConfig applyWebSocketChangesToRecord(
    CollectionConfig record,
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
      case 'code':
        return (obj as dynamic).code;
      case 'active':
        return (obj as dynamic).active;
      case 'companyId':
        return (obj as dynamic).companyId;
      case 'companyName':
        return (obj as dynamic).companyName;
      case 'journalId':
        return (obj as dynamic).journalId;
      case 'journalName':
        return (obj as dynamic).journalName;
      case 'cashJournalId':
        return (obj as dynamic).cashJournalId;
      case 'cashJournalName':
        return (obj as dynamic).cashJournalName;
      case 'allowedJournalIds':
        return (obj as dynamic).allowedJournalIds;
      case 'cashDifferenceAccountId':
        return (obj as dynamic).cashDifferenceAccountId;
      case 'currencyId':
        return (obj as dynamic).currencyId;
      case 'currencyName':
        return (obj as dynamic).currencyName;
      case 'setMaximumDifference':
        return (obj as dynamic).setMaximumDifference;
      case 'amountAuthorizedDiff':
        return (obj as dynamic).amountAuthorizedDiff;
      case 'userIds':
        return (obj as dynamic).userIds;
      case 'currentSessionId':
        return (obj as dynamic).currentSessionId;
      case 'currentSessionState':
        return (obj as dynamic).currentSessionState;
      case 'currentSessionName':
        return (obj as dynamic).currentSessionName;
      case 'numberOfOpenedSession':
        return (obj as dynamic).numberOfOpenedSession;
      case 'lastSessionClosingDate':
        return (obj as dynamic).lastSessionClosingDate;
      case 'lastSessionClosingCash':
        return (obj as dynamic).lastSessionClosingCash;
      case 'currentSessionUserName':
        return (obj as dynamic).currentSessionUserName;
      case 'currentSessionStateDisplay':
        return (obj as dynamic).currentSessionStateDisplay;
      case 'numberOfRescueSession':
        return (obj as dynamic).numberOfRescueSession;
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
    'code',
    'active',
    'companyId',
    'companyName',
    'journalId',
    'journalName',
    'cashJournalId',
    'cashJournalName',
    'allowedJournalIds',
    'cashDifferenceAccountId',
    'currencyId',
    'currencyName',
    'setMaximumDifference',
    'amountAuthorizedDiff',
    'userIds',
    'currentSessionId',
    'currentSessionState',
    'currentSessionName',
    'numberOfOpenedSession',
    'lastSessionClosingDate',
    'lastSessionClosingCash',
    'currentSessionUserName',
    'currentSessionStateDisplay',
    'numberOfRescueSession',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'code',
    'active',
    'companyId',
    'journalId',
    'cashJournalId',
    'allowedJournalIds',
    'cashDifferenceAccountId',
    'currencyId',
    'setMaximumDifference',
    'amountAuthorizedDiff',
    'userIds',
    'currentSessionId',
    'currentSessionState',
    'currentSessionName',
    'numberOfOpenedSession',
    'lastSessionClosingDate',
    'lastSessionClosingCash',
    'currentSessionUserName',
    'currentSessionStateDisplay',
    'numberOfRescueSession',
  ];
}

/// Global instance of CollectionConfigManager.
final collectionConfigManager = CollectionConfigManager();
