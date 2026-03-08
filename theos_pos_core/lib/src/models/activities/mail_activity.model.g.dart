// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mail_activity.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MailActivity _$MailActivityFromJson(Map<String, dynamic> json) =>
    _MailActivity(
      id: (json['id'] as num).toInt(),
      resId: (json['resId'] as num).toInt(),
      resModel: json['resModel'] as String,
      resName: json['resName'] as String?,
      summary: json['summary'] as String?,
      note: json['note'] as String?,
      activityTypeId: (json['activityTypeId'] as num?)?.toInt(),
      activityTypeName: json['activityTypeName'] as String?,
      userId: (json['userId'] as num?)?.toInt(),
      userName: json['userName'] as String?,
      dateDeadline: DateTime.parse(json['dateDeadline'] as String),
      state: json['state'] as String,
      icon: json['icon'] as String?,
      canWrite: json['canWrite'] as bool? ?? true,
      createDate: json['createDate'] == null
          ? null
          : DateTime.parse(json['createDate'] as String),
      writeDate: json['writeDate'] == null
          ? null
          : DateTime.parse(json['writeDate'] as String),
    );

Map<String, dynamic> _$MailActivityToJson(_MailActivity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'resId': instance.resId,
      'resModel': instance.resModel,
      'resName': instance.resName,
      'summary': instance.summary,
      'note': instance.note,
      'activityTypeId': instance.activityTypeId,
      'activityTypeName': instance.activityTypeName,
      'userId': instance.userId,
      'userName': instance.userName,
      'dateDeadline': instance.dateDeadline.toIso8601String(),
      'state': instance.state,
      'icon': instance.icon,
      'canWrite': instance.canWrite,
      'createDate': instance.createDate?.toIso8601String(),
      'writeDate': instance.writeDate?.toIso8601String(),
    };

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for MailActivity.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: mail.activity
class MailActivityManager extends OdooModelManager<MailActivity>
    with GenericDriftOperations<MailActivity> {
  @override
  String get odooModel => 'mail.activity';

  @override
  String get tableName => 'mail_activity_table';

  @override
  List<String> get odooFields => [
    'id',
    'res_id',
    'res_model',
    'res_name',
    'summary',
    'note',
    'activity_type_id',
    'user_id',
    'date_deadline',
    'state',
    'icon',
    'can_write',
    'create_date',
    'write_date',
  ];

  @override
  MailActivity fromOdoo(Map<String, dynamic> data) {
    return MailActivity(
      id: data['id'] as int? ?? 0,
      resId: parseOdooInt(data['res_id']) ?? 0,
      resModel: parseOdooStringRequired(data['res_model']),
      resName: parseOdooString(data['res_name']),
      summary: parseOdooString(data['summary']),
      note: parseOdooString(data['note']),
      activityTypeId: extractMany2oneId(data['activity_type_id']),
      activityTypeName: extractMany2oneName(data['activity_type_id']),
      userId: extractMany2oneId(data['user_id']),
      userName: extractMany2oneName(data['user_id']),
      dateDeadline: parseOdooDate(data['date_deadline']) ?? DateTime(1970),
      state: parseOdooStringRequired(data['state']),
      icon: parseOdooString(data['icon']),
      canWrite: parseOdooBool(data['can_write']),
      createDate: parseOdooDateTime(data['create_date']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(MailActivity record) {
    return {
      'res_id': record.resId,
      'res_model': record.resModel,
      'res_name': record.resName,
      'summary': record.summary,
      'note': record.note,
      'activity_type_id': record.activityTypeId,
      'user_id': record.userId,
      'date_deadline': formatOdooDate(record.dateDeadline),
      'state': record.state,
      'icon': record.icon,
      'can_write': record.canWrite,
    };
  }

  @override
  MailActivity fromDrift(dynamic row) {
    return MailActivity(
      id: row.odooId as int,
      resId: row.resId as int,
      resModel: row.resModel as String,
      resName: row.resName as String?,
      summary: row.summary as String?,
      note: row.note as String?,
      activityTypeId: row.activityTypeId as int?,
      activityTypeName: row.activityTypeName as String?,
      userId: row.userId as int?,
      userName: row.userName as String?,
      dateDeadline: row.dateDeadline as DateTime,
      state: row.state as String,
      icon: row.icon as String?,
      canWrite: row.canWrite as bool,
      createDate: row.createDate as DateTime?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(MailActivity record) => record.id;

  @override
  String? getUuid(MailActivity record) => null;

  @override
  MailActivity withIdAndUuid(MailActivity record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  MailActivity withSyncStatus(MailActivity record, bool isSynced) {
    return record; // No sync status field
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'res_id': 'resId',
    'res_model': 'resModel',
    'res_name': 'resName',
    'summary': 'summary',
    'note': 'note',
    'activity_type_id': 'activityTypeId',
    'user_id': 'userId',
    'date_deadline': 'dateDeadline',
    'state': 'state',
    'icon': 'icon',
    'can_write': 'canWrite',
    'create_date': 'createDate',
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
      throw StateError('Table \'mail_activity_table\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(MailActivity record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'res_id': Variable<int>(record.resId),
      'res_model': Variable<String>(record.resModel),
      'res_name': driftVar<String>(record.resName),
      'summary': driftVar<String>(record.summary),
      'note': driftVar<String>(record.note),
      'activity_type_id': driftVar<int>(record.activityTypeId),
      'activity_type_id_name': driftVar<String>(record.activityTypeName),
      'user_id': driftVar<int>(record.userId),
      'user_id_name': driftVar<String>(record.userName),
      'date_deadline': Variable<DateTime>(record.dateDeadline),
      'state': Variable<String>(record.state),
      'icon': driftVar<String>(record.icon),
      'can_write': Variable<bool>(record.canWrite),
      'create_date': driftVar<DateTime>(record.createDate),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'resId',
    'resModel',
    'resName',
    'summary',
    'note',
    'activityTypeId',
    'userId',
    'dateDeadline',
    'state',
    'icon',
    'canWrite',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'resId': 'Res Id',
    'resModel': 'Res Model',
    'resName': 'Res Name',
    'summary': 'Summary',
    'note': 'Note',
    'activityTypeId': 'Activity Type Id',
    'activityTypeName': 'Activity Type Name',
    'userId': 'User Id',
    'userName': 'User Name',
    'dateDeadline': 'Date Deadline',
    'state': 'State',
    'icon': 'Icon',
    'canWrite': 'Can Write',
    'createDate': 'Create Date',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(MailActivity record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(MailActivity record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(MailActivity record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(MailActivity record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'resId':
        return record.resId;
      case 'resModel':
        return record.resModel;
      case 'resName':
        return record.resName;
      case 'summary':
        return record.summary;
      case 'note':
        return record.note;
      case 'activityTypeId':
        return record.activityTypeId;
      case 'activityTypeName':
        return record.activityTypeName;
      case 'userId':
        return record.userId;
      case 'userName':
        return record.userName;
      case 'dateDeadline':
        return record.dateDeadline;
      case 'state':
        return record.state;
      case 'icon':
        return record.icon;
      case 'canWrite':
        return record.canWrite;
      case 'createDate':
        return record.createDate;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  MailActivity applyWebSocketChangesToRecord(
    MailActivity record,
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
      case 'resId':
        return (obj as dynamic).resId;
      case 'resModel':
        return (obj as dynamic).resModel;
      case 'resName':
        return (obj as dynamic).resName;
      case 'summary':
        return (obj as dynamic).summary;
      case 'note':
        return (obj as dynamic).note;
      case 'activityTypeId':
        return (obj as dynamic).activityTypeId;
      case 'activityTypeName':
        return (obj as dynamic).activityTypeName;
      case 'userId':
        return (obj as dynamic).userId;
      case 'userName':
        return (obj as dynamic).userName;
      case 'dateDeadline':
        return (obj as dynamic).dateDeadline;
      case 'state':
        return (obj as dynamic).state;
      case 'icon':
        return (obj as dynamic).icon;
      case 'canWrite':
        return (obj as dynamic).canWrite;
      case 'createDate':
        return (obj as dynamic).createDate;
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
    'resId',
    'resModel',
    'resName',
    'summary',
    'note',
    'activityTypeId',
    'activityTypeName',
    'userId',
    'userName',
    'dateDeadline',
    'state',
    'icon',
    'canWrite',
    'createDate',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'resId',
    'resModel',
    'resName',
    'summary',
    'note',
    'activityTypeId',
    'userId',
    'dateDeadline',
    'state',
    'icon',
    'canWrite',
  ];
}

/// Global instance of MailActivityManager.
final mailActivityManager = MailActivityManager();
