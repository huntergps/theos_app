import '../../../../core/services/logger_service.dart';
import 'sale_order_form_state.dart';

/// Mixin para actualizar campos del formulario de orden de venta
///
/// Proporciona metodos para:
/// - Actualizar campos individuales
/// - Rastrear cambios
/// - Resolver nombres desde cache
mixin SaleOrderFieldUpdater {
  /// Estado actual del formulario - debe ser implementado por el notifier
  SaleOrderFormState get state;

  /// Metodo para actualizar estado - debe ser implementado por el notifier
  set state(SaleOrderFormState newState);

  /// Hook called after any field is updated - override to sync with cache
  ///
  /// [orderId] - ID of the order being updated
  /// [fieldName] - Name of the field (e.g., 'partner', 'payment_term_id', 'pricelist_id')
  /// [value] - New value. For 'partner' field, this is a Map with partner details
  void onFieldUpdated(int orderId, String fieldName, dynamic value) {}

  /// Resuelve el nombre de un elemento desde una lista cacheada
  ///
  /// [items] - Lista de mapas con 'id' y 'name'
  /// [id] - ID a buscar
  /// Returns: Nombre del elemento o null si no se encuentra
  String? _resolveNameFromList(List<Map<String, dynamic>> items, int? id) {
    if (id == null || items.isEmpty) return null;
    try {
      final item = items.firstWhere(
        (i) => i['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      return item.isNotEmpty ? item['name'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  /// Actualizar un campo del formulario
  ///
  /// [field] - Nombre del campo (partner_id, payment_term_id, etc.)
  /// [value] - Nuevo valor del campo
  void updateField(String field, dynamic value) {
    final oldValue = getFieldValue(field);
    if (oldValue == value) return;

    // Registrar cambio
    final newChangedFields = Map<String, dynamic>.from(state.changedFields);
    newChangedFields[field] = {
      'old': oldValue,
      'new': value,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Actualizar estado segun el campo
    switch (field) {
      case 'partner_id':
        state = state.copyWith(
          partnerId: value as int?,
          hasChanges: true,
          changedFields: newChangedFields,
        );

      case 'partner_name':
        state = state.copyWith(
          partnerName: value as String?,
          hasChanges: true,
          changedFields: newChangedFields,
        );

      case 'payment_term_id':
        final id = value as int?;
        // Resolve payment term details from cached list
        Map<String, dynamic>? paymentTermData;
        if (id != null && state.paymentTerms.isNotEmpty) {
          paymentTermData = state.paymentTerms.cast<Map<String, dynamic>>().firstWhere(
            (pt) => pt['id'] == id,
            orElse: () => <String, dynamic>{},
          );
        }
        state = state.copyWith(
          paymentTermId: id,
          paymentTermName: paymentTermData?['name'] as String?,
          isCash: paymentTermData?['is_cash'] as bool? ?? (id == null),
          isCredit: paymentTermData?['is_credit'] as bool? ?? false,
          hasChanges: true,
          changedFields: newChangedFields,
        );

      case 'pricelist_id':
        final id = value as int?;
        state = state.copyWith(
          pricelistId: id,
          pricelistName: _resolveNameFromList(state.pricelists, id),
          hasChanges: true,
          changedFields: newChangedFields,
        );

      case 'warehouse_id':
        final id = value as int?;
        state = state.copyWith(
          warehouseId: id,
          warehouseName: _resolveNameFromList(state.warehouses, id),
          hasChanges: true,
          changedFields: newChangedFields,
        );

      case 'user_id':
        final id = value as int?;
        state = state.copyWith(
          userId: id,
          userName: _resolveNameFromList(state.salespeople, id),
          hasChanges: true,
          changedFields: newChangedFields,
        );

      case 'date_order':
        state = state.copyWith(
          dateOrder: value as DateTime?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      case 'validity_date':
        state = state.copyWith(
          validityDate: value as DateTime?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      case 'commitment_date':
        state = state.copyWith(
          commitmentDate: value as DateTime?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      case 'client_order_ref':
        state = state.copyWith(
          clientOrderRef: value as String?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      case 'note':
        state = state.copyWith(
          note: value as String?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      // Campos de consumidor final (l10n_ec_sale_base)
      case 'end_customer_name':
        state = state.copyWith(
          endCustomerName: value as String?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      case 'end_customer_phone':
        state = state.copyWith(
          endCustomerPhone: value as String?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      case 'end_customer_email':
        state = state.copyWith(
          endCustomerEmail: value as String?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      // Campos de facturación postfechada (l10n_ec_sale_base)
      case 'emitir_factura_fecha_posterior':
        state = state.copyWith(
          emitirFacturaFechaPosterior: value as bool? ?? false,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      case 'fecha_facturar':
        state = state.copyWith(
          fechaFacturar: value as DateTime?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      // Campos de referidor (l10n_ec_sale_base)
      case 'referrer_id':
        state = state.copyWith(
          referrerId: value as int?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      case 'referrer_name':
        state = state.copyWith(
          referrerName: value as String?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      // Campos de tipo/canal cliente (l10n_ec_sale_base)
      case 'tipo_cliente':
        state = state.copyWith(
          tipoCliente: value as String?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      case 'canal_cliente':
        state = state.copyWith(
          canalCliente: value as String?,
          hasChanges: true,
          changedFields: newChangedFields,
        );
        break;

      default:
        logger.w('[SaleOrderFieldUpdater]', 'Campo desconocido: $field');
        return; // Don't notify for unknown fields
    }

    logger.d('[SaleOrderFieldUpdater]', 'Campo actualizado: $field = $value');

    // Notify hook for cache synchronization
    final orderId = state.order?.id;
    if (orderId != null) {
      onFieldUpdated(orderId, field, value);
    }
  }

  /// Actualizar cliente con su nombre y detalles adicionales
  void updatePartner(
    int? partnerId,
    String? partnerName, {
    String? vat,
    String? street,
    String? phone,
    String? email,
    List<int>? paymentTermIds,
    int? propertyPaymentTermId,
    String? propertyPaymentTermName,
  }) {
    logger.i(
      '[SaleOrderFieldUpdater]',
      '>>> updatePartner CALLED: partnerId=$partnerId, name=$partnerName, vat=$vat',
    );
    logger.d(
      '[SaleOrderFieldUpdater]',
      '>>> Current state: partnerId=${state.partnerId}, partnerName=${state.partnerName}, isEditing=${state.isEditing}',
    );

    final newChangedFields = Map<String, dynamic>.from(state.changedFields);
    newChangedFields['partner_id'] = {
      'old': state.partnerId,
      'new': partnerId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Determinar el término de pago a usar
    int? newPaymentTermId = state.paymentTermId;
    String? newPaymentTermName = state.paymentTermName;
    
    // Si el cliente tiene un término de pago por defecto, usarlo
    if (propertyPaymentTermId != null) {
      newPaymentTermId = propertyPaymentTermId;
      newPaymentTermName = propertyPaymentTermName;
      // Si no tenemos el nombre, buscarlo en la lista de términos de pago
      if (newPaymentTermName == null && state.paymentTerms.isNotEmpty) {
        final found = state.paymentTerms.firstWhere(
          (pt) => pt['id'] == propertyPaymentTermId,
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty) {
          newPaymentTermName = found['name'] as String?;
        }
      }
    } else if (paymentTermIds != null &&
        paymentTermIds.isNotEmpty &&
        state.paymentTermId != null &&
        !paymentTermIds.contains(state.paymentTermId)) {
      // Si el término de pago actual no está en la nueva lista, limpiar
      newPaymentTermId = null;
      newPaymentTermName = null;
    }

    // Determinar si es consumidor final por el VAT (9999999999999)
    final isFinalConsumer = vat == '9999999999999';

    state = state.copyWith(
      partnerId: partnerId,
      partnerName: partnerName,
      partnerVat: vat,
      partnerStreet: street,
      partnerPhone: phone,
      partnerEmail: email,
      partnerPaymentTermIds: paymentTermIds ?? [],
      paymentTermId: newPaymentTermId,
      paymentTermName: newPaymentTermName,
      // Campos de consumidor final
      isFinalConsumer: isFinalConsumer,
      // Limpiar datos del cliente final si el partner cambió y no es consumidor final
      endCustomerName:
          isFinalConsumer ? state.endCustomerName : null,
      endCustomerPhone:
          isFinalConsumer ? state.endCustomerPhone : null,
      endCustomerEmail:
          isFinalConsumer ? state.endCustomerEmail : null,
      hasChanges: true,
      changedFields: newChangedFields,
    );

    logger.i(
      '[SaleOrderFieldUpdater]',
      '>>> updatePartner DONE: state.partnerId=${state.partnerId}, state.partnerName=${state.partnerName}',
    );

    // Notify hook for cache synchronization
    final orderId = state.order?.id;
    logger.d('[SaleOrderFieldUpdater]', '>>> orderId for cache sync: $orderId');
    if (orderId != null) {
      onFieldUpdated(orderId, 'partner', {
        'partner_id': partnerId,
        'partner_name': partnerName,
        'partner_vat': vat,
        'partner_street': street,
        'partner_phone': phone,
        'partner_email': email,
      });
    }
  }

  /// Obtener valor actual de un campo
  dynamic getFieldValue(String field) {
    switch (field) {
      case 'partner_id':
        return state.partnerId;
      case 'partner_name':
        return state.partnerName;
      case 'payment_term_id':
        return state.paymentTermId;
      case 'pricelist_id':
        return state.pricelistId;
      case 'warehouse_id':
        return state.warehouseId;
      case 'user_id':
        return state.userId;
      case 'date_order':
        return state.dateOrder;
      case 'validity_date':
        return state.validityDate;
      case 'commitment_date':
        return state.commitmentDate;
      case 'client_order_ref':
        return state.clientOrderRef;
      case 'note':
        return state.note;
      // Campos de consumidor final
      case 'is_final_consumer':
        return state.isFinalConsumer;
      case 'end_customer_name':
        return state.endCustomerName;
      case 'end_customer_phone':
        return state.endCustomerPhone;
      case 'end_customer_email':
        return state.endCustomerEmail;
      // Campos de facturación postfechada
      case 'emitir_factura_fecha_posterior':
        return state.emitirFacturaFechaPosterior;
      case 'fecha_facturar':
        return state.fechaFacturar;
      // Campos de referidor
      case 'referrer_id':
        return state.referrerId;
      case 'referrer_name':
        return state.referrerName;
      // Campos de tipo/canal cliente
      case 'tipo_cliente':
        return state.tipoCliente;
      case 'canal_cliente':
        return state.canalCliente;
      default:
        return null;
    }
  }

  /// Verificar si un campo especifico ha cambiado
  bool hasFieldChanged(String field) {
    return state.changedFields.containsKey(field);
  }

  /// Obtener valor original de un campo (antes de cambios)
  dynamic getOriginalFieldValue(String field) {
    if (state.changedFields.containsKey(field)) {
      final change = state.changedFields[field] as Map<String, dynamic>;
      return change['old'];
    }
    return getFieldValue(field);
  }
}
