/// CollectionConfigManager extensions - Business methods beyond generated CRUD
///
/// The base CollectionConfigManager is generated in collection_config.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/collection/collection_config.model.dart';

/// Extension methods for CollectionConfigManager
extension CollectionConfigManagerBusiness on CollectionConfigManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  /// Get collection config by Odoo ID (alias for readLocal)
  Future<CollectionConfig?> getById(int odooId) => readLocal(odooId);

  /// Get all active collection configs
  Future<List<CollectionConfig>> getAll() async {
    final results = await (_db.select(_db.collectionConfig)
          ..where((t) => t.active.equals(true))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
        .get();

    return results.map((r) => fromDrift(r)).toList();
  }
}
