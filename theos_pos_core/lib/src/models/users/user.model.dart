import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'user.model.freezed.dart';
part 'user.model.g.dart';

/// User model representing res.users in Odoo
///
/// Uses @OdooModel annotation for code generation.
/// The generated UserManager provides CRUD, sync, and Drift operations.
@OdooModel('res.users', tableName: 'res_users')
@freezed
abstract class User with _$User {
  const User._();

  const factory User({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooString() required String login,
    @OdooString() String? email,
    @OdooString() String? lang,
    @OdooString() String? tz,
    @OdooString() String? signature,
    @OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,
    @OdooMany2OneName(sourceField: 'partner_id') String? partnerName,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,
    @OdooMany2One('stock.warehouse', odooName: 'property_warehouse_id') int? warehouseId,
    @OdooMany2OneName(sourceField: 'property_warehouse_id') String? warehouseName,
    @OdooString(odooName: 'avatar_128') String? avatar128,
    @OdooString(odooName: 'notification_type') String? notificationType,
    @OdooLocalOnly() String? workEmail,
    @OdooLocalOnly() String? workPhone,
    @OdooLocalOnly() String? mobilePhone,
    @OdooLocalOnly() @Default([]) List<int> groupIds,
    @OdooLocalOnly() @Default([]) List<String> permissions,
    @OdooLocalOnly() @Default(false) bool isCurrentUser,
    @OdooDateTime(odooName: 'write_date') DateTime? writeDate,

    // Out of Office (modulo mail)
    @OdooDateTime(odooName: 'out_of_office_from') DateTime? outOfOfficeFrom,
    @OdooDateTime(odooName: 'out_of_office_to') DateTime? outOfOfficeTo,
    @OdooString(odooName: 'out_of_office_message') String? outOfOfficeMessage,

    // Calendar preferences
    @OdooString(odooName: 'calendar_default_privacy') String? calendarDefaultPrivacy,

    // Work location (modulo hr)
    @OdooMany2One('hr.work.location', odooName: 'work_location_id') int? workLocationId,
    @OdooMany2OneName(sourceField: 'work_location_id') String? workLocationName,

    // Resource calendar / Work schedule
    @OdooMany2One('resource.calendar', odooName: 'resource_calendar_id') int? resourceCalendarId,
    @OdooMany2OneName(sourceField: 'resource_calendar_id') String? resourceCalendarName,

    // PIN for attendance (modulo hr)
    @OdooString() String? pin,

    // Private information (modulo hr)
    @OdooString(odooName: 'private_street') String? privateStreet,
    @OdooString(odooName: 'private_street2') String? privateStreet2,
    @OdooString(odooName: 'private_city') String? privateCity,
    @OdooString(odooName: 'private_zip') String? privateZip,
    @OdooMany2One('res.country.state', odooName: 'private_state_id') int? privateStateId,
    @OdooMany2OneName(sourceField: 'private_state_id') String? privateStateName,
    @OdooMany2One('res.country', odooName: 'private_country_id') int? privateCountryId,
    @OdooMany2OneName(sourceField: 'private_country_id') String? privateCountryName,
    @OdooString(odooName: 'private_email') String? privateEmail,
    @OdooString(odooName: 'private_phone') String? privatePhone,

    // Emergency contact (modulo hr)
    @OdooString(odooName: 'emergency_contact') String? emergencyContact,
    @OdooString(odooName: 'emergency_phone') String? emergencyPhone,
  }) = _User;

  // ============ Computed Fields (@api.depends equivalents) ============

  /// Display name (name or login if empty)
  String get displayName => name.isNotEmpty ? name : login;

  /// Check if user has avatar
  bool get hasAvatar => avatar128 != null && avatar128!.isNotEmpty;

  /// Get initials for avatar placeholder
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Get timezone display name
  String get timezoneDisplay => tz ?? 'UTC';

  /// Get language display name
  String get languageDisplay => lang ?? 'en_US';

  /// Check if user has a specific permission/group
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Check if user belongs to a group by ID
  bool hasGroupId(int groupId) => groupIds.contains(groupId);

  /// Check if user is a manager (has manager permission)
  bool get isManager =>
      hasPermission('sales.group_sale_manager') ||
      hasPermission('base.group_system');

  /// Check if user is a salesperson
  bool get isSalesperson =>
      hasPermission('sales.group_sale_salesman') ||
      hasPermission('sales.group_sale_salesman_all_leads');

  /// Check if user has full admin rights
  bool get isAdmin => hasPermission('base.group_system');

  /// Check if user can perform sales operations
  bool get canMakeSales => warehouseId != null && (isSalesperson || isManager);

  /// Check if user can approve discounts
  bool get canApproveDiscounts => isManager;

  /// Check if user can modify prices
  bool get canModifyPrices =>
      hasPermission('product.group_product_pricelist') || isManager;

  /// Get effective email (email or work_email)
  String get effectiveEmail => email ?? workEmail ?? '';

  /// Get effective phone (workPhone or mobilePhone)
  String get effectivePhone => workPhone ?? mobilePhone ?? '';
}
