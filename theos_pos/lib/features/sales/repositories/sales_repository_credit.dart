part of 'sales_repository.dart';

/// Credit approval operations: checking pending requests and creating
/// credit approval requests for sale orders.
extension SalesRepositoryCredit on SalesRepository {
  Future<Map<String, dynamic>?> checkPendingApprovalRequests({
    required int partnerId,
    int? orderId,
  }) async {
    if (!_orderManager.isOnline) return null;

    try {
      final domain = [
        ['partner_id', '=', partnerId],
        ['approval_type', '=', 'credit'],
        [
          'request_status',
          'in',
          ['new', 'pending'],
        ],
        if (orderId != null) ['sale_order_id', '=', orderId],
      ];

      // NOTA: 'approval.request' no tiene manager generado — se usa el
      // client de _orderManager (mismo OdooClient compartido) por ser el
      // manager mas relacionado conceptualmente con este flujo (aprobacion
      // de credito de una orden de venta). Ver comentario de excepcion en
      // la clase para el criterio general.
      final pendingRequests = await _orderManager.client.searchRead(
        model: 'approval.request',
        domain: domain,
        fields: [
          'id',
          'name',
          'reference',
          'request_status',
          'sale_order_id',
          'create_date',
        ],
        order: 'create_date desc',
        limit: 5,
      );

      if (pendingRequests.isEmpty) return null;

      return {
        'count': pendingRequests.length,
        'requests': pendingRequests,
        'latestRequest': pendingRequests.first,
      };
    } catch (e) {
      logger.w(
        '[SalesRepository]',
        'Error checking pending approval requests: $e',
      );
      return null;
    }
  }

