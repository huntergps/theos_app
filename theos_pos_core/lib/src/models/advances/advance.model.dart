import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:uuid/uuid.dart';

part 'advance.model.freezed.dart';
part 'advance.model.g.dart';

/// Estado del anticipo
enum AdvanceState {
  @JsonValue('draft')
  draft('draft', 'Borrador'),
  @JsonValue('posted')
  posted('posted', 'Publicado'),
  @JsonValue('in_use')
  inUse('in_use', 'En Uso'),
  @JsonValue('used')
  used('used', 'Usado'),
  @JsonValue('expired')
  expired('expired', 'Vencido'),
  @JsonValue('canceled')
  canceled('canceled', 'Cancelado'),
  @JsonValue('rejected')
  rejected('rejected', 'Rechazado');

  final String code;
  final String label;

  const AdvanceState(this.code, this.label);

  static AdvanceState fromCode(String? code) {
    if (code == null) return AdvanceState.draft;
    return AdvanceState.values.firstWhere(
      (e) => e.code == code,
      orElse: () => AdvanceState.draft,
    );
  }
}

/// Tipo de anticipo
enum AdvanceType {
  @JsonValue('inbound')
  inbound('inbound', 'Anticipo de Cliente'),
  @JsonValue('outbound')
  outbound('outbound', 'Anticipo a Proveedor');

  final String code;
  final String label;

  const AdvanceType(this.code, this.label);

  static AdvanceType fromCode(String? code) {
    if (code == null) return AdvanceType.inbound;
    return AdvanceType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => AdvanceType.inbound,
    );
  }
}

/// Modelo de anticipo.
///
/// Representa un anticipo de cliente o proveedor que puede ser aplicado
/// a futuras facturas.
///
/// ## State Machine
/// - draft -> posted (action_post)
/// - posted -> in_use (when applied to invoice)
/// - in_use -> used (when fully used)
/// - draft -> canceled (action_cancel)
@OdooModel('account.advance', tableName: 'account_advance')
@freezed
abstract class Advance with _$Advance {
  const Advance._();

  const factory Advance({
    @OdooId() @Default(0) int id,
    @OdooLocalOnly() String? advanceUuid,
    @OdooString() String? name,
    @OdooDate() required DateTime date,
    @OdooDate(odooName: 'date_estimated') DateTime? dateEstimated,
    @OdooDate(odooName: 'date_due') DateTime? dateDue,
    @OdooSelection() @Default(AdvanceState.draft) AdvanceState state,
    @OdooSelection(odooName: 'advance_type') required AdvanceType advanceType,
    @OdooMany2One('res.partner', odooName: 'partner_id') required int partnerId,
    @OdooMany2OneName(sourceField: 'partner_id') String? partnerName,
    @OdooString() required String reference,
    @OdooFloat() @Default(0) double amount,
    @OdooFloat(odooName: 'amount_used') @Default(0) double amountUsed,
    @OdooFloat(odooName: 'amount_available') @Default(0) double amountAvailable,
    @OdooFloat(odooName: 'amount_returned') @Default(0) double amountReturned,
    @OdooFloat(odooName: 'usage_percentage') @Default(0) double usagePercentage,
    @OdooInteger(odooName: 'days_to_expire') int? daysToExpire,
    @OdooBoolean(odooName: 'is_expired') @Default(false) bool isExpired,
    @OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,
    @OdooMany2One('sale.order', odooName: 'sale_order_id') int? saleOrderId,
    @OdooLocalOnly() @Default([]) List<AdvanceLine> lines,
  }) = _Advance;

  factory Advance.fromJson(Map<String, dynamic> json) =>
      _$AdvanceFromJson(json);

  // ═══════════════════ Factory Methods ═══════════════════

  /// Crear nuevo anticipo con UUID generado
  factory Advance.create({
    required DateTime date,
    DateTime? dateEstimated,
    DateTime? dateDue,
    AdvanceState state = AdvanceState.draft,
    required AdvanceType advanceType,
    required int partnerId,
    String? partnerName,
    required String reference,
    double amount = 0,
    int? collectionSessionId,
    int? saleOrderId,
    List<AdvanceLine> lines = const [],
  }) {
    return Advance(
      advanceUuid: const Uuid().v4(),
      date: date,
      dateEstimated: dateEstimated,
      dateDue: dateDue,
      state: state,
      advanceType: advanceType,
      partnerId: partnerId,
      partnerName: partnerName,
      reference: reference,
      amount: amount,
      collectionSessionId: collectionSessionId,
      saleOrderId: saleOrderId,
      lines: lines,
    );
  }

  // ═══════════════════ Computed Properties ═══════════════════

