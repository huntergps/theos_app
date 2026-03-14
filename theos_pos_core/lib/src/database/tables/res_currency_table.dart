import 'package:drift/drift.dart';

/// ResCurrency - Monedas y su precisión
class ResCurrency extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get uuid => text().nullable()(); // UUID local para sync
  TextColumn get name => text()(); // 'USD'
  TextColumn get symbol => text()(); // '$'
  RealColumn get rounding => real()(); // 0.01
  IntColumn get decimalPlaces => integer()(); // 2
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get writeDate => dateTime().nullable()();
}