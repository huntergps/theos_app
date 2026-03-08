import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'payment_term.model.freezed.dart';
part 'payment_term.model.g.dart';

/// Payment Term model representing account.payment.term in Odoo
@OdooModel('account.payment.term', tableName: 'account_payment_term')
@freezed
abstract class PaymentTerm with _$PaymentTerm {
  const PaymentTerm._();

  const factory PaymentTerm({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooBoolean() @Default(true) bool active,
    @OdooString() String? note,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooInteger() @Default(10) int sequence,
    @OdooBoolean(odooName: 'is_cash') @Default(true) bool isCash,
    @OdooBoolean(odooName: 'is_credit') @Default(false) bool isCredit,
    @OdooInteger(odooName: 'due_days') @Default(0) int dueDays,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _PaymentTerm;

  // ============ Computed Fields ============

  /// Check if this is an immediate/cash payment term
  bool get isImmediatePayment => isCash && !isCredit;

  /// Check if this requires credit validation
  bool get requiresCreditValidation => isCredit;

  /// Display name with payment type indicator
  String get displayName {
    if (isCredit) return '$name (Crédito)';
    if (isCash) return '$name (Contado)';
    return name;
  }

  /// Get payment type label
  String get paymentTypeLabel => isCredit ? 'Crédito' : 'Contado';
}
