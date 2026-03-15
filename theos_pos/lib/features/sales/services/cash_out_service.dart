import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../core/services/odoo_service.dart';
import '../../../shared/utils/formatting_utils.dart';

/// Servicio para gestionar retiros de dinero de la caja de cobranzas
///
/// Proporciona métodos para:
/// - Crear y confirmar retiros de dinero
/// - Consultar tipos de retiro disponibles
/// - Obtener documentos pendientes (retenciones, NC, facturas)
/// - Validar saldo disponible en caja
///
/// Sigue el patrón offline-first:
/// 1. Guardar en BD local (ID negativo para registros nuevos)
/// 2. Intentar sincronizar con Odoo
/// 3. Si falla (offline), encolar en OfflineQueue
/// 4. Volver a leer desde BD local
class CashOutService {
  final OdooService _odoo;
  final CashOutManager _cashOutManager;
  final OfflineQueueDataSource? _offlineQueue;
  final AppDatabase _db;

  /// Whether Odoo is reachable (client configured)
  bool get _isOnline => _odoo.client != null;

  /// Generate a negative local ID for offline records
  int _generateLocalId() => -(DateTime.now().microsecondsSinceEpoch % 1000000000);

  /// Get the current user's company_id, defaulting to 1 if unavailable
  Future<int> _getUserCompanyId() async {
    try {
      final user = await userManager.getCurrentUser();
      final companyId = user?.companyId;
      if (companyId == null) {
        logger.w('[CashOutService]', 'company_id not available from user, using fallback=1');
        return 1;
      }
      return companyId;
    } catch (e) {
      logger.w('[CashOutService]', 'Error getting company_id, using fallback=1: $e');
      return 1;
    }
  }

  CashOutService(this._odoo, this._cashOutManager, this._offlineQueue, this._db);

  // ============================================================
  // TIPOS DE RETIRO
  // ============================================================

  /// Obtiene los tipos de retiro disponibles
  ///
  /// Sigue patrón offline-first:
  /// 1. Buscar en BD local
  /// 2. Traer de Odoo y guardar en BD local
  /// 3. Volver a leer desde BD local
  Future<List<CashOutType>> getCashOutTypes() async {
    // 1. Read from local DB first
    final cached = await _cashOutManager.getCashOutTypes();
    if (cached.isNotEmpty) {
      // Have cached data, try to refresh in background
      _refreshCashOutTypesFromOdoo();
      return cached;
    }

    // 2. No cache, fetch from Odoo
    try {
      await _fetchAndCacheCashOutTypes();
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error fetching cash out types', e, st);
      return cached;
    }

    // 3. Re-read from local DB
    final result = await _cashOutManager.getCashOutTypes();
    return result;
  }

  /// Refresh cash out types from Odoo (non-blocking)
  Future<void> _refreshCashOutTypesFromOdoo() async {
    try {
      await _fetchAndCacheCashOutTypes();
    } catch (e) {
      // Silently fail - we have cached data
    }
  }

  /// Fetch cash out types from Odoo and cache locally
  Future<void> _fetchAndCacheCashOutTypes() async {
    final types = await _odoo.call(
      model: 'l10n_ec.cash.out.type',
      method: 'search_read',
      kwargs: {
        'domain': [['active', '=', true]],
        'fields': ['id', 'name', 'code', 'default_cash_flow'],
        'order': 'sequence, name',
      },
    );

    if (types == null || types is! List) {
      return;
    }

    final typeList = types
        .map((t) => CashOutType.fromOdoo(t as Map<String, dynamic>))
        .toList();

    await _cashOutManager.upsertCashOutTypes(typeList);
  }

  /// Obtiene un tipo de retiro por código
  ///
  /// Sigue patrón offline-first
  Future<CashOutType?> getCashOutTypeByCode(String code) async {
    // 1. Read from local DB first
    final cached = await _cashOutManager.getCashOutTypeByCode(code);
    if (cached != null) {
      return cached;
    }

    // 2. No cache, fetch all types (they'll be cached for future use)
    try {
      await _fetchAndCacheCashOutTypes();
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error fetching cash out type by code $code', e, st);
      return null;
    }

    // 3. Re-read from local DB
    return await _cashOutManager.getCashOutTypeByCode(code);
  }

