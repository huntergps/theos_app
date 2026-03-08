import 'package:drift/drift.dart';

/// ResGroups - Grupos de usuarios y permisos
class ResGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get fullName => text().nullable()();
  TextColumn get xmlId =>
      text().nullable()(); // External ID (e.g., 'base.group_user')
  IntColumn get categoryId => integer().nullable()();
  TextColumn get categoryName => text().nullable()();
  TextColumn get comment => text().nullable()();
  TextColumn get impliedIds =>
      text().nullable()(); // JSON array of implied group IDs
  BoolColumn get share =>
      boolean().withDefault(const Constant(false))(); // Portal/public group
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// MailActivityTable - Actividades de correo y seguimiento
class MailActivityTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  IntColumn get resId => integer()();
  TextColumn get resModel => text()();
  TextColumn get resName => text().nullable()();
  TextColumn get summary => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get activityTypeId => integer().nullable()();
  TextColumn get activityTypeName => text().nullable()();
  IntColumn get userId => integer().nullable()();
  TextColumn get userName => text().nullable()();
  DateTimeColumn get dateDeadline => dateTime()();
  TextColumn get state => text().withDefault(const Constant('planned'))(); // planned, today, overdue, done, cancelled
  TextColumn get icon => text().nullable()();
  BoolColumn get canWrite => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createDate => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// DecimalPrecision - Precisiones configuradas en Odoo
class DecimalPrecision extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()(); // 'Product Price', 'Discount', etc.
  IntColumn get digits => integer()(); // Número de decimales
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// OfflineInvoice - Facturas generadas offline esperando sincronización
class OfflineInvoice extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get orderId => integer()();
  TextColumn get orderName => text().nullable()();
  TextColumn get invoiceName => text().nullable()();
  TextColumn get accessKey => text().nullable()();
  IntColumn get sequenceNumber => integer().nullable()();
  TextColumn get documentType => text().nullable()(); // '01' = factura
  DateTimeColumn get invoiceDate => dateTime().nullable()();
  IntColumn get partnerId => integer().nullable()();
  RealColumn get amountTotal => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get invoiceType => text()(); // 'out_invoice', 'out_refund'
  TextColumn get invoiceData => text()(); // JSON invoice data
  TextColumn get state => text().withDefault(const Constant('draft'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}