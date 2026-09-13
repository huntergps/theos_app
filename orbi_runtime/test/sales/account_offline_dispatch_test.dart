import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

class _MockSaleOdooActions extends Mock implements SaleOdooActions {}

void main() {
  late _MockSaleOdooActions actions;
  late AppDatabase db;
  late OfflineQueueDataSource queue;
  late OdooOfflineOperationAdapter adapter;
  late AppScope scope;

  setUp(() {
    actions = _MockSaleOdooActions();
    db = AppDatabase(NativeDatabase.memory());
    queue = OfflineQueueDataSource(db);
    scope = AppScope(
      appId: 'panel',
      installationId: 'install',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 7,
    );
    adapter = OdooOfflineOperationAdapter(
      actions: actions,
      database: db,
      scope: scope,
      queue: queue,
    );
  });

  tearDown(() => db.close());

  group('reconcile — preferencias y presencia son idempotentes', () {
    test('res.users.write nunca consulta el servidor antes de reintentar', () async {
      final operation = OfflineOperation(
        id: 1,
        model: 'res.users',
        method: 'write',
        recordId: 7,
        values: const {'lang': 'en_US'},
        createdAt: DateTime.utc(2026, 9, 13),
      );
      expect(await adapter.reconcile(operation), isA<OperationNotApplied>());
      verifyNever(
        () => actions.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        ),
      );
    });

    test('res.partner.write nunca consulta el servidor antes de reintentar', () async {
      final operation = OfflineOperation(
        id: 1,
        model: 'res.partner',
        method: 'write',
        recordId: 42,
        values: const {'phone': '0987654321'},
        createdAt: DateTime.utc(2026, 9, 13),
      );
      expect(await adapter.reconcile(operation), isA<OperationNotApplied>());
    });

    test('mobile_set_im_status nunca consulta el servidor antes de reintentar', () async {
      final operation = OfflineOperation(
        id: 1,
        model: 'res.users',
        method: 'mobile_set_im_status',
        recordId: 7,
        values: const {'status': 'busy'},
        createdAt: DateTime.utc(2026, 9, 13),
      );
      expect(await adapter.reconcile(operation), isA<OperationNotApplied>());
    });
  });

  group('dispatch — el despachador ya sabe escribir res.users/res.partner', () {
    test('res.users.write manda ids y vals correctos', () async {
      when(
        () => actions.call(
          model: 'res.users',
          method: 'write',
          ids: [7],
          kwargs: {
            'vals': {'lang': 'en_US'},
          },
        ),
      ).thenAnswer((_) async => true);

      final operation = OfflineOperation(
        id: 1,
        model: 'res.users',
        method: 'write',
        recordId: 7,
        values: const {'lang': 'en_US'},
        createdAt: DateTime.utc(2026, 9, 13),
      );
      final conflict = await adapter.dispatch(operation);

      expect(conflict, isNull);
      verify(
        () => actions.call(
          model: 'res.users',
          method: 'write',
          ids: [7],
          kwargs: {
            'vals': {'lang': 'en_US'},
          },
        ),
      ).called(1);
    });

    test('res.partner.write manda ids y vals correctos', () async {
      when(
        () => actions.call(
          model: 'res.partner',
          method: 'write',
          ids: [42],
          kwargs: {
            'vals': {'phone': '0987654321'},
          },
        ),
      ).thenAnswer((_) async => true);

      final operation = OfflineOperation(
        id: 1,
        model: 'res.partner',
        method: 'write',
        recordId: 42,
        values: const {'phone': '0987654321'},
        createdAt: DateTime.utc(2026, 9, 13),
      );
      final conflict = await adapter.dispatch(operation);

      expect(conflict, isNull);
      verify(
        () => actions.call(
          model: 'res.partner',
          method: 'write',
          ids: [42],
          kwargs: {
            'vals': {'phone': '0987654321'},
          },
        ),
      ).called(1);
    });

    test('un res.users.write rechazado vuelve como ConflictInfo, no se pierde', () async {
      when(
        () => actions.call(
          model: 'res.users',
          method: 'write',
          ids: [7],
          kwargs: {
            'vals': {'lang': 'en_US'},
          },
        ),
      ).thenAnswer((_) async => false);

      final operation = OfflineOperation(
        id: 1,
        model: 'res.users',
        method: 'write',
        recordId: 7,
        values: const {'lang': 'en_US'},
        createdAt: DateTime.utc(2026, 9, 13),
      );
      final conflict = await adapter.dispatch(operation);

      expect(conflict, isNotNull);
      expect(conflict!.model, 'res.users');
      expect(conflict.recordId, 7);
    });

    test('mobile_set_im_status manda status sin ids (es @api.model)', () async {
      when(
        () => actions.call(
          model: 'res.users',
          method: 'mobile_set_im_status',
          kwargs: {'status': 'busy'},
        ),
      ).thenAnswer((_) async => true);

      final operation = OfflineOperation(
        id: 1,
        model: 'res.users',
        method: 'mobile_set_im_status',
        recordId: 7,
        values: const {'status': 'busy'},
        createdAt: DateTime.utc(2026, 9, 13),
      );
      final conflict = await adapter.dispatch(operation);

      expect(conflict, isNull);
      final captured = verify(
        () => actions.call(
          model: 'res.users',
          method: 'mobile_set_im_status',
          ids: captureAny(named: 'ids'),
          kwargs: {'status': 'busy'},
        ),
      ).captured;
      expect(captured.single, isNull);
    });
  });
}
