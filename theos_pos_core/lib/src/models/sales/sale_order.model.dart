import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import '../../models/clients/client.model.dart';
import '../../models/payment_terms/payment_term.model.dart';
import '../../models/prices/pricelist.model.dart';
import '../../models/taxes/fiscal_position.model.dart';
import '../../models/users/user.model.dart';
import '../../models/warehouses/warehouse.model.dart';
import 'sale_order_enums.dart';
import 'sale_order_line.model.dart';

// Re-export enums for backwards compatibility
export 'sale_order_enums.dart';

part 'sale_order.model.freezed.dart';
part 'sale_order.model.g.dart';

/// Sale Order model using OdooModelManager annotations
///
/// Implements SmartOdooModel for:
/// - Integrated CRUD operations (save(), delete(), refresh())
/// - Reactive bindings via manager.watch()
/// - Validation framework with validateFor('confirm')
/// - Odoo action calls with callActionAndRefresh()
/// - State machine transitions (draft -> sent -> sale -> done/cancel)
/// - Computed fields that depend on orderLines
///
/// ## State Machine (OdooStateMachine equivalent)
///
/// Valid transitions:
/// - draft -> sent, cancel
/// - sent -> sale, draft, cancel
/// - sale -> done, cancel (if not locked)
/// - done -> (terminal)
/// - cancel -> draft
///
/// ## Computed Fields (equivalent to @api.depends)
///
/// - amountUntaxed: sum of orderLines.priceSubtotal
/// - amountTax: sum of orderLines.priceTax
/// - amountTotal: amountUntaxed + amountTax
@OdooModel('sale.order', tableName: 'sale_order')
@freezed
abstract class SaleOrder with _$SaleOrder {
  const SaleOrder._();

