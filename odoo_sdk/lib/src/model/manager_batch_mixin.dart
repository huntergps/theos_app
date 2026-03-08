// Part of odoo_model_manager library
part of 'odoo_model_manager.dart';

/// Batch CRUD operations mixin for OdooModelManager.
///
/// Provides efficient batch operations for multiple records:
/// - [createBatch] for creating multiple records at once
/// - [updateBatch] for updating multiple records at once
/// - [deleteBatch] for deleting multiple records at once
/// - [upsertBatch] for create-or-update based on record ID
mixin _ManagerBatchMixin<T> on _OdooModelManagerBase<T> {
  /// Create multiple records in a single batch.
  ///
  /// More efficient than calling [create] multiple times.
  /// Returns list of created record IDs.
  Future<List<int>> createBatch(List<T> records) async {
    if (records.isEmpty) return [];

    final ids = <int>[];
    final batchUuid = _uuid.v4();

    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final tempId = -DateTime.now().millisecondsSinceEpoch - i;
      final recordUuid = '${batchUuid}_$i';

      final recordWithIds = withIdAndUuid(record, tempId, recordUuid);
      final unsyncedRecord = withSyncStatus(recordWithIds, false);

      await upsertLocal(unsyncedRecord);
      await _queueOperation(
        OfflineOperationType.create,
        tempId,
        recordUuid,
        unsyncedRecord,
      );

      ids.add(tempId);

      // Emit individual change events
      _recordChanges.add(RecordChangeEvent(
        type: ChangeType.create,
        id: tempId,
        record: unsyncedRecord,
        timestamp: DateTime.now(),
      ));
    }

    await _updateUnsyncedCount();
    return ids;
  }

  /// Update multiple records in a single batch.
  ///
  /// More efficient than calling [update] multiple times.
  Future<void> updateBatch(List<T> records) async {
    if (records.isEmpty) return;

    for (final record in records) {
      final id = getId(record);
      if (id <= 0) continue;

      final unsyncedRecord = withSyncStatus(record, false);
      await upsertLocal(unsyncedRecord);
      await _queueOperation(
        OfflineOperationType.write,
        id,
        getUuid(record),
        unsyncedRecord,
      );

      // Emit individual change event
      _recordChanges.add(RecordChangeEvent(
        type: ChangeType.update,
        id: id,
        record: unsyncedRecord,
        timestamp: DateTime.now(),
      ));
    }

    await _updateUnsyncedCount();
  }

  /// Delete multiple records in a single batch.
  ///
  /// More efficient than calling [delete] multiple times.
  Future<void> deleteBatch(List<int> ids) async {
    if (ids.isEmpty) return;

    for (final id in ids) {
      if (id <= 0) continue;

      final existing = await readLocal(id);
      if (existing != null) {
        await deleteLocal(id);
        await _queueOperation(
          OfflineOperationType.unlink,
          id,
          getUuid(existing),
          null,
        );

        // Emit individual change event
        _recordChanges.add(RecordChangeEvent(
          type: ChangeType.delete,
          id: id,
          timestamp: DateTime.now(),
        ));
      }
    }

    await _updateUnsyncedCount();
  }

  /// Upsert multiple records (create if not exists, update if exists).
  ///
  /// Uses record ID to determine create vs update.
  Future<List<int>> upsertBatch(List<T> records) async {
    if (records.isEmpty) return [];

    final toCreate = <T>[];
    final toUpdate = <T>[];

    for (final record in records) {
      final id = getId(record);
      if (id <= 0) {
        toCreate.add(record);
      } else {
        toUpdate.add(record);
      }
    }

    final createdIds = await createBatch(toCreate);
    await updateBatch(toUpdate);

    return [
      ...createdIds,
      ...toUpdate.map(getId),
    ];
  }
}
