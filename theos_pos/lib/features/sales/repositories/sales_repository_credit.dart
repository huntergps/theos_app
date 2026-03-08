part of 'sales_repository.dart';

/// Credit approval operations: checking pending requests and creating
/// credit approval requests for sale orders.
extension SalesRepositoryCredit on SalesRepository {
  Future<Map<String, dynamic>?> checkPendingApprovalRequests({
    required int partnerId,
    int? orderId,
  }) async {
    if (_odooClient == null) return null;

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

      final pendingRequests = await _odooClient.searchRead(
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
    if (_odooClient == null) {
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
            if (paymentTermId != null) 'payment_term_id': paymentTermId,
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

      // 1. Buscar la categoría de aprobación de crédito
      final categorySearch = await _odooClient.searchRead(
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
      final orderSearch = await _odooClient.searchRead(
        model: 'sale.order',
        domain: [
          ['id', '=', orderId],
        ],
        fields: ['name', 'amount_total'],
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
      // Nota: request_owner_id se asigna automáticamente al usuario actual en Odoo
      final approvalId = await _odooClient.create(
        model: 'approval.request',
        values: {
          'category_id': categoryId,
          'partner_id': partnerId,
          'amount': amount,
          'reference': '$orderName - $referenceType',
          'reason': reason,
          'approval_type': 'credit',
          'sale_order_id': orderId,
          if (paymentTermId != null) 'payment_term_id': paymentTermId,
        },
      );

      if (approvalId == null) {
        throw StateError('No se pudo crear la solicitud de aprobación');
      }

      logger.i(
        '[SalesRepository]',
        'Approval request created: ID=$approvalId for order $orderId',
      );

      // 5. Confirmar la solicitud para que pase a estado 'pending'
      await _odooClient.call(
        model: 'approval.request',
        method: 'action_confirm',
        ids: [approvalId],
      );

      logger.d('[SalesRepository]', 'Approval request $approvalId confirmed');

      // 6. Cambiar estado de la orden a 'waiting'
      await _odooClient.write(
        model: 'sale.order',
        ids: [orderId],
        values: {'state': 'waiting'},
      );

      logger.d('[SalesRepository]', 'Order $orderId state changed to waiting');

      // 7. Refrescar la orden para obtener el nuevo estado
      await getById(orderId, forceRefresh: true);

      return approvalId;
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
}