  const factory SaleOrder({
    @OdooId() required int id,
    @OdooLocalOnly() String? orderUuid, // UUID local para sincronizacion offline-first
    @OdooString() required String name, // Referencia (SO001)
    @OdooSelection() required SaleOrderState state,

    // Fechas
    @OdooDateTime(odooName: 'date_order') DateTime? dateOrder,
    @OdooDate(odooName: 'validity_date') DateTime? validityDate,
    @OdooDateTime(odooName: 'commitment_date') DateTime? commitmentDate,
    @OdooDateTime(odooName: 'expected_date') DateTime? expectedDate,

    // Cliente y direcciones
    @OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,
    @OdooMany2OneName(sourceField: 'partner_id') String? partnerName,
    @OdooString(odooName: 'partner_vat') String? partnerVat,
    @OdooString(odooName: 'partner_street') String? partnerStreet,
    @OdooString(odooName: 'partner_phone') String? partnerPhone,
    @OdooString(odooName: 'partner_email') String? partnerEmail,
    @OdooString(odooName: 'partner_avatar') String? partnerAvatar,
    @OdooMany2One('res.partner', odooName: 'partner_invoice_id') int? partnerInvoiceId,
    @OdooMany2OneName(sourceField: 'partner_invoice_id') String? partnerInvoiceAddress,
    @OdooMany2One('res.partner', odooName: 'partner_shipping_id') int? partnerShippingId,
    @OdooMany2OneName(sourceField: 'partner_shipping_id') String? partnerShippingAddress,

    // Vendedor y equipo
    @OdooMany2One('res.users', odooName: 'user_id') int? userId,
    @OdooMany2OneName(sourceField: 'user_id') String? userName,
    @OdooMany2One('crm.team', odooName: 'team_id') int? teamId,
    @OdooMany2OneName(sourceField: 'team_id') String? teamName,

    // Compania
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,

    // Almacen (sale_stock)
    @OdooMany2One('stock.warehouse', odooName: 'warehouse_id') int? warehouseId,
    @OdooMany2OneName(sourceField: 'warehouse_id') String? warehouseName,

    // Lista de precios y moneda
    @OdooMany2One('product.pricelist', odooName: 'pricelist_id') int? pricelistId,
    @OdooMany2OneName(sourceField: 'pricelist_id') String? pricelistName,
    @OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,
    @OdooString(odooName: 'currency_symbol') String? currencySymbol,
    @OdooFloat(odooName: 'currency_rate') @Default(1.0) double currencyRate,

    // Condiciones comerciales
    @OdooMany2One('account.payment.term', odooName: 'payment_term_id') int? paymentTermId,
    @OdooMany2OneName(sourceField: 'payment_term_id') String? paymentTermName,

    // Payment type (synced from Odoo: payment_term_id.is_cash / is_credit)
    /// True if payment term is cash/immediate payment
    @OdooBoolean(odooName: 'is_cash') @Default(true) bool isCash,

    /// True if payment term is credit (has payment days > 0)
    @OdooBoolean(odooName: 'is_credit') @Default(false) bool isCredit,

    @OdooMany2One('account.fiscal.position', odooName: 'fiscal_position_id') int? fiscalPositionId,
    @OdooMany2OneName(sourceField: 'fiscal_position_id') String? fiscalPositionName,

    // Montos
    @OdooFloat(odooName: 'amount_untaxed') @Default(0.0) double amountUntaxed,
    @OdooFloat(odooName: 'amount_tax') @Default(0.0) double amountTax,
    @OdooFloat(odooName: 'amount_total') @Default(0.0) double amountTotal,
    @OdooFloat(odooName: 'amount_to_invoice') @Default(0.0) double amountToInvoice,
    @OdooFloat(odooName: 'amount_invoiced') @Default(0.0) double amountInvoiced,

    // Estado de facturacion
    @OdooSelection(odooName: 'invoice_status') @Default(InvoiceStatus.no) InvoiceStatus invoiceStatus,
    @OdooInteger(odooName: 'invoice_count') @Default(0) int invoiceCount,

    // Notas y referencias
    @OdooString(odooName: 'note') String? note,
    @OdooString(odooName: 'client_order_ref') String? clientOrderRef,

    // Firma digital
    @OdooBoolean(odooName: 'require_signature') @Default(false) bool requireSignature,
    @OdooString(odooName: 'signature') String? signature,
    @OdooString(odooName: 'signed_by') String? signedBy,
    @OdooDateTime(odooName: 'signed_on') DateTime? signedOn,

    // Pago online
    @OdooBoolean(odooName: 'require_payment') @Default(false) bool requirePayment,
    @OdooFloat(odooName: 'prepayment_percent') @Default(0.0) double prepaymentPercent,

    // Control
    @OdooBoolean(odooName: 'locked') @Default(false) bool locked,
    @OdooBoolean(odooName: 'is_expired') @Default(false) bool isExpired,

    // Descuentos (l10n_ec_sale_discount)
    @OdooFloat(odooName: 'total_discount_amount') @Default(0.0) double totalDiscountAmount,
    @OdooFloat(odooName: 'total_amount_undiscounted') @Default(0.0) double amountUntaxedUndiscounted,

    // Consumidor Final (l10n_ec_sale_base)
    @OdooBoolean(odooName: 'is_final_consumer') @Default(false) bool isFinalConsumer,
    @OdooString(odooName: 'end_customer_name') String? endCustomerName,
    @OdooString(odooName: 'end_customer_phone') String? endCustomerPhone,
    @OdooString(odooName: 'end_customer_email') String? endCustomerEmail,
    @OdooBoolean(odooName: 'exceeds_final_consumer_limit') @Default(false) bool exceedsFinalConsumerLimit,

    // Facturacion postfechada (l10n_ec_sale_base)
    @OdooBoolean(odooName: 'emitir_factura_fecha_posterior') @Default(false) bool emitirFacturaFechaPosterior,
    @OdooDate(odooName: 'fecha_facturar') DateTime? fechaFacturar,

    // Referidor (l10n_ec_sale_base)
    @OdooMany2One('res.partner', odooName: 'referrer_id') int? referrerId,
    @OdooMany2OneName(sourceField: 'referrer_id') String? referrerName,

    // Tipo y Canal de cliente (l10n_ec_sale_base)
    @OdooString(odooName: 'tipo_cliente') String? tipoCliente,
    @OdooString(odooName: 'canal_cliente') String? canalCliente,

    // Entregas/Picking (sale_stock)
    @OdooMany2Many('stock.picking', odooName: 'picking_ids') @Default(<int>[]) List<int> pickingIds,
    @OdooString(odooName: 'delivery_status') String? deliveryStatus,

    // Tax totals JSON para desglose de impuestos
    @OdooJson(odooName: 'tax_totals') Map<String, dynamic>? taxTotals,

    // Credit Control (l10n_ec_sale_credit)
    @OdooBoolean(odooName: 'credit_exceeded') @Default(false) bool creditExceeded,
    @OdooBoolean(odooName: 'credit_check_bypassed') @Default(false) bool creditCheckBypassed,

    // Additional Amounts
    @OdooFloat(odooName: 'amount_cash') @Default(0.0) double amountCash,
    @OdooFloat(odooName: 'amount_unpaid') @Default(0.0) double amountUnpaid,
    @OdooFloat(odooName: 'total_cost_amount') @Default(0.0) double totalCostAmount,
    @OdooFloat(odooName: 'margin') @Default(0.0) double margin,
    @OdooFloat(odooName: 'margin_percent') @Default(0.0) double marginPercent,
    @OdooFloat(odooName: 'retenido_amount') @Default(0.0) double retenidoAmount,

    // Approvals (l10n_ec_sale_credit)
    @OdooInteger(odooName: 'approval_count') @Default(0) int approvalCount,
    @OdooDateTime(odooName: 'approved_date') DateTime? approvedDate,
    @OdooDateTime(odooName: 'rejected_date') DateTime? rejectedDate,
    @OdooString(odooName: 'rejected_reason') String? rejectedReason,

    // Collection Session (l10n_ec_collection_box)
    @OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,
    @OdooMany2One('res.users', odooName: 'collection_user_id') int? collectionUserId,
    @OdooMany2One('res.users', odooName: 'sale_created_user_id') int? saleCreatedUserId,

    // Dispatch Control (l10n_ec_sale_base)
    @OdooBoolean(odooName: 'entregar_solo_pagado') @Default(false) bool entregarSoloPagado,
    @OdooBoolean(odooName: 'es_para_despacho') @Default(false) bool esParaDespacho,
    @OdooString(odooName: 'nota_adicional') String? notaAdicional,

    // UUID for offline sync (l10n_ec_collection_box_pos)
    @OdooString(odooName: 'x_uuid') String? xUuid,

    // Sync
    @OdooLocalOnly() @Default(false) bool isSynced,
    @OdooLocalOnly() DateTime? lastSyncDate,
    @OdooLocalOnly() @Default(0) int syncRetryCount,
    @OdooLocalOnly() DateTime? lastSyncAttempt,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,

    /// Indicates invoice creation was queued offline - prevents modifying payments/withholds
    @OdooLocalOnly() @Default(false) bool hasQueuedInvoice,
  }) = _SaleOrder;

