import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_operations.dart';
import 'package:orbi_runtime/src/envases/envases_operations_durable.dart';
import 'package:orbi_runtime/src/sales/sale_runtime_adapters.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

class _MockSaleOdooActions extends Mock implements SaleOdooActions {}

void main() {
  late _MockSaleOdooActions actions;
  late RuntimeDatabaseOwner owner;
  late RuntimeDatabase db;
  late AppScope scope;
  late CompanyContext company;

  setUp(() async {
    actions = _MockSaleOdooActions();
    scope = AppScope(
      appId: 'orbi',
      installationId: 'install-1',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 7,
    );
    owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    db = await owner.open(scope);
    await ensureEnvasesOperationsSchema(db.database);
    company = CompanyContext.forScope(
      scope: scope,
      companyId: 1,
      allowedCompanyIds: const [1],
      capabilityRevision: 1,
    );
  });

  tearDown(() => owner.close());

  void stubFieldsGetFor(
    String model, {
    required bool present,
    String probedField = 'envases_operacion_uuid',
  }) {
    when(
      () => actions.call(
        model: model,
        method: 'fields_get',
        ids: any(named: 'ids'),
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer(
      (_) async =>
          present ? {probedField: {'type': 'char'}} : {'id': {'type': 'integer'}},
    );
  }

  /// Deja las tres sondas (envío, recepción y `l10n_ec.envases.operacion`)
  /// respondiendo lo mismo — sirve para las pruebas que no comprueban el
  /// valor exacto de la política, sólo que la operación se encola.
  void stubAllFieldsGet({required bool present}) {
    stubFieldsGetFor(envasesEnvioModel, present: present);
    stubFieldsGetFor(envasesRecepcionModel, present: present);
    stubFieldsGetFor(envasesOperacionModel, present: present, probedField: 'uuid');
  }

  // Alias retrocompatible con el nombre viejo, usado por las pruebas ya
  // existentes que no distinguían por modelo.
  void stubFieldsGet({required bool present}) => stubAllFieldsGet(present: present);

  DurableEnvasesOperations producer() => DurableEnvasesOperations(
    owner: owner,
    lease: db.lease,
    company: company,
    actions: actions,
  );

  EnvasesEnviarCommand envio({String uuid = 'uuid-1'}) => EnvasesEnviarCommand(
    operacionUuid: uuid,
    origenId: 10,
    destinoId: 20,
    fechaSalida: DateTime.utc(2026, 9, 13, 8),
    lineas: const [EnvasesEnvioLinea(productId: 5, cantidad: 3)],
  );

  test(
    'enviar guarda la operación y encola exactamente 1 operación; '
    'repetir el mismo uuid no duplica',
    () async {
      stubFieldsGet(present: true);
      final durable = producer();
      final first = await durable.enviar(envio());
      expect(first.estado, EnvasesOperacionEstado.pendienteDeEnviar);
      final second = await durable.enviar(envio());
      expect(second.operacionUuid, first.operacionUuid);

      final queue = OfflineQueueDataSource(db.database);
      final ops = await queue.getOperationsForModel(envasesEnvioModel);
      expect(ops, hasLength(1));
      expect(ops.single.operationKey, 'envases.envio:uuid-1');
    },
  );

  test(
    'servidor sin envases_operacion_uuid encola manual_after_ambiguous',
    () async {
      stubFieldsGet(present: false);
      final durable = producer();
      await durable.enviar(envio(uuid: 'uuid-2'));

      final queue = OfflineQueueDataSource(db.database);
      final ops = await queue.getOperationsForModel(envasesEnvioModel);
      expect(ops.single.replayPolicy, OfflineReplayPolicy.manualAfterAmbiguous);
    },
  );

  test(
    'servidor con envases_operacion_uuid encola retry_safe',
    () async {
      stubFieldsGet(present: true);
      final durable = producer();
      await durable.enviar(envio(uuid: 'uuid-3'));

      final queue = OfflineQueueDataSource(db.database);
      final ops = await queue.getOperationsForModel(envasesEnvioModel);
      expect(ops.single.replayPolicy, OfflineReplayPolicy.retrySafe);
    },
  );

  test('recibir guarda picking_id y las líneas llegaron/danadas', () async {
    stubFieldsGet(present: true);
    final durable = producer();
    final result = await durable.recibir(
      EnvasesRecibirCommand(
        operacionUuid: 'uuid-4',
        pickingId: 99,
        lineas: const [
          EnvasesRecepcionLinea(productId: 5, llegaron: 3, danadas: 1),
        ],
      ),
    );
    expect(result.pickingId, 99);

    final queue = OfflineQueueDataSource(db.database);
    final ops = await queue.getOperationsForModel(envasesRecepcionModel);
    expect(ops, hasLength(1));
    final values = ops.single.values;
    expect(values['picking_id'], 99);
    final lineas = values['lineas'] as List;
    expect(lineas.single, {'product_id': 5, 'llegaron': 3.0, 'danadas': 1.0});
  });

  test('darPorPerdido siempre encola retry_safe', () async {
    final durable = producer();
    await durable.darPorPerdido(operacionUuid: 'uuid-5', pickingId: 42);

    final queue = OfflineQueueDataSource(db.database);
    final ops = await queue.getOperationsForModel(envasesPerdidoModel);
    expect(ops.single.replayPolicy, OfflineReplayPolicy.retrySafe);
    verifyNever(
      () => actions.call(
        model: any(named: 'model'),
        method: any(named: 'method'),
        ids: any(named: 'ids'),
        kwargs: any(named: 'kwargs'),
      ),
    );
  });

  test('watchOperaciones filtra por compañía', () async {
    stubFieldsGet(present: true);
    final durable = producer();
    await durable.enviar(envio(uuid: 'uuid-6'));
    final otherCompany = CompanyContext.forScope(
      scope: scope,
      companyId: 2,
      allowedCompanyIds: const [2],
      capabilityRevision: 1,
    );
    final durableOther = DurableEnvasesOperations(
      owner: owner,
      lease: db.lease,
      company: otherCompany,
      actions: actions,
    );
    final ownRows = await durable.watchOperaciones().first;
    final otherRows = await durableOther.watchOperaciones().first;
    expect(ownRows, hasLength(1));
    expect(otherRows, isEmpty);
  });

  group('sondeo por asistente (14-sep-2026)', () {
    test(
      'A: wizard.envio tiene el campo y l10n_ec.envases.operacion NO -> envío manualAfterAmbiguous',
      () async {
        stubFieldsGetFor(envasesEnvioModel, present: true);
        stubFieldsGetFor(envasesOperacionModel, present: false, probedField: 'uuid');
        final durable = producer();
        await durable.enviar(envio(uuid: 'uuid-a'));

        final queue = OfflineQueueDataSource(db.database);
        final ops = await queue.getOperationsForModel(envasesEnvioModel);
        expect(ops.single.replayPolicy, OfflineReplayPolicy.manualAfterAmbiguous);
      },
    );

    test(
      'B: l10n_ec.envases.operacion tiene uuid (y stock.picking también, cebo del sondeo viejo) pero wizard.envio NO tiene envases_operacion_uuid -> envío manualAfterAmbiguous',
      () async {
        stubFieldsGetFor(envasesEnvioModel, present: false);
        // Cebo: el sondeo viejo miraba stock.picking y con esto solo
        // devolvería retrySafe — la prueba exige que el nuevo sondeo NO
        // caiga en esa trampa.
        stubFieldsGetFor('stock.picking', present: true);
        stubFieldsGetFor(envasesOperacionModel, present: true, probedField: 'uuid');
        final durable = producer();
        await durable.enviar(envio(uuid: 'uuid-b'));

        final queue = OfflineQueueDataSource(db.database);
        final ops = await queue.getOperationsForModel(envasesEnvioModel);
        expect(ops.single.replayPolicy, OfflineReplayPolicy.manualAfterAmbiguous);
      },
    );

    test(
      'B2: stock.picking y wizard.envio tienen el campo pero l10n_ec.envases.operacion no existe (lanza) -> envío manualAfterAmbiguous',
      () async {
        stubFieldsGetFor(envasesEnvioModel, present: true);
        stubFieldsGetFor('stock.picking', present: true);
        when(
          () => actions.call(
            model: envasesOperacionModel,
            method: 'fields_get',
            ids: any(named: 'ids'),
            kwargs: any(named: 'kwargs'),
          ),
        ).thenThrow(const OdooTimeoutException());
        final durable = producer();
        await durable.enviar(envio(uuid: 'uuid-b2'));

        final queue = OfflineQueueDataSource(db.database);
        final ops = await queue.getOperationsForModel(envasesEnvioModel);
        expect(ops.single.replayPolicy, OfflineReplayPolicy.manualAfterAmbiguous);
      },
    );

    test(
      'C: wizard.envio y l10n_ec.envases.operacion tienen el campo -> envío retrySafe',
      () async {
        stubFieldsGetFor(envasesEnvioModel, present: true);
        stubFieldsGetFor(envasesOperacionModel, present: true, probedField: 'uuid');
        final durable = producer();
        await durable.enviar(envio(uuid: 'uuid-c'));

        final queue = OfflineQueueDataSource(db.database);
        final ops = await queue.getOperationsForModel(envasesEnvioModel);
        expect(ops.single.replayPolicy, OfflineReplayPolicy.retrySafe);
      },
    );

    test(
      'D: wizard.recepcion NO tiene el campo aunque envío, stock.picking y l10n_ec.envases.operacion sí -> recepción manualAfterAmbiguous, envío retrySafe',
      () async {
        stubFieldsGetFor(envasesEnvioModel, present: true);
        stubFieldsGetFor(envasesRecepcionModel, present: false);
        // Cebo: si la política siguiera memorizada en un solo campo
        // compartido (el bug de hoy), el retrySafe del envío se le
        // pegaría a la recepción sin volver a sondear su asistente.
        stubFieldsGetFor('stock.picking', present: true);
        stubFieldsGetFor(envasesOperacionModel, present: true, probedField: 'uuid');
        final durable = producer();
        await durable.enviar(envio(uuid: 'uuid-d1'));
        await durable.recibir(
          EnvasesRecibirCommand(
            operacionUuid: 'uuid-d2',
            pickingId: 55,
            lineas: const [
              EnvasesRecepcionLinea(productId: 5, llegaron: 3, danadas: 0),
            ],
          ),
        );

        final queue = OfflineQueueDataSource(db.database);
        final opsEnvio = await queue.getOperationsForModel(envasesEnvioModel);
        expect(opsEnvio.single.replayPolicy, OfflineReplayPolicy.retrySafe);
        final opsRecepcion = await queue.getOperationsForModel(
          envasesRecepcionModel,
        );
        expect(
          opsRecepcion.single.replayPolicy,
          OfflineReplayPolicy.manualAfterAmbiguous,
        );
      },
    );

    test(
      'E: el sondeo lanza la primera vez y responde bien la segunda -> no se memoriza el fallo',
      () async {
        var callCount = 0;
        when(
          () => actions.call(
            model: envasesEnvioModel,
            method: 'fields_get',
            ids: any(named: 'ids'),
            kwargs: any(named: 'kwargs'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw const OdooTimeoutException();
          }
          return {'envases_operacion_uuid': {'type': 'char'}};
        });
        stubFieldsGetFor(envasesOperacionModel, present: true, probedField: 'uuid');
        final durable = producer();

        await durable.enviar(envio(uuid: 'uuid-e1'));
        await durable.enviar(envio(uuid: 'uuid-e2'));

        final queue = OfflineQueueDataSource(db.database);
        final ops = await queue.getOperationsForModel(envasesEnvioModel);
        final opE1 = ops.firstWhere(
          (o) => o.operationKey == 'envases.envio:uuid-e1',
        );
        final opE2 = ops.firstWhere(
          (o) => o.operationKey == 'envases.envio:uuid-e2',
        );
        expect(opE1.replayPolicy, OfflineReplayPolicy.manualAfterAmbiguous);
        expect(opE2.replayPolicy, OfflineReplayPolicy.retrySafe);
      },
    );
  });
}
