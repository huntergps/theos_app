import 'package:odoo_sdk/odoo_sdk.dart' show OdooNotFoundException;

import '../../../features/banks/repositories/bank_repository.dart';
import '../../../core/services/odoo_service.dart';
import '../../../shared/utils/error_utils.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Servicio para gestionar anticipos de clientes/proveedores
///
/// Proporciona métodos para:
/// - Crear y publicar anticipos
/// - Consultar anticipos disponibles
/// - Aplicar anticipos a ventas
/// - Obtener diarios y métodos de pago disponibles
///
/// Sigue el patrón offline-first:
/// 1. Guardar en BD local (con ID negativo si es nuevo)
/// 2. Intentar sincronizar con Odoo
/// 3. Si falla, encolar en OfflineQueue para sync posterior
/// 4. Si tiene éxito, actualizar BD local con datos reales
class AdvanceService {
  final OdooService _odoo;
  final BankRepository _bankRepo;
  final OfflineQueueDataSource? _offlineQueue;

  AdvanceService(this._odoo, this._bankRepo, this._offlineQueue);

  /// Generate a temporary negative ID for offline-created records
  int _generateTempId() => -(DateTime.now().millisecondsSinceEpoch % 1000000000);

  /// Get the current user's company_id, defaulting to 1 if unavailable
  Future<int> _getUserCompanyId() async {
    try {
      final user = await userManager.getCurrentUser();
      final companyId = user?.companyId;
      if (companyId == null) {
        logger.w('[AdvanceService]', 'company_id not available from user, using fallback=1');
        return 1;
      }
      return companyId;
    } catch (e) {
      logger.w('[AdvanceService]', 'Error getting company_id, using fallback=1: $e');
      return 1;
    }
  }

  // ============================================================
  // CONSULTAR ANTICIPOS
  // ============================================================

  /// Obtiene anticipos disponibles del cliente
  ///
  /// Sigue patrón offline-first:
  /// 1. Buscar en BD local
  /// 2. Traer de Odoo y guardar en BD local
  /// 3. Volver a leer desde BD local
  Future<List<Advance>> getAvailableAdvances(int partnerId) async {
    // 1. Read from local DB first
    final cached = await advanceManager.searchLocal(
          domain: [
            ['partner_id', '=', partnerId],
            ['advance_type', '=', 'inbound'],
            ['state', 'in', ['posted', 'in_use']],
            ['amount_available', '>', 0],
          ],
          orderBy: 'date desc',
        );
    if (cached.isNotEmpty) {
      // Have cached data, try to refresh in background
      _refreshAvailableAdvancesFromOdoo(partnerId);
      return cached;
    }

    // 2. No cache, fetch from Odoo
    try {
      await _fetchAndCacheAvailableAdvances(partnerId);
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error fetching advances for partner $partnerId', e, st);
      // Return empty if both cache and Odoo fail
      return cached;
    }

    // 3. Re-read from local DB
    return await advanceManager.searchLocal(
          domain: [
            ['partner_id', '=', partnerId],
            ['advance_type', '=', 'inbound'],
            ['state', 'in', ['posted', 'in_use']],
            ['amount_available', '>', 0],
          ],
          orderBy: 'date desc',
        );
  }

  /// Refresh advances from Odoo (non-blocking)
  Future<void> _refreshAvailableAdvancesFromOdoo(int partnerId) async {
    try {
      await _fetchAndCacheAvailableAdvances(partnerId);
    } catch (e) {
      // Silently fail - we have cached data
    }
  }

