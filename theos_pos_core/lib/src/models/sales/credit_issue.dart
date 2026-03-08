class CreditIssue {
  final String type;
  final String message;
  final int partnerId;
  final String partnerName;
  final double? creditLimit;
  final double? creditUsed;
  final double? creditAvailable;
  final double? excessAmount;
  final double? orderAmount;
  final double? totalOverdue;
  final int? overdueInvoicesCount;
  final int? oldestOverdueDays;
  final bool? isOverdueDebt;

  const CreditIssue({
    required this.type,
    required this.message,
    required this.partnerId,
    required this.partnerName,
    this.creditLimit,
    this.creditUsed,
    this.creditAvailable,
    this.excessAmount,
    this.orderAmount,
    this.totalOverdue,
    this.overdueInvoicesCount,
    this.oldestOverdueDays,
    this.isOverdueDebt,
  });

  factory CreditIssue.fromOdoo(Map<String, dynamic> data) {
    return CreditIssue(
      type: data['type'] as String? ?? 'credit_limit_exceeded',
      message: data['message'] as String? ?? 'Problema de credito',
      partnerId: data['partner_id'] as int? ?? 0,
      partnerName: data['partner_name'] as String? ?? '',
      creditLimit: (data['credit_limit'] as num?)?.toDouble(),
      creditUsed: (data['credit_used'] as num?)?.toDouble(),
      creditAvailable: (data['credit_available'] as num?)?.toDouble(),
      excessAmount: (data['excess_amount'] as num?)?.toDouble(),
      orderAmount: (data['order_amount'] as num?)?.toDouble(),
      totalOverdue: (data['total_overdue'] as num?)?.toDouble(),
      overdueInvoicesCount: data['overdue_invoices_count'] as int?,
      oldestOverdueDays: data['oldest_overdue_days'] as int?,
      isOverdueDebt: data['is_overdue_debt'] as bool?,
    );
  }
}
