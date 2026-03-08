import 'package:drift/drift.dart';

/// QwebReportTemplate - Plantillas de reportes QWeb
class QwebReportTemplate extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get templateKey => text().unique()(); // Unique identifier for caching
  TextColumn get name => text()();
  TextColumn get model => text()(); // Model this report is for
  TextColumn get reportType => text()(); // pdf, html, text, etc.
  TextColumn get reportName => text()(); // Technical name
  TextColumn get attachment => text().nullable()(); // Attachment name pattern
  BoolColumn get attachmentUse => boolean().withDefault(const Constant(false))();
  TextColumn get paperformatId => text().nullable()();
  TextColumn get templateContent => text()(); // QWeb template XML/HTML (legacy)
  TextColumn get xmlContent => text().nullable()(); // QWeb template XML/HTML (new)
  TextColumn get requiredFields => text().nullable()(); // JSON array of required fields
  TextColumn get dependencies => text().nullable()(); // JSON array of template dependencies
  DateTimeColumn get lastSynced => dateTime().nullable()(); // Last sync timestamp
  TextColumn get checksum => text().nullable()(); // MD5/SHA checksum for change detection
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// QwebPaperFormat - Formatos de papel para reportes
class QwebPaperFormat extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  RealColumn get marginTop => real().withDefault(const Constant(0.0))();
  RealColumn get marginBottom => real().withDefault(const Constant(0.0))();
  RealColumn get marginLeft => real().withDefault(const Constant(0.0))();
  RealColumn get marginRight => real().withDefault(const Constant(0.0))();
  RealColumn get pageHeight => real().nullable()();
  RealColumn get pageWidth => real().nullable()();
  TextColumn get orientation => text().withDefault(const Constant('portrait'))(); // portrait, landscape
  TextColumn get format => text().nullable()(); // A4, A3, etc.
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}