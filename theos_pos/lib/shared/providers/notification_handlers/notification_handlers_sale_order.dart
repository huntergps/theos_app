part of '../notification_provider.dart';

// ============================================================
// SALE ORDER — WebSocket Sync Handlers
// ============================================================
//
// Extraído de notification_provider.dart (refactor de descomposición,
// plan aprobado por software-architect). Cero cambio de comportamiento:
// los métodos se movieron tal cual, solo cambia su ubicación física.
//
// NOTA de riesgo (ver plan): _handleSaleOrderUpdated contiene la lógica
// de detección de conflictos con el formulario de edición (Canal HTTP vs
// Canal WebSocket) — es la sección más delicada del archivo original.
// Se movió tal cual, sin tocar ninguna condición.

mixin _SaleOrderNotificationHandlers {
  /// Provisto por [NotificationCounterNotifier] (via `Notifier<T>`).
  Ref get ref;

  /// Provisto por [NotificationCounterNotifier].
  AppDatabase get _db;

  /// Handle sale order created notification
  /// Fetches the new sale order from Odoo and updates local DB
  Future<void> _handleSaleOrderCreated(
    int orderId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ Repository not available for sale order refresh',
        );
        return;
      }

      // Refresh single sale order from Odoo
      await salesRepo.getById(orderId, forceRefresh: true);

      logger.d(
        '[NotificationProvider] ✅ Sale order $orderId created and synced',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order created: $e',
      );
    }
  }

  /// Handle sale order updated notification with conflict resolution
  Future<void> _handleSaleOrderUpdated(
    int orderId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ Repository not available for sale order refresh',
        );
        return;
      }

      // Obtener datos del payload
      // changed_fields puede ser Map o List dependiendo de dónde viene la notificación
      // - Desde sale.order.write(): Map<String, dynamic> con old/new values
      // - Desde sale.order.line._notify_parent_orders(): List<String> de nombres de campos
      Map<String, dynamic>? changedFields;
      final rawChangedFields = payload['changed_fields'];
      if (rawChangedFields is Map<String, dynamic>) {
        changedFields = rawChangedFields;
      } else if (rawChangedFields is List) {
        // Convertir lista a mapa vacío (solo nos importa que hay cambios)
        changedFields = {
          for (var field in rawChangedFields) field.toString(): true,
        };
      }
      final serverUserName = payload['user_name'] as String?;
      final writeDate = payload['write_date'] as String?;

      // Verificar si la orden está siendo editada localmente (usar provider unificado)
      final formNotifier = ref.read(saleOrderFormProvider.notifier);
      final formState = ref.read(saleOrderFormProvider);

      if (formState.order?.id == orderId &&
          formState.isEditing &&
          formState.hasChanges) {
        // La orden está siendo editada localmente - verificar conflictos
        logger.d(
          '[NotificationProvider] ⚠️ Order $orderId is being edited locally, checking conflicts...',
        );

        if (changedFields != null) {
          final hasConflict = formNotifier.processServerUpdate(
            serverChangedFields: changedFields,
            serverUserName: serverUserName,
            serverWriteDate: writeDate != null
                ? DateTime.parse(writeDate)
                : DateTime.now(),
          );

          if (hasConflict) {
            logger.d(
              '[NotificationProvider] ⚠️ Conflict detected! User will be notified.',
            );
            // El conflicto se maneja en el provider unificado
            // La UI mostrará el mensaje de conflicto
          }
        }
      } else {
        // Guard: ¿la orden local tiene cambios sin sincronizar (isSynced==false)?
        // `formState.isEditing` puede ser false aunque haya cambios locales
        // pendientes (ej. tras un restart de la app, o mientras el guardado
        // offline todavía no terminó de sincronizar con Odoo). Sin este
        // guard, el push del servidor pisaría esos cambios.
        //
        // NOTA: esto reemplaza el guard anterior basado en la tabla
        // `dirty_fields` — su único escritor (`WebSocketSyncService.
        // markFieldDirty()`) era código muerto sin consumidores y fue
        // eliminado (Fase B de sync-review), así que esa tabla SIEMPRE
        // estaba vacía y la protección nunca disparaba en producción.
        // `SaleOrder.isSynced` sí refleja fielmente si hay cambios locales
        // sin sincronizar — es una señal a nivel de registro completo (no
        // por campo individual como antes), pero es la señal real.
        final localOrder = await (_db.select(_db.saleOrder)
              ..where((t) => t.odooId.equals(orderId)))
            .getSingleOrNull();
        final hasUnsyncedLocalOrder =
            localOrder != null && !localOrder.isSynced;

        if (hasUnsyncedLocalOrder && changedFields != null) {
          // Releer el form state fresco: hubo un `await` (lookup de
          // localOrder) desde la primera lectura al inicio de la función, y
          // más abajo se vuelve a releer con su propio nombre `formState`
          // (variable de bloque distinta) para el chequeo de
          // `isViewingThisOrder` — evitamos aquí el conflicto de shadowing
          // usando un nombre propio.
          final currentFormState = ref.read(saleOrderFormProvider);
          if (currentFormState.order?.id == orderId) {
            // El formulario SÍ está mostrando esta orden (aunque no estaba
            // en modo edición activa) — delegar la detección de conflictos
            // al form notifier, que decide: aplicar directo (sin cambios
            // locales relevantes), mergear campos no conflictivos, o marcar
            // conflicto para que el usuario lo resuelva.
            logger.d(
              '[NotificationProvider] ⚠️ Order $orderId has unsynced local '
              'changes, delegating to form notifier for conflict check...',
            );
            formNotifier.processServerUpdate(
              serverChangedFields: changedFields,
              serverUserName: serverUserName,
              serverWriteDate: writeDate != null
                  ? DateTime.parse(writeDate)
                  : DateTime.now(),
            );
          } else {
            // El formulario no está mostrando esta orden ahora mismo — no
            // hay estado de UI que proteger con detección de conflictos,
            // pero SÍ hay cambios locales sin sincronizar en la DB: no los
            // pisamos con el push del servidor. Se reconciliará solo cuando
            // el sync pendiente de esta orden termine.
            logger.d(
              '[NotificationProvider] ⚠️ Order $orderId has unsynced local '
              'changes (not currently viewed) — skipping WS overwrite',
            );
          }
          // No continuar con la actualización directa
          return;
        }

        // La orden NO está siendo editada ni tiene cambios locales pendientes
        // - actualizar directamente
        logger.d(
          '[NotificationProvider] 🔄 Order $orderId not being edited, updating directly',
        );

        // Verificar si estamos viendo el detalle de esta orden
        final formState = ref.read(saleOrderFormProvider);
        final isViewingThisOrder = formState.order?.id == orderId;
        final values = payload['values'] as Map<String, dynamic>?;

        // Si estamos viendo esta orden, usar actualización granular SIN hacer fetch completo
        // Esto evita regenerar toda la UI
        if (isViewingThisOrder) {
          // Determinar qué datos usar para la actualización granular:
          // - Si hay 'values' en el payload, usarlos (formato estructurado)
          // - Si no, usar los campos directos del payload (formato simple de bus.bus)
          final Map<String, dynamic> updateData;
          if (values != null) {
            updateData = values;
          } else {
            // Construir mapa de valores desde los campos directos del payload
            // Esto maneja el formato de notificación de bus.bus que no tiene 'values'
            updateData = <String, dynamic>{};
            // Copiar campos relevantes del payload que son campos de sale.order
            const orderFields = [
              'id',
              'name',
              'state',
              'partner_id',
              'partner_name',
              'amount_untaxed',
              'amount_tax',
              'amount_total',
              'date_order',
              'validity_date',
              'commitment_date',
              'pricelist_id',
              'pricelist_name',
              'payment_term_id',
              'payment_term_name',
              'warehouse_id',
              'warehouse_name',
              'user_id',
              'user_name',
              'client_order_ref',
              'note',
            ];
            for (final field in orderFields) {
              if (payload.containsKey(field)) {
                updateData[field] = payload[field];
              }
            }
          }

          // Solo hacer actualización granular si hay datos
          if (updateData.isNotEmpty) {
            // NOTA: ya NO llamamos directo a
            // saleOrderFormProvider.notifier.updateOrderFromWebSocket aquí.
            // Ese bypass (Canal 2 escribiendo directo al estado de UI) tenía
            // un bug: si el usuario estaba editando (`isEditing=true`), el
            // método descartaba el update EN SILENCIO y para siempre, sin
            // dejarlo pendiente — a diferencia del canal correcto (streams
            // de Drift `saleOrderStreamProvider`/`saleOrderLinesStreamProvider`
            // en `sale_order_form_screen.dart`, que sí usa
            // `setServerUpdatePending` para no perder el cambio). El
            // `salesRepo.getById()` de abajo escribe en Drift, y ese stream
            // ya cubre la actualización del formulario — no hace falta
            // duplicar el canal (race condition corregida).
            //
            // FastSale (POS) SÍ mantiene su actualización granular directa:
            // su implementación de updateOrderFromWebSocket ya aplica
            // correctamente el cambio del servidor y solo marca conflicto
            // para la UI en vez de descartarlo (ver
            // fast_sale_notifier_websocket.dart).
            ref
                .read(fastSaleProvider.notifier)
                .updateOrderFromWebSocket(orderId, updateData);
          }

          // Log de campos actualizados
          final changedFields = payload['changed_fields'];
          logger.d(
            '[NotificationProvider] 🎯 Granular update for order $orderId: '
            'changed_fields=$changedFields (skipped full fetch)',
          );

          // Actualizar la lista en background sin bloquear la UI.
          // El Sale Order Form (si está abierto) se actualiza reactivamente
          // vía su stream de Drift cuando este upsert local se complete.
          unawaited(salesRepo.getById(orderId, forceRefresh: true));
        } else {
          // NO estamos viendo esta orden - hacer fetch completo
          await salesRepo.getById(orderId, forceRefresh: true);
        }
      }

      logger.d('[NotificationProvider] ✅ Sale order $orderId update handled');
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order updated: $e',
      );
    }
  }

  /// Handle sale order deleted notification
  Future<void> _handleSaleOrderDeleted(
    int orderId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) return;

      // Si la orden estaba siendo editada, limpiar estado
      final formState = ref.read(saleOrderFormProvider);
      if (formState.order?.id == orderId) {
        ref.read(saleOrderFormProvider.notifier).clearState();
        logger.d(
          '[NotificationProvider] 🗑️ Cleared edit state for deleted order $orderId',
        );
      }

      // Eliminar de la DB local
      await salesRepo.deleteLocal(orderId);

      logger.d(
        '[NotificationProvider] ✅ Sale order $orderId deleted and removed from local DB',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order deleted: $e',
      );
    }
  }
}
