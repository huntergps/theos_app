import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_offline_adapter.dart';
import 'package:orbi_runtime/src/envases/envases_operations.dart';
import 'package:orbi_runtime/src/envases/envases_operations_durable.dart';
import 'package:orbi_runtime/src/sales/sale_runtime_adapters.dart';
import 'package:orbi_runtime/src/sync/operations_sync_job.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

class _MockSaleOdooActions extends Mock implements SaleOdooActions {}

void main() {
  late _MockSaleOdooActions actions;
  late AppDatabase db;
  late AppScope scope;
  late EnvasesOfflineOperationAdapter adapter;
  const store = EnvasesOperationsStore();

  setUp(() async {
    actions = _MockSaleOdooActions();
    db = AppDatabase(NativeDatabase.memory());
    await ensureEnvasesOperationsSchema(db);
    scope = AppScope(
      appId: 'orbi',
      installationId: 'i',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 7,
    );
    adapter = EnvasesOfflineOperationAdapter(
      actions: actions,
      database: db,
      scope: scope,
    );
  });

  tearDown(() => db.close());

  Future<void> seedLocalRow(String uuid, {String tipo = 'envio', int? pickingId}) =>
      store.insert(
        db,
        scopeKey: scope.scopeKey,
        companyId: 1,
        operationUuid: uuid,
        tipo: tipo,
        creadaEn: DateTime.utc(2026, 9, 13),
        pickingId: pickingId,
      );

  dynamic anyCallStub() => actions.call(
    model: any(named: 'model'),
    method: any(named: 'method'),
    ids: any(named: 'ids'),
    kwargs: any(named: 'kwargs'),
  );

  group('dispatch — envío', () {
    test('con manual_after_ambiguous crea el asistente SIN envases_operacion_uuid y llama action_enviar sobre el id creado', () async {
      await seedLocalRow('uuid-envio-1');
      final operation = OfflineOperation(
        id: 1,
        model: envasesEnvioModel,
        method: envasesEnvioMethod,
        values: {
          'operacion_uuid': 'uuid-envio-1',
          'origen_id': 10,
          'destino_id': 20,
          'fecha_salida': DateTime.utc(2026, 9, 13, 8).toIso8601String(),
          'responsable_id': 7,
          'lineas': [
            {'product_id': 5, 'cantidad': 3.0},
          ],
        },
        createdAt: DateTime.utc(2026, 9, 13),
        replayPolicy: OfflineReplayPolicy.manualAfterAmbiguous,
      );
      when(anyCallStub).thenAnswer((invocation) async {
        final method = invocation.namedArguments[#method];
        if (method == 'create') return 42;
        return {'type': 'ir.actions.act_window_close'};
      });

      final conflict = await adapter.dispatch(operation);

      expect(conflict, isNull);
      // Sin sondeo positivo de `fields_get` (manual_after_ambiguous), el
      // servidor puede no tener el campo todavía: los vals NO deben
      // llevar `envases_operacion_uuid`, ni con `create` incluida.
      verify(
        () => actions.call(
          model: envasesEnvioModel,
          method: 'create',
          ids: any(named: 'ids'),
          kwargs: {
            'vals_list': [
              {
                'origen_id': 10,
                'destino_id': 20,
                'fecha_salida': formatOdooDateTime(DateTime.utc(2026, 9, 13, 8)),
                'responsable_id': 7,
                'line_ids': [
                  [
                    0,
                    0,
                    {'product_id': 5, 'cantidad': 3.0},
                  ],
                ],
              },
            ],
          },
        ),
      ).called(1);
      verify(
        () => actions.call(
          model: envasesEnvioModel,
          method: 'action_enviar',
          ids: [42],
          kwargs: any(named: 'kwargs'),
        ),
      ).called(1);

      final local = await store.getByUuid(
        db,
        scopeKey: scope.scopeKey,
        operationUuid: 'uuid-envio-1',
      );
      expect(local!.estado, EnvasesOperacionEstado.enviada);
    });

    test('con retry_safe crea el asistente CON envases_operacion_uuid', () async {
      await seedLocalRow('uuid-envio-1b');
      final operation = OfflineOperation(
        id: 1,
        model: envasesEnvioModel,
        method: envasesEnvioMethod,
        values: {
          'operacion_uuid': 'uuid-envio-1b',
          'origen_id': 10,
          'destino_id': 20,
          'fecha_salida': DateTime.utc(2026, 9, 13, 8).toIso8601String(),
          'responsable_id': 7,
          'lineas': [
            {'product_id': 5, 'cantidad': 3.0},
          ],
        },
        createdAt: DateTime.utc(2026, 9, 13),
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      when(anyCallStub).thenAnswer((invocation) async {
        final method = invocation.namedArguments[#method];
        if (method == 'create') return 43;
        return {'type': 'ir.actions.act_window_close'};
      });

      final conflict = await adapter.dispatch(operation);

      expect(conflict, isNull);
      // El sondeo (`fields_get`) ya confirmó que el campo existe: acá sí
      // se manda, porque el `search_read` de reconciliación lo necesita.
      verify(
        () => actions.call(
          model: envasesEnvioModel,
          method: 'create',
          ids: any(named: 'ids'),
          kwargs: {
            'vals_list': [
              {
                'origen_id': 10,
                'destino_id': 20,
                'fecha_salida': formatOdooDateTime(DateTime.utc(2026, 9, 13, 8)),
                'responsable_id': 7,
                'envases_operacion_uuid': 'uuid-envio-1b',
                'line_ids': [
                  [
                    0,
                    0,
                    {'product_id': 5, 'cantidad': 3.0},
                  ],
                ],
              },
            ],
          },
        ),
      ).called(1);
    });

    test('UserError de Odoo pasa a rechazada con el mensaje, sin reintentar', () async {
      await seedLocalRow('uuid-envio-2');
      final operation = OfflineOperation(
        id: 1,
        model: envasesEnvioModel,
        method: envasesEnvioMethod,
        values: {
          'operacion_uuid': 'uuid-envio-2',
          'origen_id': 10,
          'destino_id': 20,
          'fecha_salida': DateTime.utc(2026, 9, 13, 8).toIso8601String(),
          'responsable_id': 7,
          'lineas': [
            {'product_id': 5, 'cantidad': 3.0},
          ],
        },
        createdAt: DateTime.utc(2026, 9, 13),
        replayPolicy: OfflineReplayPolicy.manualAfterAmbiguous,
      );
      when(anyCallStub).thenAnswer((invocation) async {
        final method = invocation.namedArguments[#method];
        if (method == 'create') return 42;
        throw OdooValidationException(
          'No hay suficiente disponible para enviar.',
        );
      });

      final conflict = await adapter.dispatch(operation);

      expect(conflict, isNull);
      final local = await store.getByUuid(
        db,
        scopeKey: scope.scopeKey,
        operationUuid: 'uuid-envio-2',
      );
      expect(local!.estado, EnvasesOperacionEstado.rechazada);
      expect(local.mensajeOdoo, 'No hay suficiente disponible para enviar.');
    });

    test('un fallo ambiguo bajo manual_after_ambiguous marca revisarAMano y relanza', () async {
      await seedLocalRow('uuid-envio-3');
      final operation = OfflineOperation(
        id: 1,
        model: envasesEnvioModel,
        method: envasesEnvioMethod,
        values: {
          'operacion_uuid': 'uuid-envio-3',
          'origen_id': 10,
          'destino_id': 20,
          'fecha_salida': DateTime.utc(2026, 9, 13, 8).toIso8601String(),
          'responsable_id': 7,
          'lineas': [
            {'product_id': 5, 'cantidad': 3.0},
          ],
        },
        createdAt: DateTime.utc(2026, 9, 13),
        replayPolicy: OfflineReplayPolicy.manualAfterAmbiguous,
      );
      when(anyCallStub).thenThrow(const OdooTimeoutException());

      await expectLater(adapter.dispatch(operation), throwsA(isA<OdooTimeoutException>()));

      final local = await store.getByUuid(
        db,
        scopeKey: scope.scopeKey,
        operationUuid: 'uuid-envio-3',
      );
      expect(local!.estado, EnvasesOperacionEstado.revisarAMano);
    });
  });

  group('reconcile — envío', () {
    test('encuentra el picking por uuid y no llama a create', () async {
      await seedLocalRow('uuid-envio-4');
      final operation = OfflineOperation(
        id: 1,
        model: envasesEnvioModel,
        method: envasesEnvioMethod,
        values: {'operacion_uuid': 'uuid-envio-4'},
        createdAt: DateTime.utc(2026, 9, 13),
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      when(anyCallStub).thenAnswer(
        (_) async => [
          {'id': 77, 'state': 'assigned'},
        ],
      );

      final result = await adapter.reconcile(operation);

      expect(result, isA<OperationApplied>());
      verifyNever(
        () => actions.call(
          model: any(named: 'model'),
          method: 'create',
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        ),
      );
      final local = await store.getByUuid(
        db,
        scopeKey: scope.scopeKey,
        operationUuid: 'uuid-envio-4',
      );
      expect(local!.estado, EnvasesOperacionEstado.enviada);
      expect(local.pickingId, 77);
    });

    test('sin picking encontrado devuelve OperationNotApplied', () async {
      await seedLocalRow('uuid-envio-5');
      final operation = OfflineOperation(
        id: 1,
        model: envasesEnvioModel,
        method: envasesEnvioMethod,
        values: {'operacion_uuid': 'uuid-envio-5'},
        createdAt: DateTime.utc(2026, 9, 13),
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      when(anyCallStub).thenAnswer((_) async => <Map<String, dynamic>>[]);

      final result = await adapter.reconcile(operation);

      expect(result, isA<OperationNotApplied>());
    });
  });

  group('dispatch — recepción', () {
    test('manda llegaron y danadas por línea antes de action_recibir', () async {
      await seedLocalRow('uuid-recepcion-1', tipo: 'recepcion', pickingId: 99);
      final operation = OfflineOperation(
        id: 1,
        model: envasesRecepcionModel,
        method: envasesRecepcionMethod,
        recordId: 99,
        values: {
          'operacion_uuid': 'uuid-recepcion-1',
          'picking_id': 99,
          'responsable_id': 7,
          'lineas': [
            {'product_id': 5, 'llegaron': 3.0, 'danadas': 1.0},
            {'product_id': 6, 'llegaron': 2.0, 'danadas': 0.0},
          ],
        },
        createdAt: DateTime.utc(2026, 9, 13),
        replayPolicy: OfflineReplayPolicy.manualAfterAmbiguous,
      );
      when(anyCallStub).thenAnswer((invocation) async {
        final model = invocation.namedArguments[#model];
        final method = invocation.namedArguments[#method];
        if (model == envasesRecepcionModel && method == 'create') return 55;
        if (model == '$envasesRecepcionModel.line' && method == 'search_read') {
          return [
            {'id': 501, 'product_id': [5, 'Jaba 12']},
            {'id': 502, 'product_id': [6, 'Jaba 24']},
          ];
        }
        return {'type': 'ir.actions.act_window_close'};
      });

      final conflict = await adapter.dispatch(operation);

      expect(conflict, isNull);
      verify(
        () => actions.call(
          model: '$envasesRecepcionModel.line',
          method: 'write',
          ids: [501],
          kwargs: {
            'vals': {'llegaron': 3.0, 'danadas': 1.0},
          },
        ),
      ).called(1);
      verify(
        () => actions.call(
          model: '$envasesRecepcionModel.line',
          method: 'write',
          ids: [502],
          kwargs: {
            'vals': {'llegaron': 2.0, 'danadas': 0.0},
          },
        ),
      ).called(1);
      verify(
        () => actions.call(
          model: envasesRecepcionModel,
          method: 'action_recibir',
          ids: [55],
          kwargs: any(named: 'kwargs'),
        ),
      ).called(1);

      final local = await store.getByUuid(
        db,
        scopeKey: scope.scopeKey,
        operationUuid: 'uuid-recepcion-1',
      );
      expect(local!.estado, EnvasesOperacionEstado.enviada);
      expect(local.pickingId, 99);
    });

    test('con manual_after_ambiguous crea el asistente SIN envases_operacion_uuid', () async {
      await seedLocalRow('uuid-recepcion-2', tipo: 'recepcion', pickingId: 98);
      final operation = OfflineOperation(
        id: 1,
        model: envasesRecepcionModel,
        method: envasesRecepcionMethod,
        recordId: 98,
        values: {
          'operacion_uuid': 'uuid-recepcion-2',
          'picking_id': 98,
          'responsable_id': 7,
          'lineas': [
            {'product_id': 5, 'llegaron': 3.0, 'danadas': 0.0},
          ],
        },
        createdAt: DateTime.utc(2026, 9, 13),
        replayPolicy: OfflineReplayPolicy.manualAfterAmbiguous,
      );
      when(anyCallStub).thenAnswer((invocation) async {
        final model = invocation.namedArguments[#model];
        final method = invocation.namedArguments[#method];
        if (model == envasesRecepcionModel && method == 'create') return 56;
        if (model == '$envasesRecepcionModel.line' && method == 'search_read') {
          return [
            {'id': 601, 'product_id': [5, 'Jaba 12']},
          ];
        }
        return {'type': 'ir.actions.act_window_close'};
      });

      final conflict = await adapter.dispatch(operation);

      expect(conflict, isNull);
      // Sin sondeo positivo, el `create` de `wizard.recepcion` NO debe
      // llevar `envases_operacion_uuid` — el servidor puede no tener el
      // campo todavía.
      verify(
        () => actions.call(
          model: envasesRecepcionModel,
          method: 'create',
          ids: any(named: 'ids'),
          kwargs: {
            'vals_list': [
              {
                'picking_id': 98,
                'responsable_id': 7,
              },
            ],
          },
        ),
      ).called(1);
    });

    test('con retry_safe crea el asistente CON envases_operacion_uuid', () async {
      await seedLocalRow('uuid-recepcion-3', tipo: 'recepcion', pickingId: 97);
      final operation = OfflineOperation(
        id: 1,
        model: envasesRecepcionModel,
        method: envasesRecepcionMethod,
        recordId: 97,
        values: {
          'operacion_uuid': 'uuid-recepcion-3',
          'picking_id': 97,
          'responsable_id': 7,
          'lineas': [
            {'product_id': 5, 'llegaron': 3.0, 'danadas': 0.0},
          ],
        },
        createdAt: DateTime.utc(2026, 9, 13),
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      when(anyCallStub).thenAnswer((invocation) async {
        final model = invocation.namedArguments[#model];
        final method = invocation.namedArguments[#method];
        if (model == envasesRecepcionModel && method == 'create') return 57;
        if (model == '$envasesRecepcionModel.line' && method == 'search_read') {
          return [
            {'id': 701, 'product_id': [5, 'Jaba 12']},
          ];
        }
        return {'type': 'ir.actions.act_window_close'};
      });

      final conflict = await adapter.dispatch(operation);

      expect(conflict, isNull);
      verify(
        () => actions.call(
          model: envasesRecepcionModel,
          method: 'create',
          ids: any(named: 'ids'),
          kwargs: {
            'vals_list': [
              {
                'picking_id': 97,
                'responsable_id': 7,
                'envases_operacion_uuid': 'uuid-recepcion-3',
              },
            ],
          },
        ),
      ).called(1);
    });
  });

  group('reconcile — perdido', () {
    test('picking ya no pendiente se trata como aplicada', () async {
      await seedLocalRow('uuid-perdido-1', tipo: 'perdido', pickingId: 12);
      final operation = OfflineOperation(
        id: 1,
        model: envasesPerdidoModel,
        method: envasesPerdidoMethod,
        recordId: 12,
        values: {'operacion_uuid': 'uuid-perdido-1', 'picking_id': 12},
        createdAt: DateTime.utc(2026, 9, 13),
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      when(anyCallStub).thenAnswer(
        (_) async => [
          {'state': 'cancel'},
        ],
      );

      final result = await adapter.reconcile(operation);

      expect(result, isA<OperationApplied>());
    });

    test('picking todavía pendiente devuelve OperationNotApplied', () async {
      await seedLocalRow('uuid-perdido-2', tipo: 'perdido', pickingId: 13);
      final operation = OfflineOperation(
        id: 1,
        model: envasesPerdidoModel,
        method: envasesPerdidoMethod,
        recordId: 13,
        values: {'operacion_uuid': 'uuid-perdido-2', 'picking_id': 13},
        createdAt: DateTime.utc(2026, 9, 13),
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      when(anyCallStub).thenAnswer(
        (_) async => [
          {'state': 'assigned'},
        ],
      );

      final result = await adapter.reconcile(operation);

      expect(result, isA<OperationNotApplied>());
    });
  });
}
