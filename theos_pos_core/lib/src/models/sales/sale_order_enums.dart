import 'package:freezed_annotation/freezed_annotation.dart';

/// Estado de la orden de venta
///
/// Estados según Odoo Ecuador (l10n_ec):
/// - draft: Cotización inicial
/// - sent: Cotización enviada al cliente
/// - waiting: Esperando aprobación de crédito (l10n_ec_sale_credit)
/// - approved: Aprobada por gerente (l10n_ec_base)
/// - rejected: Rechazada por gerente (l10n_ec_base)
/// - sale: Orden de venta confirmada
/// - cancel: Cancelada
///
/// Nota: Odoo no tiene estado 'done'. Usa el campo `locked` (boolean)
/// para bloquear órdenes completadas.
enum SaleOrderState {
  @JsonValue('draft')
  draft('draft'),
  @JsonValue('sent')
  sent('sent'),
  @JsonValue('waiting_approval')
  waitingApproval('waiting'),
  @JsonValue('approved')
  approved('approved'),
  @JsonValue('rejected')
  rejected('rejected'),
  @JsonValue('sale')
  sale('sale'),
  @JsonValue('done')
  done('done'),
  @JsonValue('cancel')
  cancel('cancel');

  final String code;
  const SaleOrderState(this.code);
}

/// Estado de facturación
enum InvoiceStatus {
  @JsonValue('no')
  no('no'),
  @JsonValue('to invoice')
  toInvoice('to invoice'),
  @JsonValue('invoiced')
  invoiced('invoiced'),
  @JsonValue('upselling')
  upselling('upselling');

  final String code;
  const InvoiceStatus(this.code);
}

/// Extension to convert SaleOrderState to/from Odoo string values
extension SaleOrderStateExtension on SaleOrderState {
  /// Human-readable label for UI display
  String get label {
    switch (this) {
      case SaleOrderState.draft:
        return 'Cotización';
      case SaleOrderState.sent:
        return 'Enviado';
      case SaleOrderState.waitingApproval:
        return 'Esperando aprobación';
      case SaleOrderState.approved:
        return 'Aprobado';
      case SaleOrderState.rejected:
        return 'Rechazado';
      case SaleOrderState.sale:
        return 'Orden de venta';
      case SaleOrderState.done:
        return 'Completado';
      case SaleOrderState.cancel:
        return 'Cancelado';
    }
  }

  /// Convert to Odoo string value
  String toOdooString() {
    switch (this) {
      case SaleOrderState.draft:
        return 'draft';
      case SaleOrderState.sent:
        return 'sent';
      case SaleOrderState.waitingApproval:
        return 'waiting'; // Odoo uses 'waiting' not 'waiting_approval'
      case SaleOrderState.approved:
        return 'approved';
      case SaleOrderState.rejected:
        return 'rejected';
      case SaleOrderState.sale:
        return 'sale';
      case SaleOrderState.done:
        return 'done';
      case SaleOrderState.cancel:
        return 'cancel';
    }
  }

  /// Parse from Odoo string value
  static SaleOrderState fromString(dynamic value) {
    if (value == null || value == false) return SaleOrderState.draft;
    final strValue = (value is String ? value : value.toString()).toLowerCase();
    switch (strValue) {
      case 'draft':
      case 'cotización':
      case 'cotizacion':
        return SaleOrderState.draft;
      case 'sent':
      case 'enviado':
        return SaleOrderState.sent;
      case 'waiting':
      case 'waiting_approval':
      case 'esperando aprobación':
      case 'esperando aprobacion':
      case 'espera aprobación':
      case 'espera aprobacion':
        return SaleOrderState.waitingApproval;
      case 'approved':
      case 'aprobado':
        return SaleOrderState.approved;
      case 'rejected':
      case 'rechazado':
        return SaleOrderState.rejected;
      case 'sale':
      case 'orden de venta':
        return SaleOrderState.sale;
      case 'done':
      case 'completado':
        return SaleOrderState.done;
      case 'cancel':
      case 'cancelado':
        return SaleOrderState.cancel;
      default:
        // Try to match by enum name if it's a simple case mismatch
        for (final state in SaleOrderState.values) {
          if (state.name.toLowerCase() == strValue) {
            return state;
          }
        }
        return SaleOrderState.draft;
    }
  }
}

/// Extension to convert InvoiceStatus to/from Odoo string values
extension InvoiceStatusExtension on InvoiceStatus {
  /// Human-readable label for UI display
  String get label {
    switch (this) {
      case InvoiceStatus.no:
        return 'Sin facturar';
      case InvoiceStatus.toInvoice:
        return 'Por facturar';
      case InvoiceStatus.invoiced:
        return 'Facturado';
      case InvoiceStatus.upselling:
        return 'Upselling';
    }
  }

  /// Convert to Odoo string value
  String toOdooString() {
    switch (this) {
      case InvoiceStatus.no:
        return 'no';
      case InvoiceStatus.toInvoice:
        return 'to invoice';
      case InvoiceStatus.invoiced:
        return 'invoiced';
      case InvoiceStatus.upselling:
        return 'upselling';
    }
  }

  /// Parse from Odoo string value
  static InvoiceStatus fromString(dynamic value) {
    if (value == null || value == false) return InvoiceStatus.no;
    final strValue = value is String ? value : value.toString();
    switch (strValue) {
      case 'no':
        return InvoiceStatus.no;
      case 'to invoice':
        return InvoiceStatus.toInvoice;
      case 'invoiced':
        return InvoiceStatus.invoiced;
      case 'upselling':
        return InvoiceStatus.upselling;
      default:
        return InvoiceStatus.no;
    }
  }
}
