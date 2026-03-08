import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';

/// Datasource for Field Selection caching
///
/// Handles caching of Odoo Selection field options (e.g., timezones,
/// notification types, states, etc.) for offline access.
class FieldSelectionDatasource {
  final AppDatabase _db;

  FieldSelectionDatasource(this._db);

  // ============ Query Operations ============

  /// Get cached field selection for a model/field combination
  /// Returns null if not cached
  Future<List<dynamic>?> getFieldSelection(String model, String field) async {
    final result = await (_db.select(_db.fieldSelections)
          ..where((t) => t.model.equals(model) & t.field.equals(field)))
        .getSingleOrNull();

    if (result == null) return null;
    return json.decode(result.selections) as List<dynamic>;
  }

  /// Get all cached field selections
  Future<List<FieldSelection>> getAllFieldSelections() async {
    return _db.select(_db.fieldSelections).get();
  }

  /// Check if a field selection is cached
  Future<bool> hasFieldSelection(String model, String field) async {
    final result = await (_db.select(_db.fieldSelections)
          ..where((t) => t.model.equals(model) & t.field.equals(field)))
        .getSingleOrNull();
    return result != null;
  }

  /// Get all cached field selections for a model
  Future<List<Map<String, dynamic>>> getFieldSelectionsForModel(
    String model,
  ) async {
    final results = await (_db.select(_db.fieldSelections)
          ..where((t) => t.model.equals(model)))
        .get();

    return results
        .map((r) => {
              'model': r.model,
              'field': r.field,
              'selections': json.decode(r.selections),
            })
        .toList();
  }

  // ============ Write Operations ============

  /// Upsert a field selection cache entry
  Future<void> upsertFieldSelection(
    String model,
    String field,
    List<dynamic> selections,
  ) async {
    final selectionsJson = json.encode(selections);

    // Check if entry exists
    final existing = await (_db.select(_db.fieldSelections)
          ..where((t) => t.model.equals(model) & t.field.equals(field)))
        .getSingleOrNull();

    if (existing != null) {
      // Update existing
      await (_db.update(_db.fieldSelections)
            ..where((t) => t.id.equals(existing.id)))
          .write(FieldSelectionsCompanion(selections: Value(selectionsJson)));
    } else {
      // Insert new
      await _db.into(_db.fieldSelections).insert(
            FieldSelectionsCompanion.insert(
              model: model,
              field: field,
              selections: selectionsJson,
            ),
          );
    }
  }

  /// Delete a specific field selection cache entry
  Future<void> deleteFieldSelection(String model, String field) async {
    await (_db.delete(_db.fieldSelections)
          ..where((t) => t.model.equals(model) & t.field.equals(field)))
        .go();
  }

  /// Delete all field selections for a model
  Future<void> deleteFieldSelectionsForModel(String model) async {
    await (_db.delete(_db.fieldSelections)
          ..where((t) => t.model.equals(model)))
        .go();
  }

  /// Clear all field selection cache
  Future<void> clearAllFieldSelections() async {
    await _db.delete(_db.fieldSelections).go();
  }
}
