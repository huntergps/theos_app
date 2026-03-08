// Part of odoo_model_manager library
part of 'odoo_model_manager.dart';

/// Odoo action calls mixin for OdooModelManager.
///
/// Provides methods for calling Odoo workflow actions:
/// - [callOdooAction] for single-record actions (e.g., action_confirm)
/// - [callOdooActionMulti] for multi-record actions
mixin _ManagerActionsMixin<T> on _OdooModelManagerBase<T> {
  /// Call an Odoo action method on a record.
  ///
  /// Used for workflow methods like action_confirm, action_cancel, etc.
  ///
  /// ```dart
  /// await manager.callOdooAction(orderId, 'action_confirm');
  /// ```
  Future<dynamic> callOdooAction(
    int recordId,
    String action, {
    Map<String, dynamic>? kwargs,
  }) async {
    if (!isOnline) {
      throw StateError('Cannot call Odoo action while offline');
    }

    if (recordId <= 0) {
      throw ArgumentError('Cannot call action on local-only record');
    }

    try {
      final result = await _client!.call(
        model: odooModel,
        method: action,
        ids: [recordId],
        kwargs: kwargs,
      );

      // Refresh local record after action
      await _syncRecordInBackground(recordId);

      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Call an Odoo action on multiple records.
  Future<dynamic> callOdooActionMulti(
    List<int> recordIds,
    String action, {
    Map<String, dynamic>? kwargs,
  }) async {
    if (!isOnline) {
      throw StateError('Cannot call Odoo action while offline');
    }

    final validIds = recordIds.where((id) => id > 0).toList();
    if (validIds.isEmpty) {
      throw ArgumentError('No valid record IDs provided');
    }

    try {
      final result = await _client!.call(
        model: odooModel,
        method: action,
        ids: validIds,
        kwargs: kwargs,
      );

      // Refresh local records after action
      for (final id in validIds) {
        await _syncRecordInBackground(id);
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }
}
