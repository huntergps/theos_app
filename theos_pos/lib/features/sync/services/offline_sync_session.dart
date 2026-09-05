part of 'offline_sync_service.dart';

/// Manejo de operaciones de sesión de cobro (collection.session).
extension _OfflineSyncSession on OfflineSyncService {
  // =========================================================================
  // COLLECTION SESSION SYNC HANDLERS
  // =========================================================================

  /// Process session_create_and_open: Create session + call action_session_open
  ///
  /// Values expected:
  /// - config_id: int
  /// - user_id: int
  /// - cash_register_balance_start: double
  /// - session_uuid: String
  /// - local_id: int (negative ID)
  Future<void> _processSessionCreateAndOpen(OfflineOperation op) async {
    final localId = op.values['local_id'] as int?;
    final sessionUuid = op.values['session_uuid'] as String?;

    final odooValues = <String, dynamic>{
      'config_id': op.values['config_id'],
      'user_id': op.values['user_id'],
      'cash_register_balance_start': op.values['cash_register_balance_start'],
    };

    if (sessionUuid != null) {
      odooValues['session_uuid'] = sessionUuid;
    }

    logger.d(
      '[OfflineSyncService]',
      'Creating collection.session: uuid=$sessionUuid, localId=$localId',
    );

    // A known remote ID is written to the outbox before any local hand-off.
    // On restart this marker wins, so a committed create is never sent twice.
    int? remoteId = op.values[OfflineQueueDataSource.remoteCreateIdKey] as int?;
    if (remoteId == null && sessionUuid != null && sessionUuid.isNotEmpty) {
      final existing = await _odooClient!.searchRead(
        model: 'collection.session',
        domain: [
          ['session_uuid', '=', sessionUuid],
        ],
        fields: ['id', 'state'],
        limit: 1,
      );
      if (existing.isNotEmpty) remoteId = existing.first['id'] as int?;
    }
    remoteId ??= await _odooClient!.create(
      model: 'collection.session',
      values: odooValues,
    );

    if (remoteId == null) {
      throw Exception('Failed to create collection.session - returned null');
    }
    final resolvedRemoteId = remoteId;

    await _offlineQueue.persistRemoteCreateId(op.id, resolvedRemoteId);

    logger.d('[OfflineSyncService]', 'Session created: $remoteId, opening...');

    // 2. Open session
    final existingState = sessionUuid == null
        ? null
        : (await _odooClient!.searchRead(
            model: 'collection.session',
            domain: [
              ['id', '=', resolvedRemoteId],
            ],
            fields: ['state'],
            limit: 1,
          )).firstOrNull?['state'];
    if (existingState != 'opened' && existingState != 'closed') {
      await _odooClient!.call(
        model: 'collection.session',
        method: 'action_session_open',
        ids: [resolvedRemoteId],
      );
    }

    logger.d(
      '[OfflineSyncService]',
      'Session $resolvedRemoteId opened successfully',
    );

    // 3. Atomically hand off the parent identity to the local graph and every
    // queued child. If the process stops after this transaction but before the
    // queue row is removed, replay consumes the marker above and is harmless.
    if (localId != null && sessionUuid != null) {
      await _appDb.transaction(() async {
        await _sessionManager.updateSessionIdByUuid(
          sessionUuid,
          resolvedRemoteId,
        );
        await (_appDb.update(
          _appDb.collectionSessionCash,
        )..where((table) => table.collectionSessionId.equals(localId))).write(
          CollectionSessionCashCompanion(
            collectionSessionId: drift.Value(resolvedRemoteId),
          ),
        );
        await (_appDb.update(
          _appDb.collectionSessionDeposit,
        )..where((table) => table.collectionSessionId.equals(localId))).write(
          CollectionSessionDepositCompanion(
            collectionSessionId: drift.Value(resolvedRemoteId),
          ),
        );
        await (_appDb.update(
          _appDb.cashOut,
        )..where((table) => table.collectionSessionId.equals(localId))).write(
          CashOutCompanion(collectionSessionId: drift.Value(resolvedRemoteId)),
        );
        await (_appDb.update(
          _appDb.accountPaymentTable,
        )..where((table) => table.collectionSessionId.equals(localId))).write(
          AccountPaymentCompanion(
            collectionSessionId: drift.Value(resolvedRemoteId),
          ),
        );
        await (_appDb.update(
          _appDb.saleOrder,
        )..where((table) => table.collectionSessionId.equals(localId))).write(
          SaleOrderCompanion(
            collectionSessionId: drift.Value(resolvedRemoteId),
          ),
        );
        await (_appDb.update(
          _appDb.saleOrderLine,
        )..where((table) => table.collectionSessionId.equals(localId))).write(
          SaleOrderLineCompanion(
            collectionSessionId: drift.Value(resolvedRemoteId),
          ),
        );
        await (_appDb.update(
          _appDb.accountAdvance,
        )..where((table) => table.collectionSessionId.equals(localId))).write(
          AccountAdvanceCompanion(
            collectionSessionId: drift.Value(resolvedRemoteId),
          ),
        );
        await _offlineQueue.updateCollectionSessionIdInPendingOperations(
          localId,
          resolvedRemoteId,
        );
      });
      logger.d(
        '[OfflineSyncService]',
        'Updated local session $localId -> $resolvedRemoteId',
      );
    }
  }

