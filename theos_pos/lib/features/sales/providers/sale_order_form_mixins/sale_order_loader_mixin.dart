import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../../core/database/repositories/repository_providers.dart';
import '../../utils/partner_utils.dart' as partner_utils;
import '../order_cache_provider.dart';
import '../sale_order_form_state.dart';
import '../service_providers.dart' show orderServiceProvider;
import 'sale_order_form_async_utils.dart';

/// Mixin de carga de orden/datos de selección para [SaleOrderFormNotifier]
///
/// Extraído de `sale_order_form_notifier.dart` (refactor de descomposición
/// en mixins, Fase E2b — copy-paste literal, cero cambio de comportamiento).
///
/// Proporciona: `initFromData`, `loadOrder`, `initNewOrder`,
/// `_syncDefaultsFromOdooInBackground`, `mounted`, `_loadPartnerData`,
/// `updatePartnerPhone`, `updatePartnerEmail`, `_resolveDefaultNames`,
/// `loadSelectionData`, `_loadWarehouses`, `_loadPartnerPaymentTermIds`,
/// `_loadCompanySettings`.
mixin SaleOrderLoaderMixin {
  /// Estado actual del formulario - debe ser implementado por el notifier
  SaleOrderFormState get state;

  /// Metodo para actualizar estado - debe ser implementado por el notifier
  set state(SaleOrderFormState newState);

  /// Acceso a Riverpod - debe ser implementado por el notifier
  Ref get ref;

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
  /// Guard contra race condition: captura el identificador de la orden al inicio
  /// y verifica que siga siendo la orden activa antes de aplicar cada resultado.
  /// Si el usuario cargó otra orden mientras esperaba la respuesta de Odoo,
  /// los valores recibidos se descartan silenciosamente.
  void _syncDefaultsFromOdooInBackground(SaleOrder baseOrder) async {
    // Capturar el identificador de la orden que disparó esta operación
    final targetOrderId = baseOrder.id;

    try {
      final orderService = ref.read(orderServiceProvider);
      final updatedOrder = await orderService.syncDefaultsFromOdoo(baseOrder);

      // Guard: verificar que la orden cargada siga siendo la misma
      if (updatedOrder == null) return;
      if (state.order?.id != targetOrderId) {
        logger.d(
          '[SaleOrderForm]',
          'Background sync discarded: order changed from $targetOrderId to ${state.order?.id}',
        );
        return;
      }

      // Apply updated fields to form state
      state = state.copyWith(
        pricelistId: updatedOrder.pricelistId ?? state.pricelistId,
        pricelistName: updatedOrder.pricelistName ?? state.pricelistName,
        paymentTermId: updatedOrder.paymentTermId ?? state.paymentTermId,
        paymentTermName: updatedOrder.paymentTermName ?? state.paymentTermName,
      );
      logger.i('[SaleOrderForm]', 'Form updated with Odoo defaults for order $targetOrderId');
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
}
