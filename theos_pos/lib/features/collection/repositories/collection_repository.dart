import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

// import 'package:odoo_sdk/odoo_sdk.dart';
import '../../../core/database/repositories/base_repository.dart';
import '../../users/repositories/user_repository.dart';
// Models
import '../../../core/errors/errors.dart';

/// Repository for collection-related operations
///
/// Handles: Collection Configs, Sessions, Payments, Cash Outs, Deposits
///
/// Uses [CollectionSessionManager] for all session database operations
/// through the OdooModelManager pattern with extension methods.
class CollectionRepository extends BaseRepository with OfflineSupport {
  final UserRepository _userRepository;
  final OfflineQueueDataSource? _offlineQueue;
  final CollectionSessionManager _sessionManager;
  final AccountPaymentManager _paymentManager;
  final CashOutManager _cashOutManager;
  final CollectionSessionCashManager _sessionCashManager;
  final CollectionSessionDepositManager _sessionDepositManager;

  CollectionRepository({
    required super.odooClient,
    required super.db,
    required UserRepository userRepository,
    required CollectionSessionManager sessionManager,
    required AccountPaymentManager paymentManager,
    required CashOutManager cashOutManager,
    required CollectionSessionCashManager sessionCashManager,
    required CollectionSessionDepositManager sessionDepositManager,
    OfflineQueueDataSource? offlineQueue,
  }) : _userRepository = userRepository,
       _sessionManager = sessionManager,
       _paymentManager = paymentManager,
       _cashOutManager = cashOutManager,
       _sessionCashManager = sessionCashManager,
       _sessionDepositManager = sessionDepositManager,
       _offlineQueue = offlineQueue;

  /// Access to the session manager for advanced operations
  CollectionSessionManager get sessionManager => _sessionManager;

  // ============ Collection Configs ============

  /// Sync collection configs and return them
  /// Returns cached configs if offline
  Future<List<CollectionConfig>> syncCollectionConfigs() async {
    if (!isOnline) {
      return collectionConfigManager.searchLocal();
    }

    try {
      final currentUser = await _userRepository.getCurrentUser();
      if (currentUser == null) {
        return collectionConfigManager.searchLocal();
      }

      final data = await odooClient!.searchRead(
        model: 'collection.config',
        fields: collectionConfigManager.odooFields,
        domain: [
          [
            'user_ids',
            'in',
            [currentUser.id],
          ],
        ],
      );

      final configs = data.map((e) => collectionConfigManager.fromOdoo(e)).toList();

      final accessibleIds = configs.map((c) => c.id).toList();
      await _deleteConfigsNotIn(accessibleIds);

      if (configs.isNotEmpty) {
        await collectionConfigManager.upsertLocalBatch(configs);
        await syncCollectionSessions();
      }
    } catch (e) {
      // Error syncing collection configs
    }
    return collectionConfigManager.searchLocal();
  }


  /// Delete collection configs whose IDs are NOT in the given list
  Future<void> _deleteConfigsNotIn(List<int> keepIds) async {
    if (keepIds.isEmpty) {
      await collectionConfigManager.deleteAllLocal();
      return;
    }
    final allConfigs = await collectionConfigManager.searchLocal();
    for (final config in allConfigs) {
      if (!keepIds.contains(config.id)) {
        await collectionConfigManager.deleteLocal(config.id);
      }
    }
  }

  // ============ Collection Sessions ============

  /// Sync collection sessions
  /// Does nothing if offline
  Future<void> syncCollectionSessions() async {
    if (!isOnline) return;

    try {
      final data = await odooClient!.searchRead(
        model: 'collection.session',
        fields: collectionSessionManager.odooFields,
        domain: [
          ['state', '!=', 'closed'],
        ],
        limit: 20,
      );

      if (data.isNotEmpty) {
        final sessions = data
            .map((e) => collectionSessionManager.fromOdoo(e))
            .toList();
        for (final session in sessions) {
          await _sessionManager.smartUpsert(session);
        }
        await _sessionManager.cleanupDuplicateSessions();
      }
    } catch (e) {
      // Error syncing collection sessions
    }
  }

  /// Get collection session by ID
  ///
  /// OFFLINE-FIRST: Reads from local DB first, syncs in background if online.
  ///
  /// [forceRefresh] - If true, waits for sync before returning.
  Future<CollectionSession?> getCollectionSession(
    int sessionId, {
    bool forceRefresh = false,
  }) async {
    // 1. OFFLINE-FIRST: Get local session first (always)
    final localSession = await _sessionManager.getSessionById(sessionId);

    // For local-only sessions (negative IDs or not synced), return local data
    if (sessionId < 0 || (localSession != null && !localSession.isSynced)) {
      return localSession;
    }

    // 2. If forceRefresh, wait for sync; otherwise sync in background
    if (forceRefresh) {
      return await _syncAndGetSession(sessionId, localSession);
    } else {
      // Sync in background, return local immediately
      _syncSessionInBackground(sessionId);
      return localSession;
    }
  }

  /// Sync session from Odoo and return updated data
  Future<CollectionSession?> _syncAndGetSession(
    int sessionId,
    CollectionSession? localSession,
  ) async {
    if (!isOnline) return localSession;

    try {
      final data = await odooClient!.searchRead(
        model: 'collection.session',
        fields: collectionSessionManager.odooFields,
        domain: [
          ['id', '=', sessionId],
        ],
        limit: 1,
      );

      if (data.isNotEmpty) {
        final session = collectionSessionManager.fromOdoo(data.first);
        await _sessionManager.smartUpsert(session);
        return session;
      }

      return localSession;
    } catch (e) {
      // Offline or error, return local data
      return localSession;
    }
  }