  // ============================================================
  // CONSULTAR RETIROS
  // ============================================================

  /// Obtiene los retiros de dinero de una sesión
  ///
  /// Sigue patrón offline-first:
  /// 1. Buscar en BD local
  /// 2. Traer de Odoo y guardar en BD local
  /// 3. Volver a leer desde BD local
  Future<List<CashOut>> getSessionCashOuts(int sessionId) async {
    // 1. Read from local DB first
    final cached = await _cashOutManager.getBySessionId(sessionId);
    if (cached.isNotEmpty) {
      // Have cached data, try to refresh in background
      _refreshSessionCashOutsFromOdoo(sessionId);
      return cached;
    }

    // 2. No cache, fetch from Odoo
    try {
      await _fetchAndCacheSessionCashOuts(sessionId);
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error fetching session cash outs', e, st);
      return cached;
    }

    // 3. Re-read from local DB
    final result = await _cashOutManager.getBySessionId(sessionId);
    return result;
  }

  /// Refresh session cash outs from Odoo (non-blocking)
  Future<void> _refreshSessionCashOutsFromOdoo(int sessionId) async {
    try {
      await _fetchAndCacheSessionCashOuts(sessionId);
    } catch (e) {
      // Silently fail - we have cached data
    }
  }

  /// Fetch session cash outs from Odoo and cache locally
  Future<void> _fetchAndCacheSessionCashOuts(int sessionId) async {
    final cashOuts = await _odoo.call(
      model: 'l10n_ec.cash.out',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['collection_session_id', '=', sessionId],
        ],
        'fields': [
          'id',
          'name',
          'date',
          'state',
          'cash_flow',
          'cash_out_type_id',
          'cash_out_type',
          'cash_out_code',
          'journal_id',
          'amount',
          'partner_id',
          'note',
          'collection_session_id',
        ],
        'order': 'create_date desc',
      },
    );

    if (cashOuts == null || cashOuts is! List) {
      return;
    }

    final cashOutList = cashOuts
        .map((c) => cashOutManager.fromOdoo(c as Map<String, dynamic>))
        .toList();

    await _cashOutManager.upsertBatchFromOdoo(cashOutList);
  }

  /// Obtiene un retiro de dinero por ID
  ///
  /// Sigue patrón offline-first
  Future<CashOut?> getCashOut(int cashOutId) async {
    // 1. Read from local DB first
    final cached = await _cashOutManager.getByOdooId(cashOutId);
    if (cached != null) {
      // Have cached data, try to refresh in background
      _refreshCashOutFromOdoo(cashOutId);
      return cached;
    }

    // 2. No cache, fetch from Odoo
    try {
      await _fetchAndCacheCashOut(cashOutId);
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error fetching cash out $cashOutId', e, st);
      return cached;
    }

    // 3. Re-read from local DB
    return await _cashOutManager.getByOdooId(cashOutId);
  }

  /// Refresh single cash out from Odoo (non-blocking)
  Future<void> _refreshCashOutFromOdoo(int cashOutId) async {
    try {
      await _fetchAndCacheCashOut(cashOutId);
    } catch (e) {
      // Silently fail - we have cached data
    }
  }

  /// Fetch single cash out from Odoo and cache locally
  Future<void> _fetchAndCacheCashOut(int cashOutId) async {
    final cashOuts = await _odoo.call(
      model: 'l10n_ec.cash.out',
      method: 'search_read',
      kwargs: {
        'domain': [['id', '=', cashOutId]],
        'fields': [
          'id',
          'name',
          'date',
          'state',
          'cash_flow',
          'cash_out_type_id',
          'cash_out_type',
          'cash_out_code',
          'journal_id',
          'amount',
          'partner_id',
          'note',
          'account_id_manual',
          'collection_session_id',
          'move_id',
        ],
        'limit': 1,
      },
    );

    if (cashOuts == null || cashOuts is! List || cashOuts.isEmpty) {
      return;
    }

    final cashOut = cashOutManager.fromOdoo(cashOuts[0] as Map<String, dynamic>);
    await _cashOutManager.upsertFromOdoo(cashOut);
  }

  // ============================================================
  // CREAR RETIROS
  // ============================================================

  /// Crea un nuevo retiro de dinero (offline-first)
  ///
  /// 1. Valida datos localmente
  /// 2. Guarda en BD local con ID negativo
  /// 3. Intenta crear en Odoo
  /// 4. Si tiene éxito: actualiza ID local con el remoto
  /// 5. Si falla (offline): encola en OfflineQueue
  Future<CashOutResult> createCashOut(CashOut cashOut) async {
    try {
      // Validaciones locales
      if (cashOut.amount <= 0) {
        return CashOutResult(
          success: false,
          errorMessage: 'El monto debe ser mayor a cero',
        );
      }

      // Validar saldo disponible si hay sesión (best-effort, skip if offline)
      if (cashOut.collectionSessionId != null && _isOnline) {
        try {
          final availableCash = await getAvailableCash(cashOut.collectionSessionId!);
          if (availableCash < cashOut.amount) {
            return CashOutResult(
              success: false,
              errorMessage: 'Saldo insuficiente en caja. Disponible: ${availableCash.toCurrency()}',
            );
          }
        } catch (_) {
          // Offline — skip balance check, proceed with local save
        }
      }

      // 1. Save locally with negative ID
      final localId = _generateLocalId();
      final localCashOut = cashOut.copyWith(
        id: localId,
        isSynced: false,
      );
      await _cashOutManager.upsertCashOut(localCashOut);

      logger.i('[CashOutService]', 'Saved cash out locally with id=$localId');

      // 2. Try to create in Odoo
      try {
        final odooValues = cashOutManager.toOdoo(localCashOut);
        // Remove local-only fields before sending to Odoo
        odooValues.remove('id');
        odooValues.remove('is_synced');
        odooValues.remove('last_sync_date');

        final cashOutId = await _odoo.call(
          model: 'l10n_ec.cash.out',
          method: 'create',
          kwargs: {
            'vals_list': [odooValues],
          },
        );

        if (cashOutId == null) {
          throw Exception('Odoo returned null for cash out create');
        }

        final remoteId = cashOutId is List ? cashOutId[0] as int : cashOutId as int;

        // 3. Update local record with remote ID
        // Delete the local negative-ID record and insert with remote ID
        await (_db.delete(_db.cashOut)
              ..where((t) => t.odooId.equals(localId)))
            .go();

        final syncedCashOut = localCashOut.copyWith(
          id: remoteId,
          isSynced: true,
          lastSyncDate: DateTime.now(),
        );
        await _cashOutManager.upsertFromOdoo(syncedCashOut);

        logger.i('[CashOutService]', 'Created cash out in Odoo: $remoteId (was local $localId)');

        return CashOutResult(
          success: true,
          cashOutId: remoteId,
        );
      } catch (e) {
        // 4. Offline or error — queue for later sync
        logger.w('[CashOutService]', 'Odoo create failed, queuing offline: $e');

        await _offlineQueue?.queueOperation(
          model: 'l10n_ec.cash.out',
          method: 'create',
          recordId: localId,
          values: cashOutManager.toOdoo(localCashOut),
          priority: OfflinePriority.high,
        );

        return CashOutResult(
          success: true,
          cashOutId: localId,
        );
      }
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error creating cash out', e, st);
      return CashOutResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Crea y confirma un retiro de dinero en un solo paso
  Future<CashOutResult> createAndConfirmCashOut(CashOut cashOut) async {
    try {
      // Primero crear
      final createResult = await createCashOut(cashOut);
      if (!createResult.success || createResult.cashOutId == null) {
        return createResult;
      }

      // Luego confirmar
      return await confirmCashOut(createResult.cashOutId!);
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error creating and confirming cash out', e, st);
      return CashOutResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Confirma un retiro de dinero (offline-first)
  ///
  /// 1. Actualiza estado local a 'posted'
  /// 2. Intenta confirmar en Odoo
  /// 3. Si falla (offline): encola en OfflineQueue
  Future<CashOutResult> confirmCashOut(int cashOutId) async {
    try {
      // 1. Update local state to 'posted'
      final existing = await _cashOutManager.getByOdooId(cashOutId);
      if (existing != null) {
        final updated = existing.copyWith(state: CashOutState.posted);
        await _cashOutManager.upsertCashOut(updated);
      }

      // 2. Try to confirm in Odoo
      try {
        await _odoo.call(
          model: 'l10n_ec.cash.out',
          method: 'action_confirm',
          kwargs: {'ids': [cashOutId]},
        );

        // Refresh from Odoo to get server-generated fields (name, move_id, etc.)
        await _fetchAndCacheCashOut(cashOutId);
        final cashOut = await _cashOutManager.getByOdooId(cashOutId);

        logger.i('[CashOutService]', 'Confirmed cash out $cashOutId: ${cashOut?.name}');

        return CashOutResult(
          success: true,
          cashOutId: cashOutId,
          cashOutName: cashOut?.name,
          amount: cashOut?.amount,
        );
      } catch (e) {
        // 3. Offline — queue for later sync
        logger.w('[CashOutService]', 'Odoo confirm failed, queuing offline: $e');

        await _offlineQueue?.queueOperation(
          model: 'l10n_ec.cash.out',
          method: 'action_confirm',
          recordId: cashOutId,
          values: {'ids': [cashOutId]},
          priority: OfflinePriority.high,
        );

        return CashOutResult(
          success: true,
          cashOutId: cashOutId,
          cashOutName: existing?.name,
          amount: existing?.amount,
        );
      }
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error confirming cash out $cashOutId', e, st);
      return CashOutResult(
        success: false,
        cashOutId: cashOutId,
        errorMessage: e.toString(),
      );
    }
  }

  /// Cancela un retiro de dinero (offline-first)
  ///
  /// 1. Actualiza estado local a 'cancelled'
  /// 2. Intenta cancelar en Odoo
  /// 3. Si falla (offline): encola en OfflineQueue
  Future<bool> cancelCashOut(int cashOutId) async {
    try {
      // 1. Update local state to 'cancelled'
      final existing = await _cashOutManager.getByOdooId(cashOutId);
      if (existing != null) {
        final updated = existing.copyWith(state: CashOutState.cancelled);
        await _cashOutManager.upsertCashOut(updated);
      }

      // 2. Try to cancel in Odoo
      try {
        await _odoo.call(
          model: 'l10n_ec.cash.out',
          method: 'action_cancel',
          kwargs: {'ids': [cashOutId]},
        );

        // Refresh from Odoo
        await _fetchAndCacheCashOut(cashOutId);

        logger.i('[CashOutService]', 'Cancelled cash out $cashOutId');
      } catch (e) {
        // 3. Offline — queue for later sync
        logger.w('[CashOutService]', 'Odoo cancel failed, queuing offline: $e');

        await _offlineQueue?.queueOperation(
          model: 'l10n_ec.cash.out',
          method: 'action_cancel',
          recordId: cashOutId,
          values: {'ids': [cashOutId]},
          priority: OfflinePriority.normal,
        );
      }

      return true;
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error cancelling cash out $cashOutId', e, st);
      return false;
    }
  }

  // ============================================================
  // RETIRO DE SEGURIDAD (Shortcut)
  // ============================================================

  /// Crea un retiro de seguridad rápido
  ///
  /// Este es el tipo más común de retiro en sesiones de cobranza.
  /// El dinero se retira de la caja y se crea un depósito automático.
  Future<CashOutResult> createSecurityWithdrawal({
    required double amount,
    required int journalId,
    required int sessionId,
    String? note,
  }) async {
    try {
      // Obtener el tipo de retiro de seguridad
      final securityType = await getCashOutTypeByCode('security');
      if (securityType == null) {
        return CashOutResult(
          success: false,
          errorMessage: 'Tipo de retiro de seguridad no configurado',
        );
      }

      // Crear el cash out
      final cashOut = CashOut.createLocal(
        date: DateTime.now(),
        type: securityType,
        journalId: journalId,
        amount: amount,
        note: note ?? 'Retiro de seguridad',
        collectionSessionId: sessionId,
      );

      return await createAndConfirmCashOut(cashOut);
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error creating security withdrawal', e, st);
      return CashOutResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Crea un retiro por gasto
  Future<CashOutResult> createExpenseWithdrawal({
    required double amount,
    required int journalId,
    required int sessionId,
    required String description,
    int? accountId,
  }) async {
    try {
      // Obtener el tipo de gasto
      final expenseType = await getCashOutTypeByCode('expense');
      if (expenseType == null) {
        return CashOutResult(
          success: false,
          errorMessage: 'Tipo de gasto no configurado',
        );
      }

      // Crear el cash out
      final cashOut = CashOut.createLocal(
        date: DateTime.now(),
        type: expenseType,
        journalId: journalId,
        amount: amount,
        note: description,
        collectionSessionId: sessionId,
      );

      return await createAndConfirmCashOut(cashOut);
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error creating expense withdrawal', e, st);
      return CashOutResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // ============================================================
  // DOCUMENTOS PENDIENTES
  // ============================================================

  /// Obtiene retenciones pendientes del cliente para devolución
  Future<List<PendingWithhold>> getPendingWithholds(int partnerId) async {
    try {
      final withholds = await _odoo.call(
        model: 'account.move',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['move_type', '=', 'out_withhold'],
            ['partner_id', 'child_of', partnerId],
            ['state', '=', 'posted'],
            ['amount_residual', '>', 0],
          ],
          'fields': ['id', 'name', 'amount_residual', 'date', 'partner_id'],
          'order': 'date desc',
          'limit': 50,
        },
      );

      if (withholds == null || withholds is! List) {
        return [];
      }

      return withholds
          .map((w) => PendingWithhold.fromOdoo(w as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error getting pending withholds', e, st);
      return [];
    }
  }

  /// Obtiene notas de crédito pendientes del cliente para devolución
  Future<List<PendingCreditNote>> getPendingCreditNotes(int partnerId) async {
    try {
      final creditNotes = await _odoo.call(
        model: 'account.move',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['move_type', '=', 'out_refund'],
            ['partner_id', 'child_of', partnerId],
            ['state', '=', 'posted'],
            ['payment_state', 'in', ['not_paid', 'partial']],
            ['amount_residual', '>', 0],
          ],
          'fields': ['id', 'name', 'amount_residual', 'invoice_date', 'partner_id'],
          'order': 'invoice_date desc',
          'limit': 50,
        },
      );

      if (creditNotes == null || creditNotes is! List) {
        return [];
      }

      return creditNotes
          .map((cn) => PendingCreditNote.fromOdoo(cn as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error getting pending credit notes', e, st);
      return [];
    }
  }

  /// Obtiene facturas de compra pendientes de pago
  Future<List<PendingInvoice>> getPendingPurchaseInvoices(int partnerId) async {
    try {
      final invoices = await _odoo.call(
        model: 'account.move',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['move_type', '=', 'in_invoice'],
            ['partner_id', 'child_of', partnerId],
            ['state', '=', 'posted'],
            ['payment_state', 'in', ['not_paid', 'partial']],
            ['amount_residual', '>', 0],
          ],
          'fields': ['id', 'name', 'amount_residual', 'invoice_date', 'invoice_date_due', 'partner_id'],
          'order': 'invoice_date_due asc',
          'limit': 50,
        },
      );

      if (invoices == null || invoices is! List) {
        return [];
      }

      return invoices
          .map((inv) => PendingInvoice.fromOdoo(inv as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error getting pending purchase invoices', e, st);
      return [];
    }
  }

  // ============================================================
  // SALDO DE CAJA
  // ============================================================

  /// Obtiene el saldo disponible en efectivo de la sesión
  Future<double> getAvailableCash(int sessionId) async {
    try {
      final session = await _odoo.call(
        model: 'l10n_ec_collection_box.session',
        method: 'search_read',
        kwargs: {
          'domain': [['id', '=', sessionId]],
          'fields': ['cash_register_balance_end'],
          'limit': 1,
        },
      );

      if (session is List && session.isNotEmpty) {
        return (session[0] as Map<String, dynamic>)['cash_register_balance_end'] as double? ?? 0;
      }

      return 0;
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error getting available cash for session $sessionId', e, st);
      return 0;
    }
  }

  /// Obtiene el resumen de efectivo de la sesión
  Future<SessionCashSummary?> getSessionCashSummary(int sessionId) async {
    try {
      final session = await _odoo.call(
        model: 'l10n_ec_collection_box.session',
        method: 'search_read',
        kwargs: {
          'domain': [['id', '=', sessionId]],
          'fields': [
            'cash_register_balance_start',
            'cash_register_balance_end',
            'cash_register_balance_end_real',
            'cash_register_difference',
            'total_cash_out_amount',
            'cash_out_count',
          ],
          'limit': 1,
        },
      );

      if (session == null || session is! List || session.isEmpty) {
        return null;
      }

      final data = session[0] as Map<String, dynamic>;
      return SessionCashSummary(
        balanceStart: (data['cash_register_balance_start'] as num?)?.toDouble() ?? 0,
        balanceEnd: (data['cash_register_balance_end'] as num?)?.toDouble() ?? 0,
        balanceEndReal: (data['cash_register_balance_end_real'] as num?)?.toDouble() ?? 0,
        difference: (data['cash_register_difference'] as num?)?.toDouble() ?? 0,
        totalCashOutAmount: (data['total_cash_out_amount'] as num?)?.toDouble() ?? 0,
        cashOutCount: data['cash_out_count'] as int? ?? 0,
      );
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error getting session cash summary', e, st);
      return null;
    }
  }

  // ============================================================
  // DIARIOS DISPONIBLES
  // ============================================================

  /// Obtiene los diarios de efectivo disponibles para retiros
  Future<List<AvailableJournal>> getCashJournals() async {
    try {
      final companyId = await _getUserCompanyId();
      final journals = await _odoo.call(
        model: 'account.journal',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['type', 'in', ['cash', 'bank']],
            ['company_id', '=', companyId],
          ],
          'fields': ['id', 'name', 'type'],
          'order': 'sequence, id',
        },
      );

      if (journals == null || journals is! List) {
        return [];
      }

      return journals.map((j) {
        final journal = j as Map<String, dynamic>;
        return AvailableJournal(
          id: journal['id'] as int,
          name: journal['name'] as String,
          type: journal['type'] as String,
          paymentMethods: [],
        );
      }).toList();
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error getting cash journals', e, st);
      return [];
    }
  }

  // ============================================================
  // CUENTAS CONTABLES (para tipo 'general')
  // ============================================================

  /// Obtiene cuentas de gastos para retiros generales
  Future<List<ExpenseAccount>> getExpenseAccounts() async {
    try {
      final companyId = await _getUserCompanyId();
      final accounts = await _odoo.call(
        model: 'account.account',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['account_type', 'in', ['expense', 'expense_direct_cost']],
            ['deprecated', '=', false],
            ['company_id', '=', companyId],
          ],
          'fields': ['id', 'code', 'name'],
          'order': 'code',
          'limit': 100,
        },
      );

      if (accounts == null || accounts is! List) {
        return [];
      }

      return accounts
          .map((a) => ExpenseAccount.fromOdoo(a as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      logger.e('[CashOutService]', 'Error getting expense accounts', e, st);
      return [];
    }
  }
}

/// Resultado de operación de retiro
class CashOutResult {
  final bool success;
  final int? cashOutId;
  final String? cashOutName;
  final double? amount;
  final String? errorMessage;

  CashOutResult({
    required this.success,
    this.cashOutId,
    this.cashOutName,
    this.amount,
    this.errorMessage,
  });
}

/// Resumen de efectivo de la sesión
class SessionCashSummary {
  final double balanceStart;
  final double balanceEnd;
  final double balanceEndReal;
  final double difference;
  final double totalCashOutAmount;
  final int cashOutCount;

  SessionCashSummary({
    required this.balanceStart,
    required this.balanceEnd,
    required this.balanceEndReal,
    required this.difference,
    required this.totalCashOutAmount,
    required this.cashOutCount,
  });

  /// Saldo disponible para retiros
  double get availableCash => balanceEnd;
}

/// Cuenta de gastos
class ExpenseAccount {
  final int id;
  final String code;
  final String name;

  ExpenseAccount({
    required this.id,
    required this.code,
    required this.name,
  });

  factory ExpenseAccount.fromOdoo(Map<String, dynamic> data) {
    return ExpenseAccount(
      id: data['id'] as int,
      code: data['code'] as String,
      name: data['name'] as String,
    );
  }

  String get displayName => '$code - $name';
}
