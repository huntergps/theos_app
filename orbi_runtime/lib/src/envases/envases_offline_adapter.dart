/// Despachador de la cola offline para envases: crea el asistente nativo de
/// Odoo (`create` + `action_*`) siguiendo el molde de
/// `_applyNativePaymentWizard` (`../sales/sale_runtime_adapters.dart`).
///
/// Deliberadamente NO vive en el `if` de 2500 líneas de
/// `OdooOfflineOperationAdapter`: es un `OfflineOperationAdapter`
/// independiente. El enganche al coordinador (un adaptador que decida por
/// `operation.model` cuál de los dos invocar) lo hace quien integra —
/// `stock.picking` no lo usa hoy ningún caso de la cola de ventas
/// (comprobado: `grep -n "operation.model ==" sale_runtime_adapters.dart` no
/// menciona `stock.picking`), así que no hay colisión de modelos que resolver.
library;

import 'package:odoo_sdk/odoo_sdk.dart'
    show
        ConflictInfo,
        OdooAccessDeniedException,
        OdooValidationException,
        OfflineOperation,
        OfflineReplayPolicy,
        formatOdooDateTime;
import 'package:theos_pos_core/theos_pos_core.dart';

import '../contracts.dart' show AppScope;
import '../sales/sale_runtime_adapters.dart' show SaleOdooActions;
import '../sync/operations_sync_job.dart';
import 'envases_operations_durable.dart';

/// Reconoce y despacha exactamente las tres operaciones que
/// `DurableEnvasesOperations` encola: `envio`, `recepcion` y `perdido`.
/// Cualquier otro modelo/método lanza `StateError` — igual que el `else`
/// final del adaptador de ventas — porque un router es responsabilidad de
/// quien integra, no de este adaptador.
final class EnvasesOfflineOperationAdapter implements OfflineOperationAdapter {
  const EnvasesOfflineOperationAdapter({
    required this.actions,
    required this.database,
    required this.scope,
    this.store = const EnvasesOperationsStore(),
  });

  final SaleOdooActions actions;
  final AppDatabase database;
  final AppScope scope;
  final EnvasesOperationsStore store;

  @override
  Future<OperationReconciliation> reconcile(OfflineOperation operation) async {
    final uuid = operation.values['operacion_uuid'] as String;
    if (operation.model == envasesEnvioModel &&
        operation.method == envasesEnvioMethod) {
      return _reconcileByUuid(uuid: uuid);
    }
    if (operation.model == envasesRecepcionModel &&
        operation.method == envasesRecepcionMethod) {
      final pickingId = (operation.values['picking_id'] as num).toInt();
      return _reconcileRecepcion(uuid: uuid, pickingId: pickingId);
    }
    if (operation.model == envasesPerdidoModel &&
        operation.method == envasesPerdidoMethod) {
      final pickingId = (operation.values['picking_id'] as num).toInt();
      return _reconcilePerdido(uuid: uuid, pickingId: pickingId);
    }
    throw StateError(
      'Unsupported durable envases operation ${operation.model}.${operation.method}',
    );
  }

  @override
  Future<ConflictInfo?> dispatch(OfflineOperation operation) async {
    if (operation.model == envasesEnvioModel &&
        operation.method == envasesEnvioMethod) {
      return _dispatchEnvio(operation);
    }
    if (operation.model == envasesRecepcionModel &&
        operation.method == envasesRecepcionMethod) {
      return _dispatchRecepcion(operation);
    }
    if (operation.model == envasesPerdidoModel &&
        operation.method == envasesPerdidoMethod) {
      return _dispatchPerdido(operation);
    }
    throw StateError(
      'Unsupported durable envases operation ${operation.model}.${operation.method}',
    );
  }

  // --------------------------------------------------------------------
  // reconcile()
  // --------------------------------------------------------------------

