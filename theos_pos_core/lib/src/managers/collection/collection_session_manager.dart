/// CollectionSessionManager extensions - Business methods beyond generated CRUD
///
/// The base CollectionSessionManager is generated in collection_session.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show logger;

import '../../models/collection/collection_session.model.dart';
import '../../database/database.dart';

const _uuid = Uuid();

/// Extension methods for CollectionSessionManager
extension CollectionSessionManagerBusiness on CollectionSessionManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  // ═══════════════════════════════════════════════════════════════════════════
  // Local Database Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get open session for current user
  Future<CollectionSession?> getOpenSession(int userId) async {
    final query = _db.select(_db.collectionSession)
      ..where((t) =>
          t.userId.equals(userId) &
          (t.state.equals('opened') | t.state.equals('opening_control')));
    final result = await query.getSingleOrNull();
    return result != null ? fromDrift(result) : null;
  }

  /// Get sessions by state
  Future<List<CollectionSession>> getByState(String state) async {
    final query = _db.select(_db.collectionSession)
      ..where((t) => t.state.equals(state))
      ..orderBy([(t) => drift.OrderingTerm.desc(t.startAt)]);
    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Smart Upsert & Deduplication (migrated from CollectionSessionDatasource)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Remove duplicate sessions that have the same odoo_id.
  /// Keeps the one with the most recent lastSyncDate.
  /// Also cleans up orphan temp sessions (odoo_id = -1) that have
  /// a synced counterpart with the same UUID.
  Future<void> cleanupDuplicateSessions() async {
    logger.d('[CollectionSessionManager]', 'Cleaning up duplicate sessions...');

    // Debug: list all sessions
    final allSessionsDebug = await _db.select(_db.collectionSession).get();
    logger.d(
      '[CollectionSessionManager]',
      'Total sessions in DB: ${allSessionsDebug.length}',
    );
    for (final s in allSessionsDebug) {
      logger.d(
        '[CollectionSessionManager]',
        'Session: id=${s.id}, odooId=${s.odooId}, uuid=${s.sessionUuid}, name="${s.name}"',
      );
    }

    // Get all sessions with positive odoo_id
    final allSessions = await (_db.select(
      _db.collectionSession,
    )..where((tbl) => tbl.odooId.isBiggerThanValue(0)))
        .get();

    // Group by odoo_id
    final Map<int, List<CollectionSessionData>> grouped = {};
    for (final session in allSessions) {
      final odooId = session.odooId;
      grouped.putIfAbsent(odooId, () => []);
      grouped[odooId]!.add(session);
    }

    // Find duplicates and remove them (keep the one with most recent sync)
    int removedCount = 0;
    for (final entry in grouped.entries) {
      if (entry.value.length > 1) {
        logger.w(
          '[CollectionSessionManager]',
          'Found ${entry.value.length} duplicates for odoo_id=${entry.key}',
        );

        // Sort by lastSyncDate descending (most recent first), then by id
        entry.value.sort((a, b) {
          final dateA = a.lastSyncDate ?? DateTime(1970);
          final dateB = b.lastSyncDate ?? DateTime(1970);
          final dateCompare = dateB.compareTo(dateA);
          if (dateCompare != 0) return dateCompare;
          return b.id.compareTo(a.id);
        });

        // Keep the first one (most recent), delete the rest
        for (int i = 1; i < entry.value.length; i++) {
          final toDelete = entry.value[i];
          logger.d(
            '[CollectionSessionManager]',
            'Deleting duplicate: id=${toDelete.id}, name=${toDelete.name}',
          );
          await (_db.delete(_db.collectionSession)
                ..where((tbl) => tbl.id.equals(toDelete.id)))
              .go();
          removedCount++;
        }
      }
    }

    // Also clean up orphan sessions with odoo_id = -1 that have a matching UUID
    // with a synced session (these are leftover temp sessions)
    final tempSessions = await (_db.select(
      _db.collectionSession,
    )..where((tbl) => tbl.odooId.equals(-1)))
        .get();

    for (final temp in tempSessions) {
      final syncedWithSameUuid = await (_db.select(_db.collectionSession)
            ..where((tbl) => tbl.sessionUuid.equals(temp.sessionUuid))
            ..where((tbl) => tbl.odooId.isBiggerThanValue(0)))
          .getSingleOrNull();

      if (syncedWithSameUuid != null) {
        logger.d(
          '[CollectionSessionManager]',
          'Deleting orphan temp session: id=${temp.id}, name=${temp.name} '
              '(synced version exists with odooId=${syncedWithSameUuid.odooId})',
        );
        await (_db.delete(_db.collectionSession)
              ..where((tbl) => tbl.id.equals(temp.id)))
            .go();
        removedCount++;
      }
    }

    logger.i(
      '[CollectionSessionManager]',
      'Cleaned up $removedCount duplicate/orphan sessions',
    );
  }

  /// Smart upsert: insert or update a collection session using multi-step matching.
  ///
  /// 1. If session has UUID from Odoo, check by UUID first
  /// 2. Check by odoo_id if it's a positive ID
  /// 3. Check by effective UUID (generated or from Odoo)
  /// 4. Insert new if no match found
  Future<void> smartUpsert(CollectionSession session) async {
    // Generate a stable UUID: use session.sessionUuid if from Odoo, otherwise generate
    final effectiveUuid = session.sessionUuid?.isNotEmpty == true
        ? session.sessionUuid!
        : (session.id > 0 ? 'odoo_${session.id}' : _uuid.v4());

    logger.d(
      '[CollectionSessionManager] Upserting session: id=${session.id}, '
      'incoming_uuid=${session.sessionUuid}, effective_uuid=$effectiveUuid, '
      'name="${session.name}"',
    );

    // STEP 1: If Odoo sent a UUID, ALWAYS check by UUID first
    // This handles the critical case where local session has temp odoo_id (-1)
    // but Odoo already created it and returns the same UUID
    if (session.sessionUuid?.isNotEmpty == true) {
      final existingByUuid = await (_db.select(_db.collectionSession)
            ..where((tbl) => tbl.sessionUuid.equals(session.sessionUuid!)))
          .getSingleOrNull();

      if (existingByUuid != null) {
        logger.d(
          '[CollectionSessionManager] Found existing by UUID=${session.sessionUuid}, '
          'updating odoo_id: ${existingByUuid.odooId} -> ${session.id}',
        );
        await (_db.update(_db.collectionSession)
              ..where(
                  (tbl) => tbl.sessionUuid.equals(session.sessionUuid!)))
            .write(_buildCompanionFromModel(session));
        logger.i('[CollectionSessionManager]', 'Session updated by UUID (Odoo UUID)');
        return;
      }
    }

    // STEP 2: Check if a session with this odoo_id already exists
    if (session.id > 0) {
      final existingByOdooId = await (_db.select(_db.collectionSession)
            ..where((tbl) => tbl.odooId.equals(session.id)))
          .getSingleOrNull();

      if (existingByOdooId != null) {
        logger.d(
          '[CollectionSessionManager] Found existing by odoo_id=${session.id}, updating...',
        );
        await (_db.update(_db.collectionSession)
              ..where((tbl) => tbl.odooId.equals(session.id)))
            .write(_buildCompanionFromModel(
          session,
          preserveUuid: existingByOdooId.sessionUuid.isNotEmpty,
          effectiveUuid: effectiveUuid,
        ));
        logger.i('[CollectionSessionManager]', 'Session updated by odoo_id');
        return;
      }
    }

    // STEP 3: Check if a session with the effective UUID exists
    final existingByUuid = await (_db.select(_db.collectionSession)
          ..where((tbl) => tbl.sessionUuid.equals(effectiveUuid)))
        .getSingleOrNull();

    if (existingByUuid != null) {
      logger.d(
        '[CollectionSessionManager] Updating existing by UUID: '
        'local_id=${existingByUuid.id}, odoo_id=${existingByUuid.odooId} -> ${session.id}',
      );
      await (_db.update(_db.collectionSession)
            ..where((tbl) => tbl.sessionUuid.equals(effectiveUuid)))
          .write(_buildCompanionFromModel(session));
      logger.i('[CollectionSessionManager]', 'Session updated by UUID');
      return;
    }

    // STEP 4: INSERT new session
    logger.d('[CollectionSessionManager]', 'Inserting new session');
    await _db
        .into(_db.collectionSession)
        .insert(_buildInsertCompanionFromModel(session, effectiveUuid));
    logger.i('[CollectionSessionManager]', 'Session inserted');
  }

  /// Update ALL fields of a local session with data from Odoo (by UUID).
  /// Preserves the local sessionUuid while updating other fields.
  Future<void> updateFromOdooByUuid(
    String sessionUuid,
    CollectionSession odooSession,
  ) async {
    logger.d(
      '[CollectionSessionManager] Updating session UUID=$sessionUuid with full Odoo data',
    );
    logger.d(
      '[CollectionSessionManager] Odoo data: name="${odooSession.name}", id=${odooSession.id}',
    );

    final localSession = await (_db.select(_db.collectionSession)
          ..where((tbl) => tbl.sessionUuid.equals(sessionUuid)))
        .getSingleOrNull();

    if (localSession == null) {
      logger.w('[CollectionSessionManager]', 'No session found with UUID=$sessionUuid');
      return;
    }

    logger.d(
      '[CollectionSessionManager] Local session found: name="${localSession.name}", '
      'odooId=${localSession.odooId}',
    );

    // Update ALL fields from Odoo (but preserve sessionUuid!)
    await (_db.update(_db.collectionSession)
          ..where((tbl) => tbl.sessionUuid.equals(sessionUuid)))
        .write(
      CollectionSessionCompanion(
        odooId: drift.Value(odooSession.id),
        name: drift.Value(odooSession.name),
        state: drift.Value(odooSession.state.code),
        configId: drift.Value(odooSession.configId ?? 0),
        configName: drift.Value(odooSession.configName),
        companyId: drift.Value(odooSession.companyId ?? 0),
        companyName: drift.Value(odooSession.companyName),
        userId: drift.Value(odooSession.userId ?? 0),
        userName: drift.Value(odooSession.userName),
        currencyId: drift.Value(odooSession.currencyId ?? 0),
        currencySymbol: drift.Value(odooSession.currencySymbol),
        cashJournalId: drift.Value(odooSession.cashJournalId),
        cashJournalName: drift.Value(odooSession.cashJournalName),
        startAt: drift.Value(odooSession.startAt ?? DateTime.now()),
        stopAt: drift.Value(odooSession.stopAt),
        cashRegisterBalanceStart: drift.Value(
          odooSession.cashRegisterBalanceStart,
        ),
        cashRegisterBalanceEndReal: drift.Value(
          odooSession.cashRegisterBalanceEndReal,
        ),
        cashRegisterBalanceEnd: drift.Value(odooSession.cashRegisterBalanceEnd),
        cashRegisterDifference: drift.Value(odooSession.cashRegisterDifference),
        // Contadores
        orderCount: drift.Value(odooSession.orderCount),
        invoiceCount: drift.Value(odooSession.invoiceCount),
        paymentCount: drift.Value(odooSession.paymentCount),
        advanceCount: drift.Value(odooSession.advanceCount),
        chequeRecibidoCount: drift.Value(odooSession.chequeRecibidoCount),
        cashOutCount: drift.Value(odooSession.cashOutCount),
        depositCount: drift.Value(odooSession.depositCount),
        withholdCount: drift.Value(odooSession.withholdCount),
        // Totales monetarios
        totalPaymentsAmount: drift.Value(odooSession.totalPaymentsAmount),
        totalCashOutAmount: drift.Value(odooSession.totalCashOutAmount),
        totalDepositAmount: drift.Value(odooSession.totalDepositAmount),
        totalWithholdAmount: drift.Value(odooSession.totalWithholdAmount),
        // Desglose salidas
        cashOutSecurityTotal: drift.Value(odooSession.cashOutSecurityTotal),
        cashOutInvoiceTotal: drift.Value(odooSession.cashOutInvoiceTotal),
        cashOutRefundTotal: drift.Value(odooSession.cashOutRefundTotal),
        cashOutWithholdTotal: drift.Value(odooSession.cashOutWithholdTotal),
        cashOutOtherTotal: drift.Value(odooSession.cashOutOtherTotal),
        // Cheques
        checksOnDayTotal: drift.Value(odooSession.checksOnDayTotal),
        checksPostdatedTotal: drift.Value(odooSession.checksPostdatedTotal),
        // Facturas del dia
        factCash: drift.Value(odooSession.factCash),
        factCards: drift.Value(odooSession.factCards),
        factTransfers: drift.Value(odooSession.factTransfers),
        factChecksDay: drift.Value(odooSession.factChecksDay),
        factChecksPost: drift.Value(odooSession.factChecksPost),
        factTotal: drift.Value(odooSession.factTotal),
        // Cartera
        carteraCash: drift.Value(odooSession.carteraCash),
        carteraCards: drift.Value(odooSession.carteraCards),
        carteraTransfers: drift.Value(odooSession.carteraTransfers),
        carteraChecksDay: drift.Value(odooSession.carteraChecksDay),
        carteraChecksPost: drift.Value(odooSession.carteraChecksPost),
        carteraTotal: drift.Value(odooSession.carteraTotal),
        // Anticipos
        anticipoCash: drift.Value(odooSession.anticipoCash),
        anticipoCards: drift.Value(odooSession.anticipoCards),
        anticipoTransfers: drift.Value(odooSession.anticipoTransfers),
        anticipoChecksDay: drift.Value(odooSession.anticipoChecksDay),
        anticipoChecksPost: drift.Value(odooSession.anticipoChecksPost),
        anticipoTotal: drift.Value(odooSession.anticipoTotal),
        // Totales generales
        totalCash: drift.Value(odooSession.totalCash),
        totalCards: drift.Value(odooSession.totalCards),
        totalTransfers: drift.Value(odooSession.totalTransfers),
        totalChecksDay: drift.Value(odooSession.totalChecksDay),
        totalChecksPost: drift.Value(odooSession.totalChecksPost),
        totalGeneral: drift.Value(odooSession.totalGeneral),
        // Validacion supervisor
        supervisorId: drift.Value(odooSession.supervisorId),
        supervisorName: drift.Value(odooSession.supervisorName),
        supervisorValidationDate: drift.Value(
          odooSession.supervisorValidationDate,
        ),
        supervisorNotes: drift.Value(odooSession.supervisorNotes),
        openingNotes: drift.Value(odooSession.openingNotes),
        closingNotes: drift.Value(odooSession.closingNotes),
        // Sync
        isSynced: const drift.Value(true),
        lastSyncDate: drift.Value(DateTime.now()),
        syncRetryCount: const drift.Value(0),
        // NOTE: sessionUuid is NOT updated - it stays the same local UUID
      ),
    );

    logger.d(
      '[CollectionSessionManager] Session UUID=$sessionUuid updated: '
      'name="${odooSession.name}" -> odooId=${odooSession.id}',
    );
  }

  /// Get session by sessionUuid column.
  ///
  /// Note: This is different from `readLocalByUuid()` which looks for a `uuid`
  /// column. The collection_session table uses `session_uuid` instead.
  Future<CollectionSession?> getSessionByUuid(String uuid) async {
    logger.d('[CollectionSessionManager]', 'Looking for session by UUID=$uuid');

    final result = await (_db.select(_db.collectionSession)
          ..where((tbl) => tbl.sessionUuid.equals(uuid)))
        .getSingleOrNull();

    if (result == null) {
      logger.e('[CollectionSessionManager]', 'No session found with UUID=$uuid');
      return null;
    }

    logger.d(
      '[CollectionSessionManager] Found session by UUID: name="${result.name}", '
      'odooId=${result.odooId}, state=${result.state}',
    );

    return fromDrift(result);
  }

  /// Update local session UUID to use real Odoo ID after sync.
  Future<void> updateSessionIdByUuid(String sessionUuid, int newOdooId) async {
    logger.d(
      '[CollectionSessionManager] Updating session UUID=$sessionUuid with Odoo ID=$newOdooId',
    );

    final localSession = await (_db.select(_db.collectionSession)
          ..where((tbl) => tbl.sessionUuid.equals(sessionUuid)))
        .getSingleOrNull();

    if (localSession == null) {
      logger.w('[CollectionSessionManager]', 'No session found with UUID=$sessionUuid');
      return;
    }

    await (_db.update(_db.collectionSession)
          ..where((tbl) => tbl.sessionUuid.equals(sessionUuid)))
        .write(CollectionSessionCompanion(odooId: drift.Value(newOdooId)));

    logger.i(
      '[CollectionSessionManager]',
      'Session UUID=$sessionUuid updated to ID=$newOdooId',
    );
  }

  /// Get session by Odoo ID with fallback for negative (temporary) IDs.
  ///
  /// If a negative ID is not found, looks for a recently synced session
  /// (within the last minute).
  Future<CollectionSession?> getSessionById(int id) async {
    logger.d('[CollectionSessionManager]', 'Looking for session with ID=$id');

    // First, try to find by exact odooId
    var result = await (_db.select(_db.collectionSession)
          ..where((tbl) => tbl.odooId.equals(id)))
        .getSingleOrNull();

    if (result != null) {
      logger.i('[CollectionSessionManager]', 'Found session by ID: ${result.name}');
    }

    // If not found and id is negative (temporary),
    // the session might have been synced and got a new positive ID.
    if (result == null && id < 0) {
      logger.d(
        '[CollectionSessionManager] Session with temporary ID=$id not found, '
        'looking for recently synced session...',
      );

      final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
      final recentlySynced = await (_db.select(_db.collectionSession)
            ..where((tbl) => tbl.isSynced.equals(true))
            ..where((tbl) => tbl.odooId.isBiggerThanValue(0))
            ..where(
              (tbl) => tbl.lastSyncDate.isBiggerOrEqualValue(oneMinuteAgo),
            )
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.lastSyncDate)])
            ..limit(1))
          .getSingleOrNull();

      if (recentlySynced != null) {
        logger.d(
          '[CollectionSessionManager] Found recently synced session: '
          '"${recentlySynced.name}" (ID=${recentlySynced.odooId})',
        );
        result = recentlySynced;
      } else {
        logger.e('[CollectionSessionManager]', 'No recently synced session found');
      }
    }

    if (result == null) {
      logger.e('[CollectionSessionManager]', 'Session ID=$id not found');
      return null;
    }

    return fromDrift(result);
  }

  /// Get all collection sessions from local database.
  Future<List<CollectionSession>> getAllSessions() async {
    final results = await _db.select(_db.collectionSession).get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Clear all local sessions (for debugging/reset purposes).
  Future<void> clearAllSessions() async {
    logger.w('[CollectionSessionManager]', 'CLEARING ALL LOCAL SESSIONS...');
    final count = await _db.delete(_db.collectionSession).go();
    logger.i('[CollectionSessionManager]', 'Deleted $count sessions');
  }

  /// List all local sessions (for debugging).
  Future<void> debugListAllSessions() async {
    final all = await _db.select(_db.collectionSession).get();
    logger.d(
      '[CollectionSessionManager]',
      '======= ALL LOCAL SESSIONS (${all.length}) =======',
    );
    for (final s in all) {
      logger.d(
        '[CollectionSessionManager]',
        'id=${s.id}, odooId=${s.odooId}, uuid=${s.sessionUuid.substring(0, 8)}..., '
            'name="${s.name}", synced=${s.isSynced}',
      );
    }
    logger.d(
      '[CollectionSessionManager]',
      '===============================================',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Build a CollectionSessionCompanion for update operations.
  CollectionSessionCompanion _buildCompanionFromModel(
    CollectionSession session, {
    bool preserveUuid = false,
    String? effectiveUuid,
  }) {
    return CollectionSessionCompanion(
      sessionUuid: preserveUuid
          ? const drift.Value.absent()
          : drift.Value(effectiveUuid ?? session.sessionUuid ?? ''),
      odooId: drift.Value(session.id),
      name: drift.Value(session.name),
      state: drift.Value(session.state.code),
      configId: drift.Value(session.configId ?? 0),
      configName: drift.Value(session.configName),
      companyId: drift.Value(session.companyId ?? 0),
      companyName: drift.Value(session.companyName),
      userId: drift.Value(session.userId ?? 0),
      userName: drift.Value(session.userName),
      currencyId: drift.Value(session.currencyId ?? 0),
      currencySymbol: drift.Value(session.currencySymbol),
      cashJournalId: drift.Value(session.cashJournalId),
      cashJournalName: drift.Value(session.cashJournalName),
      startAt: drift.Value(session.startAt ?? DateTime.now()),
      stopAt: drift.Value(session.stopAt),
      cashRegisterBalanceStart: drift.Value(session.cashRegisterBalanceStart),
      cashRegisterBalanceEndReal: drift.Value(
        session.cashRegisterBalanceEndReal,
      ),
      cashRegisterBalanceEnd: drift.Value(session.cashRegisterBalanceEnd),
      cashRegisterDifference: drift.Value(session.cashRegisterDifference),
      // Contadores
      orderCount: drift.Value(session.orderCount),
      invoiceCount: drift.Value(session.invoiceCount),
      paymentCount: drift.Value(session.paymentCount),
      advanceCount: drift.Value(session.advanceCount),
      chequeRecibidoCount: drift.Value(session.chequeRecibidoCount),
      cashOutCount: drift.Value(session.cashOutCount),
      depositCount: drift.Value(session.depositCount),
      withholdCount: drift.Value(session.withholdCount),
      // Totales monetarios
      totalPaymentsAmount: drift.Value(session.totalPaymentsAmount),
      totalCashOutAmount: drift.Value(session.totalCashOutAmount),
      totalDepositAmount: drift.Value(session.totalDepositAmount),
      totalWithholdAmount: drift.Value(session.totalWithholdAmount),
      // Desglose salidas
      cashOutSecurityTotal: drift.Value(session.cashOutSecurityTotal),
      cashOutInvoiceTotal: drift.Value(session.cashOutInvoiceTotal),
      cashOutRefundTotal: drift.Value(session.cashOutRefundTotal),
      cashOutWithholdTotal: drift.Value(session.cashOutWithholdTotal),
      cashOutOtherTotal: drift.Value(session.cashOutOtherTotal),
      // Cheques
      checksOnDayTotal: drift.Value(session.checksOnDayTotal),
      checksPostdatedTotal: drift.Value(session.checksPostdatedTotal),
      // Facturas del dia
      factCash: drift.Value(session.factCash),
      factCards: drift.Value(session.factCards),
      factTransfers: drift.Value(session.factTransfers),
      factChecksDay: drift.Value(session.factChecksDay),
      factChecksPost: drift.Value(session.factChecksPost),
      factTotal: drift.Value(session.factTotal),
      // Cartera
      carteraCash: drift.Value(session.carteraCash),
      carteraCards: drift.Value(session.carteraCards),
      carteraTransfers: drift.Value(session.carteraTransfers),
      carteraChecksDay: drift.Value(session.carteraChecksDay),
      carteraChecksPost: drift.Value(session.carteraChecksPost),
      carteraTotal: drift.Value(session.carteraTotal),
      // Anticipos
      anticipoCash: drift.Value(session.anticipoCash),
      anticipoCards: drift.Value(session.anticipoCards),
      anticipoTransfers: drift.Value(session.anticipoTransfers),
      anticipoChecksDay: drift.Value(session.anticipoChecksDay),
      anticipoChecksPost: drift.Value(session.anticipoChecksPost),
      anticipoTotal: drift.Value(session.anticipoTotal),
      // Totales generales
      totalCash: drift.Value(session.totalCash),
      totalCards: drift.Value(session.totalCards),
      totalTransfers: drift.Value(session.totalTransfers),
      totalChecksDay: drift.Value(session.totalChecksDay),
      totalChecksPost: drift.Value(session.totalChecksPost),
      totalGeneral: drift.Value(session.totalGeneral),
      // Validacion supervisor
      supervisorId: drift.Value(session.supervisorId),
      supervisorName: drift.Value(session.supervisorName),
      supervisorValidationDate: drift.Value(session.supervisorValidationDate),
      supervisorNotes: drift.Value(session.supervisorNotes),
      openingNotes: drift.Value(session.openingNotes),
      closingNotes: drift.Value(session.closingNotes),
      // Sync
      isSynced: drift.Value(session.isSynced),
      lastSyncDate: drift.Value(session.lastSyncDate),
      syncRetryCount: drift.Value(session.syncRetryCount),
      lastSyncAttempt: drift.Value(session.lastSyncAttempt),
    );
  }

  /// Build a CollectionSessionCompanion for insert operations.
  CollectionSessionCompanion _buildInsertCompanionFromModel(
    CollectionSession session,
    String effectiveUuid,
  ) {
    return CollectionSessionCompanion.insert(
      odooId: session.id,
      sessionUuid: effectiveUuid,
      name: session.name,
      configId: session.configId ?? 0,
      companyId: session.companyId ?? 0,
      userId: session.userId ?? 0,
      currencyId: session.currencyId ?? 0,
      startAt: session.startAt ?? DateTime.now(),
      state: drift.Value(session.state.code),
      configName: drift.Value(session.configName),
      companyName: drift.Value(session.companyName),
      userName: drift.Value(session.userName),
      currencySymbol: drift.Value(session.currencySymbol),
      cashJournalId: drift.Value(session.cashJournalId),
      cashJournalName: drift.Value(session.cashJournalName),
      stopAt: drift.Value(session.stopAt),
      cashRegisterBalanceStart: drift.Value(session.cashRegisterBalanceStart),
      cashRegisterBalanceEndReal: drift.Value(
        session.cashRegisterBalanceEndReal,
      ),
      cashRegisterBalanceEnd: drift.Value(session.cashRegisterBalanceEnd),
      cashRegisterDifference: drift.Value(session.cashRegisterDifference),
      // Contadores
      orderCount: drift.Value(session.orderCount),
      invoiceCount: drift.Value(session.invoiceCount),
      paymentCount: drift.Value(session.paymentCount),
      advanceCount: drift.Value(session.advanceCount),
      chequeRecibidoCount: drift.Value(session.chequeRecibidoCount),
      cashOutCount: drift.Value(session.cashOutCount),
      depositCount: drift.Value(session.depositCount),
      withholdCount: drift.Value(session.withholdCount),
      // Totales monetarios
      totalPaymentsAmount: drift.Value(session.totalPaymentsAmount),
      totalCashOutAmount: drift.Value(session.totalCashOutAmount),
      totalDepositAmount: drift.Value(session.totalDepositAmount),
      totalWithholdAmount: drift.Value(session.totalWithholdAmount),
      // Desglose salidas
      cashOutSecurityTotal: drift.Value(session.cashOutSecurityTotal),
      cashOutInvoiceTotal: drift.Value(session.cashOutInvoiceTotal),
      cashOutRefundTotal: drift.Value(session.cashOutRefundTotal),
      cashOutWithholdTotal: drift.Value(session.cashOutWithholdTotal),
      cashOutOtherTotal: drift.Value(session.cashOutOtherTotal),
      // Cheques
      checksOnDayTotal: drift.Value(session.checksOnDayTotal),
      checksPostdatedTotal: drift.Value(session.checksPostdatedTotal),
      // Facturas del dia
      factCash: drift.Value(session.factCash),
      factCards: drift.Value(session.factCards),
      factTransfers: drift.Value(session.factTransfers),
      factChecksDay: drift.Value(session.factChecksDay),
      factChecksPost: drift.Value(session.factChecksPost),
      factTotal: drift.Value(session.factTotal),
      // Cartera
      carteraCash: drift.Value(session.carteraCash),
      carteraCards: drift.Value(session.carteraCards),
      carteraTransfers: drift.Value(session.carteraTransfers),
      carteraChecksDay: drift.Value(session.carteraChecksDay),
      carteraChecksPost: drift.Value(session.carteraChecksPost),
      carteraTotal: drift.Value(session.carteraTotal),
      // Anticipos
      anticipoCash: drift.Value(session.anticipoCash),
      anticipoCards: drift.Value(session.anticipoCards),
      anticipoTransfers: drift.Value(session.anticipoTransfers),
      anticipoChecksDay: drift.Value(session.anticipoChecksDay),
      anticipoChecksPost: drift.Value(session.anticipoChecksPost),
      anticipoTotal: drift.Value(session.anticipoTotal),
      // Totales generales
      totalCash: drift.Value(session.totalCash),
      totalCards: drift.Value(session.totalCards),
      totalTransfers: drift.Value(session.totalTransfers),
      totalChecksDay: drift.Value(session.totalChecksDay),
      totalChecksPost: drift.Value(session.totalChecksPost),
      totalGeneral: drift.Value(session.totalGeneral),
      // Validacion supervisor
      supervisorId: drift.Value(session.supervisorId),
      supervisorName: drift.Value(session.supervisorName),
      supervisorValidationDate: drift.Value(session.supervisorValidationDate),
      supervisorNotes: drift.Value(session.supervisorNotes),
      openingNotes: drift.Value(session.openingNotes),
      closingNotes: drift.Value(session.closingNotes),
      // Sync
      isSynced: drift.Value(session.isSynced),
      lastSyncDate: drift.Value(session.lastSyncDate),
      syncRetryCount: drift.Value(session.syncRetryCount),
      lastSyncAttempt: drift.Value(session.lastSyncAttempt),
    );
  }
}