  factory SaleOrder.fromJson(Map<String, dynamic> json) =>
      _$SaleOrderFromJson(json);

  // ═══════════════════════════════════════════════════════════════════════════
  // OdooRecord Validation (equivalente a @api.constrains)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Validates order before saving.
  ///
  /// Returns map of field -> error message. Empty if valid.
  /// Used by OdooRecord.save() to prevent invalid data.
  ///
  /// Equivalente a @api.constrains en Odoo Python:
  /// ```python
  /// @api.constrains('partner_id', 'order_line')
  /// def _check_required_fields(self):
  ///     ...
  /// ```
  Map<String, String> validate() {
    final errors = <String, String>{};

    // --- Constraint: Partner required ---
    if (partnerId == null || partnerId == 0) {
      errors['partner_id'] = 'El cliente es requerido';
    }

    // --- Constraint: Amount cannot be negative ---
    if (amountTotal < 0) {
      errors['amount_total'] = 'El total no puede ser negativo';
    }

    // --- Constraint: Final consumer Ecuador ---
    if (isFinalConsumer && exceedsFinalConsumerLimit) {
      if (endCustomerName == null || endCustomerName!.isEmpty) {
        errors['end_customer_name'] = 'Nombre de consumidor requerido para montos sobre el limite';
      }
    }

    // --- Constraint: Postdated invoice ---
    if (emitirFacturaFechaPosterior && fechaFacturar == null) {
      errors['fecha_facturar'] = 'Fecha de factura requerida para facturacion postfechada';
    }

    // --- Constraint: Validity date ---
    if (validityDate != null && dateOrder != null) {
      if (validityDate!.isBefore(dateOrder!)) {
        errors['validity_date'] = 'La fecha de validez debe ser posterior a la fecha de orden';
      }
    }

    // --- Constraint: Commitment date ---
    if (commitmentDate != null && dateOrder != null) {
      if (commitmentDate!.isBefore(dateOrder!)) {
        errors['commitment_date'] = 'La fecha de compromiso debe ser posterior a la fecha de orden';
      }
    }

    return errors;
  }

