import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../clients/clients.dart'
    show
        Client,
        CreditCheckType,
        clientCreditServiceProvider,
        clientRepositoryProvider,
        CreditValidationResult;
import '../../services/credit_validation_ui_service.dart'
    show UnifiedCreditResult;
import '../sale_order_form_state.dart';

/// Mixin de validación de crédito para [SaleOrderFormNotifier]
///
/// Extraído de `sale_order_form_notifier.dart` (refactor de descomposición
/// en mixins, Fase E2b — copy-paste literal, cero cambio de comportamiento).
///
/// NOTA: el método privado original `_validateCredit()` se renombró a
/// `validateCreditForSave()` (público) porque `SaleOrderSaverMixin` (archivo
/// separado) necesita llamarlo — los miembros privados (`_`) son
/// library-scoped en Dart, así que un miembro privado no puede cruzar
/// archivos que no comparten `part of`. Es el único cambio no-literal de
/// todo este refactor; el cuerpo/lógica es idéntico al original.
mixin SaleOrderCreditValidationMixin {
  /// Estado actual del formulario - debe ser implementado por el notifier
  SaleOrderFormState get state;

  /// Metodo para actualizar estado - debe ser implementado por el notifier
  set state(SaleOrderFormState newState);

  /// Acceso a Riverpod - debe ser implementado por el notifier
  Ref get ref;

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
  /// Usa exclusivamente ClientCreditService, que es la única ruta de
  /// validación soportada por la aplicación nueva.
  ///
  /// Retorna CreditValidationResult con el resultado de la validación.
  /// Si hay problemas de crédito, establece errorMessage en el estado.
  ///
  /// Renombrado de `_validateCredit()` (privado) a público porque
  /// [SaleOrderSaverMixin] lo necesita llamar — ver nota de la clase.
  Future<CreditValidationResult?> validateCreditForSave() async {
    if (state.partnerId == null) {
      return null; // No hay partner, no se puede validar
    }

    try {
      // Intentar usar el nuevo ClientCreditService
      final clientCreditService = ref.read(clientCreditServiceProvider);
      if (clientCreditService != null) {
        return await _validateCreditWithClientService(clientCreditService);
      }

      logger.w('[SaleOrderForm]', 'ClientCreditService not available');
      return null;
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
