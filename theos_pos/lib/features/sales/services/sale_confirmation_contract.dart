/// HTTP success is not business confirmation: Odoo can return a rejection or
/// a pending approval action without raising an RPC exception.
void requireConfirmedSaleResponse(dynamic response, {required int orderId}) {
  if (response is! Map || response['success'] != true) {
    final message = response is Map ? response['error'] : null;
    throw StateError(
      message is String && message.trim().isNotEmpty
          ? message
          : 'Odoo no confirmó la venta; revisa la aprobación pendiente.',
    );
  }
  if (response['order_id'] != orderId ||
      !const {'sale', 'done'}.contains(response['state'])) {
    throw StateError(
      'Odoo no devolvió la venta solicitada en estado confirmado.',
    );
  }
}

/// A pending native action is neither a confirmation nor a transport failure.
/// Keep its context so the client can open the approval for this exact order.
Map<String, dynamic>? readPendingSaleApprovalAction(
  dynamic response, {
  required int orderId,
}) {
  if (response is! Map || response['approval_required'] != true) return null;
  final action = response['action'];
  if (response['success'] != false ||
      response['order_id'] != orderId ||
      !const {'approved', 'waiting'}.contains(response['state']) ||
      action is! Map<String, dynamic> ||
      action['type'] is! String ||
      (action['type'] as String).trim().isEmpty) {
    throw StateError('Odoo devolvió una aprobación pendiente inconsistente.');
  }
  if (action['res_model'] == 'credit.limit.exceeded.wizard') {
    final context = action['context'];
    if (context is! Map || context['default_sale_order_id'] != orderId) {
      throw StateError(
        'La aprobación de crédito no corresponde a este pedido.',
      );
    }
  }
  return Map<String, dynamic>.unmodifiable(action);
}
