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

    // 1. Create session
    final remoteId = await _odooClient!.create(
      model: 'collection.session',
      values: odooValues,
    );

    if (remoteId == null) {
      throw Exception('Failed to create collection.session - returned null');
    }

    logger.d('[OfflineSyncService]', 'Session created: $remoteId, opening...');

    // 2. Open session
    await _odooClient.call(
      model: 'collection.session',
      method: 'action_session_open',
      ids: [remoteId],
    );

    logger.d('[OfflineSyncService]', 'Session $remoteId opened successfully');

    // 3. Update local session with remote ID
    if (localId != null && sessionUuid != null) {
      await _sessionManager.updateSessionIdByUuid(sessionUuid, remoteId);
      logger.d(
        '[OfflineSyncService]',
        'Updated local session $localId -> $remoteId',
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

    await _odooClient!.call(
      model: 'collection.session',
      method: 'action_session_close',
      ids: [sessionId],
    );

    logger.d('[OfflineSyncService]', 'Session $sessionId closed successfully');
  }
}
