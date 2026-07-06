// Part of odoo_model_manager library
part of 'odoo_model_manager.dart';

/// Odoo action calls mixin for OdooModelManager.
///
/// Provides methods for calling Odoo workflow actions:
/// - [callOdooAction] for single-record actions (e.g., action_confirm)
/// - [callOdooActionMulti] for multi-record actions
mixin _ManagerActionsMixin<T> on _OdooModelManagerBase<T> {
  /// Call an Odoo action method on a record.
  ///
  /// Used for workflow methods like action_confirm, action_cancel, etc.
  ///
  /// ```dart
  /// await manager.callOdooAction(orderId, 'action_confirm');
  /// ```
  Future<dynamic> callOdooAction(
    int recordId,
    String action, {
    Map<String, dynamic>? kwargs,
  }) async {
    if (!isOnline) {
      throw StateError('Cannot call Odoo action while offline');
    }

    if (recordId <= 0) {
      throw ArgumentError('Cannot call action on local-only record');
    }

    try {
      final result = await _client!.call(
        model: odooModel,
        method: action,
        ids: [recordId],
        kwargs: kwargs,
      );

      // Refresh local record after action
      await _syncRecordInBackground(recordId);

      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Call an Odoo action on multiple records.
  Future<dynamic> callOdooActionMulti(
    List<int> recordIds,
    String action, {
    Map<String, dynamic>? kwargs,
  }) async {
    if (!isOnline) {
      throw StateError('Cannot call Odoo action while offline');
    }

    final validIds = recordIds.where((id) => id > 0).toList();
    if (validIds.isEmpty) {
      throw ArgumentError('No valid record IDs provided');
    }

    try {
      final result = await _client!.call(
        model: odooModel,
        method: action,
        ids: validIds,
        kwargs: kwargs,
      );

      // Refresh local records after action
      for (final id in validIds) {
        await _syncRecordInBackground(id);
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Llamada RPC genérica model-scoped a un método custom de Odoo.
  ///
  /// A diferencia de [callOdooAction]/[callOdooActionMulti] (pensados para
  /// acciones de workflow sobre un recordset **existente** — requieren
  /// `recordId > 0` y refrescan el registro local en background tras
  /// ejecutar), este método sirve para llamadas RPC "de servicio" que no
  /// necesariamente operan sobre un recordset local conocido (métodos
  /// `@api.model`, búsquedas/consultas custom, helpers de servidor,
  /// wizards) y **no** dispara ningún refresco/sync automático — el
  /// llamador decide qué hacer con el resultado.
  ///
  /// Este es el punto de entrada recomendado para que los repositorios de
  /// la app dejen de guardar su propio `OdooClient?` para RPC custom: en
  /// vez de `_odooClient!.call(model: 'x.y', method: 'z', ...)`, usar
  /// `xManager.callCustomMethod('z', ...)` cuando el método pertenece al
  /// mismo modelo Odoo que gestiona `xManager`. Si el método pertenece a
  /// OTRO modelo (ej. un wizard), usar el manager de ESE modelo si existe;
  /// solo si no existe ningún manager para ese modelo se justifica seguir
  /// usando el `OdooClient` directamente (documentar la excepción).
  ///
  /// Respeta la semántica JSON-2 documentada en `OdooClient.call`:
  /// - [ids] construye el recordset (`self`) — vacío/omitido es válido para
  ///   métodos `@api.model` que no operan sobre un recordset específico.
  /// - [kwargs] son los parámetros nombrados reales del método Python
  ///   destino (ver `OdooClient.call` para el porqué NO existe un parámetro
  ///   `args` acá — el dispatcher JSON-2 no trata "args" como posicional).
  ///
  /// El `model` del request es siempre [odooModel] (el modelo propio de
  /// este manager) — para llamar un método de OTRO modelo, usar el manager
  /// de ese modelo.
  ///
  /// El resultado se castea a [T2] — el llamador es responsable de pasar el
  /// tipo correcto según lo que el método Odoo realmente retorna (ej.
  /// `List<dynamic>` para `search_read`, `bool` para `write`, `int?` para
  /// `create`, `dynamic`/`Map` para wizards).
  ///
  /// ```dart
  /// // Método @api.model sin recordset:
  /// final result = await userManager.callCustomMethod<bool>(
  ///   'change_password',
  ///   kwargs: {'old_passwd': old, 'new_passwd': new},
  /// );
  ///
  /// // Método de recordset (acción sobre registros existentes, sin
  /// // refresco automático):
  /// final data = await saleOrderManager.callCustomMethod<List<dynamic>>(
  ///   'read_group',
  ///   kwargs: {'domain': [...], 'fields': [...], 'groupby': [...]},
  /// );
  /// ```
  Future<T2> callCustomMethod<T2>(
    String method, {
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    if (!isOnline) {
      throw StateError(
        'Cannot call $odooModel.$method while offline (client not configured)',
      );
    }

    final result = await _client!.call(
      model: odooModel,
      method: method,
      ids: ids,
      kwargs: kwargs,
    );

    return result as T2;
  }
}
