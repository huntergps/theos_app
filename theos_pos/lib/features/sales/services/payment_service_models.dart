import 'dart:convert';

import 'package:odoo_sdk/odoo_sdk.dart' as odoo;
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

/// Modelos/DTOs y utilidades compartidas por [PaymentService] y los
/// sub-servicios en los que se descompuso (`JournalPaymentMethodService`,
/// `CardPaymentSyncService`, `PaymentLinePersistenceService`,
/// `CreditWithholdingService`, `PaymentValidationService`).
///
/// Extraído tal cual de `payment_service.dart` como parte de la
/// descomposición sin cambio de comportamiento (Fase E2).

// ============================================================
// UTILIDADES COMPARTIDAS
// ============================================================

/// Helper para decodificar lista de IDs
/// Soporta tanto JSON array "[1,2,3]" como texto separado por comas "1,2,3"
///
/// Usado por [JournalPaymentMethodService] y [CardPaymentSyncService] —
/// extraído como función pura compartida (antes duplicado como método
/// privado `_decodeIntList` en `PaymentService`).
List<int> decodeCsvIntList(String? str) {
  if (str == null || str.isEmpty || str == '[]') return [];

  // Si es JSON array, decodificar
  if (str.startsWith('[')) {
    try {
      final list = jsonDecode(str);
      if (list is List) {
        return list.cast<int>();
      }
    } catch (e) {
      logger.w('[PaymentService]', 'Error decoding JSON int list: $e');
    }
  }

  // Si es texto separado por comas, parsear
  return str
      .split(',')
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .toList();
}

// ============================================================
// MODELOS ADICIONALES
// ============================================================

/// Información de crédito del cliente
class PartnerCreditInfo {
  final double creditLimit;
  final double creditUsed;
  final double creditToInvoice;
  final double totalOverdue;
  final int unpaidInvoicesCount;
  final double creditAvailable;
  final bool allowOverCredit;

  PartnerCreditInfo({
    required this.creditLimit,
    required this.creditUsed,
    required this.creditToInvoice,
    required this.totalOverdue,
    required this.unpaidInvoicesCount,
    required this.creditAvailable,
    required this.allowOverCredit,
  });

  /// Indica si el cliente tiene crédito habilitado
  bool get hasCreditLimit => creditLimit > 0;

  /// Indica si el crédito está excedido
  bool get isCreditExceeded => creditAvailable < 0;

  /// Indica si tiene deuda vencida
  bool get hasOverdueDebt => totalOverdue > 0;

  /// Porcentaje de uso del crédito
  double get creditUsagePercentage {
    if (creditLimit <= 0) return 0;
    return ((creditUsed + creditToInvoice) / creditLimit * 100).clamp(0, 999);
  }
}

/// Tipo de retención disponible
class WithholdingType {
  final int id;
  final String name;
  final double percentage;
  final String code;

  WithholdingType({
    required this.id,
    required this.name,
    required this.percentage,
    required this.code,
  });

  /// Descripción formateada
  String get displayName => '$name ($percentage%)';
}

/// Línea de retención para registrar
class WithholdingLine {
  final int taxId;
  final double base;
  final double amount;

  WithholdingLine({
    required this.taxId,
    required this.base,
    required this.amount,
  });
}

/// Resultado del registro de retención
class WithholdingResult {
  final bool success;
  final int? withholdId;
  final String? withholdName;
  final double totalWithheld;
  final String? errorMessage;

  WithholdingResult({
    required this.success,
    this.withholdId,
    this.withholdName,
    this.totalWithheld = 0,
    this.errorMessage,
  });
}

/// Tipo de autorización de crédito
enum CreditAuthorizationType {
  overdueDebt,
  creditLimitExceeded,
  temporaryCredit,
}

/// Resultado de solicitud de aprobación de crédito
class CreditApprovalResult {
  final bool success;
  final int? approvalId;
  final String? approvalName;
  final String? errorMessage;

  CreditApprovalResult({
    required this.success,
    this.approvalId,
    this.approvalName,
    this.errorMessage,
  });
}

// ============================================================
// MODELO DE COBRO DE SESIÓN
// ============================================================

/// Estado del pago
enum PaymentState {
  draft,
  posted,
  canceled,
  rejected;

  String get label {
    switch (this) {
      case PaymentState.draft:
        return 'Borrador';
      case PaymentState.posted:
        return 'Publicado';
      case PaymentState.canceled:
        return 'Cancelado';
      case PaymentState.rejected:
        return 'Rechazado';
    }
  }

  static PaymentState fromString(String? value) {
    switch (value) {
      case 'posted':
        return PaymentState.posted;
      case 'canceled':
        return PaymentState.canceled;
      case 'rejected':
        return PaymentState.rejected;
      default:
        return PaymentState.draft;
    }
  }
}

