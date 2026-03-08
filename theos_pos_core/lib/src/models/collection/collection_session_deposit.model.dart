import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:uuid/uuid.dart';

part 'collection_session_deposit.model.freezed.dart';
part 'collection_session_deposit.model.g.dart';

enum DepositType {
  @JsonValue('cash')
  cash,
  @JsonValue('check')
  check,
  @JsonValue('mixed')
  mixed,
}

/// Collection Session Deposit migrated to @OdooModel annotation pattern.
///
/// ## Computed fields (equivalent to @api.depends in Odoo)
///
/// - [isCashDeposit] / [isCheckDeposit] / [isMixedDeposit] -> depends: [depositType]
/// - [hasMove] -> depends: [moveId]
@OdooModel('collection.session.deposit', tableName: 'collection_session_deposit')
@freezed
abstract class CollectionSessionDeposit with _$CollectionSessionDeposit {
  const CollectionSessionDeposit._();

  // ═══════════════════ Validation ═══════════════════

  /// Validates the deposit before saving.
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (amount <= 0) {
      errors['amount'] = 'El monto debe ser mayor a cero';
    }
    if (collectionSessionId == null || collectionSessionId == 0) {
      errors['session'] = 'La sesion es requerida';
    }
    return errors;
  }

  /// Validates for specific actions.
  Map<String, String> validateFor(String action) {
    final errors = validate();
    switch (action) {
      case 'confirm':
        if (bankJournalId == null || bankJournalId == 0) {
          errors['bankJournalId'] = 'El banco es requerido';
        }
        if (isMixedDeposit) {
          if (cashAmount + checkAmount != amount) {
            errors['amount'] = 'La suma de efectivo y cheques debe ser igual al monto total';
          }
        }
        if (isCheckDeposit && checkCount <= 0) {
          errors['checkCount'] = 'Debe indicar la cantidad de cheques';
        }
        break;

      case 'cancel':
        if (hasMove) {
          errors['moveId'] = 'No se puede cancelar un deposito con asiento contable';
        }
        break;
    }
    return errors;
  }

  const factory CollectionSessionDeposit({
    // ============ Identifiers ============
    @OdooId() @Default(0) int id,
    @OdooLocalOnly() String? uuid,
    @OdooLocalOnly() @Default(false) bool isSynced,
    @OdooLocalOnly() DateTime? lastSyncDate,

    // ============ Basic Data ============
    @OdooString() String? name,
    @OdooString() String? number,

    // ============ Relations ============
    @OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,
    /// UUID of the parent session (for offline linking)
    @OdooString(odooName: 'session_uuid') String? sessionUuid,
    @OdooMany2One('res.users', odooName: 'user_id') int? userId,
    @OdooMany2OneName(sourceField: 'user_id') String? userName,

    // ============ Date Fields ============
    @OdooDateTime(odooName: 'deposit_date') DateTime? depositDate,
    @OdooDate(odooName: 'accounting_date') DateTime? accountingDate,

    // ============ Amount Fields ============
    @OdooFloat() @Default(0.0) double amount,
    @OdooSelection(odooName: 'deposit_type') @Default(DepositType.cash) DepositType depositType,
    @OdooFloat(odooName: 'cash_amount') @Default(0.0) double cashAmount,
    @OdooFloat(odooName: 'check_amount') @Default(0.0) double checkAmount,
    @OdooInteger(odooName: 'check_count') @Default(0) int checkCount,

    // ============ Bank Fields ============
    @OdooMany2One('account.journal', odooName: 'bank_journal_id') int? bankJournalId,
    @OdooMany2OneName(sourceField: 'bank_journal_id') String? bankJournalName,
    // Alias fields for table compatibility
    @OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,
    @OdooMany2OneName(sourceField: 'bank_id') String? bankName,

    // ============ State & References ============
    @OdooSelection() String? state,
    @OdooDateTime(odooName: 'write_date') DateTime? writeDate,
    @OdooString(odooName: 'deposit_slip_number') String? depositSlipNumber,
    @OdooString(odooName: 'bank_reference') String? bankReference,
    @OdooMany2One('account.move', odooName: 'move_id') int? moveId,
    @OdooString(odooName: 'depositor_name') String? depositorName,
    @OdooString() String? notes,
  }) = _CollectionSessionDeposit;

  factory CollectionSessionDeposit.fromJson(Map<String, dynamic> json) =>
      _$CollectionSessionDepositFromJson(json);

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPUTED FIELDS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Indica si es deposito en efectivo
  bool get isCashDeposit => depositType == DepositType.cash;

  /// Indica si es deposito en cheques
  bool get isCheckDeposit => depositType == DepositType.check;

  /// Indica si es deposito mixto
  bool get isMixedDeposit => depositType == DepositType.mixed;

  /// Indica si tiene asiento contable
  bool get hasMove => moveId != null && moveId! > 0;

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a new deposit with generated UUID for offline tracking
  factory CollectionSessionDeposit.create({
    required int collectionSessionId,
    String? sessionUuid,
    required DateTime depositDate,
    required double amount,
    DepositType depositType = DepositType.cash,
    double cashAmount = 0.0,
    double checkAmount = 0.0,
    int checkCount = 0,
    int? bankJournalId,
    String? bankJournalName,
    String? depositSlipNumber,
    String? bankReference,
    String? depositorName,
    String? notes,
    int? userId,
    String? userName,
  }) {
    return CollectionSessionDeposit(
      uuid: const Uuid().v4(),
      collectionSessionId: collectionSessionId,
      sessionUuid: sessionUuid,
      depositDate: depositDate,
      accountingDate: depositDate,
      amount: amount,
      depositType: depositType,
      cashAmount: cashAmount,
      checkAmount: checkAmount,
      checkCount: checkCount,
      bankJournalId: bankJournalId,
      bankJournalName: bankJournalName,
      depositSlipNumber: depositSlipNumber,
      bankReference: bankReference,
      depositorName: depositorName,
      notes: notes,
      userId: userId,
      userName: userName,
      isSynced: false,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONCHANGE SIMULATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Simula onchange de depositType.
  ///
  /// Actualiza los montos de efectivo/cheque segun el tipo.
  CollectionSessionDeposit onDepositTypeChanged(DepositType newType) {
    switch (newType) {
      case DepositType.cash:
        return copyWith(
          depositType: newType,
          cashAmount: amount,
          checkAmount: 0,
          checkCount: 0,
        );
      case DepositType.check:
        return copyWith(
          depositType: newType,
          cashAmount: 0,
          checkAmount: amount,
        );
      case DepositType.mixed:
        return copyWith(depositType: newType);
    }
  }

  /// Simula onchange de amount.
  CollectionSessionDeposit onAmountChanged(double newAmount) {
    if (isCashDeposit) {
      return copyWith(amount: newAmount, cashAmount: newAmount);
    } else if (isCheckDeposit) {
      return copyWith(amount: newAmount, checkAmount: newAmount);
    }
    return copyWith(amount: newAmount);
  }
}
