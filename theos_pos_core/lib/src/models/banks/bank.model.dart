import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'bank.model.freezed.dart';
part 'bank.model.g.dart';

/// Bank model representing res.bank in Odoo
@OdooModel('res.bank', tableName: 'res_bank')
@freezed
abstract class Bank with _$Bank {
  const Bank._();

  const factory Bank({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooString() String? bic,
    @OdooMany2One('res.country', odooName: 'country') int? countryId,
    @OdooBoolean() @Default(true) bool active,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _Bank;

  // ═══════════════════════════════════════════════════════════════════════════
  // Convenience Getters
  // ═══════════════════════════════════════════════════════════════════════════

  bool get isActive => active;
  String get displayName => name;
  DateTime? get lastModified => writeDate;

  // ═══════════════════════════════════════════════════════════════════════════
  // BUSINESS LOGIC
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if bank has BIC/SWIFT code
  bool get hasBic => bic?.isNotEmpty == true;

  /// Check if bank has country association
  bool get hasCountry => countryId != null;

  /// Get formatted bank name with BIC
  String get formattedName {
    if (hasBic) {
      return '$name ($bic)';
    }
    return name;
  }
}

/// Partner Bank Account model representing res.partner.bank in Odoo
@OdooModel('res.partner.bank', tableName: 'res_partner_bank')
@freezed
abstract class PartnerBank with _$PartnerBank {
  const PartnerBank._();

  const factory PartnerBank({
    @OdooId() required int id,
    @OdooMany2One('res.partner', odooName: 'partner_id') required int partnerId,
    @OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,
    @OdooString(odooName: 'acc_number') required String accNumber,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _PartnerBank;

  // ═══════════════════════════════════════════════════════════════════════════
  // Convenience Getters
  // ═══════════════════════════════════════════════════════════════════════════

  bool get isActive => true;
  String get displayName => accNumber;
  DateTime? get lastModified => writeDate;

  // ═══════════════════════════════════════════════════════════════════════════
  // BUSINESS LOGIC
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if partner bank has bank association
  bool get hasBank => bankId != null;

  /// Check if account number is valid (not empty)
  bool get isValidAccNumber => accNumber.trim().isNotEmpty;

  /// Get masked account number for display (show last 4 digits)
  String get maskedAccNumber {
    if (accNumber.length <= 4) return accNumber;
    return '*' * (accNumber.length - 4) + accNumber.substring(accNumber.length - 4);
  }
}
