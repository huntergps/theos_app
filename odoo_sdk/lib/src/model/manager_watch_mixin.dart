// Part of odoo_model_manager library
part of 'odoo_model_manager.dart';

/// Watch/stream methods mixin for OdooModelManager.
///
/// Uses Drift's native `.watch()` for true database-level reactivity.
/// Streams automatically re-emit whenever the underlying table changes —
/// regardless of who made the change (CRUD, sync, WebSocket, batch ops).
///
/// - [watch] / [watchMany] / [watchAll] for reactive record streams
/// - [observeRecord] / [observeAll] — aliases for consistency
mixin _ManagerWatchMixin<T> on _OdooModelManagerBase<T> {
  /// Watch a specific record by ID.
  ///
  /// Returns a stream that emits the current value immediately, then
  /// re-emits whenever the record changes in the database.
  /// Emits null if the record doesn't exist or is deleted.
  ///
  /// ```dart
  /// final orderStream = manager.watch(orderId);
  /// orderStream.listen((order) => print('Order updated: ${order?.name}'));
  /// ```
  Stream<T?> watch(int id) => watchLocalRecord(id);

  /// Watch multiple records by IDs.
  ///
  /// Returns a stream that emits the matching records whenever
  /// any of them changes in the database.
  Stream<List<T>> watchMany(List<int> ids) {
    return watchLocalSearch(domain: [
      ['id', 'in', ids],
    ]);
  }

  /// Watch all records matching a domain.
  ///
  /// Returns a stream that re-emits whenever the table changes.
  Stream<List<T>> watchAll({List<dynamic>? domain, int? limit}) {
    return watchLocalSearch(domain: domain, limit: limit);
  }

  /// Stream of a single record that updates when it changes.
  ///
  /// Alias for [watch] — both use Drift's native reactivity.
  Stream<T?> observeRecord(int id) => watchLocalRecord(id);

  /// Stream of all records that updates when any record changes.
  ///
  /// Alias for [watchAll] — both use Drift's native reactivity.
  Stream<List<T>> observeAll({List<dynamic>? domain, int? limit}) {
    return watchLocalSearch(domain: domain, limit: limit);
  }
}
