import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;
import 'package:uuid/uuid.dart';

import '../../../features/banks/repositories/bank_repository.dart';
import '../../../core/services/odoo_service.dart';
import '../../../shared/utils/formatting_utils.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import 'order_validation_types.dart';

const _uuid = Uuid();

/// Servicio para gestionar los pagos de órdenes de venta
///
/// Proporciona métodos para:
/// - Obtener diarios y métodos de pago disponibles
/// - Obtener anticipos y notas de crédito del cliente
/// - Obtener bancos, marcas de tarjeta, plazos y lotes
/// - Guardar líneas de pago
///
/// Sigue el patrón offline-first: lee de la base local primero,
/// y usa Odoo para sincronización y operaciones de escritura.
class PaymentService {
  final OdooService _odoo;
  final BankRepository _bankRepo;
  final OfflineQueueDataSource? _offlineQueue;
  final AppDatabase _db;

  PaymentService(this._odoo, this._bankRepo, this._offlineQueue, this._db);

  /// Get the current user's company_id, defaulting to 1 if unavailable
  Future<int> _getUserCompanyId() async {
    try {
      final user = await userManager.getCurrentUser();
      final companyId = user?.companyId;
      if (companyId == null) {
        logger.w('[PaymentService]', 'company_id not available from user, using fallback=1');
        return 1;
      }
      return companyId;
    } catch (e) {
      logger.w('[PaymentService]', 'Error getting company_id, using fallback=1: $e');
      return 1;
    }
  }

  /// Verifica si hay conexión a Odoo
  bool get _isOnline => _odoo.client != null;