  /// Validates order for specific actions.
  ///
  /// Provides action-specific validation beyond basic validate().
  /// Common actions: 'confirm', 'cancel', 'invoice', 'send'
  Map<String, String> validateFor(String action) {
    final errors = validate();

    switch (action) {
      case 'confirm':
        // Para confirmar, el monto debe ser > 0 (implica lineas)
        if (amountTotal <= 0) {
          errors['amount_total'] = 'La orden debe tener lineas para confirmar';
        }
        if (!canConfirm) {
          errors['state'] = 'No se puede confirmar en estado: ${state.label}';
        }
        break;

      case 'cancel':
        if (!canCancel) {
          errors['state'] = 'No se puede cancelar en estado: ${state.label}';
        }
        break;

      case 'invoice':
        if (!canInvoice) {
          errors['state'] = 'No se puede facturar en estado: ${state.label}';
        }
        if (isFullyInvoiced) {
          errors['invoice_status'] = 'La orden ya esta completamente facturada';
        }
        break;

      case 'lock':
        if (!canLock) {
          errors['state'] = 'No se puede bloquear en estado: ${state.label}';
        }
        break;

      case 'unlock':
        if (!canUnlock) {
          errors['state'] = 'No se puede desbloquear en estado: ${state.label}';
        }
        break;

      case 'send':
        if (!canSendQuotation) {
          errors['state'] = 'Solo se puede enviar desde estado borrador';
        }
        break;
    }

    return errors;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Related Record Getters (Lazy Loading)
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // These getters provide RelatedRecord<T> wrappers for lazy-loading
  // the full related record from the local database.
  //
  // Usage:
  //   // Quick access (from denormalized fields)
  //   Text(order.partnerName ?? '')
  //
  //   // Full record with lazy loading
  //   final partner = await order.partner.load();
  //   Text(partner?.email ?? '')

  // NOTE: partner RelatedRecord getter removed during model migration
  // (Client no longer extends OdooRecord). Use partnerId/partnerName directly.

  // NOTE: user RelatedRecord getter removed during model migration
  // (User no longer extends OdooRecord). Use userId/userName directly.

  // NOTE: warehouse and paymentTerm RelatedRecord getters removed during
  // model migration (Warehouse/PaymentTerm no longer extend OdooRecord).
  // Use warehouseId/warehouseName and paymentTermId/paymentTermName directly.

  // NOTE: pricelist and fiscalPosition RelatedRecord getters removed during
  // model migration (Pricelist/FiscalPosition no longer extend OdooRecord).
  // Use pricelistId/pricelistName and fiscalPositionId/fiscalPositionName directly.

  // NOTE: team RelatedRecord getter removed during model migration
  // (SalesTeam no longer extends OdooRecord). Use teamId/teamName directly.

  // ═══════════════════════════════════════════════════════════════════════════
  // Odoo Conversion
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convierte a Map para enviar a Odoo
  Map<String, dynamic> toOdoo() {
    return {
      if (partnerId != null) 'partner_id': partnerId,
      if (partnerInvoiceId != null) 'partner_invoice_id': partnerInvoiceId,
      if (partnerShippingId != null) 'partner_shipping_id': partnerShippingId,
      if (userId != null) 'user_id': userId,
      if (teamId != null) 'team_id': teamId,
      if (pricelistId != null) 'pricelist_id': pricelistId,
      if (paymentTermId != null) 'payment_term_id': paymentTermId,
      if (fiscalPositionId != null) 'fiscal_position_id': fiscalPositionId,
      if (note != null) 'note': note,
      if (clientOrderRef != null) 'client_order_ref': clientOrderRef,
      if (validityDate != null)
        'validity_date': validityDate!.toIso8601String().split('T')[0],
      if (commitmentDate != null)
        'commitment_date': formatOdooDateTime(commitmentDate!),
    };
  }

  /// Nombre legible del estado (alias: displayState)
  String get displayState => stateDisplayName;

  /// Nombre legible del estado
  String get stateDisplayName {
    switch (state) {
      case SaleOrderState.draft:
        return 'Cotizacion';
      case SaleOrderState.sent:
        return 'Enviado';
      case SaleOrderState.waitingApproval:
        return 'Esperando Aprobacion';
      case SaleOrderState.approved:
        return 'Aprobado';
      case SaleOrderState.rejected:
        return 'Rechazado';
      case SaleOrderState.sale:
        return 'Orden de Venta';
      case SaleOrderState.done:
        return 'Completado';
      case SaleOrderState.cancel:
        return 'Cancelado';
    }
  }

  /// Nombre legible del estado de facturacion
  String get invoiceStatusDisplayName {
    switch (invoiceStatus) {
      case InvoiceStatus.no:
        return 'Nada que facturar';
      case InvoiceStatus.toInvoice:
        return 'Por facturar';
      case InvoiceStatus.invoiced:
        return 'Facturado';
      case InvoiceStatus.upselling:
        return 'Oportunidad de venta';
    }
  }

  /// Indica si la orden puede tener alguna accion (no cancelada ni rechazada)
  ///
  /// NOTA: Este getter es permisivo. Para verificar si se puede EDITAR
  /// lineas, precios, partner, usar [isEditable] en su lugar.
  ///
  /// Usado para: Mostrar botones de accion como Cancelar, etc.
  bool get canEdit =>
      !locked && state != SaleOrderState.cancel && state != SaleOrderState.rejected;

  /// Indica si la orden puede ser editada (lineas, precios, partner, descuentos)
  ///
  /// Segun las reglas de negocio de Odoo:
  /// - draft: Editable
  /// - sent: Editable
  /// - waiting: Bloqueado (esperando aprobacion)
  /// - approved: Solo lectura estricta
  /// - sale: Bloqueado (confirmado)
  /// - done: Inmutable
  /// - cancel: Terminal
  ///
  /// IMPORTANTE: Usar este getter para determinar si mostrar controles de edicion.
  bool get isEditable =>
      !locked &&
      (state == SaleOrderState.draft || state == SaleOrderState.sent);

  /// Check if order is confirmed (sale state)
  /// Note: Odoo doesn't have 'done' state - uses 'locked' boolean instead
  bool get isConfirmed => state == SaleOrderState.sale;

  /// Indica si la orden puede ser confirmada (boton verde "Confirmar Venta")
  /// Visible en: draft, sent, approved (waiting_approval no porque necesita aprobacion)
  bool get canConfirm =>
      state == SaleOrderState.draft ||
      state == SaleOrderState.sent ||
      state == SaleOrderState.approved;

  /// Indica si la orden puede ser cancelada
  ///
  /// Segun Odoo Ecuador:
  /// - draft, sent, waiting_approval, approved: Si (sin restriccion de lock)
  /// - sale: Solo si NO esta bloqueada
  /// - rejected, cancel: No (rejected se reactiva a draft primero)
  bool get canCancel =>
      (state == SaleOrderState.draft ||
          state == SaleOrderState.sent ||
          state == SaleOrderState.waitingApproval ||
          state == SaleOrderState.approved) ||
      (state == SaleOrderState.sale && !locked);

  /// Indica si se puede volver a cotizacion (establecer como borrador)
  ///
  /// Segun Odoo Ecuador:
  /// - cancel: Si (para reactivar)
  /// - rejected: Si (reactivar desde rechazo)
  /// - sale, approved: Solo si NO esta bloqueada
  bool get canSetToQuotation =>
      state == SaleOrderState.cancel ||
      state == SaleOrderState.rejected ||
      ((state == SaleOrderState.sale || state == SaleOrderState.approved) &&
          !locked);

  /// Indica si se puede bloquear la orden
  ///
  /// Segun Odoo 19: Solo en estado sale, no bloqueada, y no completamente facturada
  /// Una orden facturada no deberia poder bloquearse/desbloquearse
  bool get canLock =>
      state == SaleOrderState.sale && !locked && !isFullyInvoiced;

  /// Indica si se puede desbloquear la orden
  ///
  /// Segun Odoo 19: Solo en estado sale, bloqueada, y no completamente facturada
  /// Una orden facturada no deberia poder bloquearse/desbloquearse
  bool get canUnlock =>
      state == SaleOrderState.sale && locked && !isFullyInvoiced;

  /// Indica si se pueden agregar pagos a la orden
  ///
  /// Permite registrar pagos y generar factura en:
  /// - sale: Orden confirmada (puede o no tener factura)
  /// - approved: Orden aprobada (pre-confirmacion con aprobacion de gerente)
  ///
  /// No permite en:
  /// - draft/sent/waiting/approved: Aun no confirmadas para venta
  /// - done: Ya completada/entregada
  /// - cancel: Cancelada
  /// - hasQueuedInvoice: Ya hay una factura encolada esperando sync
  ///
  /// Nota: El estado locked NO afecta la capacidad de cobrar y facturar
  /// IMPORTANTE: Solo estado 'sale' permite pagos. 'approved' requiere confirmar primero.
  bool get canAddPayments =>
      !hasQueuedInvoice && state == SaleOrderState.sale;

  /// Indica si la orden puede ser facturada
  ///
  /// Solo permite en estado 'sale' (confirmada).
  /// El estado 'approved' requiere confirmar primero para pasar a 'sale'.
  ///
  /// No permite en:
  /// - draft/sent/waiting/approved: Aun no confirmadas
  /// - done: Ya completada (generalmente ya facturada)
  /// - cancel: Cancelada
  /// - hasQueuedInvoice: Ya hay una factura encolada esperando sync
  bool get canInvoice =>
      !hasQueuedInvoice && state == SaleOrderState.sale;

  /// Indica si la orden ya esta completamente facturada
  ///
  /// Cuando esta facturada, los pagos deben mostrarse en modo solo lectura
  /// y no se deben permitir mas pagos/retenciones
  bool get isFullyInvoiced => invoiceStatus == InvoiceStatus.invoiced;

  /// Indica si la orden puede ser rechazada (por gerente)
  ///
  /// Segun Odoo Ecuador (l10n_ec_base):
  /// Solo se pueden rechazar ordenes en estado waitingApproval
  bool get canReject => state == SaleOrderState.waitingApproval;

  /// Indica si la orden puede ser reactivada desde rechazo
  ///
  /// Segun Odoo Ecuador (l10n_ec_base):
  /// Solo ordenes en estado rejected pueden ser reactivadas
  bool get canReactivateFromRejection => state == SaleOrderState.rejected;

  /// Indica si la orden esta rechazada
  bool get isRejected => state == SaleOrderState.rejected;

  /// Indica si se puede reservar stock
  ///
  /// Segun Odoo Ecuador: Solo en estado sale y no bloqueada
  bool get canReserveStock => state == SaleOrderState.sale && !locked;

  /// Indica si se puede enviar la cotizacion por correo
  /// Visible en: draft
  bool get canSendQuotation => state == SaleOrderState.draft;

  /// Indica si es una cotizacion (no una orden confirmada)
  bool get isQuotation =>
      state == SaleOrderState.draft || state == SaleOrderState.sent;

  /// Indica si es una orden de venta confirmada
  /// Note: approved is pre-confirmation state, not a confirmed sale
  bool get isSaleOrder => state == SaleOrderState.sale;

  /// Indica si es una venta de contado (pago inmediato)
  ///
  /// Usa el campo [isCash] sincronizado desde Odoo (payment_term_id.is_cash).
  /// Si no hay termino de pago, se considera contado.
  bool get isCashSale => isCash || paymentTermId == null;

  /// Indica si es una venta a credito
  ///
  /// Usa el campo [isCredit] sincronizado desde Odoo (payment_term_id.is_credit).
  bool get isCreditSale => isCredit;

  // ═══════════════════════════════════════════════════════════════════════════
  // ONCHANGE SIMULATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Simula el onchange de partner_id.
  ///
  /// Retorna una copia de la orden con campos actualizados
  /// segun la configuracion del cliente.
  ///
  /// Equivalente a: @api.onchange('partner_id') en Odoo
  SaleOrder onPartnerChanged(Client? partner) {
    if (partner == null) return this;

    return copyWith(
      partnerId: partner.id,
      partnerName: partner.name,
      partnerVat: partner.vat,
      partnerStreet: partner.street,
      partnerPhone: partner.phone,
      partnerEmail: partner.email,
      // Aplicar configuracion del cliente
      pricelistId: partner.propertyProductPricelistId,
      pricelistName: partner.propertyProductPricelistName,
      paymentTermId: partner.propertyPaymentTermId,
      paymentTermName: partner.propertyPaymentTermName,
      // fiscalPositionId se actualizaria desde FiscalPosition si esta disponible
    );
  }

  /// Simula el onchange del termino de pago.
  ///
  /// Actualiza los flags de contado/credito.
  SaleOrder onPaymentTermChanged(PaymentTerm? paymentTerm) {
    if (paymentTerm == null) {
      return copyWith(
        paymentTermId: null,
        paymentTermName: null,
        isCash: true,
        isCredit: false,
      );
    }

    return copyWith(
      paymentTermId: paymentTerm.id,
      paymentTermName: paymentTerm.name,
      isCash: paymentTerm.isCash,
      isCredit: paymentTerm.isCredit,
    );
  }

  /// Simula el onchange de la lista de precios.
  SaleOrder onPricelistChanged(Pricelist? pricelist) {
    if (pricelist == null) return this;

    return copyWith(
      pricelistId: pricelist.id,
      pricelistName: pricelist.name,
      currencyId: pricelist.currencyId,
      // currencySymbol se obtiene de la moneda relacionada
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea una nueva orden en borrador con valores por defecto.
  ///
  /// Similar a: self.env['sale.order'].new({...}) en Odoo
  factory SaleOrder.newDraft({
    required int partnerId,
    String? partnerName,
    int? userId,
    String? userName,
    int? warehouseId,
    String? warehouseName,
    int? companyId,
    String? companyName,
    int? pricelistId,
    String? pricelistName,
    int? currencyId,
    String? currencySymbol,
    int? paymentTermId,
    String? paymentTermName,
    bool isCash = true,
    bool isCredit = false,
  }) {
    return SaleOrder(
      id: 0, // ID temporal hasta que se guarde
      orderUuid: null, // Se asignara al guardar
      name: 'Nuevo', // Se generara secuencia al confirmar
      state: SaleOrderState.draft,
      dateOrder: DateTime.now(),
      partnerId: partnerId,
      partnerName: partnerName,
      userId: userId,
      userName: userName,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      companyId: companyId,
      companyName: companyName,
      pricelistId: pricelistId,
      pricelistName: pricelistName,
      currencyId: currencyId,
      currencySymbol: currencySymbol,
      paymentTermId: paymentTermId,
      paymentTermName: paymentTermName,
      isCash: isCash,
      isCredit: isCredit,
      isSynced: false,
    );
  }

  /// Crea una orden con todos los datos de un cliente.
  ///
  /// Aplica automaticamente la configuracion del cliente:
  /// - Lista de precios
  /// - Terminos de pago
  factory SaleOrder.fromClient({
    required Client client,
    required User user,
    Warehouse? warehouse,
    int? companyId,
    String? companyName,
    FiscalPosition? fiscalPosition,
  }) {
    // Construir direccion de display
    final clientAddress = [client.street, client.city, client.stateName]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return SaleOrder(
      id: 0,
      name: 'Nuevo',
      state: SaleOrderState.draft,
      dateOrder: DateTime.now(),
      // Cliente
      partnerId: client.id,
      partnerName: client.name,
      partnerVat: client.vat,
      partnerStreet: client.street,
      partnerPhone: client.phone,
      partnerEmail: client.email,
      partnerInvoiceId: client.id,
      partnerInvoiceAddress: clientAddress.isNotEmpty ? clientAddress : client.name,
      partnerShippingId: client.id,
      partnerShippingAddress: clientAddress.isNotEmpty ? clientAddress : client.name,
      // Vendedor
      userId: user.id,
      userName: user.name,
      // Almacen
      warehouseId: warehouse?.id,
      warehouseName: warehouse?.name,
      // Compania
      companyId: companyId,
      companyName: companyName,
      // Configuracion del cliente
      pricelistId: client.propertyProductPricelistId,
      pricelistName: client.propertyProductPricelistName,
      paymentTermId: client.propertyPaymentTermId,
      paymentTermName: client.propertyPaymentTermName,
      fiscalPositionId: fiscalPosition?.id,
      fiscalPositionName: fiscalPosition?.name,
      // Determinar si es contado o credito
      isCash: client.propertyPaymentTermId == null,
      isCredit: client.propertyPaymentTermId != null,
      isSynced: false,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REPORT METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convierte a mapa para el reporte PDF
  ///
  /// [lines] List of SaleOrderLine objects associated with this order.
  ///         They are passed separately because SaleOrder logic is decoupled from lines.
  /// [taxDataMap] Optional map of tax ID -> tax data for looking up tax names.
  ///              Expected structure: {taxId: {'name': 'IVA 15%', 'amount': 15.0}}
  Map<String, dynamic> toReportMap({
    required List<SaleOrderLine> lines,
    Map<int, Map<String, dynamic>>? taxDataMap,
  }) {
    // Process lines using their own toReportMap logic, passing tax data
    final processedLines = lines
        .map((l) => l.toReportMap(taxDataMap: taxDataMap))
        .toList();

    // Prepare partner map
    final partnerMap = partnerId != null
        ? {
            'id': partnerId,
            'name': partnerName,
            'vat': partnerVat,
            'street': partnerStreet,
            'phone': partnerPhone,
            'email': partnerEmail,
            'avatar_128': partnerAvatar,
          }
        : null;

    final result = <String, dynamic>{
      'id': id,
      'name': name,
      'state': state.toOdooString(),
      'date_order': dateOrder?.toIso8601String(),
      'validity_date': validityDate != null
          ? validityDate!.toIso8601String().split('T')[0]
          : null,
      'commitment_date': commitmentDate?.toIso8601String(),
      'expected_date': expectedDate?.toIso8601String(),

      'partner_id': partnerMap,
      'partner_shipping_id': partnerShippingId != null
          ? {
              'id': partnerShippingId,
              'name': partnerShippingAddress,
              // Ideally would include address fields but we only have name/ID
            }
          : null,
      'partner_invoice_id': partnerInvoiceId != null
          ? {'id': partnerInvoiceId, 'name': partnerInvoiceAddress}
          : null,

      'user_id': userId != null ? {'id': userId, 'name': userName} : null,
      'team_id': teamId != null ? {'id': teamId, 'name': teamName} : null,
      'company_id': companyId != null
          ? {'id': companyId, 'name': companyName}
          : null,
      'currency_id': currencyId != null
          ? {'id': currencyId, 'symbol': currencySymbol}
          : null,
      'pricelist_id': pricelistId != null
          ? {'id': pricelistId, 'name': pricelistName}
          : null,
      'payment_term_id': paymentTermId != null
          ? {'id': paymentTermId, 'name': paymentTermName}
          : null,

      'amount_untaxed': amountUntaxed,
      'amount_tax': amountTax,
      'amount_total': amountTotal,
      'total_discount_amount': totalDiscountAmount,
      'total_amount_undiscounted': amountUntaxedUndiscounted,

      'note': note,
      'client_order_ref': clientOrderRef,

      // Order lines
      'order_line': processedLines,
      // Default to assuming these are the lines to report
      'lines_to_report': processedLines,

      // Tax totals (if available)
      'tax_totals': taxTotals,

      // Flags
      'is_pro_forma': false,
    };

    return result;
  }
}
