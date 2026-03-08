import 'package:drift/drift.dart';

/// ResCountry - Países para direcciones y localización
class ResCountry extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// ResCountryState - Estados/provincias de países
class ResCountryState extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  IntColumn get countryId => integer().nullable()();
  TextColumn get countryName => text().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// ResLang - Idiomas disponibles en el sistema
class ResLang extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get translatable => boolean().withDefault(const Constant(false))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}

/// ResourceCalendar - Calendarios de trabajo
class ResourceCalendar extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  DateTimeColumn get writeDate => dateTime().nullable()();
}