  /// Helper para decodificar lista de IDs
  /// Soporta tanto JSON array "[1,2,3]" como texto separado por comas "1,2,3"
  List<int> _decodeIntList(String? str) {
    if (str == null || str.isEmpty || str == '[]') return [];

    // Si es JSON array, decodificar
    if (str.startsWith('[')) {
      try {
        final list = jsonDecode(str);
        if (list is List) {
          return list.cast<int>();
        }
      } catch (e) {
        logger.w('[PaymentService]', 'Error decoding JSON int list: $e');
      }
    }

    // Si es texto separado por comas, parsear
    return str
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  /// Obtiene los diarios de pago disponibles para la sesión de cobranza
  ///
  /// Usa la configuración del punto de cobro (collection_config.allowed_journal_ids)
  /// para obtener solo los diarios permitidos.
  ///
  /// OFFLINE-FIRST: Primero intenta cargar desde la base de datos local.
  ///
  /// [sessionId]: ID de la sesión de cobranza (collection.session)
  Future<List<AvailableJournal>> getAvailableJournals(int? sessionId) async {
    try {
      // 1. OFFLINE-FIRST: Intentar cargar desde base local primero
      final localResult = await _getAvailableJournalsFromLocal(sessionId);
      if (localResult.isNotEmpty) {
        logger.d('[PaymentService]', 'Loaded ${localResult.length} journals from local DB');
        return localResult;
      }

      logger.d('[PaymentService]', 'No local journals found, trying Odoo API...');

      // 2. Fallback: Intentar cargar desde Odoo (online)
      return await _getAvailableJournalsFromOdoo(sessionId);
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting journals', e, st);
      return [];
    }
  }

  /// Obtiene diarios desde la base de datos local (offline)
  Future<List<AvailableJournal>> _getAvailableJournalsFromLocal(int? sessionId) async {
    try {
      List<int> allowedJournalIds = [];
      logger.d('[PaymentService]', '_getAvailableJournalsFromLocal: sessionId=$sessionId');
      logger.d('[PaymentService]', 'Using local database for journal lookup');

      // 1. Obtener allowed_journal_ids desde collection_config vía session
      if (sessionId != null) {
        // Buscar la sesión via manager
        final session = await collectionSessionManager.readLocal(sessionId);

        logger.d('[PaymentService]', 'session found: ${session != null}, configId: ${session?.configId}');

        if (session != null && session.configId != null) {
          // Obtener el config via manager
          final config = await collectionConfigManager.readLocal(session.configId!);

          logger.d('[PaymentService]', 'config found: ${config != null}, allowedJournalIds: ${config?.allowedJournalIds}, cashJournalId: ${config?.cashJournalId}');
          if (config != null) {
            // allowedJournalIds is List<int>? from the Freezed model
            if (config.allowedJournalIds != null && config.allowedJournalIds!.isNotEmpty) {
              allowedJournalIds = List<int>.from(config.allowedJournalIds!);
            }
            // Agregar diario de efectivo si no está en la lista
            if (config.cashJournalId != null && !allowedJournalIds.contains(config.cashJournalId)) {
              allowedJournalIds.add(config.cashJournalId!);
            }
          }
        }
      }

      logger.d('[PaymentService]', 'allowedJournalIds after config: $allowedJournalIds');

      // 2. Si no hay diarios configurados, usar fallback con disponible_ventas
      List<AccountJournalData> journals;
      if (allowedJournalIds.isNotEmpty) {
        logger.d('[PaymentService]', 'Querying journals with IDs: $allowedJournalIds');
        try {
          // Use raw query to avoid Drift mapping issues with empty/null fields
          final rawResults = await _db.customSelect(
            'SELECT odoo_id, name, code, type, is_card_journal, card_brand_ids, '
            'default_card_brand_id, card_deadline_credit_ids, card_deadline_debit_ids, '
            'default_card_deadline_credit_id, default_card_deadline_debit_id '
            'FROM account_journal WHERE odoo_id IN (${allowedJournalIds.join(",")})',
          ).get();
          logger.d('[PaymentService]', 'Raw query returned ${rawResults.length} rows');

          // Build AvailableJournal list directly from raw results
          final result = <AvailableJournal>[];
          for (final row in rawResults) {
            final journalId = row.read<int>('odoo_id');
            final journalName = row.read<String>('name');
            final journalType = row.read<String>('type');
            final isCard = row.read<int>('is_card_journal') == 1;
            final cardBrandIdsStr = row.readNullable<String>('card_brand_ids') ?? '';
            final deadlineCreditIdsStr = row.readNullable<String>('card_deadline_credit_ids') ?? '';
            final deadlineDebitIdsStr = row.readNullable<String>('card_deadline_debit_ids') ?? '';

            // Get payment methods for this journal
            final methods = await _getPaymentMethodsFromLocal(journalId);
            logger.d('[PaymentService]', 'Journal $journalId ($journalName): ${methods.length} methods');

            if (methods.isNotEmpty) {
              result.add(AvailableJournal(
                id: journalId,
                name: journalName,
                type: journalType,
                isCardJournal: isCard,
                paymentMethods: methods,
                cardBrandIds: _decodeIntList(cardBrandIdsStr),
                defaultCardBrandId: row.readNullable<int>('default_card_brand_id'),
                deadlineCreditIds: _decodeIntList(deadlineCreditIdsStr),
                deadlineDebitIds: _decodeIntList(deadlineDebitIdsStr),
                defaultDeadlineCreditId: row.readNullable<int>('default_card_deadline_credit_id'),
                defaultDeadlineDebitId: row.readNullable<int>('default_card_deadline_debit_id'),
              ));
            }
          }

          logger.d('[PaymentService]', 'Returning ${result.length} journals with payment methods');
          return result;
        } catch (e, st) {
          logger.d('[PaymentService]', 'EXCEPTION in journal query: $e');
          logger.d('[PaymentService]', 'Stack: $st');
          rethrow;
        }
      } else {
        // Fallback: diarios con disponible_ventas=true
        logger.d('[PaymentService]', 'No session config, using disponible_ventas fallback');
        journals = await (_db.select(_db.accountJournal)
              ..where((t) => t.type.isIn(['cash', 'bank', 'credit']))
              ..where((t) => t.disponibleVentas.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
            .get();
      }

      logger.d('[PaymentService]', 'journals found in DB: ${journals.length}');
      if (journals.isEmpty) {
        logger.d('[PaymentService]', 'No journals found, returning empty list');
        return [];
      }

      // 3. Construir lista de AvailableJournal con métodos de pago
      final result = <AvailableJournal>[];
      for (final journal in journals) {
        // Obtener métodos de pago inbound del diario
        final methods = await _getPaymentMethodsFromLocal(journal.odooId);
        logger.d('[PaymentService]', 'Journal ${journal.odooId} (${journal.name}): ${methods.length} payment methods');

        // Solo agregar si tiene métodos de pago inbound
        if (methods.isNotEmpty) {
          result.add(AvailableJournal(
            id: journal.odooId,
            name: journal.name,
            type: journal.type,
            isCardJournal: journal.isCardJournal,
            paymentMethods: methods,
            cardBrandIds: _decodeIntList(journal.cardBrandIds),
            defaultCardBrandId: journal.defaultCardBrandId,
            deadlineCreditIds: _decodeIntList(journal.cardDeadlineCreditIds),
            deadlineDebitIds: _decodeIntList(journal.cardDeadlineDebitIds),
            defaultDeadlineCreditId: journal.defaultCardDeadlineCreditId,
            defaultDeadlineDebitId: journal.defaultCardDeadlineDebitId,
          ));
        }
      }

      logger.d('[PaymentService]', 'Returning ${result.length} journals with payment methods');
      return result;
    } catch (e) {
      logger.d('[PaymentService]', 'EXCEPTION in _getAvailableJournalsFromLocal: $e');
      logger.w('[PaymentService]', 'Error loading journals from local DB: $e');
      return [];
    }
  }

  /// Obtiene métodos de pago de un diario desde la base local
  ///
  /// Para diarios tipo 'cash' y 'bank': métodos inbound (recibir pagos)
  /// Para diarios tipo 'credit' (procesadores de tarjeta como DATAFAST):
  ///   - Primero intenta inbound (pagos entrantes configurados)
  ///   - Si no hay, usa outbound (para compatibilidad con configuraciones legacy)
  Future<List<PaymentMethod>> _getPaymentMethodsFromLocal(int journalId) async {
    try {
      logger.d('[PaymentService]', '_getPaymentMethodsFromLocal START for journalId=$journalId');

      // Get journal type using raw query to avoid Drift mapping issues
      final journalResult = await _db.customSelect(
        'SELECT type FROM account_journal WHERE odoo_id = $journalId',
      ).getSingleOrNull();

      if (journalResult == null) {
        logger.d('[PaymentService]', '_getPaymentMethodsFromLocal: journal $journalId not found');
        return [];
      }

      final journalType = journalResult.read<String>('type');
      logger.d('[PaymentService]', 'Journal $journalId has type: $journalType');

      // Debug: verificar cuántos métodos de pago hay en total para este journal
      final allMethodsCount = await _db.customSelect(
        'SELECT COUNT(*) as cnt FROM account_payment_method_line WHERE journal_id = $journalId',
      ).getSingle();
      logger.d('[PaymentService]', 'Total methods in DB for journal $journalId: ${allMethodsCount.read<int>('cnt')}');

      // Query payment methods using raw SQL to avoid Drift issues
      String paymentType = 'inbound';
      var methodRows = await _db.customSelect(
        'SELECT odoo_id, name, payment_method_code FROM account_payment_method_line '
        'WHERE journal_id = $journalId AND payment_type = ?',
        variables: [Variable.withString(paymentType)],
      ).get();

      logger.d('[PaymentService]', 'Found ${methodRows.length} $paymentType methods for journal $journalId');

      // For credit journals, try outbound if no inbound found
      if (methodRows.isEmpty && journalType == 'credit') {
        paymentType = 'outbound';
        methodRows = await _db.customSelect(
          'SELECT odoo_id, name, payment_method_code FROM account_payment_method_line '
          'WHERE journal_id = $journalId AND payment_type = ?',
          variables: [Variable.withString(paymentType)],
        ).get();
        logger.d('[PaymentService]', 'Fallback to outbound: ${methodRows.length} methods');
      }

      // Map results to PaymentMethod
      // Use the line's custom name (e.g., "Deposito1") instead of generic translation
      return methodRows.map((row) {
        return PaymentMethod(
          id: row.read<int>('odoo_id'),
          name: row.read<String>('name'), // Custom line name from account.payment.method.line
          code: row.readNullable<String>('payment_method_code') ?? 'manual',
        );
      }).toList();
    } catch (e) {
      logger.d('[PaymentService]', '_getPaymentMethodsFromLocal EXCEPTION: $e');
      logger.w('[PaymentService]', 'Error loading payment methods from local DB for journal $journalId: $e');
      return [];
    }
  }

  /// Obtiene diarios desde Odoo API (online fallback)
  Future<List<AvailableJournal>> _getAvailableJournalsFromOdoo(int? sessionId) async {
    List<int> allowedJournalIds = [];

    // 1. Intentar obtener diarios desde la configuración de la sesión
    if (sessionId != null) {
      final sessions = await _odoo.call(
        model: 'collection.session',
        method: 'search_read',
        kwargs: {
          'domain': [['id', '=', sessionId]],
          'fields': ['config_id'],
          'limit': 1,
        },
      );

      if (sessions is List && sessions.isNotEmpty) {
        final configId = odoo.extractMany2oneId(sessions[0]['config_id']);
        if (configId != null) {
          // Obtener diarios permitidos + diario de efectivo del punto de cobro
          final configs = await _odoo.call(
            model: 'collection.config',
            method: 'search_read',
            kwargs: {
              'domain': [['id', '=', configId]],
              'fields': ['allowed_journal_ids', 'cash_journal_id'],
              'limit': 1,
            },
          );

          if (configs is List && configs.isNotEmpty) {
            final config = configs[0] as Map<String, dynamic>;
            // Agregar diarios permitidos
            if (config['allowed_journal_ids'] is List) {
              allowedJournalIds.addAll((config['allowed_journal_ids'] as List).cast<int>());
            }
            // Agregar diario de efectivo
            final cashJournalId = odoo.extractMany2oneId(config['cash_journal_id']);
            if (cashJournalId != null && !allowedJournalIds.contains(cashJournalId)) {
              allowedJournalIds.add(cashJournalId);
            }
          }
        }
      }
    }

    // 2. Obtener diarios
    List<dynamic>? journals;
    const journalFields = [
      'id', 'name', 'type', 'is_card_journal',
      'card_brand_ids', 'default_card_brand_id',
      'card_deadline_credit_ids', 'card_deadline_debit_ids',
      'default_card_deadline_credit_id', 'default_card_deadline_debit_id',
    ];

    if (allowedJournalIds.isNotEmpty) {
      journals = await _odoo.call(
        model: 'account.journal',
        method: 'search_read',
        kwargs: {
          'domain': [['id', 'in', allowedJournalIds]],
          'fields': journalFields,
          'order': 'sequence, id',
        },
      );
    } else {
      // Fallback: usar diarios con disponible_ventas=true
      logger.w('[PaymentService]', 'No session config found, using fallback');
      final companyId = await _getUserCompanyId();
      journals = await _odoo.call(
        model: 'account.journal',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['type', 'in', ['cash', 'bank', 'credit']],
            ['disponible_ventas', '=', true],
            ['company_id', '=', companyId],
          ],
          'fields': journalFields,
          'order': 'sequence, id',
        },
      );
    }

    if (journals == null || journals.isEmpty) {
      return [];
    }

    final result = <AvailableJournal>[];
    for (final journalData in journals) {
      final journal = journalData as Map<String, dynamic>;
      final journalId = journal['id'] as int;
      final journalType = journal['type'] as String?;

      // Obtener métodos de pago del diario
      final methods = await _getPaymentMethods(journalId, journalType: journalType);

      // Solo agregar si tiene métodos de pago
      if (methods.isNotEmpty) {
        final cardBrandIds = (journal['card_brand_ids'] as List?)?.cast<int>() ?? [];
        final deadlineCreditIds = (journal['card_deadline_credit_ids'] as List?)?.cast<int>() ?? [];
        final deadlineDebitIds = (journal['card_deadline_debit_ids'] as List?)?.cast<int>() ?? [];

        result.add(AvailableJournal(
          id: journalId,
          name: journal['name'] as String,
          type: journal['type'] as String,
          isCardJournal: journal['is_card_journal'] as bool? ?? false,
          paymentMethods: methods,
          cardBrandIds: cardBrandIds,
          defaultCardBrandId: odoo.extractMany2oneId(journal['default_card_brand_id']),
          deadlineCreditIds: deadlineCreditIds,
          deadlineDebitIds: deadlineDebitIds,
          defaultDeadlineCreditId: odoo.extractMany2oneId(journal['default_card_deadline_credit_id']),
          defaultDeadlineDebitId: odoo.extractMany2oneId(journal['default_card_deadline_debit_id']),
        ));
      }
    }

    return result;
  }

  /// Obtiene los métodos de pago de un diario
  /// Obtiene métodos de pago de un diario desde Odoo API
  ///
  /// [journalId]: ID del diario
  /// [journalType]: Tipo de diario ('cash', 'bank', 'credit')
  Future<List<PaymentMethod>> _getPaymentMethods(int journalId, {String? journalType}) async {
    try {
      List<dynamic>? methods;

      if (journalType == 'credit') {
        // Para diarios 'credit' (procesadores), intentar primero inbound
        methods = await _odoo.call(
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

        // Si no hay métodos inbound, usar outbound como fallback
        if (methods == null || methods.isEmpty) {
          methods = await _odoo.call(
            model: 'account.payment.method.line',
            method: 'search_read',
            kwargs: {
              'domain': [
                ['journal_id', '=', journalId],
                ['payment_type', '=', 'outbound'],
              ],
              'fields': ['id', 'name', 'code'],
            },
          );
        }
      } else {
        // Para diarios 'cash' y 'bank', usar métodos inbound
        methods = await _odoo.call(
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
      }

      if (methods == null) {
        return [];
      }

      return methods.map((m) {
        final data = m as Map<String, dynamic>;
        // Use the line's custom name (e.g., "Deposito1") - don't translate
        // The 'name' field from account.payment.method.line is the user-defined name
        data['spanish_name'] = data['name'] as String;
        return PaymentMethod.fromOdoo(data);
      }).toList();
    } catch (e) {
      logger.e('[PaymentService]', 'Error getting payment methods for journal $journalId', e);
      return [];
    }
  }

  /// Obtiene los anticipos disponibles del cliente
  ///
  /// Usa datos locales (offline-first)
  Future<List<AvailableAdvance>> getAvailableAdvances(int partnerId) async {
    try {
      // Obtener anticipos de la base local
      final advances = await (_db.select(_db.accountAdvance)
            ..where((t) => t.partnerId.equals(partnerId))
            ..where((t) => t.advanceType.equals('advance'))
            ..where((t) => t.state.isIn(['posted', 'in_use']))
            ..where((t) => t.amountAvailable.isBiggerThanValue(0))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

      if (advances.isEmpty) {
        logger.d('[PaymentService]', 'No advances found locally for partner $partnerId');
        return [];
      }

      // Convertir a AvailableAdvance
      return advances.map((a) => AvailableAdvance(
        id: a.odooId,
        name: a.name,
        amountAvailable: a.amountAvailable,
        date: a.date,
        reference: a.reference,
      )).toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting advances for partner $partnerId', e, st);
      return [];
    }
  }

  /// Obtiene las notas de crédito disponibles del cliente
  ///
  /// Usa datos locales (offline-first)
  Future<List<AvailableCreditNote>> getAvailableCreditNotes(int partnerId) async {
    try {
      // Obtener notas de crédito de la base local (usando accountMove con moveType='out_refund')
      final creditNotes = await (_db.select(_db.accountMove)
            ..where((t) => t.partnerId.equals(partnerId))
            ..where((t) => t.moveType.equals('out_refund'))
            ..where((t) => t.state.equals('posted'))
            ..where((t) => t.paymentState.isIn(['not_paid', 'partial']))
            ..where((t) => t.amountResidual.isBiggerThanValue(0))
            ..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)]))
          .get();

      if (creditNotes.isEmpty) {
        logger.d('[PaymentService]', 'No credit notes found locally for partner $partnerId');
        return [];
      }

      // Convertir a AvailableCreditNote
      return creditNotes.map((nc) => AvailableCreditNote(
        id: nc.odooId,
        name: nc.name ?? '',
        amountResidual: nc.amountResidual,
        invoiceDate: nc.invoiceDate,
        ref: nc.ref,
      )).toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting credit notes for partner $partnerId', e, st);
      return [];
    }
  }

  /// Obtiene los bancos disponibles (delegado a BankRepository)
  ///
  /// Sigue patrón offline-first:
  /// 1. Lee de tabla local resBank
  /// 2. Si vacía y online, sincroniza desde Odoo
  /// 3. Retorna desde local
  Future<List<AvailableBank>> getBanks() async {
    try {
      final banks = await _bankRepo.getBanks();
      return banks
          .map((b) => AvailableBank(id: b.odooId, name: b.name))
          .toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting banks', e, st);
      return [];
    }
  }

  /// Obtiene las marcas de tarjeta configuradas para un diario (sync-on-demand)
  /// Si las marcas no están en local, sincroniza desde Odoo primero
  Future<List<CardBrand>> getCardBrands(int journalId) async {
    try {
      logger.d('[PaymentService]', 'getCardBrands($journalId) START');

      // 1. Obtener el diario de la base local por odooId
      final journal = await (_db.select(_db.accountJournal)
            ..where((t) => t.odooId.equals(journalId)))
          .getSingleOrNull();

      if (journal == null) {
        logger.w('[PaymentService]', 'Journal $journalId not found locally');
        return [];
      }

      logger.d('[PaymentService]', 'Journal found: ${journal.name}, cardBrandIds raw: ${journal.cardBrandIds}');

      // Decodificar IDs de marcas del JSON
      final brandIds = _decodeIntList(journal.cardBrandIds);
      logger.d('[PaymentService]', 'Decoded brandIds: $brandIds');

      // Si el diario NO tiene marcas configuradas, retornar lista vacía
      if (brandIds.isEmpty) {
        logger.d('[PaymentService]', 'Journal $journalId has no configured card brands');
        return [];
      }

      // 2. Obtener las marcas de la base local
      var brands = await (_db.select(_db.accountCreditCardBrand)
            ..where((t) => t.odooId.isIn(brandIds))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

      logger.d('[PaymentService]', 'Brands from DB (filtered): ${brands.map((b) => '${b.odooId}:${b.name}').join(', ')}');

      // 3. Si faltan marcas, sincronizar desde Odoo
      if (brands.isEmpty || brands.length < brandIds.length) {
        logger.d('[PaymentService]', 'Card brands incomplete locally, syncing from Odoo...');
        await _syncCardBrandsFromOdoo(brandIds);

        // Recargar desde local
        brands = await (_db.select(_db.accountCreditCardBrand)
              ..where((t) => t.odooId.isIn(brandIds))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
      }

      final result = brands.map((b) => CardBrand(id: b.odooId, name: b.name)).toList();
      logger.d('[PaymentService]', 'getCardBrands returning ${result.length} brands: ${result.map((b) => b.name).join(', ')}');
      return result;
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting card brands', e, st);
      return [];
    }
  }

  /// Sincroniza marcas de tarjeta desde Odoo
  Future<void> _syncCardBrandsFromOdoo(List<int> brandIds) async {
    try {
      final result = await _odoo.call(
        model: 'account.credit.card.brand',
        method: 'search_read',
        kwargs: {
          'domain': [['id', 'in', brandIds]],
          'fields': ['id', 'name', 'code', 'credit', 'debit', 'active', 'company_id'],
        },
      );

      if (result == null || result is! List) return;

      for (final b in result) {
        final odooId = b['id'] as int;

        final companion = AccountCreditCardBrandCompanion(
          odooId: Value(odooId),
          name: Value(b['name'] as String? ?? ''),
          code: Value(b['code'] as String?),
          active: Value(b['active'] as bool? ?? true),
        );

        final existing = await (_db.select(_db.accountCreditCardBrand)
              ..where((t) => t.odooId.equals(odooId)))
            .getSingleOrNull();

        if (existing != null) {
          await (_db.update(_db.accountCreditCardBrand)
                ..where((t) => t.id.equals(existing.id)))
              .write(companion);
        } else {
          await _db.into(_db.accountCreditCardBrand).insert(companion);
        }
      }
      logger.d('[PaymentService]', 'Synced ${result.length} card brands from Odoo');
    } catch (e) {
      logger.w('[PaymentService]', 'Could not sync card brands from Odoo: $e');
    }
  }

  /// Obtiene los plazos de tarjeta configurados para un diario (sync-on-demand)
  /// Si los plazos no están en local, sincroniza desde Odoo primero
  Future<List<CardDeadline>> getCardDeadlines(int journalId, CardType cardType) async {
    try {
      // 1. Obtener el diario de la base local
      final journal = await (_db.select(_db.accountJournal)
            ..where((t) => t.odooId.equals(journalId)))
          .getSingleOrNull();

      if (journal == null) {
        logger.w('[PaymentService]', 'Journal $journalId not found locally');
        return [];
      }

      // Decodificar IDs de plazos según el tipo de tarjeta
      final deadlineIds = cardType == CardType.credit
          ? _decodeIntList(journal.cardDeadlineCreditIds)
          : _decodeIntList(journal.cardDeadlineDebitIds);

      // Si no hay plazos configurados, retornar lista vacía
      if (deadlineIds.isEmpty) {
        logger.d('[PaymentService]', 'Journal $journalId has no configured ${cardType.name} deadlines');
        return [];
      }

      // 2. Obtener los plazos de la base local
      var deadlines = await (_db.select(_db.accountCreditCardDeadline)
            ..where((t) => t.odooId.isIn(deadlineIds))
            ..orderBy([
              (t) => OrderingTerm.asc(t.name),
            ]))
          .get();

      // 3. Si faltan plazos, sincronizar desde Odoo
      if (deadlines.isEmpty || deadlines.length < deadlineIds.length) {
        logger.d('[PaymentService]', 'Card deadlines incomplete locally, syncing from Odoo...');
        await _syncCardDeadlinesFromOdoo(deadlineIds);

        // Recargar desde local
        deadlines = await (_db.select(_db.accountCreditCardDeadline)
              ..where((t) => t.odooId.isIn(deadlineIds))
              ..orderBy([
                (t) => OrderingTerm.asc(t.name),
              ]))
            .get();
      }

      return deadlines.map((d) => CardDeadline(
        id: d.odooId,
        name: d.name,
        deadlineDays: d.deadlineDays,
        percentage: d.percentage,
      )).toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting card deadlines', e, st);
      return [];
    }
  }

  /// Sincroniza plazos de tarjeta desde Odoo
  Future<void> _syncCardDeadlinesFromOdoo(List<int> deadlineIds) async {
    try {
      final result = await _odoo.call(
        model: 'account.credit.card.deadline',
        method: 'search_read',
        kwargs: {
          'domain': [['id', 'in', deadlineIds]],
          'fields': ['id', 'name', 'code', 'credit', 'debit', 'meses', 'interes', 'sequence', 'active', 'company_id'],
        },
      );

      if (result == null || result is! List) return;

      for (final d in result) {
        final odooId = d['id'] as int;

        final companion = AccountCreditCardDeadlineCompanion(
          odooId: Value(odooId),
          name: Value(d['name'] as String? ?? ''),
          deadlineDays: Value(d['meses'] as int? ?? d['deadline_days'] as int? ?? 0),
          percentage: Value((d['percentage'] as num? ?? 0.0).toDouble()),
          active: Value(d['active'] as bool? ?? true),
        );

        final existing = await (_db.select(_db.accountCreditCardDeadline)
              ..where((t) => t.odooId.equals(odooId)))
            .getSingleOrNull();

        if (existing != null) {
          await (_db.update(_db.accountCreditCardDeadline)
                ..where((t) => t.id.equals(existing.id)))
              .write(companion);
        } else {
          await _db.into(_db.accountCreditCardDeadline).insert(companion);
        }
      }
      logger.d('[PaymentService]', 'Synced ${result.length} card deadlines from Odoo');
    } catch (e) {
      logger.w('[PaymentService]', 'Could not sync card deadlines from Odoo: $e');
    }
  }

  /// Obtiene los lotes abiertos para un diario (sync-on-demand)
  /// Si no hay lotes locales, sincroniza desde Odoo primero
  Future<List<CardLote>> getOpenLotes(int journalId) async {
    try {
      // 1. Obtener lotes abiertos de la base local
      var lotes = await (_db.select(_db.accountCardLote)
            ..where((t) => t.journalId.equals(journalId))
            ..where((t) => t.state.equals('open'))
            ..orderBy([(t) => OrderingTerm.desc(t.dateFrom)]))
          .get();

      // 2. Si no hay lotes locales, sincronizar desde Odoo
      if (lotes.isEmpty) {
        logger.d('[PaymentService]', 'No local lotes for journal $journalId, syncing from Odoo...');
        await _syncLotesFromOdoo(journalId);

        // Recargar desde local
        lotes = await (_db.select(_db.accountCardLote)
              ..where((t) => t.journalId.equals(journalId))
              ..where((t) => t.state.equals('open'))
              ..orderBy([(t) => OrderingTerm.desc(t.dateFrom)]))
            .get();
      }

      // Convertir objetos Drift a CardLote
      return lotes.map((l) => CardLote(
        id: l.odooId,
        localId: l.id,
        name: l.name,
        journalId: l.journalId,
        journalName: l.journalName,
        state: l.state,
        date: l.dateFrom,
        numeroLote: l.code,
        amountTotal: l.totalAmount,
        amountBalance: 0.0, // Field doesn't exist in table
        paymentCount: l.transactionCount,
        isPosLote: false, // Field doesn't exist in table
      )).toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting open lotes', e, st);
      return [];
    }
  }

  /// Sincroniza lotes desde Odoo para un diario
  Future<void> _syncLotesFromOdoo(int journalId) async {
    try {
      final result = await _odoo.call(
        model: 'account.card.lote',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['journal_id', '=', journalId],
            ['state', '=', 'open'],
          ],
          'fields': [
            'id', 'name', 'journal_id', 'state', 'date',
            'numero_lote', 'amount_total', 'amount_balance',
            'payment_count', 'is_pos_lote', 'start_at', 'stop_at',
            'cashier_id', 'company_id',
          ],
          'order': 'date desc',
          'limit': 50,
        },
      );

      if (result == null || result is! List) return;

      for (final l in result) {
        final odooId = l['id'] as int;

        // Extraer journal
        int journalIdVal = journalId;
        final journalData = l['journal_id'];
        if (journalData is List && journalData.isNotEmpty) {
          journalIdVal = journalData[0] as int;
        }

        // Parsear fecha
        DateTime? date;
        final dateStr = l['date'];
        if (dateStr is String && dateStr.isNotEmpty) {
          date = DateTime.tryParse(dateStr);
        }

        final companion = AccountCardLoteCompanion(
          odooId: Value(odooId),
          name: Value(l['name'] as String? ?? ''),
          code: Value(l['numero_lote'] as String? ?? ''),
          journalId: Value(journalIdVal),
          journalName: Value(l['journal_id'] is List && (l['journal_id'] as List).length > 1
              ? (l['journal_id'] as List)[1] as String?
              : null),
          dateFrom: Value(date ?? DateTime.now()),
          dateTo: Value((date ?? DateTime.now()).add(const Duration(days: 1))),
          totalAmount: Value((l['amount_total'] as num?)?.toDouble() ?? 0.0),
          transactionCount: Value(l['payment_count'] as int? ?? 0),
          state: Value(l['state'] as String? ?? 'open'),
          active: const Value(true),
          writeDate: Value(DateTime.now()),
        );

        final existing = await (_db.select(_db.accountCardLote)
              ..where((t) => t.odooId.equals(odooId)))
            .getSingleOrNull();

        if (existing != null) {
          await (_db.update(_db.accountCardLote)
                ..where((t) => t.id.equals(existing.id)))
              .write(companion);
        } else {
          await _db.into(_db.accountCardLote).insert(companion);
        }
      }
      logger.d('[PaymentService]', 'Synced ${result.length} lotes from Odoo');
    } catch (e) {
      logger.w('[PaymentService]', 'Could not sync lotes from Odoo: $e');
    }
  }

  /// Crea un nuevo lote de tarjetas para un diario
  ///
  /// [journalId]: ID del diario de tarjetas (odooId)
  /// [isPosLote]: Si es un lote de POS (punto de venta)
  ///
  /// El número de lote se calcula automáticamente basándose en los lotes
  /// existentes para el diario y fecha.
  ///
  /// Crea primero en la base local con un UUID para tracking offline.
  /// Si hay conexión, sincroniza inmediatamente a Odoo.
  ///
  /// Retorna el lote creado o null si falla
  Future<CardLote?> createLote(int journalId, {bool isPosLote = true}) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final loteUuid = _uuid.v4();

      // 1. Calcular el siguiente número de lote basándose en los lotes locales
      // Buscar lotes existentes para el diario y fecha actual
      final tomorrow = today.add(const Duration(days: 1));
      final existingLotes = await (_db.select(_db.accountCardLote)
            ..where((t) => t.journalId.equals(journalId))
            ..where((t) => t.dateFrom.isBiggerOrEqualValue(today))
            ..where((t) => t.dateFrom.isSmallerThanValue(tomorrow))
            ..orderBy([(t) => OrderingTerm.desc(t.name)]))
          .get();

      // Calcular el siguiente número
      int nextNumber = 1;
      for (final lote in existingLotes) {
        final num = int.tryParse(lote.name);
        if (num != null && num >= nextNumber) {
          nextNumber = num + 1;
        }
      }

      final loteName = nextNumber.toString();

      // 2. Crear el lote en la base local primero
      final localId = await _db.into(_db.accountCardLote).insert(
        AccountCardLoteCompanion.insert(
          odooId: 0, // Sin odooId todavía
          name: loteName,
          code: '', // Se actualizará cuando se sincronice con Odoo
          journalId: journalId,
          dateFrom: today,
          dateTo: today.add(const Duration(days: 1)),
          state: const Value('open'),
        ),
      );

      logger.i('[PaymentService]', 'Lote created locally: $loteName (localId: $localId, uuid: $loteUuid)');

      // 3. Intentar sincronizar a Odoo si hay conexión
      try {
        final result = await _odoo.call(
          model: 'account.card.lote',
          method: 'create',
          kwargs: {
            'vals_list': [
              {
                'name': loteName, // Solo dígitos, requerido
                'journal_id': journalId,
                'is_pos_lote': isPosLote,
                'date': today.toIso8601String().split('T')[0],
              }
            ],
          },
        );

        if (result != null) {
          final odooId = result is List ? result[0] as int : result as int;

          // Obtener datos completos del lote de Odoo
          final odooLotes = await _odoo.call(
            model: 'account.card.lote',
            method: 'search_read',
            kwargs: {
              'domain': [['id', '=', odooId]],
              'fields': [
                'id', 'name', 'journal_id', 'state', 'date',
                'numero_lote', 'amount_total', 'amount_balance',
                'payment_count', 'is_pos_lote',
              ],
              'limit': 1,
            },
          );

          String? numeroLote;
          if (odooLotes is List && odooLotes.isNotEmpty) {
            numeroLote = odooLotes[0]['numero_lote'] as String?;
          }

          // Actualizar el registro local con el odooId
          await (_db.update(_db.accountCardLote)
                ..where((t) => t.id.equals(localId)))
              .write(AccountCardLoteCompanion(
            odooId: Value(odooId),
            code: Value(numeroLote ?? ''),
          ));

          logger.i('[PaymentService]', 'Lote synced to Odoo: $loteName (odooId: $odooId, numero_lote: $numeroLote)');

          return CardLote(
            id: odooId,
            localId: localId,
            loteUuid: loteUuid,
            name: loteName,
            journalId: journalId,
            state: 'open',
            date: today,
            numeroLote: numeroLote,
            amountTotal: 0.0,
            amountBalance: 0.0,
            paymentCount: 0,
            isPosLote: isPosLote,
          );
        }
      } catch (syncError) {
        // Si falla la sincronización, retornar el lote local sin odooId
        logger.w('[PaymentService]', 'Failed to sync lote to Odoo, will sync later: $syncError');
      }

      // Retornar el lote local (sin odooId si no se sincronizó)
      return CardLote(
        id: 0, // Sin odooId todavía
        localId: localId,
        loteUuid: loteUuid,
        name: loteName,
        journalId: journalId,
        state: 'open',
        date: today,
        numeroLote: null,
        amountTotal: 0.0,
        amountBalance: 0.0,
        paymentCount: 0,
        isPosLote: isPosLote,
      );
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error creating lote', e, st);
      return null;
    }
  }

  /// Guarda las líneas de pago en la orden de venta
  ///
  /// OFFLINE-FIRST:
  /// 1. Guarda las líneas en la base local primero
  /// 2. Si online, intenta sincronizar con Odoo
  /// 3. Si offline o falla sync, encola para procesamiento posterior
  Future<bool> savePaymentLines(
    int saleOrderId,
    List<PaymentLine> lines, {
    int? collectionSessionId,
  }) async {
    try {
      if (lines.isEmpty) {
        logger.w('[PaymentService]', 'No payment lines to save');
        return true;
      }

      // 1. SIEMPRE guardar en base local primero
      await _savePaymentLinesLocally(saleOrderId, lines, collectionSessionId);
      logger.d('[PaymentService]', 'Payment lines saved locally for order $saleOrderId');

      // 2. Intentar sincronizar si estamos online
      if (_isOnline) {
        try {
          await _syncPaymentLinesToOdoo(saleOrderId, lines, collectionSessionId);

          // Marcar como sincronizadas
          await _markPaymentLinesAsSynced(saleOrderId);
          logger.i('[PaymentService]', 'Payment lines synced to Odoo for order $saleOrderId');
          return true;
        } catch (syncError) {
          logger.w('[PaymentService]', 'Failed to sync payment lines, queueing: $syncError');
          await _queuePaymentLinesForSync(saleOrderId, lines, collectionSessionId);
        }
      } else {
        // 3. Si offline, encolar para sincronización posterior
        logger.d('[PaymentService]', 'Offline - queueing payment lines for sync');
        await _queuePaymentLinesForSync(saleOrderId, lines, collectionSessionId);
      }

      return true;
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error saving payment lines', e, st);
      return false;
    }
  }

  /// Guarda las líneas de pago en la base de datos local
  Future<void> _savePaymentLinesLocally(
    int saleOrderId,
    List<PaymentLine> lines,
    int? collectionSessionId,
  ) async {
    for (final line in lines) {
      final lineUuid = line.lineUuid ?? _uuid.v4();

      await _db.into(_db.saleOrderPaymentLine).insertOnConflictUpdate(
        SaleOrderPaymentLineCompanion.insert(
          lineUuid: Value(lineUuid),
          orderId: saleOrderId,
          paymentType: const Value('inbound'),
          journalId: Value(line.journalId),
          journalName: Value(line.journalName),
          journalType: Value(line.journalType),
          paymentMethodLineId: Value(line.paymentMethodLineId),
          paymentMethodCode: Value(line.paymentMethodCode),
          paymentMethodName: Value(line.paymentMethodName),
          amount: Value(line.amount),
          date: Value(line.date),
          paymentReference: Value(line.reference),
          creditNoteId: Value(line.creditNoteId),
          creditNoteName: Value(line.creditNoteName),
          advanceId: Value(line.advanceId),
          advanceName: Value(line.advanceName),
          cardType: Value(line.cardType?.name),
          cardBrandId: Value(line.cardBrandId),
          cardBrandName: Value(line.cardBrandName),
          cardDeadlineId: Value(line.cardDeadlineId),
          cardDeadlineName: Value(line.cardDeadlineName),
          loteId: Value(line.loteId),
          loteName: Value(line.loteName),
          bankId: Value(line.bankId),
          bankName: Value(line.bankName),
          partnerBankId: Value(line.partnerBankId),
          partnerBankName: Value(line.partnerBankName),
          effectiveDate: Value(line.effectiveDate),
          state: const Value('draft'),
          isSynced: const Value(false),
        ),
      );
    }
  }

  /// Sincroniza las líneas de pago a Odoo
  Future<void> _syncPaymentLinesToOdoo(
    int saleOrderId,
    List<PaymentLine> lines,
    int? collectionSessionId,
  ) async {
    // Preparar las líneas para Odoo
    final lineVals = lines.map((l) => [0, 0, paymentLineManager.toOdoo(l)]).toList();

    // Crear el wizard usando vals_list (requerido por Odoo 18 JSON2 API)
    final wizardId = await _odoo.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'sale_id': saleOrderId,
            if (collectionSessionId != null) 'collection_session_id': collectionSessionId,
            'line_ids': lineVals,
          }
        ],
      },
    );

    if (wizardId == null) {
      throw Exception('Failed to create payment wizard');
    }

    // Ejecutar action_apply con ids como args
    final actualId = wizardId is List ? wizardId[0] : wizardId;
    await _odoo.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'action_apply',
      kwargs: {'ids': [actualId]},
    );
  }

  /// Marca las líneas de pago como sincronizadas
  Future<void> _markPaymentLinesAsSynced(int saleOrderId) async {
    await (_db.update(_db.saleOrderPaymentLine)
          ..where((t) => t.orderId.equals(saleOrderId)))
        .write(const SaleOrderPaymentLineCompanion(
      isSynced: Value(true),
      lastSyncDate: Value(null), // Se actualizará con DateTime.now()
    ));

    // Actualizar con fecha actual
    await (_db.update(_db.saleOrderPaymentLine)
          ..where((t) => t.orderId.equals(saleOrderId)))
        .write(SaleOrderPaymentLineCompanion(
      lastSyncDate: Value(DateTime.now()),
    ));
  }

  /// Encola las líneas de pago para sincronización posterior
  Future<void> _queuePaymentLinesForSync(
    int saleOrderId,
    List<PaymentLine> lines,
    int? collectionSessionId,
  ) async {
    if (_offlineQueue == null) return;

    await _offlineQueue.queueOperation(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'apply_payment_lines',
      recordId: saleOrderId,
      values: {
        'sale_id': saleOrderId,
        if (collectionSessionId != null) 'collection_session_id': collectionSessionId,
        'lines': lines.map((l) => paymentLineManager.toOdoo(l)).toList(),
      },
      priority: OfflinePriority.high,
    );
  }

  /// Guarda y crea factura
  Future<int?> savePaymentLinesAndCreateInvoice(
    int saleOrderId,
    List<PaymentLine> lines, {
    int? collectionSessionId,
  }) async {
    try {
      if (lines.isEmpty) {
        logger.w('[PaymentService]', 'No payment lines to save');
        return null;
      }

      // Preparar las líneas para Odoo
      final lineVals = lines.map((l) => [0, 0, paymentLineManager.toOdoo(l)]).toList();

      // Crear el wizard usando vals_list (requerido por Odoo 18 JSON2 API)
      final wizardId = await _odoo.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'create',
        kwargs: {
          'vals_list': [
            {
              'sale_id': saleOrderId,
              if (collectionSessionId != null) 'collection_session_id': collectionSessionId,
              'line_ids': lineVals,
            }
          ],
        },
      );

      if (wizardId == null) {
        throw Exception('Failed to create payment wizard');
      }

      // Ejecutar action_apply_and_create_invoice con ids como kwargs
      final actualId = wizardId is List ? wizardId[0] : wizardId;
      final result = await _odoo.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'action_apply_and_create_invoice',
        kwargs: {'ids': [actualId]},
      );

      logger.i('[PaymentService]', 'Payment lines saved and invoice created: $result');

      // Intentar extraer el ID de la factura del resultado
      if (result is Map && result.containsKey('res_id')) {
        return result['res_id'] as int?;
      }

      return null;
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error saving payment lines and creating invoice', e, st);
      return null;
    }
  }

  /// Crea factura para venta a crédito (sin pagos)
  ///
  /// Usa el wizard estándar de Odoo para crear la factura.
  /// Retorna el ID de la factura creada o null si falla.
  Future<int?> createInvoiceForCreditSale(int saleOrderId) async {
    try {
      logger.i('[PaymentService]', 'Creating invoice for credit sale: $saleOrderId');

      // Crear wizard de facturación con contexto de la orden
      final wizardId = await _odoo.call(
        model: 'sale.advance.payment.inv',
        method: 'create',
        kwargs: {
          'vals_list': [
            {
              'advance_payment_method': 'delivered', // Facturar productos entregados
            }
          ],
        },
        context: {
          'active_ids': [saleOrderId],
          'active_model': 'sale.order',
          'active_id': saleOrderId,
        },
      );

      if (wizardId == null) {
        throw Exception('Failed to create invoice wizard');
      }

      // Ejecutar create_invoices del wizard
      final actualId = wizardId is List ? wizardId[0] : wizardId;
      final result = await _odoo.call(
        model: 'sale.advance.payment.inv',
        method: 'create_invoices',
        kwargs: {'ids': [actualId]},
        context: {
          'active_ids': [saleOrderId],
          'active_model': 'sale.order',
          'active_id': saleOrderId,
        },
      );

      logger.i('[PaymentService]', 'Invoice created: $result');

      // Obtener el ID de la factura creada buscando facturas de la orden
      final invoices = await _odoo.call(
        model: 'account.move',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['invoice_origin', '=', await _getOrderName(saleOrderId)],
            ['move_type', '=', 'out_invoice'],
          ],
          'fields': ['id', 'name'],
          'order': 'id desc',
          'limit': 1,
        },
      );

      if (invoices is List && invoices.isNotEmpty) {
        return invoices[0]['id'] as int?;
      }

      return null;
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error creating invoice for credit sale', e, st);
      rethrow;
    }
  }

  /// Obtiene el nombre de la orden
  Future<String?> _getOrderName(int orderId) async {
    try {
      final result = await _odoo.call(
        model: 'sale.order',
        method: 'search_read',
        kwargs: {
          'domain': [['id', '=', orderId]],
          'fields': ['name'],
          'limit': 1,
        },
      );
      if (result is List && result.isNotEmpty) {
        return result[0]['name'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // CRÉDITO - Información de crédito del cliente
  // ============================================================

  /// Obtiene la información de crédito del cliente
  Future<PartnerCreditInfo?> getPartnerCreditInfo(int partnerId) async {
    try {
      // Usar search_read en lugar de read para evitar problemas con la API JSON2
      final result = await _odoo.call(
        model: 'res.partner',
        method: 'search_read',
        kwargs: {
          'domain': [['id', '=', partnerId]],
          'fields': [
            'credit_limit',
            'credit',
            'credit_to_invoice',
            'total_overdue',
            'unpaid_invoices_count',
            'credit_available',
            'allow_over_credit',
          ],
          'limit': 1,
        },
      );

      if (result == null || result is! List || result.isEmpty) {
        return null;
      }

      final data = result[0] as Map<String, dynamic>;

      return PartnerCreditInfo(
        creditLimit: (data['credit_limit'] as num?)?.toDouble() ?? 0,
        creditUsed: (data['credit'] as num?)?.toDouble() ?? 0,
        creditToInvoice: (data['credit_to_invoice'] as num?)?.toDouble() ?? 0,
        totalOverdue: (data['total_overdue'] as num?)?.toDouble() ?? 0,
        unpaidInvoicesCount: data['unpaid_invoices_count'] as int? ?? 0,
        creditAvailable: (data['credit_available'] as num?)?.toDouble() ?? 0,
        allowOverCredit: data['allow_over_credit'] as bool? ?? false,
      );
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting partner credit info', e, st);
      return null;
    }
  }

  // ============================================================
  // RETENCIONES - Registro de retenciones del cliente
  // ============================================================

  /// Obtiene los tipos de retención disponibles
  Future<List<WithholdingType>> getWithholdingTypes() async {
    try {
      // Obtener impuestos de retención (grupo de retención)
      final taxes = await _odoo.call(
        model: 'account.tax',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['type_tax_use', '=', 'sale'],
            ['l10n_ec_code_applied', '!=', false],
            ['active', '=', true],
          ],
          'fields': ['id', 'name', 'amount', 'l10n_ec_code_applied'],
          'order': 'name',
        },
      );

      if (taxes == null || taxes is! List) {
        return [];
      }

      return taxes.map((t) {
        final tax = t as Map<String, dynamic>;
        return WithholdingType(
          id: tax['id'] as int,
          name: tax['name'] as String,
          percentage: (tax['amount'] as num).toDouble().abs(),
          code: tax['l10n_ec_code_applied'] as String? ?? '',
        );
      }).toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting withholding types', e, st);
      return [];
    }
  }

  /// Registra una retención del cliente en la orden de venta
  ///
  /// Crea un registro de retención (out_withhold) vinculado a la factura.
  ///
  /// El wizard l10n_ec.wizard.account.withhold usa context para recibir
  /// las facturas via active_ids/active_model, y el campo related_invoice_ids
  /// se computa automáticamente.
  ///
  /// [invoiceId]: ID de la factura (account.move)
  /// [lines]: Líneas de retención con tax_id, base y amount
  /// [authorizationNumber]: Número de autorización SRI (49 dígitos)
  /// [documentNumber]: Secuencia de la retención (ej: 001-001-000000001)
  Future<WithholdingResult> registerWithholding({
    required int invoiceId,
    required List<WithholdingLine> lines,
    String? authorizationNumber,
    String? documentNumber,
  }) async {
    try {
      if (lines.isEmpty) {
        return WithholdingResult(
          success: false,
          errorMessage: 'Debe agregar al menos una línea de retención',
        );
      }

      // Preparar valores del wizard
      // El wizard usa context para recibir las facturas (active_ids)
      final wizardVals = <String, dynamic>{};

      // Para retenciones de venta (out_withhold), se requiere número de autorización manual
      if (authorizationNumber != null && authorizationNumber.isNotEmpty) {
        wizardVals['manual_authorization_number'] = authorizationNumber;
      }

      // Número de documento/secuencia de la retención
      if (documentNumber != null && documentNumber.isNotEmpty) {
        wizardVals['document_number'] = documentNumber;
      }

      // Crear wizard con contexto de la factura activa
      // El wizard obtiene las facturas desde context['active_ids']
      final wizardId = await _odoo.call(
        model: 'l10n_ec.wizard.account.withhold',
        method: 'create',
        kwargs: {'vals_list': [wizardVals]},
        context: {
          'active_ids': [invoiceId],
          'active_model': 'account.move',
          'active_id': invoiceId,
        },
      );

      if (wizardId == null) {
        throw Exception('Failed to create withholding wizard');
      }

      final id = wizardId is List ? wizardId[0] as int : wizardId as int;
      logger.d('[PaymentService]', 'Created withhold wizard: $id for invoice $invoiceId');

      // Agregar líneas de retención
      for (final line in lines) {
        await _odoo.call(
          model: 'l10n_ec.wizard.account.withhold.line',
          method: 'create',
          kwargs: {
            'vals_list': [
              {
                'wizard_id': id,
                'invoice_id': invoiceId, // Link to invoice for taxsupport computation
                'tax_id': line.taxId,
                'base': line.base,
              }
            ],
          },
        );
      }
      logger.d('[PaymentService]', 'Added ${lines.length} withhold lines');

      // Crear y publicar la retención
      final result = await _odoo.call(
        model: 'l10n_ec.wizard.account.withhold',
        method: 'action_create_and_post_withhold',
        kwargs: {'ids': [id]},
      );

      // Obtener el ID de la retención creada
      int? withholdId;
      String? withholdName;

      if (result is Map && result.containsKey('res_id')) {
        withholdId = result['res_id'] as int?;
      }

      if (withholdId != null) {
        // Usar search_read para obtener el nombre de la retención
        final withhold = await _odoo.call(
          model: 'account.move',
          method: 'search_read',
          kwargs: {
            'domain': [['id', '=', withholdId]],
            'fields': ['name'],
            'limit': 1,
          },
        );
        if (withhold is List && withhold.isNotEmpty) {
          withholdName = (withhold[0] as Map<String, dynamic>)['name'] as String?;
        }
      }

      logger.i('[PaymentService]', 'Withholding registered: $withholdName');

      // Calcular total retenido de las líneas
      final totalWithheld = lines.fold(0.0, (sum, line) => sum + line.amount);

      return WithholdingResult(
        success: true,
        withholdId: withholdId,
        withholdName: withholdName,
        totalWithheld: totalWithheld,
      );
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error registering withholding', e, st);
      return WithholdingResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // ============================================================
  // APROBACIÓN DE CRÉDITO
  // ============================================================

  /// Solicita aprobación de crédito para una orden de venta
  ///
  /// Crea una solicitud de aprobación cuando el cliente:
  /// - Excede su límite de crédito
  /// - Tiene deudas vencidas
  /// - Requiere crédito temporal
  Future<CreditApprovalResult> requestCreditApproval({
    required int partnerId,
    required double transactionAmount,
    required CreditAuthorizationType authorizationType,
    int? saleOrderId,
    int? invoiceId,
    int? paymentTermId,
    double? creditLimit,
  }) async {
    try {
      // Convertir tipo de autorización
      final authTypeStr = switch (authorizationType) {
        CreditAuthorizationType.overdueDebt => 'overdue_debt',
        CreditAuthorizationType.creditLimitExceeded => 'credit_limit_exceeded',
        CreditAuthorizationType.temporaryCredit => 'temporary_credit',
      };

      // Crear el wizard de crédito excedido
      final wizardVals = <String, dynamic>{
        'partner_id': partnerId,
        'transaction_amount': transactionAmount,
        'authorization_type': authTypeStr,
        'check_type': authTypeStr,
      };

      if (saleOrderId != null) {
        wizardVals['sale_order_id'] = saleOrderId;
      }
      if (invoiceId != null) {
        wizardVals['invoice_id'] = invoiceId;
      }
      if (paymentTermId != null) {
        wizardVals['payment_term_id'] = paymentTermId;
      }
      if (creditLimit != null) {
        wizardVals['current_credit_limit'] = creditLimit;
      }

      // Crear el wizard usando vals_list (requerido por Odoo 18 JSON2 API)
      final wizardId = await _odoo.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'create',
        kwargs: {'vals_list': [wizardVals]},
      );

      if (wizardId == null) {
        throw Exception('Failed to create credit approval wizard');
      }

      final id = wizardId is List ? wizardId[0] as int : wizardId as int;

      // Ejecutar action_create_approval_request
      await _odoo.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'action_create_approval_request',
        kwargs: {'ids': [id]},
      );

      // La orden debe quedar en estado 'waiting'
      logger.i('[PaymentService]', 'Credit approval request created');

      // Obtener info de la solicitud creada
      // El resultado del wizard no devuelve directamente el ID
      // pero la orden queda en 'waiting' y se puede consultar
      int? approvalId;
      String? approvalName;

      if (saleOrderId != null) {
        // Buscar la solicitud de aprobación vinculada a la orden
        final approvals = await _odoo.call(
          model: 'approval.request',
          method: 'search_read',
          kwargs: {
            'domain': [
              ['sale_order_id', '=', saleOrderId],
              ['approval_type', '=', 'credit'],
            ],
            'fields': ['id', 'name'],
            'order': 'create_date desc',
            'limit': 1,
          },
        );

        if (approvals is List && approvals.isNotEmpty) {
          final approval = approvals[0] as Map<String, dynamic>;
          approvalId = approval['id'] as int;
          approvalName = approval['name'] as String?;
        }
      }

      return CreditApprovalResult(
        success: true,
        approvalId: approvalId,
        approvalName: approvalName,
      );
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error requesting credit approval', e, st);
      return CreditApprovalResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Verifica si una orden tiene aprobación de crédito pendiente
  Future<bool> hasPendingCreditApproval(int saleOrderId) async {
    try {
      final approvals = await _odoo.call(
        model: 'approval.request',
        method: 'search_count',
        kwargs: {
          'domain': [
            ['sale_order_id', '=', saleOrderId],
            ['approval_type', '=', 'credit'],
            ['request_status', '=', 'pending'],
          ],
        },
      );

      return (approvals as int? ?? 0) > 0;
    } catch (e) {
      logger.e('[PaymentService]', 'Error checking pending credit approval', e);
      return false;
    }
  }

  /// Verifica si una orden tiene aprobación de crédito aprobada
  Future<bool> hasCreditApprovalApproved(int saleOrderId) async {
    try {
      final approvals = await _odoo.call(
        model: 'approval.request',
        method: 'search_count',
        kwargs: {
          'domain': [
            ['sale_order_id', '=', saleOrderId],
            ['approval_type', '=', 'credit'],
            ['request_status', '=', 'approved'],
          ],
        },
      );

      return (approvals as int? ?? 0) > 0;
    } catch (e) {
      logger.e('[PaymentService]', 'Error checking credit approval status', e);
      return false;
    }
  }

  // ============================================================
  // COBROS DE SESIÓN - Para vista de collection
  // ============================================================

  /// Obtiene los cobros registrados en una sesión de cobranza
  ///
  /// Retorna lista de pagos asociados a la sesión especificada
  Future<List<SessionPayment>> getSessionPayments(int sessionId) async {
    try {
      final payments = await _odoo.call(
        model: 'account.payment',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['collection_session_id', '=', sessionId],
          ],
          'fields': [
            'id',
            'name',
            'partner_id',
            'journal_id',
            'payment_method_line_id',
            'amount',
            'payment_type',
            'state',
            'date',
            'ref',
            'payment_origin_type',
            'payment_method_category',
            'reconciled_invoice_ids',
          ],
          'order': 'date desc, id desc',
        },
      );

      if (payments == null || payments is! List) {
        return [];
      }

      return payments
          .map((p) => SessionPayment.fromOdoo(p as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting session payments', e, st);
      return [];
    }
  }

  /// Obtiene el detalle de un cobro específico
  Future<SessionPayment?> getPaymentDetail(int paymentId) async {
    try {
      final payments = await _odoo.call(
        model: 'account.payment',
        method: 'search_read',
        kwargs: {
          'domain': [['id', '=', paymentId]],
          'fields': [
            'id',
            'name',
            'partner_id',
            'journal_id',
            'payment_method_line_id',
            'amount',
            'payment_type',
            'state',
            'date',
            'ref',
            'payment_origin_type',
            'payment_method_category',
            'reconciled_invoice_ids',
            'move_id',
            'currency_id',
            'company_id',
            'collection_session_id',
          ],
          'limit': 1,
        },
      );

      if (payments == null || payments is! List || payments.isEmpty) {
        return null;
      }

      return SessionPayment.fromOdoo(payments[0] as Map<String, dynamic>);
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting payment detail', e, st);
      return null;
    }
  }

  // ============================================================
  // VALIDACIÓN DE PAGOS
  // ============================================================

  /// Valida las líneas de pago antes de guardar
  ///
  /// Verifica:
  /// - Que cada línea tenga monto > 0
  /// - Que los anticipos tengan saldo suficiente
  /// - Que las notas de crédito tengan saldo residual suficiente
  /// - Detecta sobrepago (pagos > total de orden)
  ///
  /// [lines]: Lista de líneas de pago a validar
  /// [orderTotal]: Monto total de la orden
  /// [partnerId]: ID del cliente (para validar anticipos y NC)
  ///
  /// Retorna un ValidationResult con errores/advertencias
  Future<ValidationResult> validatePaymentLines({
    required List<PaymentLine> lines,
    required double orderTotal,
    int? partnerId,
  }) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    if (lines.isEmpty) {
      return ValidationResult.success();
    }

    double totalPayments = 0;

    for (final line in lines) {
      // Validar monto > 0
      if (line.amount <= 0) {
        errors.add(ValidationError.invalidPaymentAmount());
        continue;
      }

      totalPayments += line.amount;

      // Validar anticipo
      if (line.type == PaymentLineType.advance && line.advanceId != null) {
        final validationError = await _validateAdvance(
          line.advanceId!,
          line.amount,
        );
        if (validationError != null) {
          errors.add(validationError);
        }
      }

      // Validar nota de crédito
      if (line.type == PaymentLineType.creditNote && line.creditNoteId != null) {
        final validationError = await _validateCreditNote(
          line.creditNoteId!,
          line.amount,
        );
        if (validationError != null) {
          errors.add(validationError);
        }
      }

      // Validar campos requeridos por tipo de pago
      if (line.type == PaymentLineType.payment) {
        final code = line.paymentMethodCode ?? '';

        // Validar campos para pagos con tarjeta
        if (code.contains('card')) {
          if (line.cardBrandId == null) {
            errors.add(ValidationError.missingPaymentInfo(field: 'Marca de tarjeta'));
          }
          if (line.cardDeadlineId == null) {
            errors.add(ValidationError.missingPaymentInfo(field: 'Plazo de tarjeta'));
          }
        }

        // Validar campos para pagos con cheque
        if (code.contains('cheque')) {
          if (line.reference == null || line.reference!.isEmpty) {
            errors.add(ValidationError.missingPaymentInfo(field: 'Número de cheque'));
          }
          if (line.bankId == null) {
            errors.add(ValidationError.missingPaymentInfo(field: 'Banco'));
          }
        }

        // Validar campos para transferencias
        if (code.contains('transf')) {
          if (line.reference == null || line.reference!.isEmpty) {
            errors.add(ValidationError.missingPaymentInfo(field: 'Referencia de transferencia'));
          }
        }
      }
    }

    // Verificar sobrepago
    if (totalPayments > orderTotal) {
      final overpayment = totalPayments - orderTotal;
      if (overpayment > 0.01) { // Tolerancia de 1 centavo
        warnings.add(ValidationWarning(
          code: 'overpayment',
          message: 'El sobrepago de ${overpayment.toCurrency()} generará un anticipo a favor del cliente.',
        ));
      }
    }

    if (errors.isNotEmpty) {
      return ValidationResult.failed(errors);
    }

    if (warnings.isNotEmpty) {
      return ValidationResult.successWithWarnings(warnings);
    }

    return ValidationResult.success();
  }

  /// Valida un anticipo antes de usarlo
  Future<ValidationError?> _validateAdvance(int advanceId, double requestedAmount) async {
    try {
      final advance = await (_db.select(_db.accountAdvance)
            ..where((t) => t.odooId.equals(advanceId)))
          .getSingleOrNull();

      if (advance == null) {
        return ValidationError.advanceNotFound(advanceId: advanceId);
      }

      if (advance.amountAvailable < requestedAmount) {
        return ValidationError.insufficientAdvanceBalance(
          advanceName: advance.name,
          available: advance.amountAvailable,
          requested: requestedAmount,
        );
      }

      return null;
    } catch (e) {
      logger.e('[PaymentService]', 'Error validating advance $advanceId', e);
      return ValidationError.advanceNotFound(advanceId: advanceId);
    }
  }

  /// Valida una nota de crédito antes de usarla
  Future<ValidationError?> _validateCreditNote(int creditNoteId, double requestedAmount) async {
    try {
      final creditNote = await (_db.select(_db.accountMove)
            ..where((t) => t.odooId.equals(creditNoteId))
            ..where((t) => t.moveType.equals('out_refund')))
          .getSingleOrNull();

      if (creditNote == null) {
        return ValidationError.creditNoteNotFound(creditNoteId: creditNoteId);
      }

      if (creditNote.amountResidual < requestedAmount) {
        return ValidationError.insufficientCreditNoteBalance(
          creditNoteName: creditNote.name ?? '',
          available: creditNote.amountResidual,
          requested: requestedAmount,
        );
      }

      return null;
    } catch (e) {
      logger.e('[PaymentService]', 'Error validating credit note $creditNoteId', e);
      return ValidationError.creditNoteNotFound(creditNoteId: creditNoteId);
    }
  }

  /// Valida si el cliente puede hacer una venta a crédito
  ///
  /// Verifica:
  /// - Límite de crédito
  /// - Deuda vencida
  /// - Crédito disponible vs monto de la orden
  ///
  /// [partnerId]: ID del cliente
  /// [orderAmount]: Monto total de la orden (solo crédito, no pagos al contado)
  Future<ValidationResult> validateCreditSale({
    required int partnerId,
    required double orderAmount,
  }) async {
    try {
      final creditInfo = await getPartnerCreditInfo(partnerId);

      if (creditInfo == null) {
        // Sin información de crédito - permitir por defecto
        return ValidationResult.success();
      }

      final errors = <ValidationError>[];
      final warnings = <ValidationWarning>[];

      // Verificar deuda vencida
      if (creditInfo.hasOverdueDebt && !creditInfo.allowOverCredit) {
        errors.add(ValidationError.overdueDebtExists(
          overdueAmount: creditInfo.totalOverdue,
          overdueCount: creditInfo.unpaidInvoicesCount,
        ));
      }

      // Verificar límite de crédito
      if (creditInfo.hasCreditLimit) {
        final totalCredit = creditInfo.creditUsed + creditInfo.creditToInvoice + orderAmount;
        if (totalCredit > creditInfo.creditLimit && !creditInfo.allowOverCredit) {
          errors.add(ValidationError.creditLimitExceeded(
            creditUsed: creditInfo.creditUsed + creditInfo.creditToInvoice,
            creditLimit: creditInfo.creditLimit,
            orderAmount: orderAmount,
          ));
        } else if (totalCredit > creditInfo.creditLimit * 0.9) {
          // Advertencia si está cerca del límite (90%)
          warnings.add(ValidationWarning(
            code: 'credit_near_limit',
            message: 'El cliente está cerca de su límite de crédito (${creditInfo.creditUsagePercentage.toFixed(0)}% usado).',
          ));
        }
      }

      if (errors.isNotEmpty) {
        return ValidationResult.failed(errors);
      }

      if (warnings.isNotEmpty) {
        return ValidationResult.successWithWarnings(warnings);
      }

      return ValidationResult.success();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error validating credit sale', e, st);
      // En caso de error, permitir por defecto pero con advertencia
      return ValidationResult.successWithWarnings([
        ValidationWarning(
          code: 'credit_check_failed',
          message: 'No se pudo verificar el crédito del cliente. Proceda con precaución.',
        ),
      ]);
    }
  }

  /// Calcula el monto pendiente después de aplicar los pagos
  ///
  /// [orderTotal]: Monto total de la orden
  /// [lines]: Líneas de pago aplicadas
  ///
  /// Retorna el monto pendiente (positivo) o sobrepago (negativo)
  double calculateRemainingAmount(double orderTotal, List<PaymentLine> lines) {
    final totalPayments = lines.fold(0.0, (sum, line) => sum + line.amount);
    return orderTotal - totalPayments;
  }

  /// Indica si hay sobrepago
  bool hasOverpayment(double orderTotal, List<PaymentLine> lines) {
    return calculateRemainingAmount(orderTotal, lines) < -0.01;
  }

  /// Indica si el pago está completo
  bool isPaymentComplete(double orderTotal, List<PaymentLine> lines) {
    final remaining = calculateRemainingAmount(orderTotal, lines);
    return remaining <= 0.01; // Tolerancia de 1 centavo
  }

}

// ============================================================
// MODELOS ADICIONALES
// ============================================================

/// Información de crédito del cliente
class PartnerCreditInfo {
  final double creditLimit;
  final double creditUsed;
  final double creditToInvoice;
  final double totalOverdue;
  final int unpaidInvoicesCount;
  final double creditAvailable;
  final bool allowOverCredit;

  PartnerCreditInfo({
    required this.creditLimit,
    required this.creditUsed,
    required this.creditToInvoice,
    required this.totalOverdue,
    required this.unpaidInvoicesCount,
    required this.creditAvailable,
    required this.allowOverCredit,
  });

  /// Indica si el cliente tiene crédito habilitado
  bool get hasCreditLimit => creditLimit > 0;

  /// Indica si el crédito está excedido
  bool get isCreditExceeded => creditAvailable < 0;

  /// Indica si tiene deuda vencida
  bool get hasOverdueDebt => totalOverdue > 0;

  /// Porcentaje de uso del crédito
  double get creditUsagePercentage {
    if (creditLimit <= 0) return 0;
    return ((creditUsed + creditToInvoice) / creditLimit * 100).clamp(0, 999);
  }
}

/// Tipo de retención disponible
class WithholdingType {
  final int id;
  final String name;
  final double percentage;
  final String code;

  WithholdingType({
    required this.id,
    required this.name,
    required this.percentage,
    required this.code,
  });

  /// Descripción formateada
  String get displayName => '$name ($percentage%)';
}

/// Línea de retención para registrar
class WithholdingLine {
  final int taxId;
  final double base;
  final double amount;

  WithholdingLine({
    required this.taxId,
    required this.base,
    required this.amount,
  });
}

/// Resultado del registro de retención
class WithholdingResult {
  final bool success;
  final int? withholdId;
  final String? withholdName;
  final double totalWithheld;
  final String? errorMessage;

  WithholdingResult({
    required this.success,
    this.withholdId,
    this.withholdName,
    this.totalWithheld = 0,
    this.errorMessage,
  });
}

/// Tipo de autorización de crédito
enum CreditAuthorizationType {
  overdueDebt,
  creditLimitExceeded,
  temporaryCredit,
}

/// Resultado de solicitud de aprobación de crédito
class CreditApprovalResult {
  final bool success;
  final int? approvalId;
  final String? approvalName;
  final String? errorMessage;

  CreditApprovalResult({
    required this.success,
    this.approvalId,
    this.approvalName,
    this.errorMessage,
  });
}

// ============================================================
// MODELO DE COBRO DE SESIÓN
// ============================================================

/// Estado del pago
enum PaymentState {
  draft,
  posted,
  canceled,
  rejected;

  String get label {
    switch (this) {
      case PaymentState.draft:
        return 'Borrador';
      case PaymentState.posted:
        return 'Publicado';
      case PaymentState.canceled:
        return 'Cancelado';
      case PaymentState.rejected:
        return 'Rechazado';
    }
  }

  static PaymentState fromString(String? value) {
    switch (value) {
      case 'posted':
        return PaymentState.posted;
      case 'canceled':
        return PaymentState.canceled;
      case 'rejected':
        return PaymentState.rejected;
      default:
        return PaymentState.draft;
    }
  }
}

/// Tipo de origen del pago
enum PaymentOriginType {
  invoiceDay,
  debt,
  advance;

  String get label {
    switch (this) {
      case PaymentOriginType.invoiceDay:
        return 'Factura del día';
      case PaymentOriginType.debt:
        return 'Deuda';
      case PaymentOriginType.advance:
        return 'Anticipo';
    }
  }

  static PaymentOriginType? fromString(String? value) {
    switch (value) {
      case 'invoice_day':
        return PaymentOriginType.invoiceDay;
      case 'debt':
        return PaymentOriginType.debt;
      case 'advance':
        return PaymentOriginType.advance;
      default:
        return null;
    }
  }
}

/// Categoría del método de pago
enum PaymentMethodCategory {
  cash,
  cardCredit,
  cardDebit,
  cheque,
  transfer,
  other;

  String get label {
    switch (this) {
      case PaymentMethodCategory.cash:
        return 'Efectivo';
      case PaymentMethodCategory.cardCredit:
        return 'Tarjeta Crédito';
      case PaymentMethodCategory.cardDebit:
        return 'Tarjeta Débito';
      case PaymentMethodCategory.cheque:
        return 'Cheque';
      case PaymentMethodCategory.transfer:
        return 'Transferencia';
      case PaymentMethodCategory.other:
        return 'Otro';
    }
  }

  static PaymentMethodCategory fromString(String? value) {
    switch (value) {
      case 'cash':
        return PaymentMethodCategory.cash;
      case 'card_credit':
        return PaymentMethodCategory.cardCredit;
      case 'card_debit':
        return PaymentMethodCategory.cardDebit;
      case 'cheque':
        return PaymentMethodCategory.cheque;
      case 'transfer':
        return PaymentMethodCategory.transfer;
      default:
        return PaymentMethodCategory.other;
    }
  }
}

/// Cobro de sesión para visualización en collection
class SessionPayment {
  final int id;
  final String? name;
  final int? partnerId;
  final String? partnerName;
  final int? journalId;
  final String? journalName;
  final int? paymentMethodLineId;
  final String? paymentMethodLineName;
  final double amount;
  final String paymentType;
  final PaymentState state;
  final DateTime? date;
  final String? ref;
  final PaymentOriginType? originType;
  final PaymentMethodCategory methodCategory;
  final List<int>? invoiceIds;
  final int? moveId;
  final int? collectionSessionId;

  SessionPayment({
    required this.id,
    this.name,
    this.partnerId,
    this.partnerName,
    this.journalId,
    this.journalName,
    this.paymentMethodLineId,
    this.paymentMethodLineName,
    required this.amount,
    required this.paymentType,
    required this.state,
    this.date,
    this.ref,
    this.originType,
    required this.methodCategory,
    this.invoiceIds,
    this.moveId,
    this.collectionSessionId,
  });

  factory SessionPayment.fromOdoo(Map<String, dynamic> data) {
    return SessionPayment(
      id: data['id'] as int,
      name: data['name'] as String?,
      partnerId: odoo.extractMany2oneId(data['partner_id']),
      partnerName: odoo.extractMany2oneName(data['partner_id']),
      journalId: odoo.extractMany2oneId(data['journal_id']),
      journalName: odoo.extractMany2oneName(data['journal_id']),
      paymentMethodLineId: odoo.extractMany2oneId(data['payment_method_line_id']),
      paymentMethodLineName: odoo.extractMany2oneName(data['payment_method_line_id']),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentType: data['payment_type'] as String? ?? 'inbound',
      state: PaymentState.fromString(data['state'] as String?),
      date: odoo.parseOdooDateTime(data['date']),
      ref: data['ref'] as String?,
      originType: PaymentOriginType.fromString(
        data['payment_origin_type'] as String?,
      ),
      methodCategory: PaymentMethodCategory.fromString(
        data['payment_method_category'] as String?,
      ),
      invoiceIds: (data['reconciled_invoice_ids'] as List<dynamic>?)
          ?.cast<int>(),
      moveId: odoo.extractMany2oneId(data['move_id']),
      collectionSessionId: odoo.extractMany2oneId(data['collection_session_id']),
    );
  }

  /// Indica si es un cobro entrante (del cliente)
  bool get isInbound => paymentType == 'inbound';

  /// Indica si es un pago saliente (al proveedor)
  bool get isOutbound => paymentType == 'outbound';

  /// Indica si está publicado
  bool get isPosted => state == PaymentState.posted;

  /// Indica si está cancelado
  bool get isCanceled => state == PaymentState.canceled;
}