  /// Fetch advances from Odoo and cache locally
  Future<void> _fetchAndCacheAvailableAdvances(int partnerId) async {
    final advances = await _odoo.call(
      model: 'account.advance',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['partner_id', 'child_of', partnerId],
          ['advance_type', '=', 'inbound'],
          ['state', 'in', ['posted', 'in_use']],
          ['amount_available', '>', 0],
        ],
        'fields': [
          'id',
          'name',
          'date',
          'date_estimated',
          'date_due',
          'state',
          'advance_type',
          'partner_id',
          'reference',
          'amount',
          'amount_used',
          'amount_available',
          'amount_returned',
          'usage_percentage',
          'days_to_expire',
          'is_expired',
        ],
        'order': 'date desc',
        'limit': 50,
      },
    );

    if (advances == null || advances is! List) {
      return;
    }

    // Parse and cache
    final advanceList = advances
        .map((a) => advanceManager.fromOdoo(a as Map<String, dynamic>))
        .toList();

    // Save to local DB
    await advanceManager.upsertLocalBatch(advanceList);
  }

  /// Obtiene un anticipo por ID
  ///
  /// Sigue patrón offline-first:
  /// 1. Buscar en BD local
  /// 2. Traer de Odoo y guardar en BD local
  /// 3. Volver a leer desde BD local
  Future<Advance?> getAdvance(int advanceId) async {
    // 1. Read from local DB first
    final cached = await advanceManager.readLocal(advanceId);
    if (cached != null) {
      // Have cached data, try to refresh in background
      _refreshAdvanceFromOdoo(advanceId);
      return cached;
    }

    // 2. No cache, fetch from Odoo
    try {
      await _fetchAndCacheAdvance(advanceId);
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error fetching advance $advanceId', e, st);
      return cached;
    }

    // 3. Re-read from local DB
    return await advanceManager.readLocal(advanceId);
  }

  /// Refresh single advance from Odoo (non-blocking)
  Future<void> _refreshAdvanceFromOdoo(int advanceId) async {
    try {
      await _fetchAndCacheAdvance(advanceId);
    } catch (e) {
      // Silently fail - we have cached data
    }
  }

  /// Fetch single advance from Odoo and cache locally
  Future<void> _fetchAndCacheAdvance(int advanceId) async {
    final advances = await _odoo.call(
      model: 'account.advance',
      method: 'search_read',
      kwargs: {
        'domain': [['id', '=', advanceId]],
        'fields': [
          'id',
          'name',
          'date',
          'date_estimated',
          'date_due',
          'state',
          'advance_type',
          'partner_id',
          'reference',
          'amount',
          'amount_used',
          'amount_available',
          'amount_returned',
          'usage_percentage',
          'days_to_expire',
          'is_expired',
          'collection_session_id',
          'sale_order_id',
        ],
        'limit': 1,
      },
    );

    if (advances == null || advances is! List || advances.isEmpty) {
      return;
    }

    final advance = advanceManager.fromOdoo(advances[0] as Map<String, dynamic>);
    await advanceManager.upsertLocal(advance);
  }

  /// Obtiene anticipos de la sesión de cobranza
  ///
  /// Sigue patrón offline-first:
  /// 1. Buscar en BD local
  /// 2. Traer de Odoo y guardar en BD local
  /// 3. Volver a leer desde BD local
  Future<List<Advance>> getSessionAdvances(int sessionId) async {
    // 1. Read from local DB first
    final cached = await advanceManager.searchLocal(
          domain: [['collection_session_id', '=', sessionId]],
          orderBy: 'date desc',
        );
    if (cached.isNotEmpty) {
      // Have cached data, try to refresh in background
      _refreshSessionAdvancesFromOdoo(sessionId);
      return cached;
    }

    // 2. No cache, fetch from Odoo
    try {
      await _fetchAndCacheSessionAdvances(sessionId);
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error fetching session advances', e, st);
      return cached;
    }

    // 3. Re-read from local DB
    return await advanceManager.searchLocal(
          domain: [['collection_session_id', '=', sessionId]],
          orderBy: 'date desc',
        );
  }

  /// Refresh session advances from Odoo (non-blocking)
  Future<void> _refreshSessionAdvancesFromOdoo(int sessionId) async {
    try {
      await _fetchAndCacheSessionAdvances(sessionId);
    } catch (e) {
      // Silently fail - we have cached data
    }
  }

  /// Fetch session advances from Odoo and cache locally
  Future<void> _fetchAndCacheSessionAdvances(int sessionId) async {
    final advances = await _odoo.call(
      model: 'account.advance',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['collection_session_id', '=', sessionId],
        ],
        'fields': [
          'id',
          'name',
          'date',
          'date_estimated',
          'date_due',
          'state',
          'advance_type',
          'partner_id',
          'reference',
          'amount',
          'amount_used',
          'amount_available',
          'amount_returned',
          'collection_session_id',
        ],
        'order': 'create_date desc',
      },
    );

    if (advances == null || advances is! List) {
      return;
    }

    final advanceList = advances
        .map((a) => advanceManager.fromOdoo(a as Map<String, dynamic>))
        .toList();

    await advanceManager.upsertLocalBatch(advanceList);
  }

  // ============================================================
  // CREAR ANTICIPOS
  // ============================================================

  /// Crea un nuevo anticipo (offline-first)
  ///
  /// 1. Valida los datos
  /// 2. Guarda localmente con ID negativo temporal
  /// 3. Intenta crear en Odoo
  /// 4. Si Odoo OK: actualiza registro local con ID real
  /// 5. Si Odoo falla: encola operación para sync posterior
  Future<AdvanceResult> createAdvance(Advance advance) async {
    try {
      // Validaciones
      if (advance.reference.length < 30) {
        return AdvanceResult(
          success: false,
          errorMessage: 'La referencia debe tener al menos 30 caracteres',
        );
      }

      if (advance.lines.isEmpty) {
        return AdvanceResult(
          success: false,
          errorMessage: 'Debe agregar al menos un método de pago',
        );
      }

      final totalLines = advance.lines.fold(0.0, (sum, l) => sum + l.amount);
      if (totalLines <= 0) {
        return AdvanceResult(
          success: false,
          errorMessage: 'El monto total debe ser mayor a cero',
        );
      }

      // 1. Save locally with a temporary negative ID
      final tempId = _generateTempId();
      final localAdvance = advance.copyWith(
        id: tempId,
        amount: totalLines,
        amountAvailable: totalLines,
      );
      await advanceManager.upsertLocal(localAdvance);
      logger.d('[AdvanceService]', 'Saved advance locally with tempId=$tempId');

      // 2. Try to create in Odoo
      final odooValues = advanceManager.toOdoo(advance);
      try {
        final advanceId = await _odoo.call(
          model: 'account.advance',
          method: 'create',
          kwargs: {
            'vals_list': [odooValues],
          },
        );

        if (advanceId == null) {
          throw Exception('Failed to create advance — null response');
        }

        final id = advanceId is List ? advanceId[0] as int : advanceId as int;

        // 3. Odoo OK — update local record with real ID
        await advanceManager.deleteLocal(tempId);
        final syncedAdvance = localAdvance.copyWith(id: id);
        await advanceManager.upsertLocal(syncedAdvance);

        logger.i('[AdvanceService]', 'Created advance $id (synced)');
        return AdvanceResult(success: true, advanceId: id);
      } catch (e) {
        // 4. Odoo failed — queue for later sync
        logger.w('[AdvanceService]', 'Odoo unreachable, queuing advance create (tempId=$tempId): $e');
        await _offlineQueue?.queueOperation(
          model: 'account.advance',
          method: 'create',
          recordId: tempId,
          values: odooValues,
          priority: OfflinePriority.high,
        );

        return AdvanceResult(
          success: true,
          advanceId: tempId,
          errorMessage: 'Guardado localmente. Se sincronizará cuando haya conexión.',
        );
      }
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error creating advance', e, st);
      return AdvanceResult(
        success: false,
        errorMessage: friendlyErrorMessage(e),
      );
    }
  }

  /// Crea y publica un anticipo en un solo paso (offline-first)
  ///
  /// Si offline: crea localmente y encola tanto el create como el post.
  /// Si online: crea y publica en Odoo, luego sincroniza a local.
  Future<AdvanceResult> createAndPostAdvance(Advance advance) async {
    try {
      // Primero crear (offline-first)
      final createResult = await createAdvance(advance);
      if (!createResult.success || createResult.advanceId == null) {
        return createResult;
      }

      // Si el ID es negativo, la creación fue offline.
      // Encolar el post para que se ejecute después del create.
      final advanceId = createResult.advanceId!;
      if (advanceId < 0) {
        await _offlineQueue?.queueOperation(
          model: 'account.advance',
          method: 'action_post',
          recordId: advanceId,
          values: {'ids': [advanceId]},
          priority: OfflinePriority.high,
        );
        // Update local state optimistically
        final local = await advanceManager.readLocal(advanceId);
        if (local != null) {
          await advanceManager.upsertLocal(
            local.copyWith(state: AdvanceState.posted),
          );
        }
        return AdvanceResult(
          success: true,
          advanceId: advanceId,
          amount: advance.lines.fold<double>(0.0, (sum, l) => sum + l.amount),
          errorMessage: 'Guardado localmente. Se sincronizará cuando haya conexión.',
        );
      }

      // Online — publicar normalmente
      return await postAdvance(advanceId);
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error creating and posting advance', e, st);
      return AdvanceResult(
        success: false,
        errorMessage: friendlyErrorMessage(e),
      );
    }
  }

  /// Publica un anticipo (offline-first)
  ///
  /// 1. Actualiza estado local a 'posted' optimistamente
  /// 2. Intenta llamar a Odoo action_post
  /// 3. Si falla, encola para sync posterior
  Future<AdvanceResult> postAdvance(int advanceId) async {
    try {
      // 1. Optimistic local state update
      final localAdvance = await advanceManager.readLocal(advanceId);
      if (localAdvance != null) {
        await advanceManager.upsertLocal(
          localAdvance.copyWith(state: AdvanceState.posted),
        );
      }

      // 2. Try Odoo
      try {
        await _odoo.call(
          model: 'account.advance',
          method: 'action_post',
          kwargs: {'ids': [advanceId]},
        );

        // Refresh from Odoo to get server-generated fields (name, etc.)
        final advance = await getAdvance(advanceId);

        logger.i('[AdvanceService]', 'Posted advance $advanceId: ${advance?.name}');

        return AdvanceResult(
          success: true,
          advanceId: advanceId,
          advanceName: advance?.name,
          amount: advance?.amount,
        );
      } catch (e) {
        // 3. Odoo failed — queue for later
        logger.w('[AdvanceService]', 'Odoo unreachable, queuing action_post for advance $advanceId: $e');
        await _offlineQueue?.queueOperation(
          model: 'account.advance',
          method: 'action_post',
          recordId: advanceId,
          values: {'ids': [advanceId]},
          priority: OfflinePriority.high,
        );

        return AdvanceResult(
          success: true,
          advanceId: advanceId,
          advanceName: localAdvance?.name,
          amount: localAdvance?.amount,
          errorMessage: 'Publicado localmente. Se sincronizará cuando haya conexión.',
        );
      }
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error posting advance $advanceId', e, st);
      return AdvanceResult(
        success: false,
        advanceId: advanceId,
        errorMessage: friendlyErrorMessage(e),
      );
    }
  }

  /// Devuelve el saldo disponible de un anticipo al cliente (offline-first)
  ///
  /// 1. Actualiza estado local optimistamente
  /// 2. Intenta llamar a Odoo action_return
  /// 3. Si falla, encola para sync posterior
  Future<bool> returnAdvance(int advanceId) async {
    try {
      // 1. Optimistic local state update
      final localAdvance = await advanceManager.readLocal(advanceId);
      if (localAdvance != null) {
        await advanceManager.upsertLocal(
          localAdvance.copyWith(
            amountReturned: localAdvance.amountAvailable,
            amountAvailable: 0,
          ),
        );
      }

      // 2. Try Odoo
      try {
        await _odoo.call(
          model: 'account.advance',
          method: 'action_return',
          kwargs: {'ids': [advanceId]},
        );

        // Refresh local cache with server data
        await _fetchAndCacheAdvance(advanceId);

        logger.i('[AdvanceService]', 'Returned advance $advanceId');
        return true;
      } catch (e) {
        // 3. Odoo failed — queue for later
        logger.w('[AdvanceService]', 'Odoo unreachable, queuing action_return for advance $advanceId: $e');
        await _offlineQueue?.queueOperation(
          model: 'account.advance',
          method: 'action_return',
          recordId: advanceId,
          values: {'ids': [advanceId]},
          priority: OfflinePriority.high,
        );
        return true;
      }
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error returning advance $advanceId', e, st);
      rethrow;
    }
  }

  /// Cancela un anticipo (offline-first)
  ///
  /// 1. Actualiza estado local a 'canceled' optimistamente
  /// 2. Intenta llamar a Odoo action_cancel
  /// 3. Si falla, encola para sync posterior
  Future<bool> cancelAdvance(int advanceId) async {
    try {
      // 1. Optimistic local state update
      final localAdvance = await advanceManager.readLocal(advanceId);
      if (localAdvance != null) {
        await advanceManager.upsertLocal(
          localAdvance.copyWith(state: AdvanceState.canceled),
        );
      }

      // 2. Try Odoo
      try {
        await _odoo.call(
          model: 'account.advance',
          method: 'action_cancel',
          kwargs: {'ids': [advanceId]},
        );

        // Refresh from Odoo
        await _fetchAndCacheAdvance(advanceId);

        logger.i('[AdvanceService]', 'Cancelled advance $advanceId');
        return true;
      } catch (e) {
        // 3. Odoo failed — queue for later
        logger.w('[AdvanceService]', 'Odoo unreachable, queuing action_cancel for advance $advanceId: $e');
        await _offlineQueue?.queueOperation(
          model: 'account.advance',
          method: 'action_cancel',
          recordId: advanceId,
          values: {'ids': [advanceId]},
          priority: OfflinePriority.normal,
        );
        return true;
      }
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error cancelling advance $advanceId', e, st);
      return false;
    }
  }

  // ============================================================
  // DIARIOS Y MÉTODOS DE PAGO
  // ============================================================

  /// Obtiene los diarios disponibles para anticipos de clientes
  Future<List<AvailableJournal>> getAvailableJournals() async {
    try {
      final companyId = await _getUserCompanyId();
      final journals = await _odoo.call(
        model: 'account.journal',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['type', 'in', ['cash', 'bank', 'credit']],
            ['allow_advance_customer', '=', true],
            ['company_id', '=', companyId],
          ],
          'fields': ['id', 'name', 'type', 'is_card_journal'],
          'order': 'sequence, id',
        },
      );

      if (journals == null || journals is! List) {
        return [];
      }

      final result = <AvailableJournal>[];
      for (final journalData in journals) {
        final journal = journalData as Map<String, dynamic>;
        final journalId = journal['id'] as int;

        // Obtener métodos de pago del diario
        final methods = await _getAdvancePaymentMethods(journalId);

        result.add(AvailableJournal(
          id: journalId,
          name: journal['name'] as String,
          type: journal['type'] as String,
          isCardJournal: journal['is_card_journal'] as bool? ?? false,
          paymentMethods: methods,
        ));
      }

      return result;
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error getting available journals', e, st);
      return [];
    }
  }

  /// Obtiene los métodos de pago para anticipos de un diario
  Future<List<PaymentMethod>> _getAdvancePaymentMethods(int journalId) async {
    try {
      final methods = await _odoo.call(
        model: 'account.payment.method.line',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['journal_id', '=', journalId],
            ['payment_type', '=', 'inbound'],
          ],
          'fields': ['id', 'name', 'code'],
        },
      );

      if (methods == null || methods is! List) {
        return [];
      }

      return methods
          .map((m) => PaymentMethod.fromOdoo(m as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error getting payment methods for journal $journalId', e, st);
      return [];
    }
  }

  // ============================================================
  // BANCOS Y TARJETAS (igual que PaymentService)
  // ============================================================

  /// Obtiene los bancos disponibles.
  /// In Odoo 19.2+, res.bank was removed — returns empty list.
  Future<List<AvailableBank>> getBanks() async {
    try {
      final banks = await _odoo.call(
        model: 'res.bank',
        method: 'search_read',
        kwargs: {
          'domain': [],
          'fields': ['id', 'name'],
          'order': 'name',
        },
      );

      if (banks == null || banks is! List) {
        return [];
      }

      return banks
          .map((b) => AvailableBank.fromOdoo(b as Map<String, dynamic>))
          .toList();
    } on OdooNotFoundException {
      // Odoo 19.2+: res.bank model doesn't exist
      logger.i('[AdvanceService]', 'res.bank not available (Odoo 19.2+)');
      return [];
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error getting banks', e, st);
      return [];
    }
  }

  /// Obtiene las marcas de tarjeta disponibles para un diario
  Future<List<CardBrand>> getCardBrands(int journalId) async {
    try {
      // Primero obtener las marcas configuradas en el diario
      final journal = await _odoo.call(
        model: 'account.journal',
        method: 'search_read',
        kwargs: {
          'domain': [['id', '=', journalId]],
          'fields': ['card_brand_ids'],
          'limit': 1,
        },
      );

      if (journal == null || journal is! List || journal.isEmpty) {
        return [];
      }

      final brandIds = (journal[0]['card_brand_ids'] as List?)?.cast<int>() ?? [];

      List<dynamic>? brands;
      if (brandIds.isEmpty) {
        // Si no hay marcas específicas, obtener todas
        brands = await _odoo.call(
          model: 'account.credit.card.brand',
          method: 'search_read',
          kwargs: {
            'domain': [],
            'fields': ['id', 'name'],
            'order': 'name',
          },
        );
      } else {
        brands = await _odoo.call(
          model: 'account.credit.card.brand',
          method: 'search_read',
          kwargs: {
            'domain': [['id', 'in', brandIds]],
            'fields': ['id', 'name'],
          },
        );
      }

      if (brands == null) {
        return [];
      }

      return brands
          .map((b) => CardBrand.fromOdoo(b as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error getting card brands', e, st);
      return [];
    }
  }

  /// Obtiene los plazos de tarjeta disponibles
  Future<List<CardDeadline>> getCardDeadlines({bool? credit, bool? debit}) async {
    try {
      final domain = <List<dynamic>>[
        if (credit == true) ['credit', '=', true],
        if (debit == true) ['debit', '=', true],
      ];

      final deadlines = await _odoo.call(
        model: 'account.credit.card.deadline',
        method: 'search_read',
        kwargs: {
          'domain': domain,
          'fields': ['id', 'name', 'credit', 'debit'],
          'order': 'sequence, name',
        },
      );

      if (deadlines == null || deadlines is! List) {
        return [];
      }

      return deadlines
          .map((d) => CardDeadline.fromOdoo(d as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error getting card deadlines', e, st);
      return [];
    }
  }

  /// Obtiene cuentas bancarias del cliente (delegado a BankRepository)
  ///
  /// Sigue patrón offline-first:
  /// 1. Lee de tabla local resPartnerBank
  /// 2. Si vacía y online, sincroniza desde Odoo
  /// 3. Retorna desde local
  Future<List<PartnerBank>> getPartnerBanks(int partnerId) async {
    try {
      final banks = await _bankRepo.getPartnerBanks(partnerId);
      return banks.map((b) => PartnerBank(
        id: b.odooId,
        accountNumber: b.accNumber,
        bankId: b.bankId,
        bankName: b.bankName,
      )).toList();
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error getting partner banks', e, st);
      return [];
    }
  }

  /// Crea una nueva cuenta bancaria para el cliente (delegado a BankRepository)
  ///
  /// Si online: crea en Odoo primero, luego guarda en local
  /// Si offline: crea con ID negativo y needsSync=true
  Future<PartnerBank?> createPartnerBank({
    required int partnerId,
    required String accNumber,
    int? bankId,
    String? bankName,
    String? accHolderName,
  }) async {
    try {
      final result = await _bankRepo.createPartnerBank(
        partnerId: partnerId,
        accNumber: accNumber,
        bankId: bankId,
        accHolderName: accHolderName,
      );

      if (result != null) {
        return PartnerBank(
          id: result.odooId,
          accountNumber: result.accNumber,
          bankId: result.bankId,
          bankName: result.bankName,
        );
      }
      return null;
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error creating partner bank', e, st);
      return null;
    }
  }

  // ============================================================
  // CONFIGURACIÓN
  // ============================================================

  /// Obtiene los días por defecto para fecha estimada
  Future<int> getDefaultDueDays() async {
    try {
      final companyId = await _getUserCompanyId();
      final company = await _odoo.call(
        model: 'res.company',
        method: 'search_read',
        kwargs: {
          'domain': [['id', '=', companyId]],
          'fields': ['l10n_ec_advance_default_due_days'],
          'limit': 1,
        },
      );

      if (company is List && company.isNotEmpty) {
        return (company[0] as Map<String, dynamic>)['l10n_ec_advance_default_due_days'] as int? ?? 30;
      }

      return 30;
    } catch (e) {
      logger.e('[AdvanceService]', 'Error getting default due days', e);
      return 30;
    }
  }

  /// Obtiene la longitud mínima de la referencia
  Future<int> getMinReferenceLength() async {
    try {
      final companyId = await _getUserCompanyId();
      final company = await _odoo.call(
        model: 'res.company',
        method: 'search_read',
        kwargs: {
          'domain': [['id', '=', companyId]],
          'fields': ['l10n_ec_advance_min_reference_length'],
          'limit': 1,
        },
      );

      if (company is List && company.isNotEmpty) {
        return (company[0] as Map<String, dynamic>)['l10n_ec_advance_min_reference_length'] as int? ?? 30;
      }

      return 30;
    } catch (e) {
      logger.e('[AdvanceService]', 'Error getting min reference length', e);
      return 30;
    }
  }
}

/// Resultado de operación de anticipo
class AdvanceResult {
  final bool success;
  final int? advanceId;
  final String? advanceName;
  final double? amount;
  final String? errorMessage;

  AdvanceResult({
    required this.success,
    this.advanceId,
    this.advanceName,
    this.amount,
    this.errorMessage,
  });
}

/// Cuenta bancaria del cliente
class PartnerBank {
  final int id;
  final String accountNumber;
  final int? bankId;
  final String? bankName;

  PartnerBank({
    required this.id,
    required this.accountNumber,
    this.bankId,
    this.bankName,
  });

  factory PartnerBank.fromOdoo(Map<String, dynamic> data) {
    final bankData = data['bank_id'];
    int? bankId;
    String? bankName;
    if (bankData is List && bankData.length >= 2) {
      bankId = bankData[0] as int;
      bankName = bankData[1] as String;
    }

    return PartnerBank(
      id: data['id'] as int,
      accountNumber: data['acc_number'] as String,
      bankId: bankId,
      bankName: bankName,
    );
  }

  String get displayName => bankName != null ? '$bankName - $accountNumber' : accountNumber;
}
