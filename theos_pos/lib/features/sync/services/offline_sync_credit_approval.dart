part of 'offline_sync_service.dart';

/// Replay of the complete credit-approval wizard workflow.
///
/// The queued method is a local command, not an Odoo RPC method. Retrying is
/// safe because every attempt first reconciles an existing pending request for
/// the sale order. This covers a lost response after
/// `action_create_approval_request` committed remotely.
extension _OfflineSyncCreditApproval on OfflineSyncService {
  Future<ConflictInfo?> _processCreditApproval(OfflineOperation op) async {
    if (op.commandVersion != CreditApprovalOfflineContract.version) {
      throw StateError(
        'Unsupported ${CreditApprovalOfflineContract.method} payload version '
        '${op.commandVersion}; expected '
        '${CreditApprovalOfflineContract.version}',
      );
    }

    final values = op.values;
    final partnerId = _positiveInt(values['partner_id']);
    final amount = (values['amount'] as num?)?.toDouble();
    final checkType = values['check_type'] as String?;
    if (partnerId == null ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        checkType == null ||
        checkType.trim().isEmpty) {
      throw StateError(
        'Invalid credit approval payload: partner, amount and check type are required',
      );
    }

    final orderId = await _resolveCreditApprovalOrderId(op);
    if (orderId == null) {
      throw StateError(
        'Credit approval sale order has no resolvable remote ID',
      );
    }

    if (await _pendingCreditApprovalExists(orderId)) {
      logger.i(
        '[OfflineSyncService]',
        'Credit approval for sale $orderId already exists; replay reconciled',
      );
      return null;
    }

    final partnerCredit = await _odooClient!.searchRead(
      model: 'res.partner',
      domain: [
        ['id', '=', partnerId],
      ],
      fields: const ['credit_limit', 'credit', 'credit_to_invoice'],
      limit: 1,
    );
    final partner = partnerCredit.isEmpty
        ? const <String, dynamic>{}
        : partnerCredit.first;
    final currentCreditLimit =
        (partner['credit_limit'] as num?)?.toDouble() ?? 0;
    final credit = (partner['credit'] as num?)?.toDouble() ?? 0;
    final creditToInvoice =
        (partner['credit_to_invoice'] as num?)?.toDouble() ?? 0;

    final wizardValues = <String, dynamic>{
      'partner_id': partnerId,
      'sale_order_id': orderId,
      'transaction_amount': amount,
      'current_credit_limit': currentCreditLimit,
      'credit_available': currentCreditLimit - credit - creditToInvoice,
      'authorization_type': checkType.trim(),
      'check_type': checkType.trim(),
      'payment_term_id': ?_positiveInt(values['payment_term_id']),
    };

    final rawWizardId = await _odooClient.call(
      model: 'credit.limit.exceeded.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [wizardValues],
      },
    );
    final wizardId = _firstPositiveId(rawWizardId);
    if (wizardId == null) {
      throw StateError('Odoo credit approval wizard returned no record ID');
    }

    await _odooClient.call(
      model: 'credit.limit.exceeded.wizard',
      method: 'action_create_approval_request',
      ids: [wizardId],
    );
    logger.i(
      '[OfflineSyncService]',
      'Credit approval replay completed for sale $orderId',
    );
    return null;
  }

  Future<int?> _resolveCreditApprovalOrderId(OfflineOperation op) async {
    final parentId = _positiveInt(op.parentOrderId);
    if (parentId != null) return parentId;

    final payloadId = _positiveInt(op.values['order_id']);
    if (payloadId != null) return payloadId;

    final uuid = op.values['order_uuid'] as String?;
    if (uuid == null || uuid.trim().isEmpty) return null;
    final orders = await _odooClient!.searchRead(
      model: 'sale.order',
      domain: [
        ['x_uuid', '=', uuid.trim()],
      ],
      fields: const ['id'],
      limit: 1,
    );
    return orders.isEmpty ? null : _positiveInt(orders.first['id']);
  }

  Future<bool> _pendingCreditApprovalExists(int orderId) async {
    final approvals = await _odooClient!.searchRead(
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
      fields: const ['id'],
      limit: 1,
    );
    return approvals.isNotEmpty;
  }

  int? _positiveInt(Object? value) {
    if (value is! num) return null;
    final integer = value.toInt();
    return integer > 0 ? integer : null;
  }

  int? _firstPositiveId(Object? value) {
    if (value is List && value.isNotEmpty) return _positiveInt(value.first);
    return _positiveInt(value);
  }
}
