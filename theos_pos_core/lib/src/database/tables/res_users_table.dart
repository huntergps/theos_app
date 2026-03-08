import 'package:drift/drift.dart';

/// ResUsers table definition - User/Employee data
///
/// This table stores all user information synced from Odoo.
/// Used by UserManager and related services.
class ResUsers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get login => text()();
  TextColumn get email => text().nullable()();
  TextColumn get lang => text().nullable()();
  TextColumn get tz => text().nullable()();
  TextColumn get signature => text().nullable()();
  IntColumn get partnerId => integer().nullable()();
  TextColumn get partnerName => text().nullable()();
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  IntColumn get warehouseId => integer().nullable()();
  TextColumn get warehouseName => text().nullable()();
  TextColumn get avatar128 => text().nullable()();
  TextColumn get notificationType => text().nullable()();
  TextColumn get workEmail => text().nullable()();
  TextColumn get workPhone => text().nullable()();
  TextColumn get mobilePhone => text().nullable()();
  TextColumn get groupIds => text().nullable()(); // JSON array as string
  TextColumn get permissions => text().nullable()(); // JSON object as string
  BoolColumn get isCurrentUser => boolean().withDefault(const Constant(false))();
  DateTimeColumn get writeDate => dateTime().nullable()();

  // Out of Office (módulo mail)
  DateTimeColumn get outOfOfficeFrom => dateTime().nullable()();
  DateTimeColumn get outOfOfficeTo => dateTime().nullable()();
  TextColumn get outOfOfficeMessage => text().nullable()();

  // Calendar preferences
  TextColumn get calendarDefaultPrivacy => text().nullable()(); // public, private, confidential

  // Work location (módulo hr)
  IntColumn get workLocationId => integer().nullable()();
  TextColumn get workLocationName => text().nullable()();

  // Resource calendar / Work schedule (módulo hr)
  IntColumn get resourceCalendarId => integer().nullable()();
  TextColumn get resourceCalendarName => text().nullable()();

  // PIN for attendance (módulo hr)
  TextColumn get pin => text().nullable()();

  // Private information (módulo hr) - stored on user, not partner
  TextColumn get privateStreet => text().nullable()();
  TextColumn get privateStreet2 => text().nullable()();
  TextColumn get privateCity => text().nullable()();
  TextColumn get privateZip => text().nullable()();
  IntColumn get privateStateId => integer().nullable()();
  TextColumn get privateStateName => text().nullable()();
  IntColumn get privateCountryId => integer().nullable()();
  TextColumn get privateCountryName => text().nullable()();
  TextColumn get privateEmail => text().nullable()();
  TextColumn get privatePhone => text().nullable()();

  // Emergency contact (módulo hr)
  TextColumn get emergencyContact => text().nullable()();
  TextColumn get emergencyPhone => text().nullable()();
}
