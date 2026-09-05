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
  IntColumn get propertyWarehouseId => integer().nullable()();
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

  // HR attendance PIN, private address and emergency-contact fields are not
  // part of this POS domain. They are deliberately not cached at rest.
}
