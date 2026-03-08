import 'package:drift/drift.dart';

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class FieldSelections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get model => text()();
  TextColumn get field => text()();
  TextColumn get selections => text()(); // JSON string
}

/// Cache genérico para registros relacionados de cualquier modelo Odoo
/// Almacena [id, name] para campos Many2one que no tienen tabla específica
class RelatedRecordCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get model => text()(); // e.g., 'hr.employee', 'stock.location'
  IntColumn get odooId => integer()(); // ID en Odoo
  TextColumn get name => text()(); // display_name del registro
  TextColumn get data => text().nullable()(); // JSON con campos adicionales
  DateTimeColumn get cachedAt => dateTime()(); // Fecha de caché
  DateTimeColumn get writeDate => dateTime().nullable()(); // write_date de Odoo

  @override
  List<Set<Column>> get uniqueKeys => [
    {model, odooId},
  ];
}
