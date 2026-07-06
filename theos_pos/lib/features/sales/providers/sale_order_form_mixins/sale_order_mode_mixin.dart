import 'package:theos_pos_core/theos_pos_core.dart';

import '../sale_order_form_state.dart';
import 'sale_order_form_async_utils.dart';

/// Mixin de cambio de modo (vista/edición) para [SaleOrderFormNotifier]
///
/// Extraído de `sale_order_form_notifier.dart` (refactor de descomposición
/// en mixins, Fase E2b — copy-paste literal, cero cambio de comportamiento).
///
/// Proporciona:
/// - `_syncFormFieldsFromOrder`: sincroniza campos del formulario con la orden
/// - `enterEditMode`: pasa a modo edición
/// - `exitEditMode`: vuelve a modo vista, aplicando updates pendientes si los hay
mixin SaleOrderModeMixin {
  /// Estado actual del formulario - debe ser implementado por el notifier
  SaleOrderFormState get state;

  /// Metodo para actualizar estado - debe ser implementado por el notifier
  set state(SaleOrderFormState newState);

  /// Implementado por [SaleOrderLoaderMixin]
  Future<void> loadSelectionData();

  /// Implementado por [SaleOrderConflictMixin]
  void applyPendingServerUpdate();

  /// Sincroniza campos del formulario con la orden
  ///
  /// [preserveLocalChanges] - Si true, usa ?? para mantener cambios locales
  ///                          Si false, restaura todos los valores desde order
  void _syncFormFieldsFromOrder({required bool preserveLocalChanges}) {
    final order = state.order!;

    // Calcular isFinalConsumer desde partnerVat si el campo de Odoo es false
    final computedIsFinalConsumer = preserveLocalChanges
        ? (state.isFinalConsumer ||
              order.isFinalConsumer ||
              order.partnerVat == '9999999999999')
        : (order.isFinalConsumer || order.partnerVat == '9999999999999');

    state = state.copyWith(
      isEditing: preserveLocalChanges,
      // Campos de partner
      partnerId: preserveLocalChanges
          ? (state.partnerId ?? order.partnerId)
          : order.partnerId,
      partnerName: preserveLocalChanges
          ? (state.partnerName ?? order.partnerName)
          : order.partnerName,
      partnerVat: preserveLocalChanges
          ? (state.partnerVat ?? order.partnerVat)
          : order.partnerVat,
      partnerStreet: preserveLocalChanges
          ? (state.partnerStreet ?? order.partnerStreet)
          : order.partnerStreet,
      partnerPhone: preserveLocalChanges
          ? (state.partnerPhone ?? order.partnerPhone)
          : order.partnerPhone,
      partnerEmail: preserveLocalChanges
          ? (state.partnerEmail ?? order.partnerEmail)
          : order.partnerEmail,
      partnerAvatar: preserveLocalChanges
          ? (state.partnerAvatar ?? order.partnerAvatar)
          : order.partnerAvatar,
      // Campos de configuración
      paymentTermId: preserveLocalChanges
          ? (state.paymentTermId ?? order.paymentTermId)
          : order.paymentTermId,
      paymentTermName: preserveLocalChanges
          ? (state.paymentTermName ?? order.paymentTermName)
          : order.paymentTermName,
      pricelistId: preserveLocalChanges
          ? (state.pricelistId ?? order.pricelistId)
          : order.pricelistId,
      pricelistName: preserveLocalChanges
          ? (state.pricelistName ?? order.pricelistName)
          : order.pricelistName,
      warehouseId: preserveLocalChanges
          ? (state.warehouseId ?? order.warehouseId)
          : order.warehouseId,
      warehouseName: preserveLocalChanges
          ? (state.warehouseName ?? order.warehouseName)
          : order.warehouseName,
      userId: preserveLocalChanges
          ? (state.userId ?? order.userId)
          : order.userId,
      userName: preserveLocalChanges
          ? (state.userName ?? order.userName)
          : order.userName,
      // Fechas
      dateOrder: preserveLocalChanges
          ? (state.dateOrder ?? order.dateOrder)
          : order.dateOrder,
      validityDate: preserveLocalChanges
          ? (state.validityDate ?? order.validityDate)
          : order.validityDate,
      commitmentDate: preserveLocalChanges
          ? (state.commitmentDate ?? order.commitmentDate)
          : order.commitmentDate,
      // Referencias y notas
      clientOrderRef: preserveLocalChanges
          ? (state.clientOrderRef ?? order.clientOrderRef)
          : order.clientOrderRef,
      note: preserveLocalChanges ? (state.note ?? order.note) : order.note,
      // Campos de consumidor final (l10n_ec_sale_base)
      isFinalConsumer: computedIsFinalConsumer,
      endCustomerName: preserveLocalChanges
          ? (state.endCustomerName ?? order.endCustomerName)
          : order.endCustomerName,
      endCustomerPhone: preserveLocalChanges
          ? (state.endCustomerPhone ?? order.endCustomerPhone)
          : order.endCustomerPhone,
      endCustomerEmail: preserveLocalChanges
          ? (state.endCustomerEmail ?? order.endCustomerEmail)
          : order.endCustomerEmail,
      // Campos de facturación postfechada (l10n_ec_sale_base)
      emitirFacturaFechaPosterior: preserveLocalChanges
          ? (state.emitirFacturaFechaPosterior ||
                order.emitirFacturaFechaPosterior)
          : order.emitirFacturaFechaPosterior,
      fechaFacturar: preserveLocalChanges
          ? (state.fechaFacturar ?? order.fechaFacturar)
          : order.fechaFacturar,
      // Campos de referidor (l10n_ec_sale_base)
      referrerId: preserveLocalChanges
          ? (state.referrerId ?? order.referrerId)
          : order.referrerId,
      referrerName: preserveLocalChanges
          ? (state.referrerName ?? order.referrerName)
          : order.referrerName,
      // Campos de tipo/canal cliente (l10n_ec_sale_base)
      tipoCliente: preserveLocalChanges
          ? (state.tipoCliente ?? order.tipoCliente)
          : order.tipoCliente,
      canalCliente: preserveLocalChanges
          ? (state.canalCliente ?? order.canalCliente)
          : order.canalCliente,
      // Reset change tracking
      hasChanges: false,
      changedFields: {},
      deletedLineIds: [],
      newLines: [],
      updatedLines: [],
      errorMessage: preserveLocalChanges ? state.errorMessage : null,
    );
  }

  /// Cambiar a modo edición (desde modo vista)
  ///
  /// Mantiene todos los datos, solo cambia el flag isEditing.
  /// Carga datos de selección si no están disponibles.
  void enterEditMode() {
    if (state.isEditing) return;
    if (state.order == null) {
      logger.w('[SaleOrderForm]', 'Cannot enter edit mode without order');
      return;
    }

    logger.i('[SaleOrderForm]', 'Entering edit mode for ${state.order!.name}');
    _syncFormFieldsFromOrder(preserveLocalChanges: true);

    // Cargar datos de selección si no están cargados
    if (!state.hasSelectionData) {
      unawaited(loadSelectionData());
    }
  }

  /// Salir del modo edición (volver a modo vista)
  ///
  /// Descarta cambios no guardados y restaura datos originales.
  void exitEditMode() {
    if (!state.isEditing) return;
    if (state.order == null) return;

    logger.i('[SaleOrderForm]', 'Exiting edit mode for ${state.order!.name}');

    // If there's a pending server update, apply it instead of reverting
    // to the (now stale) local order data.
    if (state.serverUpdatePending && state.pendingServerOrder != null) {
      logger.i(
        '[SaleOrderForm]',
        'Applying pending server update on exit edit mode',
      );
      // First exit edit mode with current data
      _syncFormFieldsFromOrder(preserveLocalChanges: false);
      // Then apply the pending update
      applyPendingServerUpdate();
    } else {
      _syncFormFieldsFromOrder(preserveLocalChanges: false);
    }
  }
}
