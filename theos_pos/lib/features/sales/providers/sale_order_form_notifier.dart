import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide SaleOrderLineManager;

// Hide generated SaleOrderLineManager - we use the mixin
import 'order_cache_provider.dart';
import 'sale_order_field_updater.dart';
import 'sale_order_form_mixins/sale_order_conflict_mixin.dart';
import 'sale_order_form_mixins/sale_order_credit_validation_mixin.dart';
import 'sale_order_form_mixins/sale_order_loader_mixin.dart';
import 'sale_order_form_mixins/sale_order_mode_mixin.dart';
import 'sale_order_form_mixins/sale_order_saver_mixin.dart';
import 'sale_order_form_mixins/sale_order_state_mixin.dart';
import 'sale_order_form_mixins/sale_order_utility_mixin.dart';
import 'sale_order_form_state.dart';
import 'sale_order_line_manager.dart';

part 'sale_order_form_notifier.g.dart';

/// Notifier para gestionar el estado del formulario de orden de venta
///
/// Proporciona metodos para:
/// - Cargar orden existente o inicializar nueva orden
/// - Actualizar campos del formulario (via SaleOrderFieldUpdater)
/// - Gestionar lineas (via SaleOrderLineManager)
/// - Guardar orden en el servidor
/// - Cargar datos de seleccion (listas desplegables)
@Riverpod(keepAlive: true)
class SaleOrderFormNotifier extends _$SaleOrderFormNotifier
    with
        SaleOrderFieldUpdater,
        SaleOrderLineManager,
        SaleOrderModeMixin,
        SaleOrderUtilityMixin,
        SaleOrderCreditValidationMixin,
        SaleOrderStateMixin,
        SaleOrderLoaderMixin,
        SaleOrderSaverMixin,
        SaleOrderConflictMixin {
  @override
  SaleOrderFormState build() {
    // Listen to cache changes for cross-provider sync (FastSale → Form)
    ref.listen<OrderCacheState>(orderCacheProvider, (previous, next) {
      if (previous?.version != next.version) {
        _syncFromCache(next);
      }
    });

    return const SaleOrderFormState();
  }

  /// Sync the current order from cache when another provider updates it
  ///
  /// Only syncs directamente si:
  /// - Tenemos una orden cargada
  /// - NO estamos en modo edición (para preservar cambios locales)
  /// - La orden cacheada difiere de la actual
  ///
  /// Si SÍ estamos editando, el cambio no se descarta: se deja como
  /// "pending" (mismo mecanismo de [setServerUpdatePending] que ya usa el
  /// canal de streams de Drift en `sale_order_form_screen.dart`) para
  /// aplicarlo con merge/detección de conflictos al salir de edición. Antes
  /// este cambio se perdía para siempre si venía de `orderCacheProvider`
  /// (ej. la misma orden editada desde FastSale) mientras el Form estaba en
  /// modo edición — race condition corregida.
  void _syncFromCache(OrderCacheState cache) {
    logger.d('[SaleOrderForm]', '>>> _syncFromCache CALLED');

    final currentOrder = state.order;
    if (currentOrder == null) {
      logger.d(
        '[SaleOrderForm]',
        '>>> _syncFromCache: No current order, skipping',
      );
      return;
    }

    final cachedOrder = cache.orders[currentOrder.id];
    if (cachedOrder == null) {
      logger.d(
        '[SaleOrderForm]',
        '>>> _syncFromCache: No cached order for ${currentOrder.id}, skipping',
      );
      return;
    }

    final cachedLines = cache.orderLines[currentOrder.id];

    if (state.isEditing) {
      logger.d(
        '[SaleOrderForm]',
        '>>> _syncFromCache: isEditing=true, queuing as pending server update',
      );
      setServerUpdatePending(cachedOrder, cachedLines);
      return;
    }

    // Check if there are actual differences
    if (!_orderNeedsSync(currentOrder, cachedOrder)) {
      logger.d('[SaleOrderForm]', '>>> _syncFromCache: No sync needed');
      return;
    }

    logger.w(
      '[SaleOrderForm]',
      '>>> _syncFromCache: SYNCING! cached partner=${cachedOrder.partnerId}/${cachedOrder.partnerName}, current=${state.partnerId}/${state.partnerName}',
    );

    // Sync from cache
    state = state.copyWith(
      order: cachedOrder,
      partnerId: cachedOrder.partnerId,
      partnerName: cachedOrder.partnerName,
      partnerVat: cachedOrder.partnerVat,
      partnerStreet: cachedOrder.partnerStreet,
      partnerPhone: cachedOrder.partnerPhone,
      partnerEmail: cachedOrder.partnerEmail,
      paymentTermId: cachedOrder.paymentTermId,
      paymentTermName: cachedOrder.paymentTermName,
      pricelistId: cachedOrder.pricelistId,
      pricelistName: cachedOrder.pricelistName,
      warehouseId: cachedOrder.warehouseId,
      warehouseName: cachedOrder.warehouseName,
    );

    // Sync lines if available
    if (cachedLines != null) {
      state = state.copyWith(lines: cachedLines);
    }

    logger.d(
      '[SaleOrderForm]',
      'Synced from cache: order=${currentOrder.id}, partner=${cachedOrder.partnerName}',
    );
  }

  /// Check if order needs syncing from cache
  bool _orderNeedsSync(SaleOrder local, SaleOrder cached) {
    return local.partnerId != cached.partnerId ||
        local.partnerName != cached.partnerName ||
        local.partnerVat != cached.partnerVat ||
        local.state != cached.state ||
        local.locked != cached.locked ||
        local.paymentTermId != cached.paymentTermId ||
        local.pricelistId != cached.pricelistId ||
        local.warehouseId != cached.warehouseId;
  }

  // ==========================================================================
  // METODOS DE CAMBIO DE MODO
  // ==========================================================================
  // Movidos a sale_order_form_mixins/sale_order_mode_mixin.dart (Fase E2b):
  // _syncFormFieldsFromOrder, enterEditMode, exitEditMode.
  // ==========================================================================

  // ==========================================================================
  // METODOS DE CARGA
  // ==========================================================================
  // Movidos a sale_order_form_mixins/sale_order_loader_mixin.dart (Fase E2b):
  // initFromData, loadOrder, initNewOrder, _syncDefaultsFromOdooInBackground,
  // mounted, _loadPartnerData, updatePartnerPhone, updatePartnerEmail,
  // _resolveDefaultNames, loadSelectionData, _loadWarehouses,
  // _loadPartnerPaymentTermIds, _loadCompanySettings.
  // ==========================================================================

  // ==========================================================================
  // METODOS DE GUARDADO
  // ==========================================================================
  // Movidos a sale_order_form_mixins/sale_order_saver_mixin.dart (Fase E2b):
  // saveOrder, _createNewOrder, _updateExistingOrder,
  // _consolidateChangesAfterSave, _prepareOrderValues.
  // ==========================================================================

  // ==========================================================================
  // CACHE SYNCHRONIZATION HOOKS
  // ==========================================================================

  /// Hook called when any field is updated via [SaleOrderFieldUpdater]
  ///
  /// Syncs field changes to [OrderCacheProvider] so that other providers
  /// (like [fastSaleProvider]) that read from the cache get the update.
  ///
  /// Handles:
  /// - 'partner': Map with partner_id, partner_name, partner_vat, etc.
  /// - Other fields: direct value sync
  @override
  void onFieldUpdated(int orderId, String fieldName, dynamic value) {
    logger.d(
      '[SaleOrderForm]',
      '>>> onFieldUpdated: orderId=$orderId, field=$fieldName',
    );
    final cache = ref.read(orderCacheProvider.notifier);

    switch (fieldName) {
      case 'partner':
        // Partner is a composite field with multiple values
        final data = value as Map<String, dynamic>;
        logger.d(
          '[SaleOrderForm]',
          '>>> Updating cache with partner: ${data['partner_name']} (${data['partner_id']})',
        );
        cache.updateOrderPartner(
          orderId,
          partnerId: data['partner_id'] as int?,
          partnerName: data['partner_name'] as String?,
          partnerVat: data['partner_vat'] as String?,
          partnerStreet: data['partner_street'] as String?,
          partnerPhone: data['partner_phone'] as String?,
          partnerEmail: data['partner_email'] as String?,
        );
        logger.d(
          '[SaleOrderForm]',
          '>>> Cache updated for partner: order=$orderId, partner=${data['partner_name']}',
        );

      case 'payment_term_id':
      case 'pricelist_id':
      case 'warehouse_id':
      case 'user_id':
        // Update order in cache with new field value
        cache.updateOrder(orderId, (order) {
          switch (fieldName) {
            case 'payment_term_id':
              return order.copyWith(
                paymentTermId: value as int?,
                paymentTermName: state.paymentTermName,
              );
            case 'pricelist_id':
              return order.copyWith(
                pricelistId: value as int?,
                pricelistName: state.pricelistName,
              );
            case 'warehouse_id':
              return order.copyWith(
                warehouseId: value as int?,
                warehouseName: state.warehouseName,
              );
            case 'user_id':
              return order.copyWith(
                userId: value as int?,
                userName: state.userName,
              );
            default:
              return order;
          }
        });
        logger.d(
          '[SaleOrderForm]',
          'Synced $fieldName to cache: order=$orderId, value=$value',
        );

      default:
        // Log other field updates but don't sync to cache
        logger.d(
          '[SaleOrderForm]',
          'Field updated (not cached): order=$orderId, $fieldName=$value',
        );
    }
  }

  // ==========================================================================
  // METODOS DE UTILIDAD
  // ==========================================================================
  // Movidos a sale_order_form_mixins/sale_order_utility_mixin.dart (Fase E2b):
  // clearState, discardChanges, refreshOrder, updateOrderFromSync.
  // ==========================================================================

  // ==========================================================================
  // SERVER UPDATE PENDING (Phase 3 - Step 2)
  // ==========================================================================
  // Movidos a sale_order_form_mixins/sale_order_conflict_mixin.dart.
  // Fase E2b (AREA DE RIESGO ALTO, copy-paste literal): setServerUpdatePending,
  // applyPendingServerUpdate, _applyMergeableFields, _applyPendingLinesMerge,
  // clearServerUpdatePending, clearError.
  // Fase F2 (unificación con METODOS DE RESOLUCION DE CONFLICTOS, ver ese
  // mixin para el diseño completo): se eliminó la duplicación
  // _clearPendingState/clearServerUpdatePending y el código muerto
  // resolveConflictsWithServer/resolveConflictsWithLocal/detectConflictsWithServer
  // (verificado sin consumidores). API pública externa sin cambios.
  // ==========================================================================

  // ==========================================================================
  // METODOS DE ELIMINACION Y ACTUALIZACION DE ESTADO DE ORDEN
  // ==========================================================================
  // Movidos a sale_order_form_mixins/sale_order_state_mixin.dart (Fase E2b):
  // deleteOrder, updateOrderLocked, updateOrderState, updateOrderLockedById,
  // updateOrderStateById.
  // ==========================================================================

  // ==========================================================================
  // METODOS DE RESOLUCION DE CONFLICTOS
  // ==========================================================================
  // Movidos a sale_order_form_mixins/sale_order_conflict_mixin.dart (fusionado
  // con SERVER UPDATE PENDING en Fase F2, ver ese archivo para el diseño
  // completo): acceptServerChanges, keepLocalChanges, clearConflict.
  // ==========================================================================

  // ==========================================================================
  // METODOS DE VALIDACION DE CREDITO
  // ==========================================================================
  // Movidos a sale_order_form_mixins/sale_order_credit_validation_mixin.dart
  // (Fase E2b): validateCreditForUI, validateCreditForSave (renombrado de
  // _validateCredit — ver nota en el mixin), _validateCreditWithClientService,
  // _validateCreditLegacy, _buildCreditErrorMessage, bypassCreditCheck,
  // resetCreditValidation.
  // ==========================================================================
}

/// Helper para ejecutar Future sin esperar (similar a unawaited de dart:async)
void unawaited(Future<void>? future) {}