  /// Process session_open: Write cash + call action_session_open
  ///
  /// Values expected:
  /// - session_id: int
  /// - cash_register_balance_start: double
  Future<void> _processSessionOpen(OfflineOperation op) async {
    final sessionId = op.values['session_id'] as int;
    final cashAmount = op.values['cash_register_balance_start'] as double;

    logger.d(
      '[OfflineSyncService]',
      'Opening session $sessionId with cash=$cashAmount',
    );

    final currentState = await _remoteSessionState(sessionId);
    if (currentState == 'opened' ||
        currentState == 'closing_control' ||
        currentState == 'closed') {
      logger.d(
        '[OfflineSyncService]',
        'Session $sessionId is already $currentState; open replay reconciled',
      );
      return;
    }

    // 1. Write cash balance
    final writeResult = await _odooClient!.write(
      model: 'collection.session',
      ids: [sessionId],
      values: {'cash_register_balance_start': cashAmount},
    );

    if (!writeResult) {
      throw Exception('Failed to write cash_register_balance_start');
    }

    // 2. Open session
    await _odooClient.call(
      model: 'collection.session',
      method: 'action_session_open',
      ids: [sessionId],
    );

    logger.d('[OfflineSyncService]', 'Session $sessionId opened successfully');
  }

  /// Process session_closing_control: Write closing cash + start closing control
  ///
  /// Values expected:
  /// - session_id: int
  /// - cash_register_balance_end_real: double
  Future<void> _processSessionClosingControl(OfflineOperation op) async {
    final sessionId = op.values['session_id'] as int;
    final cashAmount = op.values['cash_register_balance_end_real'] as double;

    logger.d(
      '[OfflineSyncService]',
      'Starting closing control for session $sessionId, cash=$cashAmount',
    );

    final currentState = await _remoteSessionState(sessionId);
    if (currentState == 'closing_control' || currentState == 'closed') {
      logger.d(
        '[OfflineSyncService]',
        'Session $sessionId is already $currentState; closing-control replay reconciled',
      );
      return;
    }

    // 1. Write closing cash
    final writeResult = await _odooClient!.write(
      model: 'collection.session',
      ids: [sessionId],
      values: {'cash_register_balance_end_real': cashAmount},
    );

    if (!writeResult) {
      throw Exception('Failed to write cash_register_balance_end_real');
    }

    // 2. Start closing control
    await _odooClient.call(
      model: 'collection.session',
      method: 'action_session_closing_control',
      ids: [sessionId],
    );

    logger.d(
      '[OfflineSyncService]',
      'Closing control started for session $sessionId',
    );
  }

  /// Process session_close: Close the session
  ///
  /// Values expected:
  /// - session_id: int
  Future<void> _processSessionClose(OfflineOperation op) async {
    final sessionId = op.values['session_id'] as int;

    logger.d('[OfflineSyncService]', 'Closing session $sessionId');

    if (await _remoteSessionState(sessionId) == 'closed') {
      logger.d(
        '[OfflineSyncService]',
        'Session $sessionId is already closed; close replay reconciled',
      );
      return;
    }

    await _odooClient!.call(
      model: 'collection.session',
      method: 'action_session_close',
      ids: [sessionId],
    );

    logger.d('[OfflineSyncService]', 'Session $sessionId closed successfully');
  }

  Future<String?> _remoteSessionState(int sessionId) async {
    final rows = await _odooClient!.searchRead(
      model: 'collection.session',
      domain: [
        ['id', '=', sessionId],
      ],
      fields: const ['state'],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Collection session $sessionId does not exist');
    }
    return rows.first['state'] as String?;
  }
}
