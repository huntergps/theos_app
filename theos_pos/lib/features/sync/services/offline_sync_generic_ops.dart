part of 'offline_sync_service.dart';

/// Procesamiento genérico de operaciones de la cola offline: create/write/
/// unlink estándar, detección de conflictos por write_date, y el fallback
/// genérico para modelos/acciones sin handler específico.
extension _OfflineSyncGenericOps on OfflineSyncService {
  static const _durablyReconciledCreateModels = <String>{
    'res.partner.bank',
    'collection.session.cash',
    'collection.session.deposit',
    'account.advance',
    'l10n_ec.cash.out',
  };

  /// Busca en Odoo un registro existente por `x_uuid`.
  ///
  /// Usado para recuperar de un `create` cuya respuesta se perdió pero que
  /// sí se persistió en el servidor (ver [_processCreate]). Retorna `null`
  /// si no existe o si la búsqueda falla (en ese caso el llamador debe
  /// tratar el create original como un fallo real y reintentar).
  Future<int?> _findExistingIdByUuid(String model, String uuid) async {
    final results = await _odooClient!.searchRead(
      model: model,
      domain: [
        ['x_uuid', '=', uuid],
      ],
      fields: ['id'],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['id'] as int?;
  }

  /// Reconciles generic financial creates by a server-visible natural key.
  /// These models do not all expose `x_uuid`, so retrying blindly after a
  /// lost response could duplicate the remote row.
  Future<int?> _findExistingGenericCreate(
    String model,
    Map<String, dynamic> values,
  ) async {
    final domain = switch (model) {
      'res.partner.bank'
          when values['partner_id'] is int &&
              values['account_number'] is String =>
        <dynamic>[
          ['partner_id', '=', values['partner_id']],
          ['account_number', '=', values['account_number']],
        ],
      'collection.session.cash'
          when values['collection_session_id'] is int &&
              values['cash_type'] is String =>
        <dynamic>[
          ['collection_session_id', '=', values['collection_session_id']],
          ['cash_type', '=', values['cash_type']],
        ],
      'collection.session.deposit' when values['uuid'] is String => <dynamic>[
        ['uuid', '=', values['uuid']],
      ],
      'account.advance' when values['external_id'] is String => <dynamic>[
        ['external_id', '=', values['external_id']],
      ],
      'l10n_ec.cash.out' when values['cash_out_uuid'] is String => <dynamic>[
        ['cash_out_uuid', '=', values['cash_out_uuid']],
      ],
      _ => null,
    };
    if (domain == null) return null;

    final results = await _odooClient!.searchRead(
      model: model,
      domain: domain,
      fields: const ['id'],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['id'] as int?;
  }

  /// Atomically hands a generic offline row over from its temporary Odoo ID
  /// to the definitive server ID and marks it synchronized.
  Future<void> _reconcileGenericLocalCreate({
    required String model,
    required int localId,
    required int remoteId,
  }) async {
    final syncedAt = DateTime.now().toUtc();

    await _appDb.transaction(() async {
      switch (model) {
        case 'res.partner.bank':
          final local = await (_appDb.select(
            _appDb.resPartnerBank,
          )..where((table) => table.odooId.equals(localId))).getSingleOrNull();
          final remote = await (_appDb.select(
            _appDb.resPartnerBank,
          )..where((table) => table.odooId.equals(remoteId))).getSingleOrNull();
          if (local != null && remote != null && local.id != remote.id) {
            await (_appDb.delete(
              _appDb.resPartnerBank,
            )..where((table) => table.id.equals(local.id))).go();
          } else if (local != null) {
            await (_appDb.update(
              _appDb.resPartnerBank,
            )..where((table) => table.id.equals(local.id))).write(
              ResPartnerBankCompanion(
                odooId: drift.Value(remoteId),
                isSynced: const drift.Value(true),
              ),
            );
          }
          break;
        case 'collection.session.cash':
          final local = await (_appDb.select(
            _appDb.collectionSessionCash,
          )..where((table) => table.odooId.equals(localId))).getSingleOrNull();
          final remote = await (_appDb.select(
            _appDb.collectionSessionCash,
          )..where((table) => table.odooId.equals(remoteId))).getSingleOrNull();
          if (local != null && remote != null && local.id != remote.id) {
            await (_appDb.delete(
              _appDb.collectionSessionCash,
            )..where((table) => table.id.equals(local.id))).go();
          } else if (local != null) {
            await (_appDb.update(
              _appDb.collectionSessionCash,
            )..where((table) => table.id.equals(local.id))).write(
              CollectionSessionCashCompanion(
                odooId: drift.Value(remoteId),
                isSynced: const drift.Value(true),
                lastSyncDate: drift.Value(syncedAt),
              ),
            );
          }
          break;
        case 'collection.session.deposit':
          final local = await (_appDb.select(
            _appDb.collectionSessionDeposit,
          )..where((table) => table.odooId.equals(localId))).getSingleOrNull();
          final remote = await (_appDb.select(
            _appDb.collectionSessionDeposit,
          )..where((table) => table.odooId.equals(remoteId))).getSingleOrNull();
          if (local != null && remote != null && local.id != remote.id) {
            await (_appDb.delete(
              _appDb.collectionSessionDeposit,
            )..where((table) => table.id.equals(local.id))).go();
          } else if (local != null) {
            await (_appDb.update(
              _appDb.collectionSessionDeposit,
            )..where((table) => table.id.equals(local.id))).write(
              CollectionSessionDepositCompanion(
                odooId: drift.Value(remoteId),
                isSynced: const drift.Value(true),
                lastSyncDate: drift.Value(syncedAt),
              ),
            );
          }
          break;
        case 'account.advance':
          final local = await (_appDb.select(
            _appDb.accountAdvance,
          )..where((table) => table.odooId.equals(localId))).getSingleOrNull();
          final remote = await (_appDb.select(
            _appDb.accountAdvance,
          )..where((table) => table.odooId.equals(remoteId))).getSingleOrNull();
          if (local != null && remote != null && local.id != remote.id) {
            await (_appDb.delete(
              _appDb.accountAdvance,
            )..where((table) => table.id.equals(local.id))).go();
          } else if (local != null) {
            await (_appDb.update(_appDb.accountAdvance)
                  ..where((table) => table.id.equals(local.id)))
                .write(AccountAdvanceCompanion(odooId: drift.Value(remoteId)));
          }
          final remoteLines =
              await (_appDb.select(_appDb.advanceLinesTable)
                    ..where((table) => table.advanceId.equals(remoteId))
                    ..limit(1))
                  .get();
          if (remoteLines.isNotEmpty) {
            // A refreshed remote snapshot already owns the authoritative lines.
            await (_appDb.delete(
              _appDb.advanceLinesTable,
            )..where((table) => table.advanceId.equals(localId))).go();
          } else {
            await (_appDb.update(
              _appDb.advanceLinesTable,
            )..where((table) => table.advanceId.equals(localId))).write(
              AdvanceLinesTableCompanion(advanceId: drift.Value(remoteId)),
            );
          }
          break;
        case 'l10n_ec.cash.out':
          final local = await (_appDb.select(
            _appDb.cashOut,
          )..where((table) => table.odooId.equals(localId))).getSingleOrNull();
          final remote = await (_appDb.select(
            _appDb.cashOut,
          )..where((table) => table.odooId.equals(remoteId))).getSingleOrNull();
          if (local != null && remote != null && local.id != remote.id) {
            await (_appDb.delete(
              _appDb.cashOut,
            )..where((table) => table.id.equals(local.id))).go();
          } else if (local != null) {
            await (_appDb.update(
              _appDb.cashOut,
            )..where((table) => table.id.equals(local.id))).write(
              CashOutCompanion(
                odooId: drift.Value(remoteId),
                isSynced: const drift.Value(true),
                lastSyncDate: drift.Value(syncedAt),
              ),
            );
          }
          break;
      }

      await _offlineQueue.updateRecordIdInPendingOperations(
        model,
        localId,
        remoteId,
      );
    });
  }

  /// Marks a successful generic write in the corresponding local cache.
  Future<void> _markGenericLocalWriteSynced(String model, int remoteId) async {
    final syncedAt = DateTime.now().toUtc();
    switch (model) {
      case 'res.partner.bank':
        await (_appDb.update(_appDb.resPartnerBank)
              ..where((table) => table.odooId.equals(remoteId)))
            .write(const ResPartnerBankCompanion(isSynced: drift.Value(true)));
        break;
      case 'collection.session.cash':
        await (_appDb.update(
          _appDb.collectionSessionCash,
        )..where((table) => table.odooId.equals(remoteId))).write(
          CollectionSessionCashCompanion(
            isSynced: const drift.Value(true),
            lastSyncDate: drift.Value(syncedAt),
          ),
        );
        break;
      case 'collection.session.deposit':
        await (_appDb.update(
          _appDb.collectionSessionDeposit,
        )..where((table) => table.odooId.equals(remoteId))).write(
          CollectionSessionDepositCompanion(
            isSynced: const drift.Value(true),
            lastSyncDate: drift.Value(syncedAt),
          ),
        );
        break;
    }
  }

  /// Process a CREATE operation
  ///
  /// Creates the record in Odoo, then updates the local database
  /// with the real Odoo ID.
  ///
  /// For sale.order, reads current local order values to ensure
  /// any updates made after the operation was queued are included.
  Future<void> _processCreate(OfflineOperation op) async {
    // Extract local_id and uuid from values (support both 'uuid' and '_uuid' keys)
    // For sale.order, the local_id might be stored in recordId (negative number)
    int? localId = op.values['local_id'] as int?;
    if (localId == null && op.recordId != null && op.recordId! < 0) {
      // Use recordId as localId for orders created offline
      localId = op.recordId;
    }
    final uuid = (op.values['uuid'] ?? op.values['_uuid']) as String?;

    // Prepare values for Odoo (remove local-only fields)
    Map<String, dynamic> odooValues = Map<String, dynamic>.from(op.values)
      ..remove('local_id')
      ..remove('_uuid')
      ..remove('_operation_key')
      ..remove(OfflineQueueDataSource.remoteCreateIdKey);
    // `uuid` is a real idempotency field on collection.session.deposit. For
    // all other generic models it remains local metadata and must not be sent.
    if (op.model != 'collection.session.deposit') {
      odooValues.remove('uuid');
    }

    // For sale.order, read current local values to get any updates made after queue
    if (op.model == 'sale.order' && localId != null) {
      final localOrder = await _orderManager.getSaleOrder(localId);
      if (localOrder != null) {
        // Validate order before syncing
        final validationError = await _validateOrderForSync(localOrder);
        if (validationError != null) {
          throw Exception(validationError);
        }

        // Use current local values (override stale queued values)
        odooValues = {
          'partner_id': localOrder.partnerId,
          if (localOrder.warehouseId != null)
            'warehouse_id': localOrder.warehouseId,
          if (localOrder.pricelistId != null)
            'pricelist_id': localOrder.pricelistId,
          if (localOrder.paymentTermId != null)
            'payment_term_id': localOrder.paymentTermId,
          if (localOrder.userId != null) 'user_id': localOrder.userId,
          // Final consumer fields
          if (localOrder.isFinalConsumer) 'is_final_consumer': true,
          if (localOrder.endCustomerName != null &&
              localOrder.endCustomerName!.isNotEmpty)
            'end_customer_name': localOrder.endCustomerName,
          if (localOrder.endCustomerPhone != null &&
              localOrder.endCustomerPhone!.isNotEmpty)
            'end_customer_phone': localOrder.endCustomerPhone,
          if (localOrder.endCustomerEmail != null &&
              localOrder.endCustomerEmail!.isNotEmpty)
            'end_customer_email': localOrder.endCustomerEmail,
          // Referrer
          if (localOrder.referrerId != null)
            'referrer_id': localOrder.referrerId,
          // Note / commitment date
          if (localOrder.note != null && localOrder.note!.isNotEmpty)
            'note': localOrder.note,
          if (localOrder.commitmentDate != null)
            'commitment_date': localOrder.commitmentDate!.toIso8601String(),
        };

        logger.d(
          '[OfflineSyncService]',
          'Using current local values for order $localId: isFinalConsumer=${localOrder.isFinalConsumer}, '
              'endCustomerName=${localOrder.endCustomerName}, referrerId=${localOrder.referrerId}',
        );
      }
    }

    // Add x_uuid for tracking
    if (uuid != null &&
        (op.model == 'sale.order' || op.model == 'sale.order.line')) {
      odooValues['x_uuid'] = uuid;
    }

    logger.d(
      '[OfflineSyncService]',
      'Creating ${op.model} with uuid=$uuid, localId=$localId',
    );

    final persistedRemoteId =
        op.values[OfflineQueueDataSource.remoteCreateIdKey];
    int? remoteId = persistedRemoteId is int ? persistedRemoteId : null;
    final supportsDurableHandoff = _durablyReconciledCreateModels.contains(
      op.model,
    );
    if (supportsDurableHandoff && localId == null) {
      throw StateError(
        'Cannot create ${op.model}: no durable local ID was queued',
      );
    }
    final hasUuidReconciliation =
        uuid != null &&
        uuid.isNotEmpty &&
        (op.model == 'sale.order' || op.model == 'sale.order.line');
    if (remoteId == null && hasUuidReconciliation) {
      // Always reconcile before create. This handles retries after the server
      // committed but the client never received the response.
      remoteId = await _findExistingIdByUuid(op.model, uuid);
    }
    if (remoteId == null && supportsDurableHandoff) {
      remoteId = await _findExistingGenericCreate(op.model, op.values);
    }
    try {
      remoteId ??= await _odooClient!.create(
        model: op.model,
        values: odooValues,
      );
    } catch (e) {
      // Recuperación de idempotencia: el create puede haber llegado a Odoo
      // y persistido, pero la respuesta HTTP se perdió (timeout, red
      // inestable) — el cliente lo interpreta como fallo y reintenta. El
      // reintento choca con el constraint único `x_uuid_unique` en
      // sale.order y sigue fallando indefinidamente, dejando la orden
      // huérfana: sincronizada en Odoo pero atascada en dead-letter local.
      // Antes de reintentar, verificamos si ya existe por x_uuid y, si es
      // así, vinculamos el ID real en vez de volver a intentar el create.
      if (hasUuidReconciliation) {
        final existingId = await _findExistingIdByUuid(op.model, uuid);
        if (existingId != null) {
          logger.w(
            '[OfflineSyncService]',
            'Create de ${op.model} (uuid=$uuid) falló ("$e") pero YA existe '
                'en Odoo con id=$existingId — vinculando en vez de reintentar.',
          );
          remoteId = existingId;
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    if (supportsDurableHandoff && remoteId != null) {
      await _offlineQueue.persistRemoteCreateId(op.id, remoteId);
    }
    if (supportsDurableHandoff && remoteId == null) {
      throw StateError('Create of ${op.model} returned no remote ID');
    }

    if (remoteId != null && localId != null) {
      // Persist the ID hand-off before processing the next claimed operation.
      // This is required beyond sale.order: generic create/action chains also
      // carry the local negative ID in OfflineQueue.recordId.
      if (op.model != 'sale.order' &&
          op.model != 'sale.order.line' &&
          !supportsDurableHandoff) {
        await _offlineQueue.updateRecordIdInPendingOperations(
          op.model,
          localId,
          remoteId,
        );
      }

      // Update local record with remote ID based on model type
      if (supportsDurableHandoff) {
        await _reconcileGenericLocalCreate(
          model: op.model,
          localId: localId,
          remoteId: remoteId,
        );
      } else if (op.model == 'sale.order') {
        await _orderManager.updateSaleOrderRemoteId(localId, remoteId);
        logger.d(
          '[OfflineSyncService]',
          'Updated local order $localId -> remote $remoteId',
        );

        // Also update order_id in pending line operations in the queue
        await _offlineQueue.updateOrderIdInPendingOperations(localId, remoteId);

        // Remove any pending write operations for this order since we already included all values
        await _offlineQueue.removePendingWritesForOrder(localId);
      } else if (op.model == 'sale.order.line') {
        await _updateLineRemoteIdByUuid(uuid!, remoteId);
        logger.d(
          '[OfflineSyncService]',
          'Updated local line $uuid -> remote $remoteId',
        );
      }
    }
  }

  /// Process a WRITE operation
  ///
  /// If we have a recordId, use it directly. Otherwise, look up by UUID.
  /// Returns ConflictInfo if there's a conflict, null otherwise.
  Future<ConflictInfo?> _processWrite(OfflineOperation op) async {
    final uuid = op.values['uuid'] as String?;

    // Prepare values for Odoo (remove uuid)
    final odooValues = Map<String, dynamic>.from(op.values)
      ..remove('uuid')
      ..remove('_uuid')
      ..remove('local_id')
      ..remove('_operation_key')
      ..remove(OfflineQueueDataSource.remoteCreateIdKey);

    int? targetId = op.recordId;

    // If no recordId but we have UUID, look it up
    if (targetId == null && uuid != null && op.model == 'sale.order.line') {
      final line = await _findLineByUuid(uuid);
      if (line != null && line.id > 0) {
        targetId = line.id;
      }
    }

    if (targetId == null || targetId <= 0) {
      throw Exception(
        'Cannot write to ${op.model}: no valid remote ID (uuid=$uuid)',
      );
    }

    // Check for conflicts if we have baseWriteDate
    if (op.baseWriteDate != null) {
      final conflict = await _checkWriteConflict(op, targetId);
      if (conflict != null) {
        return conflict;
      }
    }

    logger.d(
      '[OfflineSyncService]',
      'Writing to ${op.model}[$targetId]: $odooValues',
    );

    final success = await _odooClient!.write(
      model: op.model,
      ids: [targetId],
      values: odooValues,
    );

    if (!success) {
      throw Exception('Write to ${op.model}[$targetId] returned false');
    }

    if (_durablyReconciledCreateModels.contains(op.model)) {
      await _markGenericLocalWriteSynced(op.model, targetId);
    }

    return null;
  }

  /// Check if server has newer version than our queued operation
  Future<ConflictInfo?> _checkWriteConflict(
    OfflineOperation op,
    int targetId,
  ) async {
    try {
      final requestedFields = op.values.keys
          .where(
            (field) =>
                field != 'uuid' &&
                field != '_uuid' &&
                field != 'local_id' &&
                field != '_operation_key' &&
                field != OfflineQueueDataSource.remoteCreateIdKey &&
                field != 'write_date',
          )
          .toSet();

      // Read both write_date and the server values that differ. Without the
      // latter the conflict screen had no evidence to compare or resolve.
      final serverData = await _odooClient!.searchRead(
        model: op.model,
        domain: [
          ['id', '=', targetId],
        ],
        fields: ['write_date', ...requestedFields],
        limit: 1,
      );

      if (serverData.isEmpty) {
        // Record doesn't exist on server anymore
        logger.w(
          '[OfflineSyncService]',
          '${op.model}[$targetId] not found on server',
        );
        return null;
      }

      final serverWriteDateStr = serverData[0]['write_date'] as String?;
      if (serverWriteDateStr == null) {
        return null;
      }

      final serverWriteDate = DateTime.parse(serverWriteDateStr);
      final localWriteDate = op.baseWriteDate!;

      // Server has been modified after our local change was queued
      if (serverWriteDate.isAfter(localWriteDate)) {
        logger.w(
          '[OfflineSyncService]',
          '⚠️ CONFLICT: ${op.model}[$targetId] - server: $serverWriteDate > local: $localWriteDate',
        );

        return ConflictInfo(
          operationId: op.id,
          model: op.model,
          recordId: targetId,
          localWriteDate: localWriteDate,
          serverWriteDate: serverWriteDate,
          localValues: op.values,
          serverValues: Map<String, dynamic>.from(serverData[0]),
        );
      }

      return null;
    } catch (e) {
      logger.e(
        '[OfflineSyncService]',
        'Error checking conflict for ${op.model}[$targetId]: $e',
      );
      // Never overwrite blindly if conflict detection itself is unavailable.
      rethrow;
    }
  }

  /// Process an UNLINK operation
  ///
  /// Throws [OperationSkippedException] if the record doesn't exist
  Future<void> _processUnlink(OfflineOperation op) async {
    if (op.recordId == null || op.recordId! <= 0) {
      // Record was never synced, nothing to delete on server
      throw OperationSkippedException(
        '${op.model}: sin ID remoto (registro local no sincronizado)',
      );
    }

    logger.d('[OfflineSyncService]', 'Unlinking ${op.model}[${op.recordId}]');

    try {
      final success = await _odooClient!.unlink(
        model: op.model,
        ids: [op.recordId!],
      );

      if (!success) {
        throw Exception('Unlink ${op.model}[${op.recordId}] returned false');
      }
    } catch (e) {
      // If record doesn't exist, throw skipped exception
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('does not exist') ||
          errorStr.contains('has been deleted') ||
          errorStr.contains('missing record')) {
        throw OperationSkippedException(
          '${op.model}[${op.recordId}] ya no existe en Odoo',
        );
      }
      rethrow; // Other errors should still fail
    }
  }

  /// Process offline order state actions (lock/unlock/confirm/cancel/draft)
  ///
  /// Calls the specified action method on the order in Odoo.
  /// Used for offline-first state changes that were queued for later sync.
  ///
  /// Returns [ConflictInfo] if the order was modified on the server after
  /// the operation was queued (based on write_date comparison).
  ///
  /// Expected op.values:
  /// - order_id: int (Odoo order ID)
  /// Process a generic action method on any model.
  ///
  /// This handles action_* methods (action_confirm, action_cancel, action_post,
  /// action_return, etc.) for models other than sale.order by calling the method
  /// directly on the correct model via the Odoo API.
  Future<ConflictInfo?> _processGenericAction(OfflineOperation op) async {
    final recordId = op.recordId ?? op.values['id'] as int?;

    if (recordId == null) {
      throw Exception(
        'Cannot process ${op.model}.${op.method} - no record ID available',
      );
    }

    logger.d(
      '[OfflineSyncService]',
      'Processing generic action ${op.model}.${op.method} for record $recordId',
    );

    if (await _genericActionAlreadyApplied(op, recordId)) {
      logger.i(
        '[OfflineSyncService]',
        '${op.model}.${op.method} already reflected by server state; '
            'finishing replay without a duplicate RPC',
      );
      return null;
    }

    await _odooClient!.call(
      model: op.model,
      method: op.method,
      ids: [recordId],
    );

    logger.d(
      '[OfflineSyncService]',
      '${op.model} $recordId ${op.method} synced to Odoo',
    );

    return null;
  }

  /// Reconciles retry-safe financial state actions after a lost response.
  /// Both backends expose a canonical `state`, so a recovered outbox row can
  /// prove whether the prior request committed before issuing another action.
  Future<bool> _genericActionAlreadyApplied(
    OfflineOperation op,
    int recordId,
  ) async {
    final appliedStates = switch ((op.model, op.method)) {
      ('account.advance', 'action_post') => const {
        'posted',
        'in_use',
        'used',
        'expired',
      },
      ('account.advance', 'action_cancel') => const {'canceled', 'cancelled'},
      ('l10n_ec.cash.out', 'action_confirm') => const {'posted'},
      ('l10n_ec.cash.out', 'action_cancel') => const {'canceled', 'cancelled'},
      _ => null,
    };
    if (appliedStates == null) return false;

    final rows = await _odooClient!.searchRead(
      model: op.model,
      domain: [
        ['id', '=', recordId],
      ],
      fields: const ['state'],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final state = rows.first['state'];
    return state is String && appliedStates.contains(state);
  }

  /// Process operations for models other than sale.order and sale.order.line
  ///
  /// This handles payment wizards, withhold lines, advances, etc.
  Future<ConflictInfo?> _processOtherModelOperation(OfflineOperation op) async {
    logger.d(
      '[OfflineSyncService]',
      'Processing ${op.model}.${op.method} (op ${op.id})',
    );

    switch (op.model) {
      // Payment wizard operations
      case 'l10n_ec_collection_box.sale.order.payment.wizard':
        return await _processPaymentWizard(op);

      // Payment lines (individual payments)
      case 'l10n_ec_collection_box.sale.order.payment':
        await _processPaymentLine(op);
        return null;

      // Withhold lines
      case 'sale.order.withhold.line':
        await _processWithholdLine(op);
        return null;

      // Advance payments
      case 'sale.order.advance.line':
        await _processAdvanceLine(op);
        return null;

      // Generic fallback - try standard CRUD operations
      default:
        logger.w(
          '[OfflineSyncService]',
          'Unknown model ${op.model}, attempting generic ${op.method}',
        );
        await _processGenericOperation(op);
        return null;
    }
  }

  /// Process generic operation for unknown models
  Future<void> _processGenericOperation(OfflineOperation op) async {
    final values = Map<String, dynamic>.from(op.values);

    // Remove local-only fields
    values.remove('local_id');
    values.remove('uuid');
    values.remove('_uuid');

    switch (op.method) {
      case 'create':
        final remoteId = await _odooClient!.create(
          model: op.model,
          values: values,
        );
        logger.d('[OfflineSyncService]', '${op.model} created: $remoteId');
        break;

      case 'write':
        if (op.recordId == null || op.recordId! <= 0) {
          throw Exception('Cannot write ${op.model}: no valid record ID');
        }
        await _odooClient!.write(
          model: op.model,
          ids: [op.recordId!],
          values: values,
        );
        logger.d('[OfflineSyncService]', '${op.model} updated: ${op.recordId}');
        break;

      case 'unlink':
        if (op.recordId == null || op.recordId! <= 0) {
          throw OperationSkippedException('${op.model}: sin ID remoto');
        }
        try {
          await _odooClient!.unlink(model: op.model, ids: [op.recordId!]);
          logger.d(
            '[OfflineSyncService]',
            '${op.model} deleted: ${op.recordId}',
          );
        } catch (e) {
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('does not exist') ||
              errorStr.contains('has been deleted') ||
              errorStr.contains('missing record')) {
            throw OperationSkippedException(
              '${op.model}[${op.recordId}] ya no existe en Odoo',
            );
          }
          rethrow;
        }
        break;

      default:
        // Try to call the method directly on the model
        if (op.recordId != null && op.recordId! > 0) {
          await _odooClient!.call(
            model: op.model,
            method: op.method,
            ids: [op.recordId!],
          );
          logger.d(
            '[OfflineSyncService]',
            '${op.model}.${op.method}(${op.recordId}) called',
          );
        } else {
          throw Exception(
            'Cannot call ${op.model}.${op.method}: no valid record ID',
          );
        }
    }
  }
}
