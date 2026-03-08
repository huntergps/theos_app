import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:uuid/uuid.dart';

part 'cash_out.model.freezed.dart';
part 'cash_out.model.g.dart';

/// Estado del retiro de dinero
enum CashOutState {
  @JsonValue('draft')
  draft('draft', 'Borrador'),
  @JsonValue('posted')
  posted('posted', 'Publicado'),
  @JsonValue('cancelled')
  cancelled('cancelled', 'Cancelado');

  final String code;
  final String label;

  const CashOutState(this.code, this.label);

  static CashOutState fromCode(String? code) {
    if (code == null) return CashOutState.draft;
    // Handle both 'cancel' and 'cancelled'
    if (code == 'cancel') return CashOutState.cancelled;
    return CashOutState.values.firstWhere(
      (e) => e.code == code,
      orElse: () => CashOutState.draft,
    );
  }
}

/// Flujo del movimiento de dinero
enum CashFlow {
  @JsonValue('out')
  out('out', 'Salida'),
  @JsonValue('in')
  inFlow('in', 'Entrada');

  final String code;
  final String label;

  const CashFlow(this.code, this.label);

  static CashFlow fromCode(String? code) {
    if (code == null) return CashFlow.out;
    return CashFlow.values.firstWhere(
      (e) => e.code == code,
      orElse: () => CashFlow.out,
    );
  }
}

/// Tipo de retiro de dinero
///
/// Define el proposito del retiro y determina que campos adicionales
/// son requeridos.
class CashOutType {
  final int id;
  final String name;
  final String code;
  final CashFlow defaultCashFlow;
  final bool requiresPartner;
  final bool requiresLines;
  final bool createsSecurity;

  const CashOutType({
    required this.id,
    required this.name,
    required this.code,
    this.defaultCashFlow = CashFlow.out,
    this.requiresPartner = false,
    this.requiresLines = false,
    this.createsSecurity = false,
  });

  /// Tipos predefinidos
  static const expense = CashOutType(
    id: 0,
    name: 'Gasto',
    code: 'expense',
  );

  static const withhold = CashOutType(
    id: 0,
    name: 'Retencion',
    code: 'withhold',
    requiresPartner: true,
    requiresLines: true,
  );

  static const refund = CashOutType(
    id: 0,
    name: 'Nota de Credito',
    code: 'refund',
    requiresPartner: true,
    requiresLines: true,
  );

  static const commission = CashOutType(
    id: 0,
    name: 'Comision',
    code: 'commission',
  );

  static const invoice = CashOutType(
    id: 0,
    name: 'Factura',
    code: 'invoice',
    requiresPartner: true,
    requiresLines: true,
  );

  static const general = CashOutType(
    id: 0,
    name: 'General',
    code: 'general',
  );

  static const security = CashOutType(
    id: 0,
    name: 'Retiro de Seguridad',
    code: 'security',
    createsSecurity: true,
  );

  static const other = CashOutType(
    id: 0,
    name: 'Otro',
    code: 'other',
  );

  /// Todos los tipos predefinidos
  static const List<CashOutType> predefined = [
    expense,
    withhold,
    refund,
    commission,
    invoice,
    general,
    security,
    other,
  ];

  /// Obtener tipo por codigo
  static CashOutType fromCode(String? code) {
    if (code == null || code.isEmpty) return other;
    return predefined.firstWhere(
      (t) => t.code == code,
      orElse: () => CashOutType(id: 0, name: code, code: code),
    );
  }

  factory CashOutType.fromOdoo(Map<String, dynamic> data) {
    final code = data['code'] as String? ?? '';
    return CashOutType(
      id: data['id'] as int,
      name: data['name'] as String,
      code: code,
      defaultCashFlow: CashFlow.fromCode(data['default_cash_flow'] as String?),
      requiresPartner:
          code == 'withhold' || code == 'refund' || code == 'invoice',
      requiresLines:
          code == 'withhold' || code == 'refund' || code == 'invoice',
      createsSecurity: code == 'security',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
      };

  @override
  String toString() => 'CashOutType($code: $name)';
}

/// Modelo de retiro de dinero migrated to @OdooModel annotation pattern.
///
/// ## Computed fields (equivalent to @api.depends in Odoo)
///
/// - [isPosted] / [isCancelled] / [isDraft] / [canEdit] / [canPost] / [canCancel] -> depends: [state]
/// - [isOutflow] / [isInflow] -> depends: [cashFlow]
/// - [hasMove] -> depends: [moveId]
/// - [type] -> depends: [typeId, typeName, typeCode]
@OdooModel('l10n_ec_collection_box.cash_out', tableName: 'cash_out')
@freezed
abstract class CashOut with _$CashOut {
  const CashOut._();

  // ═══════════════════ Validation ═══════════════════

  /// Validates the cash out before saving.
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (amount <= 0) {
      errors['amount'] = 'El monto debe ser mayor a cero';
    }
    if (journalId <= 0) {
      errors['journal'] = 'El diario es requerido';
    }
    return errors;
  }

