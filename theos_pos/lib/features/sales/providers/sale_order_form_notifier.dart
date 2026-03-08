import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide SaleOrderLineManager;
import '../../../core/database/repositories/repository_providers.dart';
import '../../clients/clients.dart'
    show
        Client,
        CreditCheckType,
        clientCreditServiceProvider,
        clientRepositoryProvider,
        clientValidationProvider,
        CreditValidationResult;
// Hide generated SaleOrderLineManager - we use the mixin
import '../services/conflict_detection_service.dart';
import '../services/credit_validation_ui_service.dart' show UnifiedCreditResult;
import '../utils/partner_utils.dart' as partner_utils;
import 'service_providers.dart' show orderServiceProvider;
import 'order_cache_provider.dart';
import 'sale_order_field_updater.dart';
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
    with SaleOrderFieldUpdater, SaleOrderLineManager {
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
  /// Only syncs if:
  /// - We have an order loaded
  /// - We're not in editing mode (to preserve local changes)
  /// - The cached order differs from our current order
  void _syncFromCache(OrderCacheState cache) {
    logger.d('[SaleOrderForm]', '>>> _syncFromCache CALLED');

    final currentOrder = state.order;
    if (currentOrder == null) {
      logger.d('[SaleOrderForm]', '>>> _syncFromCache: No current order, skipping');
      return;
    }

    // Don't sync during editing to preserve local changes
    if (state.isEditing) {
      logger.d('[SaleOrderForm]', '>>> _syncFromCache: isEditing=true, skipping');
      return;
    }

    final cachedOrder = cache.orders[currentOrder.id];
    if (cachedOrder == null) {
      logger.d('[SaleOrderForm]', '>>> _syncFromCache: No cached order for ${currentOrder.id}, skipping');
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
    final cachedLines = cache.orderLines[currentOrder.id];
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

  // ==========================================================================
  // METODOS DE CARGA
  // ==========================================================================

  /// Inicializar formulario con datos ya disponibles (sin loading)
  ///
  /// Usa esto cuando ya tienes los datos de la orden (ej: del modo vista)
  /// para evitar el estado de loading y transición instantánea.
  void initFromData(SaleOrder order, List<SaleOrderLine> lines) {
    if (state.order?.id == order.id && !state.isLoading) {
      logger.d('[SaleOrderForm]', 'Orden ${order.id} ya inicializada');
      return;
    }

    logger.i('[SaleOrderForm]', 'Inicializando desde datos: ${order.name}');

    state = state.copyWith(
      isLoading: false,
      order: order,
      lines: lines,
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
      // Campos de consumidor final (l10n_ec_sale_base)
      // Calcular isFinalConsumer desde partnerVat si el campo de Odoo es false
      isFinalConsumer:
          order.isFinalConsumer || order.partnerVat == '9999999999999',
      endCustomerName: order.endCustomerName,
      endCustomerPhone: order.endCustomerPhone,
      endCustomerEmail: order.endCustomerEmail,
      // Campos de facturación postfechada (l10n_ec_sale_base)
      emitirFacturaFechaPosterior: order.emitirFacturaFechaPosterior,
      fechaFacturar: order.fechaFacturar,
      // Campos de referidor (l10n_ec_sale_base)
      referrerId: order.referrerId,
      referrerName: order.referrerName,
      // Campos de tipo/canal cliente (l10n_ec_sale_base)
      tipoCliente: order.tipoCliente,
      canalCliente: order.canalCliente,
      hasChanges: false,
      changedFields: {},
      deletedLineIds: [],
      newLines: [],
      updatedLines: [],
      errorMessage: null,
    );

    // Cargar datos de selección en segundo plano
    unawaited(loadSelectionData());
  }

  /// Cargar una orden existente para edicion
  ///
  /// [orderId] - ID de la orden a cargar
  /// [forceRefresh] - Si es true, fuerza recarga desde el servidor.
  ///                  Por defecto es false para usar cache local (más rápido).
  Future<void> loadOrder(int orderId, {bool forceRefresh = false}) async {
    // ID=0 es invalido, pero IDs negativos son validos para ordenes offline
    if (orderId == 0) {
      state = state.copyWith(errorMessage: 'ID de orden invalido');
      return;
    }

    // Si ya tenemos esta orden cargada y no se fuerza refresh, no recargar
    if (!forceRefresh &&
        state.order != null &&
        state.order!.id == orderId &&
        !state.isLoading) {
      logger.d('[SaleOrderForm]', 'Orden $orderId ya cargada, usando cache');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final repo = ref.read(salesRepositoryProvider);
      if (repo == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Repositorio no disponible',
        );
        return;
      }

      // Obtener orden con lineas (usa cache local por defecto)
      final result = await repo.getWithLines(
        orderId,
        forceRefresh: forceRefresh,
      );
      final order = result.$1;
      final lines = result.$2;

      if (order == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Orden no encontrada',
        );
        return;
      }

      // OFFLINE-FIRST: No bloquear la carga de la orden esperando datos de Odoo
      // Cargar terminos de pago autorizados del partner en background
      List<int> partnerPaymentTermIds = [];
      if (order.partnerId != null) {
        // Load in background - don't await
        unawaited(() async {
          final ids = await _loadPartnerPaymentTermIds(order.partnerId!);
          if (ids.isNotEmpty && state.order?.id == orderId) {
            // Only update if we're still viewing the same order
            state = state.copyWith(partnerPaymentTermIds: ids);
          }
        }());
      }

      // Actualizar estado con datos de la orden
      state = state.copyWith(
        isLoading: false,
        isEditing: false, // Always exit edit mode when loading/reloading
        order: order,
        lines: lines,
        // Campos del formulario desde la orden
        partnerId: order.partnerId,
        partnerName: order.partnerName,
        partnerVat: order.partnerVat,
        partnerStreet: order.partnerStreet,
        partnerPhone: order.partnerPhone,
        partnerEmail: order.partnerEmail,
        partnerPaymentTermIds: partnerPaymentTermIds,
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
        // Campos de consumidor final (l10n_ec_sale_base)
        // Calcular isFinalConsumer desde partnerVat si el campo de Odoo es false
        // (porque la DB local no tiene ese campo)
        isFinalConsumer:
            order.isFinalConsumer || order.partnerVat == '9999999999999',
        endCustomerName: order.endCustomerName,
        endCustomerPhone: order.endCustomerPhone,
        endCustomerEmail: order.endCustomerEmail,
        // Campos de facturación postfechada (l10n_ec_sale_base)
        emitirFacturaFechaPosterior: order.emitirFacturaFechaPosterior,
        fechaFacturar: order.fechaFacturar,
        // Campos de referidor (l10n_ec_sale_base)
        referrerId: order.referrerId,
        referrerName: order.referrerName,
        // Campos de tipo/canal cliente (l10n_ec_sale_base)
        tipoCliente: order.tipoCliente,
        canalCliente: order.canalCliente,
        // Resetear rastreo de cambios
        hasChanges: false,
        changedFields: {},
        deletedLineIds: [],
        newLines: [],
        updatedLines: [],
        errorMessage: null,
      );

      logger.i(
        '[SaleOrderForm]',
        'Orden ${order.name} cargada con ${lines.length} lineas',
      );

      // Cache order in unified cache (single source of truth)
      ref.read(orderCacheProvider.notifier).cacheOrder(order, lines: lines);

      // Cargar configuraciones de empresa en segundo plano
      unawaited(_loadCompanySettings());

      // Cargar datos de seleccion en segundo plano
      unawaited(loadSelectionData());
    } catch (e, stack) {
      logger.e('[SaleOrderForm]', 'Error cargando orden', e, stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al cargar la orden: $e',
      );
    }
  }

  /// Inicializar formulario para nueva orden
  ///
  /// Usa OrderService para crear la orden con valores por defecto unificados,
  /// garantizando consistencia con FastSale (POS).
  ///
  /// Opcionalmente puede recibir valores iniciales que sobreescriben los defaults
  Future<void> initNewOrder({
    int? partnerId,
    String? partnerName,
    int? pricelistId,
    int? warehouseId,
    int? userId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Step 1: Use OrderService for unified order creation
      final orderService = ref.read(orderServiceProvider);
      final baseOrder = await orderService.createOrder(
        partnerId: partnerId,
        partnerName: partnerName,
        pricelistId: pricelistId,
        warehouseId: warehouseId,
        userId: userId,
      );

      logger.d(
        '[SaleOrderForm]',
        'Order created via OrderService: partner=${baseOrder.partnerId}, '
            'pricelist=${baseOrder.pricelistId}, warehouse=${baseOrder.warehouseId}',
      );

      // Step 2: Apply form-specific state updates
      state = state.copyWith(
        isLoading: false,
        order: null,
        lines: [],
        // Campos del formulario desde el order unificado
        partnerId: baseOrder.partnerId,
        partnerName: baseOrder.partnerName,
        paymentTermId: baseOrder.paymentTermId,
        paymentTermName: baseOrder.paymentTermName,
        pricelistId: baseOrder.pricelistId,
        pricelistName: baseOrder.pricelistName,
        warehouseId: baseOrder.warehouseId,
        warehouseName: baseOrder.warehouseName,
        userId: baseOrder.userId,
        userName: baseOrder.userName,
        dateOrder: baseOrder.dateOrder ?? DateTime.now(),
        validityDate: (baseOrder.dateOrder ?? DateTime.now()).add(
          const Duration(days: 30),
        ),
        commitmentDate: null,
        clientOrderRef: null,
        note: null,
        // Estado inicial
        hasChanges: baseOrder.partnerId != null,
        changedFields: baseOrder.partnerId != null
            ? {'partner_id': baseOrder.partnerId}
            : {},
        deletedLineIds: [],
        newLines: [],
        updatedLines: [],
        errorMessage: null,
      );

      logger.i(
        '[SaleOrderForm]',
        'Nueva orden inicializada via OrderService: partner=${baseOrder.partnerId}',
      );

      // Step 3: Cargar configuraciones de empresa
      await _loadCompanySettings();

      // Step 4: Cargar datos de seleccion
      await loadSelectionData();

      // Step 5: Resolver nombres que puedan faltar
      _resolveDefaultNames(
        paymentTermId: baseOrder.paymentTermId,
        warehouseId: baseOrder.warehouseId,
        pricelistId: baseOrder.pricelistId,
      );

      // Step 6: Si tenemos un partner, cargar sus datos completos
      if (baseOrder.partnerId != null) {
        await _loadPartnerData(baseOrder.partnerId!);
      }

      // Step 7: (Optional) Sync with Odoo in background for missing fields
      _syncDefaultsFromOdooInBackground(baseOrder);
    } catch (e, stack) {
      logger.e('[SaleOrderForm]', 'Error inicializando nueva orden', e, stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al inicializar nueva orden: $e',
      );
    }
  }

  /// Background sync of defaults from Odoo (non-blocking)
  ///
  /// Updates missing fields from Odoo if they were null locally.
  void _syncDefaultsFromOdooInBackground(SaleOrder baseOrder) async {
    try {
      final orderService = ref.read(orderServiceProvider);
      final updatedOrder = await orderService.syncDefaultsFromOdoo(baseOrder);

      if (updatedOrder != null && mounted) {
        // Apply updated fields to form state
        state = state.copyWith(
          pricelistId: updatedOrder.pricelistId ?? state.pricelistId,
          pricelistName: updatedOrder.pricelistName ?? state.pricelistName,
          paymentTermId: updatedOrder.paymentTermId ?? state.paymentTermId,
          paymentTermName:
              updatedOrder.paymentTermName ?? state.paymentTermName,
        );
        logger.i('[SaleOrderForm]', 'Form updated with Odoo defaults');
      }
    } catch (e) {
      // Silent failure - background sync shouldn't affect user experience
      logger.d('[SaleOrderForm]', 'Background sync skipped: $e');
    }
  }

  /// Check if notifier is still mounted
  bool get mounted =>
      true; // In Riverpod, notifiers are always mounted while ref is valid

  /// Cargar datos del partner (nombre, VAT, etc.) usando repositorio de ventas
  Future<void> _loadPartnerData(int partnerId) async {
    try {
      final partnerRepo = ref.read(partnerRepositoryProvider);
      if (partnerRepo == null) return;

      // Buscar partner por ID usando el método de búsqueda de partners del partner repo
      final partners = await partnerRepo.searchPartners(partnerId: partnerId);
      if (partners.isNotEmpty) {
        final partner = partners.first;
        // Helper para convertir valores de Odoo (false -> null)
        String? getString(dynamic value) => value is String ? value : null;

        // Obtener el término de pago por defecto del partner
        int? partnerPaymentTermId;
        String? partnerPaymentTermName;
        final paymentTermData = partner['property_payment_term_id'];
        if (paymentTermData != null && paymentTermData != false) {
          if (paymentTermData is List && paymentTermData.isNotEmpty) {
            partnerPaymentTermId = paymentTermData[0] as int?;
            partnerPaymentTermName = paymentTermData.length > 1
                ? paymentTermData[1] as String?
                : null;
          } else if (paymentTermData is int) {
            partnerPaymentTermId = paymentTermData;
            // Buscar el nombre en la lista de términos de pago
            if (state.paymentTerms.isNotEmpty) {
              final found = state.paymentTerms.firstWhere(
                (pt) => pt['id'] == partnerPaymentTermId,
                orElse: () => <String, dynamic>{},
              );
              if (found.isNotEmpty) {
                partnerPaymentTermName = found['name'] as String?;
              }
            }
          }
        }

        // Extraer terminos_pagos_ids (puede venir como false, null, [] o [1, 2, 3])
        List<int> paymentTermIds = [];
        final terminosPagosRaw = partner['terminos_pagos_ids'];
        if (terminosPagosRaw != null &&
            terminosPagosRaw != false &&
            terminosPagosRaw is List) {
          paymentTermIds = List<int>.from(terminosPagosRaw.whereType<int>());
        }

        logger.d(
          '[SaleOrderForm]',
          'Partner terminos_pagos_ids raw: $terminosPagosRaw, parsed: $paymentTermIds',
        );

        state = state.copyWith(
          partnerName: getString(partner['name']),
          partnerVat: getString(partner['vat']),
          partnerStreet: getString(partner['street']),
          partnerPhone: getString(partner['phone']),
          partnerEmail: getString(partner['email']),
          partnerAvatar: getString(partner['image_128']),
          partnerPaymentTermIds: paymentTermIds,
          // Actualizar término de pago si el partner tiene uno configurado
          paymentTermId: partnerPaymentTermId ?? state.paymentTermId,
          paymentTermName: partnerPaymentTermName ?? state.paymentTermName,
        );

        logger.d(
          '[SaleOrderForm]',
          'Partner data loaded: name=${partner['name']}, paymentTermId=$partnerPaymentTermId, paymentTermIds=$paymentTermIds',
        );
      }
    } catch (e) {
      logger.w('[SaleOrderForm]', 'Error loading partner data: $e');
    }
  }

  /// Actualizar teléfono del partner (para facturación electrónica Ecuador)
  ///
  /// Actualiza el estado local y envía el cambio a Odoo
  Future<void> updatePartnerPhone(String phone) async {
    if (state.partnerId == null) return;

    final oldPhone = state.partnerPhone;

    // Actualizar estado local inmediatamente
    state = state.copyWith(partnerPhone: phone);

    final partnerRepo = ref.read(partnerRepositoryProvider);
    if (partnerRepo == null) return;

    await partner_utils.updatePartnerField(
      partnerId: state.partnerId!,
      fieldName: 'phone',
      newValue: phone,
      partnerRepo: partnerRepo,
      logTag: '[SaleOrderForm]',
      onFailure: (error) {
        // Revertir estado si falla
        state = state.copyWith(partnerPhone: oldPhone);
      },
    );
  }

  /// Actualizar email del partner (para facturación electrónica Ecuador)
  ///
  /// Actualiza el estado local y envía el cambio a Odoo
  Future<void> updatePartnerEmail(String email) async {
    if (state.partnerId == null) return;

    final oldEmail = state.partnerEmail;

    // Actualizar estado local inmediatamente
    state = state.copyWith(partnerEmail: email);

    final partnerRepo = ref.read(partnerRepositoryProvider);
    if (partnerRepo == null) return;

    await partner_utils.updatePartnerField(
      partnerId: state.partnerId!,
      fieldName: 'email',
      newValue: email,
      partnerRepo: partnerRepo,
      logTag: '[SaleOrderForm]',
      onFailure: (error) {
        // Revertir estado si falla
        state = state.copyWith(partnerEmail: oldEmail);
      },
    );
  }

  /// Cargar datos de seleccion (listas desplegables)
  ///
  /// Carga en paralelo: paymentTerms, pricelists, warehouses, salespeople
  /// Resolver nombres basándose en los IDs por defecto
  /// Busca en las listas cargadas (paymentTerms, warehouses, pricelists) los nombres correspondientes
  void _resolveDefaultNames({
    int? paymentTermId,
    int? warehouseId,
    int? pricelistId,
  }) {
    String? paymentTermName;
    String? warehouseName;
    String? pricelistName;

    // Buscar nombre del término de pago
    if (paymentTermId != null && state.paymentTerms.isNotEmpty) {
      final found = state.paymentTerms.firstWhere(
        (pt) => pt['id'] == paymentTermId,
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) {
        paymentTermName = found['name'] as String?;
      }
    }

    // Buscar nombre del almacén
    if (warehouseId != null && state.warehouses.isNotEmpty) {
      final found = state.warehouses.firstWhere(
        (w) => w['id'] == warehouseId,
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) {
        warehouseName = found['name'] as String?;
      }
    }

    // Buscar nombre de la lista de precios
    if (pricelistId != null && state.pricelists.isNotEmpty) {
      final found = state.pricelists.firstWhere(
        (pl) => pl['id'] == pricelistId,
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) {
        pricelistName = found['name'] as String?;
      }
    }

    // Actualizar estado con los nombres encontrados
    if (paymentTermName != null ||
        warehouseName != null ||
        pricelistName != null) {
      state = state.copyWith(
        paymentTermName: paymentTermName ?? state.paymentTermName,
        warehouseName: warehouseName ?? state.warehouseName,
        pricelistName: pricelistName ?? state.pricelistName,
      );
      logger.d(
        '[SaleOrderForm]',
        'Nombres resueltos: paymentTerm=$paymentTermName, warehouse=$warehouseName, pricelist=$pricelistName',
      );
    }
  }

  Future<void> loadSelectionData() async {
    if (state.isLoadingSelectionData) return;

    state = state.copyWith(isLoadingSelectionData: true);

    try {
      final partnerRepo = ref.read(partnerRepositoryProvider);
      if (partnerRepo == null) {
        state = state.copyWith(isLoadingSelectionData: false);
        return;
      }

      // Cargar datos en paralelo
      final results = await Future.wait(<Future<dynamic>>[
        partnerRepo.getPaymentTerms(),
        partnerRepo.getPricelists(),
        _loadWarehouses(),
        partnerRepo.getSalespeople(),
      ]);

      state = state.copyWith(
        isLoadingSelectionData: false,
        paymentTerms: results[0],
        pricelists: results[1],
        warehouses: results[2],
        salespeople: results[3],
      );
    } catch (e) {
      logger.e('[SaleOrderForm]', 'Error cargando datos de seleccion', e);
      state = state.copyWith(isLoadingSelectionData: false);
    }
  }

  /// Cargar almacenes desde CommonRepository
  Future<List<Map<String, dynamic>>> _loadWarehouses() async {
    try {
      final commonRepo = ref.read(commonRepositoryProvider);
      if (commonRepo == null) return [];

      final warehouses = await commonRepo.getWarehouses();
      return warehouses
          .map((w) => {'id': w.id, 'name': w.name, 'code': w.code})
          .toList();
    } catch (e) {
      logger.e('[SaleOrderForm]', 'Error cargando almacenes', e);
      return [];
    }
  }

  /// Cargar terminos de pago autorizados del partner desde Odoo
  Future<List<int>> _loadPartnerPaymentTermIds(int partnerId) async {
    return partner_utils.loadPartnerPaymentTermIds(
      partnerId: partnerId,
      odooClient: ref.read(odooClientProvider),
      logTag: '[SaleOrderForm]',
    );
  }

  /// Cargar configuraciones de empresa (pedir_sale_referrer, pedir_tipo_canal_cliente)
  Future<void> _loadCompanySettings() async {
    try {
      final companyRepo = ref.read(companyRepositoryProvider);
      if (companyRepo == null) return;

      final company = await companyRepo.getCurrentUserCompany();
      if (company == null) return;

      state = state.copyWith(
        companyRequiresEndCustomerData: company.pedirEndCustomerData,
        companyRequiresReferrer: company.pedirSaleReferrer,
        companyRequiresTipoCanalCliente: company.pedirTipoCanalCliente,
        saleCustomerInvoiceLimitSri: company.saleCustomerInvoiceLimitSri ?? 0.0,
      );

      logger.d(
        '[SaleOrderForm]',
        'Company settings loaded: requiresEndCustomerData=${company.pedirEndCustomerData}, '
            'requiresReferrer=${company.pedirSaleReferrer}, '
            'requiresTipoCanalCliente=${company.pedirTipoCanalCliente}, '
            'saleCustomerInvoiceLimitSri=${company.saleCustomerInvoiceLimitSri}',
      );
    } catch (e) {
      logger.w('[SaleOrderForm]', 'Error loading company settings: $e');
    }
  }

  // ==========================================================================
  // METODOS DE GUARDADO
  // ==========================================================================

  /// Guardar la orden (crear o actualizar)
  ///
  /// [skipCreditCheck] - Si true, omite la validación de crédito interna.
  /// Útil cuando la validación ya se realizó en la UI y el usuario
  /// eligió proceder (bypass o después de aprobación).
  ///
  /// Retorna el ID de la orden guardada, o null si falla
  Future<int?> saveOrder({bool skipCreditCheck = false}) async {
    if (state.partnerId == null) {
      state = state.copyWith(errorMessage: 'Debe seleccionar un cliente');
      return null;
    }

    // Validación de consumidor final (replica _check_final_consumer_name de Odoo)
    // Si el partner es consumidor final (VAT 9999999999999), end_customer_name es obligatorio
    if (state.isFinalConsumer &&
        (state.endCustomerName == null ||
            state.endCustomerName!.trim().isEmpty)) {
      state = state.copyWith(
        errorMessage:
            'El nombre del consumidor final es obligatorio cuando se marca como Consumidor Final.',
      );
      return null;
    }

    // Validación de facturación postfechada (replica _check_fecha_facturar de Odoo)
    if (state.emitirFacturaFechaPosterior) {
      if (state.fechaFacturar == null) {
        state = state.copyWith(
          errorMessage:
              'Debe especificar la fecha de facturación cuando se activa facturación postfechada.',
        );
        return null;
      }

      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final fechaOnly = DateTime(
        state.fechaFacturar!.year,
        state.fechaFacturar!.month,
        state.fechaFacturar!.day,
      );

      if (fechaOnly.isBefore(todayOnly)) {
        state = state.copyWith(
          errorMessage: 'La fecha de facturación no puede ser anterior a hoy.',
        );
        return null;
      }

      final maxDays = state.diasMaxFacturaPosterior;
      final maxDate = todayOnly.add(Duration(days: maxDays));
      if (fechaOnly.isAfter(maxDate)) {
        state = state.copyWith(
          errorMessage:
              'La fecha de facturación no puede exceder $maxDays días desde hoy.',
        );
        return null;
      }
    }

    // Validación de referidor (replica _compute_required_referrer de Odoo)
    if (state.companyRequiresReferrer && state.referrerId == null) {
      state = state.copyWith(
        errorMessage:
            'El referidor es obligatorio según la configuración de la empresa.',
      );
      return null;
    }

    // Validación de tipo/canal cliente (replica _compute_required_tipo_canal_cliente de Odoo)
    if (state.companyRequiresTipoCanalCliente) {
      if (state.tipoCliente == null || state.tipoCliente!.isEmpty) {
        state = state.copyWith(
          errorMessage:
              'El tipo de cliente es obligatorio según la configuración de la empresa.',
        );
        return null;
      }
      if (state.canalCliente == null || state.canalCliente!.isEmpty) {
        state = state.copyWith(
          errorMessage:
              'El canal de cliente es obligatorio según la configuración de la empresa.',
        );
        return null;
      }
    }

    // Validación de crédito (OFFLINE-FIRST)
    // Solo validar si no se ha bypassed Y no se pide skipCreditCheck
    if (!state.creditCheckBypassed && !skipCreditCheck) {
      final creditResult = await _validateCredit();
      if (creditResult != null && !creditResult.isValid) {
        // El mensaje de error ya fue establecido en _validateCredit
        return null;
      }
    }

    if (state.isSaving) return null;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final salesRepo = ref.read(salesRepositoryProvider);

      if (salesRepo == null) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Repositorio no disponible',
        );
        return null;
      }

      int? orderId;

      if (state.isNewMode) {
        // Crear nueva orden
        orderId = await _createNewOrder(salesRepo);
      } else {
        // Actualizar orden existente
        orderId = await _updateExistingOrder(salesRepo);
      }

      if (orderId != null) {
        if (state.isNewMode) {
          // Orden nueva - cargar desde DB local para obtener ID y nombre asignados
          // forceRefresh: false lee de DB local, no de Odoo
          await loadOrder(orderId, forceRefresh: false);
        } else {
          // Orden existente - consolidar cambios en memoria sin recargar
          // Esto evita flicker y funciona tanto online como offline
          await _consolidateChangesAfterSave();
        }
        // Asegurar que isSaving se resetea
        state = state.copyWith(isSaving: false);
        logger.i('[SaleOrderForm]', 'Orden guardada exitosamente: ID=$orderId');
      } else {
        // Si orderId es null, también resetear isSaving
        state = state.copyWith(isSaving: false);
      }

      return orderId;
    } catch (e, stack) {
      logger.e('[SaleOrderForm]', 'Error guardando orden', e, stack);
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Error al guardar la orden: $e',
      );
      return null;
    }
  }

  /// Crear nueva orden en el servidor (o localmente si está offline)
  Future<int?> _createNewOrder(dynamic salesRepo) async {
    // Preparar valores para crear orden
    final vals = _prepareOrderValues();

    // Crear orden con campos esenciales para soporte offline
    final orderId = await salesRepo.create(
      partnerId: state.partnerId!,
      warehouseId: state.warehouseId,
      userId: state.userId,
      userName: state.userName,
      pricelistId: state.pricelistId,
      paymentTermId: state.paymentTermId,
    );
    if (orderId == null) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Error al crear la orden',
      );
      return null;
    }

    // Actualizar campos adicionales si hay (tanto online como offline)
    // Campos como end_customer_name, is_final_consumer, referrer_id no están en create()
    vals.remove('partner_id');
    vals.remove('warehouse_id');
    vals.remove('user_id');
    vals.remove('pricelist_id');
    vals.remove('payment_term_id');
    if (vals.isNotEmpty) {
      logger.d(
        '[SaleOrderForm]',
        'Updating additional fields for new order $orderId: $vals',
      );
      await salesRepo.update(orderId, vals);
    }

    // Crear lineas
    for (final line in state.newLines) {
      final lineWithOrderId = line.copyWith(orderId: orderId);
      await salesRepo.addLine(orderId, lineWithOrderId);
    }

    return orderId;
  }

  /// Actualizar orden existente en el servidor
  Future<int?> _updateExistingOrder(dynamic salesRepo) async {
    final orderId = state.order!.id;

    logger.d(
      '[SaleOrderForm]',
      'Updating order $orderId: '
          'changedFields=${state.changedFields.keys}, '
          'deletedLines=${state.deletedLineIds.length}, '
          'updatedLines=${state.updatedLines.length}, '
          'newLines=${state.newLines.length}',
    );

    // Preparar valores para actualizar
    final vals = _prepareOrderValues();

    // Solo actualizar si hay cambios en los campos de la orden
    if (vals.isNotEmpty) {
      logger.d('[SaleOrderForm]', 'Updating order fields: $vals');
      final success = await salesRepo.update(orderId, vals);
      if (!success) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Error al actualizar la orden',
        );
        return null;
      }
    }

    // Eliminar lineas marcadas
    for (final lineId in state.deletedLineIds) {
      logger.d('[SaleOrderForm]', 'Deleting line: $lineId');
      await salesRepo.deleteLine(lineId);
    }

    // Actualizar lineas modificadas
    for (final line in state.updatedLines) {
      // Use saleOrderLineManager.toOdoo() to include calculated fields (price_subtotal, price_tax, price_total)
      // The repository will exclude these when syncing to Odoo
      final lineVals = saleOrderLineManager.toOdoo(line);
      logger.d('[SaleOrderForm]', 'Updating line ${line.id}: $lineVals');
      await salesRepo.updateLine(line.id, lineVals);
    }

    // Crear nuevas lineas
    for (final line in state.newLines) {
      final lineWithOrderId = line.copyWith(orderId: orderId);
      logger.d(
        '[SaleOrderForm]',
        'Creating new line: productId=${line.productId}, qty=${line.productUomQty}',
      );
      await salesRepo.addLine(orderId, lineWithOrderId);
    }

    return orderId;
  }

  /// Consolidar cambios después de guardar sin recargar de la DB
  ///
  /// Esto actualiza state.lines con los cambios de updatedLines y newLines,
  /// elimina las líneas marcadas, y resetea el tracking de cambios.
  /// Evita el flicker causado por recargar toda la orden.
  Future<void> _consolidateChangesAfterSave() async {
    // Construir nueva lista de líneas consolidada
    final consolidatedLines = <SaleOrderLine>[];

    // 1. Agregar líneas existentes (con updates aplicados, excluyendo eliminadas)
    for (final line in state.lines) {
      if (state.deletedLineIds.contains(line.id)) continue;

      // Buscar si hay una versión actualizada
      final updated = state.updatedLines.firstWhere(
        (l) => l.id == line.id,
        orElse: () => line,
      );
      consolidatedLines.add(updated);
    }

    // 2. Agregar nuevas líneas (ya tienen IDs asignados por el servidor o temporales)
    consolidatedLines.addAll(state.newLines);

    // 3. Ordenar por secuencia
    consolidatedLines.sort((a, b) => a.sequence.compareTo(b.sequence));

    // 4. Actualizar state.order con los campos del formulario si cambiaron
    // Leer el estado de isSynced desde la base de datos (puede haber cambiado si estamos offline)
    final salesRepo = ref.read(salesRepositoryProvider);
    final freshOrder = await salesRepo?.getById(
      state.order!.id,
      forceRefresh: false,
    );
    final isSynced = freshOrder?.isSynced ?? state.order!.isSynced;

    final updatedOrder = state.order?.copyWith(
      partnerId: state.partnerId,
      partnerName: state.partnerName,
      partnerVat: state.partnerVat,
      partnerStreet: state.partnerStreet,
      partnerPhone: state.partnerPhone,
      partnerEmail: state.partnerEmail,
      paymentTermId: state.paymentTermId,
      paymentTermName: state.paymentTermName,
      pricelistId: state.pricelistId,
      pricelistName: state.pricelistName,
      warehouseId: state.warehouseId,
      warehouseName: state.warehouseName,
      userId: state.userId,
      userName: state.userName,
      dateOrder: state.dateOrder,
      validityDate: state.validityDate,
      commitmentDate: state.commitmentDate,
      clientOrderRef: state.clientOrderRef,
      note: state.note,
      isSynced: isSynced,
    );

    // 5. Actualizar estado: consolidar líneas y salir de modo edición
    state = state.copyWith(
      isEditing: false,
      order: updatedOrder,
      lines: consolidatedLines,
      // Resetear tracking de cambios
      hasChanges: false,
      changedFields: {},
      deletedLineIds: [],
      newLines: [],
      updatedLines: [],
    );

    logger.d(
      '[SaleOrderForm]',
      'Changes consolidated: ${consolidatedLines.length} lines',
    );
  }

  /// Preparar valores para enviar a Odoo
  Map<String, dynamic> _prepareOrderValues() {
    final vals = <String, dynamic>{};

    // Solo incluir campos que han cambiado
    for (final entry in state.changedFields.entries) {
      final fieldName = entry.key;
      final rawValue = entry.value;

      // Soporte para ambos formatos:
      // - Valor directo: {'partner_id': 123}
      // - Map con 'new': {'partner_id': {'old': null, 'new': 123}}
      final dynamic newValue;
      if (rawValue is Map<String, dynamic>) {
        newValue = rawValue['new'];
      } else {
        newValue = rawValue;
      }

      switch (fieldName) {
        case 'partner_id':
          if (newValue != null) vals['partner_id'] = newValue;
          break;
        case 'payment_term_id':
          vals['payment_term_id'] = newValue ?? false;
          break;
        case 'pricelist_id':
          vals['pricelist_id'] = newValue ?? false;
          break;
        case 'warehouse_id':
          vals['warehouse_id'] = newValue ?? false;
          break;
        case 'user_id':
          vals['user_id'] = newValue ?? false;
          break;
        case 'date_order':
          if (newValue != null) {
            vals['date_order'] = formatOdooDateTime(newValue as DateTime);
          }
          break;
        case 'validity_date':
          if (newValue != null) {
            vals['validity_date'] = formatOdooDate(newValue as DateTime);
          } else {
            vals['validity_date'] = false;
          }
          break;
        case 'commitment_date':
          if (newValue != null) {
            vals['commitment_date'] = formatOdooDateTime(
              newValue as DateTime,
            );
          } else {
            vals['commitment_date'] = false;
          }
          break;
        case 'client_order_ref':
          vals['client_order_ref'] = newValue ?? false;
          break;
        case 'note':
          vals['note'] = newValue ?? false;
          break;
        // Campos de consumidor final (l10n_ec_sale_base)
        case 'is_final_consumer':
          vals['is_final_consumer'] = newValue ?? false;
          break;
        case 'end_customer_name':
          vals['end_customer_name'] = newValue ?? false;
          break;
        case 'end_customer_phone':
          vals['end_customer_phone'] = newValue ?? false;
          break;
        case 'end_customer_email':
          vals['end_customer_email'] = newValue ?? false;
          break;
        // Campos de facturación postfechada (l10n_ec_sale_base)
        case 'emitir_factura_fecha_posterior':
          vals['emitir_factura_fecha_posterior'] = newValue ?? false;
          break;
        case 'fecha_facturar':
          if (newValue != null) {
            vals['fecha_facturar'] = formatOdooDate(newValue as DateTime);
          } else {
            vals['fecha_facturar'] = false;
          }
          break;
        // Campos de referidor (l10n_ec_sale_base)
        case 'referrer_id':
          vals['referrer_id'] = newValue ?? false;
          break;
        // Campos de tipo/canal cliente (l10n_ec_sale_base)
        case 'tipo_cliente':
          vals['tipo_cliente'] = newValue ?? false;
          break;
        case 'canal_cliente':
          vals['canal_cliente'] = newValue ?? false;
          break;
      }
    }

    // IMPORTANTE: Siempre enviar is_final_consumer y end_customer_name si es consumidor final
    // Esto asegura que Odoo valide correctamente incluso si los campos no cambiaron
    if (state.isFinalConsumer) {
      vals['is_final_consumer'] = true;
      if (state.endCustomerName != null && state.endCustomerName!.isNotEmpty) {
        vals['end_customer_name'] = state.endCustomerName;
      }
      if (state.endCustomerPhone != null &&
          state.endCustomerPhone!.isNotEmpty) {
        vals['end_customer_phone'] = state.endCustomerPhone;
      }
      if (state.endCustomerEmail != null &&
          state.endCustomerEmail!.isNotEmpty) {
        vals['end_customer_email'] = state.endCustomerEmail;
      }
    }

    return vals;
  }

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
    logger.d('[SaleOrderForm]', '>>> onFieldUpdated: orderId=$orderId, field=$fieldName');
    final cache = ref.read(orderCacheProvider.notifier);

    switch (fieldName) {
      case 'partner':
        // Partner is a composite field with multiple values
        final data = value as Map<String, dynamic>;
        logger.d('[SaleOrderForm]', '>>> Updating cache with partner: ${data['partner_name']} (${data['partner_id']})');
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

  // ==========================================================================
  // SERVER UPDATE PENDING (Phase 3 - Step 2)
  // ==========================================================================

  /// Mark that a server update arrived while in edit mode.
  ///
  /// Stores the pending data so it can be applied later (when the user
  /// clicks the sync indicator or exits edit mode).
  void setServerUpdatePending(SaleOrder order, List<SaleOrderLine>? lines) {
    logger.i(
      '[SaleOrderForm]',
      'Server update pending for order ${order.id} (user is editing)',
    );
    state = state.copyWith(
      serverUpdatePending: true,
      pendingServerOrder: order,
      pendingServerLines: lines,
    );
  }

  /// Apply the pending server update with fine-grained field merging.
  ///
  /// Called when the user clicks the pending-update indicator, or
  /// automatically when exiting edit mode.
  ///
  /// **Merge strategy:**
  /// - View mode (not editing): full overwrite via [updateOrderFromSync]
  /// - Edit mode, no conflicts: auto-merge server-changed fields that the
  ///   user did NOT touch
  /// - Edit mode, conflicts: set conflict state for UI resolution AND
  ///   auto-merge the non-conflicting fields
  void applyPendingServerUpdate() {
    final pendingOrder = state.pendingServerOrder;
    if (pendingOrder == null) {
      clearServerUpdatePending();
      return;
    }

    logger.i(
      '[SaleOrderForm]',
      'Applying pending server update for order ${pendingOrder.id}',
    );

    final pendingLines = state.pendingServerLines ?? state.lines;

    if (!state.isEditing) {
      // View mode: full overwrite (no conflicts possible)
      updateOrderFromSync(pendingOrder, pendingLines);
      _clearPendingState();
      return;
    }

    // ---- Edit mode: detect conflicts on order header ----
    final result = conflictDetectionService.detectOrderConflicts(
      localOrder: state.order!,
      serverOrder: pendingOrder,
      changedFields: state.changedFields,
    );

    if (result.hasConflicts) {
      // Show conflicts to user — convert from service ConflictDetail to
      // state ConflictDetail (they are structurally identical but separate
      // classes from base_order_state.dart vs sale_order_form_state.dart).
      final stateConflicts = <String, ConflictDetail>{
        for (var c in result.conflicts)
          c.fieldName: ConflictDetail(
            fieldName: c.fieldName,
            localValue: c.localValue,
            serverValue: c.serverValue,
            serverUserName: c.serverUserName,
          ),
      };
      state = state.copyWith(
        hasConflict: true,
        conflicts: stateConflicts,
        conflictMessage: result.conflictMessage,
      );
      logger.w(
        '[SaleOrderForm]',
        'Conflicts detected: ${result.conflictingFieldNames}',
      );
    }

    // Auto-merge non-conflicting header fields
    if (result.mergeableFields.isNotEmpty) {
      _applyMergeableFields(result.mergeableFields);
    }

    // ---- Line merging ----
    _applyPendingLinesMerge(pendingLines);

    _clearPendingState();
  }

  /// Apply mergeable (non-conflicting) server field values to local state.
  ///
  /// Each key is the snake_case Odoo field name; the value comes straight
  /// from the server order via [ConflictDetectionService].
  void _applyMergeableFields(Map<String, dynamic> fields) {
    if (fields.isEmpty) return;

    logger.d(
      '[SaleOrderForm]',
      'Auto-merging ${fields.length} server fields: ${fields.keys}',
    );

    // Build a partial copyWith with only the mergeable fields.
    int? partnerId = state.partnerId;
    int? pricelistId = state.pricelistId;
    String? pricelistName = state.pricelistName;
    int? paymentTermId = state.paymentTermId;
    String? paymentTermName = state.paymentTermName;
    int? warehouseId = state.warehouseId;
    String? warehouseName = state.warehouseName;
    int? userId = state.userId;
    String? userName = state.userName;
    DateTime? dateOrder = state.dateOrder;
    DateTime? commitmentDate = state.commitmentDate;
    String? note = state.note;
    String? partnerPhone = state.partnerPhone;
    String? partnerEmail = state.partnerEmail;
    String? endCustomerName = state.endCustomerName;
    String? endCustomerPhone = state.endCustomerPhone;
    String? endCustomerEmail = state.endCustomerEmail;

    for (final entry in fields.entries) {
      switch (entry.key) {
        case 'partner_id':
          partnerId = entry.value as int?;
          break;
        case 'pricelist_id':
          pricelistId = entry.value as int?;
          // Try to resolve name from selection data
          if (pricelistId != null && state.pricelists.isNotEmpty) {
            final found = state.pricelists.firstWhere(
              (pl) => pl['id'] == pricelistId,
              orElse: () => <String, dynamic>{},
            );
            if (found.isNotEmpty) pricelistName = found['name'] as String?;
          }
          break;
        case 'payment_term_id':
          paymentTermId = entry.value as int?;
          if (paymentTermId != null && state.paymentTerms.isNotEmpty) {
            final found = state.paymentTerms.firstWhere(
              (pt) => pt['id'] == paymentTermId,
              orElse: () => <String, dynamic>{},
            );
            if (found.isNotEmpty) paymentTermName = found['name'] as String?;
          }
          break;
        case 'warehouse_id':
          warehouseId = entry.value as int?;
          if (warehouseId != null && state.warehouses.isNotEmpty) {
            final found = state.warehouses.firstWhere(
              (w) => w['id'] == warehouseId,
              orElse: () => <String, dynamic>{},
            );
            if (found.isNotEmpty) warehouseName = found['name'] as String?;
          }
          break;
        case 'user_id':
          userId = entry.value as int?;
          if (userId != null && state.salespeople.isNotEmpty) {
            final found = state.salespeople.firstWhere(
              (s) => s['id'] == userId,
              orElse: () => <String, dynamic>{},
            );
            if (found.isNotEmpty) userName = found['name'] as String?;
          }
          break;
        case 'date_order':
          dateOrder = entry.value as DateTime?;
          break;
        case 'commitment_date':
          commitmentDate = entry.value as DateTime?;
          break;
        case 'note':
          note = entry.value as String?;
          break;
        case 'partner_phone':
          partnerPhone = entry.value as String?;
          break;
        case 'partner_email':
          partnerEmail = entry.value as String?;
          break;
        case 'end_customer_name':
          endCustomerName = entry.value as String?;
          break;
        case 'end_customer_phone':
          endCustomerPhone = entry.value as String?;
          break;
        case 'end_customer_email':
          endCustomerEmail = entry.value as String?;
          break;
      }
    }

    state = state.copyWith(
      partnerId: partnerId,
      pricelistId: pricelistId,
      pricelistName: pricelistName,
      paymentTermId: paymentTermId,
      paymentTermName: paymentTermName,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      userId: userId,
      userName: userName,
      dateOrder: dateOrder,
      commitmentDate: commitmentDate,
      note: note,
      partnerPhone: partnerPhone,
      partnerEmail: partnerEmail,
      endCustomerName: endCustomerName,
      endCustomerPhone: endCustomerPhone,
      endCustomerEmail: endCustomerEmail,
    );
  }

  /// Merge pending server lines into local state.
  ///
  /// - If user has NOT modified any lines, apply server lines directly.
  /// - If user HAS modified lines, use [ConflictDetectionService] to detect
  ///   line-level conflicts and only flag those that actually conflict.
  void _applyPendingLinesMerge(List<SaleOrderLine> serverLines) {
    final hasLocalLineChanges = state.updatedLines.isNotEmpty ||
        state.deletedLineIds.isNotEmpty ||
        state.newLines.isNotEmpty;

    if (!hasLocalLineChanges) {
      // No local line modifications — safe to apply server lines directly
      logger.d(
        '[SaleOrderForm]',
        'No local line changes, applying ${serverLines.length} server lines',
      );
      state = state.copyWith(lines: serverLines);
      return;
    }

    // User has modified lines — detect per-line conflicts
    final modifiedLineIds = <int>{
      ...state.updatedLines.map((l) => l.id),
      ...state.deletedLineIds,
    };

    final lineResults = conflictDetectionService.detectLineConflicts(
      localLines: state.lines,
      serverLines: serverLines,
      modifiedLineIds: modifiedLineIds,
    );

    // Check if any line has conflicts
    final hasLineConflicts =
        lineResults.values.any((r) => r.hasConflicts);

    if (hasLineConflicts) {
      // Add line conflicts to the existing conflict state
      final conflictMessages = <String>[];
      for (final entry in lineResults.entries) {
        if (entry.value.hasConflicts) {
          conflictMessages.add(
            'Línea ${entry.key}: ${entry.value.conflictMessage}',
          );
        }
      }

      final existingMessage = state.conflictMessage ?? '';
      final lineMessage = conflictMessages.join('; ');
      final combinedMessage = existingMessage.isEmpty
          ? lineMessage
          : '$existingMessage\n$lineMessage';

      state = state.copyWith(
        hasConflict: true,
        conflictMessage: combinedMessage,
      );

      logger.w(
        '[SaleOrderForm]',
        'Line conflicts detected: ${conflictMessages.length} lines',
      );
    } else {
      // No line conflicts — apply non-modified server lines
      // Keep locally modified lines, update the rest from server
      final serverLineMap = {for (var l in serverLines) l.id: l};
      final mergedLines = <SaleOrderLine>[];

      for (final line in state.lines) {
        if (modifiedLineIds.contains(line.id)) {
          // Keep local version of modified lines
          mergedLines.add(line);
        } else if (serverLineMap.containsKey(line.id)) {
          // Use server version of non-modified lines
          mergedLines.add(serverLineMap[line.id]!);
        } else {
          // Line exists locally but not on server (deleted on server)
          // Keep it — user didn't delete it locally
          mergedLines.add(line);
        }
      }

      // Add new server lines that don't exist locally
      for (final serverLine in serverLines) {
        if (!state.lines.any((l) => l.id == serverLine.id)) {
          mergedLines.add(serverLine);
        }
      }

      state = state.copyWith(lines: mergedLines);
      logger.d(
        '[SaleOrderForm]',
        'Lines merged: ${mergedLines.length} total',
      );
    }
  }

  /// Helper to clear the pending server update state.
  void _clearPendingState() {
    state = state.copyWith(
      serverUpdatePending: false,
      pendingServerOrder: null,
      pendingServerLines: null,
    );
  }

  /// Resolve all conflicts by accepting server values.
  ///
  /// Clears conflicting local changes and reloads from server.
  Future<void> resolveConflictsWithServer() async {
    if (state.order == null || !state.hasConflict) return;

    logger.d('[SaleOrderForm]', 'Resolving conflicts with server values');

    // Remove locally changed fields that were in conflict
    final newChangedFields = Map<String, dynamic>.from(state.changedFields);
    for (final conflictField in state.conflicts?.keys ?? <String>[]) {
      newChangedFields.remove(conflictField);
    }

    // Reload from server to get authoritative values
    await loadOrder(state.order!.id, forceRefresh: true);

    state = state.copyWith(
      changedFields: newChangedFields,
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
      hasChanges: newChangedFields.isNotEmpty,
    );
  }

  /// Resolve all conflicts by keeping local values.
  ///
  /// Clears conflict UI state so the user can continue editing and re-save.
  void resolveConflictsWithLocal() {
    keepLocalChanges();
  }

  /// Clear the pending flag without applying (e.g., user dismissed it).
  void clearServerUpdatePending() {
    state = state.copyWith(
      serverUpdatePending: false,
      pendingServerOrder: null,
      pendingServerLines: null,
    );
  }

  /// Actualizar todos los campos del partner sin recargar toda la orden
  ///
  /// Usado por WebSocket notifications para actualizar campos desnormalizados
  /// sin causar un rebuild completo del formulario.
  void updatePartnerFieldsOnly(
    int partnerId, {
    required String name,
    String? vat,
    String? street,
    String? phone,
    String? email,
    String? avatar,
  }) {
    if (state.order == null) return;
    if (state.order!.partnerId != partnerId) return;

    logger.d(
      '[SaleOrderForm]',
      'Updating partner fields: $partnerId -> name=$name, vat=$vat, street=$street, phone=$phone, email=$email, avatar=${avatar != null ? '(${avatar.length} chars)' : 'null'}',
    );

    // Actualizar todos los campos del partner en el estado
    state = state.copyWith(
      partnerName: name,
      partnerVat: vat,
      partnerStreet: street,
      partnerPhone: phone,
      partnerEmail: email,
      partnerAvatar: avatar,
      order: state.order!.copyWith(
        partnerName: name,
        partnerVat: vat,
        partnerStreet: street,
        partnerPhone: phone,
        partnerEmail: email,
        partnerAvatar: avatar,
      ),
    );
  }

  /// Limpiar error
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  // ==========================================================================
  // METODOS DE ACTUALIZACION GRANULAR (WebSocket)
  // ==========================================================================

  /// Actualizar una línea específica desde datos de WebSocket
  ///
  /// Este método actualiza solo la línea indicada en el estado, sin recargar
  /// toda la orden. Preserva el modo de edición actual.
  ///
  /// [updatedLine] - La línea actualizada con los nuevos valores
  void updateLineFromWebSocket(SaleOrderLine updatedLine) {
    if (state.order == null) return;
    if (state.order!.id != updatedLine.orderId) return;

    // Si estamos en modo edición, no actualizar para no perder cambios locales
    if (state.isEditing) {
      logger.d(
        '[SaleOrderForm]',
        'Ignorando actualización WebSocket de línea ${updatedLine.id} '
            'porque estamos en modo edición',
      );
      return;
    }

    // Buscar y actualizar la línea en state.lines
    final lineIndex = state.lines.indexWhere((l) => l.id == updatedLine.id);
    if (lineIndex >= 0) {
      // Verificar si hay cambios reales (Freezed implementa deep equality)
      final existingLine = state.lines[lineIndex];
      if (existingLine == updatedLine) {
        logger.d(
          '[SaleOrderForm]',
          'WebSocket line update ignored - no changes detected for line ${updatedLine.id}',
        );
        return;
      }

      // Actualizar línea existente
      final newLines = List<SaleOrderLine>.from(state.lines);
      newLines[lineIndex] = updatedLine;

      // Incrementar linesVersion para forzar rebuild de UI
      state = state.copyWith(
        lines: newLines,
        linesVersion: state.linesVersion + 1,
      );

      logger.d(
        '[SaleOrderForm]',
        'Línea ${updatedLine.id} actualizada granularmente via WebSocket '
            '(version: ${state.linesVersion})',
      );
    } else {
      // La línea no existe en el estado actual, agregarla
      final newLines = List<SaleOrderLine>.from(state.lines)..add(updatedLine);
      newLines.sort((a, b) => a.sequence.compareTo(b.sequence));

      // Incrementar linesVersion para forzar rebuild de UI
      state = state.copyWith(
        lines: newLines,
        linesVersion: state.linesVersion + 1,
      );

      logger.d(
        '[SaleOrderForm]',
        'Línea ${updatedLine.id} agregada via WebSocket '
            '(version: ${state.linesVersion})',
      );
    }
  }

  /// Actualizar campos de la orden desde WebSocket
  ///
  /// Este método actualiza los campos especificados sin recargar toda la orden.
  /// Esto evita rebuild completo del UI - solo actualiza los campos que cambiaron.
  ///
  /// [orderId] - ID de la orden
  /// [values] - Map con los valores a actualizar (del payload WebSocket)
  void updateOrderFromWebSocket(int orderId, Map<String, dynamic> values) {
    if (state.order == null) return;
    if (state.order!.id != orderId) return;

    // Si estamos en modo edición, no actualizar para no perder cambios locales
    if (state.isEditing) {
      logger.d(
        '[SaleOrderForm]',
        'Ignorando actualización WebSocket para orden $orderId '
            'porque estamos en modo edición',
      );
      return;
    }

    final currentOrder = state.order!;

    // Parsear campos del payload
    final orderState = values['state'] as String?;
    SaleOrderState? newState;
    if (orderState != null) {
      newState = SaleOrderState.values
          .where((e) => e.name == orderState)
          .firstOrNull;
    }

    // Parsear fechas
    DateTime? dateOrder;
    if (values['date_order'] != null) {
      dateOrder = DateTime.tryParse(values['date_order'].toString());
    }

    DateTime? validityDate;
    if (values['validity_date'] != null) {
      validityDate = DateTime.tryParse(values['validity_date'].toString());
    }

    DateTime? commitmentDate;
    if (values['commitment_date'] != null) {
      commitmentDate = DateTime.tryParse(values['commitment_date'].toString());
    }

    // Actualizar la orden con los nuevos valores
    final updatedOrder = currentOrder.copyWith(
      // Totales
      amountUntaxed:
          (values['amount_untaxed'] as num?)?.toDouble() ??
          currentOrder.amountUntaxed,
      amountTax:
          (values['amount_tax'] as num?)?.toDouble() ?? currentOrder.amountTax,
      amountTotal:
          (values['amount_total'] as num?)?.toDouble() ??
          currentOrder.amountTotal,
      // Estado
      state: newState ?? currentOrder.state,
      // Fechas
      dateOrder: dateOrder ?? currentOrder.dateOrder,
      validityDate: validityDate ?? currentOrder.validityDate,
      commitmentDate: commitmentDate ?? currentOrder.commitmentDate,
      // Partner
      partnerId: (values['partner_id'] as int?) ?? currentOrder.partnerId,
      partnerName:
          (values['partner_name'] as String?) ?? currentOrder.partnerName,
      // Payment term
      paymentTermId:
          (values['payment_term_id'] as int?) ?? currentOrder.paymentTermId,
      paymentTermName:
          (values['payment_term_name'] as String?) ??
          currentOrder.paymentTermName,
      // Pricelist
      pricelistId: (values['pricelist_id'] as int?) ?? currentOrder.pricelistId,
      pricelistName:
          (values['pricelist_name'] as String?) ?? currentOrder.pricelistName,
      // User/salesperson
      userId: (values['user_id'] as int?) ?? currentOrder.userId,
      userName: (values['user_name'] as String?) ?? currentOrder.userName,
      // Warehouse
      warehouseId: (values['warehouse_id'] as int?) ?? currentOrder.warehouseId,
      warehouseName:
          (values['warehouse_name'] as String?) ?? currentOrder.warehouseName,
      // Referencias
      clientOrderRef:
          (values['client_order_ref'] as String?) ??
          currentOrder.clientOrderRef,
      note: (values['note'] as String?) ?? currentOrder.note,
    );

    // Solo actualizar el estado si hay cambios reales
    // Freezed implementa deep equality, así que == compara todos los campos
    if (updatedOrder == currentOrder) {
      logger.d(
        '[SaleOrderForm]',
        'WebSocket update ignored - no changes detected for order $orderId',
      );
      return;
    }

    state = state.copyWith(order: updatedOrder);

    // Log de campos actualizados
    final updatedFields = <String>[];
    if (values.containsKey('amount_untaxed')) updatedFields.add('subtotal');
    if (values.containsKey('amount_tax')) updatedFields.add('tax');
    if (values.containsKey('amount_total')) updatedFields.add('total');
    if (values.containsKey('date_order')) updatedFields.add('dateOrder');
    if (values.containsKey('validity_date')) updatedFields.add('validityDate');
    if (values.containsKey('commitment_date')) {
      updatedFields.add('commitmentDate');
    }
    if (values.containsKey('partner_id')) updatedFields.add('partner');
    if (values.containsKey('payment_term_id')) updatedFields.add('paymentTerm');
    if (values.containsKey('pricelist_id')) updatedFields.add('pricelist');
    if (values.containsKey('user_id')) updatedFields.add('user');
    if (values.containsKey('warehouse_id')) updatedFields.add('warehouse');
    if (values.containsKey('state')) updatedFields.add('state');

    logger.d(
      '[SaleOrderForm]',
      'Orden actualizada granularmente via WebSocket: '
          'campos=${updatedFields.join(", ")}',
    );
  }

  /// Eliminar una línea específica desde notificación WebSocket
  ///
  /// [lineId] - ID de la línea a eliminar
  /// [orderId] - ID de la orden (para verificar que es la orden actual)
  void removeLineFromWebSocket(int lineId, int orderId) {
    if (state.order == null) return;
    if (state.order!.id != orderId) return;

    // Si estamos en modo edición, no eliminar para no perder cambios locales
    if (state.isEditing) {
      logger.d(
        '[SaleOrderForm]',
        'Ignorando eliminación WebSocket de línea $lineId '
            'porque estamos en modo edición',
      );
      return;
    }

    final newLines = state.lines.where((l) => l.id != lineId).toList();

    if (newLines.length != state.lines.length) {
      // Incrementar linesVersion para forzar rebuild de UI
      state = state.copyWith(
        lines: newLines,
        linesVersion: state.linesVersion + 1,
      );
      logger.d(
        '[SaleOrderForm]',
        'Línea $lineId eliminada granularmente via WebSocket '
            '(version: ${state.linesVersion})',
      );
    }
  }

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

  // ==========================================================================
  // METODOS DE ACTUALIZACION DE ESTADO DE ORDEN
  // ==========================================================================

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

  // ==========================================================================
  // METODOS DE RESOLUCION DE CONFLICTOS
  // ==========================================================================

  /// Procesar actualización del servidor (desde WebSocket)
  ///
  /// Detecta conflictos entre cambios locales y cambios del servidor.
  /// Retorna true si hay conflicto que requiere atención del usuario.
  bool processServerUpdate({
    required Map<String, dynamic> serverChangedFields,
    required String? serverUserName,
    required DateTime serverWriteDate,
  }) {
    if (state.order == null) return false;

    // Si no estamos en modo edición o no hay cambios, aplicar directamente
    if (!state.isEditing || !state.hasChanges || state.changedFields.isEmpty) {
      logger.d(
        '[SaleOrderForm]',
        'No local changes, applying server update directly',
      );
      refreshOrder();
      return false;
    }

    // Detectar conflictos
    final conflicts = <String, ConflictDetail>{};
    final mergedFields = <String, dynamic>{};

    for (final entry in serverChangedFields.entries) {
      final fieldName = entry.key;
      final serverChange = entry.value as Map<String, dynamic>;

      if (state.changedFields.containsKey(fieldName)) {
        // Conflicto: el mismo campo fue modificado localmente y en el servidor
        final localChange = state.changedFields[fieldName];
        final localValue = localChange is Map
            ? localChange['new']
            : localChange;

        conflicts[fieldName] = ConflictDetail(
          fieldName: fieldName,
          localValue: localValue,
          serverValue: serverChange['new'],
          serverUserName: serverUserName,
        );
      } else {
        // Sin conflicto: campo solo modificado en servidor, se puede mergear
        mergedFields[fieldName] = serverChange['new'];
      }
    }

    if (conflicts.isNotEmpty) {
      // Hay conflictos - notificar al usuario
      final conflictFieldNames = conflicts.keys.join(', ');
      state = state.copyWith(
        hasConflict: true,
        conflicts: conflicts,
        conflictMessage:
            'El usuario $serverUserName modificó los campos: $conflictFieldNames. '
            'Los cambios del servidor se aplicarán. Revisa tus cambios.',
      );
      logger.d(
        '[SaleOrderForm]',
        'Conflict detected in fields: $conflictFieldNames',
      );
      return true;
    } else if (mergedFields.isNotEmpty) {
      // Sin conflictos, mergear campos del servidor
      logger.d(
        '[SaleOrderForm]',
        'No conflicts, merging server fields: ${mergedFields.keys}',
      );
      refreshOrder();
    }

    return false;
  }

  /// Resolver conflicto aceptando cambios del servidor
  Future<void> acceptServerChanges() async {
    if (state.order == null) return;

    logger.d('[SaleOrderForm]', 'Accepting server changes');

    // Limpiar cambios locales en los campos en conflicto
    final newChangedFields = Map<String, dynamic>.from(state.changedFields);
    for (final conflictField in state.conflicts?.keys ?? <String>[]) {
      newChangedFields.remove(conflictField);
    }

    // Refrescar desde servidor
    await loadOrder(state.order!.id, forceRefresh: true);

    state = state.copyWith(
      changedFields: newChangedFields,
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
      hasChanges: newChangedFields.isNotEmpty,
    );
  }

  /// Resolver conflicto manteniendo cambios locales (para volver a guardar)
  void keepLocalChanges() {
    logger.d('[SaleOrderForm]', 'Keeping local changes, user will re-save');
    state = state.copyWith(
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
    );
  }

  /// Limpiar estado de conflicto
  void clearConflict() {
    state = state.copyWith(
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
    );
  }

  /// Detectar conflictos entre orden local y servidor usando ConflictDetectionService
  ///
  /// Usado cuando tenemos la orden completa del servidor (ej: al recargar).
  /// Para actualizaciones WebSocket parciales, usar [processServerUpdate].
  ConflictDetectionResult detectConflictsWithServer({
    required SaleOrder serverOrder,
    String? serverUserName,
  }) {
    if (state.order == null) {
      return ConflictDetectionResult.noConflicts();
    }

    return conflictDetectionService.detectOrderConflicts(
      localOrder: state.order!,
      serverOrder: serverOrder,
      changedFields: state.changedFields,
      serverUserName: serverUserName,
    );
  }

  // ==========================================================================
  // METODOS DE VALIDACION DE CREDITO
  // ==========================================================================

  /// Validar crédito para mostrar en UI (antes de guardar)
  ///
  /// Este método está diseñado para ser llamado desde la capa de UI
  /// para determinar si se debe mostrar el CreditControlDialog.
  ///
  /// Retorna [UnifiedCreditResult] que indica:
  /// - requiresDialog: true si hay problema de crédito que requiere intervención
  /// - partner: datos del partner para mostrar en el dialog
  /// - validationResult: resultado detallado de la validación
  /// - orderAmount: monto de la orden
  /// - isOnline: si hay conexión al servidor
  Future<UnifiedCreditResult> validateCreditForUI() async {
    // Si ya se bypasó la validación, no mostrar dialog
    if (state.creditCheckBypassed) {
      return UnifiedCreditResult.notRequired();
    }

    if (state.partnerId == null) {
      return UnifiedCreditResult.notRequired();
    }

    try {
      // 1. Obtener client desde ClientRepository
      final clientRepo = ref.read(clientRepositoryProvider);
      if (clientRepo == null) {
        logger.w('[SaleOrderForm]', 'ClientRepository not available');
        return UnifiedCreditResult.notRequired();
      }

      Client? client = await clientRepo.getById(state.partnerId!);

      if (client == null) {
        logger.w(
          '[SaleOrderForm]',
          'Client ${state.partnerId} not found in local DB',
        );
        return UnifiedCreditResult.notRequired();
      }

      // 2. Verificar si hay límite de crédito configurado
      if (!client.hasCreditLimit) {
        logger.d(
          '[SaleOrderForm]',
          'Client ${client.name} has no credit limit configured',
        );
        return UnifiedCreditResult.notRequired();
      }

      // 3. Determinar si estamos online
      final isOnline = clientRepo.isOnline;

      // 4. Si online y datos desactualizados, sincronizar
      if (isOnline && client.isCreditDataStale(1)) {
        try {
          client = await clientRepo.refreshCreditData(state.partnerId!);
        } catch (e) {
          logger.w(
            '[SaleOrderForm]',
            'Failed to refresh credit data for UI, using local: $e',
          );
        }
      }

      // Verificar que client sigue siendo válido después de la sincronización
      if (client == null) {
        return UnifiedCreditResult.notRequired();
      }

      // 5. Calcular monto de la orden
      final orderAmount = state.calculatedSubtotal;

      // 6. Ejecutar validación usando ClientCreditService
      final creditService = ref.read(clientCreditServiceProvider);
      if (creditService == null) {
        logger.w('[SaleOrderForm]', 'ClientCreditService not available');
        return UnifiedCreditResult.notRequired();
      }

      final result = await creditService.validateOrderCreditForClient(
        client: client,
        orderAmount: orderAmount,
        isOnline: isOnline,
        bypassCheck: false,
      );

      // 7. Determinar si se debe mostrar el dialog
      if (!result.isValid) {
        return UnifiedCreditResult.showDialog(
          client: client,
          validationResult: result,
          orderAmount: orderAmount,
          isOnline: isOnline,
        );
      }

      return UnifiedCreditResult.proceed();
    } catch (e, stack) {
      logger.e('[SaleOrderForm]', 'Error validating credit for UI', e, stack);
      return UnifiedCreditResult.notRequired();
    }
  }

  /// Validar crédito del partner antes de guardar
  ///
  /// Implementa lógica offline-first:
  /// - Si online: sincroniza datos frescos del partner antes de validar
  /// - Si offline: aplica margen de seguridad y verifica TTL de datos
  ///
  /// Usa ClientCreditService del módulo clients cuando está disponible,
  /// con fallback al CreditValidationService original.
  ///
  /// Retorna CreditValidationResult con el resultado de la validación.
  /// Si hay problemas de crédito, establece errorMessage en el estado.
  Future<CreditValidationResult?> _validateCredit() async {
    if (state.partnerId == null) {
      return null; // No hay partner, no se puede validar
    }

    try {
      // Intentar usar el nuevo ClientCreditService
      final clientCreditService = ref.read(clientCreditServiceProvider);
      if (clientCreditService != null) {
        return await _validateCreditWithClientService(clientCreditService);
      }

      // Fallback al método original si ClientCreditService no está disponible
      return await _validateCreditLegacy();
    } catch (e, stack) {
      logger.e('[SaleOrderForm]', 'Error validating credit', e, stack);
      // En caso de error, permitir continuar para no bloquear ventas
      return null;
    }
  }

  /// Validar crédito usando el nuevo ClientCreditService
  Future<CreditValidationResult?> _validateCreditWithClientService(
    dynamic clientCreditService,
  ) async {
    final orderAmount = state.calculatedSubtotal;

    // Usar el nuevo servicio de clientes para validar
    final result = await clientCreditService.validateOrderCredit(
      clientId: state.partnerId!,
      orderAmount: orderAmount,
      bypassCheck: state.creditCheckBypassed,
    ) as CreditValidationResult;

    // Procesar resultado
    if (!result.isValid) {
      state = state.copyWith(
        errorMessage: result.message ?? 'Problema de crédito detectado',
      );
      logger.w(
        '[SaleOrderForm]',
        'Credit validation failed (via ClientCreditService): '
            '${result.type} - ${result.message}',
      );
    } else if (result.type == CreditCheckType.warning) {
      state = state.copyWith(creditWarningMessage: result.message);
      logger.i(
        '[SaleOrderForm]',
        'Credit warning (via ClientCreditService): ${result.message}',
      );
    }

    return result;
  }

  /// Método legacy de validación de crédito (fallback)
  ///
  /// Usa ClientRepository y ClientValidationService directamente
  /// cuando ClientCreditService no está disponible.
  Future<CreditValidationResult?> _validateCreditLegacy() async {
    // 1. Obtener cliente desde ClientRepository
    final clientRepo = ref.read(clientRepositoryProvider);
    if (clientRepo == null) {
      logger.w('[SaleOrderForm]', 'ClientRepository not available (legacy)');
      return null;
    }

    Client? client = await clientRepo.getById(state.partnerId!);

    if (client == null) {
      logger.w(
        '[SaleOrderForm]',
        'Client ${state.partnerId} not found in local DB (legacy)',
      );
      return null;
    }

    // 2. Verificar si hay límite de crédito configurado
    if (!client.hasCreditLimit) {
      logger.d(
        '[SaleOrderForm]',
        'Client ${client.name} has no credit limit configured (legacy)',
      );
      return CreditValidationResult.noLimit();
    }

    // 3. Determinar si estamos online
    final isOnline = clientRepo.isOnline;

    // 4. Si online y datos desactualizados, sincronizar
    if (isOnline && client.isCreditDataStale(1)) {
      try {
        client = await clientRepo.refreshCreditData(state.partnerId!);
        logger.d(
          '[SaleOrderForm]',
          'Credit data refreshed for ${client.name} (legacy): '
              'limit=${client.creditLimit}, '
              'available=${client.creditAvailable}',
        );
      } catch (e) {
        logger.w(
          '[SaleOrderForm]',
          'Failed to refresh credit data, using local (legacy): $e',
        );
      }
    }

    if (client == null) {
      return null;
    }

    // 5. Calcular monto de la orden
    final orderAmount = state.calculatedSubtotal;

    // 6. Usar ClientValidationService para validar
    final validationService = ref.read(clientValidationProvider);
    if (validationService == null) {
      logger.w('[SaleOrderForm]', 'ClientValidationService not available');
      return null;
    }

    final result = await validationService.validateCreditForOrder(
      client: client,
      orderAmount: orderAmount,
      isOnline: isOnline,
      bypassCheck: state.creditCheckBypassed,
    );

    // 7. Procesar resultado
    if (!result.isValid) {
      final errorMsg = _buildCreditErrorMessage(result, client);
      state = state.copyWith(errorMessage: errorMsg);
      logger.w(
        '[SaleOrderForm]',
        'Credit validation failed (legacy): ${result.type} - ${result.message}',
      );
    } else if (result.type == CreditCheckType.warning) {
      state = state.copyWith(creditWarningMessage: result.message);
      logger.i(
        '[SaleOrderForm]',
        'Credit warning (legacy): ${result.message}',
      );
    }

    return result;
  }

  /// Construir mensaje de error detallado para problemas de crédito
  String _buildCreditErrorMessage(
    CreditValidationResult result,
    Client client,
  ) {
    switch (result.type) {
      case CreditCheckType.creditLimitExceeded:
        final exceeded = result.creditExceededAmount ?? 0;
        return 'El cliente ${client.name} ha excedido su límite de crédito '
            'por ${exceeded.toCurrency()}. '
            'Disponible: ${(result.creditAvailable ?? 0).toCurrency()}';

      case CreditCheckType.overdueDebt:
        return 'El cliente ${client.name} tiene deudas vencidas. '
            '${result.message ?? "Se requiere aprobación para continuar."}';

      case CreditCheckType.staleData:
        return 'Los datos de crédito del cliente ${client.name} están '
            'desactualizados. Conecte a internet para actualizar antes de '
            'procesar ventas a crédito.';

      case CreditCheckType.none:
      case CreditCheckType.noLimit:
      case CreditCheckType.warning:
        return result.message ?? 'Problema de crédito detectado';
    }
  }

  /// Bypass de verificación de crédito (después de aprobación)
  ///
  /// Marca la orden para permitir continuar sin validación de crédito.
  /// Debe usarse solo después de obtener aprobación del supervisor.
  void bypassCreditCheck() {
    state = state.copyWith(creditCheckBypassed: true);
    logger.i('[SaleOrderForm]', 'Credit check bypassed by user');
  }

  /// Resetear estado de validación de crédito
  void resetCreditValidation() {
    state = state.copyWith(
      creditCheckBypassed: false,
      creditWarningMessage: null,
    );
  }
}

/// Helper para ejecutar Future sin esperar (similar a unawaited de dart:async)
void unawaited(Future<void>? future) {}
