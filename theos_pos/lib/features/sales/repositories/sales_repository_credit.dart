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
    Map<String, dynamic>? approvalAction,
  }) async {
    // OFFLINE-FIRST: Commit the local state and its durable intent together.
    if (!_orderManager.isOnline) {
      logger.d('[SalesRepo]', 'Offline - queuing credit approval request');
      final queue = _offlineQueue;
      if (queue == null) return null;

      return _db.transaction(() async {
        final localOrder = await _orderManager.getSaleOrder(orderId);
        if (localOrder == null || localOrder.partnerId != partnerId) {
          throw StateError('El pedido local no corresponde a este cliente.');
        }
        await _orderManager.updateSaleOrderState(
          orderId,
          state: 'waiting',
          pendingConfirm: true,
        );
        await CreditApprovalOfflineContract.enqueue(
          queue: queue,
          orderId: orderId,
          partnerId: partnerId,
          amount: amount,
          checkType: checkType,
          paymentTermId: paymentTermId,
          orderUuid: localOrder.orderUuid,
        );
        logger.i('[SalesRepo]', 'Credit approval queued for order $orderId');
        return -1; // Persisted locally; awaiting synchronization.
      });
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

      // Un rechazo del asistente es un rechazo del negocio, no una señal para
      // crear approval.request por otra vía ni escribir waiting a mano.
      final approvalId = await _createApprovalViaWizard(
        odooClient: _orderManager.client,
        orderId: orderId,
        partnerId: partnerId,
        amount: amount,
        checkType: checkType,
        paymentTermId: paymentTermId,
        approvalAction: approvalAction,
      );

      // Refrescar la orden para obtener el nuevo estado (waiting)
      await getById(orderId, forceRefresh: true);

      return approvalId ??
          -2; // -2 indica que se usó el wizard sin ID de retorno
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
    Map<String, dynamic>? approvalAction,
  }) async {
    if (approvalAction != null) {
      final context = approvalAction['context'];
      if (approvalAction['type'] != 'ir.actions.act_window' ||
          approvalAction['res_model'] != 'credit.limit.exceeded.wizard' ||
          context is! Map<String, dynamic> ||
          context['default_sale_order_id'] != orderId ||
          context['default_partner_id'] != partnerId) {
        throw StateError('La acción de aprobación no corresponde al pedido.');
      }
      // Igual que abrir el asistente nativo: defaults calculados por Odoo, no
      // una segunda clasificación de crédito basada en el saldo local.
      final created = await odooClient.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'create',
        kwargs: {
          'vals_list': [<String, dynamic>{}],
        },
        context: context,
      );
      final wizardId = created is int
          ? created
          : created is List && created.length == 1 && created.first is int
          ? created.first as int
          : null;
      if (wizardId == null || wizardId <= 0) {
        throw StateError('Odoo no devolvió el asistente de aprobación.');
      }
      await odooClient.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'action_create_approval_request',
        ids: [wizardId],
      );
      final requests = await odooClient.searchRead(
        model: 'approval.request',
        domain: [
          ['sale_order_id', '=', orderId],
          ['approval_type', '=', 'credit'],
          [
            'request_status',
            'in',
            ['new', 'pending'],
          ],
        ],
        fields: ['id'],
        order: 'id desc',
        limit: 1,
      );
      final requestId = requests.isEmpty ? null : requests.first['id'];
      if (requestId is! int || requestId <= 0) {
        throw StateError(
          'Odoo no confirmó una solicitud de aprobación pendiente.',
        );
      }
      return requestId;
    }

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
      final creditToInvoice =
          (data['credit_to_invoice'] as num?)?.toDouble() ?? 0;
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
      throw StateError(
        'No se pudo crear el wizard credit.limit.exceeded.wizard',
      );
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
}
