// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for User.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: res.users
class UserManager extends OdooModelManager<User>
    with GenericDriftOperations<User> {
  @override
  String get odooModel => 'res.users';

  @override
  String get tableName => 'res_users';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'login',
    'email',
    'lang',
    'tz',
    'signature',
    'partner_id',
    'company_id',
    'property_warehouse_id',
    'avatar_128',
    'notification_type',
    'work_email',
    'work_phone',
    'mobile_phone',
    'write_date',
    'out_of_office_from',
    'out_of_office_to',
    'out_of_office_message',
    'calendar_default_privacy',
    'work_location_id',
    'resource_calendar_id',
    'pin',
    'private_street',
    'private_street2',
    'private_city',
    'private_zip',
    'private_state_id',
    'private_country_id',
    'private_email',
    'private_phone',
    'emergency_contact',
    'emergency_phone',
  ];

  @override
  User fromOdoo(Map<String, dynamic> data) {
    return User(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      login: parseOdooStringRequired(data['login']),
      email: parseOdooString(data['email']),
      lang: parseOdooString(data['lang']),
      tz: parseOdooString(data['tz']),
      signature: parseOdooString(data['signature']),
      partnerId: extractMany2oneId(data['partner_id']),
      partnerName: extractMany2oneName(data['partner_id']),
      companyId: extractMany2oneId(data['company_id']),
      companyName: extractMany2oneName(data['company_id']),
      warehouseId: extractMany2oneId(data['property_warehouse_id']),
      warehouseName: extractMany2oneName(data['property_warehouse_id']),
      avatar128: parseOdooString(data['avatar_128']),
      notificationType: parseOdooString(data['notification_type']),
      workEmail: parseOdooString(data['work_email']),
      workPhone: parseOdooString(data['work_phone']),
      mobilePhone: parseOdooString(data['mobile_phone']),
      groupIds: const [],
      permissions: const [],
      isCurrentUser: false,
      writeDate: parseOdooDateTime(data['write_date']),
      outOfOfficeFrom: parseOdooDateTime(data['out_of_office_from']),
      outOfOfficeTo: parseOdooDateTime(data['out_of_office_to']),
      outOfOfficeMessage: parseOdooString(data['out_of_office_message']),
      calendarDefaultPrivacy: parseOdooString(data['calendar_default_privacy']),
      workLocationId: extractMany2oneId(data['work_location_id']),
      workLocationName: extractMany2oneName(data['work_location_id']),
      resourceCalendarId: extractMany2oneId(data['resource_calendar_id']),
      resourceCalendarName: extractMany2oneName(data['resource_calendar_id']),
      pin: parseOdooString(data['pin']),
      privateStreet: parseOdooString(data['private_street']),
      privateStreet2: parseOdooString(data['private_street2']),
      privateCity: parseOdooString(data['private_city']),
      privateZip: parseOdooString(data['private_zip']),
      privateStateId: extractMany2oneId(data['private_state_id']),
      privateStateName: extractMany2oneName(data['private_state_id']),
      privateCountryId: extractMany2oneId(data['private_country_id']),
      privateCountryName: extractMany2oneName(data['private_country_id']),
      privateEmail: parseOdooString(data['private_email']),
      privatePhone: parseOdooString(data['private_phone']),
      emergencyContact: parseOdooString(data['emergency_contact']),
      emergencyPhone: parseOdooString(data['emergency_phone']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(User record) {
    return {
      'name': record.name,
      'login': record.login,
      'email': record.email,
      'lang': record.lang,
      'tz': record.tz,
      'signature': record.signature,
      'partner_id': record.partnerId,
      'company_id': record.companyId,
      'property_warehouse_id': record.warehouseId,
      'avatar_128': record.avatar128,
      'notification_type': record.notificationType,
      'work_email': record.workEmail,
      'work_phone': record.workPhone,
      'mobile_phone': record.mobilePhone,
      'write_date': formatOdooDateTime(record.writeDate),
      'out_of_office_from': formatOdooDateTime(record.outOfOfficeFrom),
      'out_of_office_to': formatOdooDateTime(record.outOfOfficeTo),
      'out_of_office_message': record.outOfOfficeMessage,
      'calendar_default_privacy': record.calendarDefaultPrivacy,
      'work_location_id': record.workLocationId,
      'resource_calendar_id': record.resourceCalendarId,
      'pin': record.pin,
      'private_street': record.privateStreet,
      'private_street2': record.privateStreet2,
      'private_city': record.privateCity,
      'private_zip': record.privateZip,
      'private_state_id': record.privateStateId,
      'private_country_id': record.privateCountryId,
      'private_email': record.privateEmail,
      'private_phone': record.privatePhone,
      'emergency_contact': record.emergencyContact,
      'emergency_phone': record.emergencyPhone,
    };
  }

  @override
  User fromDrift(dynamic row) {
    return User(
      id: row.odooId as int,
      name: row.name as String,
      login: row.login as String,
      email: row.email as String?,
      lang: row.lang as String?,
      tz: row.tz as String?,
      signature: row.signature as String?,
      partnerId: row.partnerId as int?,
      partnerName: row.partnerName as String?,
      companyId: row.companyId as int?,
      companyName: row.companyName as String?,
      warehouseId: row.warehouseId as int?,
      warehouseName: row.warehouseName as String?,
      avatar128: row.avatar128 as String?,
      notificationType: row.notificationType as String?,
      workEmail: row.workEmail as String?,
      workPhone: row.workPhone as String?,
      mobilePhone: row.mobilePhone as String?,
      isCurrentUser: row.isCurrentUser as bool? ?? false,
      writeDate: row.writeDate as DateTime?,
      outOfOfficeFrom: row.outOfOfficeFrom as DateTime?,
      outOfOfficeTo: row.outOfOfficeTo as DateTime?,
      outOfOfficeMessage: row.outOfOfficeMessage as String?,
      calendarDefaultPrivacy: row.calendarDefaultPrivacy as String?,
      workLocationId: row.workLocationId as int?,
      workLocationName: row.workLocationName as String?,
      resourceCalendarId: row.resourceCalendarId as int?,
      resourceCalendarName: row.resourceCalendarName as String?,
      pin: row.pin as String?,
      privateStreet: row.privateStreet as String?,
      privateStreet2: row.privateStreet2 as String?,
      privateCity: row.privateCity as String?,
      privateZip: row.privateZip as String?,
      privateStateId: row.privateStateId as int?,
      privateStateName: row.privateStateName as String?,
      privateCountryId: row.privateCountryId as int?,
      privateCountryName: row.privateCountryName as String?,
      privateEmail: row.privateEmail as String?,
      privatePhone: row.privatePhone as String?,
      emergencyContact: row.emergencyContact as String?,
      emergencyPhone: row.emergencyPhone as String?,
    );
  }

  @override
  int getId(User record) => record.id;

  @override
  String? getUuid(User record) => null;

  @override
  User withIdAndUuid(User record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  User withSyncStatus(User record, bool isSynced) {
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
    'login': 'login',
    'email': 'email',
    'lang': 'lang',
    'tz': 'tz',
    'signature': 'signature',
    'partner_id': 'partnerId',
    'company_id': 'companyId',
    'property_warehouse_id': 'warehouseId',
    'avatar_128': 'avatar128',
    'notification_type': 'notificationType',
    'work_email': 'workEmail',
    'work_phone': 'workPhone',
    'mobile_phone': 'mobilePhone',
    'write_date': 'writeDate',
    'out_of_office_from': 'outOfOfficeFrom',
    'out_of_office_to': 'outOfOfficeTo',
    'out_of_office_message': 'outOfOfficeMessage',
    'calendar_default_privacy': 'calendarDefaultPrivacy',
    'work_location_id': 'workLocationId',
    'resource_calendar_id': 'resourceCalendarId',
    'pin': 'pin',
    'private_street': 'privateStreet',
    'private_street2': 'privateStreet2',
    'private_city': 'privateCity',
    'private_zip': 'privateZip',
    'private_state_id': 'privateStateId',
    'private_country_id': 'privateCountryId',
    'private_email': 'privateEmail',
    'private_phone': 'privatePhone',
    'emergency_contact': 'emergencyContact',
    'emergency_phone': 'emergencyPhone',
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
      throw StateError('Table \'res_users\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(User record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'login': Variable<String>(record.login),
      'email': driftVar<String>(record.email),
      'lang': driftVar<String>(record.lang),
      'tz': driftVar<String>(record.tz),
      'signature': driftVar<String>(record.signature),
      'partner_id': driftVar<int>(record.partnerId),
      'partner_id_name': driftVar<String>(record.partnerName),
      'company_id': driftVar<int>(record.companyId),
      'company_id_name': driftVar<String>(record.companyName),
      'property_warehouse_id': driftVar<int>(record.warehouseId),
      'property_warehouse_id_name': driftVar<String>(record.warehouseName),
      'avatar_128': driftVar<String>(record.avatar128),
      'notification_type': driftVar<String>(record.notificationType),
      'work_email': driftVar<String>(record.workEmail),
      'work_phone': driftVar<String>(record.workPhone),
      'mobile_phone': driftVar<String>(record.mobilePhone),
      'write_date': driftVar<DateTime>(record.writeDate),
      'out_of_office_from': driftVar<DateTime>(record.outOfOfficeFrom),
      'out_of_office_to': driftVar<DateTime>(record.outOfOfficeTo),
      'out_of_office_message': driftVar<String>(record.outOfOfficeMessage),
      'calendar_default_privacy': driftVar<String>(
        record.calendarDefaultPrivacy,
      ),
      'work_location_id': driftVar<int>(record.workLocationId),
      'work_location_id_name': driftVar<String>(record.workLocationName),
      'resource_calendar_id': driftVar<int>(record.resourceCalendarId),
      'resource_calendar_id_name': driftVar<String>(
        record.resourceCalendarName,
      ),
      'pin': driftVar<String>(record.pin),
      'private_street': driftVar<String>(record.privateStreet),
      'private_street2': driftVar<String>(record.privateStreet2),
      'private_city': driftVar<String>(record.privateCity),
      'private_zip': driftVar<String>(record.privateZip),
      'private_state_id': driftVar<int>(record.privateStateId),
      'private_state_id_name': driftVar<String>(record.privateStateName),
      'private_country_id': driftVar<int>(record.privateCountryId),
      'private_country_id_name': driftVar<String>(record.privateCountryName),
      'private_email': driftVar<String>(record.privateEmail),
      'private_phone': driftVar<String>(record.privatePhone),
      'emergency_contact': driftVar<String>(record.emergencyContact),
      'emergency_phone': driftVar<String>(record.emergencyPhone),
      'is_current_user': Variable<bool>(record.isCurrentUser),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'login',
    'email',
    'lang',
    'tz',
    'signature',
    'partnerId',
    'companyId',
    'warehouseId',
    'avatar128',
    'notificationType',
    'workEmail',
    'workPhone',
    'mobilePhone',
    'writeDate',
    'outOfOfficeFrom',
    'outOfOfficeTo',
    'outOfOfficeMessage',
    'calendarDefaultPrivacy',
    'workLocationId',
    'resourceCalendarId',
    'pin',
    'privateStreet',
    'privateStreet2',
    'privateCity',
    'privateZip',
    'privateStateId',
    'privateCountryId',
    'privateEmail',
    'privatePhone',
    'emergencyContact',
    'emergencyPhone',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'login': 'Login',
    'email': 'Email',
    'lang': 'Lang',
    'tz': 'Tz',
    'signature': 'Signature',
    'partnerId': 'Partner Id',
    'partnerName': 'Partner Name',
    'companyId': 'Company Id',
    'companyName': 'Company Name',
    'warehouseId': 'Warehouse Id',
    'warehouseName': 'Warehouse Name',
    'avatar128': 'Avatar128',
    'notificationType': 'Notification Type',
    'workEmail': 'Work Email',
    'workPhone': 'Work Phone',
    'mobilePhone': 'Mobile Phone',
    'groupIds': 'Group Ids',
    'permissions': 'Permissions',
    'isCurrentUser': 'Is Current User',
    'writeDate': 'Write Date',
    'outOfOfficeFrom': 'Out Of Office From',
    'outOfOfficeTo': 'Out Of Office To',
    'outOfOfficeMessage': 'Out Of Office Message',
    'calendarDefaultPrivacy': 'Calendar Default Privacy',
    'workLocationId': 'Work Location Id',
    'workLocationName': 'Work Location Name',
    'resourceCalendarId': 'Resource Calendar Id',
    'resourceCalendarName': 'Resource Calendar Name',
    'pin': 'Pin',
    'privateStreet': 'Private Street',
    'privateStreet2': 'Private Street2',
    'privateCity': 'Private City',
    'privateZip': 'Private Zip',
    'privateStateId': 'Private State Id',
    'privateStateName': 'Private State Name',
    'privateCountryId': 'Private Country Id',
    'privateCountryName': 'Private Country Name',
    'privateEmail': 'Private Email',
    'privatePhone': 'Private Phone',
    'emergencyContact': 'Emergency Contact',
    'emergencyPhone': 'Emergency Phone',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(User record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(User record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(User record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(User record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'login':
        return record.login;
      case 'email':
        return record.email;
      case 'lang':
        return record.lang;
      case 'tz':
        return record.tz;
      case 'signature':
        return record.signature;
      case 'partnerId':
        return record.partnerId;
      case 'partnerName':
        return record.partnerName;
      case 'companyId':
        return record.companyId;
      case 'companyName':
        return record.companyName;
      case 'warehouseId':
        return record.warehouseId;
      case 'warehouseName':
        return record.warehouseName;
      case 'avatar128':
        return record.avatar128;
      case 'notificationType':
        return record.notificationType;
      case 'workEmail':
        return record.workEmail;
      case 'workPhone':
        return record.workPhone;
      case 'mobilePhone':
        return record.mobilePhone;
      case 'groupIds':
        return record.groupIds;
      case 'permissions':
        return record.permissions;
      case 'isCurrentUser':
        return record.isCurrentUser;
      case 'writeDate':
        return record.writeDate;
      case 'outOfOfficeFrom':
        return record.outOfOfficeFrom;
      case 'outOfOfficeTo':
        return record.outOfOfficeTo;
      case 'outOfOfficeMessage':
        return record.outOfOfficeMessage;
      case 'calendarDefaultPrivacy':
        return record.calendarDefaultPrivacy;
      case 'workLocationId':
        return record.workLocationId;
      case 'workLocationName':
        return record.workLocationName;
      case 'resourceCalendarId':
        return record.resourceCalendarId;
      case 'resourceCalendarName':
        return record.resourceCalendarName;
      case 'pin':
        return record.pin;
      case 'privateStreet':
        return record.privateStreet;
      case 'privateStreet2':
        return record.privateStreet2;
      case 'privateCity':
        return record.privateCity;
      case 'privateZip':
        return record.privateZip;
      case 'privateStateId':
        return record.privateStateId;
      case 'privateStateName':
        return record.privateStateName;
      case 'privateCountryId':
        return record.privateCountryId;
      case 'privateCountryName':
        return record.privateCountryName;
      case 'privateEmail':
        return record.privateEmail;
      case 'privatePhone':
        return record.privatePhone;
      case 'emergencyContact':
        return record.emergencyContact;
      case 'emergencyPhone':
        return record.emergencyPhone;
      default:
        return null;
    }
  }

  @override
  User applyWebSocketChangesToRecord(
    User record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      groupIds: record.groupIds,
      permissions: record.permissions,
      isCurrentUser: record.isCurrentUser,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'name':
        return (obj as dynamic).name;
      case 'login':
        return (obj as dynamic).login;
      case 'email':
        return (obj as dynamic).email;
      case 'lang':
        return (obj as dynamic).lang;
      case 'tz':
        return (obj as dynamic).tz;
      case 'signature':
        return (obj as dynamic).signature;
      case 'partnerId':
        return (obj as dynamic).partnerId;
      case 'partnerName':
        return (obj as dynamic).partnerName;
      case 'companyId':
        return (obj as dynamic).companyId;
      case 'companyName':
        return (obj as dynamic).companyName;
      case 'warehouseId':
        return (obj as dynamic).warehouseId;
      case 'warehouseName':
        return (obj as dynamic).warehouseName;
      case 'avatar128':
        return (obj as dynamic).avatar128;
      case 'notificationType':
        return (obj as dynamic).notificationType;
      case 'workEmail':
        return (obj as dynamic).workEmail;
      case 'workPhone':
        return (obj as dynamic).workPhone;
      case 'mobilePhone':
        return (obj as dynamic).mobilePhone;
      case 'groupIds':
        return (obj as dynamic).groupIds;
      case 'permissions':
        return (obj as dynamic).permissions;
      case 'isCurrentUser':
        return (obj as dynamic).isCurrentUser;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'outOfOfficeFrom':
        return (obj as dynamic).outOfOfficeFrom;
      case 'outOfOfficeTo':
        return (obj as dynamic).outOfOfficeTo;
      case 'outOfOfficeMessage':
        return (obj as dynamic).outOfOfficeMessage;
      case 'calendarDefaultPrivacy':
        return (obj as dynamic).calendarDefaultPrivacy;
      case 'workLocationId':
        return (obj as dynamic).workLocationId;
      case 'workLocationName':
        return (obj as dynamic).workLocationName;
      case 'resourceCalendarId':
        return (obj as dynamic).resourceCalendarId;
      case 'resourceCalendarName':
        return (obj as dynamic).resourceCalendarName;
      case 'pin':
        return (obj as dynamic).pin;
      case 'privateStreet':
        return (obj as dynamic).privateStreet;
      case 'privateStreet2':
        return (obj as dynamic).privateStreet2;
      case 'privateCity':
        return (obj as dynamic).privateCity;
      case 'privateZip':
        return (obj as dynamic).privateZip;
      case 'privateStateId':
        return (obj as dynamic).privateStateId;
      case 'privateStateName':
        return (obj as dynamic).privateStateName;
      case 'privateCountryId':
        return (obj as dynamic).privateCountryId;
      case 'privateCountryName':
        return (obj as dynamic).privateCountryName;
      case 'privateEmail':
        return (obj as dynamic).privateEmail;
      case 'privatePhone':
        return (obj as dynamic).privatePhone;
      case 'emergencyContact':
        return (obj as dynamic).emergencyContact;
      case 'emergencyPhone':
        return (obj as dynamic).emergencyPhone;
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
    'login',
    'email',
    'lang',
    'tz',
    'signature',
    'partnerId',
    'partnerName',
    'companyId',
    'companyName',
    'warehouseId',
    'warehouseName',
    'avatar128',
    'notificationType',
    'workEmail',
    'workPhone',
    'mobilePhone',
    'groupIds',
    'permissions',
    'isCurrentUser',
    'writeDate',
    'outOfOfficeFrom',
    'outOfOfficeTo',
    'outOfOfficeMessage',
    'calendarDefaultPrivacy',
    'workLocationId',
    'workLocationName',
    'resourceCalendarId',
    'resourceCalendarName',
    'pin',
    'privateStreet',
    'privateStreet2',
    'privateCity',
    'privateZip',
    'privateStateId',
    'privateStateName',
    'privateCountryId',
    'privateCountryName',
    'privateEmail',
    'privatePhone',
    'emergencyContact',
    'emergencyPhone',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'login',
    'email',
    'lang',
    'tz',
    'signature',
    'partnerId',
    'companyId',
    'warehouseId',
    'avatar128',
    'notificationType',
    'workEmail',
    'workPhone',
    'mobilePhone',
    'writeDate',
    'outOfOfficeFrom',
    'outOfOfficeTo',
    'outOfOfficeMessage',
    'calendarDefaultPrivacy',
    'workLocationId',
    'resourceCalendarId',
    'pin',
    'privateStreet',
    'privateStreet2',
    'privateCity',
    'privateZip',
    'privateStateId',
    'privateCountryId',
    'privateEmail',
    'privatePhone',
    'emergencyContact',
    'emergencyPhone',
  ];
}

/// Global instance of UserManager.
final userManager = UserManager();
