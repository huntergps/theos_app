// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_session_cash.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CollectionSessionCash _$CollectionSessionCashFromJson(
  Map<String, dynamic> json,
) => _CollectionSessionCash(
  id: (json['id'] as num?)?.toInt() ?? 0,
  isSynced: json['isSynced'] as bool? ?? false,
  lastSyncDate: json['lastSyncDate'] == null
      ? null
      : DateTime.parse(json['lastSyncDate'] as String),
  collectionSessionId: (json['collectionSessionId'] as num?)?.toInt(),
  cashType:
      $enumDecodeNullable(_$CashTypeEnumMap, json['cashType']) ??
      CashType.opening,
  bills100: (json['bills100'] as num?)?.toInt() ?? 0,
  bills50: (json['bills50'] as num?)?.toInt() ?? 0,
  bills20: (json['bills20'] as num?)?.toInt() ?? 0,
  bills10: (json['bills10'] as num?)?.toInt() ?? 0,
  bills5: (json['bills5'] as num?)?.toInt() ?? 0,
  bills1: (json['bills1'] as num?)?.toInt() ?? 0,
  coins1: (json['coins1'] as num?)?.toInt() ?? 0,
  coins50: (json['coins50'] as num?)?.toInt() ?? 0,
  coins25: (json['coins25'] as num?)?.toInt() ?? 0,
  coins10: (json['coins10'] as num?)?.toInt() ?? 0,
  coins5: (json['coins5'] as num?)?.toInt() ?? 0,
  coins1Cent: (json['coins1Cent'] as num?)?.toInt() ?? 0,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$CollectionSessionCashToJson(
  _CollectionSessionCash instance,
) => <String, dynamic>{
  'id': instance.id,
  'isSynced': instance.isSynced,
  'lastSyncDate': instance.lastSyncDate?.toIso8601String(),
  'collectionSessionId': instance.collectionSessionId,
  'cashType': _$CashTypeEnumMap[instance.cashType]!,
  'bills100': instance.bills100,
  'bills50': instance.bills50,
  'bills20': instance.bills20,
  'bills10': instance.bills10,
  'bills5': instance.bills5,
  'bills1': instance.bills1,
  'coins1': instance.coins1,
  'coins50': instance.coins50,
  'coins25': instance.coins25,
  'coins10': instance.coins10,
  'coins5': instance.coins5,
  'coins1Cent': instance.coins1Cent,
  'notes': instance.notes,
};

const _$CashTypeEnumMap = {
  CashType.opening: 'opening',
  CashType.closing: 'closing',
};

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for CollectionSessionCash.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: collection.session.cash
class CollectionSessionCashManager
    extends OdooModelManager<CollectionSessionCash>
    with GenericDriftOperations<CollectionSessionCash> {
  @override
  String get odooModel => 'collection.session.cash';

  @override
  String get tableName => 'collection_session_cash';

  @override
  List<String> get odooFields => [
    'id',
    'collection_session_id',
    'cash_type',
    'bills_100',
    'bills_50',
    'bills_20',
    'bills_10',
    'bills_5',
    'bills_1',
    'coins_1',
    'coins_50',
    'coins_25',
    'coins_10',
    'coins_5',
    'coins_1_cent',
    'notes',
  ];

  @override
  CollectionSessionCash fromOdoo(Map<String, dynamic> data) {
    return CollectionSessionCash(
      id: data['id'] as int? ?? 0,
      isSynced: false,
      collectionSessionId: extractMany2oneId(data['collection_session_id']),
      cashType: CashType.values.firstWhere(
        (e) => e.name == parseOdooSelection(data['cash_type']),
        orElse: () => CashType.values.first,
      ),
      bills100: parseOdooInt(data['bills_100']) ?? 0,
      bills50: parseOdooInt(data['bills_50']) ?? 0,
      bills20: parseOdooInt(data['bills_20']) ?? 0,
      bills10: parseOdooInt(data['bills_10']) ?? 0,
      bills5: parseOdooInt(data['bills_5']) ?? 0,
      bills1: parseOdooInt(data['bills_1']) ?? 0,
      coins1: parseOdooInt(data['coins_1']) ?? 0,
      coins50: parseOdooInt(data['coins_50']) ?? 0,
      coins25: parseOdooInt(data['coins_25']) ?? 0,
      coins10: parseOdooInt(data['coins_10']) ?? 0,
      coins5: parseOdooInt(data['coins_5']) ?? 0,
      coins1Cent: parseOdooInt(data['coins_1_cent']) ?? 0,
      notes: parseOdooString(data['notes']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(CollectionSessionCash record) {
    return {
      'collection_session_id': record.collectionSessionId,
      'cash_type': record.cashType.name,
      'bills_100': record.bills100,
      'bills_50': record.bills50,
      'bills_20': record.bills20,
      'bills_10': record.bills10,
      'bills_5': record.bills5,
      'bills_1': record.bills1,
      'coins_1': record.coins1,
      'coins_50': record.coins50,
      'coins_25': record.coins25,
      'coins_10': record.coins10,
      'coins_5': record.coins5,
      'coins_1_cent': record.coins1Cent,
      'notes': record.notes,
    };
  }

  @override
  CollectionSessionCash fromDrift(dynamic row) {
    return CollectionSessionCash(
      id: row.odooId as int,
      isSynced: row.isSynced as bool? ?? false,
      lastSyncDate: row.lastSyncDate as DateTime?,
      collectionSessionId: row.collectionSessionId as int?,
      cashType: CashType.values.firstWhere(
        (e) => e.name == (row.cashType as String?),
        orElse: () => CashType.values.first,
      ),
      bills100: row.bills100 as int,
      bills50: row.bills50 as int,
      bills20: row.bills20 as int,
      bills10: row.bills10 as int,
      bills5: row.bills5 as int,
      bills1: row.bills1 as int,
      coins1: row.coins1 as int,
      coins50: row.coins50 as int,
      coins25: row.coins25 as int,
      coins10: row.coins10 as int,
      coins5: row.coins5 as int,
      coins1Cent: row.coins1Cent as int,
      notes: row.notes as String?,
    );
  }

  @override
  int getId(CollectionSessionCash record) => record.id;

  @override
  String? getUuid(CollectionSessionCash record) => null;

  @override
  CollectionSessionCash withIdAndUuid(
    CollectionSessionCash record,
    int id,
    String uuid,
  ) {
    return record.copyWith(id: id);
  }

  @override
  CollectionSessionCash withSyncStatus(
    CollectionSessionCash record,
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
    'collection_session_id': 'collectionSessionId',
    'cash_type': 'cashType',
    'bills_100': 'bills100',
    'bills_50': 'bills50',
    'bills_20': 'bills20',
    'bills_10': 'bills10',
    'bills_5': 'bills5',
    'bills_1': 'bills1',
    'coins_1': 'coins1',
    'coins_50': 'coins50',
    'coins_25': 'coins25',
    'coins_10': 'coins10',
    'coins_5': 'coins5',
    'coins_1_cent': 'coins1Cent',
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
        'Table \'collection_session_cash\' not found in database.',
      );
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(CollectionSessionCash record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'collection_session_id': driftVar<int>(record.collectionSessionId),
      'cash_type': Variable<String>(record.cashType.name),
      'bills_100': Variable<int>(record.bills100),
      'bills_50': Variable<int>(record.bills50),
      'bills_20': Variable<int>(record.bills20),
      'bills_10': Variable<int>(record.bills10),
      'bills_5': Variable<int>(record.bills5),
      'bills_1': Variable<int>(record.bills1),
      'coins_1': Variable<int>(record.coins1),
      'coins_50': Variable<int>(record.coins50),
      'coins_25': Variable<int>(record.coins25),
      'coins_10': Variable<int>(record.coins10),
      'coins_5': Variable<int>(record.coins5),
      'coins_1_cent': Variable<int>(record.coins1Cent),
      'notes': driftVar<String>(record.notes),
      'is_synced': Variable<bool>(record.isSynced),
      'last_sync_date': driftVar<DateTime>(record.lastSyncDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'collectionSessionId',
    'cashType',
    'bills100',
    'bills50',
    'bills20',
    'bills10',
    'bills5',
    'bills1',
    'coins1',
    'coins50',
    'coins25',
    'coins10',
    'coins5',
    'coins1Cent',
    'notes',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'isSynced': 'Is Synced',
    'lastSyncDate': 'Last Sync Date',
    'collectionSessionId': 'Collection Session Id',
    'cashType': 'Cash Type',
    'bills100': 'Bills100',
    'bills50': 'Bills50',
    'bills20': 'Bills20',
    'bills10': 'Bills10',
    'bills5': 'Bills5',
    'bills1': 'Bills1',
    'coins1': 'Coins1',
    'coins50': 'Coins50',
    'coins25': 'Coins25',
    'coins10': 'Coins10',
    'coins5': 'Coins5',
    'coins1Cent': 'Coins1 Cent',
    'notes': 'Notes',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(CollectionSessionCash record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(CollectionSessionCash record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(CollectionSessionCash record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(CollectionSessionCash record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'isSynced':
        return record.isSynced;
      case 'lastSyncDate':
        return record.lastSyncDate;
      case 'collectionSessionId':
        return record.collectionSessionId;
      case 'cashType':
        return record.cashType;
      case 'bills100':
        return record.bills100;
      case 'bills50':
        return record.bills50;
      case 'bills20':
        return record.bills20;
      case 'bills10':
        return record.bills10;
      case 'bills5':
        return record.bills5;
      case 'bills1':
        return record.bills1;
      case 'coins1':
        return record.coins1;
      case 'coins50':
        return record.coins50;
      case 'coins25':
        return record.coins25;
      case 'coins10':
        return record.coins10;
      case 'coins5':
        return record.coins5;
      case 'coins1Cent':
        return record.coins1Cent;
      case 'notes':
        return record.notes;
      default:
        return null;
    }
  }

  @override
  CollectionSessionCash applyWebSocketChangesToRecord(
    CollectionSessionCash record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
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
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'lastSyncDate':
        return (obj as dynamic).lastSyncDate;
      case 'collectionSessionId':
        return (obj as dynamic).collectionSessionId;
      case 'cashType':
        return (obj as dynamic).cashType;
      case 'bills100':
        return (obj as dynamic).bills100;
      case 'bills50':
        return (obj as dynamic).bills50;
      case 'bills20':
        return (obj as dynamic).bills20;
      case 'bills10':
        return (obj as dynamic).bills10;
      case 'bills5':
        return (obj as dynamic).bills5;
      case 'bills1':
        return (obj as dynamic).bills1;
      case 'coins1':
        return (obj as dynamic).coins1;
      case 'coins50':
        return (obj as dynamic).coins50;
      case 'coins25':
        return (obj as dynamic).coins25;
      case 'coins10':
        return (obj as dynamic).coins10;
      case 'coins5':
        return (obj as dynamic).coins5;
      case 'coins1Cent':
        return (obj as dynamic).coins1Cent;
      case 'notes':
        return (obj as dynamic).notes;
      case 'writeDate':
        return (obj as dynamic).writeDate;
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
    'isSynced',
    'lastSyncDate',
    'collectionSessionId',
    'cashType',
    'bills100',
    'bills50',
    'bills20',
    'bills10',
    'bills5',
    'bills1',
    'coins1',
    'coins50',
    'coins25',
    'coins10',
    'coins5',
    'coins1Cent',
    'notes',
  ];

  @override
  List<String> get writableFieldNames => const [
    'collectionSessionId',
    'cashType',
    'bills100',
    'bills50',
    'bills20',
    'bills10',
    'bills5',
    'bills1',
    'coins1',
    'coins50',
    'coins25',
    'coins10',
    'coins5',
    'coins1Cent',
    'notes',
  ];
}

/// Global instance of CollectionSessionCashManager.
final collectionSessionCashManager = CollectionSessionCashManager();
