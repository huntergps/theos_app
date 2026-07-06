import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../order_cache_provider.dart';
import '../sale_order_form_state.dart';

/// Mixin de eliminación y actualización de estado de la orden para
/// [SaleOrderFormNotifier]
///
/// Extraído de `sale_order_form_notifier.dart` (refactor de descomposición
/// en mixins, Fase E2b — copy-paste literal, cero cambio de comportamiento).
///
/// Proporciona: `deleteOrder`, `updateOrderLocked`, `updateOrderState`,
/// `updateOrderLockedById`, `updateOrderStateById`.
mixin SaleOrderStateMixin {
  /// Estado actual del formulario - debe ser implementado por el notifier
  SaleOrderFormState get state;

  /// Metodo para actualizar estado - debe ser implementado por el notifier
  set state(SaleOrderFormState newState);

  /// Acceso a Riverpod - debe ser implementado por el notifier
  Ref get ref;

  /// Implementado por [SaleOrderUtilityMixin]
  void clearState();

  /// Eliminar orden no sincronizada de la base de datos local
  ///
  /// Solo permite eliminar ordenes que:
  /// - Existen (order != null)
  /// - NO han sido sincronizadas con el servidor (!isSynced)
  ///
  /// Funciona tanto en modo online como offline.
  /// Retorna true si la eliminacion fue exitosa, false en caso contrario.
  Future<bool> deleteOrder() async {
    if (state.order == null) {
      logger.w('[SaleOrderForm]', 'No hay orden para eliminar');
      return false;
    }

    if (state.order!.isSynced) {
      state = state.copyWith(
        errorMessage:
            'No se puede eliminar una orden ya sincronizada con el servidor',
      );
      logger.w('[SaleOrderForm]', 'Intento de eliminar orden sincronizada');
      return false;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final orderId = state.order!.id;

      // Eliminar orden y sus lineas de la base de datos local
      await saleOrderManager.deleteSaleOrderWithLines(orderId);

      logger.i('[SaleOrderForm]', 'Orden eliminada exitosamente: ID=$orderId');

      // Limpiar estado
      clearState();

      return true;
    } catch (e) {
      logger.e('[SaleOrderForm]', 'Error al eliminar orden: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al eliminar la orden: $e',
      );
      return false;
    }
  }

  /// Actualiza el estado bloqueado de la orden de forma reactiva
  ///
  /// Updates both:
  /// 1. Local state (for immediate UI response)
  /// 2. Unified cache (propagates to all providers)
  void updateOrderLocked(bool locked) {
    if (state.order == null) return;
    final orderId = state.order!.id;

    // Update unified cache (single source of truth)
    ref.read(orderCacheProvider.notifier).updateOrderLocked(orderId, locked);

    // Update local state for immediate response
    final updatedOrder = state.order!.copyWith(locked: locked);
    state = state.copyWith(order: updatedOrder);

    logger.d('[SaleOrderForm]', 'Order $orderId locked=$locked (via cache)');
  }

  /// Actualiza el estado de la orden de forma reactiva
  ///
  /// Updates both:
  /// 1. Local state (for immediate UI response)
  /// 2. Unified cache (propagates to all providers)
  void updateOrderState(SaleOrderState newState) {
    if (state.order == null) return;
    final orderId = state.order!.id;

    // Update unified cache (single source of truth)
    ref.read(orderCacheProvider.notifier).updateOrderState(orderId, newState);

    // Update local state for immediate response
    final updatedOrder = state.order!.copyWith(state: newState);
    state = state.copyWith(order: updatedOrder);

    logger.d(
      '[SaleOrderForm]',
      'Order $orderId state=${newState.name} (via cache)',
    );
  }

  /// Actualiza el estado bloqueado de una orden específica por ID
  ///
  /// Updates local state ONLY if the order ID matches the current order.
  /// The cache update is handled by the caller.
  void updateOrderLockedById(int orderId, bool locked) {
    if (state.order == null || state.order!.id != orderId) return;

    final updatedOrder = state.order!.copyWith(locked: locked);
    state = state.copyWith(order: updatedOrder);

    logger.d(
      '[SaleOrderForm]',
      'Order $orderId locked=$locked (from cache sync)',
    );
  }

  /// Actualiza el estado de una orden específica por ID
  ///
  /// Updates local state ONLY if the order ID matches the current order.
  /// The cache update is handled by the caller.
  void updateOrderStateById(int orderId, SaleOrderState newState) {
    if (state.order == null || state.order!.id != orderId) return;

    final updatedOrder = state.order!.copyWith(state: newState);
    state = state.copyWith(order: updatedOrder);

    logger.d(
      '[SaleOrderForm]',
      'Order $orderId state=${newState.name} (from cache sync)',
    );
  }
}
