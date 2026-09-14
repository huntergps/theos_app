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
    show ConflictInfo, OdooValidationException, OfflineOperation, OfflineReplayPolicy, formatOdooDateTime;
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
      return _reconcileByUuid(uuid: uuid, preferPending: true);
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

  /// Busca un `stock.picking` con este `envases_operacion_uuid`. Sólo se
  /// alcanza cuando `replayPolicy == retrySafe`, es decir cuando el
  /// productor ya confirmó (vía `fields_get`) que el campo existe — nunca
  /// se arma un domain con un campo que el servidor no tiene.
  Future<OperationReconciliation> _reconcileByUuid({
    required String uuid,
    required bool preferPending,
  }) async {
    final result = await actions.call(
      model: 'stock.picking',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['envases_operacion_uuid', '=', uuid],
        ],
        'fields': ['id', 'state'],
        'limit': 10,
      },
    );
    final rows = result is List ? result.whereType<Map>().toList() : const <Map>[];
    if (rows.isEmpty) return const OperationNotApplied();
    final chosen = preferPending
        ? rows.firstWhere(
            (row) => row['state'] != 'done' && row['state'] != 'cancel',
            orElse: () => rows.first,
          )
        : rows.first;
    final pickingId = (chosen['id'] as num).toInt();
    await store.markEnviada(
      database,
      scopeKey: scope.scopeKey,
      operationUuid: uuid,
      pickingId: pickingId,
    );
    return const OperationApplied();
  }

  /// La recepción ya conoce su `pickingId` de entrada (es «el recibido»):
  /// sólo confirma que ESE picking quedó marcado con el uuid.
  Future<OperationReconciliation> _reconcileRecepcion({
    required String uuid,
    required int pickingId,
  }) async {
    final result = await actions.call(
      model: 'stock.picking',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['id', '=', pickingId],
          ['envases_operacion_uuid', '=', uuid],
        ],
        'fields': ['id'],
        'limit': 1,
      },
    );
    final rows = result is List ? result : const [];
    if (rows.isEmpty) return const OperationNotApplied();
    await store.markEnviada(
      database,
      scopeKey: scope.scopeKey,
      operationUuid: uuid,
      pickingId: pickingId,
    );
    return const OperationApplied();
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
        int? pickingId;
        if (operation.replayPolicy == OfflineReplayPolicy.retrySafe) {
          final found = await actions.call(
            model: 'stock.picking',
            method: 'search_read',
            kwargs: {
              'domain': [
                ['envases_operacion_uuid', '=', uuid],
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
            pickingId = ((found.first as Map)['id'] as num).toInt();
          }
        }
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
