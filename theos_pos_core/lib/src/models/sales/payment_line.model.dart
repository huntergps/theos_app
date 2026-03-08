import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:uuid/uuid.dart';

part 'payment_line.model.freezed.dart';
part 'payment_line.model.g.dart';

/// Tipo de linea de pago
enum PaymentLineType {
  @JsonValue('payment')
  payment,
  @JsonValue('advance')
  advance,
  @JsonValue('creditNote')
  creditNote,
}

/// Tipo de tarjeta
enum CardType {
  @JsonValue('credit')
  credit,
  @JsonValue('debit')
  debit,
}

/// Modelo de linea de pago para el wizard de cobros
///
/// Representa una linea individual de pago que puede ser:
/// - Pago directo (efectivo, tarjeta, cheque, transferencia)
/// - Aplicacion de anticipo
/// - Aplicacion de nota de credito
@OdooModel('account.payment.line', tableName: 'sale_order_payment_line')
@freezed
abstract class PaymentLine with _$PaymentLine {
  const PaymentLine._();

  // ═══════════════════ Validation ═══════════════════

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (amount <= 0) {
      errors['amount'] = 'El monto debe ser mayor a cero';
    }
    if (type == PaymentLineType.payment && journalId == null) {
      errors['journalId'] = 'Diario es requerido para pagos';
    }
    if (type == PaymentLineType.advance && advanceId == null) {
      errors['advanceId'] = 'Anticipo es requerido';
    }
    if (type == PaymentLineType.creditNote && creditNoteId == null) {
      errors['creditNoteId'] = 'Nota de credito es requerida';
    }
    return errors;
  }

  const factory PaymentLine({
    // ============ Identifiers ============
    @OdooId() @Default(0) int id,
    @OdooLocalOnly() String? lineUuid,
    @OdooLocalOnly() String? uuid,
    @OdooLocalOnly() @Default(false) bool isSynced,

    // ============ Core Fields ============
    @OdooLocalOnly() required PaymentLineType type,
    @OdooDate() required DateTime date,
    @OdooFloat() required double amount,
    @OdooString(odooName: 'payment_reference') String? reference,

    // ============ Order Reference ============
    @OdooLocalOnly() int? orderId,
    @OdooSelection() @Default('draft') String state,

    // ============ Payment Journal ============
    @OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,
    @OdooMany2OneName(sourceField: 'journal_id') String? journalName,
    @OdooLocalOnly() String? journalType,
    @OdooLocalOnly() int? paymentMethodId,
    @OdooMany2One('account.payment.method.line', odooName: 'payment_method_line_id') int? paymentMethodLineId,
    @OdooLocalOnly() String? paymentMethodCode,
    @OdooLocalOnly() String? paymentMethodName,

    // ============ Card Fields ============
    @OdooMany2One('res.bank', odooName: 'bank_id') int? bankId,
    @OdooMany2OneName(sourceField: 'bank_id') String? bankName,
    @OdooLocalOnly() CardType? cardType,
    @OdooMany2One('account.card.brand', odooName: 'card_brand_id') int? cardBrandId,
    @OdooMany2OneName(sourceField: 'card_brand_id') String? cardBrandName,
    @OdooMany2One('account.card.deadline', odooName: 'card_deadline_id') int? cardDeadlineId,
    @OdooMany2OneName(sourceField: 'card_deadline_id') String? cardDeadlineName,
    @OdooMany2One('account.card.lote', odooName: 'lote_id') int? loteId,
    @OdooMany2OneName(sourceField: 'lote_id') String? loteName,
    @OdooDate(odooName: 'bank_reference_date') DateTime? voucherDate,

    // ============ Check Fields ============
    @OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') int? partnerBankId,
    @OdooMany2OneName(sourceField: 'partner_bank_id') String? partnerBankName,
    @OdooDate(odooName: 'effective_date') DateTime? effectiveDate,

    // ============ Advance Fields ============
    @OdooMany2One('account.payment', odooName: 'advance_id') int? advanceId,
    @OdooMany2OneName(sourceField: 'advance_id') String? advanceName,
    @OdooLocalOnly() double? advanceAvailable,

    // ============ Credit Note Fields ============
    @OdooMany2One('account.move', odooName: 'credit_note_id') int? creditNoteId,
    @OdooMany2OneName(sourceField: 'credit_note_id') String? creditNoteName,
    @OdooLocalOnly() double? creditNoteAvailable,
  }) = _PaymentLine;

  factory PaymentLine.fromJson(Map<String, dynamic> json) =>
      _$PaymentLineFromJson(json);

  // ═══════════════════ Computed Properties ═══════════════════

  /// Descripcion legible de la linea de pago
  String get description {
    switch (type) {
      case PaymentLineType.advance:
        return 'Anticipo ${advanceName ?? advanceId}';
      case PaymentLineType.creditNote:
        return 'NC ${creditNoteName ?? creditNoteId}';
      case PaymentLineType.payment:
        final parts = <String>[];

        // Nombre del diario/metodo
        if (journalName != null) {
          parts.add(journalName!);
        }

        // Detalles especificos por tipo
        if (paymentMethodCode == 'manual' && journalType == 'cash') {
          // Efectivo - ya esta en journalName
        } else if (paymentMethodCode?.contains('card') == true) {
          if (cardBrandName != null) parts.add(cardBrandName!);
          if (cardDeadlineName != null) parts.add(cardDeadlineName!);
        } else if (paymentMethodCode?.contains('cheque') == true) {
          if (reference != null) parts.add('Ch. $reference');
        } else if (paymentMethodCode?.contains('transf') == true) {
          if (reference != null) parts.add('Ref. $reference');
        }

        return parts.join(' - ');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPUTED FIELDS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Indica si es un pago en efectivo
  bool get isCash => type == PaymentLineType.payment && journalType == 'cash';

  /// Indica si es un pago con tarjeta
  bool get isCard => paymentMethodCode?.contains('card') == true;

  /// Indica si es un cheque
  bool get isCheck => paymentMethodCode?.contains('cheque') == true;

  /// Indica si es una transferencia
  bool get isTransfer => paymentMethodCode?.contains('transf') == true;

  /// Indica si es un anticipo aplicado
  bool get isAdvance => type == PaymentLineType.advance;

  /// Indica si es una nota de credito aplicada
  bool get isCreditNote => type == PaymentLineType.creditNote;

  /// Indica si requiere campos adicionales
  bool get requiresAdditionalFields => isCard || isCheck || isTransfer;

  /// Obtiene el monto disponible segun el tipo
  double get availableAmount {
    if (isAdvance) return advanceAvailable ?? 0;
    if (isCreditNote) return creditNoteAvailable ?? 0;
    return double.infinity;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crear nueva linea con UUID generado
  factory PaymentLine.create({
    required PaymentLineType type,
    required DateTime date,
    required double amount,
    String? reference,
    int? journalId,
    String? journalName,
    String? journalType,
    int? paymentMethodLineId,
    String? paymentMethodCode,
    String? paymentMethodName,
    int? bankId,
    String? bankName,
    CardType? cardType,
    int? cardBrandId,
    String? cardBrandName,
    int? cardDeadlineId,
    String? cardDeadlineName,
    int? loteId,
    String? loteName,
    DateTime? voucherDate,
    int? partnerBankId,
    String? partnerBankName,
    DateTime? effectiveDate,
    int? advanceId,
    String? advanceName,
    double? advanceAvailable,
    int? creditNoteId,
    String? creditNoteName,
    double? creditNoteAvailable,
  }) {
    return PaymentLine(
      lineUuid: const Uuid().v4(),
      type: type,
      date: date,
      amount: amount,
      reference: reference,
      journalId: journalId,
      journalName: journalName,
      journalType: journalType,
      paymentMethodLineId: paymentMethodLineId,
      paymentMethodCode: paymentMethodCode,
      paymentMethodName: paymentMethodName,
      bankId: bankId,
      bankName: bankName,
      cardType: cardType,
      cardBrandId: cardBrandId,
      cardBrandName: cardBrandName,
      cardDeadlineId: cardDeadlineId,
      cardDeadlineName: cardDeadlineName,
      loteId: loteId,
      loteName: loteName,
      voucherDate: voucherDate,
      partnerBankId: partnerBankId,
      partnerBankName: partnerBankName,
      effectiveDate: effectiveDate,
      advanceId: advanceId,
      advanceName: advanceName,
      advanceAvailable: advanceAvailable,
      creditNoteId: creditNoteId,
      creditNoteName: creditNoteName,
      creditNoteAvailable: creditNoteAvailable,
    );
  }

  /// Crear linea de pago en efectivo.
  factory PaymentLine.cash({
    required DateTime date,
    required double amount,
    required int journalId,
    String? journalName,
    int? paymentMethodLineId,
    String? reference,
  }) {
    return PaymentLine.create(
      type: PaymentLineType.payment,
      date: date,
      amount: amount,
      journalId: journalId,
      journalName: journalName,
      journalType: 'cash',
      paymentMethodLineId: paymentMethodLineId,
      paymentMethodCode: 'manual',
      reference: reference,
    );
  }

  /// Crear linea de pago con tarjeta.
  factory PaymentLine.card({
    required DateTime date,
    required double amount,
    required int journalId,
    required int bankId,
    required CardType cardType,
    required int cardBrandId,
    required int cardDeadlineId,
    String? journalName,
    String? bankName,
    String? cardBrandName,
    String? cardDeadlineName,
    int? loteId,
    String? loteName,
    DateTime? voucherDate,
    String? reference,
  }) {
    return PaymentLine.create(
      type: PaymentLineType.payment,
      date: date,
      amount: amount,
      journalId: journalId,
      journalName: journalName,
      journalType: 'bank',
      paymentMethodCode: cardType == CardType.credit ? 'card_credit_in' : 'card_debit_in',
      bankId: bankId,
      bankName: bankName,
      cardType: cardType,
      cardBrandId: cardBrandId,
      cardBrandName: cardBrandName,
      cardDeadlineId: cardDeadlineId,
      cardDeadlineName: cardDeadlineName,
      loteId: loteId,
      loteName: loteName,
      voucherDate: voucherDate,
      reference: reference,
    );
  }

  /// Crear linea desde anticipo.
  factory PaymentLine.fromAdvance({
    required DateTime date,
    required double amount,
    required int advanceId,
    required String advanceName,
    required double advanceAvailable,
  }) {
    return PaymentLine.create(
      type: PaymentLineType.advance,
      date: date,
      amount: amount,
      advanceId: advanceId,
      advanceName: advanceName,
      advanceAvailable: advanceAvailable,
    );
  }

  /// Crear linea desde nota de credito.
  factory PaymentLine.fromCreditNote({
    required DateTime date,
    required double amount,
    required int creditNoteId,
    required String creditNoteName,
    required double creditNoteAvailable,
  }) {
    return PaymentLine.create(
      type: PaymentLineType.creditNote,
      date: date,
      amount: amount,
      creditNoteId: creditNoteId,
      creditNoteName: creditNoteName,
      creditNoteAvailable: creditNoteAvailable,
    );
  }
}

/// Diario de pago disponible
@freezed
abstract class AvailableJournal with _$AvailableJournal {
  const AvailableJournal._();

  const factory AvailableJournal({
    required int id,
    required String name,
    required String type,
    @Default(false) bool isCardJournal,
    @Default([]) List<PaymentMethod> paymentMethods,
    @Default([]) List<int> cardBrandIds,
    int? defaultCardBrandId,
    @Default([]) List<int> deadlineCreditIds,
    @Default([]) List<int> deadlineDebitIds,
    int? defaultDeadlineCreditId,
    int? defaultDeadlineDebitId,
  }) = _AvailableJournal;

  factory AvailableJournal.fromJson(Map<String, dynamic> json) =>
      _$AvailableJournalFromJson(json);

  factory AvailableJournal.fromOdoo(Map<String, dynamic> data) {
    return AvailableJournal(
      id: data['id'] as int,
      name: data['name'] as String,
      type: data['type'] as String,
      isCardJournal: data['is_card_journal'] as bool? ?? false,
      paymentMethods: (data['payment_method_ids'] as List<dynamic>?)
              ?.map((m) => PaymentMethod.fromOdoo(m as Map<String, dynamic>))
              .toList() ??
          [],
      cardBrandIds: (data['card_brand_ids'] as List<dynamic>?)?.cast<int>() ?? [],
    );
  }

  bool get isCash => type == 'cash';
  bool get isBank => type == 'bank';
  bool get isCredit => type == 'credit';

  bool get hasConfiguredCardBrands => cardBrandIds.isNotEmpty;
  bool get hasConfiguredCreditDeadlines => deadlineCreditIds.isNotEmpty;
  bool get hasConfiguredDebitDeadlines => deadlineDebitIds.isNotEmpty;

  List<int> getDeadlineIds(CardType cardType) {
    return cardType == CardType.credit ? deadlineCreditIds : deadlineDebitIds;
  }

  int? getDefaultDeadlineId(CardType cardType) {
    return cardType == CardType.credit ? defaultDeadlineCreditId : defaultDeadlineDebitId;
  }
}

/// Metodo de pago
@freezed
abstract class PaymentMethod with _$PaymentMethod {
  const PaymentMethod._();

  const factory PaymentMethod({
    required int id,
    required String name,
    String? spanishName,
    required String code,
  }) = _PaymentMethod;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodFromJson(json);

  factory PaymentMethod.fromOdoo(Map<String, dynamic> data) {
    return PaymentMethod(
      id: data['id'] as int,
      name: data['name'] as String,
      spanishName: data['spanish_name'] as String?,
      code: data['code'] as String,
    );
  }

  String get displayName => spanishName ?? name;

  bool get isCash => code == 'manual';
  bool get isCard => code.contains('card');
  bool get isCreditCard => code == 'card_credit_in' || code == 'card_credit_out';
  bool get isDebitCard => code == 'card_debit_in' || code == 'card_debit_out';
  bool get isCheck => code == 'cheque_in';
  bool get isDepositCheque => code == 'deposit_cheque_in';
  bool get isTransfer => code.contains('transf');
}

/// Anticipo disponible del cliente
@freezed
abstract class AvailableAdvance with _$AvailableAdvance {
  const AvailableAdvance._();

  const factory AvailableAdvance({
    required int id,
    required String name,
    required double amountAvailable,
    required DateTime date,
    String? reference,
  }) = _AvailableAdvance;

  factory AvailableAdvance.fromJson(Map<String, dynamic> json) =>
      _$AvailableAdvanceFromJson(json);

  factory AvailableAdvance.fromOdoo(Map<String, dynamic> data) {
    return AvailableAdvance(
      id: data['id'] as int,
      name: data['name'] as String,
      amountAvailable: (data['amount_available'] as num).toDouble(),
      date: DateTime.parse(data['date'] as String),
      reference: data['reference'] as String?,
    );
  }
}

/// Nota de credito disponible
@freezed
abstract class AvailableCreditNote with _$AvailableCreditNote {
  const AvailableCreditNote._();

  const factory AvailableCreditNote({
    required int id,
    required String name,
    required double amountResidual,
    DateTime? invoiceDate,
    String? ref,
  }) = _AvailableCreditNote;

  factory AvailableCreditNote.fromJson(Map<String, dynamic> json) =>
      _$AvailableCreditNoteFromJson(json);

  factory AvailableCreditNote.fromOdoo(Map<String, dynamic> data) {
    return AvailableCreditNote(
      id: data['id'] as int,
      name: data['name'] as String,
      amountResidual: (data['amount_residual'] as num).toDouble(),
      invoiceDate: data['invoice_date'] != null
          ? DateTime.parse(data['invoice_date'] as String)
          : null,
      ref: data['ref'] as String?,
    );
  }
}

/// Banco disponible
@freezed
abstract class AvailableBank with _$AvailableBank {
  const factory AvailableBank({
    required int id,
    required String name,
  }) = _AvailableBank;

  factory AvailableBank.fromJson(Map<String, dynamic> json) =>
      _$AvailableBankFromJson(json);

  factory AvailableBank.fromOdoo(Map<String, dynamic> data) {
    return AvailableBank(
      id: data['id'] as int,
      name: data['name'] as String,
    );
  }
}

/// Marca de tarjeta
@freezed
abstract class CardBrand with _$CardBrand {
  const factory CardBrand({
    required int id,
    required String name,
  }) = _CardBrand;

  factory CardBrand.fromJson(Map<String, dynamic> json) =>
      _$CardBrandFromJson(json);

  factory CardBrand.fromOdoo(Map<String, dynamic> data) {
    return CardBrand(
      id: data['id'] as int,
      name: data['name'] as String,
    );
  }
}

/// Plazo de tarjeta
@freezed
abstract class CardDeadline with _$CardDeadline {
  const CardDeadline._();

  const factory CardDeadline({
    required int id,
    required String name,
    @Default(0) int deadlineDays,
    @Default(0.0) double percentage,
  }) = _CardDeadline;

  factory CardDeadline.fromJson(Map<String, dynamic> json) =>
      _$CardDeadlineFromJson(json);

  factory CardDeadline.fromOdoo(Map<String, dynamic> data) {
    return CardDeadline(
      id: data['id'] as int,
      name: data['name'] as String,
      deadlineDays: data['deadline_days'] as int? ?? 0,
      percentage: (data['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get displayName {
    if (deadlineDays > 0) {
      return '$name ($deadlineDays dias)';
    }
    return name;
  }
}

/// Lote de tarjetas con estado y acciones.
@OdooModel('account.card.lote', tableName: 'account_card_lote')
@freezed
abstract class CardLote with _$CardLote {
  const CardLote._();

  // ═══════════════════ Validation ═══════════════════

  Map<String, String> validate() => {};

  const factory CardLote({
    // ============ Identifiers ============
    @OdooId() @Default(0) int id,
    @OdooLocalOnly() int? localId,
    @OdooLocalOnly() String? loteUuid,

    // ============ Basic Data ============
    @OdooString() required String name,
    @OdooMany2One('account.journal', odooName: 'journal_id') required int journalId,
    @OdooMany2OneName(sourceField: 'journal_id') String? journalName,
    @OdooSelection() @Default('open') String state,
    @OdooDate() DateTime? date,
    @OdooString(odooName: 'numero_lote') String? numeroLote,

    // ============ Amounts ============
    @OdooFloat(odooName: 'amount_total') @Default(0) double amountTotal,
    @OdooFloat(odooName: 'amount_balance') @Default(0) double amountBalance,
    @OdooInteger(odooName: 'payment_count') @Default(0) int paymentCount,

    // ============ Flags ============
    @OdooBoolean(odooName: 'is_pos_lote') @Default(false) bool isPosLote,
  }) = _CardLote;

  factory CardLote.fromJson(Map<String, dynamic> json) =>
      _$CardLoteFromJson(json);

  // ═══════════════════ Computed Properties ═══════════════════

  bool get isOpen => state == 'open';
  bool get isClosed => state == 'closed';
  bool get hasOdooId => id > 0;

  String get displayName {
    if (date != null) {
      final d = date!;
      return '$name (${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year})';
    }
    return name;
  }

  int get effectiveId => id > 0 ? id : (localId ?? 0);

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crear nuevo lote.
  factory CardLote.newLote({
    required String name,
    required int journalId,
    String? journalName,
    DateTime? date,
    String? numeroLote,
  }) {
    return CardLote(
      loteUuid: const Uuid().v4(),
      name: name,
      journalId: journalId,
      journalName: journalName,
      state: 'open',
      date: date ?? DateTime.now(),
      numeroLote: numeroLote,
    );
  }
}
