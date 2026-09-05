import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide SaleOrderLineManager;

import '../../../../core/database/repositories/repository_providers.dart';
import '../../repositories/sales_repository.dart';
import '../../../clients/clients.dart' show CreditValidationResult;
import '../sale_order_form_state.dart';

/// Mixin de guardado de la orden para [SaleOrderFormNotifier]
///
/// Extraído de `sale_order_form_notifier.dart` (refactor de descomposición
/// en mixins, Fase E2b — copy-paste literal, cero cambio de comportamiento).
///
/// Proporciona: `saveOrder`, `_createNewOrder`, `_updateExistingOrder`,
/// `_consolidateChangesAfterSave`, `_prepareOrderValues`.
mixin SaleOrderSaverMixin {
  /// Estado actual del formulario - debe ser implementado por el notifier
  SaleOrderFormState get state;

  /// Metodo para actualizar estado - debe ser implementado por el notifier
  set state(SaleOrderFormState newState);

  /// Acceso a Riverpod - debe ser implementado por el notifier
  Ref get ref;

  /// Implementado por [SaleOrderCreditValidationMixin]
  /// (renombrado de `_validateCredit` — ver nota en ese mixin)
  Future<CreditValidationResult?> validateCreditForSave();

  /// Implementado por [SaleOrderLoaderMixin]
  Future<void> loadOrder(int orderId, {bool forceRefresh = false});

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
        errorMessage: 'El nombre del consumidor final es obligatorio cuando se marca como Consumidor Final.',
      );
      return null;
    }

    // Validación de facturación postfechada (replica _check_fecha_facturar de Odoo)
    if (state.emitirFacturaFechaPosterior) {
      if (state.fechaFacturar == null) {
        state = state.copyWith(
          errorMessage: 'Debe especificar la fecha de facturación cuando se activa facturación postfechada.',
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
          errorMessage: 'El tipo de cliente es obligatorio según la configuración de la empresa.',
        );
        return null;
      }
      if (state.canalCliente == null || state.canalCliente!.isEmpty) {
        state = state.copyWith(
          errorMessage: 'El canal de cliente es obligatorio según la configuración de la empresa.',
        );
        return null;
      }
    }

    // Validación de crédito (OFFLINE-FIRST)
    // Solo validar si no se ha bypassed Y no se pide skipCreditCheck
    if (!state.creditCheckBypassed && !skipCreditCheck) {
      final creditResult = await validateCreditForSave();
      if (creditResult != null && !creditResult.isValid) {
        // El mensaje de error ya fue establecido en validateCreditForSave
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
  Future<int?> _createNewOrder(SalesRepository salesRepo) async {
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
  Future<int?> _updateExistingOrder(SalesRepository salesRepo) async {
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

    // Actualizar lineas modificadas and keep their real persisted sync status.
    // If the immediate write fails, confirmation must see isSynced=false and
    // flush the line before changing the order state.
    final persistedUpdatedLines = <SaleOrderLine>[];
    for (final line in state.updatedLines) {
      // Use saleOrderLineManager.toOdoo() to include calculated fields (price_subtotal, price_tax, price_total)
      // The repository will exclude these when syncing to Odoo
      final lineVals = saleOrderLineManager.toOdoo(line);
      logger.d('[SaleOrderForm]', 'Updating line ${line.id}: $lineVals');
      await salesRepo.updateLine(line.id, lineVals, localLine: line);
      persistedUpdatedLines.add(
        await saleOrderLineManager.readLocal(line.id) ?? line,
      );
    }
    state = state.copyWith(updatedLines: persistedUpdatedLines);

    // Crear nuevas lineas and replace their temporary in-memory identity with
    // the persisted row (UUID and possibly the positive Odoo ID included).
    final persistedNewLines = <SaleOrderLine>[];
    for (final line in state.newLines) {
      final lineWithOrderId = line.copyWith(orderId: orderId);
      logger.d(
        '[SaleOrderForm]',
        'Creating new line: productId=${line.productId}, qty=${line.productUomQty}',
      );
      final persistedId = await salesRepo.addLine(orderId, lineWithOrderId);
      final persisted = persistedId == null
          ? null
          : await saleOrderLineManager.readLocal(persistedId);
      persistedNewLines.add(
        persisted ??
            lineWithOrderId.copyWith(id: persistedId ?? lineWithOrderId.id),
      );
    }
    state = state.copyWith(newLines: persistedNewLines);

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
      isCash: state.isCash,
      isCredit: state.isCredit,
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
      isFinalConsumer: state.isFinalConsumer,
      endCustomerName: state.endCustomerName,
      endCustomerPhone: state.endCustomerPhone,
      endCustomerEmail: state.endCustomerEmail,
      emitirFacturaFechaPosterior: state.emitirFacturaFechaPosterior,
      fechaFacturar: state.fechaFacturar,
      referrerId: state.referrerId,
      referrerName: state.referrerName,
      tipoCliente: state.tipoCliente,
      canalCliente: state.canalCliente,
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
            vals['commitment_date'] = formatOdooDateTime(newValue as DateTime);
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
}
