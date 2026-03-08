// Part of odoo_model_manager library
part of 'odoo_model_manager.dart';

/// Sync operations mixin for OdooModelManager.
///
/// Provides bidirectional sync between local database and Odoo server:
/// - [syncFromOdoo] for downloading records from Odoo
/// - [syncToOdoo] for uploading local changes to Odoo
/// - [sync] for full bidirectional sync
mixin _ManagerSyncMixin<T> on _OdooModelManagerBase<T> {
  /// Get the list of fields available for selective sync.
  ///
  /// Returns all Odoo field names that can be used with [selectedFields]
  /// in [syncFromOdoo] and [sync].
  List<String> get selectableFields => odooFields;

  /// Resolve the final field list for a sync operation.
  ///
  /// If [selectedFields] is null, returns all [odooFields].
  /// If provided, intersects with [odooFields] and ensures mandatory
  /// fields (id, write_date, create_date) are always included.
  List<String> _resolveFields(List<String>? selectedFields) {
    if (selectedFields == null || selectedFields.isEmpty) {
      return odooFields;
    }

    // Always include mandatory fields for sync to work
    const mandatoryFields = {'id', 'write_date', 'create_date'};

    // Intersect with available odooFields to prevent requesting invalid fields
    final available = odooFields.toSet();
    final resolved = <String>{
      ...mandatoryFields.intersection(available),
      ...selectedFields.where((f) => available.contains(f)),
    };

    return resolved.toList();
  }

  /// Sync records from Odoo to local database.
  ///
  /// Performs incremental sync if [since] is provided, otherwise full sync.
  /// If [selectedFields] is provided, only those fields (plus mandatory ones
  /// like id, write_date, create_date) are fetched from Odoo. Fields not in
  /// [odooFields] are silently ignored.
  /// Progress is reported via [onProgress] callback.
  /// Can be cancelled via [cancellation] token.
  Future<SyncResult> syncFromOdoo({
    DateTime? since,
    List<dynamic>? additionalDomain,
    List<String>? selectedFields,
    void Function(SyncProgress)? onProgress,
    CancellationToken? cancellation,
  }) async {
    if (!isOnline) {
      return SyncResult.offline(model: odooModel);
    }

    if (_syncInProgress.value) {
      return SyncResult.alreadyInProgress(model: odooModel);
    }

    _syncInProgress.add(true);

    try {
      // Build domain for incremental sync
      final domain = <List<dynamic>>[
        if (since != null && trackWriteDate)
          ['write_date', '>', since.toIso8601String()],
        if (additionalDomain != null)
          ...additionalDomain.cast<List<dynamic>>(),
      ];

      // Count total records
      onProgress?.call(SyncProgress(
        model: odooModel,
        synced: 0,
        total: 0,
        phase: SyncPhase.counting,
      ));

      final total = await _client!.searchCount(
            model: odooModel,
            domain: domain.isEmpty ? null : domain,
          ) ??
          0;

      int synced = 0;
      int offset = 0;
      bool hasMore = true;

      while (hasMore) {
        // Check cancellation
        if (cancellation?.isCancelled ?? false) {
          _syncInProgress.add(false);
          return SyncResult.cancelled(model: odooModel, synced: synced);
        }

        // Fetch batch
        final records = await _client!.searchRead(
          model: odooModel,
          domain: domain.isEmpty ? null : domain,
          fields: _resolveFields(selectedFields),
          limit: _config.syncBatchSize,
          offset: offset,
          order: 'write_date ASC',
        );

        // Process batch
        for (final data in records) {
          final record = fromOdoo(data);
          final syncedRecord = withSyncStatus(record, true);
          await upsertLocal(syncedRecord);
          _emitChange(ChangeType.sync, getId(syncedRecord), record: syncedRecord);
          synced++;

          // Report progress
          if (synced % _config.progressInterval == 0) {
            onProgress?.call(SyncProgress(
              model: odooModel,
              synced: synced,
              total: total,
              phase: SyncPhase.downloading,
              percentage: total > 0 ? synced.toDouble() / total : null,
            ));
          }
        }

        offset += _config.syncBatchSize;
        hasMore = records.length == _config.syncBatchSize;
      }

      _lastSyncTime.add(DateTime.now());
      _syncInProgress.add(false);
      await _updateUnsyncedCount();

      onProgress?.call(SyncProgress(
        model: odooModel,
        synced: synced,
        total: total,
        phase: SyncPhase.completed,
        percentage: 1.0,
      ));

      return SyncResult.success(model: odooModel, synced: synced);
    } catch (e) {
      _syncInProgress.add(false);
      return SyncResult.error(model: odooModel, error: e.toString());
    }
  }

  /// Sync local changes to Odoo.
  ///
  /// Processes queued operations and unsynced records.
  Future<SyncResult> syncToOdoo({
    void Function(SyncProgress)? onProgress,
    CancellationToken? cancellation,
  }) async {
    if (!isOnline) {
      return SyncResult.offline(model: odooModel);
    }

    _syncInProgress.add(true);

    try {
      // Get pending operations from queue
      final operations = await _queue!.getPendingForModel(odooModel);
      int processed = 0;
      int failed = 0;

      for (final op in operations) {
        if (cancellation?.isCancelled ?? false) {
          _syncInProgress.add(false);
          return SyncResult.cancelled(model: odooModel, synced: processed);
        }

        try {
          await _processQueuedOperation(op);
          await _queue!.markCompleted(op.id);
          processed++;
        } catch (e) {
          await _queue!.markFailed(op.id, e.toString());
          failed++;
        }

        onProgress?.call(SyncProgress(
          model: odooModel,
          synced: processed,
          total: operations.length,
          phase: SyncPhase.uploading,
        ));
      }

      _syncInProgress.add(false);
      await _updateUnsyncedCount();

      return SyncResult.success(
        model: odooModel,
        synced: processed,
        failed: failed,
      );
    } catch (e) {
      _syncInProgress.add(false);
      return SyncResult.error(model: odooModel, error: e.toString());
    }
  }

  /// Perform full bidirectional sync.
  ///
  /// If [selectedFields] is provided, only those fields are fetched from Odoo
  /// during the download phase. See [syncFromOdoo] for details.
  Future<SyncResult> sync({
    DateTime? since,
    List<String>? selectedFields,
    void Function(SyncProgress)? onProgress,
    CancellationToken? cancellation,
  }) async {
    // First push local changes
    final uploadResult = await syncToOdoo(
      onProgress: onProgress,
      cancellation: cancellation,
    );

    if (uploadResult.status == SyncStatus.cancelled) {
      return uploadResult;
    }

    // Then pull server changes
    final downloadResult = await syncFromOdoo(
      since: since,
      selectedFields: selectedFields,
      onProgress: onProgress,
      cancellation: cancellation,
    );

    return SyncResult.combined(uploadResult, downloadResult);
  }
}
