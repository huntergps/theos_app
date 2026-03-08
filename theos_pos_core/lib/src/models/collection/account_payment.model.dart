import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'account_payment.model.freezed.dart';
part 'account_payment.model.g.dart';

/// Account Payment model with state machine.
///
/// ## State Machine
/// - draft -> posted (action_post)
/// - posted -> cancelled (action_cancel)
/// - cancelled -> draft (action_draft)
@OdooModel('account.payment', tableName: 'account_payment')
@freezed
abstract class AccountPayment with _$AccountPayment {
  const AccountPayment._();

  // ═══════════════════ Validation ═══════════════════

  /// Validates the payment before saving.
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (amount <= 0) {
      errors['amount'] = 'El monto debe ser mayor a cero';
    }
    return errors;
  }

  /// Validates for specific actions.
  Map<String, String> validateFor(String action) {
    final errors = validate();
    switch (action) {
      case 'post':
        if (!canPost) {
          errors['state'] = 'No se puede confirmar el pago en estado: $state';
        }
        if (journalId == null || journalId == 0) {
          errors['journalId'] = 'El diario de pago es requerido';
        }
        break;

      case 'cancel':
        if (!canCancel) {
          errors['state'] = 'No se puede cancelar el pago en estado: $state';
        }
        break;

      case 'draft':
        if (!isCancelled) {
          errors['state'] = 'Solo se puede pasar a borrador desde cancelado';
        }
        break;

      case 'reconcile':
        if (!isPosted) {
          errors['state'] = 'Solo se pueden conciliar pagos publicados';
        }
        break;
    }
    return errors;
  }

  const factory AccountPayment({
    // ============ Identifiers ============
    @OdooId() required int id,
    @OdooLocalOnly() String? paymentUuid,
    @OdooLocalOnly() @Default(false) bool isSynced,

    // ============ Relations ============
    @OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,
    @OdooMany2One('account.move', odooName: 'reconciled_invoice_ids') int? invoiceId,
    @OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,
    @OdooMany2OneName(sourceField: 'partner_id') String? partnerName,
    @OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,
    @OdooMany2OneName(sourceField: 'journal_id') String? journalName,
    @OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') int? paymentMethodLineId,
    @OdooMany2OneName(sourceField: 'payment_method_line_id') String? paymentMethodLineName,

    // ============ Economic Data ============
    @OdooFloat() @Default(0.0) double amount,
    @OdooSelection(odooName: 'payment_type') @Default('inbound') String paymentType,
    @OdooSelection() @Default('draft') String state,

    // ============ Classification ============
    @OdooSelection(odooName: 'payment_origin_type') String? paymentOriginType,
    @OdooSelection(odooName: 'payment_method_category') String? paymentMethodCategory,

    // ============ Bank (res.bank) ============
    @OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,
    @OdooMany2OneName(sourceField: 'bank_id') String? bankName,

    // ============ Check Fields (l10n_ec_collection_box) ============
    @OdooString(odooName: 'check_number') String? checkNumber,
    @OdooString(odooName: 'check_amount_in_words') String? checkAmountInWords,
    @OdooDate(odooName: 'bank_reference_date') DateTime? bankReferenceDate,
    @OdooBoolean(odooName: 'es_posfechado') @Default(false) bool esPosfechado,
    @OdooMany2One('account.cheque.recibido', odooName: 'cheque_recibido_id') int? chequeRecibidoId,

    // ============ Card Fields (l10n_ec_collection_box) ============
    @OdooMany2One('account.card.brand', odooName: 'card_brand_id') int? cardBrandId,
    @OdooMany2OneName(sourceField: 'card_brand_id') String? cardBrandName,
    @OdooSelection(odooName: 'card_type') String? cardType,
    @OdooMany2One('account.card.lote', odooName: 'lote_id') int? loteId,
    @OdooString(odooName: 'card_holder_name') String? cardHolderName,
    @OdooString(odooName: 'card_last_4') String? cardLast4,
    @OdooString(odooName: 'authorization_code') String? authorizationCode,

    // ============ Payment Classification (computed flags) ============
    @OdooBoolean(odooName: 'is_card_payment') @Default(false) bool isCardPayment,
    @OdooBoolean(odooName: 'is_transfer_payment') @Default(false) bool isTransferPayment,
    @OdooBoolean(odooName: 'is_check_payment') @Default(false) bool isCheckPayment,
    @OdooBoolean(odooName: 'is_cash_payment') @Default(false) bool isCashPayment,

    // ============ Sale Order Link ============
    @OdooMany2One('sale.order', odooName: 'sale_id') int? saleId,
    @OdooMany2One('account.payment', odooName: 'advance_id') int? advanceId,
    @OdooMany2One('res.users', odooName: 'collection_user_id') int? collectionUserId,

    // ============ Metadata ============
    @OdooDate() DateTime? date,
    @OdooString() String? name,
    @OdooString() String? ref,

    // ============ Sync ============
    @OdooLocalOnly() DateTime? lastSyncDate,
    @OdooDateTime(odooName: 'write_date') DateTime? writeDate,
  }) = _AccountPayment;

  factory AccountPayment.fromJson(Map<String, dynamic> json) =>
      _$AccountPaymentFromJson(json);

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPUTED FIELDS (equivalente a @api.depends)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Estado como enum para facilitar comparaciones
  PaymentState get stateEnum => PaymentState.fromString(state);

  /// Indica si el pago esta en borrador
  bool get isDraft => stateEnum == PaymentState.draft;

  /// Indica si el pago esta confirmado
  bool get isPosted => stateEnum == PaymentState.posted;

  /// Indica si el pago esta cancelado
  bool get isCancelled => stateEnum == PaymentState.cancelled;

  /// Indica si es un pago de entrada (cliente paga)
  bool get isInbound => paymentType == 'inbound';

  /// Indica si es un pago de salida (reembolso)
  bool get isOutbound => paymentType == 'outbound';

  /// Indica si se puede confirmar
  bool get canPost => isDraft && amount > 0;

  /// Indica si se puede cancelar
  bool get canCancel => isPosted;

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea un nuevo pago de cliente.
  ///
  /// Similar a: account.payment.new({...})
  factory AccountPayment.newCustomerPayment({
    required double amount,
    required int partnerId,
    String? partnerName,
    required int journalId,
    String? journalName,
    int? collectionSessionId,
    String? ref,
    DateTime? date,
    String? paymentOriginType,
    String? paymentMethodCategory,
  }) {
    return AccountPayment(
      id: 0,
      amount: amount,
      paymentType: 'inbound',
      state: 'draft',
      partnerId: partnerId,
      partnerName: partnerName,
      journalId: journalId,
      journalName: journalName,
      collectionSessionId: collectionSessionId,
      ref: ref,
      date: date ?? DateTime.now(),
      paymentOriginType: paymentOriginType,
      paymentMethodCategory: paymentMethodCategory,
      isSynced: false,
    );
  }

  /// Crea un nuevo pago en efectivo.
  factory AccountPayment.newCashPayment({
    required double amount,
    required int partnerId,
    String? partnerName,
    required int cashJournalId,
    String? cashJournalName,
    int? collectionSessionId,
    String? ref,
  }) {
    return AccountPayment.newCustomerPayment(
      amount: amount,
      partnerId: partnerId,
      partnerName: partnerName,
      journalId: cashJournalId,
      journalName: cashJournalName,
      collectionSessionId: collectionSessionId,
      ref: ref,
      paymentMethodCategory: 'cash',
    );
  }
}

/// Estado del pago
enum PaymentState {
  draft,
  posted,
  cancelled;

  static PaymentState fromString(String? value) {
    switch (value) {
      case 'posted':
        return PaymentState.posted;
      case 'cancel':
      case 'cancelled':
        return PaymentState.cancelled;
      default:
        return PaymentState.draft;
    }
  }
}
