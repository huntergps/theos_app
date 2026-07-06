import 'package:theos_pos_core/theos_pos_core.dart';

import '../../services/conflict_detection_service.dart';
import '../sale_order_form_state.dart';

// =============================================================================
// DISEÑO — Fase F2: unificación de SaleOrderServerUpdateMixin +
// SaleOrderConflictResolutionMixin
// =============================================================================
//
// ## Mapeo de los dos canales que llegaban aquí
//
// **Canal A — streams de Drift (`sale_order_form_screen.dart`)**: el widget
// escucha `saleOrderStreamProvider`/`saleOrderLinesStreamProvider` (Drift
// `.watch()`, reacciona a CUALQUIER escritura local a la DB — HTTP propio,
// sync, u otro canal). En `build()`:
//   - Si NO está editando → `updateOrderFromSync(newOrder, lines)` (Utility):
//     sobreescritura completa, sin detección de conflictos (no hay cambios
//     locales que proteger en modo vista).
//   - Si SÍ está editando → `setServerUpdatePending(newOrder, lines)`: solo
//     guarda el dato, NO detecta conflictos todavía.
//   - La detección de conflictos ocurre después, en `applyPendingServerUpdate()`
//     (al hacer clic en "Aplicar", o automáticamente al salir de modo edición
//     vía `exitEditMode()`): usa `ConflictDetectionService.detectOrderConflicts`
//     + `detectLineConflicts` (servicio compartido), hace merge quirúrgico de
//     los campos NO conflictivos (`_applyMergeableFields`) y de las líneas NO
//     conflictivas (`_applyPendingLinesMerge`), preservando el resto de los
//     cambios locales no guardados.
//   - `ConflictBanner` (UI) ofrece "Aceptar servidor" → `acceptServerChanges()`
//     (descarta campos en conflicto + refetch completo) o "Mantener local" →
//     `keepLocalChanges()` (solo limpia el flag de conflicto).
//
// **Canal B — WebSocket puntual (`notification_handlers_sale_order.dart`)**:
// reacciona a una notificación push de `sale_order_updated` con un diff
// parcial de campos (`serverChangedFields`, formato `{'campo': {'old':..,
// 'new':..}}`). Si la orden está siendo editada Y tiene cambios locales →
// `processServerUpdate(serverChangedFields, ...)`:
//   - Compara campo por campo el diff del servidor contra `state.changedFields`
//     con un loop manual propio — **NO usa `ConflictDetectionService`**, es
//     una segunda implementación de detección de conflictos, independiente.
//   - Si hay overlap → mismo estado compartido (`hasConflict`/`conflicts`/
//     `conflictMessage`) que Canal A, así que el mismo `ConflictBanner` se
//     muestra sin importar qué canal detectó el conflicto (el ESTADO ya
//     estaba unificado antes de este refactor — no había duplicación ahí).
//   - Si NO hay overlap pero SÍ hay campos para mergear → llama `refreshOrder()`
//     (`loadOrder(forceRefresh:true)`): un refetch COMPLETO que descarta TODOS
//     los cambios locales no guardados, no solo los campos mergeados. Esto es
//     distinto al merge quirúrgico de Canal A.
//
// ## Redundancias REALES identificadas (y qué se hizo con cada una)
//
// 1. **Dos algoritmos de detección de conflictos independientes** para el
//    mismo concepto (campos de cabecera): el de `ConflictDetectionService`
//    (Canal A) vs el loop manual de `processServerUpdate` (Canal B).
//    **NO SE FUSIONAN** — ver sección "Qué NO se unificó" abajo.
// 2. **`_clearPendingState()` y `clearServerUpdatePending()` — cuerpos
//    IDÉNTICOS** (mismo `state.copyWith(serverUpdatePending:false,
//    pendingServerOrder:null, pendingServerLines:null)`), uno privado (llamado
//    2x dentro de `applyPendingServerUpdate`) y otro público (llamado por el
//    botón de cerrar en `sale_order_form_screen.dart`). **SÍ SE FUSIONA**:
//    se eliminó `_clearPendingState()` y `applyPendingServerUpdate()` ahora
//    llama directo a `clearServerUpdatePending()` (mismo nombre público,
//    mismo comportamiento, cero cambio observable).
// 3. **`resolveConflictsWithServer()`, `resolveConflictsWithLocal()`,
//    `detectConflictsWithServer()` — código muerto**: verificado con grep
//    exhaustivo en todo `theos_pos/lib` y `theos_pos/test` que ninguno tenía
//    consumidores. Ya se eliminaron en el primer paso de este refactor (F2,
//    paso 1). `resolveConflictsWithLocal()` era además un wrapper de una
//    línea sobre `keepLocalChanges()` (que sí se usa).
// 4. **Los dos mixins en archivos separados** (`SaleOrderServerUpdateMixin`
//    + `SaleOrderConflictResolutionMixin`) manejaban el MISMO concepto
//    (conflicto local-vs-servidor) con declaraciones abstractas cruzadas
//    (`keepLocalChanges()` declarado abstracto en uno, implementado en el
//    otro). **SÍ SE FUSIONAN** en este único archivo/mixin
//    (`SaleOrderConflictMixin`) — elimina la necesidad de la declaración
//    abstracta cruzada, ya que ahora es una llamada directa dentro del mismo
//    mixin. Verificado con grep que ninguno de los dos nombres de mixin
//    (`SaleOrderServerUpdateMixin`/`SaleOrderConflictResolutionMixin`) se
//    referencia fuera de `sale_order_form_notifier.dart` — son libres de
//    renombrar/fusionar sin afectar consumidores externos.
//
// ## Qué NO se unificó (y por qué)
//
// Los dos ALGORITMOS de detección de conflictos (Canal A vs Canal B) **no se
// fusionan** pese a ser conceptualmente el mismo problema. Razones concretas:
//
// - Requeriría reconstruir un `SaleOrder` completo a partir del diff parcial
//   de WebSocket (`serverChangedFields`) para poder llamar a
//   `ConflictDetectionService.detectOrderConflicts` (que espera un
//   `SaleOrder serverOrder` completo, no un diff) — es un cambio de
//   arquitectura en `notification_handlers_sale_order.dart`, archivo FUERA de
//   mi alcance en esta fase (`sale_order_form_mixins/**` +
//   `sale_order_form_notifier.dart` solamente).
// - Cambiaría comportamiento observable real: hoy, cuando Canal B mergea sin
//   conflicto, hace un refetch COMPLETO (`refreshOrder()`) que descarta
//   cualquier cambio local no relacionado al campo mergeado — a diferencia
//   del merge quirúrgico de Canal A. Unificar significaría CAMBIAR ese
//   comportamiento (posible bug real: un cambio local no conflictivo se
//   pierde si Canal B dispara primero) — pero corregirlo es una decisión de
//   producto/arquitectura, no una reorganización de código, y este archivo
//   maneja dinero real sin tests directos (ver plan original). Queda
//   señalado explícitamente para revisión de integration-engineer, tal como
//   ya indicaba el plan original de d-arch.
// - El ESTADO compartido (`hasConflict`/`conflicts`/`conflictMessage`) YA
//   estaba unificado antes de este refactor (ambos canales escriben al mismo
//   store) — no hay duplicación de estado que resolver ahí.
//
// =============================================================================

