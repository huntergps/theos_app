import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../../core/services/odoo_service.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import 'payment_service_models.dart';

/// Servicio para obtener diarios y métodos de pago disponibles.
///
/// Extraído tal cual de `payment_service.dart` como parte de la
/// descomposición sin cambio de comportamiento (Fase E2, sección 3 del plan
/// de descomposición). `PaymentService` delega aquí (facade).
class JournalPaymentMethodService {
  final OdooService _odoo;
  final AppDatabase _db;

  JournalPaymentMethodService(this._odoo, this._db);

  /// Get the current user's company_id, defaulting to 1 if unavailable
  Future<int> _getUserCompanyId() async {
    try {
      final user = await userManager.getCurrentUser();
      final companyId = user?.companyId;
      if (companyId == null) {
        logger.w(
          '[PaymentService]',
          'company_id not available from user, using fallback=1',
        );
        return 1;
      }
      return companyId;
    } catch (e) {
      logger.w(
        '[PaymentService]',
        'Error getting company_id, using fallback=1: $e',
      );
      return 1;
    }
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
        logger.d(
          '[PaymentService]',
          'Loaded ${localResult.length} journals from local DB',
        );
        return localResult;
      }

      logger.d(
        '[PaymentService]',
        'No local journals found, trying Odoo API...',
      );