  /// Validates for specific actions.
  Map<String, String> validateFor(String action) {
    final errors = validate();
    switch (action) {
      case 'post':
        if (!canPost) {
          errors['state'] = 'No se puede confirmar el retiro en estado: ${state.label}';
        }
        // Validaciones especificas por tipo
        if (type.requiresPartner && (partnerId == null || partnerId == 0)) {
          errors['partnerId'] = 'El cliente/proveedor es requerido para este tipo de retiro';
        }
        break;

      case 'cancel':
        if (!canCancel) {
          errors['state'] = 'No se puede cancelar el retiro en estado: ${state.label}';
        }
        break;

      case 'draft':
        if (!isCancelled) {
          errors['state'] = 'Solo se puede pasar a borrador desde cancelado';
        }
        break;
    }
    return errors;
  }

  const factory CashOut({
    // ============ Identifiers ============
    @OdooId() @Default(0) int id,
    @OdooLocalOnly() String? uuid,
    @OdooLocalOnly() @Default(false) bool isSynced,
    @OdooLocalOnly() DateTime? lastSyncDate,

    // ============ Basic Data ============
    @OdooString() String? name,
    @OdooDate() required DateTime date,
    @OdooSelection() @Default(CashOutState.draft) CashOutState state,
    @OdooSelection(odooName: 'cash_flow') @Default(CashFlow.out) CashFlow cashFlow,

    // ============ Relations ============
    @OdooMany2One('account.journal', odooName: 'journal_id') required int journalId,
    @OdooMany2OneName(sourceField: 'journal_id') String? journalName,
    @OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,
    @OdooMany2OneName(sourceField: 'partner_id') String? partnerName,
    @OdooMany2One('account.account', odooName: 'account_id_manual') int? accountIdManual,
    @OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,
    @OdooMany2One('account.move', odooName: 'move_id') int? moveId,

    // ============ Amount ============
    @OdooFloat() @Default(0.0) double amount,

    // ============ Notes ============
    @OdooString() String? note,

    // ============ Type Info ============
    @OdooSelection(odooName: 'cash_out_type') @Default('other') String typeCode,
    @OdooMany2One('l10n_ec_collection_box.cash_out_type', odooName: 'cash_out_type_id') int? typeId,
    @OdooMany2OneName(sourceField: 'cash_out_type_id') String? typeName,
  }) = _CashOut;

  factory CashOut.fromJson(Map<String, dynamic> json) => _$CashOutFromJson(json);

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPUTED FIELDS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Tipo completo (computed)
  CashOutType get type {
    if (typeId != null && typeId! > 0) {
      return CashOutType(
        id: typeId!,
        name: typeName ?? typeCode,
        code: typeCode,
      );
    }
    return CashOutType.fromCode(typeCode);
  }

  /// Indica si el retiro esta confirmado
  bool get isPosted => state == CashOutState.posted;

  /// Indica si el retiro esta cancelado
  bool get isCancelled => state == CashOutState.cancelled;

  /// Indica si el retiro esta en borrador
  bool get isDraft => state == CashOutState.draft;

  /// Indica si se puede editar
  bool get canEdit => state == CashOutState.draft;

  /// Indica si se puede confirmar
  bool get canPost => isDraft && amount > 0 && journalId > 0;

  /// Indica si se puede cancelar
  bool get canCancel => isPosted;

  /// Indica si es una salida de efectivo
  bool get isOutflow => cashFlow == CashFlow.out;

  /// Indica si es una entrada de efectivo
  bool get isInflow => cashFlow == CashFlow.inFlow;

  /// Indica si tiene asiento contable
  bool get hasMove => moveId != null && moveId! > 0;

