// Part of odoo_model_manager library
part of 'odoo_model_manager.dart';

/// Conflict resolution mixin for OdooModelManager.
///
/// Provides conflict detection and resolution for sync operations:
/// - [setConflictHandler] to configure resolution strategy
/// - [detectConflict] to check for local/server divergence
/// - [resolveConflict] to apply configured resolution strategy
/// - [applyResolution] to persist the resolved record
mixin _ManagerConflictsMixin<T> on _OdooModelManagerBase<T> {
  /// Conflict handler for this manager.
  ConflictHandler<T>? _conflictHandler;

  /// Set the conflict handler for this manager.
  void setConflictHandler(ConflictHandler<T> handler) {
    _conflictHandler = handler;
  }

  /// Detect if there's a conflict between local and server versions.
  Future<SyncConflict<T>?> detectConflict(int id) async {
    if (!isOnline) return null;

    final local = await readLocal(id);
    if (local == null) return null;

    // Fetch server version
    try {
      final serverData = await _client!.read(
        model: odooModel,
        ids: [id],
        fields: odooFields,
      );

      if (serverData.isEmpty) return null;

      final server = fromOdoo(serverData.first);

      // Compare local and server
      final localMap = toOdoo(local);
      final serverMap = toOdoo(server);

      final conflictingFields = <String>[];
      for (final field in localMap.keys) {
        if (localMap[field] != serverMap[field]) {
          conflictingFields.add(field);
        }
      }

      if (conflictingFields.isEmpty) return null;

      return SyncConflict<T>(
        recordId: id,
        model: odooModel,
        localRecord: local,
        serverRecord: server,
        conflictingFields: conflictingFields,
      );
    } catch (e) {
      return null;
    }
  }

  /// Resolve a conflict using the configured handler.
  Future<ConflictResolution<T>?> resolveConflict(
      SyncConflict<T> conflict) async {
    final handler = _conflictHandler ?? DefaultConflictHandler<T>();
    return handler.resolveConflict(conflict);
  }

  /// Apply a conflict resolution.
  Future<void> applyResolution(ConflictResolution<T> resolution) async {
    final record = resolution.resolvedRecord;
    final id = getId(record);

    // Save resolved version locally
    await upsertLocal(withSyncStatus(record, !resolution.updateServer));

    // Update server if needed
    if (resolution.updateServer && isOnline && id > 0) {
      try {
        await _client!.write(
          model: odooModel,
          ids: [id],
          values: toOdoo(record),
        );
        await upsertLocal(withSyncStatus(record, true));
      } catch (e) {
        // Queue for later sync
        await _queueOperation(
          OfflineOperationType.write,
          id,
          getUuid(record),
          record,
        );
      }
    }

    _recordChanges.add(RecordChangeEvent(
      type: ChangeType.update,
      id: id,
      record: record,
      timestamp: DateTime.now(),
    ));
  }
}