      // 2. Fallback: Intentar cargar desde Odoo (online)
      return await _getAvailableJournalsFromOdoo(sessionId);
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting journals', e, st);
      return [];
    }
  }

  /// Obtiene diarios desde la base de datos local (offline)
  Future<List<AvailableJournal>> _getAvailableJournalsFromLocal(
    int? sessionId,
  ) async {
    try {
      List<int> allowedJournalIds = [];
      logger.d(
        '[PaymentService]',
        '_getAvailableJournalsFromLocal: sessionId=$sessionId',
      );
      logger.d('[PaymentService]', 'Using local database for journal lookup');

      // 1. Obtener allowed_journal_ids desde collection_config vía session
      if (sessionId != null) {
        // Buscar la sesión via manager
        final session = await collectionSessionManager.readLocal(sessionId);

        logger.d(
          '[PaymentService]',
          'session found: ${session != null}, configId: ${session?.configId}',
        );

        if (session != null && session.configId != null) {
          // Obtener el config via manager
          final config = await collectionConfigManager.readLocal(
            session.configId!,
          );

          logger.d(
            '[PaymentService]',
            'config found: ${config != null}, allowedJournalIds: ${config?.allowedJournalIds}, cashJournalId: ${config?.cashJournalId}',
          );
          if (config != null) {
            // allowedJournalIds is List<int> from the Freezed model
            if (config.allowedJournalIds.isNotEmpty) {
              allowedJournalIds = List<int>.from(config.allowedJournalIds);
            }
            // Agregar diario de efectivo si no está en la lista
            if (config.cashJournalId != null &&
                !allowedJournalIds.contains(config.cashJournalId)) {
              allowedJournalIds.add(config.cashJournalId!);
            }
          }
        }
      }

      logger.d(
        '[PaymentService]',
        'allowedJournalIds after config: $allowedJournalIds',
      );

      // 2. Si no hay diarios configurados, usar fallback con disponible_ventas
      List<AccountJournalData> journals;
      if (allowedJournalIds.isNotEmpty) {
        logger.d(
          '[PaymentService]',
          'Querying journals with IDs: $allowedJournalIds',
        );
        try {
          // Use raw query to avoid Drift mapping issues with empty/null fields
          final rawResults = await _db
              .customSelect(
                'SELECT odoo_id, name, code, type, is_card_journal, card_brand_ids, '
                'default_card_brand_id, card_deadline_credit_ids, card_deadline_debit_ids, '
                'default_card_deadline_credit_id, default_card_deadline_debit_id '
                'FROM account_journal WHERE odoo_id IN (${allowedJournalIds.join(",")})',
              )
              .get();
          logger.d(
            '[PaymentService]',
            'Raw query returned ${rawResults.length} rows',
          );

          // Build AvailableJournal list directly from raw results
          final result = <AvailableJournal>[];
          for (final row in rawResults) {
            final journalId = row.read<int>('odoo_id');
            final journalName = row.read<String>('name');
            final journalType = row.read<String>('type');
            final isCard = row.read<int>('is_card_journal') == 1;
            final cardBrandIdsStr =
                row.readNullable<String>('card_brand_ids') ?? '';
            final deadlineCreditIdsStr =
                row.readNullable<String>('card_deadline_credit_ids') ?? '';
            final deadlineDebitIdsStr =
                row.readNullable<String>('card_deadline_debit_ids') ?? '';

            // Get payment methods for this journal
            final methods = await _getPaymentMethodsFromLocal(journalId);
            logger.d(
              '[PaymentService]',
              'Journal $journalId ($journalName): ${methods.length} methods',
            );

            if (methods.isNotEmpty) {
              result.add(
                AvailableJournal(
                  id: journalId,
                  name: journalName,
                  type: journalType,
                  isCardJournal: isCard,
                  paymentMethods: methods,
                  cardBrandIds: decodeCsvIntList(cardBrandIdsStr),
                  defaultCardBrandId: row.readNullable<int>(
                    'default_card_brand_id',
                  ),
                  deadlineCreditIds: decodeCsvIntList(deadlineCreditIdsStr),
                  deadlineDebitIds: decodeCsvIntList(deadlineDebitIdsStr),
                  defaultDeadlineCreditId: row.readNullable<int>(
                    'default_card_deadline_credit_id',
                  ),
                  defaultDeadlineDebitId: row.readNullable<int>(
                    'default_card_deadline_debit_id',
                  ),
                ),
              );
            }
          }

          logger.d(
            '[PaymentService]',
            'Returning ${result.length} journals with payment methods',
          );
          return result;
        } catch (e, st) {
          logger.d('[PaymentService]', 'EXCEPTION in journal query: $e');
          logger.d('[PaymentService]', 'Stack: $st');
          rethrow;
        }
      } else {
        // Fallback: diarios con disponible_ventas=true
        logger.d(
          '[PaymentService]',
          'No session config, using disponible_ventas fallback',
        );
        journals =
            await (_db.select(_db.accountJournal)
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
        logger.d(
          '[PaymentService]',
          'Journal ${journal.odooId} (${journal.name}): ${methods.length} payment methods',
        );

        // Solo agregar si tiene métodos de pago inbound
        if (methods.isNotEmpty) {
          result.add(
            AvailableJournal(
              id: journal.odooId,
              name: journal.name,
              type: journal.type,
              isCardJournal: journal.isCardJournal,
              paymentMethods: methods,
              cardBrandIds: decodeCsvIntList(journal.cardBrandIds),
              defaultCardBrandId: journal.defaultCardBrandId,
              deadlineCreditIds: decodeCsvIntList(
                journal.cardDeadlineCreditIds,
              ),
              deadlineDebitIds: decodeCsvIntList(journal.cardDeadlineDebitIds),
              defaultDeadlineCreditId: journal.defaultCardDeadlineCreditId,
              defaultDeadlineDebitId: journal.defaultCardDeadlineDebitId,
            ),
          );
        }
      }

      logger.d(
        '[PaymentService]',
        'Returning ${result.length} journals with payment methods',
      );
      return result;
    } catch (e) {
      logger.d(
        '[PaymentService]',
        'EXCEPTION in _getAvailableJournalsFromLocal: $e',
      );
      logger.w('[PaymentService]', 'Error loading journals from local DB: $e');
      return [];
    }
  }

  /// Obtiene métodos de pago de un diario desde la base local
  ///
  /// Para diarios tipo 'cash' y 'bank': métodos inbound (recibir pagos)
  /// Para diarios tipo 'credit' (procesadores de tarjeta como DATAFAST):
  ///   - Primero intenta inbound (pagos entrantes configurados)
  ///   - Si no hay, usa outbound para instalaciones que configuran allí el método
  Future<List<PaymentMethod>> _getPaymentMethodsFromLocal(int journalId) async {
    try {
      logger.d(
        '[PaymentService]',
        '_getPaymentMethodsFromLocal START for journalId=$journalId',
      );

      // Get journal type using raw query to avoid Drift mapping issues
      final journalResult = await _db
          .customSelect(
            'SELECT type FROM account_journal WHERE odoo_id = $journalId',
          )
          .getSingleOrNull();

      if (journalResult == null) {
        logger.d(
          '[PaymentService]',
          '_getPaymentMethodsFromLocal: journal $journalId not found',
        );
        return [];
      }

      final journalType = journalResult.read<String>('type');
      logger.d('[PaymentService]', 'Journal $journalId has type: $journalType');

      // Debug: verificar cuántos métodos de pago hay en total para este journal
      final allMethodsCount = await _db
          .customSelect(
            'SELECT COUNT(*) as cnt FROM account_payment_method_line WHERE journal_id = $journalId',
          )
          .getSingle();
      logger.d(
        '[PaymentService]',
        'Total methods in DB for journal $journalId: ${allMethodsCount.read<int>('cnt')}',
      );

      // Query payment methods using raw SQL to avoid Drift issues
      String paymentType = 'inbound';
      var methodRows = await _db
          .customSelect(
            'SELECT odoo_id, name, payment_method_code FROM account_payment_method_line '
            'WHERE journal_id = $journalId AND payment_type = ?',
            variables: [Variable.withString(paymentType)],
          )
          .get();

      logger.d(
        '[PaymentService]',
        'Found ${methodRows.length} $paymentType methods for journal $journalId',
      );

      // For credit journals, try outbound if no inbound found
      if (methodRows.isEmpty && journalType == 'credit') {
        paymentType = 'outbound';
        methodRows = await _db
            .customSelect(
              'SELECT odoo_id, name, payment_method_code FROM account_payment_method_line '
              'WHERE journal_id = $journalId AND payment_type = ?',
              variables: [Variable.withString(paymentType)],
            )
            .get();
        logger.d(
          '[PaymentService]',
          'Fallback to outbound: ${methodRows.length} methods',
        );
      }

      // Map results to PaymentMethod
      // Use the line's custom name (e.g., "Deposito1") instead of generic translation
      return methodRows.map((row) {
        return PaymentMethod(
          id: row.read<int>('odoo_id'),
          name: row.read<String>(
            'name',
          ), // Custom line name from account.payment.method.line
          code: row.readNullable<String>('payment_method_code') ?? 'manual',
        );
      }).toList();
    } catch (e) {
      logger.d('[PaymentService]', '_getPaymentMethodsFromLocal EXCEPTION: $e');
      logger.w(
        '[PaymentService]',
        'Error loading payment methods from local DB for journal $journalId: $e',
      );
      return [];
    }
  }

  /// Obtiene diarios desde Odoo API (online fallback)
  Future<List<AvailableJournal>> _getAvailableJournalsFromOdoo(
    int? sessionId,
  ) async {
    List<int> allowedJournalIds = [];

    // 1. Intentar obtener diarios desde la configuración de la sesión
    if (sessionId != null) {
      final sessions = await _odoo.call(
        model: 'collection.session',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['id', '=', sessionId],
          ],
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
              'domain': [
                ['id', '=', configId],
              ],
              'fields': ['allowed_journal_ids', 'cash_journal_id'],
              'limit': 1,
            },
          );

          if (configs is List && configs.isNotEmpty) {
            final config = configs[0] as Map<String, dynamic>;
            // Agregar diarios permitidos
            if (config['allowed_journal_ids'] is List) {
              allowedJournalIds.addAll(
                (config['allowed_journal_ids'] as List).cast<int>(),
              );
            }
            // Agregar diario de efectivo
            final cashJournalId = odoo.extractMany2oneId(
              config['cash_journal_id'],
            );
            if (cashJournalId != null &&
                !allowedJournalIds.contains(cashJournalId)) {
              allowedJournalIds.add(cashJournalId);
            }
          }
        }
      }
    }

    // 2. Obtener diarios
    List<dynamic>? journals;
    const journalFields = [
      'id',
      'name',
      'type',
      'is_card_journal',
      'card_brand_ids',
      'default_card_brand_id',
      'card_deadline_credit_ids',
      'card_deadline_debit_ids',
      'default_card_deadline_credit_id',
      'default_card_deadline_debit_id',
    ];

    if (allowedJournalIds.isNotEmpty) {
      journals = await _odoo.call(
        model: 'account.journal',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['id', 'in', allowedJournalIds],
          ],
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
            [
              'type',
              'in',
              ['cash', 'bank', 'credit'],
            ],
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
      final methods = await _getPaymentMethods(
        journalId,
        journalType: journalType,
      );

      // Solo agregar si tiene métodos de pago
      if (methods.isNotEmpty) {
        final cardBrandIds =
            (journal['card_brand_ids'] as List?)?.cast<int>() ?? [];
        final deadlineCreditIds =
            (journal['card_deadline_credit_ids'] as List?)?.cast<int>() ?? [];
        final deadlineDebitIds =
            (journal['card_deadline_debit_ids'] as List?)?.cast<int>() ?? [];

        result.add(
          AvailableJournal(
            id: journalId,
            name: journal['name'] as String,
            type: journal['type'] as String,
            isCardJournal: journal['is_card_journal'] as bool? ?? false,
            paymentMethods: methods,
            cardBrandIds: cardBrandIds,
            defaultCardBrandId: odoo.extractMany2oneId(
              journal['default_card_brand_id'],
            ),
            deadlineCreditIds: deadlineCreditIds,
            deadlineDebitIds: deadlineDebitIds,
            defaultDeadlineCreditId: odoo.extractMany2oneId(
              journal['default_card_deadline_credit_id'],
            ),
            defaultDeadlineDebitId: odoo.extractMany2oneId(
              journal['default_card_deadline_debit_id'],
            ),
          ),
        );
      }
    }

    return result;
  }

  /// Obtiene los métodos de pago de un diario
  /// Obtiene métodos de pago de un diario desde Odoo API
  ///
  /// [journalId]: ID del diario
  /// [journalType]: Tipo de diario ('cash', 'bank', 'credit')
  Future<List<PaymentMethod>> _getPaymentMethods(
    int journalId, {
    String? journalType,
  }) async {
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
      logger.e(
        '[PaymentService]',
        'Error getting payment methods for journal $journalId',
        e,
      );
      return [];
    }
  }
}
