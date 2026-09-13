import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

class _MockSaleOdooActions extends Mock implements SaleOdooActions {}

void main() {
  late _MockSaleOdooActions actions;
  late AppDatabase db;
  late OfflineQueueDataSource queue;
  late UserPresencePort port;

  setUp(() {
    actions = _MockSaleOdooActions();
    db = AppDatabase(NativeDatabase.memory());
    queue = OfflineQueueDataSource(db);
    port = UserPresencePort(actions: actions, queue: queue);
  });

  tearDown(() => db.close());

  group('OdooPresence.fromOdoo', () {
    test('un valor desconocido no se convierte en online: devuelve null', () {
      expect(OdooPresence.fromOdoo('xyz'), isNull);
    });

    test('es sensible a mayúsculas: "Busy" no es "busy", devuelve null', () {
      expect(OdooPresence.fromOdoo('Busy'), isNull);
    });

    test('null también devuelve null', () {
      expect(OdooPresence.fromOdoo(null), isNull);
    });

    test('los cuatro valores exactos del servidor se reconocen', () {
      expect(OdooPresence.fromOdoo('online'), OdooPresence.online);
      expect(OdooPresence.fromOdoo('away'), OdooPresence.away);
      expect(OdooPresence.fromOdoo('busy'), OdooPresence.busy);
      expect(OdooPresence.fromOdoo('offline'), OdooPresence.offline);
    });
  });

  group('UserPresencePort.read — lo que el usuario ELIGIÓ, no el computado', () {
    test('pide el campo manual_im_status, no im_status', () async {
      when(
        () => actions.call(
          model: 'res.users',
          method: 'read',
          ids: [7],
          kwargs: const {
            'fields': ['manual_im_status'],
          },
        ),
      ).thenAnswer(
        (_) async => [
          {'id': 7, 'manual_im_status': false},
        ],
      );

      await port.read(7);

      verify(
        () => actions.call(
          model: 'res.users',
          method: 'read',
          ids: [7],
          kwargs: const {
            'fields': ['manual_im_status'],
          },
        ),
      ).called(1);
    });

    test('manual_im_status: false (sin estado manual) es online, no offline', () async {
      when(
        () => actions.call(
          model: 'res.users',
          method: 'read',
          ids: [7],
          kwargs: const {
            'fields': ['manual_im_status'],
          },
        ),
      ).thenAnswer(
        (_) async => [
          {'id': 7, 'manual_im_status': false, 'im_status': 'offline'},
        ],
      );

      final result = await port.read(7);

      expect(result, OdooPresence.online);
    });

    test('manual_im_status: busy se respeta tal cual', () async {
      when(
        () => actions.call(
          model: 'res.users',
          method: 'read',
          ids: [7],
          kwargs: const {
            'fields': ['manual_im_status'],
          },
        ),
      ).thenAnswer(
        (_) async => [
          {'id': 7, 'manual_im_status': 'busy'},
        ],
      );

      final result = await port.read(7);

      expect(result, OdooPresence.busy);
    });

    test('un manual_im_status que el servidor no reconoce devuelve null, no online', () async {
      when(
        () => actions.call(
          model: 'res.users',
          method: 'read',
          ids: [7],
          kwargs: const {
            'fields': ['manual_im_status'],
          },
        ),
      ).thenAnswer(
        (_) async => [
          {'id': 7, 'manual_im_status': 'xyz'},
        ],
      );

      final result = await port.read(7);

      expect(result, isNull);
    });
  });

  group('UserPresencePort.set — SIEMPRE local, nunca llama al servidor', () {
    test('encola mobile_set_im_status con el status elegido', () async {
      await port.set(7, OdooPresence.busy);

      final ops = await queue.getOperationsForModel('res.users');
      expect(ops, hasLength(1));
      expect(ops.single.method, 'mobile_set_im_status');
      expect(ops.single.recordId, 7);
      expect(ops.single.values, {'status': 'busy'});
      verifyNever(
        () => actions.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        ),
      );
    });

    test(
      'dos cambios seguidos sin red dejan UNA sola operación con el ÚLTIMO estado',
      () async {
        await port.set(7, OdooPresence.busy);
        await port.set(7, OdooPresence.away);

        final ops = await queue.getOperationsForModel('res.users');
        expect(ops, hasLength(1));
        expect(ops.single.values, {'status': 'away'});
      },
    );

    test('presence de otro usuario no se pisa: cada quien su propia operación', () async {
      await port.set(7, OdooPresence.busy);
      await port.set(9, OdooPresence.offline);

      final ops = await queue.getOperationsForModel('res.users');
      expect(ops, hasLength(2));
    });
  });

  group('UserPresencePort.readPending', () {
    test('sin cambios pendientes devuelve null', () async {
      expect(await port.readPending(7), isNull);
    });

    test('con un cambio pendiente devuelve el último estado elegido', () async {
      await port.set(7, OdooPresence.busy);
      await port.set(7, OdooPresence.away);

      expect(await port.readPending(7), OdooPresence.away);
    });
  });
}
