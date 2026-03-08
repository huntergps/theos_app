/// Standalone model classes used by SalesRepository
library;

/// Result of POS confirmation operation
class PosConfirmResult {
  final bool success;
  final String? error;
  final int? orderId;
  final String? orderName;
  final String? orderState;
  final CreditIssue? creditIssue;
  /// True if the order was confirmed offline (queued for sync)
  final bool confirmedOffline;

  const PosConfirmResult({
    required this.success,
    this.error,
    this.orderId,
    this.orderName,
    this.orderState,
    this.creditIssue,
    this.confirmedOffline = false,
  });

  bool get hasCreditIssue => creditIssue != null;
}

/// Credit validation issue details from Odoo
class CreditIssue {
  final String
  type; // 'pending_requests', 'overdue_debt', 'credit_limit_exceeded'
  final String message;
  final int partnerId;
  final String partnerName;

  // For pending_requests
  final int? pendingCount;

  // For overdue_debt
  final double? totalOverdue;
  final int? overdueInvoicesCount;
  final int? oldestOverdueDays;

  // For credit_limit_exceeded
  final double? creditLimit;
  final double? creditUsed;
  final double? creditAvailable;
  final double? excessAmount;

  // Common
  final double? orderAmount;

  const CreditIssue({
    required this.type,
    required this.message,
    required this.partnerId,
    required this.partnerName,
    this.pendingCount,
    this.totalOverdue,
    this.overdueInvoicesCount,
    this.oldestOverdueDays,
    this.creditLimit,
    this.creditUsed,
    this.creditAvailable,
    this.excessAmount,
    this.orderAmount,
  });

  factory CreditIssue.fromMap(Map<String, dynamic> map) {
    return CreditIssue(
      type: map['type'] as String? ?? 'unknown',
      message: map['message'] as String? ?? '',
      partnerId: map['partner_id'] as int? ?? 0,
      partnerName: map['partner_name'] as String? ?? '',
      pendingCount: map['pending_count'] as int?,
      totalOverdue: (map['total_overdue'] as num?)?.toDouble(),
      overdueInvoicesCount: map['overdue_invoices_count'] as int?,
      oldestOverdueDays: map['oldest_overdue_days'] as int?,
      creditLimit: (map['credit_limit'] as num?)?.toDouble(),
      creditUsed: (map['credit_used'] as num?)?.toDouble(),
      creditAvailable: (map['credit_available'] as num?)?.toDouble(),
      excessAmount: (map['excess_amount'] as num?)?.toDouble(),
      orderAmount: (map['order_amount'] as num?)?.toDouble(),
    );
  }

  bool get isPendingRequests => type == 'pending_requests';
  bool get isOverdueDebt => type == 'overdue_debt';
  bool get isCreditLimitExceeded => type == 'credit_limit_exceeded';
}