  /// Sync session from Odoo in background
  Future<void> _syncSessionInBackground(int sessionId) async {
    if (!isOnline) return;

    try {
      final data = await odooClient!.searchRead(
        model: 'collection.session',
        fields: collectionSessionManager.odooFields,
        domain: [
          ['id', '=', sessionId],
        ],
        limit: 1,
      );

      if (data.isNotEmpty) {
        final session = collectionSessionManager.fromOdoo(data.first);
        await _sessionManager.smartUpsert(session);
      }
    } catch (e) {
      // Offline or error - ignore, local data is already returned
    }
  }

  /// Fetch session from Odoo WITHOUT saving to local DB
  /// Returns null if offline
  Future<CollectionSession?> fetchSessionFromOdoo(int sessionId) async {
    if (!isOnline) return null;

    try {
      final data = await odooClient!.searchRead(
        model: 'collection.session',
        fields: collectionSessionManager.odooFields,
        domain: [
          ['id', '=', sessionId],
        ],
        limit: 1,
      );

      if (data.isNotEmpty) {
        final session = collectionSessionManager.fromOdoo(data.first);
        return session;
      }
    } catch (e) {
      // Error fetching session from Odoo
    }

    return null;
  }

  /// Update collection session locally
  Future<void> updateCollectionSession(CollectionSession session) async {
    await _sessionManager.smartUpsert(session);
  }

  /// Create new collection session in Odoo (or queue if offline)
  ///
  /// If online: creates session in Odoo and opens it
  /// If offline: creates local session and queues for sync
  Future<int> createCollectionSession({
    required int configId,
    required int userId,
    required double cashRegisterBalanceStart,
    String? sessionUuid,
  }) async {
    try {
      final Map<String, dynamic> values = {
        'config_id': configId,
        'user_id': userId,
        'cash_register_balance_start': cashRegisterBalanceStart,
      };

      if (sessionUuid != null) {
        values['session_uuid'] = sessionUuid;
      }

      final sessionId = await odooClient!.create(
        model: 'collection.session',
        values: values,
      );

      if (sessionId == null) {
        throw Exception('Failed to create session in Odoo - returned null');
      }

      await odooClient!.call(
        model: 'collection.session',
        method: 'action_session_open',
        ids: [sessionId],
      );

      return sessionId;
    } catch (e) {
      rethrow;
    }
  }

  /// Create collection session offline-first
  ///
  /// Creates a local session with negative ID and queues for sync.
  /// Returns the local (negative) session ID.
  Future<int> createCollectionSessionOffline({
    required int configId,
    required int userId,
    required double cashRegisterBalanceStart,
    required String sessionUuid,
  }) async {
    // Generate negative local ID
    final localId = -DateTime.now().millisecondsSinceEpoch % 1000000000;

    // Create local session
    final localSession = CollectionSession(
      id: localId,
      configId: configId,
      name: 'Sesión (Pendiente)',
      userId: userId,
      state: SessionState.opened,
      cashRegisterBalanceStart: cashRegisterBalanceStart,
      startAt: DateTime.now(),
      isSynced: false,
      sessionUuid: sessionUuid,
      syncRetryCount: 0,
    );

    await _sessionManager.smartUpsert(localSession);

    // Queue for sync with critical priority
    if (_offlineQueue != null) {
      await _offlineQueue.queueOperation(
        model: 'collection.session',
        method: 'session_create_and_open',
        values: {
          'local_id': localId,
          'config_id': configId,
          'user_id': userId,
          'cash_register_balance_start': cashRegisterBalanceStart,
          'session_uuid': sessionUuid,
        },
        priority: OfflinePriority.critical,
      );
    }

    return localId;
  }

  /// Open collection session
  ///
  /// OFFLINE-FIRST:
  /// 1. Actualiza estado local primero
  /// 2. Si online, sincroniza con Odoo
  /// 3. Si offline o falla sync, encola para procesamiento posterior
  Future<CollectionSession?> openCollectionSession(
    int sessionId,
    double cashAmount,
  ) async {
    // Para sesiones locales (negativas), solo actualizar localmente
    if (sessionId < 0) {
      return await _openCollectionSessionLocally(sessionId, cashAmount);
    }

    // If offline, use local mode
    if (!isOnline) {
      return await _openCollectionSessionLocally(sessionId, cashAmount);
    }

    try {
      // Intentar sincronizar con Odoo primero
      final writeResult = await odooClient!.write(
        model: 'collection.session',
        ids: [sessionId],
        values: {'cash_register_balance_start': cashAmount},
      );

      if (!writeResult) {
        throw Exception('Failed to write cash_register_balance_start');
      }

      await odooClient!.call(
        model: 'collection.session',
        method: 'action_session_open',
        ids: [sessionId],
      );

      return await getCollectionSession(sessionId, forceRefresh: true);
    } catch (e) {
      // Si falla la sincronización, usar modo offline
      logger.w('[CollectionRepo]', 'Failed to open session online, using offline: $e');
      return await _openCollectionSessionLocally(sessionId, cashAmount);
    }
  }

  /// Abre la sesión localmente y encola para sincronización
  Future<CollectionSession?> _openCollectionSessionLocally(
    int sessionId,
    double cashAmount,
  ) async {
    // Obtener sesión local
    final session = await _sessionManager.getSessionById(sessionId);
    if (session == null) {
      throw Exception('Session $sessionId not found locally');
    }

    // Actualizar estado local
    final updatedSession = session.copyWith(
      state: SessionState.opened,
      cashRegisterBalanceStart: cashAmount,
      startAt: DateTime.now(),
      isSynced: false,
    );
    await _sessionManager.smartUpsert(updatedSession);

    // Encolar para sincronización si es una sesión con ID de Odoo
    if (_offlineQueue != null && sessionId > 0) {
      await _offlineQueue.queueOperation(
        model: 'collection.session',
        method: 'session_open',
        recordId: sessionId,
        values: {
          'session_id': sessionId,
          'cash_register_balance_start': cashAmount,
        },
        priority: OfflinePriority.critical,
      );
      logger.d('[CollectionRepo]', 'Session open operation queued for sync');
    }

    return updatedSession;
  }