  /// Fuente atómica de reconciliación (contrato confirmado 14-sep-2026, en
  /// sesión con Odoo): la fila de `l10n_ec.envases.operacion` con este
  /// `uuid` existe SI Y SOLO SI la operación se confirmó. Ya no se infiere
  /// por el estado de un `stock.picking` — ese picking de salida queda
  /// `done` al validarse (el envío es instantáneo), así que su estado no
  /// dice nada sobre si la operación se aplicó.
  ///
  /// Si la fila existe con OTRO `tipo` del esperado, el mismo uuid lo usó
  /// una operación distinta — Odoo ya la rechaza con un `UserError` al
  /// `create`, así que esto sólo debería poder pasar por una carrera
  /// rarísima o un bug de generación de uuid. `OperationReconciliation`
  /// (`../sync/operations_sync_job.dart`) no tiene una variante pensada
  /// para esto: la única de conflicto es `OperationConflict`, que exige un
  /// `ConflictInfo` con fechas de escritura local/servidor — pensado para
  /// el choque por `write_date` que resuelve la pantalla SYN-03 — y
  /// forzarlo aquí dispararía el mensaje «el servidor cambió este
  /// registro...», que es falso para este caso. Se deja como no aplicada,
  /// con aviso a mano.
  Future<OperationReconciliation> _reconcileEnvasesOperacion({
    required String uuid,
    required String tipoEsperado,
    required Future<int?> Function() pickingId,
  }) async {
    final result = await actions.call(
      model: envasesOperacionModel,
      method: 'search_read',
      kwargs: {
        'domain': [
          ['uuid', '=', uuid],
        ],
        'fields': ['tipo', 'picking_ids'],
        'limit': 1,
      },
    );
    final rows = result is List ? result.whereType<Map>().toList() : const <Map>[];
    if (rows.isEmpty) return const OperationNotApplied();
    final tipo = rows.first['tipo'] as String?;
    if (tipo != tipoEsperado) {
      await store.markRevisarAMano(
        database,
        scopeKey: scope.scopeKey,
        operationUuid: uuid,
        mensaje:
            'El identificador de esta operación ya lo usó otra operación '
            'de tipo $tipo en Odoo.',
      );
      return const OperationNotApplied();
    }
    await store.markEnviada(
      database,
      scopeKey: scope.scopeKey,
      operationUuid: uuid,
      pickingId: await pickingId(),
    );
    return const OperationApplied();
  }

  /// El `pickingId` de un envío aplicado es la RECEPCIÓN PENDIENTE que
  /// generó, nunca el picking de salida (ese queda `done`). Se apoya en
  /// `stock.picking.envases_envio_operacion_uuid` (el uuid del envío,
  /// distinto de `envases_operacion_uuid` que llevaría una recepción
  /// propia) — dominio confirmado por la sesión de Odoo del 14-sep-2026.
  Future<OperationReconciliation> _reconcileByUuid({required String uuid}) {
    return _reconcileEnvasesOperacion(
      uuid: uuid,
      tipoEsperado: 'envio',
      pickingId: () => _buscarRecepcionPendiente(uuid),
    );
  }

  /// El `pickingId` de una recepción ya se conoce de entrada (es «el
  /// recibido»): a diferencia del envío, no hace falta ir a buscarlo. Y a
  /// propósito ya NO se exige que ESE picking lleve el uuid — con
  /// recepciones parciales/backorder ese picking concreto puede no
  /// tenerlo aunque la operación sí se haya aplicado; la fuente de verdad
  /// es la fila de `l10n_ec.envases.operacion`.
  Future<OperationReconciliation> _reconcileRecepcion({
    required String uuid,
    required int pickingId,
  }) {
    return _reconcileEnvasesOperacion(
      uuid: uuid,
      tipoEsperado: 'recepcion',
      pickingId: () async => pickingId,
    );
  }

