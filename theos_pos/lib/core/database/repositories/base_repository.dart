import 'package:odoo_sdk/odoo_sdk.dart' as core;
import '../database_helper.dart';

// Re-export mixins and extensions from odoo_offline_core package
// These are the ONLY definitions - no duplicates in this file
export 'package:odoo_sdk/odoo_sdk.dart'
    show
        OfflineSupport,
        SessionInfoCache,
        GenericSyncExtension,
        OfflineWriteExtension;

// ============================================================
// MIGRATION GUIDE: Converting to BaseRepository Pattern
// ============================================================
//
// To migrate a repository to use BaseRepository and its extensions:
//
// 1. Change class declaration:
//    BEFORE: class MyRepository { ... }
//    AFTER:  class MyRepository extends BaseRepository with OfflineSupport<DatabaseHelper> { ... }
//
// 2. Update constructor - OdooClient is OPTIONAL for offline-first:
//    BEFORE: MyRepository(this._db, this._client);
//    AFTER:  MyRepository({super.odooClient, required super.db});
//
// 3. Use extension methods instead of manual patterns:
//    BEFORE:
//      if (!forceRefresh) {
//        final cached = await _db.getItems();
//        if (cached.isNotEmpty) return cached;
//      }
//      final data = await _client.searchRead(...);
//      await _db.upsertItems(data.map(Item.fromOdoo).toList());
//
//    AFTER:
//      return fetchWithCache<Item>(
//        forceRefresh: forceRefresh,
//        getFromCache: () => _db.getItems(),
//        fetchFromRemote: () => odooClient!.searchRead(...),
//        parseItem: (data) => Item.fromOdoo(data),
//        saveToCache: (items) => _db.upsertItems(items),
//      );
//
// 4. Use offline write extensions for create/update:
//    BEFORE: Manual try/catch with queue fallback
//    AFTER:  await createWithOfflineFallback(...)
//
// 5. Check connectivity with isOnline before remote operations:
//    if (isOnline) {
//      // Remote operations
//    }
//
// Benefits:
// - Consistent offline-first patterns
// - OdooClient is optional - works fully offline
// - Automatic queue for offline operations
// - Less boilerplate code
// - Shared logic for sync, cache, and error handling
//

/// Base repository class providing common functionality for all repositories
///
/// Extends the core package BaseRepository but specifies DatabaseHelper as the
/// database type, allowing subclasses to access application-specific tables.
///
/// OdooClient is OPTIONAL - repositories work fully offline when null.
/// Use `isOnline` to check connectivity before remote operations.
///
/// All extension methods (fetchWithCache, createWithOfflineFallback, etc.)
/// are inherited from odoo_offline_core's BaseRepository extensions.
abstract class BaseRepository extends core.BaseRepository<DatabaseHelper> {
  BaseRepository({super.odooClient, required super.db});
}

// ============================================================
// OBSOLETE RECORDS CLEANUP
// ============================================================

/// Extension for cleaning up obsolete records during sync
///
/// When syncing from Odoo, records may have been deleted or replaced.
/// This extension provides a pattern for detecting and removing
/// obsolete local records that no longer exist in Odoo.
extension ObsoleteRecordCleanupExtension on BaseRepository {
  /// Clean up local records that no longer exist in Odoo
  ///
  /// Compares local IDs with the IDs returned from Odoo and
  /// deletes any local records that are no longer present in Odoo.
  ///
  /// Parameters:
  /// - [getLocalIds]: Function to get list of odoo_ids from local DB
  /// - [remoteIds]: List of IDs returned from Odoo (the current valid set)
  /// - [deleteLocal]: Function to delete a local record by its odoo_id
  /// - [modelName]: Name of the model for logging (e.g., 'account.move')
  ///
  /// Example usage:
  /// ```dart
  /// await cleanupObsoleteRecords(
  ///   getLocalIds: () => db.getInvoiceOdooIdsForOrder(orderId),
  ///   remoteIds: invoiceIdsFromOdoo,
  ///   deleteLocal: (id) => db.deleteInvoice(id),
  ///   modelName: 'account.move',
  /// );
  /// ```
  Future<int> cleanupObsoleteRecords({
    required Future<List<int>> Function() getLocalIds,
    required List<int> remoteIds,
    required Future<void> Function(int odooId) deleteLocal,
    String modelName = 'record',
  }) async {
    try {
      final localIds = await getLocalIds();
      if (localIds.isEmpty) return 0;

      // Find IDs that exist locally but not in Odoo
      final obsoleteIds = localIds.where((id) => !remoteIds.contains(id)).toList();
      if (obsoleteIds.isEmpty) return 0;

      // Delete obsolete records
      for (final id in obsoleteIds) {
        await deleteLocal(id);
      }

      return obsoleteIds.length;
    } catch (e) {
      // Don't fail the sync if cleanup fails - just log the error
      return 0;
    }
  }

  /// Clean up local child records when parent is synced
  ///
  /// Used for one-to-many relationships where child records
  /// should be deleted if they no longer exist in Odoo.
  ///
  /// Example: sale_order_line records for a sale_order
  /// When syncing a sale order, remove lines that were deleted in Odoo.
  Future<int> cleanupObsoleteChildRecords({
    required int parentId,
    required Future<List<int>> Function(int parentId) getLocalChildIds,
    required List<int> remoteChildIds,
    required Future<void> Function(int odooId) deleteLocalChild,
    String parentModelName = 'parent',
    String childModelName = 'child',
  }) async {
    try {
      final localChildIds = await getLocalChildIds(parentId);
      if (localChildIds.isEmpty) return 0;

      // Find child IDs that exist locally but not in Odoo
      final obsoleteIds = localChildIds
          .where((id) => !remoteChildIds.contains(id))
          .toList();
      if (obsoleteIds.isEmpty) return 0;

      // Delete obsolete child records
      for (final id in obsoleteIds) {
        await deleteLocalChild(id);
      }

      return obsoleteIds.length;
    } catch (e) {
      // Don't fail the sync if cleanup fails
      return 0;
    }
  }
}