  /// Start closing control for session
  Future<CollectionSession?> startSessionClosingControl(
    int sessionId,
    double cashRealAmount,
  ) async {
    // If offline, use offline mode
    if (!isOnline) {
      return await startSessionClosingControlOffline(sessionId, cashRealAmount);
    }

    try {
      final writeResult = await odooClient!.write(
        model: 'collection.session',
        ids: [sessionId],
        values: {'cash_register_balance_end_real': cashRealAmount},
      );

      if (!writeResult) {
        throw Exception('Failed to write cash_register_balance_end_real');
      }

      await odooClient!.call(
        model: 'collection.session',
        method: 'action_session_closing_control',
        ids: [sessionId],
      );

      return await getCollectionSession(sessionId, forceRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  /// Close collection session
  Future<CollectionSession?> closeCollectionSession(int sessionId) async {
    // If offline, use offline mode
    if (!isOnline) {
      return await closeCollectionSessionOffline(sessionId);
    }

    try {
      await odooClient!.call(
        model: 'collection.session',
        method: 'action_session_close',
        ids: [sessionId],
      );

      return await getCollectionSession(sessionId, forceRefresh: true);
    } catch (e) {
      rethrow;
    }
  }

  /// Start closing control offline
  ///
  /// Updates local session and queues operation for sync
  Future<CollectionSession?> startSessionClosingControlOffline(
    int sessionId,
    double cashRealAmount,
  ) async {
    // Update local session state
    final session = await _sessionManager.getSessionById(sessionId);
    if (session == null) {
      throw Exception('Session $sessionId not found locally');
    }

    final updatedSession = session.copyWith(
      state: SessionState.closingControl,
      cashRegisterBalanceEndReal: cashRealAmount,
      isSynced: false,
    );
    await _sessionManager.smartUpsert(updatedSession);

    // Queue for sync
    if (_offlineQueue != null && sessionId > 0) {
      await _offlineQueue.queueOperation(
        model: 'collection.session',
        method: 'session_closing_control',
        recordId: sessionId,
        values: {
          'session_id': sessionId,
          'cash_register_balance_end_real': cashRealAmount,
        },
        priority: OfflinePriority.critical,
      );
    }

    return updatedSession;
  }

  /// Close collection session offline
  ///
  /// Updates local session and queues operation for sync
  Future<CollectionSession?> closeCollectionSessionOffline(
    int sessionId,
  ) async {

    // Update local session state
    final session = await _sessionManager.getSessionById(sessionId);
    if (session == null) {
      throw Exception('Session $sessionId not found locally');
    }

    final updatedSession = session.copyWith(
      state: SessionState.closed,
      stopAt: DateTime.now(),
      isSynced: false,
    );
    await _sessionManager.smartUpsert(updatedSession);

    // Queue for sync
    if (_offlineQueue != null && sessionId > 0) {
      await _offlineQueue.queueOperation(
        model: 'collection.session',
        method: 'session_close',
        recordId: sessionId,
        values: {'session_id': sessionId},
        priority: OfflinePriority.critical,
      );
    }

    return updatedSession;
  }

  /// Get failed sync sessions
  Future<List<CollectionSession>> getFailedSyncSessions({
    int maxRetries = 3,
  }) async {
    try {
      final allSessions = await _sessionManager.getAllSessions();
      return allSessions
          .where((s) => s.id < 0 && (s.syncRetryCount) >= maxRetries)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Retry syncing unsynced sessions
  Future<int> retryUnsyncedSessions({
    int maxRetries = 3,
    bool force = false,
  }) async {
    try {
      final allSessions = await _sessionManager.getAllSessions();
      final unsyncedSessions = allSessions
          .where((s) => s.id < 0 && (force || s.syncRetryCount < maxRetries))
          .toList();

      if (unsyncedSessions.isEmpty) {
        return 0;
      }

      int successCount = 0;
      for (final localSession in unsyncedSessions) {
        try {
          if (localSession.configId == null) {
            continue;
          }

          final updatedSession = localSession.copyWith(
            syncRetryCount: localSession.syncRetryCount + 1,
            lastSyncAttempt: DateTime.now(),
          );
          await _sessionManager.smartUpsert(updatedSession);

          final openingCash = await _sessionCashManager.getBySessionAndType(
            sessionId: localSession.id,
            cashType: 'opening',
          );
          final openingBalance = openingCash?.cashTotal ?? 0.0;

          final createdSessionId = await createCollectionSession(
            configId: localSession.configId!,
            userId: localSession.userId ?? 2,
            cashRegisterBalanceStart: openingBalance,
            sessionUuid: localSession.sessionUuid,
          );

          if (localSession.sessionUuid != null) {
            await _sessionManager.updateSessionIdByUuid(
              localSession.sessionUuid!,
              createdSessionId,
            );

            final odooSession = await getCollectionSession(
              createdSessionId,
              forceRefresh: true,
            );
            if (odooSession != null) {
              await _sessionManager.smartUpsert(odooSession);
              successCount++;
            }
          }
        } catch (e) {
          // Failed to sync session
        }
      }

      return successCount;
    } catch (e) {
      return 0;
    }
  }

  // ============ Session Cash ============

  /// Save session cash count
  Future<CollectionSessionCash> saveSessionCash(
    CollectionSessionCash cash,
  ) async {
    if (cash.collectionSessionId == null) {
      throw Exception('collection_session_id is required but was null');
    }

    // If offline, save locally and queue for later sync
    if (!isOnline) {
      final unsyncedCash = cash.copyWith(isSynced: false);
      await _sessionCashManager.upsertSessionCash(unsyncedCash);

      if (_offlineQueue != null) {
        final queueValues = collectionSessionCashManager.toOdoo(cash);
        queueValues.remove('id');
        await _offlineQueue.queueOperation(
          model: 'collection.session.cash',
          method: cash.id > 0 ? 'write' : 'create',
          recordId: cash.id > 0 ? cash.id : null,
          values: queueValues,
        );
        logger.i(
          '[CollectionRepository] Offline: queued session cash for later sync '
          '(session=${cash.collectionSessionId}, type=${cash.cashType})',
        );
      }

      return unsyncedCash;
    }

    try {
      final existing = await odooClient!.searchRead(
        model: 'collection.session.cash',
        domain: [
          ['collection_session_id', '=', cash.collectionSessionId],
          [
            'cash_type',
            '=',
            cash.cashType == CashType.closing ? 'closing' : 'opening',
          ],
        ],
        fields: ['id'],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final odooId = existing[0]['id'] as int;

        final updateValues = collectionSessionCashManager.toOdoo(cash);
        updateValues.remove('id');

        final writeResult = await odooClient!.write(
          model: 'collection.session.cash',
          ids: [odooId],
          values: updateValues,
        );

        if (!writeResult) {
          throw Exception('Write returned false - update may have failed');
        }

        final updatedCash = cash.copyWith(id: odooId, isSynced: true);
        await _sessionCashManager.upsertSessionCash(updatedCash);

        return updatedCash;
      } else {
        final createValues = collectionSessionCashManager.toOdoo(cash);
        createValues.remove('id');

        final odooId = await odooClient!.create(
          model: 'collection.session.cash',
          values: createValues,
        );

        if (odooId == null) {
          throw Exception('Create returned null - creation failed');
        }

        final syncedCash = cash.copyWith(id: odooId, isSynced: true);
        await _sessionCashManager.upsertSessionCash(syncedCash);

        return syncedCash;
      }
    } catch (e) {
      // Save locally with isSynced=false
      final unsyncedCash = cash.copyWith(isSynced: false);
      await _sessionCashManager.upsertSessionCash(unsyncedCash);

      // Queue the operation for later sync instead of rethrowing
      if (_offlineQueue != null) {
        final queueValues = collectionSessionCashManager.toOdoo(cash);
        queueValues.remove('id');
        await _offlineQueue.queueOperation(
          model: 'collection.session.cash',
          method: cash.id > 0 ? 'write' : 'create',
          recordId: cash.id > 0 ? cash.id : null,
          values: queueValues,
        );
        logger.i(
          '[CollectionRepository] Queued session cash for later sync '
          '(session=${cash.collectionSessionId}, type=${cash.cashType})',
        );
      }

      return unsyncedCash;
    }
  }

  /// Save session cash locally only
  Future<void> saveSessionCashLocally(CollectionSessionCash cash) async {
    final localCash = cash.copyWith(isSynced: false);
    await _sessionCashManager.upsertSessionCash(localCash);
  }

  /// Update sessionId of locally stored cash count
  Future<void> updateSessionCashLocalSessionId({
    required int oldSessionId,
    required int newSessionId,
  }) async {
    try {
      final openingCash = await _sessionCashManager.getBySessionAndType(
        sessionId: oldSessionId,
        cashType: 'opening',
      );
      final closingCash = await _sessionCashManager.getBySessionAndType(
        sessionId: oldSessionId,
        cashType: 'closing',
      );

      if (openingCash != null) {
        final updatedOpening = openingCash.copyWith(
          collectionSessionId: newSessionId,
        );
        await _sessionCashManager.upsertSessionCash(updatedOpening);
      }

      if (closingCash != null) {
        final updatedClosing = closingCash.copyWith(
          collectionSessionId: newSessionId,
        );
        await _sessionCashManager.upsertSessionCash(updatedClosing);
      }
    } catch (e) {
      // Error actualizando sessionId de cash count
    }
  }

  /// Get session cash details
  ///
  /// OFFLINE-FIRST: Reads from local DB first, syncs in background if online.
  Future<CollectionSessionCash?> getSessionCashDetails({
    required int sessionId,
    required CashType cashType,
  }) async {
    final cashTypeStr = cashType == CashType.closing ? 'closing' : 'opening';

    // 1. OFFLINE-FIRST: Read from local first
    final localCash = await _sessionCashManager.getBySessionAndType(
      sessionId: sessionId,
      cashType: cashTypeStr,
    );

    // For local-only sessions, return local data only
    if (sessionId < 0) {
      return localCash;
    }

    // 2. Sync from Odoo in background
    _syncSessionCashInBackground(sessionId, cashTypeStr);

    // 3. Return local data immediately
    return localCash;
  }

  /// Sync session cash from Odoo in background
  Future<void> _syncSessionCashInBackground(
    int sessionId,
    String cashTypeStr,
  ) async {
    if (!isOnline) return;

    try {
      final results = await odooClient!.searchRead(
        model: 'collection.session.cash',
        domain: [
          ['collection_session_id', '=', sessionId],
          ['cash_type', '=', cashTypeStr],
        ],
        fields: [
          'id',
          'collection_session_id',
          'cash_type',
          'bills_100',
          'bills_50',
          'bills_20',
          'bills_10',
          'bills_5',
          'bills_1',
          'coins_1',
          'coins_50',
          'coins_25',
          'coins_10',
          'coins_5',
          'coins_1_cent',
          'notes',
        ],
        limit: 1,
        order: 'id desc',
      );

      if (results.isNotEmpty) {
        final cash = collectionSessionCashManager.fromOdoo(results[0]);
        await _sessionCashManager.upsertSessionCash(cash);
      }
    } catch (e) {
      // Offline or error - ignore, local data is already returned
    }
  }

  // ============ Payments & Cash Outs ============

  /// Get session payments
  Future<List<AccountPayment>> getSessionPayments(int sessionId) async {
    return _paymentManager.getBySessionId(sessionId);
  }

  /// Create payment offline-first
  ///
  /// Creates a local payment and queues it for sync.
  /// Returns the created payment with local ID.
  Future<AccountPayment> createPaymentOffline({
    required int collectionSessionId,
    required int partnerId,
    required int journalId,
    required double amount,
    required String paymentUuid,
    int? invoiceId,
    int? paymentMethodLineId,
    String? paymentType,
    String? paymentOriginType,
    String? paymentMethodCategory,
    String? ref,
  }) async {
    // Create local payment (with negative ID to indicate offline)
    final localId = -DateTime.now().millisecondsSinceEpoch % 1000000000;

    final payment = AccountPayment(
      id: localId,
      paymentUuid: paymentUuid,
      collectionSessionId: collectionSessionId,
      partnerId: partnerId,
      journalId: journalId,
      paymentMethodLineId: paymentMethodLineId,
      amount: amount,
      paymentType: paymentType ?? 'inbound',
      state: 'draft',
      paymentOriginType: paymentOriginType,
      paymentMethodCategory: paymentMethodCategory,
      invoiceId: invoiceId,
      date: DateTime.now(),
      ref: ref,
      isSynced: false,
      lastSyncDate: null,
    );

    await _paymentManager.upsertLocal(payment);

    // Queue for sync with high priority
    if (_offlineQueue != null) {
      await _offlineQueue.queueOperation(
        model: 'account.payment',
        method: 'payment_create',
        values: {
          'local_id': localId,
          'collection_session_id': collectionSessionId,
          'partner_id': partnerId,
          'journal_id': journalId,
          'payment_method_line_id': paymentMethodLineId,
          'amount': amount,
          'payment_type': paymentType ?? 'inbound',
          'payment_origin_type': paymentOriginType,
          'payment_method_category': paymentMethodCategory,
          'invoice_id': invoiceId,
          'ref': ref,
          'payment_uuid': paymentUuid,
        },
        priority: OfflinePriority.high,
      );
    }

    return payment;
  }

  /// Get payment by UUID
  Future<AccountPayment?> getPaymentByUuid(String uuid) async {
    return (await _paymentManager.searchLocal(
      domain: [['payment_uuid', '=', uuid]],
      limit: 1,
    )).firstOrNull;
  }

  /// Update payment ID by UUID after sync
  Future<void> updatePaymentIdByUuid(String uuid, int newOdooId) async {
    final existing = (await _paymentManager.searchLocal(
      domain: [['payment_uuid', '=', uuid]],
      limit: 1,
    )).firstOrNull;
    if (existing == null) {
      logger.w('[CollectionRepository] No payment found with UUID=$uuid');
      return;
    }
    final updated = existing.copyWith(
      id: newOdooId,
      isSynced: true,
      lastSyncDate: DateTime.now(),
    );
    await _paymentManager.upsertLocal(updated);
    logger.i('[CollectionRepository] Payment UUID=$uuid updated to ID=$newOdooId');
  }

  // ============ Partners (Offline Support) ============

  /// Create partner offline-first
  ///
  /// Creates a local partner and queues it for sync.
  /// Returns the local (negative) partner ID.
  Future<int> createPartnerOffline({
    required String name,
    required String partnerUuid,
    String? vat,
    String? email,
    String? phone,
    String? mobile,
    String? street,
    String? city,
    int? countryId,
    String? countryName,
  }) async {
    // Generate negative local ID
    final localId = -DateTime.now().millisecondsSinceEpoch % 1000000000;

    // Create local partner
    await clientManager.insertOfflinePartner(
      localOdooId: localId,
      name: name,
      partnerUuid: partnerUuid,
      vat: vat,
      email: email,
      phone: phone,
      mobile: mobile,
      street: street,
      city: city,
      countryId: countryId,
      countryName: countryName,
    );

    // Queue for sync with high priority
    if (_offlineQueue != null) {
      await _offlineQueue.queueOperation(
        model: 'res.partner',
        method: 'partner_create',
        values: {
          'local_id': localId,
          'partner_uuid': partnerUuid,
          'name': name,
          'vat': vat,
          'email': email,
          'phone': phone,
          'mobile': mobile,
          'street': street,
          'city': city,
          'country_id': countryId,
        },
        priority: OfflinePriority.high,
      );
    }

    return localId;
  }

  /// Get partner by UUID
  Future<dynamic> getPartnerByUuid(String uuid) async {
    return clientManager.getPartnerByUuid(uuid);
  }

  /// Update partner ID by UUID after sync
  Future<void> updatePartnerIdByUuid(String uuid, int newOdooId) async {
    await clientManager.updatePartnerIdByUuid(uuid, newOdooId);
  }

  /// Get session cash outs
  Future<List<CashOut>> getSessionCashOuts(int sessionId) async {
    return _cashOutManager.getBySessionId(sessionId);
  }

  /// Get session deposits
  Future<List<CollectionSessionDeposit>> getSessionDeposits(
    int sessionId,
  ) async {
    return _sessionDepositManager.getBySessionId(sessionId);
  }

  /// Create a new deposit for a collection session
  ///
  /// OFFLINE-FIRST: Saves locally first, then attempts direct Odoo sync.
  /// If online sync fails, queues the operation for later processing.
  Future<Either<Failure, CollectionSessionDeposit>> createDeposit(
    CollectionSessionDeposit deposit,
  ) async {
    try {
      // Generate UUID if not present
      final depositWithUuid = deposit.uuid != null
          ? deposit
          : deposit.copyWith(uuid: const Uuid().v4());

      // Save locally first (offline-first)
      await _sessionDepositManager.upsertDeposit(depositWithUuid);

      // Try direct Odoo sync if online, queue on failure
      if (_offlineQueue != null) {
        if (isOnline && odooClient != null) {
          try {
            final odooId = await odooClient!.create(
              model: 'collection.session.deposit',
              values: {
                'collection_session_id': depositWithUuid.collectionSessionId,
                'session_uuid': depositWithUuid.sessionUuid,
                'deposit_date': depositWithUuid.depositDate?.toIso8601String(),
                'accounting_date': depositWithUuid.accountingDate?.toIso8601String(),
                'amount': depositWithUuid.amount,
                'deposit_type': depositWithUuid.depositType.name,
                'cash_amount': depositWithUuid.cashAmount,
                'check_amount': depositWithUuid.checkAmount,
                'check_count': depositWithUuid.checkCount,
                'bank_journal_id': depositWithUuid.bankJournalId,
                'bank_id': depositWithUuid.bankId,
                'deposit_slip_number': depositWithUuid.depositSlipNumber,
                'bank_reference': depositWithUuid.bankReference,
                'depositor_name': depositWithUuid.depositorName,
                'notes': depositWithUuid.notes,
                'user_id': depositWithUuid.userId,
                'uuid': depositWithUuid.uuid,
              },
            );

            // Update local record with Odoo ID and mark as synced
            final synced = depositWithUuid.copyWith(
              id: odooId ?? depositWithUuid.id,
              isSynced: true,
              lastSyncDate: DateTime.now(),
            );
            await _sessionDepositManager.upsertDeposit(synced);

            logger.d('[CollectionRepository]', 'Deposit created in Odoo: id=$odooId');
            return Right(synced);
          } catch (e) {
            // Direct sync failed — fall back to queue
            logger.w(
              '[CollectionRepository]',
              'Direct deposit create failed, queuing: $e',
            );
            await _queueDepositSync(depositWithUuid);
          }
        } else {
          // Offline — queue for later sync
          await _queueDepositSync(depositWithUuid);
        }
      }

      return Right(depositWithUuid);
    } catch (e) {
      logger.e('[CollectionRepository]', 'Error creating deposit: $e');
      return Left(CacheFailure(message: 'Error guardando depósito: $e'));
    }
  }

  /// Update an existing deposit
  ///
  /// OFFLINE-FIRST: Saves locally first, then attempts direct Odoo sync.
  /// If online sync fails, queues the operation for later processing.
  Future<Either<Failure, CollectionSessionDeposit>> updateDeposit(
    CollectionSessionDeposit deposit,
  ) async {
    try {
      // Mark as not synced since it was modified
      final updatedDeposit = deposit.copyWith(isSynced: false);

      // Save locally first (offline-first)
      await _sessionDepositManager.upsertDeposit(updatedDeposit);

      // Try direct Odoo sync if online, queue on failure
      if (_offlineQueue != null) {
        if (isOnline && odooClient != null && updatedDeposit.id > 0) {
          try {
            await odooClient!.write(
              model: 'collection.session.deposit',
              ids: [updatedDeposit.id],
              values: {
                'collection_session_id': updatedDeposit.collectionSessionId,
                'session_uuid': updatedDeposit.sessionUuid,
                'deposit_date': updatedDeposit.depositDate?.toIso8601String(),
                'accounting_date': updatedDeposit.accountingDate?.toIso8601String(),
                'amount': updatedDeposit.amount,
                'deposit_type': updatedDeposit.depositType.name,
                'cash_amount': updatedDeposit.cashAmount,
                'check_amount': updatedDeposit.checkAmount,
                'check_count': updatedDeposit.checkCount,
                'bank_journal_id': updatedDeposit.bankJournalId,
                'bank_id': updatedDeposit.bankId,
                'deposit_slip_number': updatedDeposit.depositSlipNumber,
                'bank_reference': updatedDeposit.bankReference,
                'depositor_name': updatedDeposit.depositorName,
                'notes': updatedDeposit.notes,
                'user_id': updatedDeposit.userId,
                'uuid': updatedDeposit.uuid,
              },
            );

            // Mark as synced after successful write
            final synced = updatedDeposit.copyWith(
              isSynced: true,
              lastSyncDate: DateTime.now(),
            );
            await _sessionDepositManager.upsertDeposit(synced);

            logger.d('[CollectionRepository]', 'Deposit updated in Odoo: id=${synced.id}');
            return Right(synced);
          } catch (e) {
            // Direct sync failed — fall back to queue
            logger.w(
              '[CollectionRepository]',
              'Direct deposit update failed, queuing: $e',
            );
            await _queueDepositSync(updatedDeposit);
          }
        } else {
          // Offline or new record — queue for later sync
          await _queueDepositSync(updatedDeposit);
        }
      }

      return Right(updatedDeposit);
    } catch (e) {
      logger.e('[CollectionRepository]', 'Error updating deposit: $e');
      return Left(CacheFailure(message: 'Error actualizando depósito: $e'));
    }
  }

  /// Queue deposit for sync with backend
  ///
  /// For new deposits (id <= 0 or no Odoo ID): queues a `create` operation.
  /// For existing deposits (id > 0): queues a `write` operation.
  Future<void> _queueDepositSync(CollectionSessionDeposit deposit) async {
    if (_offlineQueue == null) return;

    final isNew = deposit.id <= 0;
    final method = isNew ? 'create' : 'write';

    final values = <String, dynamic>{
      'uuid': deposit.uuid,
      'collection_session_id': deposit.collectionSessionId,
      'session_uuid': deposit.sessionUuid,
      'deposit_date': deposit.depositDate?.toIso8601String(),
      'accounting_date': deposit.accountingDate?.toIso8601String(),
      'amount': deposit.amount,
      'deposit_type': deposit.depositType.name,
      'cash_amount': deposit.cashAmount,
      'check_amount': deposit.checkAmount,
      'check_count': deposit.checkCount,
      'bank_journal_id': deposit.bankJournalId,
      'bank_id': deposit.bankId,
      'state': deposit.state,
      'deposit_slip_number': deposit.depositSlipNumber,
      'bank_reference': deposit.bankReference,
      'depositor_name': deposit.depositorName,
      'notes': deposit.notes,
      'user_id': deposit.userId,
    };

    if (isNew) {
      values['local_id'] = deposit.id;
    }

    await _offlineQueue.queueOperation(
      model: 'collection.session.deposit',
      method: method,
      recordId: isNew ? null : deposit.id,
      values: values,
      priority: OfflinePriority.high,
    );

    logger.d(
      '[CollectionRepository]',
      'Deposit queued for sync ($method): id=${deposit.id}, uuid=${deposit.uuid}',
    );
  }

  // ============ Local Database Access (for UI screens) ============

  /// Get all collection sessions from local database
  Future<List<CollectionSession>> getCollectionSessions() async {
    return _sessionManager.getAllSessions();
  }

  /// Get the active (not closed) session for a user
  ///
  /// OFFLINE-FIRST: Reads from local DB first, syncs in background if online.
  /// Returns null if no active session exists.
  Future<CollectionSession?> getActiveUserSession(int userId) async {
    // 1. OFFLINE-FIRST: Always read from local DB first
    final localSessions = await _sessionManager.getAllSessions();
    final localActive = localSessions.where(
      (s) =>
          s.userId == userId &&
          s.state != SessionState.closed,
    ).toList();

    CollectionSession? localSession;
    if (localActive.isNotEmpty) {
      localActive.sort((a, b) => (b.startAt ?? DateTime.now())
          .compareTo(a.startAt ?? DateTime.now()));
      localSession = localActive.first;
    }

    // 2. Sync from Odoo in background (don't block UI)
    _syncActiveSessionInBackground(userId, localSession);

    // 3. Return local data immediately
    return localSession;
  }

  /// Sync active session from Odoo in background
  /// Updates local DB if server has newer data
  Future<void> _syncActiveSessionInBackground(
    int userId,
    CollectionSession? currentLocal,
  ) async {
    if (!isOnline) return;

    try {
      final result = await odooClient!.searchRead(
        model: 'collection.session',
        domain: [
          ['user_id', '=', userId],
          ['state', 'not in', ['closed']],
        ],
        fields: collectionSessionManager.odooFields,
        order: 'start_at desc',
        limit: 1,
      );

      if (result.isNotEmpty) {
        final serverSession = collectionSessionManager.fromOdoo(result[0]);

        // Update local if server has this session
        await _sessionManager.smartUpsert(serverSession);

        // If local had a different/older session, merge or keep
        if (currentLocal != null &&
            currentLocal.id != serverSession.id &&
            currentLocal.id > 0) {
          // Local session exists but is different - keep both
          // Server session is now in local DB
        }
      }
    } catch (e) {
      // Offline or error - ignore, local data is already returned
    }
  }

  /// Get session cash by type from local database
  Future<CollectionSessionCash?> getSessionCashByType(
    int sessionId,
    CashType cashType,
  ) async {
    final cashTypeStr = cashType == CashType.closing ? 'closing' : 'opening';
    return _sessionCashManager.getBySessionAndType(
      sessionId: sessionId,
      cashType: cashTypeStr,
    );
  }

  /// Get collection session by UUID from local database
  Future<CollectionSession?> getCollectionSessionByUuid(String uuid) async {
    return _sessionManager.getSessionByUuid(uuid);
  }

  /// Update local session with Odoo data by UUID
  Future<void> updateSessionFromOdooByUuid(
    String uuid,
    CollectionSession odooSession,
  ) async {
    await _sessionManager.updateFromOdooByUuid(uuid, odooSession);
  }

  // ============ Business Logic Operations (moved from usecases) ============

  /// Sync a local session with Odoo
  ///
  /// Business logic:
  /// 1. Validates session is not already synced
  /// 2. Gets opening cash details
  /// 3. Creates session in Odoo
  /// 4. Updates local with Odoo data
  Future<Either<Failure, CollectionSession>> syncLocalSession({
    required CollectionSession localSession,
    required CollectionConfig config,
  }) async {
    try {
      // Business validation
      if (localSession.isSynced) {
        return Left(
          ValidationFailure(message: 'La sesión ya está sincronizada'),
        );
      }

      if (localSession.sessionUuid == null) {
        return Left(
          ValidationFailure(
            message: 'La sesión no tiene UUID para sincronizar',
          ),
        );
      }

      if (config.id != localSession.configId) {
        return Left(
          ValidationFailure(
            message:
                'El config ID no coincide con la sesión: config=${config.id}, session.configId=${localSession.configId}',
          ),
        );
      }

      // Get opening cash details from local DB
      final openingCash = await getSessionCashDetails(
        sessionId: localSession.id,
        cashType: CashType.opening,
      );

      final openingBalance =
          openingCash?.cashTotal ?? localSession.cashRegisterBalanceStart;

      // Create session in Odoo
      final createdSessionId = await createCollectionSession(
        configId: config.id,
        userId: localSession.userId ?? 2,
        cashRegisterBalanceStart: openingBalance,
        sessionUuid: localSession.sessionUuid,
      );

      // Fetch complete session from Odoo
      final odooSession = await fetchSessionFromOdoo(createdSessionId);

      if (odooSession == null) {
        return Left(
          ServerFailure(
            message: 'No se pudo obtener la sesión de Odoo después de crearla',
            statusCode: 404,
          ),
        );
      }

      // Update local session with Odoo data
      await updateSessionFromOdooByUuid(localSession.sessionUuid!, odooSession);

      // Update cash count session ID if exists
      if (openingCash != null) {
        await updateSessionCashLocalSessionId(
          oldSessionId: localSession.id,
          newSessionId: createdSessionId,
        );

        // Sync cash with Odoo
        final cashWithRealId = openingCash.copyWith(
          collectionSessionId: createdSessionId,
        );
        await saveSessionCash(cashWithRealId);
      }

      return Right(odooSession);
    } on ValidationFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Error al sincronizar sesión: $e',
          originalError: e,
        ),
      );
    }
  }

  /// Register opening cash with business validation
  ///
  /// Business logic:
  /// 1. Validates cash type is 'opening'
  /// 2. Validates amount is not negative
  /// 3. Opens session if in opening_control state
  Future<Either<Failure, CollectionSession>> registerOpeningCash({
    required int sessionId,
    required CollectionSessionCash cash,
  }) async {
    try {
      // Get current session
      final currentSession = await getCollectionSession(sessionId);

      if (currentSession == null) {
        return Left(
          NotFoundFailure(
            message: 'Sesión no encontrada: $sessionId',
            entityType: 'CollectionSession',
            entityId: sessionId,
          ),
        );
      }

      // Business validation - cash must be for opening
      if (cash.cashType != CashType.opening) {
        return Left(
          ValidationFailure(
            message:
                'El tipo de efectivo debe ser "opening" para registrar fondo de apertura',
          ),
        );
      }

      // Validate cash total is not negative
      if (cash.cashTotal < 0) {
        return Left(
          ValidationFailure(
            message: 'El total de efectivo no puede ser negativo',
          ),
        );
      }

      // Ensure cash is linked to this session
      final cashToSave = cash.copyWith(collectionSessionId: sessionId);

      // Save cash count
      await saveSessionCash(cashToSave);

      // If session is in opening_control state, open it
      if (currentSession.state == SessionState.openingControl) {
        final updatedSession = await openCollectionSession(
          sessionId,
          cashToSave.cashTotal,
        );

        if (updatedSession == null) {
          return Left(
            ServerFailure(
              message:
                  'No se pudo obtener la sesión actualizada después de abrirla',
            ),
          );
        }

        return Right(updatedSession);
      }

      // Otherwise, just refresh and return the session
      final refreshedSession = await getCollectionSession(
        sessionId,
        forceRefresh: true,
      );

      if (refreshedSession == null) {
        return Left(
          ServerFailure(message: 'No se pudo obtener la sesión actualizada'),
        );
      }

      return Right(refreshedSession);
    } on ValidationFailure catch (e) {
      return Left(e);
    } on NotFoundFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Error al registrar fondo de apertura: $e',
          originalError: e,
        ),
      );
    }
  }

  /// Register closing cash with business validation
  ///
  /// Business logic:
  /// 1. Validates cash type is 'closing'
  /// 2. Validates amount is not negative
  /// 3. Starts closing control if session is opened
  Future<Either<Failure, CollectionSession>> registerClosingCash({
    required int sessionId,
    required CollectionSessionCash cash,
  }) async {
    try {
      // Get current session
      final currentSession = await getCollectionSession(sessionId);

      if (currentSession == null) {
        return Left(
          NotFoundFailure(
            message: 'Sesión no encontrada: $sessionId',
            entityType: 'CollectionSession',
            entityId: sessionId,
          ),
        );
      }

      // Business validation - cash must be for closing
      if (cash.cashType != CashType.closing) {
        return Left(
          ValidationFailure(
            message:
                'El tipo de efectivo debe ser "closing" para registrar efectivo de cierre',
          ),
        );
      }

      // Validate cash total is not negative
      if (cash.cashTotal < 0) {
        return Left(
          ValidationFailure(
            message: 'El total de efectivo no puede ser negativo',
          ),
        );
      }

      // Ensure cash is linked to this session
      final cashToSave = cash.copyWith(collectionSessionId: sessionId);

      // Save cash count
      await saveSessionCash(cashToSave);

      // If session is opened, start closing control
      if (currentSession.state == SessionState.opened) {
        final updatedSession = await startSessionClosingControl(
          sessionId,
          cashToSave.cashTotal,
        );

        if (updatedSession == null) {
          return Left(
            ServerFailure(
              message:
                  'No se pudo obtener la sesión actualizada después de iniciar control de cierre',
            ),
          );
        }

        return Right(updatedSession);
      }

      // Otherwise, just refresh and return the session
      final refreshedSession = await getCollectionSession(
        sessionId,
        forceRefresh: true,
      );

      if (refreshedSession == null) {
        return Left(
          ServerFailure(message: 'No se pudo obtener la sesión actualizada'),
        );
      }

      return Right(refreshedSession);
    } on ValidationFailure catch (e) {
      return Left(e);
    } on NotFoundFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Error al registrar efectivo de cierre: $e',
          originalError: e,
        ),
      );
    }
  }
}