  /// Indica si el anticipo esta en borrador
  bool get isDraft => state == AdvanceState.draft;

  /// Indica si el anticipo esta publicado
  bool get isPosted => state == AdvanceState.posted;

  /// Indica si el anticipo esta en uso
  bool get isInUse => state == AdvanceState.inUse;

  /// Indica si el anticipo esta usado completamente
  bool get isUsed => state == AdvanceState.used;

  /// Indica si el anticipo se puede confirmar
  bool get canPost => isDraft && lines.isNotEmpty;

  /// Indica si el anticipo se puede usar
  bool get canUse => isPosted && amountAvailable > 0 && !isExpired;

  /// Indica si el anticipo se puede devolver
  bool get canReturn => (isPosted || isInUse) && amountAvailable > 0;

  /// Total de lineas de pago
  double get totalLines => lines.fold(0.0, (sum, l) => sum + l.amount);

}

/// Linea de pago del anticipo.
@OdooModel('account.advance.line', tableName: 'advance_lines')
@freezed
abstract class AdvanceLine with _$AdvanceLine {
  const AdvanceLine._();

  const factory AdvanceLine({
    @OdooId() @Default(0) int id,
    @OdooLocalOnly() String? lineUuid,
    @OdooMany2One('account.journal', odooName: 'journal_id') required int journalId,
    @OdooMany2OneName(sourceField: 'journal_id') String? journalName,
    @OdooString(odooName: 'journal_type') String? journalType,
    @OdooMany2One('account.advance.method.line', odooName: 'advance_method_line_id') int? advanceMethodLineId,
    @OdooMany2OneName(sourceField: 'advance_method_line_id') String? advanceMethodName,
    @OdooFloat() required double amount,
    @OdooString(odooName: 'nro_document') String? documentNumber,
    @OdooDate(odooName: 'date_document') DateTime? documentDate,
    @OdooMany2One('res.partner.bank', odooName: 'partner_bank_id') int? partnerBankId,
    @OdooMany2OneName(sourceField: 'partner_bank_id') String? partnerBankName,
    @OdooDate(odooName: 'check_due_date') DateTime? checkDueDate,
    @OdooMany2One('card.brand', odooName: 'card_brand_id') int? cardBrandId,
    @OdooMany2OneName(sourceField: 'card_brand_id') String? cardBrandName,
    @OdooMany2One('card.deadline', odooName: 'card_deadline_id') int? cardDeadlineId,
    @OdooMany2OneName(sourceField: 'card_deadline_id') String? cardDeadlineName,
  }) = _AdvanceLine;

  factory AdvanceLine.fromJson(Map<String, dynamic> json) =>
      _$AdvanceLineFromJson(json);

  // ═══════════════════ Factory Methods ═══════════════════

  /// Crear nueva linea con UUID generado
  factory AdvanceLine.create({
    required int journalId,
    String? journalName,
    String? journalType,
    int? advanceMethodLineId,
    String? advanceMethodName,
    required double amount,
    String? documentNumber,
    DateTime? documentDate,
    int? partnerBankId,
    String? partnerBankName,
    DateTime? checkDueDate,
    int? cardBrandId,
    String? cardBrandName,
    int? cardDeadlineId,
    String? cardDeadlineName,
  }) {
    return AdvanceLine(
      lineUuid: const Uuid().v4(),
      journalId: journalId,
      journalName: journalName,
      journalType: journalType,
      advanceMethodLineId: advanceMethodLineId,
      advanceMethodName: advanceMethodName,
      amount: amount,
      documentNumber: documentNumber,
      documentDate: documentDate,
      partnerBankId: partnerBankId,
      partnerBankName: partnerBankName,
      checkDueDate: checkDueDate,
      cardBrandId: cardBrandId,
      cardBrandName: cardBrandName,
      cardDeadlineId: cardDeadlineId,
      cardDeadlineName: cardDeadlineName,
    );
  }

  // ═══════════════════ Computed Properties ═══════════════════

  /// Descripcion de la linea
  String get description {
    final parts = <String>[];
    if (journalName != null) parts.add(journalName!);
    if (cardBrandName != null) parts.add(cardBrandName!);
    if (documentNumber != null) parts.add('#$documentNumber');
    return parts.isNotEmpty ? parts.join(' - ') : 'Pago';
  }

  /// Indica si es pago en efectivo
  bool get isCash => journalType == 'cash';

  /// Indica si es pago con tarjeta
  bool get isCard => journalType == 'credit' || cardBrandId != null;

  /// Indica si es cheque
  bool get isCheck => checkDueDate != null;

  /// Indica si es transferencia
  bool get isTransfer => partnerBankId != null;
}