/// Mixin unificado de actualizaciones pendientes del servidor + resolución
/// de conflictos para [SaleOrderFormNotifier].
///
/// Fusiona `SaleOrderServerUpdateMixin` + `SaleOrderConflictResolutionMixin`
/// (Fase E2b) en un solo archivo/mixin (Fase F2) — ver diseño completo en el
/// comentario de arriba. **Ningún nombre ni firma de método público cambió**:
/// `setServerUpdatePending`, `applyPendingServerUpdate`, `processServerUpdate`,
/// `acceptServerChanges`, `keepLocalChanges`, `clearConflict`,
/// `clearServerUpdatePending`, `updatePartnerFieldsOnly`, `clearError` siguen
/// exactamente igual para sus consumidores externos (`sale_order_form_screen.dart`,
/// `form_header.dart`, `notification_handlers_sale_order.dart`,
/// `notification_handlers_partner_user_company.dart`).
///
/// **ÁREA DE RIESGO ALTO**: contiene el mecanismo de staging de updates del
/// servidor mientras el usuario edita, corregido en Fase B/C para no perder
/// cambios locales cuando llega un push de WebSocket mientras
/// `isEditing==true`. La lógica de cada método individual NO se modificó —
/// solo se fusionaron los dos archivos y se eliminó la duplicación exacta
/// de `_clearPendingState`/`clearServerUpdatePending`.
mixin SaleOrderConflictMixin {
  /// Estado actual del formulario - debe ser implementado por el notifier
  SaleOrderFormState get state;

  /// Metodo para actualizar estado - debe ser implementado por el notifier
  set state(SaleOrderFormState newState);

  /// Implementado por [SaleOrderUtilityMixin]
  void updateOrderFromSync(SaleOrder order, List<SaleOrderLine> lines);

  /// Implementado por [SaleOrderUtilityMixin]
  Future<void> refreshOrder();

  /// Implementado por [SaleOrderLoaderMixin]
  Future<void> loadOrder(int orderId, {bool forceRefresh = false});

  // ===========================================================================
  // Canal A: staging de updates pendientes (streams de Drift)
  // ===========================================================================

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
      clearServerUpdatePending();
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

    clearServerUpdatePending();
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

  /// Clear the pending flag without applying (e.g., user dismissed it).
  ///
  /// FASE F2: antes existían DOS métodos con el cuerpo idéntico —
  /// `clearServerUpdatePending()` (público, usado por el botón de cerrar en
  /// `sale_order_form_screen.dart`) y `_clearPendingState()` (privado, usado
  /// 2x dentro de `applyPendingServerUpdate`). Se fusionaron en este único
  /// método — `applyPendingServerUpdate()` ahora llama directo acá.
  void clearServerUpdatePending() {
    state = state.copyWith(
      serverUpdatePending: false,
      pendingServerOrder: null,
      pendingServerLines: null,
    );
  }

  // ===========================================================================
  // Canal B: notificación puntual de WebSocket (sale.order.write)
  // ===========================================================================

  /// Procesar actualización del servidor (desde WebSocket)
  ///
  /// Detecta conflictos entre cambios locales y cambios del servidor.
  /// Retorna true si hay conflicto que requiere atención del usuario.
  ///
  /// NOTA (ver diseño arriba): usa su propia comparación campo-por-campo, NO
  /// [ConflictDetectionService] — es una segunda vía de detección de
  /// conflictos, deliberadamente NO fusionada con la de
  /// [applyPendingServerUpdate] en esta fase (requeriría reconstruir un
  /// [SaleOrder] completo desde el diff parcial de WebSocket en
  /// `notification_handlers_sale_order.dart`, archivo fuera de mi alcance, y
  /// cambiaría comportamiento observable real).
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
  ///
  /// Consumido directamente por `ConflictBanner.onAcceptServer` en
  /// `sale_order_form_screen.dart`.
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
  ///
  /// Consumido directamente por `ConflictBanner.onKeepLocal` en
  /// `sale_order_form_screen.dart`.
  void keepLocalChanges() {
    logger.d('[SaleOrderForm]', 'Keeping local changes, user will re-save');
    state = state.copyWith(
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
    );
  }

  /// Limpiar estado de conflicto
  ///
  /// Consumido directamente desde `form_header.dart`.
  void clearConflict() {
    state = state.copyWith(
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
    );
  }

  // ===========================================================================
  // Utilidades varias (agrupadas acá desde la Fase E2b original)
  // ===========================================================================

  /// Actualizar todos los campos del partner sin recargar toda la orden
  ///
  /// Usado por WebSocket notifications para actualizar campos desnormalizados
  /// sin causar un rebuild completo del formulario. Consumido desde
  /// `notification_handlers_partner_user_company.dart`.
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
  ///
  /// Consumido directamente desde `sale_order_form_screen.dart`.
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