  Future<int?> createCreditApprovalRequest({
    required int orderId,
    required int partnerId,
    required double amount,
    required String reason,
    required String checkType,
    int? paymentTermId,
    bool skipDuplicateCheck = false,
  }) async {
    // OFFLINE-FIRST: If offline, update local state and queue
    if (!_orderManager.isOnline) {
      logger.d('[SalesRepo]', 'Offline - queuing credit approval request');

      // 1. Update local order state to 'waiting'
      await _orderManager.updateSaleOrderState(orderId, state: 'waiting', pendingConfirm: true);

      // 2. Queue the approval request creation
      if (_offlineQueue != null) {
        await _offlineQueue.queueOperation(
          model: 'approval.request',
          method: 'create_credit_approval',
          recordId: orderId,
          values: {
            'order_id': orderId,
            'partner_id': partnerId,
            'amount': amount,
            'reason': reason,
            'check_type': checkType,
            'payment_term_id': ?paymentTermId,
          },
          priority: OfflinePriority.high,
        );
      }

      logger.i('[SalesRepo]', 'Credit approval queued for order $orderId');
      return -1; // Indicates queued for offline processing
    }

    try {
      // 0. Check for existing pending approval requests (avoid duplicates)
      if (!skipDuplicateCheck) {
        final pendingRequests = await checkPendingApprovalRequests(
          partnerId: partnerId,
          orderId: orderId,
        );

        if (pendingRequests != null) {
          final count = pendingRequests['count'] as int;
          final latestRef =
              pendingRequests['latestRequest']?['reference'] as String?;
          throw StateError(
            count == 1
                ? 'Ya existe una solicitud de aprobación pendiente${latestRef != null ? ': $latestRef' : ''}. Espere la aprobación o cancele la solicitud existente.'
                : 'Existen $count solicitudes de aprobación pendientes para este cliente.',
          );
        }
      }

      // Intentar usar el wizard del módulo l10n_ec_sale_credit.
      // Si el wizard existe, es el flujo preferido porque:
      // - Maneja categoría, campos de auditoría y campos relacionados automáticamente
      // - Llama action_confirm() internamente (pasa a 'pending')
      // - Actualiza el estado de la orden a 'waiting' de forma nativa
      // - Mantiene compatibilidad con cualquier personalización del módulo
      int? approvalId;
      bool usedWizard = false;

      try {
        approvalId = await _createApprovalViaWizard(
          odooClient: _orderManager.client,
          orderId: orderId,
          partnerId: partnerId,
          amount: amount,
          checkType: checkType,
          paymentTermId: paymentTermId,
        );
        usedWizard = true;
        logger.i(
          '[SalesRepository]',
          'Approval request created via wizard for order $orderId',
        );
      } catch (wizardError) {
        // El wizard no está disponible (módulo no instalado, versión diferente, etc.)
        // Fallback: crear el approval.request directamente.
        logger.w(
          '[SalesRepository]',
          'Wizard approach failed, using direct fallback: $wizardError',
        );
        approvalId = await _createApprovalDirect(
          odooClient: _orderManager.client,
          orderId: orderId,
          partnerId: partnerId,
          amount: amount,
          reason: reason,
          checkType: checkType,
          paymentTermId: paymentTermId,
        );
      }

      if (approvalId == null && !usedWizard) {
        throw StateError('No se pudo crear la solicitud de aprobación');
      }

      if (approvalId != null) {
        logger.i(
          '[SalesRepository]',
          'Approval request ID=$approvalId for order $orderId '
          '(via ${usedWizard ? "wizard" : "direct"})',
        );
      }

      // Si se usó el fallback directo, el estado de la orden no fue cambiado
      // por el wizard. Actualizarlo manualmente.
      if (!usedWizard) {
        await _orderManager.client.write(
          model: 'sale.order',
          ids: [orderId],
          values: {'state': 'waiting'},
        );
        logger.d('[SalesRepository]', 'Order $orderId state changed to waiting (direct fallback)');
      }

      // Refrescar la orden para obtener el nuevo estado (waiting)
      await getById(orderId, forceRefresh: true);

      return approvalId ?? -2; // -2 indica que se usó el wizard sin ID de retorno
    } catch (e, stack) {
      logger.e(
        '[SalesRepository]',
        'Error creating credit approval request',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Crear solicitud de aprobación usando el wizard `credit.limit.exceeded.wizard`.
  ///
  /// El wizard maneja internamente:
  /// 1. Categoría de aprobación
  /// 2. Creación del approval.request con campos de auditoría
  /// 3. Llamada a action_confirm() (pasa a 'pending')
  /// 4. Cambio de estado de la orden a 'waiting'
  ///
  /// Retorna null si el wizard retorna sin ID explícito (el wizard
  /// confirma el request internamente sin devolver su ID directamente).
  Future<int?> _createApprovalViaWizard({
    required OdooClient odooClient,
    required int orderId,
    required int partnerId,
    required double amount,
    required String checkType,
    int? paymentTermId,
  }) async {
    // Obtener datos de crédito del cliente para pasar al wizard
    // (el wizard necesita current_credit_limit y credit_available)
    final clientData = await odooClient.searchRead(
      model: 'res.partner',
      domain: [
        ['id', '=', partnerId],
      ],
      fields: ['credit_limit', 'credit', 'credit_to_invoice'],
      limit: 1,
    );

    double currentCreditLimit = 0;
    double creditAvailable = 0;

    if (clientData.isNotEmpty) {
      final data = clientData.first;
      currentCreditLimit = (data['credit_limit'] as num?)?.toDouble() ?? 0;
      final credit = (data['credit'] as num?)?.toDouble() ?? 0;
      final creditToInvoice = (data['credit_to_invoice'] as num?)?.toDouble() ?? 0;
      creditAvailable = currentCreditLimit - credit - creditToInvoice;
    }

    // Crear la instancia del wizard
    final wizardId = await odooClient.create(
      model: 'credit.limit.exceeded.wizard',
      values: {
        'partner_id': partnerId,
        'sale_order_id': orderId,
        'transaction_amount': amount,
        'current_credit_limit': currentCreditLimit,
        'credit_available': creditAvailable,
        'authorization_type': checkType,
        'check_type': checkType,
        'payment_term_id': ?paymentTermId,
      },
    );

    if (wizardId == null) {
      throw StateError('No se pudo crear el wizard credit.limit.exceeded.wizard');
    }

    // Ejecutar la acción del wizard
    await odooClient.call(
      model: 'credit.limit.exceeded.wizard',
      method: 'action_create_approval_request',
      ids: [wizardId],
    );

    // El wizard no retorna el ID del approval.request directamente,
    // pero podemos buscarlo si lo necesitamos.
    // Para efectos del flujo de UI, retornamos null (el wizard lo creó internamente).
    return null;
  }

  /// Fallback: crear approval.request directamente (sin wizard).
  ///
  /// Usado cuando el wizard `credit.limit.exceeded.wizard` no está disponible
  /// (módulo en versión anterior o no instalado).
  Future<int?> _createApprovalDirect({
    required OdooClient odooClient,
    required int orderId,
    required int partnerId,
    required double amount,
    required String reason,
    required String checkType,
    int? paymentTermId,
  }) async {
    // 1. Buscar la categoría de aprobación de crédito
    final categorySearch = await odooClient.searchRead(
      model: 'approval.category',
      domain: [
        ['approval_type', '=', 'credit'],
      ],
      fields: ['id', 'name'],
      limit: 1,
    );

    if (categorySearch.isEmpty) {
      throw StateError(
        'No se encontró la categoría de aprobación de crédito en Odoo. '
        'Verifique que el módulo l10n_ec_sale_credit esté instalado.',
      );
    }

    final categoryId = categorySearch.first['id'] as int;

    // 2. Obtener nombre de la orden para referencia
    final orderSearch = await odooClient.searchRead(
      model: 'sale.order',
      domain: [
        ['id', '=', orderId],
      ],
      fields: ['name'],
      limit: 1,
    );

    final orderName = orderSearch.isNotEmpty
        ? orderSearch.first['name'] as String
        : 'SO$orderId';

    // 3. Construir referencia según tipo de verificación
    final referenceType = checkType == 'overdue_debt'
        ? 'Solicitud de Aprobación - Cliente con Deudas'
        : 'Solicitud de Aprobación - Límite de Crédito Excedido';

    // 4. Crear el approval.request
    final approvalId = await odooClient.create(
      model: 'approval.request',
      values: {
        'category_id': categoryId,
        'partner_id': partnerId,
        'amount': amount,
        'reference': '$orderName - $referenceType',
        'reason': reason,
        'approval_type': 'credit',
        'sale_order_id': orderId,
        'payment_term_id': ?paymentTermId,
      },
    );

    if (approvalId == null) {
      throw StateError('No se pudo crear la solicitud de aprobación (direct)');
    }

    // 5. Confirmar la solicitud para que pase a estado 'pending'
    await odooClient.call(
      model: 'approval.request',
      method: 'action_confirm',
      ids: [approvalId],
    );

    logger.d('[SalesRepository]', 'Approval request $approvalId confirmed (direct)');
    return approvalId;
  }
}