  /// Sólo informativo — nunca puede convertir un envío YA APLICADO en
  /// fallido: si el sondeo lanza (red, timeout, lo que sea), se traga el
  /// error y devuelve `null`. El próximo `reconcile()` con conexión ya
  /// encontrará la recepción pendiente.
  Future<int?> _buscarRecepcionPendiente(String uuid) async {
    try {
      final found = await actions.call(
        model: 'stock.picking',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['envases_envio_operacion_uuid', '=', uuid],
            [
              'state',
              'in',
              ['confirmed', 'waiting', 'assigned'],
            ],
          ],
          'fields': ['id'],
          'limit': 1,
        },
      );
      if (found is List && found.isNotEmpty) {
        return ((found.first as Map)['id'] as num).toInt();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// «Dar por perdido» se reconcilia por ESTADO del picking, nunca por
  /// `envases_operacion_uuid` — por eso siempre es `retry_safe`
  /// (`DurableEnvasesOperations.darPorPerdido`). Si ya no está pendiente
  /// (`confirmed`/`waiting`/`assigned`), alguien ya lo resolvió — no
  /// importa si fue este intento o uno anterior.
  Future<OperationReconciliation> _reconcilePerdido({
    required String uuid,
    required int pickingId,
  }) async {
    final result = await actions.call(
      model: 'stock.picking',
      method: 'read',
      ids: [pickingId],
      kwargs: {
        'fields': ['state'],
      },
    );
    final rows = result is List ? result : const [];
    if (rows.isEmpty) return const OperationNotApplied();
    final state = (rows.first as Map)['state'] as String?;
    const pendientes = {'confirmed', 'waiting', 'assigned'};
    if (state != null && !pendientes.contains(state)) {
      await store.markEnviada(
        database,
        scopeKey: scope.scopeKey,
        operationUuid: uuid,
        pickingId: pickingId,
      );
      return const OperationApplied();
    }
    return const OperationNotApplied();
  }

  // --------------------------------------------------------------------
  // dispatch()
  // --------------------------------------------------------------------

  Future<ConflictInfo?> _dispatchEnvio(OfflineOperation operation) async {
    final values = operation.values;
    final uuid = values['operacion_uuid'] as String;
    return _runGuarded(
      operation: operation,
      uuid: uuid,
      action: () async {
        final fechaSalida = DateTime.parse(values['fecha_salida'] as String);
        final lineas = (values['lineas'] as List).cast<Map>();
        final created = await actions.call(
          model: envasesEnvioModel,
          method: 'create',
          kwargs: {
            'vals_list': [
              {
                'origen_id': (values['origen_id'] as num).toInt(),
                'destino_id': (values['destino_id'] as num).toInt(),
                'fecha_salida': formatOdooDateTime(fechaSalida),
                'responsable_id': (values['responsable_id'] as num).toInt(),
                // Sólo se manda si el sondeo (`fields_get`, ver
                // `_resolveEnvioRecepcionReplayPolicy`) ya confirmó que el
                // servidor tiene el campo: mandarlo sin esa confirmación
                // revienta el `create` con `Invalid field` en un servidor
                // viejo (19.5.1.2.0) y la operación nunca llega a Odoo.
                if (operation.replayPolicy == OfflineReplayPolicy.retrySafe)
                  'envases_operacion_uuid': uuid,
                'line_ids': [
                  for (final linea in lineas)
                    [
                      0,
                      0,
                      {
                        'product_id': (linea['product_id'] as num).toInt(),
                        'cantidad': (linea['cantidad'] as num).toDouble(),
                      },
                    ],
                ],
              },
            ],
          },
        );
        final wizardId = _createdId(created);
        if (wizardId == null) {
          throw const AmbiguousOperationException(
            'envases wizard.envio create returned no id',
          );
        }
        await actions.call(
          model: envasesEnvioModel,
          method: 'action_enviar',
          ids: [wizardId],
        );
        // Informativa y sólo con `retry_safe` (con `manual_after_ambiguous`
        // el servidor puede ni tener `envases_envio_operacion_uuid`): busca
        // la recepción pendiente que este envío generó. `_buscarRecepcionPendiente`
        // nunca lanza — si falla, el envío se marca enviado igual, con
        // `pickingId` null, porque `action_enviar` YA se aplicó y no hay
        // vuelta atrás.
        final pickingId = operation.replayPolicy == OfflineReplayPolicy.retrySafe
            ? await _buscarRecepcionPendiente(uuid)
            : null;
        await store.markEnviada(
          database,
          scopeKey: scope.scopeKey,
          operationUuid: uuid,
          pickingId: pickingId,
        );
      },
    );
  }

  Future<ConflictInfo?> _dispatchRecepcion(OfflineOperation operation) async {
    final values = operation.values;
    final uuid = values['operacion_uuid'] as String;
    final pickingId = (values['picking_id'] as num).toInt();
    return _runGuarded(
      operation: operation,
      uuid: uuid,
      action: () async {
        final lineas = (values['lineas'] as List).cast<Map>();
        // Sin `line_ids` en los vals: el `create()` de
        // `l10n_ec.stock.envases.wizard.recepcion` (wizards/wizard_recepcion.py:70-76)
        // las auto-llena desde `picking_id` — una línea por movimiento
        // abierto encadenado (`_envases_lineas_desde_picking`, líneas
        // 78-106), con `pendientes = llegaron = move.product_uom_qty`. Esa
        // es la única fuente fiable de `move_id`/`pendientes`: no se arma a
        // mano aquí para no duplicar ese dominio.
        final created = await actions.call(
          model: envasesRecepcionModel,
          method: 'create',
          kwargs: {
            'vals_list': [
              {
                'picking_id': pickingId,
                'responsable_id': (values['responsable_id'] as num).toInt(),
                // Misma regla que en `_dispatchEnvio`: sólo con
                // `retry_safe`, porque ahí el sondeo ya confirmó el campo.
                if (operation.replayPolicy == OfflineReplayPolicy.retrySafe)
                  'envases_operacion_uuid': uuid,
              },
            ],
          },
        );
        final wizardId = _createdId(created);
        if (wizardId == null) {
          throw const AmbiguousOperationException(
            'envases wizard.recepcion create returned no id',
          );
        }
        final existingLines = await actions.call(
          model: '$envasesRecepcionModel.line',
          method: 'search_read',
          kwargs: {
            'domain': [
              ['wizard_id', '=', wizardId],
            ],
            'fields': ['id', 'product_id'],
          },
        );
        final rows = existingLines is List
            ? existingLines.whereType<Map>().toList()
            : const <Map>[];
        for (final linea in lineas) {
          final productId = (linea['product_id'] as num).toInt();
          Map? match;
          for (final row in rows) {
            if (_relationId(row['product_id']) == productId) {
              match = row;
              break;
            }
          }
          if (match == null) {
            throw StateError(
              'Envases: no se encontró línea pendiente para el producto '
              '$productId en el picking $pickingId',
            );
          }
          await actions.call(
            model: '$envasesRecepcionModel.line',
            method: 'write',
            ids: [(match['id'] as num).toInt()],
            kwargs: {
              'vals': {
                'llegaron': (linea['llegaron'] as num).toDouble(),
                'danadas': (linea['danadas'] as num).toDouble(),
              },
            },
          );
        }
        await actions.call(
          model: envasesRecepcionModel,
          method: 'action_recibir',
          ids: [wizardId],
        );
        await store.markEnviada(
          database,
          scopeKey: scope.scopeKey,
          operationUuid: uuid,
          pickingId: pickingId,
        );
      },
    );
  }

  Future<ConflictInfo?> _dispatchPerdido(OfflineOperation operation) async {
    final values = operation.values;
    final uuid = values['operacion_uuid'] as String;
    final pickingId = (values['picking_id'] as num).toInt();
    return _runGuarded(
      operation: operation,
      uuid: uuid,
      action: () async {
        await actions.call(
          model: envasesPerdidoModel,
          method: envasesPerdidoMethod,
          ids: [pickingId],
        );
        await store.markEnviada(
          database,
          scopeKey: scope.scopeKey,
          operationUuid: uuid,
          pickingId: pickingId,
        );
      },
    );
  }

  /// Requisito E del encargo: un rechazo de negocio de Odoo
  /// (`UserError`/`ValidationError`, mapeados por el SDK a
  /// `OdooValidationException` — confirmado en
  /// `odoo_sdk/lib/src/api/odoo_error_mapper.dart:108-116`) termina la
  /// operación como `rechazada`, sin reintentar: se devuelve `null` (éxito
  /// para la cola, que la remueve) porque el estado local ya cuenta la
  /// historia real.
  ///
  /// Un `AccessError` (permisos de Odoo, ej. `action_envases_dar_por_perdido`
  /// exige `group_envases_manager` —
  /// `l10n_ec_stock_envases/models/stock_picking.py:171-181`) termina IGUAL
  /// de terminal: el SDK lo mapea a `OdooAccessDeniedException`, NO a
  /// `OdooValidationException` (`odoo_error_mapper.dart:84-86`), así que sin
  /// esta rama caía en el `catch` genérico de abajo y, siendo casi siempre
  /// `retry_safe`, la cola lo reintentaba para siempre — un permiso no se
  /// arregla reintentando. Se anota `rechazada` con un mensaje en español
  /// que diga que es un problema de permiso, más el detalle del servidor.
  ///
  /// Cualquier otro error bajo `manual_after_ambiguous` (sin evidencia
  /// durable con la que reconciliar — servidor sin
  /// `envases_operacion_uuid`) se anota como `revisarAMano` ANTES de dejar
  /// que la cola decida su propio destino (reintento con backoff si fuera
  /// `retry_safe`, o `dead_letter` inmediato si es `manual_after_ambiguous`
  /// — ver `OfflineQueueProcessor.processQueue`). La red o un 5xx de
  /// transporte no se tocan aquí: siguen en `pendienteDeEnviar` porque
  /// nunca pasan por este `catch`.
  Future<ConflictInfo?> _runGuarded({
    required OfflineOperation operation,
    required String uuid,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
      return null;
    } on OdooValidationException catch (error) {
      await store.markRechazada(
        database,
        scopeKey: scope.scopeKey,
        operationUuid: uuid,
        mensaje: error.message,
      );
      return null;
    } on OdooAccessDeniedException catch (error) {
      await store.markRechazada(
        database,
        scopeKey: scope.scopeKey,
        operationUuid: uuid,
        mensaje: 'No tienes permiso en Odoo para esta operación: ${error.message}',
      );
      return null;
    } on AmbiguousOperationException {
      rethrow;
    } catch (error) {
      if (operation.replayPolicy == OfflineReplayPolicy.manualAfterAmbiguous) {
        await store.markRevisarAMano(
          database,
          scopeKey: scope.scopeKey,
          operationUuid: uuid,
          mensaje: error.toString(),
        );
      }
      rethrow;
    }
  }
}

int? _relationId(dynamic value) {
  if (value is List && value.isNotEmpty && value.first is num) {
    return (value.first as num).toInt();
  }
  if (value is num) return value.toInt();
  return null;
}

int? _createdId(dynamic result) {
  if (result is num) {
    final asInt = result.toInt();
    return asInt > 0 ? asInt : null;
  }
  if (result is List && result.length == 1) return _createdId(result.first);
  if (result is Map) return _createdId(result['id'] ?? result['result']);
  return null;
}
