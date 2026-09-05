import 'package:odoo_sdk/odoo_sdk.dart'
    show
        OfflineReplayPolicy,
        OdooConnectionException,
        OdooException,
        OdooNotFoundException,
        OdooOfflineException,
        OdooTimeoutException;
import 'package:uuid/uuid.dart';

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

  AppDatabase get _db => advanceManager.database as AppDatabase;

  /// Generate a temporary negative ID for offline-created records
  int _generateTempId() =>
      -(DateTime.now().millisecondsSinceEpoch % 1000000000);

  bool _isConnectivityFailure(Object error) =>
      error is OdooConnectionException ||
      error is OdooTimeoutException ||
      error is OdooOfflineException;

  String _operationError(Object error) =>
      error is OdooException ? error.message : friendlyErrorMessage(error);

  /// Get the current user's company_id, defaulting to 1 if unavailable
  Future<int> _getUserCompanyId() async {
    try {
      final user = await userManager.getCurrentUser();
      final companyId = user?.companyId;
      if (companyId == null) {
        logger.w(
          '[AdvanceService]',
          'company_id not available from user, using fallback=1',
        );
        return 1;
      }
      return companyId;
    } catch (e) {
      logger.w(
        '[AdvanceService]',
        'Error getting company_id, using fallback=1: $e',
      );
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
        [
          'state',
          'in',
          ['posted', 'in_use'],
        ],
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
      logger.e(
        '[AdvanceService]',
        'Error fetching advances for partner $partnerId',
        e,
        st,
      );
      // Return empty if both cache and Odoo fail
      return cached;
    }

    // 3. Re-read from local DB
    return await advanceManager.searchLocal(
      domain: [
        ['partner_id', '=', partnerId],
        ['advance_type', '=', 'inbound'],
        [
          'state',
          'in',
          ['posted', 'in_use'],
        ],
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
          [
            'state',
            'in',
            ['posted', 'in_use'],
          ],
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
    final cached = await advanceManager.readLocalWithLines(advanceId);
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
    return await advanceManager.readLocalWithLines(advanceId);
  }

  /// Explicit refresh for callers that need to await a complete line snapshot.
  Future<Advance?> refreshAdvance(int advanceId) async {
    await _fetchAndCacheAdvance(advanceId);
    return advanceManager.readLocalWithLines(advanceId);
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
        'domain': [
          ['id', '=', advanceId],
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
          'collection_session_id',
          'sale_order_id',
          'advance_line_ids',
        ],
        'limit': 1,
      },
    );

    if (advances == null || advances is! List || advances.isEmpty) {
      return;
    }

    final raw = Map<String, dynamic>.from(advances[0] as Map);
    final advance = advanceManager.fromOdoo(raw);
    final rawLineIds = raw['advance_line_ids'];
    if (advance.id != advanceId ||
        rawLineIds is! List ||
        rawLineIds.any((id) => id is! int || id <= 0)) {
      return;
    }
    final requestedIds = rawLineIds.cast<int>().toSet();
    if (requestedIds.length != rawLineIds.length) return;
    final lines = <AdvanceLine>[];
    // An empty, valid one2many is an authoritative empty snapshot. Otherwise
    // require every child before replacing either the header or the lines.
    if (requestedIds.isNotEmpty) {
      final childRows = await _odoo.call(
        model: 'account.advance.line',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['advance_id', '=', advanceId],
            ['id', 'in', requestedIds.toList()],
          ],
          'fields': advanceLineManager.odooFields,
          'order': 'id',
          'limit': requestedIds.length,
        },
      );
      if (childRows is! List || childRows.length != requestedIds.length) return;
      final seenIds = <int>{};
      for (final row in childRows) {
        if (row is! Map ||
            row['id'] is! int ||
            !requestedIds.contains(row['id']) ||
            !seenIds.add(row['id'] as int) ||
            row['amount'] is! num ||
            !(row['amount'] as num).isFinite) {
          return;
        }
        final line = advanceLineManager.fromOdoo(
          Map<String, dynamic>.from(row),
        );
        if (line.journalId <= 0) return;
        lines.add(line.copyWith(advanceId: advanceId));
      }
    }
    await advanceManager.upsertLocalWithLines(advance.copyWith(lines: lines));
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
      domain: [
        ['collection_session_id', '=', sessionId],
      ],
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
      domain: [
        ['collection_session_id', '=', sessionId],
      ],
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

      // 1. Persist the local financial snapshot and its replay intent in the
      // same Drift transaction. `external_id` is a writable server field on
      // account.advance and is the durable idempotency marker for recovery.
      final tempId = _generateTempId();
      final advanceUuid = advance.advanceUuid?.trim().isNotEmpty == true
          ? advance.advanceUuid!.trim()
          : const Uuid().v4();
      final localAdvance = advance.copyWith(
        id: tempId,
        advanceUuid: advanceUuid,
        amount: totalLines,
        amountAvailable: totalLines,
      );
      final odooValues = advanceManager.toOdoo(localAdvance)
        ..['external_id'] = advanceUuid
        ..['advance_line_ids'] = [
          for (final line in localAdvance.lines)
            [0, 0, advanceLineManager.toOdoo(line)],
        ];
      int? createOperationId;

      Future<void> persistAdvanceAndIntent() async {
        await advanceManager.upsertLocalWithLines(localAdvance);
        createOperationId = await _offlineQueue?.queueOperation(
          model: 'account.advance',
          method: 'create',
          recordId: tempId,
          values: {
            ...odooValues,
            'local_id': tempId,
            '_operation_key': 'account.advance:create:$advanceUuid',
          },
          priority: OfflinePriority.high,
          replayPolicy: OfflineReplayPolicy.retrySafe,
        );
      }

      if (_offlineQueue == null) {
        await persistAdvanceAndIntent();
      } else {
        await _db.transaction(persistAdvanceAndIntent);
      }
      logger.d('[AdvanceService]', 'Saved advance locally with tempId=$tempId');

      // 2. Try to create in Odoo
      if (_odoo.client == null && _offlineQueue != null) {
        return AdvanceResult(
          success: true,
          advanceId: tempId,
          errorMessage:
              'Guardado localmente. Se sincronizará cuando haya conexión.',
        );
      }
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

        // 3. Odoo OK — hand off the local ID and retire exactly this create
        // intent atomically. A crash before here is recovered by external_id.
        Future<void> completeHandoff() async {
          await advanceManager.deleteLocal(tempId);
          await advanceManager.upsertLocal(localAdvance.copyWith(id: id));
          await _db.customStatement(
            'UPDATE "advance_lines" SET "advance_id" = ? WHERE "advance_id" = ?',
            [id, tempId],
          );
          if (createOperationId != null) {
            await _offlineQueue?.removeOperation(createOperationId!);
          }
          await _offlineQueue?.updateRecordIdInPendingOperations(
            'account.advance',
            tempId,
            id,
          );
        }

        await _db.transaction(completeHandoff);

        logger.i('[AdvanceService]', 'Created advance $id (synced)');
        return AdvanceResult(success: true, advanceId: id);
      } catch (e) {
        if (!_isConnectivityFailure(e)) {
          Future<void> discardRejectedDraft() async {
            await _db.customStatement(
              'DELETE FROM "advance_lines" WHERE "advance_id" = ?',
              [tempId],
            );
            await advanceManager.deleteLocal(tempId);
            if (createOperationId != null) {
              await _offlineQueue?.removeOperation(createOperationId!);
            }
          }

          await _db.transaction(discardRejectedDraft);
          logger.e(
            '[AdvanceService]',
            'Odoo rejected advance creation; removed local draft',
            e,
          );
          return AdvanceResult(
            success: false,
            errorMessage: _operationError(e),
          );
        }
        // Network unavailable — the atomic outbox intent already exists.
        logger.w(
          '[AdvanceService]',
          'Odoo unreachable, queuing advance create (tempId=$tempId): $e',
        );
        return AdvanceResult(
          success: true,
          advanceId: tempId,
          errorMessage:
              'Guardado localmente. Se sincronizará cuando haya conexión.',
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
        final local = await advanceManager.readLocal(advanceId);
        Future<void> persistPostAndIntent() async {
          if (local != null) {
            await advanceManager.upsertLocal(
              local.copyWith(state: AdvanceState.posted),
            );
          }
          await _offlineQueue?.queueOperation(
            model: 'account.advance',
            method: 'action_post',
            recordId: advanceId,
            values: {
              '_operation_key':
                  'account.advance:action_post:${local?.advanceUuid ?? advanceId}',
            },
            priority: OfflinePriority.high,
            replayPolicy: OfflineReplayPolicy.retrySafe,
          );
        }

        if (_offlineQueue == null) {
          await persistPostAndIntent();
        } else {
          await _db.transaction(persistPostAndIntent);
        }
        return AdvanceResult(
          success: true,
          advanceId: advanceId,
          amount: advance.lines.fold<double>(0.0, (sum, l) => sum + l.amount),
          errorMessage:
              'Guardado localmente. Se sincronizará cuando haya conexión.',
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
      // 1. Commit the optimistic state and its action intent together before
      // touching the network. Recovery checks the authoritative server state
      // before replaying action_post.
      final localAdvance = await advanceManager.readLocal(advanceId);
      int? operationId;
      Future<void> persistPostAndIntent() async {
        if (localAdvance != null) {
          await advanceManager.upsertLocal(
            localAdvance.copyWith(state: AdvanceState.posted),
          );
        }
        operationId = await _offlineQueue?.queueOperation(
          model: 'account.advance',
          method: 'action_post',
          recordId: advanceId,
          values: {
            '_operation_key':
                'account.advance:action_post:${localAdvance?.advanceUuid ?? advanceId}',
          },
          priority: OfflinePriority.high,
          replayPolicy: OfflineReplayPolicy.retrySafe,
        );
      }

      if (_offlineQueue == null) {
        await persistPostAndIntent();
      } else {
        await _db.transaction(persistPostAndIntent);
      }

      if (_odoo.client == null && _offlineQueue != null) {
        return AdvanceResult(
          success: true,
          advanceId: advanceId,
          advanceName: localAdvance?.name,
          amount: localAdvance?.amount,
          errorMessage:
              'Publicado localmente. Se sincronizará cuando haya conexión.',
        );
      }

      // 2. Try Odoo
      try {
        await _odoo.call(
          model: 'account.advance',
          method: 'action_post',
          ids: [advanceId],
        );

        if (operationId != null) {
          await _db.transaction(
            () => _offlineQueue!.removeOperation(operationId!),
          );
        }

        // Refresh from Odoo to get server-generated fields (name, etc.)
        final advance = await getAdvance(advanceId);

        logger.i(
          '[AdvanceService]',
          'Posted advance $advanceId: ${advance?.name}',
        );

        return AdvanceResult(
          success: true,
          advanceId: advanceId,
          advanceName: advance?.name,
          amount: advance?.amount,
        );
      } catch (e) {
        if (!_isConnectivityFailure(e)) {
          Future<void> restoreRejectedPost() async {
            if (localAdvance != null) {
              await advanceManager.upsertLocal(localAdvance);
            }
            if (operationId != null) {
              await _offlineQueue?.removeOperation(operationId!);
            }
          }

          if (_offlineQueue == null) {
            await restoreRejectedPost();
          } else {
            await _db.transaction(restoreRejectedPost);
          }
          return AdvanceResult(
            success: false,
            advanceId: advanceId,
            advanceName: localAdvance?.name,
            amount: localAdvance?.amount,
            errorMessage: _operationError(e),
          );
        }
        // Network unavailable — the atomic action intent remains queued.
        logger.w(
          '[AdvanceService]',
          'Odoo unreachable, queuing action_post for advance $advanceId: $e',
        );
        return AdvanceResult(
          success: true,
          advanceId: advanceId,
          advanceName: localAdvance?.name,
          amount: localAdvance?.amount,
          errorMessage:
              'Publicado localmente. Se sincronizará cuando haya conexión.',
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

  /// Returns the unused advance through the real accounting wizard.
  ///
  /// This operation is deliberately online-only. The former implementation
  /// called a non-existent `account.advance.action_return`, zeroed the local
  /// balance optimistically and then queued that invalid call. A return creates
  /// and posts an outbound payment, so it must be authoritative in Odoo.
  Future<AdvanceReturnResult> returnAdvance(int advanceId) async {
    if (_odoo.client == null) {
      throw const OdooOfflineException(
        'Se necesita conexión para devolver un anticipo',
      );
    }
    final advance = await advanceManager.readLocal(advanceId);
    if (advance == null || advance.amountAvailable <= 0) {
      throw StateError('El anticipo no tiene saldo disponible para devolver');
    }

    try {
      final journalId = await _resolveAdvanceReturnJournal(advance);
      final paymentType = advance.advanceType == AdvanceType.inbound
          ? 'outbound'
          : 'inbound';
      final methods = await _odoo.call(
        model: 'account.payment.method.line',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['journal_id', '=', journalId],
            ['payment_type', '=', paymentType],
            ['payment_account_id', '!=', false],
          ],
          'fields': ['id', 'code', 'name'],
          'order': 'sequence, id',
        },
      );
      if (methods is! List || methods.isEmpty) {
        throw StateError(
          'El diario del anticipo no tiene un método de devolución con cuenta pendiente',
        );
      }
      final methodMaps = methods.whereType<Map>().toList();
      final preferred = methodMaps.where(
        (method) => method['code'] == 'manual',
      );
      final method = preferred.isNotEmpty ? preferred.first : methodMaps.first;
      final methodId = method['id'];
      if (methodId is! int) {
        throw StateError('Odoo devolvió un método de pago inválido');
      }

      final createResult = await _odoo.call(
        model: 'account.advance.return.wizard',
        method: 'create',
        kwargs: {
          'vals_list': [
            {
              'advance_id': advanceId,
              'amount': advance.amountAvailable,
              'date': DateTime.now().toIso8601String().split('T').first,
              'journal_id': journalId,
              'payment_method_line_id': methodId,
              'memo': 'Devolución ${advance.name ?? advanceId}',
            },
          ],
        },
      );
      final wizardId = createResult is List && createResult.isNotEmpty
          ? createResult.first
          : createResult;
      if (wizardId is! int) {
        throw StateError('Odoo no devolvió el asistente de devolución');
      }

      final rawAction = await _odoo.call(
        model: 'account.advance.return.wizard',
        method: 'action_confirm',
        ids: [wizardId],
      );
      if (rawAction is! Map || rawAction['res_model'] != 'account.payment') {
        throw StateError('Odoo no devolvió el pago de devolución');
      }
      final action = Map<String, dynamic>.from(rawAction);
      final paymentId = action['res_id'];
      if (paymentId is! int) {
        throw StateError('Odoo no devolvió el pago de devolución');
      }
      final context = action['context'] is Map
          ? Map<String, dynamic>.from(action['context'] as Map)
          : const <String, dynamic>{};
      final pendingApproval = context['l10n_ec_pago_pendiente'] == true;
      await _fetchAndCacheAdvance(advanceId);
      return AdvanceReturnResult(
        paymentId: paymentId,
        completed: !pendingApproval,
        requiresApproval: pendingApproval,
      );
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error returning advance $advanceId', e, st);
      rethrow;
    }
  }

  Future<int> _resolveAdvanceReturnJournal(Advance advance) async {
    if (advance.lines.isNotEmpty) return advance.lines.first.journalId;
    final lines = await _odoo.call(
      model: 'account.advance.line',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['advance_id', '=', advance.id],
        ],
        'fields': ['journal_id'],
        'order': 'id',
        'limit': 1,
      },
    );
    if (lines is List && lines.isNotEmpty && lines.first is Map) {
      final journal = (lines.first as Map)['journal_id'];
      if (journal is List && journal.isNotEmpty && journal.first is int) {
        return journal.first as int;
      }
      if (journal is int) return journal;
    }
    throw StateError('No se pudo determinar el diario original del anticipo');
  }

  /// Cancela un anticipo (offline-first)
  ///
  /// 1. Actualiza estado local a 'canceled' optimistamente
  /// 2. Intenta llamar a Odoo action_cancel
  /// 3. Si falla, encola para sync posterior
  Future<bool> cancelAdvance(int advanceId) async {
    try {
      // 1. Persist state + retry-safe action atomically.
      final localAdvance = await advanceManager.readLocal(advanceId);
      int? operationId;
      Future<void> persistCancelAndIntent() async {
        if (localAdvance != null) {
          await advanceManager.upsertLocal(
            localAdvance.copyWith(state: AdvanceState.canceled),
          );
        }
        operationId = await _offlineQueue?.queueOperation(
          model: 'account.advance',
          method: 'action_cancel',
          recordId: advanceId,
          values: {
            '_operation_key':
                'account.advance:action_cancel:${localAdvance?.advanceUuid ?? advanceId}',
          },
          priority: OfflinePriority.normal,
          replayPolicy: OfflineReplayPolicy.retrySafe,
        );
      }

      if (_offlineQueue == null) {
        await persistCancelAndIntent();
      } else {
        await _db.transaction(persistCancelAndIntent);
      }

      if (_odoo.client == null && _offlineQueue != null) {
        return true;
      }

      // 2. Try Odoo
      try {
        await _odoo.call(
          model: 'account.advance',
          method: 'action_cancel',
          ids: [advanceId],
        );

        if (operationId != null) {
          await _db.transaction(
            () => _offlineQueue!.removeOperation(operationId!),
          );
        }

        // Refresh from Odoo
        await _fetchAndCacheAdvance(advanceId);

        logger.i('[AdvanceService]', 'Cancelled advance $advanceId');
        return true;
      } catch (e) {
        if (!_isConnectivityFailure(e)) {
          Future<void> restoreRejectedCancel() async {
            if (localAdvance != null) {
              await advanceManager.upsertLocal(localAdvance);
            }
            if (operationId != null) {
              await _offlineQueue?.removeOperation(operationId!);
            }
          }

          if (_offlineQueue == null) {
            await restoreRejectedCancel();
          } else {
            await _db.transaction(restoreRejectedCancel);
          }
          rethrow;
        }
        // Network unavailable — the atomic action intent remains queued.
        logger.w(
          '[AdvanceService]',
          'Odoo unreachable, queuing action_cancel for advance $advanceId: $e',
        );
        return true;
      }
    } catch (e, st) {
      logger.e(
        '[AdvanceService]',
        'Error cancelling advance $advanceId',
        e,
        st,
      );
      rethrow;
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
            [
              'type',
              'in',
              ['cash', 'bank', 'credit'],
            ],
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

        result.add(
          AvailableJournal(
            id: journalId,
            name: journal['name'] as String,
            type: journal['type'] as String,
            isCardJournal: journal['is_card_journal'] as bool? ?? false,
            paymentMethods: methods,
          ),
        );
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
      logger.e(
        '[AdvanceService]',
        'Error getting payment methods for journal $journalId',
        e,
        st,
      );
      return [];
    }
  }

  // ============================================================
  // BANCOS Y TARJETAS (igual que PaymentService)
  // ============================================================

  /// Obtiene el catálogo bancario de la localización ecuatoriana.
  Future<List<AvailableBank>> getBanks() async {
    try {
      final banks = await _odoo.call(
        model: 'l10n.ec.bank',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['active', '=', true],
          ],
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
      logger.w('[AdvanceService]', 'Catálogo l10n.ec.bank no disponible');
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
          'domain': [
            ['id', '=', journalId],
          ],
          'fields': ['card_brand_ids'],
          'limit': 1,
        },
      );

      if (journal == null || journal is! List || journal.isEmpty) {
        return [];
      }

      final brandIds =
          (journal[0]['card_brand_ids'] as List?)?.cast<int>() ?? [];

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
            'domain': [
              ['id', 'in', brandIds],
            ],
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
  Future<List<CardDeadline>> getCardDeadlines({
    bool? credit,
    bool? debit,
  }) async {
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
      return banks
          .map(
            (b) => PartnerBank(
              id: b.odooId,
              accountNumber: b.accNumber,
              bankId: b.bankId,
              bankName: b.bankName,
            ),
          )
          .toList();
    } catch (e, st) {
      logger.e('[AdvanceService]', 'Error getting partner banks', e, st);
      return [];
    }
  }

  /// Reactive stream of partner banks — mismo dato que [getPartnerBanks]
  /// pero reactivo, usando [BankRepository.watchPartnerBanks]. No unifica el
  /// [PartnerBank] local (esta clase) con el `PartnerBank` de
  /// `theos_pos_core` — sigue siendo el mismo modelo local de siempre.
  Stream<List<PartnerBank>> watchPartnerBanks(int partnerId) {
    return _bankRepo
        .watchPartnerBanks(partnerId)
        .map(
          (banks) => banks
              .map(
                (b) => PartnerBank(
                  id: b.odooId,
                  accountNumber: b.accNumber,
                  bankId: b.bankId,
                  bankName: b.bankName,
                ),
              )
              .toList(),
        );
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
          'domain': [
            ['id', '=', companyId],
          ],
          'fields': ['l10n_ec_advance_default_due_days'],
          'limit': 1,
        },
      );

      if (company is List && company.isNotEmpty) {
        return (company[0]
                    as Map<String, dynamic>)['l10n_ec_advance_default_due_days']
                as int? ??
            30;
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
          'domain': [
            ['id', '=', companyId],
          ],
          'fields': ['l10n_ec_advance_min_reference_length'],
          'limit': 1,
        },
      );

      if (company is List && company.isNotEmpty) {
        return (company[0]
                    as Map<
                      String,
                      dynamic
                    >)['l10n_ec_advance_min_reference_length']
                as int? ??
            30;
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

/// Result of the accounting return wizard. A payment awaiting supervisor
/// approval exists, but the advance balance has not been returned yet.
class AdvanceReturnResult {
  final int paymentId;
  final bool completed;
  final bool requiresApproval;

  const AdvanceReturnResult({
    required this.paymentId,
    required this.completed,
    required this.requiresApproval,
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
    return PartnerBank(
      id: data['id'] as int,
      // Odoo 19.5/19.2: 'acc_number' fue renombrado a 'account_number' en
      // res.partner.bank (verificado en vivo contra erp1, julio 2026).
      accountNumber: data['account_number'] as String,
      bankName: data['bank_name'] is String
          ? data['bank_name'] as String
          : null,
    );
  }

  String get displayName =>
      bankName != null ? '$bankName - $accountNumber' : accountNumber;
}