  // ═══════════════════════════════════════════════════════════════════════════
  // ONCHANGE SIMULATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Simula onchange de type.
  CashOut onTypeChanged(CashOutType newType) {
    return copyWith(
      typeCode: newType.code,
      typeId: newType.id,
      typeName: newType.name,
      cashFlow: newType.defaultCashFlow,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crear para uso local (nuevo)
  static CashOut createLocal({
    required DateTime date,
    required int journalId,
    required double amount,
    required CashOutType type,
    String? journalName,
    int? partnerId,
    String? partnerName,
    String? note,
    int? collectionSessionId,
  }) {
    return CashOut(
      date: date,
      journalId: journalId,
      amount: amount,
      journalName: journalName,
      partnerId: partnerId,
      partnerName: partnerName,
      note: note,
      collectionSessionId: collectionSessionId,
      typeCode: type.code,
      typeId: type.id,
      typeName: type.name,
      uuid: const Uuid().v4(),
      isSynced: false,
    );
  }
}

/// Linea de retiro de dinero
class CashOutLine {
  final String uuid;
  final int? id;
  final int documentId;
  final String? documentName;
  final double reconcileAmount;
  final double? amountAvailable;

  CashOutLine({
    String? uuid,
    this.id,
    required this.documentId,
    this.documentName,
    required this.reconcileAmount,
    this.amountAvailable,
  }) : uuid = uuid ?? const Uuid().v4();

  CashOutLine copyWith({
    String? uuid,
    int? id,
    int? documentId,
    String? documentName,
    double? reconcileAmount,
    double? amountAvailable,
  }) {
    return CashOutLine(
      uuid: uuid ?? this.uuid,
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      documentName: documentName ?? this.documentName,
      reconcileAmount: reconcileAmount ?? this.reconcileAmount,
      amountAvailable: amountAvailable ?? this.amountAvailable,
    );
  }

  Map<String, dynamic> toOdooValues() {
    return {
      'reconcile_amount': reconcileAmount,
    };
  }

  factory CashOutLine.fromOdoo(
      Map<String, dynamic> data, String documentField) {
    final docData = data[documentField];
    int documentId;
    String? documentName;
    if (docData is List && docData.length >= 2) {
      documentId = docData[0] as int;
      documentName = docData[1] as String;
    } else {
      documentId = docData as int? ?? 0;
    }

    return CashOutLine(
      id: data['id'] as int?,
      documentId: documentId,
      documentName: documentName,
      reconcileAmount: (data['reconcile_amount'] as num?)?.toDouble() ?? 0,
      amountAvailable: (data['amount_available'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() => 'CashOutLine($documentName, \$$reconcileAmount)';
}

/// Retencion pendiente para devolucion
class PendingWithhold {
  final int id;
  final String name;
  final double amountPending;
  final DateTime date;
  final int partnerId;
  final String? partnerName;

  PendingWithhold({
    required this.id,
    required this.name,
    required this.amountPending,
    required this.date,
    required this.partnerId,
    this.partnerName,
  });

  factory PendingWithhold.fromOdoo(Map<String, dynamic> data) {
    final partnerData = data['partner_id'];
    int partnerId;
    String? partnerName;
    if (partnerData is List && partnerData.length >= 2) {
      partnerId = partnerData[0] as int;
      partnerName = partnerData[1] as String;
    } else {
      partnerId = data['partner_id'] as int? ?? 0;
    }

    return PendingWithhold(
      id: data['id'] as int,
      name: data['name'] as String,
      amountPending: (data['amount_residual'] as num?)?.toDouble() ?? 0,
      date: DateTime.parse(data['date'] as String),
      partnerId: partnerId,
      partnerName: partnerName,
    );
  }
}

/// Nota de credito pendiente para devolucion
class PendingCreditNote {
  final int id;
  final String name;
  final double amountResidual;
  final DateTime? invoiceDate;
  final int partnerId;
  final String? partnerName;

  PendingCreditNote({
    required this.id,
    required this.name,
    required this.amountResidual,
    this.invoiceDate,
    required this.partnerId,
    this.partnerName,
  });

  factory PendingCreditNote.fromOdoo(Map<String, dynamic> data) {
    final partnerData = data['partner_id'];
    int partnerId;
    String? partnerName;
    if (partnerData is List && partnerData.length >= 2) {
      partnerId = partnerData[0] as int;
      partnerName = partnerData[1] as String;
    } else {
      partnerId = data['partner_id'] as int? ?? 0;
    }

    return PendingCreditNote(
      id: data['id'] as int,
      name: data['name'] as String,
      amountResidual: (data['amount_residual'] as num?)?.toDouble() ?? 0,
      invoiceDate: data['invoice_date'] != null
          ? DateTime.parse(data['invoice_date'] as String)
          : null,
      partnerId: partnerId,
      partnerName: partnerName,
    );
  }
}

/// Factura pendiente de pago
class PendingInvoice {
  final int id;
  final String name;
  final double amountResidual;
  final DateTime? invoiceDate;
  final DateTime? invoiceDateDue;
  final int partnerId;
  final String? partnerName;

  PendingInvoice({
    required this.id,
    required this.name,
    required this.amountResidual,
    this.invoiceDate,
    this.invoiceDateDue,
    required this.partnerId,
    this.partnerName,
  });

  factory PendingInvoice.fromOdoo(Map<String, dynamic> data) {
    final partnerData = data['partner_id'];
    int partnerId;
    String? partnerName;
    if (partnerData is List && partnerData.length >= 2) {
      partnerId = partnerData[0] as int;
      partnerName = partnerData[1] as String;
    } else {
      partnerId = data['partner_id'] as int? ?? 0;
    }

    return PendingInvoice(
      id: data['id'] as int,
      name: data['name'] as String,
      amountResidual: (data['amount_residual'] as num?)?.toDouble() ?? 0,
      invoiceDate: data['invoice_date'] != null
          ? DateTime.parse(data['invoice_date'] as String)
          : null,
      invoiceDateDue: data['invoice_date_due'] != null
          ? DateTime.parse(data['invoice_date_due'] as String)
          : null,
      partnerId: partnerId,
      partnerName: partnerName,
    );
  }
}
