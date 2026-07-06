import 'package:theos_pos_core/theos_pos_core.dart';

import '../sale_order_form_state.dart';

/// Mixin de utilidades varias para [SaleOrderFormNotifier]
///
/// Extraído de `sale_order_form_notifier.dart` (refactor de descomposición
/// en mixins, Fase E2b — copy-paste literal, cero cambio de comportamiento).
///
/// Proporciona: `clearState`, `discardChanges`, `refreshOrder`,
/// `updateOrderFromSync`.
mixin SaleOrderUtilityMixin {
  /// Estado actual del formulario - debe ser implementado por el notifier
  SaleOrderFormState get state;

  /// Metodo para actualizar estado - debe ser implementado por el notifier
  set state(SaleOrderFormState newState);

  /// Implementado por [SaleOrderModeMixin]
  void exitEditMode();

  /// Implementado por [SaleOrderLoaderMixin]
  Future<void> loadOrder(int orderId, {bool forceRefresh = false});

  /// Limpiar estado del formulario
  void clearState() {
    state = const SaleOrderFormState();
    logger.d('[SaleOrderForm]', 'Estado limpiado');
  }

  /// Descartar cambios y volver a modo vista
  ///
  /// NO recarga del servidor - simplemente restaura los datos originales
  /// que ya están en state.order. Para recargar del servidor, usar refreshOrder().
  void discardChanges() {
    if (state.order != null) {
      // Solo salir del modo edición - restaura valores originales sin recargar
      exitEditMode();
    } else {
      clearState();
    }
    logger.d('[SaleOrderForm]', 'Cambios descartados');
  }

  /// Refrescar orden desde el servidor (pull-to-refresh)
  ///
  /// Usa forceRefresh: true para garantizar datos frescos del servidor
  Future<void> refreshOrder() async {
    if (state.order != null) {
      await loadOrder(state.order!.id, forceRefresh: true);
      logger.i('[SaleOrderForm]', 'Orden refrescada desde servidor');
    }
  }

  /// Update order state directly from sync (without isLoading flash)
  ///
  /// Used by sync operations that have already fetched updated data.
  /// This avoids the "black screen" issue caused by isLoading: true.
  void updateOrderFromSync(SaleOrder order, List<SaleOrderLine> lines) {
    logger.d('[SaleOrderForm]', 'Updating order from sync: ${order.id}');

    state = state.copyWith(
      order: order,
      lines: lines,
      isLoading: false,
      // Update denormalized fields
      partnerId: order.partnerId,
      partnerName: order.partnerName,
      partnerVat: order.partnerVat,
      partnerStreet: order.partnerStreet,
      partnerPhone: order.partnerPhone,
      partnerEmail: order.partnerEmail,
      partnerAvatar: order.partnerAvatar,
      paymentTermId: order.paymentTermId,
      paymentTermName: order.paymentTermName,
      pricelistId: order.pricelistId,
      pricelistName: order.pricelistName,
      warehouseId: order.warehouseId,
      warehouseName: order.warehouseName,
      userId: order.userId,
      userName: order.userName,
      dateOrder: order.dateOrder,
      validityDate: order.validityDate,
      commitmentDate: order.commitmentDate,
      clientOrderRef: order.clientOrderRef,
      note: order.note,
      isFinalConsumer: order.isFinalConsumer || order.partnerVat == '9999999999999',
      endCustomerName: order.endCustomerName,
      endCustomerPhone: order.endCustomerPhone,
      endCustomerEmail: order.endCustomerEmail,
      emitirFacturaFechaPosterior: order.emitirFacturaFechaPosterior,
      fechaFacturar: order.fechaFacturar,
      referrerId: order.referrerId,
      referrerName: order.referrerName,
      tipoCliente: order.tipoCliente,
      canalCliente: order.canalCliente,
      // Clear change tracking since we just synced
      hasChanges: false,
      changedFields: {},
      deletedLineIds: [],
      newLines: [],
      updatedLines: [],
      errorMessage: null,
    );

    logger.i('[SaleOrderForm]', 'Order ${order.id} updated from sync');
  }
}
