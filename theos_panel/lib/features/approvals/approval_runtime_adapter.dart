import 'package:orbi_runtime/orbi_runtime.dart';

import 'approval_contracts.dart';

abstract interface class ApprovalOfflineQueue {
  Future<void> enqueue({
    required String commandId,
    required ApprovalRequest request,
    required ApprovalAction action,
    required String scopeKey,
    ApprovalDecision? decision,
  });
}

abstract interface class ApprovalRpc {
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  });
}

final class ApprovalSessionContext {
  const ApprovalSessionContext({
    required this.scopeKey,
    required this.userId,
    this.client,
  });
  final String scopeKey;
  final int userId;
  final OdooClient? client;
}

final class OdooApprovalRpc implements ApprovalRpc {
  const OdooApprovalRpc(this.client);
  final OdooClient client;
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) => client.call(model: model, method: method, ids: ids, kwargs: kwargs);
}

/// F07 adapter: validates the active SessionActivation and capabilities before
/// any RPC. It delegates exact custom actions; no approval/business rules are
/// reimplemented here.
final class SessionApprovalPort implements ApprovalPort {
  SessionApprovalPort({
    required this.runtime,
    required this.capabilities,
    required this.offlineQueue,
    this.rpcFactory = OdooApprovalRpc.new,
    this.sessionContext,
  });
  final SessionRuntime runtime;
  final CapabilitySnapshot capabilities;
  final ApprovalOfflineQueue offlineQueue;
  final ApprovalRpc Function(OdooClient) rpcFactory;
  final ApprovalSessionContext Function()? sessionContext;
  ApprovalSessionContext? get _activeContext =>
      sessionContext?.call() ??
      (runtime.active == null
          ? null
          : ApprovalSessionContext(
              scopeKey: runtime.active!.scope.scopeKey,
              userId: runtime.active!.scope.userId,
              client: runtime.active!.client,
            ));

  ApprovalResult _guard(
    ApprovalRequest request,
    ApprovalAction action, {
    required bool offline,
  }) {
    final active = _activeContext;
    if (active == null || active.scopeKey != capabilities.scopeKey) {
      return const ApprovalResult(
        accepted: false,
        message: 'Sesión fuera de ámbito',
      );
    }
    if (!capabilities.permissions.contains('approver')) {
      return const ApprovalResult(
        accepted: false,
        message: 'Autoridad insuficiente',
      );
    }
    if (offline && !capabilities.offlineOperations.contains('approve_credit')) {
      return const ApprovalResult(
        accepted: false,
        message: 'Capacidad offline no aprovisionada',
      );
    }
    if (request.fsc && request.terms != ApprovalTerms.cash) {
      return const ApprovalResult(
        accepted: false,
        message: 'FSC requiere contado',
      );
    }
    return const ApprovalResult(accepted: true, message: 'ok');
  }

  int _saleId(ApprovalRequest request) {
    final id = request.saleOrderRemoteId;
    if (id == null || id <= 0) {
      throw ArgumentError('saleOrderRemoteId requerido');
    }
    return id;
  }

  int _approvalId(ApprovalRequest request) {
    final id = request.approvalRequestRemoteId;
    if (id == null || id <= 0) {
      throw ArgumentError('approvalRequestRemoteId requerido');
    }
    return id;
  }