/// Tipo de origen del pago
enum PaymentOriginType {
  invoiceDay,
  debt,
  advance;

  String get label {
    switch (this) {
      case PaymentOriginType.invoiceDay:
        return 'Factura del día';
      case PaymentOriginType.debt:
        return 'Deuda';
      case PaymentOriginType.advance:
        return 'Anticipo';
    }
  }

  static PaymentOriginType? fromString(String? value) {
    switch (value) {
      case 'invoice_day':
        return PaymentOriginType.invoiceDay;
      case 'debt':
        return PaymentOriginType.debt;
      case 'advance':
        return PaymentOriginType.advance;
      default:
        return null;
    }
  }
}

/// Categoría del método de pago
enum PaymentMethodCategory {
  cash,
  cardCredit,
  cardDebit,
  cheque,
  transfer,
  other;

  String get label {
    switch (this) {
      case PaymentMethodCategory.cash:
        return 'Efectivo';
      case PaymentMethodCategory.cardCredit:
        return 'Tarjeta Crédito';
      case PaymentMethodCategory.cardDebit:
        return 'Tarjeta Débito';
      case PaymentMethodCategory.cheque:
        return 'Cheque';
      case PaymentMethodCategory.transfer:
        return 'Transferencia';
      case PaymentMethodCategory.other:
        return 'Otro';
    }
  }

  static PaymentMethodCategory fromString(String? value) {
    switch (value) {
      case 'cash':
        return PaymentMethodCategory.cash;
      case 'card_credit':
        return PaymentMethodCategory.cardCredit;
      case 'card_debit':
        return PaymentMethodCategory.cardDebit;
      case 'cheque':
        return PaymentMethodCategory.cheque;
      case 'transfer':
        return PaymentMethodCategory.transfer;
      default:
        return PaymentMethodCategory.other;
    }
  }
}

/// Cobro de sesión para visualización en collection
class SessionPayment {
  final int id;
  final String? name;
  final int? partnerId;
  final String? partnerName;
  final int? journalId;
  final String? journalName;
  final int? paymentMethodLineId;
  final String? paymentMethodLineName;
  final double amount;
  final String paymentType;
  final PaymentState state;
  final DateTime? date;
  final String? ref;
  final PaymentOriginType? originType;
  final PaymentMethodCategory methodCategory;
  final List<int>? invoiceIds;
  final int? moveId;
  final int? collectionSessionId;

  SessionPayment({
    required this.id,
    this.name,
    this.partnerId,
    this.partnerName,
    this.journalId,
    this.journalName,
    this.paymentMethodLineId,
    this.paymentMethodLineName,
    required this.amount,
    required this.paymentType,
    required this.state,
    this.date,
    this.ref,
    this.originType,
    required this.methodCategory,
    this.invoiceIds,
    this.moveId,
    this.collectionSessionId,
  });

  factory SessionPayment.fromOdoo(Map<String, dynamic> data) {
    return SessionPayment(
      id: data['id'] as int,
      name: data['name'] as String?,
      partnerId: odoo.extractMany2oneId(data['partner_id']),
      partnerName: odoo.extractMany2oneName(data['partner_id']),
      journalId: odoo.extractMany2oneId(data['journal_id']),
      journalName: odoo.extractMany2oneName(data['journal_id']),
      paymentMethodLineId: odoo.extractMany2oneId(
        data['payment_method_line_id'],
      ),
      paymentMethodLineName: odoo.extractMany2oneName(
        data['payment_method_line_id'],
      ),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentType: data['payment_type'] as String? ?? 'inbound',
      state: PaymentState.fromString(data['state'] as String?),
      date: odoo.parseOdooDateTime(data['date']),
      ref: data['ref'] as String?,
      originType: PaymentOriginType.fromString(
        data['payment_origin_type'] as String?,
      ),
      methodCategory: PaymentMethodCategory.fromString(
        data['payment_method_category'] as String?,
      ),
      invoiceIds: (data['reconciled_invoice_ids'] as List<dynamic>?)
          ?.cast<int>(),
      moveId: odoo.extractMany2oneId(data['move_id']),
      collectionSessionId: odoo.extractMany2oneId(
        data['collection_session_id'],
      ),
    );
  }

  /// Indica si es un cobro entrante (del cliente)
  bool get isInbound => paymentType == 'inbound';

  /// Indica si es un pago saliente (al proveedor)
  bool get isOutbound => paymentType == 'outbound';

  /// Indica si está publicado
  bool get isPosted => state == PaymentState.posted;

  /// Indica si está cancelado
  bool get isCanceled => state == PaymentState.canceled;
}