  @override
  Future<List<ApprovalRequest>> pending() async {
    final active = _activeContext;
    if (active == null ||
        active.scopeKey != capabilities.scopeKey ||
        active.client == null) {
      return const [];
    }
    final rows = await rpcFactory(active.client!).call(
      model: 'approval.request',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['request_owner_id', '=', active.userId],
        ],
        'fields': [
          'id',
          'reference',
          'request_status',
          'sale_order_id',
          'approval_type',
        ],
        'limit': 100,
      },
    );
    if (rows is! List) return const [];
    return [
      for (final row in rows.whereType<Map>())
        ApprovalRequest(
          commandId: 'approval:${row['id']}',
          approvalRequestRemoteId: (row['id'] as num).toInt(),
          saleOrderRemoteId: ((row['sale_order_id'] is List)
              ? ((row['sale_order_id'] as List).first as num?)?.toInt()
              : (row['sale_order_id'] as num?)?.toInt()),
          orderDisplayName:
              row['reference'] as String? ?? 'Solicitud ${row['id']}',
          terms: (row['approval_type'] == 'credit')
              ? ApprovalTerms.credit
              : ApprovalTerms.cash,
          fsc: row['approval_type'] == 'fsc',
          status: row['request_status'] == 'approved'
              ? ApprovalStatus.approved
              : row['request_status'] == 'refused'
              ? ApprovalStatus.rejected
              : ApprovalStatus.requested,
        ),
    ];
  }

  @override
  Future<ApprovalResult> request(ApprovalRequest request) async {
    final action = ApprovalAction.commercialRequest;
    final guard = _guard(request, action, offline: false);
    if (!guard.accepted) return guard;
    final client = _activeContext?.client;
    if (client == null) {
      return const ApprovalResult(
        accepted: false,
        message: 'Cliente Odoo no disponible',
      );
    }
    final rpc = rpcFactory(client);
    if (request.fsc) {
      await rpc.call(
        model: 'sale.order',
        method: 'action_l10n_ec_solicitar_facturar_sin_cobro',
        ids: [_saleId(request)],
      );
    } else if (request.terms == ApprovalTerms.credit) {
      if (request.partnerId == null || request.transactionAmount == null) {
        return const ApprovalResult(
          accepted: false,
          message: 'Datos de crédito incompletos',
        );
      }
      final values = <String, dynamic>{
        'partner_id': request.partnerId,
        'transaction_amount': request.transactionAmount,
        'authorization_type': 'credit_limit_exceeded',
        'check_type': 'credit_limit_exceeded',
        if (request.saleOrderRemoteId != null)
          'sale_order_id': request.saleOrderRemoteId,
        if (request.paymentTermId != null)
          'payment_term_id': request.paymentTermId,
      };
      final created = await rpc.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'create',
        kwargs: {
          'vals_list': [values],
        },
      );
      final wizardId = created is List
          ? (created.isEmpty ? null : (created.first as num?)?.toInt())
          : (created as num?)?.toInt();
      if (wizardId == null) {
        return const ApprovalResult(
          accepted: false,
          message: 'No se creó la solicitud de crédito',
        );
      }
      await rpc.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'action_create_approval_request',
        ids: [wizardId],
      );
    } else {
      final result = await rpc.call(
        model: 'sale.order',
        method: 'action_pos_confirm',
        ids: [_saleId(request)],
      );
      if (result is Map && result['approval_required'] == true) {
        return ApprovalResult(
          accepted: false,
          message: 'Aprobación pendiente',
          commandId: request.commandId,
          pendingAction: result['action']?.toString(),
        );
      }
    }
    return ApprovalResult(
      accepted: true,
      message: 'Solicitud registrada',
      commandId: request.commandId,
    );
  }

  @override
  Future<ApprovalResult> resolve({
    required ApprovalRequest request,
    required ApprovalDecision decision,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async {
    final action = ApprovalAction.commercialRequest;
    final guard = _guard(request, action, offline: offline);
    if (!guard.accepted) return guard;
    final method = decision == ApprovalDecision.approve
        ? 'action_approve'
        : 'action_refuse';
    if (offline) {
      await offlineQueue.enqueue(
        commandId: request.commandId,
        request: request,
        action: action,
        scopeKey: capabilities.scopeKey,
        decision: decision,
      );
      return ApprovalResult(
        accepted: true,
        message: 'Decisión encolada',
        commandId: request.commandId,
      );
    }
    final client = _activeContext?.client;
    if (client == null) {
      return const ApprovalResult(
        accepted: false,
        message: 'Cliente Odoo no disponible',
      );
    }
    final result = await rpcFactory(client).call(
      model: 'approval.request',
      method: method,
      ids: [_approvalId(request)],
    );
    if (_rpcRejected(result)) {
      return const ApprovalResult(
        accepted: false,
        message: 'Odoo rechazó la decisión de aprobación.',
      );
    }
    return ApprovalResult(
      accepted: true,
      message: 'Decisión registrada',
      commandId: request.commandId,
    );
  }

  @override
  Future<ApprovalResult> performAction({
    required ApprovalRequest request,
    required ApprovalAction action,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async {
    final guard = _guard(request, action, offline: offline);
    if (!guard.accepted) return guard;
    if (action == ApprovalAction.delivery) {
      return const ApprovalResult(
        accepted: false,
        message: 'Entrega requiere cobro completo',
      );
    }
    if (offline) {
      await offlineQueue.enqueue(
        commandId: request.commandId,
        request: request,
        action: action,
        scopeKey: capabilities.scopeKey,
        decision: null,
      );
      return ApprovalResult(
        accepted: true,
        message: 'Acción FSC encolada; entrega sigue bloqueada',
        commandId: request.commandId,
      );
    }
    final client = _activeContext?.client;
    if (client == null) {
      return const ApprovalResult(
        accepted: false,
        message: 'Cliente Odoo no disponible',
      );
    }
    if (!request.fsc || request.terms != ApprovalTerms.cash) {
      return const ApprovalResult(
        accepted: false,
        message: 'FSC requiere contado',
      );
    }
    await rpcFactory(client).call(
      model: 'sale.order',
      method: 'action_l10n_ec_aprobar_fsc',
      ids: [_saleId(request)],
    );
    return ApprovalResult(
      accepted: true,
      message: 'Factura y despacho adelantados; entrega condicionada al pago',
      commandId: request.commandId,
    );
  }
}

bool _rpcRejected(dynamic result) =>
    result == false ||
    (result is Map &&
        (result['success'] == false ||
            result['error'] != null ||
            result['warning'] != null));
